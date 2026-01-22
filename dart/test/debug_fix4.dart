import 'package:squirrel_parser/src/parser/combinators.dart';
import 'package:squirrel_parser/src/metagrammar.dart';
import 'package:squirrel_parser/src/parser/parser.dart';

void main() {
  enableRecoveryDebug();
  final grammar = MetaGrammar.parseGrammar('S <- "{" ("(" "x"+ ")")+ "}" ;');
  final parser = Parser(rules: grammar, topRuleName: 'S', input: '{(xAx)B(xCx)}');
  final result = parser.parse();
  disableRecoveryDebug();

  print('Errors: ${result.getSyntaxErrors().length}');
  for (final e in result.getSyntaxErrors()) {
    final text = e.len > 0 ? parser.input.substring(e.pos, e.pos + e.len) : '(del)';
    print('  pos=${e.pos} len=${e.len} "$text"');
  }
}
