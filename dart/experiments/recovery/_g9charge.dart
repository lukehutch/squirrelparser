// Two of Codex's claims about r1, checked across the whole battery:
//
//  (B) free passes: a known-invalid mutant returned at cost 0. Codex measured 61
//      for r1. `_conf1` defines exactly this as a free pass but only probes six
//      hand-written cases, so the battery-wide count was never taken.
//
//  (C) mis-charging: `lastCost` disagreeing with the SyntaxError spans actually
//      present in the returned tree -- repairs that were tried, charged, and
//      then not kept. Codex measured 96 for r1.
//
// Both should be zero for an engine that reads its cost off the tree it emits.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'r1.dart' as r1;
import 'r2.dart' as r2;
import 'r3.dart' as r3;
import '_u9.dart' as r4;

/// (deleted characters, zero-width marks) recorded in [m].
(int, int) edits(MatchResult m) {
  var del = 0, gap = 0;
  void walk(MatchResult k) {
    if (k is SyntaxError) {
      if (k.len == 0) {
        gap++;
      } else {
        del += k.len;
      }
    }
    k.subClauseMatches.forEach(walk);
  }

  walk(m);
  return (del, gap);
}

typedef Engine = ({MatchResult Function(String) run, int Function() cost});

void main() {
  final rulesOf = {
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final seen = <String>{};
  final cases = <Case>[];
  for (final k in weighted(buildBattery())) {
    if (seen.add('${k.grammar}\x00${k.category}\x00${k.mutant}')) cases.add(k);
  }

  // Only mutants the PURE parser rejects can be free-passed.
  final invalid = <Case>[];
  for (final k in cases) {
    final p = Parser(
        rules: rulesOf[k.grammar]!,
        topRuleName: corpora.firstWhere((c) => c.name == k.grammar).top,
        input: k.mutant);
    if (p.parse().hasSyntaxErrors) invalid.add(k);
  }
  print('battery: ${cases.length} distinct, ${invalid.length} rejected by the '
      'pure PEG\n');

  print('${'engine'.padRight(6)}${'cost 0'.padLeft(10)}'
      '${'mischarged'.padLeft(13)}${'worst gap'.padLeft(11)}   example');
  for (final name in ['r1', 'r2', 'r3', 'r4']) {
    final made = <String, dynamic>{};
    for (final c in corpora) {
      made[c.name] = switch (name) {
        'r1' => r1.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top),
        'r2' => r2.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top),
        'r3' => r3.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top),
        _ => r4.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top),
      };
    }
    var free = 0, mis = 0, worst = 0;
    var example = '', freeEg = '';
    for (final k in invalid) {
      final e = made[k.grammar];
      MatchResult t;
      try {
        t = e.recover(k.mutant) as MatchResult;
      } catch (_) {
        continue;
      }
      final charged = e.lastCost as int;
      final (del, gap) = edits(t);
      if (charged == 0 && del == 0 && gap == 0) {
        free++;
        if (freeEg.isEmpty) freeEg = '${k.grammar} `${k.mutant}`';
      }
      final onTree = del + gap;
      if (charged != onTree) {
        mis++;
        if ((charged - onTree).abs() > worst) {
          worst = (charged - onTree).abs();
          example = '${k.grammar} `${k.mutant}` charged=$charged tree=$onTree';
        }
      }
    }
    print('${name.padRight(6)}${'$free'.padLeft(10)}${'$mis'.padLeft(13)}'
        '${'$worst'.padLeft(11)}   ${example.isEmpty ? (freeEg.isEmpty ? '-' : freeEg) : example}');
  }
}
