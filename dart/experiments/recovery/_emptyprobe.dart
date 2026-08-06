import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  for (final r in ['Value', 'Number', 'Integer', 'Member', 'Object']) {
    final p = Parser(rules: rules, topRuleName: r, input: '');
    final res = p.parse().root;
    print('$r on "" -> ${res.runtimeType} '
        'len=${res is Match ? res.len : -1} mismatch=${res.isMismatch}');
  }
}
