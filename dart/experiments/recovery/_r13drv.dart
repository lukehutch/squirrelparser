// Where do r13's ~124 trials per case go, and how many are redundant?
//
// A "trial" is one `_try`: install a candidate repair, re-descend from the root,
// cost the resulting tree, take it back out. Two kinds are offered at every
// frontier site -- give up a clause that wanted `l` characters, or deny `l`
// characters the grammar did not want. The denial side has a pre-filter
// (`matchSub` must succeed and be non-empty); the give-up side has none.
//
// A candidate is REDUNDANT if, within the same widening round, another
// candidate at the same position already produced the same cost tuple: the
// scan compares only the tuple, so the second trial cannot change the outcome.

import 'package:squirrel_parser/squirrel_parser.dart';

import '_r13p.dart' as e;
import 'astdiff.dart';

void main() {
  final battery = buildBattery();
  final cases = weighted(battery);
  final byGrammar = <String, Map<String, Clause>>{};
  for (final c in corpora) {
    byGrammar[c.name] = MetaGrammar.parseGrammar(c.grammar);
  }
  final sw = Stopwatch()..start();
  for (final k in cases) {
    final corpus = corpora.firstWhere((c) => c.name == k.grammar);
    final eng = e.Squirrel(rules: byGrammar[k.grammar]!, topRuleName: corpus.top);
    try {
      eng.recover(k.mutant);
    } catch (_) {}
    e.Prof.cases++;
  }
  sw.stop();
  final n = e.Prof.cases;
  String per(int v) => (v / n).toStringAsFixed(1);
  print('cases                 $n   ${sw.elapsedMilliseconds} ms');
  print('widening rounds       ${e.Prof.rounds}  (${per(e.Prof.rounds)}/case)');
  print('matchSub pre-filter   ${e.Prof.sub}  (${per(e.Prof.sub)}/case)');
  print('  of those kept       ${e.Prof.subKept}  '
      '(${(100 * e.Prof.subKept / e.Prof.sub).toStringAsFixed(1)}% pass)');
  print('TRIALS give-up        ${e.Prof.give}  (${per(e.Prof.give)}/case)');
  print('TRIALS denial         ${e.Prof.deny}  (${per(e.Prof.deny)}/case)');
  final tot = e.Prof.give + e.Prof.deny;
  print('TRIALS total          $tot  (${per(tot)}/case)');
  final dup = e.Prof.giveDup + e.Prof.denyDup;
  print('redundant give-up     ${e.Prof.giveDup}  '
      '(${(100 * e.Prof.giveDup / (e.Prof.give == 0 ? 1 : e.Prof.give)).toStringAsFixed(1)}% of give-ups)');
  print('redundant denial      ${e.Prof.denyDup}  '
      '(${(100 * e.Prof.denyDup / (e.Prof.deny == 0 ? 1 : e.Prof.deny)).toStringAsFixed(1)}% of denials)');
  print('REDUNDANT total       $dup  (${(100 * dup / tot).toStringAsFixed(1)}% of all trials)');
  e.Prof.newRound(); // flush the last round's groups
  print('');
  print('GROUPS by pre-computable key (kind|pos|price)');
  print('  groups              ${e.Prof.groups}');
  print('  all members agree   ${e.Prof.unanimous}  '
      '(${(100 * e.Prof.unanimous / e.Prof.groups).toStringAsFixed(1)}%)');
  print('  trials if one per group: ${e.Prof.groups} vs $tot  '
      '(${(100 * e.Prof.groups / tot).toStringAsFixed(1)}%)');
}
