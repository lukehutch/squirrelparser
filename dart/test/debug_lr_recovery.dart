import 'package:squirrel_parser/src/metagrammar.dart';
import 'package:squirrel_parser/src/parser/parser.dart';
import 'package:squirrel_parser/src/parser/match_result.dart';

const precedenceLR = '''
  S <- E ;
  E <- E "+" T / E "-" T / T ;
  T <- T "*" F / T "/" F / F ;
  F <- "(" E ")" / "n" ;
''';

void main() {
  final grammar = MetaGrammar.parseGrammar(precedenceLR);

  // Test: n+*n - should skip + and parse as n*n
  final input = 'n+*n';
  print('Input: $input');
  print('Expected: 1 error (skip +)');
  print('');

  final parser = Parser(rules: grammar, topRuleName: 'S', input: input);
  final result = parser.parse();

  print('Result: ${result.hasSyntaxErrors ? "has errors" : "clean"}');
  print('Root isMismatch: ${result.root.isMismatch}');
  print('Root len: ${result.root.len}');

  final errors = result.getSyntaxErrors();
  print('Errors (${errors.length}):');
  for (final e in errors) {
    final text = e.len > 0 && e.pos + e.len <= input.length
        ? input.substring(e.pos, e.pos + e.len)
        : '(deletion at pos ${e.pos})';
    print('  pos=${e.pos} len=${e.len} "$text"');
  }

  // Also test n++n
  print('\n--- Testing n++n ---');
  final input2 = 'n++n';
  print('Input: $input2');
  print('Expected: 1 error (skip +)');

  final parser2 = Parser(rules: grammar, topRuleName: 'S', input: input2);
  final result2 = parser2.parse();

  print('Root isMismatch: ${result2.root.isMismatch}');
  print('Root len: ${result2.root.len}');

  final errors2 = result2.getSyntaxErrors();
  print('Errors (${errors2.length}):');
  for (final e in errors2) {
    final text = e.len > 0 && e.pos + e.len <= input2.length
        ? input2.substring(e.pos, e.pos + e.len)
        : '(deletion at pos ${e.pos})';
    print('  pos=${e.pos} len=${e.len} "$text"');
  }
}
