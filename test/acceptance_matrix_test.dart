import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Enforceable guard for `development_plan/ACCEPTANCE_MATRIX.md`.
///
/// This does not pretend to execute Firebase emulator denials. It guarantees
/// that the 64-row matrix is complete, that every cited test file exists, that
/// the documented PASS/PARTIAL counts match the summary, and that the key
/// deployed rules contracts have not regressed.
void main() {
  final matrixFile = File('development_plan/ACCEPTANCE_MATRIX.md');
  final rulesFile = File('firestore.rules');

  late String content;
  late String rules;
  late Map<int, List<String>> rows;

  setUpAll(() {
    expect(matrixFile.existsSync(), isTrue,
        reason: 'ACCEPTANCE_MATRIX.md must exist');
    expect(rulesFile.existsSync(), isTrue);

    content = matrixFile.readAsStringSync();
    rules = rulesFile.readAsStringSync();

    final matrixStart = content.indexOf('## Matrix');
    final openStart = content.indexOf('## Open partials');
    expect(matrixStart, greaterThanOrEqualTo(0));
    expect(openStart, greaterThan(matrixStart));

    final matrixSection = content.substring(matrixStart, openStart);
    rows = <int, List<String>>{};
    for (final line in const LineSplitter().convert(matrixSection)) {
      final match = RegExp(r'^\|\s*(\d+)\s*\|').firstMatch(line);
      if (match == null) continue;
      final parts = line.split('|');
      final cells = parts
          .sublist(1, parts.length - 1)
          .map((cell) => cell.trim())
          .toList();
      rows[int.parse(match.group(1)!)] = cells;
    }
  });

  test('matrix contains exactly tests 1-64 with seven columns each', () {
    expect(rows.length, 64);
    expect(rows.keys.toSet(), Set<int>.from(List.generate(64, (i) => i + 1)));
    for (final entry in rows.entries) {
      expect(entry.value.length, 7,
          reason: 'Test ${entry.key} must have 7 columns');
      for (final cell in entry.value) {
        expect(cell, isNotEmpty, reason: 'Test ${entry.key} has an empty cell');
      }
    }
  });

  test('statuses are valid and the summary matches the rows', () {
    final statuses = rows.values.map((cells) => cells[5]).toList();
    expect(
      statuses.every((status) => status == 'PASS' || status == 'PARTIAL'),
      isTrue,
      reason: 'Only PASS and PARTIAL are allowed; MISSING must be fixed',
    );

    final passCount = statuses.where((status) => status == 'PASS').length;
    final partialCount =
        statuses.where((status) => status == 'PARTIAL').length;
    final missingCount =
        statuses.where((status) => status == 'MISSING').length;

    final summary = RegExp(
      r'\*\*Summary:\*\* \*\*(\d+) PASS · (\d+) PARTIAL · (\d+) MISSING\*\*',
    ).firstMatch(content);
    expect(summary, isNotNull, reason: 'Summary line is required');
    expect(int.parse(summary!.group(1)!), passCount);
    expect(int.parse(summary.group(2)!), partialCount);
    expect(int.parse(summary.group(3)!), missingCount);
    expect(missingCount, 0);
    expect(content, contains('PARTIAL is not counted as a completed test'));
  });

  test('no acceptance rows remain partial or missing', () {
    final partialIds = rows.entries
        .where((entry) => entry.value[5] == 'PARTIAL')
        .map((entry) => entry.key)
        .toSet();
    expect(partialIds, isEmpty);

    // Test 5 is closed by the rules contract, not by weakening the row.
    expect(rows[5]![5], 'PASS');
    expect(rows[5]![3], contains('test 5: students cannot list another class'));
    expect(
      rows[5]![4].toLowerCase(),
      contains('isverifiedclassmember'),
    );
  });

  test('test 14 is closed by the break-recalculation widget test', () {
    expect(rows[14]![5], 'PASS');
    expect(
      rows[14]![3],
      contains('Moving the break recalculates all period times'),
    );
  });

  test('tests 24 and 25 are closed by direct time-picker interactions', () {
    expect(rows[24]![5], 'PASS');
    expect(
      rows[24]![3],
      contains('Customise Period 1 start with the time picker'),
    );

    expect(rows[25]![5], 'PASS');
    expect(
      rows[25]![3],
      contains('Customise a later period independently'),
    );
  });

  test('every cited test file exists', () {
    final references = RegExp(r'test/[A-Za-z0-9_]+\.dart')
        .allMatches(content)
        .map((match) => match.group(0)!)
        .toSet();
    expect(references.length, greaterThanOrEqualTo(10));
    for (final path in references) {
      expect(File(path).existsSync(), isTrue, reason: 'Missing $path');
    }
  });

  test('key rules contracts are still present', () {
    // P0-01: exact bootstrap emails only; no prefix elevation.
    expect(
      rules.contains(
        "request.auth.token.email in ['admin@asianschool.bh', '11209@asianschool.bh']",
      ),
      isTrue,
    );
    expect(rules.contains("matches('(?i)^admin@.*')"), isFalse);
    expect(rules.contains("matches('(?i)^11209@.*')"), isFalse);

    // Owners cannot rewrite their class/verification/status.
    // Whitespace is normalized so the contract survives multi-line formatting.
    final normalizedRules = rules.replaceAll(RegExp(r'\s+'), ' ');
    expect(
      normalizedRules.contains(
        "'role', 'points', 'points_contributed', 'scholar_no', "
        "'created_at', 'uid', 'class_id', 'class_verified', 'status'",
      ),
      isTrue,
    );

    // Notification ownership and dedupe read-state protection.
    expect(
      rules.contains(
        "request.resource.data.diff(resource.data).affectedKeys().hasOnly(['is_read'])",
      ),
      isTrue,
    );
    expect(
      rules.contains("'title', 'body', 'timestamp', 'type', 'room_id',"),
      isTrue,
    );

    // Append-only audit and immutable published timetables.
    expect(
      rules.contains(
        'allow update, delete: if false; // strictly immutable and append-only',
      ),
      isTrue,
    );
    expect(rules.contains("resource.data.status != 'published'"), isTrue);

    // Class, house, and class-group scoping helpers remain in place.
    expect(rules.contains('getUserData().class_id == classId'), isTrue);
    expect(rules.contains('isSameHouse(houseId)'), isTrue);
    expect(rules.contains('isVerifiedClassMember(classId)'), isTrue);
    expect(rules.contains('function isAdmin()'), isTrue);

    // Test 5: student timetable reads are class-scoped, and the old broad
    // signed-in published clause cannot return.
    expect(
      rules.contains('isVerifiedClassMember(resource.data.class_id)'),
      isTrue,
    );
    expect(
      rules.contains(
        "(isSignedIn() && resource != null && resource.data.status == 'published')",
      ),
      isFalse,
    );
  });
}
