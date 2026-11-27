import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asb_house_hub/models/timetable_period.dart';
import 'package:asb_house_hub/models/academic_assignment.dart';
import 'package:asb_house_hub/models/academic_report_card.dart';
import 'package:asb_house_hub/models/exam_schedule_item.dart';
import 'package:asb_house_hub/widgets/academic_image.dart';

const _kTestPhoto = 'data:image/jpeg;base64,ZmFrZV9pbWFnZV9ieXRlcw==';

// Valid 1x1 PNG so Image.memory decodes successfully in widget tests.
const _kTinyPng =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

void main() {
  group('Academic imageUrl serialization', () {
    test('TimetablePeriod round-trips imageUrl and omits it when empty', () {
      final period = TimetablePeriod(
        periodNumber: 3,
        timeSlot: '09:30 - 10:15',
        subject: 'Physics',
        teacherName: 'Ms. Fern',
        room: 'Lab 2',
        dayOfWeek: 'Monday',
        classLevel: 'Grade 10',
        imageUrl: _kTestPhoto,
      );
      final map = period.toMap();
      expect(map['image_url'], _kTestPhoto);
      final restored = TimetablePeriod.fromMap(map);
      expect(restored.imageUrl, _kTestPhoto);
      expect(restored, equals(period));

      final camel = TimetablePeriod.fromMap({'imageUrl': _kTestPhoto});
      expect(camel.imageUrl, _kTestPhoto);

      final bare = period.copyWith();
      expect(bare.imageUrl, _kTestPhoto);
      expect(bare.toMap()['image_url'], _kTestPhoto);

      final noPhoto = TimetablePeriod.fromMap(period.toMap()..remove('image_url'));
      expect(noPhoto.imageUrl, isNull);
      expect(noPhoto.toMap().containsKey('image_url'), isFalse);

      final emptyPhoto = period.copyWith(imageUrl: '');
      expect(emptyPhoto.toMap().containsKey('image_url'), isFalse);
    });

    test('AcademicAssignment round-trips imageUrl and stays rules-compatible', () {
      final assignment = AcademicAssignment(
        id: 'hw_img_test',
        title: 'Algebra Worksheet',
        subject: 'Mathematics',
        teacherName: 'Mr. Sharma',
        dueDateTime: DateTime(2026, 11, 10, 8, 0),
        classLevel: 'Grade 10',
        imageUrl: _kTestPhoto,
      );
      final map = assignment.toMap();
      expect(map['image_url'], _kTestPhoto);
      final restored = AcademicAssignment.fromMap(map);
      expect(restored.imageUrl, _kTestPhoto);
      expect(restored, equals(assignment));

      final camel = AcademicAssignment.fromMap({'imageUrl': _kTestPhoto});
      expect(camel.imageUrl, _kTestPhoto);
      expect(assignment.copyWith().imageUrl, _kTestPhoto);
      expect(assignment.copyWith(imageUrl: '').toMap().containsKey('image_url'), isFalse);

      // Every serialized key must be whitelisted by isValidHomework.
      final rules = File('firestore.rules').readAsStringSync();
      final fn = RegExp(
        r'function isValidHomework\(data\) \{[\s\S]*?hasOnlyAllowedFields\(\[([\s\S]*?)\]\)',
      ).firstMatch(rules);
      expect(fn, isNotNull, reason: 'isValidHomework whitelist not found');
      final allowed = RegExp(r"'([^']+)'")
          .allMatches(fn!.group(1)!)
          .map((m) => m.group(1)!)
          .toSet();
      for (final key in map.keys) {
        expect(allowed.contains(key), isTrue,
            reason: 'AcademicAssignment.toMap key "$key" missing from isValidHomework whitelist');
      }
    });

    test('AcademicReportCard round-trips imageUrl', () {
      final card = AcademicReportCard(
        id: 'rep_2310910_term_1_mid_term',
        scholarNo: '2310910',
        studentName: 'Test Scholar',
        termName: 'Term 1 Mid-Term',
        overallGpa: 3.9,
        overallPercentage: 93.0,
        publishedAt: DateTime(2026, 11, 1),
        imageUrl: _kTestPhoto,
      );
      final map = card.toMap();
      expect(map['image_url'], _kTestPhoto);
      final restored = AcademicReportCard.fromMap(map);
      expect(restored.imageUrl, _kTestPhoto);
      expect(restored.scholarNo, '2310910');
      expect(card.copyWith().imageUrl, _kTestPhoto);
      expect(card.copyWith(imageUrl: '').toMap().containsKey('image_url'), isFalse);
      expect(AcademicReportCard.fromMap({'imageUrl': _kTestPhoto}).imageUrl, _kTestPhoto);
    });

    test('ExamScheduleItem imageUrl regression (pre-existing feature)', () {
      final exam = ExamScheduleItem(
        id: 'exam_img',
        subject: 'Chemistry',
        paperTitle: 'Paper 1',
        examDateTime: DateTime(2026, 11, 12, 8, 30),
        examHall: 'Main Hall',
        imageUrl: _kTestPhoto,
      );
      expect(exam.toMap()['image_url'], _kTestPhoto);
      expect(ExamScheduleItem.fromMap(exam.toMap()).imageUrl, _kTestPhoto);
    });
  });

  group('firestore.rules image_url contract', () {
    test('isValidHomework whitelists image_url with a 500000-char cap', () {
      final rules = File('firestore.rules').readAsStringSync();
      final fn = RegExp(
        r'function isValidHomework\(data\) \{[\s\S]*?\n    \}',
      ).firstMatch(rules);
      expect(fn, isNotNull);
      final body = fn!.group(0)!;
      expect(body.contains("'image_url'"), isTrue);
      expect(
        body.contains("data.image_url is string && data.image_url.size() <= 500000"),
        isTrue,
        reason: 'image_url must be a capped string to prevent oversized payloads',
      );
    });
  });

  group('Academic image widgets', () {
    testWidgets('upload field shows picker buttons when empty and Remove when set',
        (tester) async {
      String? value;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => AcademicImageUploadField(
              label: 'Worksheet Photo',
              value: value,
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      ));

      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Upload Image'), findsOneWidget);
      expect(find.text('Remove'), findsNothing);

      // Simulate a picked photo via the callback contract.
      final field = tester.widget<AcademicImageUploadField>(
        find.byType(AcademicImageUploadField),
      );
      field.onChanged(_kTinyPng);
      await tester.pump();

      expect(find.text('Remove'), findsOneWidget);
      expect(find.text('Take Photo'), findsNothing);
      expect(value, _kTinyPng);

      await tester.tap(find.text('Remove'));
      await tester.pump();
      expect(value, isNull);
      expect(find.text('Take Photo'), findsOneWidget);
    });

    testWidgets('thumbnail opens zoomable preview dialog on tap', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: AcademicImageThumbnail(
            imageUrl: _kTinyPng,
            title: 'Physics — P3',
            height: 110,
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('View Photo'), findsOneWidget);
      await tester.tap(find.byType(AcademicImageThumbnail));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Physics — P3'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('broken base64 falls back to broken-image icon', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 100,
            child: AcademicImageThumbnail(
              imageUrl: 'data:image/jpeg;base64,!!!not-base64!!!',
              title: 'Broken',
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(find.byIcon(Icons.broken_image_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}