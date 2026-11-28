import 'dart:async';

import '../models/academic_assignment.dart';

/// Joins class tasks with the signed-in scholar's own submission snapshots.
/// Waits for the first submission snapshot before publishing a refreshed list.
Stream<List<AcademicAssignment>> watchAssignmentSubmissions(
  Stream<List<AcademicAssignment>> assignments,
  Stream<Map<String, dynamic>?> Function(String assignmentId) submissionFor,
) {
  late StreamController<List<AcademicAssignment>> controller;
  StreamSubscription<List<AcademicAssignment>>? parent;
  final children = <StreamSubscription<Map<String, dynamic>?>>[];
  var generation = 0;
  var cancelled = false;
  controller = StreamController<List<AcademicAssignment>>(
    onListen: () {
      parent = assignments.listen((tasks) async {
        final current = ++generation;
        final old = List.of(children);
        children.clear();
        await Future.wait(old.map((s) => s.cancel()));
        if (cancelled || current != generation) return;
        if (tasks.isEmpty) {
          controller.add([]);
          return;
        }
        final values = <String, Map<String, dynamic>?>{};
        for (final task in tasks) {
          children.add(
            submissionFor(task.id).listen(
              (submission) {
                if (cancelled || current != generation) return;
                values[task.id] = submission;
                if (values.length != tasks.length) return;
                controller.add(
                  tasks.map((task) {
                    final data = values[task.id];
                    return data == null
                        ? task
                        : AcademicAssignment.fromMap({
                            ...task.toMap(),
                            'status': data['status'] ?? task.status.name,
                            'submission_notes': data['submission_notes'] ?? '',
                            'submitted_at': data['submitted_at'],
                            'graded_at': data['graded_at'],
                          }, task.id);
                  }).toList(),
                );
              },
              onError: (Object e, StackTrace stack) {
                if (!cancelled && current == generation) {
                  controller.addError(e, stack);
                }
              },
            ),
          );
        }
      }, onError: controller.addError);
    },
    onCancel: () async {
      cancelled = true;
      generation++;
      await parent?.cancel();
      await Future.wait(children.map((s) => s.cancel()));
      children.clear();
    },
  );
  return controller.stream;
}
