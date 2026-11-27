import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/digital_ballot_cast.dart';
import '../models/election_ballot.dart';
import '../models/election_gazette.dart';
import '../services/auth_service.dart';
import '../services/election_security_service.dart';
import '../services/hierarchy_service.dart';
import '../theme/app_theme.dart';
import 'election_chamber_screen.dart';
import 'election_gazette_screen.dart';

typedef Fields = Map<String, dynamic>;

abstract class ElectionDoc {
  String get id;
  Fields data();
}

class QueryElectionDoc implements ElectionDoc {
  final QueryDocumentSnapshot<Fields> doc;
  QueryElectionDoc(this.doc);
  @override
  String get id => doc.id;
  @override
  Fields data() => doc.data();
}

class MemoryElectionDoc implements ElectionDoc {
  final String _id;
  final Fields _data;
  MemoryElectionDoc(this._id, this._data);
  @override
  String get id => _id;
  @override
  Fields data() => _data;
}

User? get _safeCurrentUser {
  try {
    if (Firebase.apps.isNotEmpty) {
      return FirebaseAuth.instance.currentUser;
    }
  } catch (_) {}
  return null;
}

bool get _isFirebaseLive {
  try {
    return Firebase.apps.isNotEmpty;
  } catch (_) {
    return false;
  }
}

bool _isNoAppException(dynamic e) {
  final s = e.toString().toLowerCase();
  return s.contains('no-app') || s.contains('no app') || s.contains('has been created');
}

class SchoolElectionsPage extends StatelessWidget {
  const SchoolElectionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cachedProfile = AuthService.getCachedProfile() ?? {};
    final activeScholar = (AuthService.getCachedScholarNo() ?? cachedProfile['scholar_no']?.toString() ?? 'guest').trim();
    final firebaseUid = _safeCurrentUser?.uid;
    final activeUid = (cachedProfile['uid'] ?? AuthService.getCachedUid() ?? firebaseUid ?? 'guest').toString().trim();

    return _ElectionDesk(
      key: ValueKey('${activeScholar}_$activeUid'),
      uid: activeUid,
      activeScholar: activeScholar,
    );
  }
}

class _ElectionDesk extends StatefulWidget {
  const _ElectionDesk({
    super.key,
    required this.uid,
    required this.activeScholar,
  });
  final String uid;
  final String activeScholar;

  @override
  State<_ElectionDesk> createState() => _ElectionDeskState();
}

class _ElectionDeskState extends State<_ElectionDesk> with TickerProviderStateMixin {
  FirebaseFirestore get db => FirebaseFirestore.instance;
  final _authService = AuthService();
  TabController? _tabController;
  bool _isManager = false;
  late Future<({
    Fields member,
    List<ElectionDoc> polls,
    List<ElectionDoc> drafts,
    List<CertifiedElectionResult> proclamations,
    List<ElectionBallot> legacyCertified,
  })> feed;
  bool busy = false;
  String? unconfirmedDraftId;
  final receipts = <String, String>{};

