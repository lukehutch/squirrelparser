// _m77diff.dart -- exactly where m77's cost leaves m74's, and why.
import 'dart:io';

import 'package:squirrel_parser/squirrel_parser.dart';
import 'm74.dart' as e74;
import 'm77.dart' as e75;

final grammars = <(String, String, String)>[
  ("S <- 'a'* \"ab\";\n", 'S', 'ab'),
  ("S <- ('a' / \"ab\") 'b';\n", 'S', 'ab'),
  ("S <- A 'c';\nA <- 'a' / \"ab\";\n", 'S', 'abc'),
  ("S <- 'a'? \"ab\";\n", 'S', 'ab'),
  ("S <- &(A 'b') A 'b' 'x';\nA <- 'a'*;\n", 'S', 'abx'),
];

void main() {
  for (final (g, top, alpha) in grammars) {
    final r = MetaGrammar.parseGrammar(g);
    final strings = <String>[''];
    for (var len = 1; len <= 4; len++) {
      for (final p in strings.where((s) => s.length == len - 1).toList()) {
        for (final ch in alpha.split('')) {
          strings.add(p + ch);
        }
      }
    }
    var diff = 0;
    final ex = <String>[];
    for (final s in strings) {
      final a = e74.SuperDot3(rules: r, topRuleName: top);
      final b = e75.SuperDot3(rules: r, topRuleName: top);
      final ca = a.recoverCost(s), cb = b.recoverCost(s);
      if (ca == cb) continue;
      diff++;
      if (ex.length < 5) {
        ex.add('"$s" m74=$ca(v=${a.lastVerified}) m77=$cb(v=${b.lastVerified})');
      }
    }
    stdout.writeln('${diff.toString().padLeft(4)} diffs / ${strings.length}  '
        '${g.replaceAll('\n', ' ').trim()}');
    if (ex.isNotEmpty) stdout.writeln('      ${ex.join('  |  ')}');
  }
}
