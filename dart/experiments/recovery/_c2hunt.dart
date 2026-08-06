import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import 'c2.dart' as c2;

void main() {
  final cases = weighted(buildBattery());
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final made = <String, c2.Squirrel>{};
  for (final c in corpora) {
    made[c.name] = c2.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top);
  }
  final sw = Stopwatch();
  var total = 0;
  for (var i = 0; i < cases.length; i++) {
    final k = cases[i];
    final doc = k.mutant.replaceAll('\n', ' ');
    print('>> i=$i ${k.grammar} ${k.category} $doc');
    sw.reset();
    sw.start();
    try {
      made[k.grammar]!.recover(k.mutant);
    } catch (err) {
      print('i=$i CRASH $err');
    }
    sw.stop();
    total += sw.elapsedMilliseconds;
    print('   ${sw.elapsedMilliseconds}ms');
  }
  print('done total=${total}ms');
}