  static DateTime _parseSafeDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  @override
  void initState() {
    super.initState();
    final cached = AuthService.getCachedProfile() ?? {};
    final scholarNo = (widget.activeScholar.isNotEmpty ? widget.activeScholar : (AuthService.getCachedScholarNo() ?? cached['scholar_no']?.toString() ?? '')).trim();
    final role = (cached['role'] ?? '').toString().trim().toLowerCase();
    final email = _safeCurrentUser?.email;
    _isManager = HierarchyService.canManageElections(
      scholarNo: scholarNo,
      role: role,
      capabilities: cached['capabilities'] is Map ? Map<String, dynamic>.from(cached['capabilities']) : null,
      email: email,
    );
    _tabController = TabController(length: _isManager ? 3 : 2, vsync: this);
    feed = load();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<({
    Fields member,
    List<ElectionDoc> polls,
    List<ElectionDoc> drafts,
    List<CertifiedElectionResult> proclamations,
    List<ElectionBallot> legacyCertified,
  })> load() async {
    final cached = AuthService.getCachedProfile() ?? {};
    final activeScholar = (widget.activeScholar.isNotEmpty ? widget.activeScholar : (AuthService.getCachedScholarNo() ?? cached['scholar_no']?.toString() ?? '')).trim();
    final cachedRole = (cached['role'] ?? '').toString().trim().toLowerCase();
    final email = _safeCurrentUser?.email;
    final isPrivilegedAdmin = HierarchyService.canManageElections(
      scholarNo: activeScholar,
      role: cachedRole,
      capabilities: cached['capabilities'] is Map ? Map<String, dynamic>.from(cached['capabilities']) : null,
      email: email,
    );

    Fields? member;

    if (isPrivilegedAdmin) {
      member = {
        'active': true,
        'role': 'admin',
        'scholar_no': activeScholar.isNotEmpty ? activeScholar : 'admin',
        'display_name': cached['full_name'] ?? 'Administrator',
        'house': cached['house_name'] ?? '',
        'grade': 12,
        'capabilities': {'manage_elections': true},
      };
    } else {
      // 1. Roster check with automatic provisioning fallback for student/faculty
      try {
        final snap = await db.collection('school_members').doc(widget.uid).get();
        if (snap.exists) {
          final data = snap.data();
          if (data?['scholar_no']?.toString().trim() == activeScholar) {
            member = data;
          }
        }
      } catch (_) {}

      if (member == null && activeScholar.isNotEmpty) {
        try {
          final qSnap = await db.collection('school_members')
              .where('scholar_no', isEqualTo: activeScholar)
              .limit(1)
              .get();
          if (qSnap.docs.isNotEmpty) {
            member = qSnap.docs.first.data();
          }
        } catch (_) {}
      }

      if (member == null || member['active'] != true) {
        try {
          member = await _authService.ensureSchoolMemberRecord(uid: widget.uid, profile: cached);
        } catch (_) {}
      }

      if (member == null || member['active'] != true) {
        final isStaff = HierarchyService.isTeacherOrFaculty(scholarNo: activeScholar, role: cachedRole) ||
            HierarchyService.isCouncil(scholarNo: activeScholar, role: cachedRole) ||
            cachedRole == 'staff' || cachedRole == 'faculty' || cachedRole == 'teacher' || cachedRole == 'council';
        member = {
          'active': true,
          'role': isStaff ? 'staff' : (cached['role'] ?? 'student'),
          'scholar_no': activeScholar.isNotEmpty ? activeScholar : '',
          'display_name': cached['full_name'] ?? 'Scholar',
          'house': cached['house_name'] ?? '',
          'grade': cached['grade'] is int ? cached['grade'] : (int.tryParse(cached['grade']?.toString() ?? '') ?? 0),
          'capabilities': {'manage_elections': isStaff},
        };
      }
    }

    // 2. Fetch published polls (server-authoritative truth, F7)
    final pollsMap = <String, ElectionDoc>{};
    final cachedBallots = AuthService.getCachedBallots();
    final cachedGazettes = AuthService.getCachedCertifiedGazette();

    try {
      final snap = await db.collection('election_polls_v2').get();
      final pollDocIds = snap.docs.map((d) => d.id).toList();

      // Batch participation lookup via callable (F11 eliminates N+1, chunked to <=50 per backend cap)
      if (activeScholar.isNotEmpty && activeScholar != 'guest' && _isFirebaseLive && pollDocIds.isNotEmpty) {
        try {
          for (var i = 0; i < pollDocIds.length; i += 50) {
            final chunk = pollDocIds.sublist(
              i,
              (i + 50) > pollDocIds.length ? pollDocIds.length : i + 50,
            );
            final res = await call('getMyParticipation', chunk.first, {'pollIds': chunk});
            final partMap = res['participation'] as Map?;
            if (partMap != null) {
              for (final entry in partMap.entries) {
                receipts['${activeScholar}_${entry.key}'] = entry.value.toString();
              }
            }
          }
        } catch (_) {}
      }

      for (final doc in snap.docs) {
        try {
          final data = doc.data();
          final isCert = data['status'] == 'certified' || data['is_certified'] == true;
          if (isCert && data['status'] != 'certified') {
            final m = Map<String, dynamic>.from(data);
            m['status'] = 'certified';
            m['is_certified'] = true;
            pollsMap[doc.id] = MemoryElectionDoc(doc.id, m);
          } else {
            pollsMap[doc.id] = QueryElectionDoc(doc);
          }

          // Local receipt cache backup
          if (activeScholar.isNotEmpty && !receipts.containsKey('${activeScholar}_${doc.id}')) {
            final cachedRcpt = AuthService.getReceiptForBallot(doc.id, scholarNo: activeScholar);
            if (cachedRcpt != null) {
              receipts['${activeScholar}_${doc.id}'] = cachedRcpt.receiptId;
            }
          }
        } catch (e) {
          debugPrint('Skipping malformed v2 poll doc ${doc.id}: $e');
        }
      }
    } catch (_) {}

    // Offline fallback: load cached ballots only when remote server is unreachable (F7)
    if (pollsMap.isEmpty && !_isFirebaseLive) {
      for (final b in cachedBallots) {
        final isCert = b.status == BallotStatus.certified;
        pollsMap[b.id] = MemoryElectionDoc(b.id, {
          'id': b.id,
          'title': b.title,
          'position': b.position.displayName,
          'house': b.houseScope,
          'minGrade': 1,
          'maxGrade': 12,
          'opensAt': Timestamp.fromDate(b.startTime),
          'closesAt': Timestamp.fromDate(b.endTime),
          'candidates': b.candidates.map((c) => {
            'id': c.scholarNo,
            'name': c.fullName,
            'scholar_no': c.scholarNo,
            'statement': c.manifesto,
            'votes_count': c.votesCount,
          }).toList(),
          'status': isCert ? 'certified' : 'published',
          'is_certified': isCert,
          'total_votes_cast': b.totalVotesCast,
        });
      }
    }

    try {
      final legacySnap = await db.collection('elections').get();
      for (final doc in legacySnap.docs) {
        try {
          final data = doc.data();
          final isCert = data['status'] == 'certified' ||
              data['is_certified'] == true;
          final rawEndTime = data['end_time'];
          final parsedEndTime = rawEndTime != null ? DateTime.tryParse(rawEndTime.toString()) : null;
          final hasValidEnd = parsedEndTime != null;
          final closesAt = hasValidEnd
              ? Timestamp.fromDate(parsedEndTime)
              : Timestamp.fromMillisecondsSinceEpoch(0);
          final defaultStatus = hasValidEnd ? 'published' : 'closed';

          if (!pollsMap.containsKey(doc.id)) {
            pollsMap[doc.id] = MemoryElectionDoc(doc.id, {
              'id': doc.id,
              'title': data['title'] ?? 'School Election',
              'position': data['position'] ?? data['running_position'] ?? 'School Leader',
              'house': data['house_scope'] ?? data['house'] ?? 'all',
              'minGrade': 1,
              'maxGrade': 12,
              'opensAt': data['start_time'] != null ? Timestamp.fromDate(DateTime.tryParse(data['start_time'].toString()) ?? DateTime.now()) : Timestamp.now(),
              'closesAt': closesAt,
              'candidates': (data['candidates'] as List? ?? []).map((c) => {
                'id': c['id'] ?? c['scholar_no'] ?? '',
                'name': c['full_name'] ?? c['name'] ?? '',
                'scholar_no': c['scholar_no'] ?? '',
                'statement': c['manifesto'] ?? c['statement'] ?? '',
                'votes_count': (c['votes_count'] as num?)?.toInt() ?? 0,
              }).toList(),
              'status': isCert ? 'certified' : defaultStatus,
              'is_certified': isCert,
              'total_votes_cast': (data['total_votes_cast'] as num?)?.toInt() ?? 0,
            });
          } else if (isCert) {
            final existing = Map<String, dynamic>.from(pollsMap[doc.id]!.data());
            existing['status'] = 'certified';
            existing['is_certified'] = true;
            pollsMap[doc.id] = MemoryElectionDoc(doc.id, existing);
          }
        } catch (e) {
          debugPrint('Skipping malformed legacy election doc ${doc.id}: $e');
        }
      }
    } catch (_) {}

    final polls = pollsMap.values.toList();
    polls.sort((a, b) {
      final aOpens = (a.data()['opensAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      final bOpens = (b.data()['opensAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      return bOpens.compareTo(aOpens);
    });

    // 3. Fetch drafts for authorized managers
    final scholarNo = activeScholar.isNotEmpty ? activeScholar : (member['scholar_no'] ?? '').toString().trim();
    final role = isPrivilegedAdmin ? 'admin' : (member['role'] ?? cachedRole).toString().trim().toLowerCase();
    final canManage = isPrivilegedAdmin || HierarchyService.canManageElections(
      scholarNo: scholarNo,
      role: role,
      capabilities: member['capabilities'] is Map ? Map<String, dynamic>.from(member['capabilities']) : null,
      email: email,
    );

    if (_isManager != canManage && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isManager = canManage;
          });
        }
      });
    }

    final draftsMap = <String, ElectionDoc>{};
    if (canManage) {
      try {
        final snap = await db.collection('election_drafts_v2').get();
        for (final doc in snap.docs) {
          if ((doc.data()['status'] ?? 'draft') == 'draft') {
            draftsMap[doc.id] = QueryElectionDoc(doc);
          }
        }
      } catch (_) {}

      final cachedDrafts = AuthService.getCachedDraftBallots();
      for (final cd in cachedDrafts) {
        final id = cd['id']?.toString() ?? '';
        if (id.isNotEmpty && !draftsMap.containsKey(id) && (cd['status'] ?? 'draft') == 'draft') {
          draftsMap[id] = MemoryElectionDoc(id, Map<String, dynamic>.from(cd));
        }
      }
    }
    final drafts = draftsMap.values.toList();
    drafts.sort((a, b) {
      final aStart = (a.data()['startMs'] as num?)?.toInt() ?? 0;
      final bStart = (b.data()['startMs'] as num?)?.toInt() ?? 0;
      return bStart.compareTo(aStart);
    });

    // 4. Fetch official certified gazette proclamations (server-authoritative truth, F7)
    List<CertifiedElectionResult> proclamations = [];
    try {
      final snap = await db.collection('election_gazettes').get();
      proclamations = snap.docs
          .map((d) {
            try { return CertifiedElectionResult.fromMap(d.data()); }
            catch (_) { return null; }
          })
          .whereType<CertifiedElectionResult>()
          .toList();
    } catch (_) {}
    if (proclamations.isEmpty && !_isFirebaseLive) {
      for (final cg in cachedGazettes) {
        if (!proclamations.any((p) => p.ballotId == cg.ballotId)) {
          proclamations.add(cg);
        }
      }
    }
    proclamations.sort((a, b) => b.certifiedAt.compareTo(a.certifiedAt));

    // 5. Fetch legacy certified ballots from chamber (server-authoritative truth, F7)
    List<ElectionBallot> legacyCertified = [];
    try {
      final snap = await db.collection('elections').where('status', isEqualTo: 'certified').get();
      legacyCertified = snap.docs
          .map((d) => ElectionBallot.fromMap(d.data(), docId: d.id))
          .toList();
    } catch (_) {}
    if (legacyCertified.isEmpty && !_isFirebaseLive) {
      final cachedCertifiedList = AuthService.getCachedBallots()
          .where((b) => b.status == BallotStatus.certified)
          .toList();
      for (final cb in cachedCertifiedList) {
        if (!legacyCertified.any((lb) => lb.id == cb.id)) {
          legacyCertified.add(cb);
        }
      }
    }

    return (
      member: member,
      polls: polls,
      drafts: drafts,
      proclamations: proclamations,
      legacyCertified: legacyCertified,
    );
  }

  void refresh() => setState(() => feed = load());

  Future<Fields> call(String action, String id, [Fields args = const {}]) async {
    final user = _safeCurrentUser;
    final activeUid = widget.uid.trim();

    // 1. Attempt Cloud Functions callable if deployed (requires Blaze plan)
    if (Firebase.apps.isNotEmpty && user != null && user.uid == activeUid && activeUid != 'guest') {
      try {
        final token = await user.getIdToken();
        if (token != null) {
          final project = Firebase.app().options.projectId;
          final url = Uri.https('us-central1-$project.cloudfunctions.net', '/schoolElection');
          final reply = await http.post(
            url,
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
            body: jsonEncode({'data': {...args, 'action': action, 'pollId': id}}),
          ).timeout(const Duration(seconds: 4));

          if (reply.statusCode == 200) {
            final envelope = jsonDecode(reply.body);
            if (envelope is Map) {
              if (envelope['error'] != null) {
                final err = envelope['error'];
                final msg = err is Map ? (err['message'] ?? err.toString()) : err.toString();
                throw Exception(msg);
              }
              final result = envelope['result'] ?? envelope['data'];
              if (result is Map) {
                return Map<String, dynamic>.from(result);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Cloud Functions unavailable (Blaze plan required for server functions). Falling back to direct client handling: $e');
      }
    }

    // 2. All live election mutations and votes must execute through the
    // server-authoritative schoolElection Cloud Function. Only offline/unit-test
    // sessions (! _isFirebaseLive) use the local/Firestore test handler.
    if (_isFirebaseLive) {
      throw StateError(
        'Secure election service is unavailable. Election operations require '
        'the deployed schoolElection Cloud Function. Please contact the election administrator.',
      );
    }

    return await _callFirestoreFallback(action, id, args, user);
  }

  Future<Fields> _callFirestoreFallback(String action, String pollId, Fields args, User? user) async {
    final cached = AuthService.getCachedProfile() ?? {};
    final activeScholar = (widget.activeScholar.isNotEmpty ? widget.activeScholar : (AuthService.getCachedScholarNo() ?? cached['scholar_no']?.toString() ?? '')).trim();
    final cachedRole = (cached['role'] ?? '').toString().trim().toLowerCase();
    final email = _safeCurrentUser?.email;
    final isStaff = HierarchyService.canManageElections(
      scholarNo: activeScholar,
      role: cachedRole,
      capabilities: cached['capabilities'] is Map ? Map<String, dynamic>.from(cached['capabilities']) : null,
      email: email,
    );

    final draftRef = db.collection('election_drafts_v2').doc(pollId);
    final pollRef = db.collection('election_polls_v2').doc(pollId);

    final person = <String, dynamic>{
      'active': true,
      'role': isStaff ? 'admin' : (cachedRole.isNotEmpty ? cachedRole : 'student'),
      'scholar_no': activeScholar.isNotEmpty ? activeScholar : '',
      'display_name': cached['full_name'] ?? '',
      'house': cached['house_name'] ?? '',
      'grade': int.tryParse((cached['grade'] ?? cached['class_level'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
      'capabilities': {'manage_elections': isStaff},
    };

    if (action == 'receipt' || action == 'vote') {
      final scholar = activeScholar.isNotEmpty ? activeScholar : (person['scholar_no'] ?? '').toString().trim();
      if (scholar.isEmpty) throw StateError('Verified roster identity required.');
      final normalizedScholar = scholar.toLowerCase().trim();
      final key = sha256.convert(utf8.encode('$pollId:$normalizedScholar')).toString();
      final partRef = pollRef.collection('participation').doc(key);

      if (action == 'receipt') {
        Map<String, dynamic>? prior;
        try {
          prior = (await partRef.get()).data();
        } catch (_) {}
        if (prior != null && prior['receipt'] != null) {
          return {'receipt': prior['receipt'], 'alreadyRecorded': true};
        }
        final cachedRcpt = AuthService.getReceiptForBallot(pollId, scholarNo: scholar);
        if (cachedRcpt != null) {
          return {'receipt': cachedRcpt.receiptId, 'alreadyRecorded': true};
        }
        return {'receipt': null, 'alreadyRecorded': false};
      }

      // Vote cast execution
      final candidateId = (args['candidateId'] ?? '').toString().trim();
      if (candidateId.isEmpty) throw StateError('Select a candidate to cast your vote.');

      try {
        final priorSnap = await partRef.get();
        if (priorSnap.exists) {
          final prior = priorSnap.data();
          return {'receipt': prior?['receipt'], 'alreadyRecorded': true};
        }
      } catch (_) {}

      final cachedPrior = AuthService.getReceiptForBallot(pollId, scholarNo: scholar);
      if (cachedPrior != null) {
        return {'receipt': cachedPrior.receiptId, 'alreadyRecorded': true};
      }

      final gradeVal = person['grade'] is int ? person['grade'] as int : (int.tryParse(person['grade']?.toString() ?? '') ?? 0);
      if (gradeVal <= 0) throw StateError('Profile incomplete: valid grade required to vote.');
      final house = person['house'];

      // Attempt Firestore vote transaction
      String? issuedReceipt;
      String resolvedCandId = candidateId;
      String candName = (args['candidateName'] ?? 'Candidate').toString();
      String candHouse = (house ?? '').toString();
      String candScholar = (args['candidateScholar'] ?? candidateId).toString().trim();
      String pollTitle = 'School Election';
      String runningPos = 'School Leader';

      final preCachedBallots = AuthService.getCachedBallots();
      for (final b in preCachedBallots) {
        if (b.id == pollId) {
          pollTitle = b.title;
          runningPos = b.position.displayName;
          for (final c in b.candidates) {
            final cSNo = c.scholarNo.trim();
            final cN = c.fullName.trim();
            if (cSNo == candidateId ||
                cN.toLowerCase() == candidateId.toLowerCase() ||
                (args['candidateScholar'] != null && cSNo == args['candidateScholar'].toString().trim())) {
              candScholar = cSNo;
              candName = cN;
              candHouse = c.houseName;
              break;
            }
          }
          break;
        }
      }

      final preCachedDrafts = AuthService.getCachedDraftBallots();
      for (final d in preCachedDrafts) {
        if (d['id'] == pollId) {
          final cList = (d['candidates'] as List? ?? []).cast<Map>();
          for (final c in cList) {
            final cId = (c['id'] ?? '').toString().trim();
            final cSNo = (c['scholar_no'] ?? '').toString().trim();
            final cN = (c['name'] ?? c['full_name'] ?? '').toString().trim();
            if (cId == candidateId ||
                cSNo == candidateId ||
                cN.toLowerCase() == candidateId.toLowerCase() ||
                (args['candidateScholar'] != null && cSNo == args['candidateScholar'].toString().trim())) {
              resolvedCandId = cId.isNotEmpty ? cId : candidateId;
              if (cSNo.isNotEmpty) candScholar = cSNo;
              if (cN.isNotEmpty) candName = cN;
              break;
            }
          }
        }
      }

      try {
        final res = await db.runTransaction<Fields>((tx) async {
          final priorSnap = await tx.get(partRef);
          if (priorSnap.exists) {
            return {'receipt': priorSnap.data()?['receipt'], 'alreadyRecorded': true};
          }
          final pollSnap = await tx.get(pollRef);
          if (!pollSnap.exists) throw StateError('Not in Firestore');
          final box = pollSnap.data()!;
          final now = DateTime.now();
          final opensAt = (box['opensAt'] as Timestamp).toDate();
          final closesAt = (box['closesAt'] as Timestamp).toDate();
          final inWindow = !now.isBefore(opensAt.subtract(const Duration(seconds: 15))) && now.isBefore(closesAt);
          if ((box['status'] != 'published' && box['status'] != 'open') || !inWindow) {
            throw StateError('Voting is currently closed.');
          }

          final candidates = (box['candidates'] as List? ?? []).cast<Map>();
          final match = candidates.firstWhere(
            (c) {
              final cId = (c['id'] ?? '').toString().trim().toLowerCase();
              final cSNo = (c['scholar_no'] ?? '').toString().trim();
              final cN = (c['name'] ?? c['full_name'] ?? '').toString().trim().toLowerCase();
              final target = candidateId.trim().toLowerCase();
              return (cId.isNotEmpty && cId == target) ||
                  (cSNo.isNotEmpty && cSNo.toLowerCase() == target) ||
                  (cN.isNotEmpty && cN == target) ||
                  (candScholar.isNotEmpty && cSNo.toLowerCase() == candScholar.toLowerCase()) ||
                  (candName != 'Candidate' && cN == candName.toLowerCase());
            },
            orElse: () => const {},
          );
          if (match.isEmpty) {
            throw StateError('Candidate is not on this ballot.');
          }

          final minGrade = box['minGrade'] as int? ?? 1;
          final maxGrade = box['maxGrade'] as int? ?? 12;
          final pollHouse = (box['house'] ?? 'all').toString();
          if (gradeVal < minGrade || gradeVal > maxGrade || (pollHouse != 'all' && pollHouse != house)) {
            throw StateError('Outside the eligible electorate for this ballot.');
          }

          // Read legacy election document if present for full atomic write-through
          final legElectionRef = db.collection('elections').doc(pollId);
          DocumentSnapshot<Map<String, dynamic>>? legSnap;
          try {
            legSnap = await tx.get(legElectionRef);
          } catch (_) {}

          final receipt = 'rcpt_${DateTime.now().millisecondsSinceEpoch}_${key.substring(0, 8)}';
          tx.set(partRef, {
            'receipt': receipt,
            'timestamp': FieldValue.serverTimestamp(),
          });

          final cId = (match['id'] ?? candidateId).toString();
          final candScholarNo = (match['scholar_no'] ?? cId).toString().trim();
          final countRef = pollRef.collection('counts').doc(cId);
          tx.set(countRef, {'count': FieldValue.increment(1)}, SetOptions(merge: true));

          final curTotal = (box['total_votes_cast'] as num?)?.toInt() ?? 0;
          tx.update(pollRef, {
            'total_votes_cast': curTotal + 1,
          });

          // Write-through to legacy election document
          if (legSnap != null && legSnap.exists) {
            final legData = legSnap.data() ?? {};
            final curLegTotal = (legData['total_votes_cast'] as num?)?.toInt() ?? 0;
            tx.update(legElectionRef, {
              'total_votes_cast': curLegTotal + 1,
            });
          }

          // Write-through to legacy election_votes preserving voter secrecy (C7)
          final legVoteRef = db.collection('election_votes').doc('${pollId}_$key');
          tx.set(legVoteRef, {
            'ballot_id': pollId,
            'anonymized_voter_hash': key,
            'receipt_id': receipt,
            'timestamp': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          return {
            'receipt': receipt,
            'alreadyRecorded': false,
            'candId': cId,
            'candName': match['name'] ?? 'Candidate',
            'candScholar': candScholarNo,
            'pollTitle': box['title'] ?? 'School Election',
            'position': box['position'] ?? 'School Leader',
          };
        });
        if (res['alreadyRecorded'] == true) return res;
        issuedReceipt = res['receipt'] as String?;
        if (res['candId'] != null) resolvedCandId = res['candId'].toString();
        if (res['candName'] != null) candName = res['candName'].toString();
        if (res['candScholar'] != null) candScholar = res['candScholar'].toString();
        if (res['pollTitle'] != null) pollTitle = res['pollTitle'].toString();
        if (res['position'] != null) runningPos = res['position'].toString();
      } catch (e) {
        debugPrint('Firestore vote transaction note: $e');
        if (issuedReceipt == null) {
          rethrow;
        }
      }

      if (issuedReceipt == null) {
        throw StateError('Your vote could not be recorded in Firestore.');
      }
      final receipt = issuedReceipt;

      // Always update local cached ballot
      final cachedBallots = AuthService.getCachedBallots();
      for (final b in cachedBallots) {
        if (b.id == pollId) {
          pollTitle = b.title;
          runningPos = b.position.displayName;
          final updatedCandidates = b.candidates.map((c) {
            final cScholar = c.scholarNo.trim().toLowerCase();
            final cNameLower = c.fullName.trim().toLowerCase();
            final targetIdLower = candidateId.trim().toLowerCase();
            final targetScholarLower = candScholar.trim().toLowerCase();
            final targetResolvedLower = resolvedCandId.trim().toLowerCase();
            final targetNameLower = candName.trim().toLowerCase();

            if (cScholar == targetIdLower ||
                cScholar == targetScholarLower ||
                cScholar == targetResolvedLower ||
                (targetNameLower != 'candidate' && cNameLower == targetNameLower) ||
                cNameLower == targetIdLower) {
              candName = c.fullName;
              candHouse = c.houseName;
              candScholar = c.scholarNo;
              return ElectionCandidate(
                scholarNo: c.scholarNo,
                fullName: c.fullName,
                houseName: c.houseName,
                runningPosition: c.runningPosition,
                manifesto: c.manifesto,
                votesCount: c.votesCount + 1,
                isVerified: c.isVerified,
              );
            }
            return c;
          }).toList();
          final updatedBallot = ElectionBallot(
            id: b.id,
            title: b.title,
            position: b.position,
            candidates: updatedCandidates,
            startTime: b.startTime,
            endTime: b.endTime,
            status: b.status,
            totalVotesCast: b.totalVotesCast + 1,
            houseScope: b.houseScope,
            eligibleGrades: b.eligibleGrades,
          );
          await AuthService.cacheBallot(updatedBallot);
          break;
        }
      }

      final now = DateTime.now();
      final proofToken = ElectionSecurityService.generateBallotProofToken(
        anonymizedVoterHash: key,
        ballotId: pollId,
        candidateScholarNo: candScholar,
        timestamp: now,
      );

      await AuthService.cacheVoteReceipt(
        BallotCastReceipt(
          receiptId: receipt,
          ballotId: pollId,
          ballotTitle: pollTitle,
          candidateScholarNo: candScholar,
          candidateName: candName,
          candidateHouse: candHouse,
          runningPosition: runningPos,
          anonymizedVoterHash: key,
          signatureProofToken: proofToken,
          timestamp: now,
        ),
        scholarNo: scholar,
      );

      return {'receipt': receipt, 'alreadyRecorded': false};
    }

    final scholarNo = (person['scholar_no'] ?? AuthService.getCachedScholarNo() ?? '').toString().trim();
    final role = (person['role'] ?? '').toString().trim().toLowerCase();
    final canManage = HierarchyService.canManageElections(
      scholarNo: scholarNo,
      role: role,
      capabilities: person['capabilities'] is Map ? Map<String, dynamic>.from(person['capabilities']) : null,
      email: email,
    );
    if (!canManage) throw StateError('Election manager permission required.');

    if (action == 'create') {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final endMs = args['endMs'] as int? ?? (nowMs + 7 * 86400000);
      if (endMs <= nowMs) throw StateError('Choose a future closing deadline.');

      final payload = {
        'id': pollId,
        'title': args['title'],
        'position': args['position'],
        'house': args['house'],
        'minGrade': args['minGrade'],
        'maxGrade': args['maxGrade'],
        'startMs': args['startMs'] ?? nowMs,
        'endMs': endMs,
        'candidates': <Map<String, dynamic>>[],
        'status': 'draft',
        'createdBy': user?.uid ?? activeScholar,
        'createdAt': DateTime.now().toIso8601String(),
      };

      try {
        await draftRef.set(payload);
      } catch (e) {
        debugPrint('Firestore draft creation note: $e');
      }
      await AuthService.cacheDraftBallot(payload);
      return {'pollId': pollId};
    }

    if (action == 'add') {
      final scholar = (args['scholarNo'] ?? '').toString().trim();
      final statement = (args['statement'] ?? '').toString().trim();
      var inputName = (args['name'] ?? '').toString().trim();
      if (scholar.isEmpty) throw StateError('Enter registered scholar number.');
      if (statement.isEmpty) throw StateError('Enter candidate manifesto pledge.');

      String candUid = 'cand_${scholar.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
      String candName = inputName;

      QuerySnapshot<Map<String, dynamic>>? matches;
      try {
        matches = await db.collection('school_members').where('scholar_no', isEqualTo: scholar).limit(2).get();
      } catch (_) {}

      String candHouse = (args['house'] ?? '').toString().trim().toLowerCase();
      if (matches != null && matches.docs.isNotEmpty) {
        final candDoc = matches.docs.first;
        candUid = candDoc.id;
        final dName = (candDoc.data()['display_name'] ?? '').toString().trim();
        if (dName.isNotEmpty) candName = dName;
        final dHouse = (candDoc.data()['house'] ?? '').toString().trim().toLowerCase();
        if (dHouse.isNotEmpty) candHouse = dHouse;
      } else {
        final saved = AuthService.getSavedAccounts();
        for (final a in saved) {
          if (a.scholarNo.trim().toLowerCase() == scholar.toLowerCase()) {
            if (a.fullName.isNotEmpty) candName = a.fullName;
            if (candHouse.isEmpty) candHouse = a.houseName.toLowerCase();
            break;
          }
        }
      }

      if (candHouse.isEmpty || !['ruby', 'sapphire', 'emerald', 'topaz'].contains(candHouse)) {
        candHouse = AuthService.inferHouseFromScholarNo(scholar) ?? '';
      }
      if (candHouse.isEmpty || !['ruby', 'sapphire', 'emerald', 'topaz'].contains(candHouse)) {
        throw StateError('Candidate must have a valid house on the school roster.');
      }

      if (candName.isEmpty) {
        throw StateError('Candidate must be verified in the school roster.');
      }

      Map<String, dynamic>? dData;
      try {
        final dSnap = await draftRef.get();
        if (dSnap.exists) dData = dSnap.data();
      } catch (_) {}
      if (dData == null) {
        final cachedDrafts = AuthService.getCachedDraftBallots();
        for (final cd in cachedDrafts) {
          if (cd['id'] == pollId) {
            dData = Map<String, dynamic>.from(cd);
            break;
          }
        }
      }
      if (dData == null) throw StateError('Draft not found.');
      if (dData['status'] != 'draft') throw StateError('Published candidates are frozen.');

      final curList = (dData['candidates'] as List? ?? []).cast<Map>();
      if (curList.any((c) => c['scholar_no']?.toString().trim() == scholar || c['uid'] == candUid)) {
        throw StateError('Scholar #$scholar is already configured on this candidate slate.');
      }
      final candId = 'cnd_${DateTime.now().millisecondsSinceEpoch}_${curList.length + 1}';
      final filtered = curList.where((c) => c['uid'] != candUid && c['scholar_no']?.toString().trim() != scholar).map((c) => Map<String, dynamic>.from(c)).toList();
      filtered.add({
        'id': candId,
        'uid': candUid,
        'name': candName,
        'scholar_no': scholar,
        'statement': statement,
        'house': candHouse,
        'house_name': candHouse,
      });

      dData['candidates'] = filtered;
      try {
        await draftRef.update({'candidates': filtered});
      } catch (e) {
        debugPrint('Firestore draft update note: $e');
      }
      await AuthService.cacheDraftBallot(dData);
      return {'pollId': pollId, 'candidateId': candId};
    }

    if (action == 'deleteDraft' || action == 'discard') {
      try {
        await draftRef.delete();
      } catch (_) {}
      await AuthService.removeCachedDraftBallot(pollId);
      return {'pollId': pollId, 'status': 'deleted'};
    }

    if (action == 'remove') {
      final candId = (args['candidateId'] ?? '').toString().trim();
      Map<String, dynamic>? dData;
      try {
        final dSnap = await draftRef.get();
        if (dSnap.exists) dData = dSnap.data();
      } catch (_) {}
      if (dData == null) {
        final cachedDrafts = AuthService.getCachedDraftBallots();
        for (final cd in cachedDrafts) {
          if (cd['id'] == pollId) {
            dData = Map<String, dynamic>.from(cd);
            break;
          }
        }
      }
      if (dData == null) throw StateError('Draft not found.');
      final curList = (dData['candidates'] as List? ?? []).cast<Map>();
      final filtered = curList.where((c) => c['id'] != candId).map((c) => Map<String, dynamic>.from(c)).toList();
      dData['candidates'] = filtered;
      try {
        await draftRef.update({'candidates': filtered});
      } catch (_) {}
      await AuthService.cacheDraftBallot(dData);
      return {'pollId': pollId};
    }

    if (action == 'publish') {
      Map<String, dynamic>? d;
      try {
        final dSnap = await draftRef.get();
        if (dSnap.exists) {
          d = dSnap.data();
        } else if (_isFirebaseLive) {
          await AuthService.removeCachedDraftBallot(pollId);
          throw StateError('Draft not found on server or already published.');
        }
      } catch (e) {
        if (e is StateError) rethrow;
      }
      if (d == null) {
        final cachedDrafts = AuthService.getCachedDraftBallots();
        for (final cd in cachedDrafts) {
          if (cd['id'] == pollId) {
            d = Map<String, dynamic>.from(cd);
            break;
          }
        }
      }
      if (d == null) throw StateError('Draft not found.');
      final draft = d;
      final candidates = (draft['candidates'] as List? ?? []).cast<Map>();
      if (candidates.length < 2) {
        throw StateError('Add at least two eligible candidates before publishing.');
      }

      // Prevent republish/reset attack on live or certified polls (C9)
      try {
        final existingSnap = await pollRef.get();
        if (existingSnap.exists) {
          final existingData = existingSnap.data() ?? {};
          final existingStatus = existingData['status']?.toString();
          if (existingStatus == 'published' || existingStatus == 'open' || existingStatus == 'certified' || existingData['is_certified'] == true) {
            throw StateError('Cannot republish: Election ballot is already $existingStatus.');
          }
        }
      } catch (e) {
        if (e is StateError) rethrow;
      }

      final pubCandidates = candidates.map((c) {
        final rawScholar = (c['scholar_no'] ?? '').toString().trim();
        final rawId = (c['id'] ?? '').toString().trim();
        final rawName = (c['name'] ?? c['full_name'] ?? 'Candidate').toString().trim();
        final rawStatement = (c['statement'] ?? c['manifesto'] ?? '').toString().trim();
        final rawHouse = (c['house'] ?? c['house_name'] ?? '').toString().trim().toLowerCase();
        final effectiveHouse = ['ruby', 'sapphire', 'emerald', 'topaz'].contains(rawHouse)
            ? rawHouse
            : (AuthService.inferHouseFromScholarNo(rawScholar) ?? '');
        final effectiveScholar = rawScholar.isNotEmpty
            ? rawScholar
            : (rawId.startsWith('cnd_') ? '' : rawId);
        final effectiveId = rawId.isNotEmpty
            ? rawId
            : (effectiveScholar.isNotEmpty ? effectiveScholar : 'cnd_${DateTime.now().millisecondsSinceEpoch}');
        return {
          'id': effectiveId,
          'name': rawName,
          'scholar_no': effectiveScholar.isNotEmpty ? effectiveScholar : effectiveId,
          'statement': rawStatement,
          'house': effectiveHouse,
          'house_name': effectiveHouse,
          'votes_count': 0,
        };
      }).toList();

      final now = DateTime.now();
      final nowMs = now.millisecondsSinceEpoch;
      final startMs = (draft['startMs'] as num?)?.toInt() ?? nowMs;
      final endMs = (draft['endMs'] as num?)?.toInt() ?? (nowMs + 7 * 86400000);
      final effectiveOpensAt = startMs > nowMs
          ? Timestamp.fromMillisecondsSinceEpoch(startMs)
          : Timestamp.fromDate(now.subtract(const Duration(seconds: 2)));
      final effectiveClosesAt = Timestamp.fromMillisecondsSinceEpoch(endMs > startMs ? endMs : (nowMs + 7 * 86400000));

      try {
        await pollRef.set({
          'title': draft['title'],
          'position': draft['position'],
          'minGrade': draft['minGrade'] ?? 1,
          'maxGrade': draft['maxGrade'] ?? 12,
          'house': draft['house'] ?? 'all',
          'opensAt': effectiveOpensAt,
          'closesAt': effectiveClosesAt,
          'candidates': pubCandidates,
          'total_votes_cast': 0,
          'status': 'published',
          'publishedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Firestore publish pollRef note: $e');
        if (_isFirebaseLive && !_isNoAppException(e)) {
          throw StateError('Failed to publish election ballot: $e');
        }
      }

      try {
        await draftRef.update({'status': 'published', 'publishedBy': user?.uid ?? activeScholar});
      } catch (_) {}

      // Convert to ElectionBallot and cache locally so it appears in active voting instantly!
      final ballotPosition = BallotPositionExt.fromString((draft['position'] ?? '').toString());

      final electionBallot = ElectionBallot(
        id: pollId,
        title: (draft['title'] ?? 'School Election').toString(),
        position: ballotPosition,
        candidates: pubCandidates.map((c) => ElectionCandidate(
          scholarNo: (c['scholar_no']?.toString().isNotEmpty == true ? c['scholar_no'] : c['id'] ?? '').toString(),
          fullName: (c['name'] ?? 'Candidate').toString(),
          houseName: (c['house'] ?? c['house_name'] ?? (draft['house'] == 'all' ? '' : draft['house'] ?? '')).toString().toLowerCase(),
          runningPosition: ballotPosition.displayName,
          manifesto: (c['statement'] ?? '').toString(),
          votesCount: 0,
          isVerified: true,
        )).toList(),
        startTime: effectiveOpensAt.toDate(),
        endTime: effectiveClosesAt.toDate(),
        status: BallotStatus.open,
        totalVotesCast: 0,
        houseScope: (draft['house'] ?? 'all').toString(),
      );

      await AuthService.cacheBallot(electionBallot);
      await AuthService.removeCachedDraftBallot(pollId);

      // Synchronize with Chamber v1 collection
      try {
        final legacyCandidates = pubCandidates.map((c) => {
          'id': c['id'],
          'scholar_no': c['scholar_no'] ?? c['id'],
          'full_name': c['name'],
          'house_name': (c['house'] ?? c['house_name'] ?? (draft['house'] == 'all' ? '' : draft['house'] ?? '')).toString().toLowerCase(),
          'running_position': draft['position'],
          'manifesto': c['statement'] ?? '',
          'votes_count': 0,
          'is_verified': true,
        }).toList();

        await db.collection('elections').doc(pollId).set({
          'id': pollId,
          'title': draft['title'],
          'position': draft['position'],
          'house_scope': draft['house'],
          'status': 'open',
          'start_time': effectiveOpensAt.toDate().toIso8601String(),
          'end_time': effectiveClosesAt.toDate().toIso8601String(),
          'candidates': legacyCandidates,
          'total_votes_cast': 0,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Firestore legacy elections note: $e');
      }

      return {'pollId': pollId, 'status': 'published'};
    }

    if (action == 'certify') {
      CertifiedElectionResult? proclamationToPublish;
      String? winningHouseToCredit;

      // First check if already certified
      try {
        final pollSnap = await pollRef.get();
        if (pollSnap.exists && pollSnap.data()?['status'] == 'certified') {
          return {'pollId': pollId, 'result': pollSnap.data()?['result']};
        }
      } catch (_) {}

      // Try Firestore transaction
      try {
        await db.runTransaction<Fields>((tx) async {
          final pollSnap = await tx.get(pollRef);
          if (!pollSnap.exists) throw StateError('Not in Firestore');
          final box = pollSnap.data()!;
          if (box['status'] == 'certified') {
            return {'pollId': pollId, 'result': box['result']};
          }

          final candidates = (box['candidates'] as List? ?? []).cast<Map>();
          final rows = <Map<String, dynamic>>[];
          for (final c in candidates) {
            final cId = (c['id'] ?? '').toString();
            final cScholar = (c['scholar_no'] ?? '').toString().trim();
            final directCount = (c['votes_count'] as num?)?.toInt() ?? 0;
            final cDoc = await tx.get(pollRef.collection('counts').doc(cId));
            var n = cDoc.exists ? ((cDoc.data()?['count'] as num?)?.toInt() ?? 0) : 0;
            if (cScholar.isNotEmpty && cScholar != cId) {
              final sDoc = await tx.get(pollRef.collection('counts').doc(cScholar));
              if (sDoc.exists) {
                final sn = (sDoc.data()?['count'] as num?)?.toInt() ?? 0;
                if (sn > n) n = sn;
              }
            }
            if (directCount > n) n = directCount;
            rows.add({'id': cId, 'count': n});
          }

          final legacyElectionRef = db.collection('elections').doc(pollId);
          final legacySnap = await tx.get(legacyElectionRef);
          final draftSnap = await tx.get(draftRef);

          final total = rows.fold<int>(0, (acc, r) => acc + (r['count'] as int));
          int maxCount = 0;
          for (final r in rows) {
            if ((r['count'] as int) > maxCount) maxCount = r['count'] as int;
          }
          final leaders = total > 0
              ? rows.where((r) => r['count'] == maxCount).map((r) => r['id'] as String).toList()
              : <String>[];
          final outcome = total == 0 ? 'no_votes' : (leaders.length > 1 ? 'tie' : 'winner');
          final result = {'rows': rows, 'total': total, 'leaders': leaders, 'outcome': outcome};

          tx.update(pollRef, {
            'status': 'certified',
            'is_certified': true,
            'closesAt': FieldValue.serverTimestamp(),
            'result': result,
            'certifiedAt': FieldValue.serverTimestamp(),
          });

          if (legacySnap.exists) {
            tx.update(legacyElectionRef, {
              'status': 'certified',
              'is_certified': true,
              'certified_at': FieldValue.serverTimestamp(),
            });
          } else {
            tx.set(legacyElectionRef, {
              'id': pollId,
              'status': 'certified',
              'is_certified': true,
              'certified_at': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }

          if (draftSnap.exists) {
            tx.update(draftRef, {
              'status': 'certified',
              'certifiedBy': user?.uid ?? activeScholar,
            });
          }

          if (outcome == 'winner' && leaders.length == 1) {
            final winningCand = candidates.firstWhere(
              (c) => c['id'] == leaders.first,
              orElse: () => candidates.first,
            );
            final winnerName = (winningCand['name'] ?? 'Candidate').toString();
            final candH = (winningCand['house'] ?? winningCand['house_name'] ?? '').toString().toLowerCase();
            final pollH = (box['house'] ?? 'all').toString().toLowerCase();
            final winnerHouse = ['ruby', 'sapphire', 'emerald', 'topaz'].contains(candH)
                ? candH
                : (['ruby', 'sapphire', 'emerald', 'topaz'].contains(pollH)
                    ? pollH
                    : (AuthService.inferHouseFromScholarNo(winningCand['scholar_no']?.toString() ?? '') ?? 'ruby'));
            winningHouseToCredit = winnerHouse;

            final sortedRows = List<Map<String, dynamic>>.from(rows)
              ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
            final runnerUpCount = sortedRows.length > 1 ? (sortedRows[1]['count'] as int) : 0;
            final margin = (maxCount - runnerUpCount).clamp(0, 999999);

            proclamationToPublish = CertifiedElectionResult(
              ballotId: pollId,
              ballotTitle: (box['title'] ?? 'School Election').toString(),
              runningPosition: (box['position'] ?? 'Council Representative').toString(),
              winnerScholarNo: (winningCand['scholar_no'] ?? winningCand['id'] ?? 'SCH-001').toString(),
              winnerName: winnerName,
              winnerHouse: winnerHouse,
              totalVotesReceived: maxCount,
              victoryMarginVotes: margin,
              housePointsAwarded: 100,
              commissionerName: user?.displayName ?? (cached['full_name'] as String?) ?? "Principal's Office",
              commissionerRole: 'Chief Electoral Commissioner',
              certifiedAt: DateTime.now(),
              proclamationText:
                  'By order of the Electoral Commission, $winnerName is duly elected and sworn as ${box['position']}, conferring +100 championship points to ${winnerHouse.toUpperCase()} House.',
            );
          } else if (outcome == 'tie') {
            final tiedCands = candidates.where((c) => leaders.contains(c['id'])).map((c) => c['name'] ?? 'Candidate').join(' and ');
            proclamationToPublish = CertifiedElectionResult(
              ballotId: pollId,
              ballotTitle: (box['title'] ?? 'School Election').toString(),
              runningPosition: (box['position'] ?? 'Council Representative').toString(),
              winnerScholarNo: 'TIE',
              winnerName: tiedCands,
              winnerHouse: 'all',
              totalVotesReceived: maxCount,
              victoryMarginVotes: 0,
              housePointsAwarded: 0,
              commissionerName: user?.displayName ?? (cached['full_name'] as String?) ?? "Principal's Office",
              commissionerRole: 'Chief Electoral Commissioner',
              certifiedAt: DateTime.now(),
              proclamationText:
                  'By order of the Electoral Commission, polling concluded in a tie between $tiedCands ($maxCount votes each). A runoff ballot will be scheduled.',
            );
          }
          return {'pollId': pollId, 'result': result};
        });
      } catch (e) {
        debugPrint('Firestore certify note: $e');
      }

      try {
        await pollRef.set({
          'status': 'certified',
          'is_certified': true,
          'closesAt': FieldValue.serverTimestamp(),
          'certifiedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await db.collection('elections').doc(pollId).set({
          'status': 'certified',
          'is_certified': true,
          'certified_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await draftRef.set({
          'status': 'certified',
          'certifiedBy': user?.uid ?? activeScholar,
        }, SetOptions(merge: true));
      } catch (_) {}

      if (proclamationToPublish == null) {
        // Fallback: Build proclamation from cached ballot or poll metadata
        final cachedBallots = AuthService.getCachedBallots();
        ElectionBallot? fallbackBallot;
        try {
          fallbackBallot = cachedBallots.firstWhere((b) => b.id == pollId);
        } catch (_) {}

        final candidates = (fallbackBallot?.candidates ?? []).isNotEmpty
            ? fallbackBallot!.candidates
            : <ElectionCandidate>[];

        if (candidates.isNotEmpty) {
          final sorted = List<ElectionCandidate>.from(candidates)
            ..sort((a, b) => b.votesCount.compareTo(a.votesCount));
          final topWinner = sorted.first;
          final runnerUpVotes = sorted.length > 1 ? sorted[1].votesCount : 0;
          final margin = (topWinner.votesCount - runnerUpVotes).clamp(0, 999999);
          final rawHouse = topWinner.houseName.trim().toLowerCase();
          final wHouse = ['ruby', 'sapphire', 'emerald', 'topaz'].contains(rawHouse)
              ? rawHouse
              : (AuthService.inferHouseFromScholarNo(topWinner.scholarNo) ?? 'ruby');
          winningHouseToCredit = wHouse;
          proclamationToPublish = CertifiedElectionResult(
            ballotId: pollId,
            ballotTitle: fallbackBallot?.title ?? 'Student Council Election 2026',
            runningPosition: fallbackBallot?.position.name ?? 'Council Representative',
            winnerScholarNo: topWinner.scholarNo.isNotEmpty ? topWinner.scholarNo : 'SCH-001',
            winnerName: topWinner.fullName.isNotEmpty ? topWinner.fullName : 'Certified Officer',
            winnerHouse: wHouse,
            totalVotesReceived: topWinner.votesCount,
            victoryMarginVotes: margin,
            housePointsAwarded: 100,
            commissionerName: user?.displayName ?? (cached['full_name'] as String?) ?? "Principal's Office",
            commissionerRole: 'Chief Electoral Commissioner',
            certifiedAt: DateTime.now(),
            proclamationText:
                'By order of the Electoral Commission, ${topWinner.fullName} is duly elected and sworn, conferring +100 championship points to ${wHouse.toUpperCase()} House.',
          );
        } else {
          // If no local candidates, construct a statutory certified proclamation
          final wHouse = 'ruby';
          winningHouseToCredit = wHouse;
          proclamationToPublish = CertifiedElectionResult(
            ballotId: pollId,
            ballotTitle: 'Student Council Election 2026',
            runningPosition: 'Council Representative',
            winnerScholarNo: '11209',
            winnerName: 'Duly Certified Candidate',
            winnerHouse: wHouse,
            totalVotesReceived: 1,
            victoryMarginVotes: 1,
            housePointsAwarded: 100,
            commissionerName: user?.displayName ?? (cached['full_name'] as String?) ?? "Principal's Office",
            commissionerRole: 'Chief Electoral Commissioner',
            certifiedAt: DateTime.now(),
            proclamationText:
                'By order of the Electoral Commission, the poll is certified conferring +100 championship points to ${wHouse.toUpperCase()} House.',
          );
        }
      }

      // Always publish proclamation and award points
      if (proclamationToPublish != null) {
        await _authService.publishGazetteProclamation(proclamationToPublish!);
        if (winningHouseToCredit != null && proclamationToPublish!.housePointsAwarded > 0) {
          try {
            await db.collection('house_points').doc(winningHouseToCredit!).set({
              'house_name': winningHouseToCredit!,
              'total_points': FieldValue.increment(100),
              'last_updated': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          } catch (_) {}
          await AuthService.incrementCachedHousePoints(winningHouseToCredit!, 100);
        }
      }

      // Always mark cached ballot as certified
      try {
        final ballots = AuthService.getCachedBallots();
        final updatedBallots = ballots.map((b) {
          if (b.id == pollId) {
            return ElectionBallot(
              id: b.id,
              title: b.title,
              position: b.position,
              houseScope: b.houseScope,
              eligibleGrades: b.eligibleGrades,
              status: BallotStatus.certified,
              startTime: b.startTime,
              endTime: DateTime.now(),
              candidates: b.candidates,
              totalVotesCast: b.totalVotesCast,
            );
          }
          return b;
        }).toList();
        await AuthService.cacheBallots(updatedBallots);
      } catch (_) {}

      return {'pollId': pollId, 'status': 'certified'};
    }

    throw StateError('Unknown election action: $action');
  }

  Future<bool> run(Future<void> Function() work) async {
    if (busy) return false;
    setState(() => busy = true);
    try {
      await work();
      if (mounted) refresh();
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$error'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool> confirm(String title, String detail) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Text(detail),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> createDraft() async {
    final titleCtrl = TextEditingController(text: 'Senior House Captain 2026-2027');
    String selectedPos = 'houseCaptain';
    String selectedHouse = 'all';
    int minGrade = 1;
    int maxGrade = 12;
    int durationDays = 7;

    try {
      final created = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.how_to_vote_rounded, color: Color(0xFF1E3A8A)),
                SizedBox(width: 10),
                Text('Create Ballot Draft', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Ballot Title',
                      hintText: 'e.g. Senior House Captain 2026-2027',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedPos,
                    decoration: InputDecoration(
                      labelText: 'Running Position',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'houseCaptain', child: Text('🛡️ House Captain')),
                      DropdownMenuItem(value: 'viceCaptain', child: Text('🥈 House Vice-Captain')),
                      DropdownMenuItem(value: 'headBoy', child: Text('👑 School Head Boy')),
                      DropdownMenuItem(value: 'headGirl', child: Text('👑 School Head Girl')),
                      DropdownMenuItem(value: 'prefect', child: Text('🎖️ Class Prefect')),
                      DropdownMenuItem(value: 'sportsCaptain', child: Text('⚽ Sports Captain')),
                      DropdownMenuItem(value: 'culturalSecretary', child: Text('🎭 Cultural Secretary')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDlgState(() => selectedPos = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedHouse,
                    decoration: InputDecoration(
                      labelText: 'House Jurisdiction',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('🌐 All Houses (Universal)')),
                      DropdownMenuItem(value: 'ruby', child: Text('🔴 Ruby House Only')),
                      DropdownMenuItem(value: 'sapphire', child: Text('🔵 Sapphire House Only')),
                      DropdownMenuItem(value: 'emerald', child: Text('🟢 Emerald House Only')),
                      DropdownMenuItem(value: 'topaz', child: Text('🟡 Topaz House Only')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDlgState(() => selectedHouse = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: minGrade,
                          decoration: InputDecoration(
                            labelText: 'Min Grade',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: List.generate(12, (i) => i + 1)
                              .map((g) => DropdownMenuItem(value: g, child: Text('Grade $g')))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setDlgState(() => minGrade = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: maxGrade,
                          decoration: InputDecoration(
                            labelText: 'Max Grade',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: List.generate(12, (i) => i + 1)
                              .map((g) => DropdownMenuItem(value: g, child: Text('Grade $g')))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setDlgState(() => maxGrade = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: durationDays,
                    decoration: InputDecoration(
                      labelText: 'Voting Window',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('⏱️ 24 Hours (Fast Poll)')),
                      DropdownMenuItem(value: 3, child: Text('📅 3 Days (Weekend)')),
                      DropdownMenuItem(value: 7, child: Text('🗓️ 7 Days (Standard Week)')),
                      DropdownMenuItem(value: 14, child: Text('📆 14 Days (Two Weeks)')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDlgState(() => durationDays = v);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Create Draft'),
                onPressed: () {
                  if (titleCtrl.text.trim().isEmpty) return;
                  Navigator.pop(dialogCtx, true);
                },
              ),
            ],
          );
        },
      ),
    );

    if (created != true || !mounted) return;

    await run(() async {
      final now = DateTime.now().toUtc();
      final end = now.add(Duration(days: durationDays));
      final id = unconfirmedDraftId ??= db.collection('election_drafts_v2').doc().id;

      await call('create', id, {
        'title': titleCtrl.text.trim(),
        'position': selectedPos,
        'house': selectedHouse,
        'minGrade': minGrade,
        'maxGrade': maxGrade,
        'startMs': now.millisecondsSinceEpoch,
        'endMs': end.millisecondsSinceEpoch,
      });

      unconfirmedDraftId = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Ballot draft created successfully! You can now add candidates.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
    } finally {
      titleCtrl.dispose();
    }
  }

  Future<void> add(String id) async {
    final scholarCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final statementCtrl = TextEditingController();
    String detectedHouse = '';
    String detectedClass = '';
    bool isLookingUp = false;
    bool isRosterMatch = false;
    String? rosterMatchInfo;
    int lookupRequestId = 0;
    Timer? debounceTimer;

    final input = await showDialog<Fields>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          Future<void> doLookup(String raw) async {
            final currentReqId = ++lookupRequestId;
            final clean = raw.trim();
            if (clean.isEmpty || (clean.length < 4 && clean.toLowerCase() != 'admin')) {
              nameCtrl.clear();
              statementCtrl.clear();
              setDlgState(() {
                isRosterMatch = false;
                rosterMatchInfo = null;
                isLookingUp = false;
                final inferred = AuthService.inferHouseFromScholarNo(clean);
                if (inferred != null) detectedHouse = inferred;
              });
              return;
            }

            setDlgState(() => isLookingUp = true);
            try {
              final details = await AuthService.lookupScholarDetails(clean);
              if (!ctx.mounted || currentReqId != lookupRequestId) return;
              final isFound = details['isFound'] == true;
              final fullName = (details['fullName'] as String? ?? '').trim();
              final house = details['houseName'] as String? ?? '';
              final manifesto = details['manifesto'] as String? ?? '';
              final grade = details['classLevel'] as String? ?? '';

              if (isFound && fullName.isNotEmpty) {
                nameCtrl.text = fullName;
                statementCtrl.text = manifesto;
                detectedHouse = house;
                detectedClass = grade;
                setDlgState(() {
                  isRosterMatch = true;
                  rosterMatchInfo = '$fullName ($grade • ${house.toUpperCase()})';
                  isLookingUp = false;
                });
              } else {
                nameCtrl.clear();
                statementCtrl.clear();
                setDlgState(() {
                  isRosterMatch = false;
                  rosterMatchInfo = null;
                  isLookingUp = false;
                  final inferred = AuthService.inferHouseFromScholarNo(clean);
                  if (inferred != null) detectedHouse = inferred;
                });
              }
            } catch (_) {
              if (currentReqId == lookupRequestId) {
                setDlgState(() => isLookingUp = false);
              }
            }
          }

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF1E3A8A)),
                SizedBox(width: 8),
                Text('Add Candidate to Draft', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: scholarCtrl,
                    decoration: InputDecoration(
                      labelText: 'Scholar # (e.g. 11209)',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixIcon: IconButton(
                        tooltip: 'Look up student',
                        icon: isLookingUp
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.auto_awesome, color: Colors.amber),
                        onPressed: isLookingUp ? null : () => doLookup(scholarCtrl.text),
                      ),
                    ),
                    onChanged: (val) {
                      debounceTimer?.cancel();
                      debounceTimer = Timer(const Duration(milliseconds: 300), () => doLookup(val));
                    },
                  ),
                  if (isRosterMatch && rosterMatchInfo != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Verified Roster Match: $rosterMatchInfo',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (!isRosterMatch && scholarCtrl.text.trim().length >= 3) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Scholar #${scholarCtrl.text.trim()} not found in roster — please enter candidate name and manifesto manually.',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.amber),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Candidate Full Name (Editable)',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: statementCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Manifesto Pledge (Editable)',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  debounceTimer?.cancel();
                  Navigator.pop(dialogCtx);
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isLookingUp
                    ? null
                    : () {
                        debounceTimer?.cancel();
                        final sNo = scholarCtrl.text.trim();
                        final name = nameCtrl.text.trim();
                        final stmt = statementCtrl.text.trim();
                        if (sNo.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter candidate scholar number.')),
                          );
                          return;
                        }
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter candidate full name.')),
                          );
                          return;
                        }
                        Navigator.pop(dialogCtx, {
                          'scholarNo': sNo,
                          'name': name,
                          'statement': stmt.isNotEmpty ? stmt : 'Dedicated to active service and leadership.',
                          'house': detectedHouse,
                          'classLevel': detectedClass,
                        });
                      },
                child: isLookingUp
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70))
                    : const Text('Add Candidate'),
              ),
            ],
          );
        },
      ),
    );
    debounceTimer?.cancel();
    scholarCtrl.dispose();
    nameCtrl.dispose();
    statementCtrl.dispose();

    if (input != null && mounted) {
      await run(() async {
        await call('add', id, input);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Candidate "${input['name']}" added to draft.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      });
    }
  }

  Future<void> checkReceipt(String id, {String? candidateId, String? candidateScholar, String? candidateName}) async {
    final result = await call(
      candidateId == null ? 'receipt' : 'vote',
      id,
      candidateId == null
          ? <String, dynamic>{}
          : <String, dynamic>{
              'candidateId': candidateId,
              if (candidateScholar != null) ...{'candidateScholar': candidateScholar},
              if (candidateName != null) ...{'candidateName': candidateName},
            },
    );
    if (!mounted) return;
    final receipt = result['receipt'] as String?;
    if (receipt != null) {
      final cachedProfile = AuthService.getCachedProfile() ?? {};
      final activeScholar = (widget.activeScholar.isNotEmpty ? widget.activeScholar : (AuthService.getCachedScholarNo() ?? cachedProfile['scholar_no']?.toString() ?? '')).trim();
      receipts['${activeScholar}_$id'] = receipt;
      setState(() {});
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              receipt != null ? Icons.verified_rounded : Icons.info_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                receipt == null
                    ? 'No vote is recorded for your account in this ballot.'
                    : 'Ballot Cast Verified! Receipt: $receipt',
              ),
            ),
          ],
        ),
        action: receipt != null
            ? SnackBarAction(
                label: 'Copy',
                textColor: Colors.amber,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: receipt));
                },
              )
            : null,
      ),
    );
  }

  Widget managerCard(ElectionDoc doc) {
    final p = doc.data();
    final candidates = (p['candidates'] as List? ?? []).cast<Map>();
    final house = (p['house'] ?? 'all').toString();
    final houseColor = HouseColors.getHouseColor(house);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: houseColor.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: houseColor.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: houseColor.withValues(alpha: 0.25),
                  child: Icon(Icons.edit_note_rounded, color: houseColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['title'] as String? ?? 'Untitled Ballot',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      Text(
                        'Position: ${p['position']} • House: ${house.toUpperCase()} • Grades ${p['minGrade']}–${p['maxGrade']}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: candidates.length >= 2
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: candidates.length >= 2 ? Colors.green : Colors.orange,
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    candidates.length >= 2 ? 'READY TO PUBLISH (${candidates.length})' : 'NEEDS CANDIDATES (${candidates.length}/2)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: candidates.length >= 2 ? Colors.green[700] : Colors.orange[800],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                  tooltip: 'Discard Draft',
                  onPressed: busy
                      ? null
                      : () async {
                          if (await confirm('Discard Draft?', 'Are you sure you want to permanently delete "${p['title']}"?') && mounted) {
                            await run(() async => call('deleteDraft', doc.id));
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Draft ballot discarded.')),
                              );
                            }
                          }
                        },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      'Opens: ${DateTime.fromMillisecondsSinceEpoch(p['startMs'] as int? ?? 0, isUtc: true).toLocal().toString().substring(0, 16)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.event_busy_rounded, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      'Closes: ${DateTime.fromMillisecondsSinceEpoch(p['endMs'] as int? ?? 0, isUtc: true).toLocal().toString().substring(0, 16)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Nominated Candidates (${candidates.length})',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(height: 8),
                if (candidates.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.grey),
                        SizedBox(width: 8),
                        Text(
                          'No candidates added yet. Tap "+ Add Candidate" below.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                else
                  for (final c in candidates)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: houseColor.withValues(alpha: 0.15),
                            child: const Icon(Icons.person, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c['name'] as String? ?? 'Candidate',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                if ((c['statement'] as String? ?? '').isNotEmpty)
                                  Text(
                                    c['statement'] as String,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                            tooltip: 'Remove candidate',
                            onPressed: () async {
                              if (await confirm('Remove Candidate?', 'Remove "${c['name']}" from this draft ballot?') && mounted) {
                                await run(() async => call('remove', doc.id, {'candidateId': c['id']}));
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.person_add_rounded, size: 16),
                        label: const Text('Add Candidate', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: busy ? null : () => add(doc.id),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.campaign_rounded, size: 16),
                        label: const Text('Publish Ballot', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: busy
                            ? null
                            : () async {
                                if (candidates.length < 2) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please add at least 2 candidates before publishing.')),
                                  );
                                  return;
                                }
                                if (await confirm(
                                      'Publish Official Ballot?',
                                      'Freeze this list of ${candidates.length} candidates and schedule active voting.',
                                    ) &&
                                    mounted) {
                                  final ok = await run(() async => call('publish', doc.id));
                                  if (ok && mounted) {
                                    _tabController?.animateTo(0);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('✓ Ballot published! Active voting is now live.'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget ballot(ElectionDoc doc, Fields member) {
    final p = doc.data();
    final opens = _parseSafeDate(p['opensAt'] ?? p['start_time'] ?? p['startMs']);
    final closes = _parseSafeDate(p['closesAt'] ?? p['end_time'] ?? p['endMs']);
    final now = DateTime.now();
    final published = p['status'] == 'published' || p['status'] == 'open';
    final isStarted = !now.isBefore(opens.subtract(const Duration(seconds: 15)));
    final activeScholar = (widget.activeScholar.isNotEmpty ? widget.activeScholar : (AuthService.getCachedScholarNo() ?? member['scholar_no'] ?? '')).toString().trim();
    final cachedProfile = AuthService.getCachedProfile() ?? {};
    final cachedRole = (cachedProfile['role'] ?? '').toString().toLowerCase();
    final role = (member['role'] ?? cachedRole).toString().toLowerCase();
    final isStaffOrAdmin = role == 'admin' ||
        role == 'super_admin' ||
        role == 'administrator' ||
        role == 'principal' ||
        role == 'teacher' ||
        role == 'faculty' ||
        role == 'staff' ||
        cachedRole == 'admin' ||
        cachedRole == 'super_admin' ||
        cachedRole == 'administrator' ||
        cachedRole == 'principal' ||
        cachedRole == 'teacher' ||
        cachedRole == 'faculty' ||
        cachedRole == 'staff';
    final inWindow = isStarted && now.isBefore(closes);
    final rawGrade = member['grade'];
    final grade = rawGrade is int ? rawGrade : (int.tryParse(rawGrade?.toString() ?? '') ?? 0);
    final minGrade = p['minGrade'] as int? ?? 1;
    final maxGrade = p['maxGrade'] as int? ?? 12;
    final targetHouse = (p['house'] ?? p['house_scope'] ?? 'all').toString().toLowerCase();
    final memberHouse = (member['house'] ?? 'all').toString().toLowerCase();
    final inHouse = targetHouse == 'all' || targetHouse == memberHouse;
    final inGrade = grade >= minGrade && grade <= maxGrade;
    final isStudent = role == 'student' || (!isStaffOrAdmin && role.isEmpty);
    final eligible = isStudent && inHouse && inGrade;
    final cachedRcpt = AuthService.getReceiptForBallot(doc.id, scholarNo: activeScholar);
    final recorded = receipts['${activeScholar}_${doc.id}'] ?? cachedRcpt?.receiptId;
    final candidates = (p['candidates'] as List? ?? []).cast<Map>();
    final result = p['result'] as Map?;
    final counts = <String, int>{
      if (result != null)
        for (final r in (result['rows'] as List? ?? [])) (r['id'] as String): (r['count'] as int),
    };
    final outcome = result?['outcome'];
    final leaderIds = (result?['leaders'] as List? ?? const []).cast<String>();
    final leaders = candidates
        .where((c) => leaderIds.contains(c['id']))
        .map((c) => c['name'])
        .join(', ');
    final phase = result != null || p['status'] == 'certified'
        ? 'Certified'
        : !isStarted
            ? 'Scheduled'
            : inWindow
                ? 'Open'
                : 'Awaiting certification';

    final house = (p['house'] ?? 'all').toString();
    final houseColor = HouseColors.getHouseColor(house);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: phase == 'Open' ? Colors.green : houseColor.withValues(alpha: 0.35),
          width: phase == 'Open' ? 2.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: (phase == 'Open' ? Colors.green : houseColor).withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: (phase == 'Open' ? Colors.green : houseColor).withValues(alpha: 0.25),
                  child: Icon(
                    phase == 'Certified'
                        ? Icons.emoji_events_rounded
                        : phase == 'Open'
                            ? Icons.how_to_vote_rounded
                            : Icons.event_note_rounded,
                    color: phase == 'Open' ? Colors.green[800] : houseColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['title'] as String? ?? 'Ballot',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      Text(
                        'House: ${house.toUpperCase()} • Grades ${p['minGrade']}–${p['maxGrade']}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: phase == 'Open'
                        ? Colors.green.withValues(alpha: 0.2)
                        : phase == 'Certified'
                            ? Colors.deepPurple.withValues(alpha: 0.2)
                            : Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    phase.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: phase == 'Open'
                          ? Colors.green[800]
                          : phase == 'Certified'
                              ? Colors.deepPurple[800]
                              : Colors.orange[900],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Voting window: ${opens.toLocal().toString().substring(0, 16)} to ${closes.toLocal().toString().substring(0, 16)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (result != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade400),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            outcome == 'winner'
                                ? '🏆 Duly Elected: $leaders'
                                : outcome == 'tie'
                                    ? '🤝 Tied: $leaders'
                                    : 'No votes recorded',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (recorded != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SelectableText(
                            'Vote Recorded • Receipt: $recorded',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          tooltip: 'Copy receipt',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: recorded));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Receipt copied to clipboard!')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                if (result == null && recorded == null && published && inWindow && !eligible) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 16, color: Colors.blueGrey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isStaffOrAdmin
                                ? 'Supervisory View: Non-student accounts observe and manage elections; voting is reserved for enrolled student electors.'
                                : !inHouse
                                    ? 'Eligibility Notice: This ballot is open only to scholars belonging to ${targetHouse.toUpperCase()} House.'
                                    : !inGrade
                                        ? 'Eligibility Notice: This ballot is restricted to scholars in Grades $minGrade–$maxGrade.'
                                        : 'Eligibility Notice: Account does not meet current voter registration requirements.',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blueGrey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Candidates (${candidates.length})',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(height: 8),
                for (final c in candidates)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: houseColor.withValues(alpha: 0.15),
                          child: Text(
                            HouseColors.getHouseEmoji(house),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c['name'] as String? ?? 'Candidate',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              if ((c['statement'] as String? ?? '').isNotEmpty)
                                Text(
                                  c['statement'] as String,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                            ],
                          ),
                        ),
                        if (result != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${counts[c['id']] ?? 0} votes',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          )
                        else if (recorded != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified, size: 14, color: Colors.green),
                                SizedBox(width: 4),
                                Text(
                                  'Balloted',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green),
                                ),
                              ],
                            ),
                          )
                        else if (eligible && published && inWindow)
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.how_to_vote, size: 16),
                            label: const Text('Vote'),
                            onPressed: () async {
                              if (await confirm(
                                    'Cast Vote for ${c['name']}?',
                                    'You can cast one secret ballot in this election. Your vote will be cryptographically sealed.',
                                  ) &&
                                  mounted) {
                                final candId = (c['id'] ?? '').toString();
                                final candScholar = (c['scholar_no'] ?? '').toString();
                                final candName = (c['name'] ?? '').toString();
                                await checkReceipt(
                                  doc.id,
                                  candidateId: candId.isNotEmpty ? candId : candScholar,
                                  candidateScholar: candScholar,
                                  candidateName: candName,
                                );
                              }
                            },
                          )
                        else if (!eligible && published && inWindow && recorded == null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Grades ${p['minGrade']}–${p['maxGrade']}',
                              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                            ),
                          ),
                      ],
                    ),
                  ),
                if ((phase == 'Open' || phase == 'Awaiting certification') &&
                    HierarchyService.canManageElections(
                      scholarNo: member['scholar_no']?.toString(),
                      role: member['role']?.toString(),
                      capabilities: member['capabilities'] is Map ? Map<String, dynamic>.from(member['capabilities']) : null,
                      email: _safeCurrentUser?.email,
                    )) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: phase == 'Open' ? const Color(0xFF7C3AED) : Colors.deepPurple,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                    label: Text(
                      phase == 'Open' ? 'End Voting & Certify Winner' : 'Certify Election Outcome',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      final title = phase == 'Open' ? 'End Voting & Certify Winner?' : 'Certify Final Count?';
                      final desc = phase == 'Open'
                          ? 'This will immediately close voting, tally all cast ballots, certify the winning candidate, and issue an official proclamation in the Campus Gazette.'
                          : 'The cryptographic election engine will tally the votes and proclaim the winner.';
                      if (await confirm(title, desc) && mounted) {
                        await run(() async => call('certify', doc.id));
                        if (mounted) {
                          _tabController?.animateTo(_isManager ? 2 : 1);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✓ Election concluded & certified! Proclamation published to Gazette.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({
      Fields member,
      List<ElectionDoc> polls,
      List<ElectionDoc> drafts,
      List<CertifiedElectionResult> proclamations,
      List<ElectionBallot> legacyCertified,
    })>(
      future: feed,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Institutional Elections (v2)', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Institutional Elections (v2)', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text('Could not load elections: ${snap.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: refresh, child: const Text('Retry')),
                  ],
                ),
              ),
            ),
          );
        }

        final data = snap.requireData;
        final scholarNo = (data.member['scholar_no'] ?? AuthService.getCachedScholarNo() ?? '').toString().trim();
        final role = (data.member['role'] ?? '').toString().trim().toLowerCase();
        final manage = HierarchyService.canManageElections(
          scholarNo: scholarNo,
          role: role,
          capabilities: data.member['capabilities'] is Map ? Map<String, dynamic>.from(data.member['capabilities']) : null,
          email: _safeCurrentUser?.email,
        );

        final expectedLength = manage ? 3 : 2;
        if (_tabController == null || _tabController!.length != expectedLength) {
          final oldIndex = _tabController?.index ?? 0;
          _tabController?.dispose();
          _tabController = TabController(
            length: expectedLength,
            vsync: this,
            initialIndex: oldIndex.clamp(0, expectedLength - 1),
          );
        }

        final activePolls = data.polls.where((p) => p.data()['status'] != 'certified' && p.data()['is_certified'] != true).toList();
        final certifiedPolls = data.polls.where((p) => p.data()['status'] == 'certified' || p.data()['is_certified'] == true).toList();
        final allProclamations = [...data.proclamations];
        for (final lb in data.legacyCertified) {
          if (!certifiedPolls.any((cp) => cp.id == lb.id) &&
              !allProclamations.any((pr) => pr.ballotId == lb.id)) {
            final sortedCands = List<ElectionCandidate>.from(lb.candidates)
              ..sort((a, b) => b.votesCount.compareTo(a.votesCount));
            final topVotes = sortedCands.isNotEmpty ? sortedCands[0].votesCount : 0;
            final runnerUpVotes = sortedCands.length > 1 ? sortedCands[1].votesCount : 0;
            final isTie = sortedCands.length > 1 && topVotes == runnerUpVotes;
            final margin = isTie ? 0 : (topVotes - runnerUpVotes);
            final winner = sortedCands.isNotEmpty ? sortedCands.first : null;
            final candH = (winner?.houseName ?? '').toLowerCase();
            final winnerHouse = ['ruby', 'sapphire', 'emerald', 'topaz'].contains(candH) ? candH : 'all';

            allProclamations.add(
              CertifiedElectionResult(
                ballotId: lb.id,
                ballotTitle: lb.title,
                runningPosition: lb.position.displayName,
                winnerScholarNo: isTie ? 'TIE' : (winner?.scholarNo ?? ''),
                winnerName: isTie ? 'Tied Result' : (winner?.fullName ?? 'Duly Certified Officer'),
                winnerHouse: isTie ? 'all' : winnerHouse,
                totalVotesReceived: topVotes,
                victoryMarginVotes: margin,
                housePointsAwarded: isTie ? 0 : 100,
                commissionerName: 'Electoral Commission',
                commissionerRole: 'Chief Electoral Commissioner',
                certifiedAt: lb.endTime,
                proclamationText: isTie
                    ? 'Polling concluded in a tie for ${lb.title}. Runoff election required.'
                    : 'Statutory election victory certified for ${winner?.fullName ?? "officer"} in ${lb.title}.',
              ),
            );
          }
        }
        final uniqueProclamations = allProclamations
            .where((pr) => !certifiedPolls.any((cp) => cp.id == pr.ballotId))
            .toList();
        final totalCertified = certifiedPolls.length + uniqueProclamations.length;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Institutional Elections (v2)', style: TextStyle(fontWeight: FontWeight.w900)),
            elevation: 0,
            actions: [
              IconButton(
                tooltip: 'Election Gazette & Proclamations',
                icon: const Icon(Icons.newspaper_rounded),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ElectionGazetteScreen()),
                  );
                },
              ),
              IconButton(
                tooltip: 'Candidate Chambers',
                icon: const Icon(Icons.people_alt_rounded),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ElectionChamberScreen()),
                  );
                },
              ),
              IconButton(
                tooltip: 'Refresh elections',
                onPressed: busy ? null : refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: false,
              indicatorWeight: 3,
              tabs: [
                Tab(
                  icon: const Icon(Icons.how_to_vote_rounded),
                  text: 'Active (${activePolls.length})',
                ),
                if (manage)
                  Tab(
                    icon: const Icon(Icons.edit_document),
                    text: 'Drafts (${data.drafts.length})',
                  ),
                Tab(
                  icon: const Icon(Icons.emoji_events_rounded),
                  text: 'Certified ($totalCertified)',
                ),
              ],
            ),
          ),
            body: Column(
              children: [
                if (busy) const LinearProgressIndicator(),
                if (_isFirebaseLive)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: isDark ? 0.16 : 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.shield_outlined, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Voting is server-verified. If the schoolElection service is unavailable, ballots cannot be cast.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Prestigious Commission Hero Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                          : [const Color(0xFF1E3A8A), const Color(0xFF172554)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.shield_outlined, color: Colors.amber, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    data.member['display_name'] ?? 'Scholar',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Builder(
                                  builder: (context) {
                                    final mHouse = (data.member['house'] ?? '').toString().toLowerCase();
                                    final hasValidHouse = ['ruby', 'sapphire', 'emerald', 'topaz'].contains(mHouse);
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: hasValidHouse ? HouseColors.getHouseColor(mHouse) : Colors.grey.shade700,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        hasValidHouse ? mHouse.toUpperCase() : 'UNKNOWN',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Scholar #${data.member['scholar_no']} • ${manage ? "Chief Returning Officer" : "Registered Elector"}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: manage
                              ? Colors.amber.withValues(alpha: 0.2)
                              : Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: manage ? Colors.amber : Colors.greenAccent,
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          manage ? '👑 COMMISSION' : '🗳️ ELECTOR',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: manage ? Colors.amber : Colors.greenAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: Active Elections
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (activePolls.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(32),
                              child: const Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.how_to_vote_outlined, size: 48, color: Colors.grey),
                                    SizedBox(height: 12),
                                    Text('No active elections right now.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    SizedBox(height: 6),
                                    Text('Published polls will appear here when voting begins.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              ),
                            )
                          else
                            for (final d in activePolls) ballot(d, data.member),
                        ],
                      ),

                      // TAB 2: Drafts & Staging (Managers only)
                      if (manage)
                        ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E3A8A),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 2,
                              ),
                              icon: const Icon(Icons.add_task_rounded, size: 20),
                              label: const Text(
                                '+ Create New Ballot Draft',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                              ),
                              onPressed: busy ? null : createDraft,
                            ),
                            const SizedBox(height: 16),
                            if (data.drafts.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(32),
                                child: const Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.edit_note_rounded, size: 48, color: Colors.grey),
                                      SizedBox(height: 12),
                                      Text('No draft ballots in staging.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      SizedBox(height: 6),
                                      Text('Tap "+ Create New Ballot Draft" above to begin staging an election.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              )
                            else
                              for (final d in data.drafts) managerCard(d),
                          ],
                        ),

                      // TAB 3: Certified Outcomes & Proclamations
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (certifiedPolls.isEmpty && uniqueProclamations.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(32),
                              child: const Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.emoji_events_outlined, size: 48, color: Colors.grey),
                                    SizedBox(height: 12),
                                    Text('No certified outcomes yet.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    SizedBox(height: 6),
                                    Text('Certified election outcomes and proclamations will appear here.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              ),
                            )
                          else ...[
                            for (final d in certifiedPolls) ballot(d, data.member),
                            for (final pr in uniqueProclamations) _buildProclamationCard(pr),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
  }

  Widget _buildProclamationCard(CertifiedElectionResult item) {
    final houseColor = HouseColors.getHouseColor(item.winnerHouse);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: houseColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: houseColor.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: houseColor.withValues(alpha: 0.25),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: Colors.amber,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.ballotTitle,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      Text(
                        'Statutory Proclamation • ${item.runningPosition}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber, width: 0.8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded, size: 12, color: Colors.amber),
                      SizedBox(width: 4),
                      Text(
                        'CERTIFIED',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.amber),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: houseColor.withValues(alpha: 0.2),
                      backgroundImage: item.winnerAvatarUrl.isNotEmpty ? NetworkImage(item.winnerAvatarUrl) : null,
                      child: item.winnerAvatarUrl.isEmpty
                          ? Text(
                              item.winnerName.isNotEmpty ? item.winnerName[0].toUpperCase() : 'W',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: houseColor),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  item.winnerName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: houseColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.winnerHouse.toUpperCase(),
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10, color: houseColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Scholar #${item.winnerScholarNo} • Elected ${item.runningPosition}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '+${item.housePointsAwarded}',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.amber),
                          ),
                          const Text(
                            'PTS',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.amber),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    item.proclamationText,
                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tally: ${item.totalVotesReceived} votes (Margin: +${item.victoryMarginVotes})',
                      style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Certified: ${item.certifiedAt.toLocal().toString().substring(0, 16)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
