// Degenerate inputs across the new engines. The mutation battery is built by
// mutating a VALID document, so it can never produce the empty string -- this
// gate is the only thing that covers it, and it is what found the RangeError in
// the lead loop. m22 deletes that loop entirely, so the whole failure class
// should be structurally absent rather than merely patched.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'sd2_shape.dart' show jsonGrammar;
import 'm22.dart' as e22b;
import 'm26.dart' as e26;

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  final inputs = ['', ' ', '{', '}', '[', 'x', '{"a"', '""', '{}', '[]', '\u{1F600}', '{"a":'];
  for (final (name, run) in <(String, int Function(String))>[
    ('m22', e22b.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost),
    ('m26', e26.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost),
  ]) {
    final parts = <String>[];
    for (final s in inputs) {
      final label = s.isEmpty ? '<empty>' : s;
      try {
        parts.add('$label=${run(s)}');
      } catch (e) {
        parts.add('$label=CRASH(${e.runtimeType})');
      }
    }
    print('${name.padRight(4)} ${parts.join('  ')}');
  }
}
