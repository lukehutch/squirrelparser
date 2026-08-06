// What holding the children costs. A mismatch used to be one shared tombstone;
// now every failure allocates a node and a list, and a memoized rule-level
// mismatch retains the subtree it failed through for the life of the parse.
// This measures the two things that could go wrong: time, and retained bytes.
import 'dart:io';

import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';

/// A large document that parses cleanly except for one break near the end, so
/// the memo table is full and the failure is deep.
String doc(int n, {required bool broken}) {
  final b = StringBuffer('[');
  for (var i = 0; i < n; i++) {
    if (i > 0) b.write(',');
    b.write('{"k$i":[1,2,3],"s":"str$i","t":true,"z":null}');
  }
  if (broken) b.write(',{"k":'); // unterminated: fails at maximum depth
  b.write(']');
  return b.toString();
}

void main() {
  final rules = MetaGrammar.parseGrammar(
      corpora.firstWhere((c) => c.name == 'json').grammar);

  for (final broken in [false, true]) {
    for (final n in [200, 400, 800, 1600]) {
      final s = doc(n, broken: broken);
      // Keep the parsers alive so retained memory is measured, not collected.
      final held = <Parser>[];
      final sw = Stopwatch()..start();
      for (var i = 0; i < 4; i++) {
        final p = Parser(rules: rules, topRuleName: 'JSON', input: s);
        p.parse();
        held.add(p);
      }
      sw.stop();
      final rss = ProcessInfo.currentRss;
      print('broken=$broken n=$n len=${s.length} '
          'ms=${sw.elapsedMilliseconds} rssMB=${(rss / 1048576).toStringAsFixed(1)} '
          'held=${held.length}');
    }
  }
}
