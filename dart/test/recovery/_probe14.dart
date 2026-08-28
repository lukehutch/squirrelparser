// Scratch: hold c13's ladder N extra rungs past first admission on the
// swallow cases, dumping every complete root admission per rung plus the
// expected skeleton. The question: does the honest reading EXIST in a
// later rung's root frontier (judgment is the barrier), or not at any
// depth (enumeration/pruning is)?
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '../../experiments/recovery/_c14.dart' as eng;

void main(List<String> argv) {
  final extra = argv.isEmpty ? 2 : int.parse(argv[0]);
  eng.Squirrel.extraHold = extra;
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final json = corpora.firstWhere((c) => c.name == 'json');
  final rules = rulesOf['json']!;
  // The four worst swallow cases from the residual sweep.
  const mutants = [
    '{"n:[,-7,1.5,2e3],"t":[true,false,null]}',
    '{"a":1,"bc":[2,33,tru],d":{"e":null},"f":"gh"}',
    '{"k":[{"a:1,{"b":2}]}',
    '{"p":[1,2,3],"q:[,5,6],"r":[7,8,9],"s":[0,-1]}',
  ];
  for (final m in mutants) {
    // The original document: the mutant with the damage undone.
    final orig = <String>[
      '{"n":[,-7,1.5,2e3],"t":[true,false,null]}',
      '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}',
      '{"k":[{"a":1},{"b":2}]}',
      '{"p":[1,2,3],"q":[5,6],"r":[7,8,9],"s":[0,-1]}',
    ][mutants.indexOf(m)];
    final expSkeleton = skeleton(
        Parser(rules: rules, topRuleName: json.top, input: orig).parse().root,
        json.named);
    print('=== $m');
    print('  expect: ${expSkeleton.join(' ')}');
    final e = eng.Squirrel(rules: rules, topRuleName: json.top);
    final tree = e.recover(m);
    print('  got   : ${skeleton(tree, json.named).join(' ')} '
        '(cost=${e.lastCost})');
    print('');
  }
}
