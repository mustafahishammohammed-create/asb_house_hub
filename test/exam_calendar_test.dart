import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:asb_house_hub/models/exam_schedule_item.dart';
import 'package:asb_house_hub/screens/academics_screen.dart';
import 'package:asb_house_hub/services/auth_service.dart';
import 'package:asb_house_hub/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Exam Calendar & Schedule Regression Suite', () {
    test('ExamScheduleItem.isUrgent handles final minute and calendar-day tomorrow countdown', () {
      final now = DateTime(2026, 10, 10, 23, 0);
      final finalMinuteExam = ExamScheduleItem(
        id: 'final_min',
        subject: 'Physics',
        paperTitle: 'Wave Optics',
        examDateTime: now.add(const Duration(seconds: 30)),
        examHall: 'Hall A',
      );
      expect(finalMinuteExam.isUrgent(now), isTrue);
      expect(finalMinuteExam.formattedCountdown(now), 'Starts in 1m');

      final tomorrowLateExam = ExamScheduleItem(
        id: 'tomorrow_late',
        subject: 'Chemistry',
        paperTitle: 'Organic Paper',
        examDateTime: DateTime(2026, 10, 11, 23, 30),
        examHall: 'Hall B',
      );
      expect(tomorrowLateExam.formattedCountdown(now), 'Starts Tomorrow');

      final epochParsed = ExamScheduleItem.fromMap({
        'id': 'epoch_1',
        'subject': 'Mathematics',
        'paper_title': 'Calculus',
        'exam_date_time': DateTime(2026, 10, 12, 9, 0).millisecondsSinceEpoch,
        'exam_hall': 'Main Hall',
      });
      expect(epochParsed.examDateTime, DateTime(2026, 10, 12, 9, 0));
    });

    test('AuthService publish, update, and delete exam schedule items update local cache', () async {
      SharedPreferences.setMockInitialValues({});
      await AuthService.cacheProfile({
        'scholar_no': '100001',
        'role': 'teacher',
        'class_level': 'Grade 10',
      });
      final auth = AuthService();
      final examDate = DateTime(2026, 11, 15, 8, 30);

      await auth.publishExamScheduleRange(
        fromGrade: 'Grade 10',
        toGrade: 'Grade 11',
        subject: 'Biology',
        paperTitle: 'Genetics & Evolution',
        examDateTime: examDate,
        examHall: 'Bio Wing',
      );

      final cached10 = AuthService.getCachedExamSchedule(classLevel: 'Grade 10');
      final cached11 = AuthService.getCachedExamSchedule(classLevel: 'Grade 11');
      expect(cached10.any((e) => e.subject == 'Biology'), isTrue);
      expect(cached11.any((e) => e.subject == 'Biology'), isTrue);

      final created = cached10.firstWhere((e) => e.subject == 'Biology');
      await auth.updateExamScheduleItem(created.copyWith(examHall: 'Updated Hall'));
      final updated = AuthService.getCachedExamSchedule(classLevel: 'Grade 10')
          .firstWhere((e) => e.id == created.id);
      expect(updated.examHall, 'Updated Hall');

      await auth.deleteExamScheduleItem(examId: created.id, classLevel: 'Grade 10');
      final afterDelete = AuthService.getCachedExamSchedule(classLevel: 'Grade 10');
      expect(afterDelete.any((e) => e.id == created.id), isFalse);
    });

    testWidgets('ExamsTab groups upcoming before concluded papers and filters all subjects', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final now = DateTime(2026, 10, 10, 9, 0);
      final exams = [
        ExamScheduleItem(
          id: 'ex_past',
          subject: 'History',
          paperTitle: 'Modern History',
          examDateTime: now.subtract(const Duration(days: 2)),
          durationMinutes: 90,
          examHall: 'Hall C',
        ),
        ExamScheduleItem(
          id: 'ex_future_bio',
          subject: 'Biology',
          paperTitle: 'Cell Biology',
          examDateTime: now.add(const Duration(days: 3)),
          durationMinutes: 90,
          examHall: 'Lab Wing',
        ),
        ExamScheduleItem(
          id: 'ex_soon_math',
          subject: 'Mathematics',
          paperTitle: 'Algebra Paper',
          examDateTime: now.add(const Duration(hours: 6)),
          durationMinutes: 90,
          examHall: 'Hall A',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ExamsTab(
              classLevel: 'Grade 10',
              mockNow: now,
              initialExams: exams,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Concluded Examinations (1)'), findsOneWidget);
      final mathY = tester.getTopLeft(find.byKey(const Key('exam_card_ex_soon_math'))).dy;
      final bioY = tester.getTopLeft(find.byKey(const Key('exam_card_ex_future_bio'))).dy;
      final pastY = tester.getTopLeft(find.byKey(const Key('exam_card_ex_past'))).dy;
      expect(mathY, lessThan(bioY));
      expect(bioY, lessThan(pastY));

      // Scroll filter bar to Biology and verify Biology filter pill exists and works
      final bioFilter = find.text('Biology');
      await tester.scrollUntilVisible(bioFilter, 120, scrollable: find.byType(Scrollable).first);
      await tester.tap(bioFilter);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('exam_card_ex_future_bio')), findsOneWidget);
      expect(find.byKey(const Key('exam_card_ex_soon_math')), findsNothing);
    });
  });
}
