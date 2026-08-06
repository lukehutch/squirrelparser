// Deterministic differential sweep for the eight isolated rework changes.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'r5.dart' as r5;
import '_v1.dart' as v1;
import '_v2.dart' as v2;
import '_v3.dart' as v3;
import '_v4.dart' as v4;
import '_v5.dart' as v5;
import '_v8.dart' as v8;
import '_v9.dart' as v9;
import '_v10.dart' as v10;
import '_v13.dart' as v13;
import '_v14.dart' as v14;
import '_v15.dart' as v15;
import '_codex_audit26_safe.dart' as safe;
import '_codex_audit26_deferred.dart' as lazy;

typedef Make = dynamic Function(Map<String, Clause> rules, String top);

String ser(MatchResult m) {
  final b = StringBuffer();
  void walk(MatchResult n) {
    b.write('${n.runtimeType}:${n.clause}:${n.pos}:${n.len}(');
    for (final child in n.subClauseMatches) {
      walk(child);
    }
    b.write(')');
  }

  walk(m);
  return b.toString();
}

String run(dynamic engine, String input) {
  try {
    final tree = engine.recover(input) as MatchResult;
    return '${engine.lastCost}|${ser(tree)}';
  } catch (e) {
    return 'THREW ${e.runtimeType}:$e';
  }
}

List<String> words(String alphabet, int max) {
  var out = <String>[''];
  var edge = <String>[''];
  for (var n = 0; n < max; n++) {
    edge = [
      for (final p in edge)
        for (final c in alphabet.split('')) '$p$c'
    ];
    out.addAll(edge);
  }
  return out;
}

void main(List<String> args) {
  final atoms = ["'a'", "'b'", '"ab"', '.', '[ab]', '[^a]'];
  final small = <String>{
    ...atoms,
    for (final a in atoms) '$a?',
    for (final a in atoms) '$a*',
    for (final a in atoms) '$a+',
    for (final a in atoms.take(4))
      for (final b in atoms.take(4)) '($a $b)',
    for (final a in atoms.take(5))
      for (final b in atoms.take(5)) '($a / $b)',
  }.toList();
  final grammars = <String>{
    for (final e in small) 'S <- $e;',
    for (final e in small) 'S <- A; A <- $e;',
    for (final e in small) 'S <- A; A <- B; B <- $e;',
    for (final e in small.take(40)) "S <- ('x'? A) A; A <- B; B <- $e;",
    for (final e in small.take(40)) "S <- A; A <- A 'a' / $e;",
    for (final e in small.take(40)) "S <- A; A <- B / $e; B <- A 'b';",
    for (final e in small.take(40)) 'S <- A*; A <- A \'a\' / $e;',
    for (final e in small.take(40)) 'S <- (A / $e)*; A <- A \'a\' / $e;',
    "S <- ((. 'b') / [ab])*;",
    'S <- S;',
    "S <- 'a' S;",
    "S <- S 'a'? / 'b';",
    "S <- (A? 'a')*; A <- A 'b' / 'b';",
  }.toList();
  final inputs = words('abcx', args.contains('wide') ? 4 : 3);
  final variants = <String, (Make, Make)>{
    '1-ref': (
      (r, t) => r5.Squirrel(rules: r, topRuleName: t),
      (r, t) => v1.Squirrel(rules: r, topRuleName: t)
    ),
    '2-afford': (
      (r, t) => r5.Squirrel(rules: r, topRuleName: t),
      (r, t) => v2.Squirrel(rules: r, topRuleName: t)
    ),
    '3-seq': (
      (r, t) => r5.Squirrel(rules: r, topRuleName: t),
      (r, t) => v3.Squirrel(rules: r, topRuleName: t)
    ),
    '4-close': (
      (r, t) => r5.Squirrel(rules: r, topRuleName: t),
      (r, t) => v4.Squirrel(rules: r, topRuleName: t)
    ),
    '5-work': (
      (r, t) => r5.Squirrel(rules: r, topRuleName: t),
      (r, t) => v5.Squirrel(rules: r, topRuleName: t)
    ),
    '6-memo': (
      (r, t) => v8.Squirrel(rules: r, topRuleName: t),
      (r, t) => v9.Squirrel(rules: r, topRuleName: t)
    ),
    '7-prune2': (
      (r, t) => v15.Squirrel(rules: r, topRuleName: t),
      (r, t) => v13.Squirrel(rules: r, topRuleName: t)
    ),
    '8-improved': (
      (r, t) => r5.Squirrel(rules: r, topRuleName: t),
      (r, t) => v14.Squirrel(rules: r, topRuleName: t)
    ),
    '13-all': (
      (r, t) => r5.Squirrel(rules: r, topRuleName: t),
      (r, t) => v13.Squirrel(rules: r, topRuleName: t)
    ),
    'safe2': (
      (r, t) => v14.Squirrel(rules: r, topRuleName: t),
      (r, t) => safe.Squirrel(rules: r, topRuleName: t)
    ),
    'deferred': (
      (r, t) => safe.Squirrel(rules: r, topRuleName: t),
      (r, t) => lazy.Squirrel(rules: r, topRuleName: t)
    ),
  };
  final counts = <String, int>{for (final k in variants.keys) k: 0};
  final samples = <String, List<String>>{for (final k in variants.keys) k: []};
  var parsed = 0;
  for (final grammar in grammars) {
    Map<String, Clause> rules;
    try {
      rules = MetaGrammar.parseGrammar(grammar);
    } catch (_) {
      continue;
    }
    parsed++;
    final engines = {
      for (final e in variants.entries)
        e.key: (e.value.$1(rules, 'S'), e.value.$2(rules, 'S'))
    };
    for (final input in inputs) {
      for (final e in engines.entries) {
        final expected = run(e.value.$1, input);
        final got = run(e.value.$2, input);
        if (got == expected) continue;
        counts[e.key] = counts[e.key]! + 1;
        if (samples[e.key]!.length < 3) {
          samples[e.key]!.add('grammar=$grammar input="$input"\n'
              '  r5=$expected\n  ${e.key}=$got');
        }
      }
    }
  }
  print(
      'grammars=$parsed inputs=${inputs.length} cases=${parsed * inputs.length}');
  for (final key in variants.keys) {
    print('$key diffs=${counts[key]}');
    for (final sample in samples[key]!) print(sample);
  }
}
