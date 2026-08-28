// Scratch probe: recover ONE document with c12 and dump the winner's bill
// and error spans. Usage:
//   dart run _one.dart <grammar> <mutant>
import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import '../../experiments/recovery/_c13.dart' as c12;

void main(List<String> argv) {
  final g = argv[0];
  final doc = argv[1];
  final corpus = corpora.firstWhere((c) => c.name == g);
  final rules = MetaGrammar.parseGrammar(corpus.grammar);
  final eng = c12.Squirrel(rules: rules, topRuleName: corpus.top);
  c12.Squirrel.debugRoots = true;
  final tree = eng.recover(doc);
  print('lastCost=${eng.lastCost}');
  // Walk the tree; print named nodes and every SyntaxError span in order.
  final errs = <String>[];
  void walk(MatchResult m, int depth) {
    final c = m.clause;
    final name = c is Ref ? c.ruleName : null;
    if (m is SyntaxError || m.isMismatch) {
      errs.add('SyntaxError(pos=${m.pos},len=${m.len})');
    }
    if (name != null) {
      print('${'  ' * depth}$name [${m.pos},${m.pos + m.len})');
    }
    for (final s in m.subClauseMatches) {
      walk(s, depth + 1);
    }
  }

  walk(tree, 0);
  print('errors: ${errs.join(' ')}');
}
