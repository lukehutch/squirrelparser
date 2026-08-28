// _frontier13.dart -- the paper's frontier statistics, measured on c13.
//
// Runs the whole battery through an instrumented copy of the engine
// (`_c13inst.dart`, c13 plus three counters at the point where a repair
// cell's computation completes) and reports both the battery score --
// which must reproduce the uninstrumented engine's -- and the cell
// statistics quoted in the paper: how many repair-cell computations the
// sweep performs, how many readings a cell holds when its computation
// completes, and the largest such cell.
import 'package:squirrel_parser/squirrel_parser.dart';

import '../../experiments/recovery/_c13inst.dart' as inst;
import 'astdiff.dart';

void main() {
  final cases = weighted(buildBattery());
  final byCorpus = <String, Corpus>{for (final c in corpora) c.name: c};
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final original = <String, MatchResult>{};
  for (final c in corpora) {
    for (final doc in c.documents) {
      final r =
          Parser(rules: rulesOf[c.name]!, topRuleName: c.top, input: doc)
              .parse();
      original['${c.name} $doc'] = r.root;
    }
  }
  final made = <String, MatchResult? Function(String)>{
    for (final c in corpora)
      c.name: inst.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top).recover
  };

  var perfect = 0;
  double total = 0;
  for (final k in cases) {
    final c = byCorpus[k.grammar]!;
    MatchResult? produced;
    try {
      produced = made[k.grammar]!(k.mutant);
    } catch (_) {
      produced = null;
    }
    final s = scoreCase(
      produced: produced,
      expected: expectedFor(k, original['${k.grammar} ${k.original}']!, c.named),
      inputLen: k.mutant.length,
      named: c.named,
    );
    if (s.score == 1.0) perfect++;
    total += s.score;
  }
  print('battery ${(total / cases.length).toStringAsFixed(4)} '
      '${(perfect / cases.length * 100).toStringAsFixed(1)} '
      'over ${cases.length} mutants');
  print('repair-cell computations ${inst.Squirrel.instCells}');
  print('mean readings at completion '
      '${(inst.Squirrel.instReadings / inst.Squirrel.instCells).toStringAsFixed(2)}');
  print('max readings in one cell ${inst.Squirrel.instMax}');
}
