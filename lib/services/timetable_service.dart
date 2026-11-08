import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/class_timetable.dart';
import 'auth_service.dart';

/// Service responsible for managing section-scoped, versioned recurring weekly
/// timetables (Module M2), version history, approval workflows, and append-only audits.
class TimetableService {
  final FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;
  static SharedPreferences? _prefs;

  static Exception? firestoreFailureSimulated;

  TimetableService({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  static Future<void> initPreferences([SharedPreferences? prefs]) async {
    _prefs = prefs ?? await SharedPreferences.getInstance();
  }

  static SharedPreferences? get _safePrefs => _prefs;

  bool get _isLive => AuthService.isFirebaseLive;

  static bool _isNoAppException(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('no-app') || s.contains('no firebase app');
  }

  // ===============================================================
  // Cache Keys (Section-Aware)
  // ===============================================================

  static String _historyKey(String classId, String dayOfWeek) =>
      'timetable_history_${classId.trim().toUpperCase()}_${dayOfWeek.trim()}';

  static String _activeKey(String classId, String dayOfWeek) =>
      'timetable_active_${classId.trim().toUpperCase()}_${dayOfWeek.trim()}';

  static String _auditKey(String classId) =>
      'timetable_audit_${classId.trim().toUpperCase()}';

  // ===============================================================
  // Local Cache Accessors
  // ===============================================================

  List<ClassTimetableVersion> getCachedVersions(String classId, String dayOfWeek) {
    final key = _historyKey(classId, dayOfWeek);
    final raw = _safePrefs?.getStringList(key);
    if (raw == null || raw.isEmpty) return <ClassTimetableVersion>[];
    final list = <ClassTimetableVersion>[];
    for (final s in raw) {
      try {
        list.add(ClassTimetableVersion.fromMap(jsonDecode(s) as Map<String, dynamic>));
      } catch (_) {}
    }
    list.sort((a, b) => b.version.compareTo(a.version));
    return list;
  }

  Future<void> cacheVersions(String classId, String dayOfWeek, List<ClassTimetableVersion> versions) async {
    final key = _historyKey(classId, dayOfWeek);
    final list = versions.map((v) => jsonEncode(v.toJsonMap())).toList();
    await _safePrefs?.setStringList(key, list);
  }

  ClassTimetableVersion? getCachedActiveVersion(String classId, String dayOfWeek, [DateTime? date]) {
    final versions = getCachedVersions(classId, dayOfWeek);
    return ClassTimetableVersion.activeForDate(versions, date ?? DateTime.now());
  }

  Future<void> cacheActiveVersion(String classId, String dayOfWeek, ClassTimetableVersion version) async {
    final key = _activeKey(classId, dayOfWeek);
    await _safePrefs?.setString(key, jsonEncode(version.toJsonMap()));
  }

  List<Map<String, dynamic>> getCachedAudits(String classId) {
    final key = _auditKey(classId);
    final raw = _safePrefs?.getStringList(key);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    final list = <Map<String, dynamic>>[];
    for (final s in raw) {
      try {
        list.add(Map<String, dynamic>.from(jsonDecode(s) as Map));
      } catch (_) {}
    }
    return list;
  }

  Future<void> cacheAudit(String classId, Map<String, dynamic> audit) async {
    final key = _auditKey(classId);
    final existing = List<Map<String, dynamic>>.from(getCachedAudits(classId));
    existing.insert(0, audit);
    if (existing.length > 100) existing.removeRange(100, existing.length);
    await _safePrefs?.setStringList(key, existing.map((e) => jsonEncode(e)).toList());
  }

  // ===============================================================
  // Version Operations (Truthful writes: Firestore first, cache after)
  // ===============================================================

  /// Saves a draft version. If [version.id] is empty, a new document ID is generated.
  Future<bool> saveTimetableDraft(ClassTimetableVersion version) async {
    final errors = version.validate();
    if (errors.isNotEmpty) {
      debugPrint('Timetable validation failed: ${errors.join(', ')}');
      return false;
    }

    final id = version.id.isNotEmpty
        ? version.id
        : 'tt_${version.classId}_${version.dayOfWeek}_v${version.version}_${DateTime.now().millisecondsSinceEpoch}';

    final draft = version.copyWith(
      id: id,
      status: TimetableStatus.draft,
      createdAt: version.createdAt ?? DateTime.now(),
    );

    if (_isLive) {
      try {
        if (firestoreFailureSimulated != null) {
          throw firestoreFailureSimulated!;
        }
        final docRef = _firestore.collection('timetable_versions').doc(id);
        final data = draft.toMap();
        data['created_at'] = Timestamp.fromDate(draft.createdAt!);
        data['updated_at'] = FieldValue.serverTimestamp();
        await docRef.set(data, SetOptions(merge: true));
      } catch (e) {
        if (!_isNoAppException(e)) {
          debugPrint('Firestore saveTimetableDraft failure: $e');
          return false;
        }
      }
    }

    _updateLocalCache(draft);
    await writeTimetableAudit(
      action: 'edit',
      classId: draft.classId,
      dayOfWeek: draft.dayOfWeek,
      versionId: draft.id,
      version: draft.version,
      actorUid: draft.createdByUid,
      actorName: draft.createdByName,
      details: draft.isTemporary
          ? 'Saved draft one-day override for ${_dateLabel(draft.overrideDate!)}'
          : 'Saved draft version ${draft.version}',
    );

    return true;
  }

  /// Submits a timetable version for administrative review.
  Future<bool> submitTimetable(ClassTimetableVersion version) async {
    final errors = version.validate();
    if (errors.isNotEmpty) return false;

    final id = version.id.isNotEmpty
        ? version.id
        : 'tt_${version.classId}_${version.dayOfWeek}_v${version.version}_${DateTime.now().millisecondsSinceEpoch}';

    final submitted = version.copyWith(
      id: id,
      status: TimetableStatus.submitted,
      createdAt: version.createdAt ?? DateTime.now(),
    );

    if (_isLive) {
      try {
        if (firestoreFailureSimulated != null) {
          throw firestoreFailureSimulated!;
        }
        final docRef = _firestore.collection('timetable_versions').doc(id);
        final data = submitted.toMap();
        data['created_at'] = Timestamp.fromDate(submitted.createdAt!);
        data['updated_at'] = FieldValue.serverTimestamp();
        await docRef.set(data, SetOptions(merge: true));
      } catch (e) {
        if (!_isNoAppException(e)) {
          debugPrint('Firestore submitTimetable failure: $e');
          return false;
        }
      }
    }

    _updateLocalCache(submitted);
    await writeTimetableAudit(
      action: 'submit',
      classId: submitted.classId,
      dayOfWeek: submitted.dayOfWeek,
      versionId: submitted.id,
      version: submitted.version,
      actorUid: submitted.createdByUid,
      actorName: submitted.createdByName,
      details: submitted.isTemporary
          ? 'Submitted one-day override for ${_dateLabel(submitted.overrideDate!)} for administrative approval'
          : 'Submitted version ${submitted.version} for administrative approval',
    );

    return true;
  }

  /// Publishes a timetable version. Once published, versions are immutable.
  /// Cross-class teacher/room conflicts are checked first (M3 tests 18–19);
  /// callers that are importing legacy data may opt out explicitly.
  Future<bool> publishTimetable(
    ClassTimetableVersion version, {
    required String publisherUid,
    required String publisherName,
    bool enforceConflicts = true,
  }) async {
    final errors = version.validate();
    if (errors.isNotEmpty) return false;

    final now = DateTime.now();
    final id = version.id.isNotEmpty
        ? version.id
        : 'tt_${version.classId}_${version.dayOfWeek}_v${version.version}_${now.millisecondsSinceEpoch}';

    final published = version.copyWith(
      id: id,
      status: TimetableStatus.published,
      publishedAt: now,
      approvedByUid: publisherUid,
      approvedByName: publisherName,
      createdAt: version.createdAt ?? now,
    );

    if (enforceConflicts) {
      try {
        final conflicts = await findTimetableConflicts(
          published,
          date: published.overrideDate ?? published.effectiveFrom,
        );
        if (conflicts.isNotEmpty) {
          debugPrint('Timetable publish blocked: ${conflicts.first.message}');
          return false;
        }
      } catch (e) {
        debugPrint('Timetable conflict check failed: $e');
        return false;
      }
    }

    if (_isLive) {
      try {
        if (firestoreFailureSimulated != null) {
          throw firestoreFailureSimulated!;
        }
        final docRef = _firestore.collection('timetable_versions').doc(id);
        final data = published.toMap();
        data['created_at'] = Timestamp.fromDate(published.createdAt!);
        data['published_at'] = Timestamp.fromDate(now);
        data['updated_at'] = FieldValue.serverTimestamp();
        await docRef.set(data, SetOptions(merge: true));
      } catch (e) {
        if (!_isNoAppException(e)) {
          debugPrint('Firestore publishTimetable failure: $e');
          return false;
        }
      }
    }

    _updateLocalCache(published);
    await cacheActiveVersion(published.classId, published.dayOfWeek, published);

    await writeTimetableAudit(
      action: 'publish',
      classId: published.classId,
      dayOfWeek: published.dayOfWeek,
      versionId: published.id,
      version: published.version,
      actorUid: publisherUid,
      actorName: publisherName,
      details: published.isTemporary
          ? 'Published one-day override for ${_dateLabel(published.overrideDate!)}'
          : 'Published recurring version ${published.version} effective from ${published.effectiveFrom.toIso8601String().split('T').first}',
    );

    return true;
  }

  /// Rejects a submitted timetable version with a reason.
  Future<bool> rejectTimetable(
    ClassTimetableVersion version, {
    required String reason,
    required String reviewerUid,
    required String reviewerName,
  }) async {
    if (version.id.isEmpty) return false;
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty || trimmedReason.length > 500) return false;

    final rejected = version.copyWith(
      status: TimetableStatus.rejected,
      approvedByUid: reviewerUid,
      approvedByName: reviewerName,
      rejectionReason: trimmedReason,
    );

    if (_isLive) {
      try {
        if (firestoreFailureSimulated != null) {
          throw firestoreFailureSimulated!;
        }
        await _firestore.collection('timetable_versions').doc(version.id).update({
          'status': TimetableStatus.rejected,
          'approved_by_uid': reviewerUid,
          'approved_by_name': reviewerName,
          'rejection_reason': trimmedReason,
          'updated_at': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        if (!_isNoAppException(e)) {
          debugPrint('Firestore rejectTimetable failure: $e');
          return false;
        }
      }
    }

    _updateLocalCache(rejected);
    await writeTimetableAudit(
      action: 'reject',
      classId: version.classId,
      dayOfWeek: version.dayOfWeek,
      versionId: version.id,
      version: version.version,
      actorUid: reviewerUid,
      actorName: reviewerName,
      details: 'Rejected version ${version.version}: $trimmedReason',
    );

    return true;
  }

  /// Restores an earlier timetable version. Restoring NEVER overwrites existing history;
  /// it creates a NEW version linked by [supersedesId] (Spec M2 §3-4, Acceptance Test 28).
  Future<ClassTimetableVersion?> restoreTimetableVersion({
    required ClassTimetableVersion targetVersion,
    required DateTime newEffectiveFrom,
    required String actorUid,
    required String actorName,
    bool publishImmediately = false,
  }) async {
    final existingVersions = getCachedVersions(targetVersion.classId, targetVersion.dayOfWeek);
    var nextVersionNum = 1;
    for (final v in existingVersions) {
      if (v.version >= nextVersionNum) nextVersionNum = v.version + 1;
    }

    final newId = 'tt_${targetVersion.classId}_${targetVersion.dayOfWeek}_v${nextVersionNum}_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    final restored = ClassTimetableVersion(
      id: newId,
      classId: targetVersion.classId,
      dayOfWeek: targetVersion.dayOfWeek,
      status: publishImmediately ? TimetableStatus.published : TimetableStatus.draft,
      effectiveFrom: newEffectiveFrom,
      version: nextVersionNum,
      breakAfterPeriod: targetVersion.breakAfterPeriod,
      breakStartMinute: targetVersion.breakStartMinute,
      slots: targetVersion.slots
          .map((s) => s.copyWith(
                substituteTeacherName: '',
                substituteTeacherUid: '',
              ))
          .toList(),
      createdByUid: actorUid,
      createdByName: actorName,
      publishedAt: publishImmediately ? now : null,
      approvedByUid: publishImmediately ? actorUid : '',
      approvedByName: publishImmediately ? actorName : '',
      supersedesId: targetVersion.id,
      createdAt: now,
    );

    final success = publishImmediately
        ? await publishTimetable(restored, publisherUid: actorUid, publisherName: actorName)
        : await saveTimetableDraft(restored);

    if (!success) return null;

    await writeTimetableAudit(
      action: 'restore',
      classId: restored.classId,
      dayOfWeek: restored.dayOfWeek,
      versionId: restored.id,
      version: restored.version,
      actorUid: actorUid,
      actorName: actorName,
      details: 'Restored from version ${targetVersion.version} as new version ${restored.version} (supersedes ${targetVersion.id})',
    );

    return restored;
  }

  // ===============================================================
  // M3 Advanced Timetable Operations
  // ===============================================================

  /// Resolves the published recurring schedule for a day, ignoring one-day
  /// overrides. Useful for weekly previews and editor baselines.
  ClassTimetableVersion? getCachedRecurringActiveVersion(
    String classId,
    String dayOfWeek, [
    DateTime? date,
  ]) {
    final recurring = getCachedVersions(classId, dayOfWeek)
        .where((v) => !v.isTemporary)
        .toList();
    return ClassTimetableVersion.activeForDate(
      recurring,
      date ?? DateTime.now(),
    );
  }

  /// Finds teacher/room double-bookings between [candidate] and every other
  /// class's published schedule for the same day (M3 tests 18–19).
  ///
  /// On Spark this is a client-side cross-class query: it filters by
  /// `day_of_week` + `status` (equality only, no new composite index) and then
  /// resolves each class's active version for [date] locally, including
  /// date-specific overrides. In offline mode the local cache is used.
  Future<List<TimetableConflict>> findTimetableConflicts(
    ClassTimetableVersion candidate, {
    DateTime? date,
  }) async {
    final hasResources = candidate.slots.any((s) =>
        s.teacherUid.trim().isNotEmpty ||
        s.teacherName.trim().isNotEmpty ||
        s.substituteTeacherUid.trim().isNotEmpty ||
        s.substituteTeacherName.trim().isNotEmpty ||
        s.room.trim().isNotEmpty);
    if (!hasResources) return const [];

    final targetDate = date ?? candidate.overrideDate ?? candidate.effectiveFrom;
    final published = await _publishedVersionsForDay(candidate.dayOfWeek);

    final byClass = <String, List<ClassTimetableVersion>>{};
    for (final v in published) {
      byClass.putIfAbsent(v.classId.trim().toUpperCase(), () => []).add(v);
    }

    final activeOthers = <ClassTimetableVersion>[];
    for (final entry in byClass.entries) {
      if (entry.key == candidate.classId.trim().toUpperCase()) continue;
      final active = ClassTimetableVersion.activeForDate(entry.value, targetDate);
      if (active != null) activeOthers.add(active);
    }

    return ClassTimetableVersion.detectConflicts(
      candidate: candidate,
      otherVersions: activeOthers,
    );
  }

  /// Copies [source]'s full day configuration into new draft versions for
  /// exactly [targetDays]. Existing versions of other days are never mutated;
  /// the source day is ignored. Substitute markers are stripped because a
  /// substitution belongs to one calendar date (M3 tests 31–32).
  Future<Map<String, bool>> copyTimetableToDays({
    required ClassTimetableVersion source,
    required Iterable<String> targetDays,
    required String actorUid,
    required String actorName,
    bool publishImmediately = false,
    bool enforceConflicts = true,
  }) async {
    final results = <String, bool>{};
    final targets = targetDays
        .where(kTimetableWeekDays.contains)
        .where((day) => day != source.dayOfWeek)
        .toSet();

    final now = DateTime.now();
    final fallbackEffective = DateTime(now.year, now.month, now.day);
    final effectiveFrom =
        source.isTemporary ? fallbackEffective : source.effectiveFrom;

    for (final day in targets) {
      final nextVersion = _nextVersionNumber(source.classId, day);
      final copy = ClassTimetableVersion(
        classId: source.classId,
        dayOfWeek: day,
        status: publishImmediately
            ? TimetableStatus.published
            : TimetableStatus.draft,
        effectiveFrom: effectiveFrom,
        version: nextVersion,
        breakAfterPeriod: source.breakAfterPeriod,
        breakStartMinute: source.breakStartMinute,
        slots: source.slots
            .map((s) => s.copyWith(
                  substituteTeacherName: '',
                  substituteTeacherUid: '',
                ))
            .toList(),
        createdByUid: actorUid,
        createdByName: actorName,
        createdAt: now,
      );

      final ok = publishImmediately
          ? await publishTimetable(
              copy,
              publisherUid: actorUid,
              publisherName: actorName,
              enforceConflicts: enforceConflicts,
            )
          : await saveTimetableDraft(copy);
      results[day] = ok;

      if (ok) {
        await writeTimetableAudit(
          action: 'copy',
          classId: source.classId,
          dayOfWeek: day,
          version: nextVersion,
          actorUid: actorUid,
          actorName: actorName,
          details:
              'Copied ${source.dayOfWeek} configuration (version ${source.version}) to $day as version $nextVersion ${publishImmediately ? 'and published it' : 'draft'}.',
        );
      }
    }
    return results;
  }

  /// Creates a one-day override for [date] from [version] without changing the
  /// recurring weekly version. Set [publish] to make it live immediately;
  /// otherwise a draft is stored. Returns null when the write is rejected.
  Future<ClassTimetableVersion?> saveTimetableOverride(
    ClassTimetableVersion version, {
    required DateTime date,
    required String actorUid,
    required String actorName,
    bool publish = false,
    bool enforceConflicts = true,
  }) async {
    final cleanDate = DateTime(date.year, date.month, date.day);
    if (cleanDate.weekday == DateTime.friday) return null;
    if (timetableDayForWeekday(cleanDate.weekday) != version.dayOfWeek) {
      return null;
    }

    final now = DateTime.now();
    final nextVersion = _nextVersionNumber(version.classId, version.dayOfWeek);
    final id =
        'tt_${version.classId}_${version.dayOfWeek}_v${nextVersion}_override_${now.millisecondsSinceEpoch}';

    final override = ClassTimetableVersion(
      id: id,
      classId: version.classId,
      dayOfWeek: version.dayOfWeek,
      status: publish ? TimetableStatus.published : TimetableStatus.draft,
      effectiveFrom: cleanDate,
      version: nextVersion,
      breakAfterPeriod: version.breakAfterPeriod,
      breakStartMinute: version.breakStartMinute,
      slots: version.slots,
      createdByUid: actorUid,
      createdByName: actorName,
      publishedAt: publish ? now : null,
      approvedByUid: publish ? actorUid : '',
      approvedByName: publish ? actorName : '',
      createdAt: now,
      overrideDate: cleanDate,
    );

    final ok = publish
        ? await publishTimetable(
            override,
            publisherUid: actorUid,
            publisherName: actorName,
            enforceConflicts: enforceConflicts,
          )
        : await saveTimetableDraft(override);
    if (!ok) return null;

    await writeTimetableAudit(
      action: 'override',
      classId: override.classId,
      dayOfWeek: override.dayOfWeek,
      versionId: override.id,
      version: override.version,
      actorUid: actorUid,
      actorName: actorName,
      details:
          '${publish ? 'Published' : 'Saved draft'} one-day override for ${_dateLabel(cleanDate)}.',
    );

    final substitutes =
        override.slots.where((s) => s.hasSubstitute).length;
    if (substitutes > 0) {
      await writeTimetableAudit(
        action: 'substitute',
        classId: override.classId,
        dayOfWeek: override.dayOfWeek,
        versionId: override.id,
        version: override.version,
        actorUid: actorUid,
        actorName: actorName,
        details:
            'Marked $substitutes substitute teacher${substitutes == 1 ? '' : 's'} for ${_dateLabel(cleanDate)}.',
      );
    }

    return override;
  }

  Future<List<ClassTimetableVersion>> _publishedVersionsForDay(
    String dayOfWeek,
  ) async {
    if (_isLive) {
      try {
        if (firestoreFailureSimulated != null) {
          throw firestoreFailureSimulated!;
        }
        final snapshot = await _firestore
            .collection('timetable_versions')
            .where('day_of_week', isEqualTo: dayOfWeek)
            .where('status', isEqualTo: TimetableStatus.published)
            .get();
        return snapshot.docs
            .map((doc) => ClassTimetableVersion.fromFirestore(doc))
            .toList();
      } catch (e) {
        if (_isNoAppException(e)) {
          return _cachedPublishedVersionsForDay(dayOfWeek);
        }
        rethrow;
      }
    }
    return _cachedPublishedVersionsForDay(dayOfWeek);
  }

  List<ClassTimetableVersion> _cachedPublishedVersionsForDay(String dayOfWeek) {
    final prefs = _safePrefs;
    if (prefs == null) return <ClassTimetableVersion>[];

    final seen = <String>{};
    final versions = <ClassTimetableVersion>[];
    for (final key in prefs.getKeys()) {
      if (!key.startsWith('timetable_history_')) continue;
      final raw = prefs.getStringList(key);
      if (raw == null) continue;
      for (final encoded in raw) {
        try {
          final v = ClassTimetableVersion.fromMap(
            jsonDecode(encoded) as Map<String, dynamic>,
          );
          if (!v.isPublished || v.dayOfWeek != dayOfWeek) continue;
          final identity = v.id.isNotEmpty
              ? v.id
              : '${v.classId}|${v.dayOfWeek}|${v.version}|${v.effectiveFrom.toIso8601String()}|${v.overrideDate?.toIso8601String()}';
          if (!seen.add(identity)) continue;
          versions.add(v);
        } catch (_) {}
      }
    }
    return versions;
  }

  int _nextVersionNumber(String classId, String dayOfWeek) {
    var next = 1;
    for (final v in getCachedVersions(classId, dayOfWeek)) {
      if (v.version >= next) next = v.version + 1;
    }
    return next;
  }

  static String _dateLabel(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  // ===============================================================
  // Reactive Streams
  // ===============================================================

  /// Stream of the active timetable version for [date] (defaults to today).
  /// Resolves the published version with the greatest effective date on or before [date].
  Stream<ClassTimetableVersion?> getActiveTimetableStream(
    String classId,
    String dayOfWeek, [
    DateTime? date,
  ]) {
    final targetDate = date ?? DateTime.now();

    if (!_isLive) {
      final active = getCachedActiveVersion(classId, dayOfWeek, targetDate);
      return Stream.value(active);
    }

    return _firestore
        .collection('timetable_versions')
        .where('class_id', isEqualTo: classId)
        .where('day_of_week', isEqualTo: dayOfWeek)
        .where('status', isEqualTo: TimetableStatus.published)
        .snapshots()
        .map((snapshot) {
          final versions = snapshot.docs
              .map((doc) => ClassTimetableVersion.fromFirestore(doc))
              .toList();
          if (versions.isNotEmpty) {
            final active = ClassTimetableVersion.activeForDate(versions, targetDate);
            if (active != null) {
              cacheActiveVersion(classId, dayOfWeek, active);
              return active;
            }
          }
          return getCachedActiveVersion(classId, dayOfWeek, targetDate);
        })
        .handleError((error) {
          debugPrint('getActiveTimetableStream error: $error, falling back to cache');
          return getCachedActiveVersion(classId, dayOfWeek, targetDate);
        });
  }

  /// Stream of all versions (drafts, submitted, published, rejected) for a day schedule.
  Stream<List<ClassTimetableVersion>> getTimetableHistoryStream(String classId, String dayOfWeek) {
    if (!_isLive) {
      return Stream.value(getCachedVersions(classId, dayOfWeek));
    }

    return _firestore
        .collection('timetable_versions')
        .where('class_id', isEqualTo: classId)
        .where('day_of_week', isEqualTo: dayOfWeek)
        .snapshots()
        .map((snapshot) {
          final versions = snapshot.docs
              .map((doc) => ClassTimetableVersion.fromFirestore(doc))
              .toList()
            ..sort((a, b) => b.version.compareTo(a.version));
          cacheVersions(classId, dayOfWeek, versions);
          return versions;
        })
        .handleError((error) {
          debugPrint('getTimetableHistoryStream error: $error, falling back to cache');
          return getCachedVersions(classId, dayOfWeek);
        });
  }

  // ===============================================================
  // Append-Only Timetable Audit Log
  // ===============================================================

  /// Writes an append-only audit entry. Rules strictly prohibit update and delete.
  Future<bool> writeTimetableAudit({
    required String action,
    required String classId,
    required String dayOfWeek,
    required String actorUid,
    String versionId = '',
    int version = 1,
    String actorName = '',
    String details = '',
  }) async {
    final now = DateTime.now();
    final audit = <String, dynamic>{
      'action': action,
      'class_id': classId,
      'day_of_week': dayOfWeek,
      'version_id': versionId,
      'version': version,
      'actor_uid': actorUid,
      'actor_name': actorName,
      'details': details,
      'timestamp': Timestamp.fromDate(now),
    };

    if (_isLive) {
      try {
        if (firestoreFailureSimulated != null) {
          throw firestoreFailureSimulated!;
        }
        await _firestore.collection('timetable_audit').add(audit);
      } catch (e) {
        if (!_isNoAppException(e)) {
          debugPrint('Firestore writeTimetableAudit failure: $e');
        }
      }
    }

    audit['timestamp'] = now.toIso8601String();
    await cacheAudit(classId, audit);
    return true;
  }

  Stream<List<Map<String, dynamic>>> getTimetableAuditStream(String classId) {
    if (!_isLive) {
      return Stream.value(getCachedAudits(classId));
    }

    return _firestore
        .collection('timetable_audit')
        .where('class_id', isEqualTo: classId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
          list.sort((a, b) {
            final ta = a['timestamp'];
            final tb = b['timestamp'];
            if (ta is Timestamp && tb is Timestamp) {
              return tb.compareTo(ta);
            }
            return 0;
          });
          return list;
        })
        .handleError((error) {
          debugPrint('getTimetableAuditStream error: $error, falling back to cache');
          return getCachedAudits(classId);
        });
  }

  // ===============================================================
  // Internal Helpers
  // ===============================================================

  void _updateLocalCache(ClassTimetableVersion version) {
    final cached = List<ClassTimetableVersion>.from(getCachedVersions(version.classId, version.dayOfWeek));
    final idx = cached.indexWhere((v) => v.id == version.id || v.version == version.version);
    if (idx != -1) {
      cached[idx] = version;
    } else {
      cached.insert(0, version);
    }
    cached.sort((a, b) => b.version.compareTo(a.version));
    cacheVersions(version.classId, version.dayOfWeek, cached);
  }
}
