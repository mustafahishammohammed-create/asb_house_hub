import 'dart:io';

void main() {
  final libDir = Directory('lib');
  final dartFiles = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  print('Scanning ${dartFiles.length} files in lib/ for async gaps...');
  int totalAsyncGaps = 0;

  for (final file in dartFiles) {
    final lines = file.readAsLinesSync();
    bool inAsyncFunction = false;
    int lastAwaitLine = -1;
    bool checkedMountedSinceAwait = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      // Simple heuristic for async function boundary
      if (trimmed.contains('async {') || trimmed.contains('async =>')) {
        inAsyncFunction = true;
        lastAwaitLine = -1;
        checkedMountedSinceAwait = false;
      }

      if (inAsyncFunction) {
        if (trimmed.startsWith('await ') || trimmed.contains(' await ')) {
          lastAwaitLine = i + 1;
          checkedMountedSinceAwait = false;
        }

        if (trimmed.contains('mounted') || trimmed.contains('!mounted')) {
          checkedMountedSinceAwait = true;
        }

        if (lastAwaitLine != -1 && !checkedMountedSinceAwait) {
          // Check if line uses setState or BuildContext (Navigator, ScaffoldMessenger, Theme.of, MediaQuery.of, showDialog, showModalBottomSheet)
          final hasSetState = trimmed.contains('setState(') || trimmed.contains('setState(()');
          final hasContextUsage = (trimmed.contains('Navigator.') ||
                  trimmed.contains('ScaffoldMessenger.') ||
                  trimmed.contains('showDialog(') ||
                  trimmed.contains('showModalBottomSheet(')) &&
              (trimmed.contains('context') || trimmed.contains('ctx'));

          if (hasSetState || hasContextUsage) {
            print('${file.path}:${i + 1} -> [After await at line $lastAwaitLine] ${hasSetState ? "UNGUARDED setState" : "UNGUARDED context/Navigator"}: "$trimmed"');
            totalAsyncGaps++;
          }
        }

        // End of function scope (rough check)
        if (trimmed == '}' && lastAwaitLine != -1 && i - lastAwaitLine > 50) {
          inAsyncFunction = false;
          lastAwaitLine = -1;
        }
      }
    }
  }

  print('\nTotal async gap occurrences flagged: $totalAsyncGaps');
}
