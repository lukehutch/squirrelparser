// Scratch: what does each engine PAY for the reading it returns, on the cases
// where the unified slot-0 deletion collapses a whole object into one string?
// If uni's answer is CHEAPER, the constraint r9 carries is not expressible in
// the cost model at all -- it is a separate axiom.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import 'r9.dart' as r9;
import '_uni.dart' as uni;

void main() {
  final c = corpora.firstWhere((x) => x.name == 'json');
  final rules = MetaGrammar.parseGrammar(c.grammar);
  const probes = ['{"p":[1,2,3],"q', '{"n":[0,-7,1.5,2e3],"', '{"a":1,', '{"k":[{"a'];
  final a = r9.Squirrel(rules: rules, topRuleName: c.top);
  final b = uni.Squirrel(rules: rules, topRuleName: c.top);
  for (final p in probes) {
    print('"$p"');
    print('   r9  cost ${a.recoverCost(p)}: '
        '${skeleton(a.recover(p), c.named).join(' ')}');
    print('   uni cost ${b.recoverCost(p)}: '
        '${skeleton(b.recover(p), c.named).join(' ')}');
  }
}
