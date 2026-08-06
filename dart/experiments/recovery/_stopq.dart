// Scratch: is the `stop` offer a distinct claim, or the give-up chain by another
// name? Both price the abandoned tail at the same total, so if the trees also
// agree, `stop` is ten lines of redundancy.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import 'r9.dart' as a;
import '_ab_stop.dart' as b;

void show(MatchResult m, String ind) {
  final lbl = m is SyntaxError
      ? 'ERR'
      : (m.clause == null
          ? 'ROOT'
          : (m.clause is Ref
              ? (m.clause as Ref).ruleName
              : m.clause.runtimeType.toString()));
  print('$ind$lbl @${m.pos}+${m.len}');
  for (final s in m.subClauseMatches) {
    show(s, '$ind  ');
  }
}

void main() {
  var same = 0, diff = 0;
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final ea = {
    for (final c in corpora)
      c.name: a.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top)
  };
  final eb = {
    for (final c in corpora)
      c.name: b.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top)
  };
  final byCorpus = {for (final c in corpora) c.name: c};
  final examples = <String>[];
  for (final k in weighted(buildBattery())) {
    final c = byCorpus[k.grammar]!;
    String s(MatchResult? m) => m == null ? '<null>' : skeleton(m, c.named).join(' ');
    final x = s(ea[k.grammar]!.recover(k.mutant));
    final y = s(eb[k.grammar]!.recover(k.mutant));
    final cx = ea[k.grammar]!.recoverCost(k.mutant);
    final cy = eb[k.grammar]!.recoverCost(k.mutant);
    if (x == y && cx == cy) {
      same++;
    } else {
      diff++;
      if (examples.length < 4) {
        examples.add('${k.category} ${k.grammar} "${k.mutant.replaceAll('\n', ' ')}"\n'
            '   r9      cost $cx: $x\n'
            '   no-stop cost $cy: $y');
      }
    }
  }
  print('identical tree AND cost: $same    differ: $diff\n');
  for (final e in examples) {
    print(e);
  }
  // One truncation in full, both ways.
  final c = corpora.firstWhere((x) => x.name == 'json');
  const p = '{"a":1,';
  print('\n=== "$p" full trees');
  print('--- r9');
  show(ea['json']!.recover(p)!, '  ');
  print('--- no stop');
  show(eb['json']!.recover(p)!, '  ');
}
