// _holes75.dart -- where does m74's ONE-CHARACTER obligation actually break?
//
// m74 carries a character class as its forward obligation. Three separate
// mechanisms produce one:
//   `_notFirst`  (m74.dart:260) -- taking branch k means every earlier branch
//                must fail; approximated as "the next character is not in
//                FIRST(branch j)", and DROPPED ENTIRELY (`_free`) when branch j
//                does not match exactly one character.
//   `_looks`     (m74.dart:292) -- `&P` / `!P`; same approximation, same drop.
//   the possessive stop -- after `X*`, the next character must not continue X.
//
// _subset74's twelve grammars only ever put a ONE-CHARACTER clause in the
// dropped position, so the drop is largely untested there. These grammars put a
// multi-character clause in each of the three positions on purpose. Truth is
// brute-force over the edit ball, exactly as _subset74 computes it.
import 'dart:io';

import 'package:squirrel_parser/squirrel_parser.dart';
import 'm74.dart' as e74;

bool inLang(Map<String, Clause> r, String t, String s) {
  final p = Parser(rules: r, topRuleName: t, input: s).parse();
  return !p.hasSyntaxErrors && p.root.len == s.length;
}

int? trueDist(
    Map<String, Clause> r, String t, String s, String alpha, int maxK) {
  var frontier = {s};
  final seen = {s};
  for (var k = 0; k <= maxK; k++) {
    for (final c in frontier) {
      if (inLang(r, t, c)) return k;
    }
    final next = <String>{};
    for (final c in frontier) {
      for (var i = 0; i < c.length; i++) {
        final del = c.substring(0, i) + c.substring(i + 1);
        if (seen.add(del)) next.add(del);
      }
      for (var i = 0; i <= c.length; i++) {
        for (final ch in alpha.split('')) {
          final ins = c.substring(0, i) + ch + c.substring(i);
          if (seen.add(ins)) next.add(ins);
          if (i < c.length) {
            final sub = c.substring(0, i) + ch + c.substring(i + 1);
            if (seen.add(sub)) next.add(sub);
          }
        }
      }
    }
    frontier = next;
  }
  return null;
}

/// (grammar, top rule, alphabet, which mechanism this grammar aims at)
final probes = <(String, String, String, String)>[
  // --- ordered choice: the EARLIER branch is the one that must fail ---------
  ("S <- ('a' / \"ab\") 'b';\n", 'S', 'ab', 'choice, earlier branch 1 char'),
  ("S <- (\"ab\" / 'a') 'b';\n", 'S', 'ab', 'choice, earlier branch 2 chars'),
  ("S <- (A / 'a') 'b';\nA <- \"ab\";\n", 'S', 'ab',
      'choice, earlier branch 2 chars via rule'),
  ("S <- (\"ab\" / 'a' / 'b') 'c';\n", 'S', 'abc',
      'choice, three branches, earlier 2 chars'),
  // --- lookahead: the body is the thing that must (not) match --------------
  ("S <- &'a' 'a' 'b';\n", 'S', 'ab', 'lookahead body 1 char'),
  ("S <- &\"ab\" 'a' 'b';\n", 'S', 'ab', 'lookahead body 2 chars'),
  ("S <- !\"ab\" 'a' 'c';\n", 'S', 'abc', 'neg lookahead body 2 chars'),
  ("S <- &(A 'b') A 'b' 'x';\nA <- 'a'*;\n", 'S', 'abx',
      'lookahead body star+char (known 97)'),
  ("S <- !('a' 'b') . 'c';\n", 'S', 'abc', 'neg lookahead body 2 chars, dot'),
  // --- possessive star: the stop is an obligation too -----------------------
  ("S <- 'a'* \"ab\";\n", 'S', 'ab', 'star body 1 char'),
  ("S <- (\"ab\")* 'a' 'c';\n", 'S', 'abc', 'star body 2 chars'),
  ("S <- ('a' 'b')* !.;\n", 'S', 'ab', 'star body 2 chars, end anchor'),
];

void main() {
  var totalChecked = 0, totalWrong = 0;
  final rows = <String>[];
  for (final (g, top, alpha, what) in probes) {
    final r = MetaGrammar.parseGrammar(g);
    final engine = e74.SuperDot3(rules: r, topRuleName: top);
    final strings = <String>[''];
    for (var len = 1; len <= 5; len++) {
      for (final p in strings.where((s) => s.length == len - 1).toList()) {
        for (final ch in alpha.split('')) {
          strings.add(p + ch);
        }
      }
    }
    var checked = 0, wrong = 0;
    final examples = <String>[];
    for (final s in strings) {
      final truth = trueDist(r, top, s, alpha, 3);
      final c = engine.recoverCost(s);
      final ok = truth == null ? (c > 3 || c == -1) : c == truth;
      checked++;
      if (!ok) {
        wrong++;
        if (examples.length < 3) {
          examples.add('"$s" true=${truth ?? ">3"} m74=$c');
        }
      }
    }
    totalChecked += checked;
    totalWrong += wrong;
    rows.add('${wrong.toString().padLeft(4)}/${checked.toString().padLeft(4)}  '
        '${what.padRight(38)} ${g.replaceAll('\n', ' ').trim()}'
        '${examples.isEmpty ? '' : '\n           ${examples.join('  |  ')}'}');
  }
  stdout.writeln('m74 wrong / checked, by which obligation the grammar '
      'stresses\n');
  for (final row in rows) {
    stdout.writeln(row);
  }
  stdout.writeln('\ntotal $totalWrong wrong of $totalChecked');
}
