import 'package:squirrel_parser/src/metagrammar.dart';
import 'package:squirrel_parser/src/parser/parser.dart';
import 'package:squirrel_parser/src/parser/combinators.dart';
import 'package:squirrel_parser/src/parser/match_result.dart';

void main() {
  enableRecoveryDebug();

  final grammar = MetaGrammar.parseGrammar('Test <- "a" &"b" ;');
  final parser = Parser(rules: grammar, topRuleName: 'Test', input: 'ac');
  final result = parser.parse();

  disableRecoveryDebug();

  print('\nResult root type: ${result.root.runtimeType}');
  print('Result hasSyntaxErrors: ${result.hasSyntaxErrors}');
  print('Result root isMismatch: ${result.root.isMismatch}');
  print('Result root len: ${result.root.len}');

  if (result.root is SyntaxError) {
    print('Root IS SyntaxError');
  } else {
    print('Root is NOT SyntaxError');
  }
}
