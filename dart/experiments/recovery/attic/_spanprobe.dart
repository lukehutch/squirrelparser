// _spanprobe.dart -- does `span` ever decide a PRUNE, and does it lose one?
//
// I65 ranks `span` = echo - doubt above both endpoints and records that it is
// NOT prefix-optimal: under a repairing suffix it reduces to maximizing doubt,
// under a repair-free one it carries the prefix span through. `_put` keeps ONE
// way per ending, so wherever those two readings disagree the engine must drop
// a way that some suffix would have preferred.
//
// Argument alone cannot say whether that is reached, so count it:
//   cmpPut    contested _put calls -- two ways offered at the same ending
//   flipPut   those where span REVERSED the span-free verdict
//   lostDoubt the subset of flips where the DISCARDED way had strictly more
//             doubt, i.e. exactly the way a repairing suffix would have wanted
//
// flipPut == 0 would mean the compromise is free on this battery. lostDoubt is
// the number that says whether a Pareto front over (doubt, span) is worth
// building, since those are the only prunes a suffix could punish.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_m105cnt.dart' as cnt;

void main() {
  final cases = weighted(buildBattery());
  final byCorpus = <String, Corpus>{for (final c in corpora) c.name: c};
  final rules = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final original = <String, MatchResult>{};
  for (final c in corpora) {
    for (final doc in c.documents) {
      original['${c.name} $doc'] =
          Parser(rules: rules[c.name]!, topRuleName: c.top, input: doc)
              .parse()
              .root;
    }
  }
  final made = <String, MatchResult? Function(String)>{
    for (final c in corpora)
      c.name: cnt.SuperDot3(rules: rules[c.name]!, topRuleName: c.top).recover
  };

  double total = 0;
  var perfect = 0;
  for (final k in cases) {
    final c = byCorpus[k.grammar]!;
    MatchResult? produced;
    try {
      produced = made[k.grammar]!(k.mutant);
    } catch (_) {}
    final s = scoreCase(
        produced: produced,
        expected: expectedFor(k, original['${k.grammar} ${k.original}']!, c.named),
        inputLen: k.mutant.length,
        named: c.named);
    total += s.score;
    if (s.score == 1.0) perfect++;
  }

  // The score is printed as a control: it must equal m105's 0.9573/67.2, or
  // the instrumentation changed the engine and the counts describe something
  // other than m105.
  print('control  score ${(total / cases.length).toStringAsFixed(4)}  '
      'perfect ${(perfect / cases.length * 100).toStringAsFixed(1)}%');
  print('contested _put calls  ${cnt.cmpPut}');
  print('span flipped verdict  ${cnt.flipPut}'
      '  (${(cnt.flipPut / cnt.cmpPut * 100).toStringAsFixed(4)}%)');
  print('  of those, discarded the LARGER doubt  ${cnt.lostDoubt}');
}
