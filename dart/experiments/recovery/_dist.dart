// _dist.dart -- what shape is the search? Cells filled, rounds run, and the
// distribution of how many ENDINGS a memo cell actually holds. If cells hold
// one ending, the Map<int,_Way> is overhead rather than expressiveness.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' show jsonGrammar;
import '_m80h.dart' as h;

const doc = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  bool parses(String s) => !Parser(rules: rules, topRuleName: 'JSON', input: s)
      .parse()
      .hasSyntaxErrors;
  final b = <String>[];
  for (var j = 0; j < doc.length; j++) {
    b.add(doc.substring(0, j) + doc.substring(j + 1));
    if (j + 1 < doc.length && doc[j] != doc[j + 1]) {
      b.add(doc.substring(0, j) + doc[j + 1] + doc[j] + doc.substring(j + 2));
    }
  }
  for (var j = 0; j <= doc.length; j++) {
    for (final c in ['Q', 'z', '}', '"', ',', '5']) {
      b.add(doc.substring(0, j) + c + doc.substring(j));
      if (j < doc.length && doc[j] != c) {
        b.add(doc.substring(0, j) + c + doc.substring(j + 1));
      }
    }
  }
  final mutants = b.where((x) => !parses(x)).toList();

  final eng = h.SuperDot3(rules: rules, topRuleName: 'JSON');
  for (final m in mutants) {
    eng.recoverCost(m);
  }
  print('mutants ${mutants.length}   rounds ${h.rounds}  '
      '(${(h.rounds / mutants.length).toStringAsFixed(2)} per mutant)');
  print('cells ${h.cells}  (${(h.cells / mutants.length).round()} per mutant, '
      '${(h.cells / h.rounds).round()} per round)');
  print('entries ${h.entries}   mean endings per cell '
      '${(h.entries / h.cells).toStringAsFixed(2)}');
  final ks = h.hist.keys.toList()..sort();
  for (final k in ks.take(12)) {
    print('  $k ending(s): ${h.hist[k]}  '
        '${(h.hist[k]! / h.cells * 100).toStringAsFixed(1)}%');
  }
}
