// THROWAWAY (MemNote NOTE-179). Summarises a `flutter test --file-reporter=json:...`
// report into per-suite totals so the mac/linux/windows gap can be attributed.
//
// Usage: dart run ci_timings.dart <report.json> <label>
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

/// The report carries absolute paths, which differ per runner. Reduce them to the
/// repo-relative `test/...` form so the three OSes can be joined on the path.
String _normalisePath(String raw) {
  final unix = raw.replaceAll(r'\', '/');
  final at = unix.lastIndexOf('/test/');
  return at < 0 ? unix : unix.substring(at + 1);
}

class Suite {
  Suite(this.path);
  final String path;
  int loadMs = 0;
  int testMs = 0;
  int testCount = 0;
}

void main(List<String> args) {
  final file = File(args[0]);
  final label = args.length > 1 ? args[1] : 'run';

  final suitesById = <int, Suite>{};
  final suiteIdByTestId = <int, int>{};
  final startByTestId = <int, int>{};
  final nameByTestId = <int, String>{};
  int doneMs = 0;
  int firstRealTestStartMs = -1;

  for (final line in file.readAsLinesSync()) {
    if (line.isEmpty || !line.startsWith('{')) {
      continue;
    }
    final Map<String, dynamic> event = jsonDecode(line) as Map<String, dynamic>;
    switch (event['type']) {
      case 'suite':
        final suite = event['suite'] as Map<String, dynamic>;
        suitesById[suite['id'] as int] = Suite(_normalisePath(suite['path'] as String));
      case 'testStart':
        final test = event['test'] as Map<String, dynamic>;
        final id = test['id'] as int;
        final name = test['name'] as String;
        suiteIdByTestId[id] = test['suiteID'] as int;
        startByTestId[id] = event['time'] as int;
        nameByTestId[id] = name;
        if (!name.startsWith('loading ') && firstRealTestStartMs < 0) {
          firstRealTestStartMs = event['time'] as int;
        }
      case 'testDone':
        final id = event['testID'] as int;
        final start = startByTestId[id];
        final suite = suitesById[suiteIdByTestId[id]];
        if (start == null || suite == null) {
          continue;
        }
        final elapsed = (event['time'] as int) - start;
        if (nameByTestId[id]!.startsWith('loading ')) {
          suite.loadMs += elapsed;
        } else {
          suite.testMs += elapsed;
          suite.testCount++;
        }
      case 'done':
        doneMs = event['time'] as int;
    }
  }

  final suites = suitesById.values.toList()..sort((a, b) => b.testMs.compareTo(a.testMs));
  final totalLoad = suites.fold<int>(0, (sum, s) => sum + s.loadMs);
  final totalTest = suites.fold<int>(0, (sum, s) => sum + s.testMs);
  final totalCount = suites.fold<int>(0, (sum, s) => sum + s.testCount);

  stdout.writeln('### NOTE-179 timings: $label');
  stdout.writeln('os=${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
  stdout.writeln('Platform.numberOfProcessors=${Platform.numberOfProcessors}');
  stdout.writeln('package:test defaultConcurrency=${math.max(1, Platform.numberOfProcessors ~/ 2)}');
  stdout.writeln('wall_ms=$doneMs suites=${suites.length} tests=$totalCount');
  stdout.writeln('sum_load_ms=$totalLoad sum_test_ms=$totalTest first_real_test_at_ms=$firstRealTestStartMs');
  stdout.writeln('parallel_speedup=${(totalLoad + totalTest) / math.max(1, doneMs)}');
  stdout.writeln('--- top 25 suites by summed test time ---');
  for (final s in suites.take(25)) {
    stdout.writeln('  ${s.testMs}ms test / ${s.loadMs}ms load / ${s.testCount} tests  ${s.path}');
  }
  final byLoad = suites.toList()..sort((a, b) => b.loadMs.compareTo(a.loadMs));
  stdout.writeln('--- top 10 suites by load (compile) time ---');
  for (final s in byLoad.take(10)) {
    stdout.writeln('  ${s.loadMs}ms load / ${s.testMs}ms test  ${s.path}');
  }
  stdout.writeln('--- CSV: label,path,test_ms,load_ms,test_count ---');
  for (final s in suites) {
    stdout.writeln('CSV,$label,${s.path},${s.testMs},${s.loadMs},${s.testCount}');
  }
}
