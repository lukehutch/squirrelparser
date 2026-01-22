import 'package:squirrel_parser/src/metagrammar.dart';
import 'package:squirrel_parser/src/parser/parser.dart';
import 'package:squirrel_parser/src/parser/combinators.dart';
import 'package:squirrel_parser/src/parser/match_result.dart';

void main() {
  enableRecoveryDebug();

  final grammar = MetaGrammar.parseGrammar('S <- "ab"* "!" ;');
  final parser = Parser(rules: grammar, topRuleName: 'S', input: 'XXab!');
  final result = parser.parse();

  disableRecoveryDebug();

  print('\nResult: ${result.hasSyntaxErrors ? "has errors" : "clean"}');
  print('Root len: ${result.root.len}');

  final errors = result.getSyntaxErrors();
  print('Errors: ${errors.length}');
  for (final e in errors) {
    final text = e.len > 0
        ? parser.input.substring(e.pos, e.pos + e.len)
        : '(deletion)';
    print('  pos=${e.pos} len=${e.len} "$text"');
  }
}
