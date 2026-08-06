import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';

void main() {
  for (final c in corpora) {
    final rules = MetaGrammar.parseGrammar(c.grammar);
    print('== ${c.name}: rules ${rules.keys.toList()}');
    for (final name in rules.keys) {
      try {
        final res = Parser(rules: rules, topRuleName: name, input: '').parse();
        final r = res.root;
        print('  $name -> root=${r.runtimeType} len=${r.len} '
            'isMismatch=${r.isMismatch}');
      } catch (e) {
        print('  $name -> THREW $e');
      }
    }
  }
}
