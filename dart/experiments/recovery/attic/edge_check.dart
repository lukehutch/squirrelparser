import 'package:squirrel_parser/squirrel_parser.dart';
import 'sd2_shape.dart' show jsonGrammar;
import 'sd6.dart' as v6;
import 'm15.dart' as m15;
import 'm16.dart' as m16;

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  final engines = <String, dynamic>{
    'v6': v6.SuperDot3(rules: rules, topRuleName: 'JSON'),
    'm15': m15.SuperDot3(rules: rules, topRuleName: 'JSON'),
    'm16': m16.SuperDot3(rules: rules, topRuleName: 'JSON'),
  };
  final inputs = <String>['', ' ', '{', '}', '[', 'x', '{"a"', '""', '{}', '[]'];
  for (final e in engines.entries) {
    final out = <String>[];
    for (final s in inputs) {
      try {
        final r = e.value.recover(s);
        out.add('${s.isEmpty ? "<empty>" : s}=${e.value.lastCost}'
            '${r.root == null ? "/NOROOT" : ""}');
      } catch (err) {
        out.add('${s.isEmpty ? "<empty>" : s}=CRASH(${err.runtimeType})');
      }
    }
    print('${e.key.padRight(4)} ${out.join('  ')}');
  }
}
