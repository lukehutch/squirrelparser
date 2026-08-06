import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import '_dbg81.dart' as eng;

void main() {
  final co = corpora.firstWhere((c) => c.name == 'expr');
  final rules = MetaGrammar.parseGrammar(co.grammar);
  final e = eng.SuperDot3(rules: rules, topRuleName: co.top);
  for (final s in ['1++2', '1*+3']) {
    print('=== "$s" (len ${s.length}) ===');
    final r = e.recover(s);
    print('  -> cost ${e.lastCost}');
    print('  skeleton: ${skeleton(r, co.named).join(' ')}\n');
  }
}
