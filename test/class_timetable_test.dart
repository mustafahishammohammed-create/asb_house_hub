import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:asb_house_hub/models/class_timetable.dart';
import 'package:asb_house_hub/models/timetable_period.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M2 structure constants', () {
    test('six-day school week is Saturday through Thursday, no Friday', () {
      expect(kTimetableWeekDays, [
        'Saturday', 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      ]);
      expect(kTimetableWeekDays.contains('Friday'), isFalse);
      expect(kTeachingPeriodCount, 8);
      expect(kTeachingPeriodMinutes, 45);
      expect(kBreakMinutes, 30);
    });

    test('weekday mapping rolls Friday forward to Saturday', () {
      expect(timetableDayForWeekday(DateTime.saturday), 'Saturday');
      expect(timetableDayForWeekday(DateTime.sunday), 'Sunday');
      expect(timetableDayForWeekday(DateTime.monday), 'Monday');
      expect(timetableDayForWeekday(DateTime.thursday), 'Thursday');
      expect(timetableDayForWeekday(DateTime.friday), 'Saturday');
    });
  });

  group('TimetableSlot fixed-duration timing', () {
    test('end time is always start + 45 minutes', () {
      const slot = TimetableSlot(periodNumber: 1, startMinute: 465); // 07:45
      expect(slot.endMinute, 510); // 08:30
      expect(slot.timeSlot, '07:45 - 08:30');
      expect(slot.hasStart, isTrue);
    });

    test('unset start yields sentinel and invalid flag', () {
      const slot = TimetableSlot(periodNumber: 2);
      expect(slot.hasStart, isFalse);
      expect(slot.endMinute, -1);
      expect(TimetableSlot.formatMinute(-1), '--:--');
      expect(TimetableSlot.formatMinute(810), '13:30');
    });

    test('derived timeSlot parses through TimetablePeriod', () {
      const slot = TimetableSlot(periodNumber: 1, startMinute: 465);
      final parsed = TimetablePeriod.parseTimeSlot(slot.timeSlot);
      expect(parsed, isNotNull);
      expect(parsed!.$1.hour, 7);
      expect(parsed.$1.minute, 45);
      expect(parsed.$2.hour, 8);
      expect(parsed.$2.minute, 30);
    });
  });

  group('ClassTimetableVersion template & rendering', () {
    test('template builds 8 valid teaching periods plus a separate 30-min break', () {
      final v = ClassTimetableVersion.template(classId: '11D', dayOfWeek: 'Saturday');
      expect(v.slots.length, 8);
      expect(v.isValid, isTrue, reason: v.validate().join('; '));
      expect(v.breakAfterPeriod, 4);
      expect(v.breakEndMinute - v.breakStartMinute, 30);

      final periods = v.toPeriods();
      expect(periods.length, 9); // 8 teaching + 1 break
      expect(periods.where((p) => p.isBreak).length, 1);
      expect(periods.where((p) => !p.isBreak).length, 8);
      // Break is inserted right after Period 4.
      final breakIndex = periods.indexWhere((p) => p.isBreak);
      expect(periods[breakIndex - 1].periodNumber, 4);
      expect(periods[breakIndex + 1].periodNumber, 5);
    });

    test('every teaching period is exactly 45 minutes in rendered output', () {
      final v = ClassTimetableVersion.template(classId: '11D', dayOfWeek: 'Sunday');
      for (final p in v.toPeriods().where((p) => !p.isBreak)) {
        final parsed = TimetablePeriod.parseTimeSlot(p.timeSlot)!;
        final mins = (parsed.$2.hour * 60 + parsed.$2.minute) -
            (parsed.$1.hour * 60 + parsed.$1.minute);
        expect(mins, 45);
      }
    });
  });

  group('ClassTimetableVersion validation', () {
    test('rejects wrong period count', () {
      final v = ClassTimetableVersion.template(classId: '11D', dayOfWeek: 'Saturday')
          .copyWith(slots: [const TimetableSlot(periodNumber: 1, startMinute: 465)]);
      expect(v.isValid, isFalse);
      expect(v.validate().any((e) => e.contains('8 teaching periods')), isTrue);
    });

    test('rejects a missing start time', () {
      final v = ClassTimetableVersion.template(classId: '11D', dayOfWeek: 'Saturday');
      final slots = [...v.slots];
      slots[2] = slots[2].copyWith(startMinute: -1);
      final invalid = v.copyWith(slots: slots);
      expect(invalid.isValid, isFalse);
      expect(invalid.validate().any((e) => e.contains('Period 3')), isTrue);
    });

    test('rejects overlapping / out-of-order start times', () {
      final v = ClassTimetableVersion.template(classId: '11D', dayOfWeek: 'Saturday');
      final slots = [...v.slots];
      // Period 2 starts before Period 1 ends -> overlap.
      slots[1] = slots[1].copyWith(startMinute: slots[0].startMinute + 10);
      final invalid = v.copyWith(slots: slots);
      expect(invalid.isValid, isFalse);
      expect(invalid.validate().any((e) => e.contains('chronological')), isTrue);
    });

    test('rejects invalid break placement', () {
      final v = ClassTimetableVersion.template(classId: '11D', dayOfWeek: 'Saturday')
          .copyWith(breakAfterPeriod: 9);
      expect(v.isValid, isFalse);
    });

    test('accepts transition gaps between periods (no overlap)', () {
      final v = ClassTimetableVersion.template(classId: '11D', dayOfWeek: 'Saturday');
      final slots = [...v.slots];
      // Shift Period 5 onward later by 10 minutes, leaving a valid gap after break.
      for (var i = 4; i < 8; i++) {
        slots[i] = slots[i].copyWith(startMinute: slots[i].startMinute + 10);
      }
      final gap = v.copyWith(slots: slots);
      expect(gap.isValid, isTrue, reason: gap.validate().join('; '));
    });
  });

  group('Effective-date recurring resolution', () {
    ClassTimetableVersion published(int version, DateTime eff) =>
        ClassTimetableVersion.template(classId: '11D', dayOfWeek: 'Wednesday')
            .copyWith(
          status: TimetableStatus.published,
          version: version,
          effectiveFrom: eff,
        );

    test('picks the greatest effective date on or before the target', () {
      final old = published(1, DateTime(2026, 11, 1));
      final newer = published(2, DateTime(2026, 11, 18));
      final versions = [old, newer];
      expect(
        ClassTimetableVersion.activeForDate(versions, DateTime(2026, 11, 17)),
        same(old),
      );
      expect(
        ClassTimetableVersion.activeForDate(versions, DateTime(2026, 11, 18)),
        same(newer),
      );
      expect(
        ClassTimetableVersion.activeForDate(versions, DateTime(2026, 12, 25)),
        same(newer),
      );
    });

    test('ignores future-effective and non-published versions', () {
      final future = published(3, DateTime(2027, 1, 1));
      final draft = ClassTimetableVersion.template(classId: '11D', dayOfWeek: 'Wednesday')
          .copyWith(version: 9, effectiveFrom: DateTime(2026, 11, 1));
      expect(
        ClassTimetableVersion.activeForDate([future, draft], DateTime(2026, 11, 20)),
        isNull,
      );
    });

    test('breaks effective-date ties by higher version number', () {
      final a = published(1, DateTime(2026, 11, 18));
      final b = published(2, DateTime(2026, 11, 18));
      expect(
        ClassTimetableVersion.activeForDate([a, b], DateTime(2026, 11, 20)),
        same(b),
      );
    });
  });

  group('Serialization round-trip', () {
    test('toMap / fromMap preserves slots, break and metadata', () {
      final v = ClassTimetableVersion.template(
        classId: '11D',
        dayOfWeek: 'Saturday',
        createdByUid: 'teacher-1',
        createdByName: 'Ms. Fatima',
      ).copyWith(
        status: TimetableStatus.published,
        version: 3,
        publishedAt: DateTime(2026, 11, 8, 10),
        slots: [
          for (var n = 1; n <= 8; n++)
            TimetableSlot(
              periodNumber: n,
              subject: 'Subject $n',
              teacherName: 'Teacher $n',
              room: 'Room $n',
              startMinute: 465 + (n - 1) * 45,
              imageUrl: n == 1 ? 'data:image/png;base64,xyz' : '',
            ),
        ],
      );
      final restored = ClassTimetableVersion.fromMap(v.toMap(), 'doc-1');
      expect(restored.id, 'doc-1');
      expect(restored.classId, '11D');
      expect(restored.dayOfWeek, 'Saturday');
      expect(restored.status, TimetableStatus.published);
      expect(restored.version, 3);
      expect(restored.slots.length, 8);
      expect(restored.slots.first.subject, 'Subject 1');
      expect(restored.slots.first.imageUrl, 'data:image/png;base64,xyz');
      expect(restored.createdByName, 'Ms. Fatima');
      expect(restored.publishedAt, DateTime(2026, 11, 8, 10));
    });

    test('fromMap tolerates ISO-string dates from offline cache', () {
      final v = ClassTimetableVersion.template(classId: 'LKG-A', dayOfWeek: 'Sunday');
      final json = {
        'class_id': v.classId,
        'day_of_week': v.dayOfWeek,
        'status': v.status,
        'effective_from': v.effectiveFrom.toIso8601String(),
        'version': v.version,
        'break_after_period': v.breakAfterPeriod,
        'break_start_minute': v.breakStartMinute,
        'slots': v.slots.map((s) => s.toMap()).toList(),
      };
      final restored = ClassTimetableVersion.fromMap(json);
      expect(restored.classId, 'LKG-A');
      expect(restored.slots.length, 8);
      expect(restored.effectiveFrom.year, v.effectiveFrom.year);
    });

    test('rejection reason round-trips so a rejected version stays explainable', () {
      final v = ClassTimetableVersion.template(classId: '11D', dayOfWeek: 'Monday')
          .copyWith(
        status: TimetableStatus.rejected,
        rejectionReason: 'Break timing conflicts with general assembly',
      );

      final map = v.toMap();
      expect(map['rejection_reason'], 'Break timing conflicts with general assembly');
      expect(
        ClassTimetableVersion.fromMap(map).rejectionReason,
        'Break timing conflicts with general assembly',
      );
    });

    test('Firestore Timestamp effective date round-trips', () {
      final eff = DateTime(2026, 11, 18);
      final v = ClassTimetableVersion.template(classId: '11D', dayOfWeek: 'Monday')
          .copyWith(effectiveFrom: eff);
      final map = v.toMap();
      expect(map['effective_from'], isA<Timestamp>());
      expect(ClassTimetableVersion.fromMap(map).effectiveFrom, eff);
    });
  });
}