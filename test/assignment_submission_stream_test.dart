import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:asb_house_hub/models/academic_assignment.dart';
import 'package:asb_house_hub/services/assignment_submission_stream.dart';

void main() {
  test(
    'submission snapshots restore notes and deliver later grading updates',
    () async {
      final tasks = StreamController<List<AcademicAssignment>>();
      final own = StreamController<Map<String, dynamic>?>();
      final results = <List<AcademicAssignment>>[];
      final subscription = watchAssignmentSubmissions(
        tasks.stream,
        (_) => own.stream,
      ).listen(results.add);
      final task = AcademicAssignment(
        id: 'hw',
        title: 'Essay',
        subject: 'English',
        teacherName: 'Teacher',
        dueDateTime: DateTime(2026, 12),
      );
      tasks.add([task]);
      await Future<void>.delayed(Duration.zero);
      expect(results, isEmpty);
      own.add({
        'status': 'submitted',
        'submission_notes': 'Answer https://example.com/work',
      });
      await Future<void>.delayed(Duration.zero);
      expect(results.single.single.status, AssignmentStatus.submitted);
      expect(
        results.single.single.submissionNotes,
        contains('https://example.com/work'),
      );
      own.add({
        'status': 'graded',
        'submission_notes': 'Answer https://example.com/work',
      });
      await Future<void>.delayed(Duration.zero);
      expect(results.last.single.status, AssignmentStatus.graded);
      await subscription.cancel();
      expect(own.hasListener, isFalse);
      await tasks.close();
      await own.close();
    },
  );

  test(
    'deleting tasks cancels submission listeners and publishes an empty list',
    () async {
      final tasks = StreamController<List<AcademicAssignment>>();
      final own = StreamController<Map<String, dynamic>?>();
      final results = <List<AcademicAssignment>>[];
      final subscription = watchAssignmentSubmissions(
        tasks.stream,
        (_) => own.stream,
      ).listen(results.add);
      tasks.add([
        AcademicAssignment(
          id: 'hw',
          title: 'Essay',
          subject: 'English',
          teacherName: 'Teacher',
          dueDateTime: DateTime(2026, 12),
        ),
      ]);
      await Future<void>.delayed(Duration.zero);
      own.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(results.single.single.status, AssignmentStatus.pending);
      tasks.add([]);
      await Future<void>.delayed(Duration.zero);
      expect(results.last, isEmpty);
      expect(own.hasListener, isFalse);
      await subscription.cancel();
      await tasks.close();
      await own.close();
    },
  );
}
