import 'package:squirrel_parser/src/metagrammar.dart';
import 'package:squirrel_parser/src/parser/parser.dart';
import 'package:squirrel_parser/src/parser/match_result.dart';
import 'package:squirrel_parser/src/parser/combinators.dart';

const precedenceLR = '''
  S <- E ;
  E <- E "+" T / E "-" T / T ;
  T <- T "*" F / T "/" F / F ;
  F <- "(" E ")" / "n" ;
''';

void main() {
  final grammar = MetaGrammar.parseGrammar(precedenceLR);

  final input = 'n+*n';
  print('Input: $input');
  print('Expected: parse as n*n, with 1 error (skip +)');
  print('');

  enableRecoveryDebug();
  final parser = Parser(rules: grammar, topRuleName: 'S', input: input);
  final result = parser.parse();
  disableRecoveryDebug();

  print('Result: ${result.hasSyntaxErrors ? "has errors" : "clean"}');
  print('Root isMismatch: ${result.root.isMismatch}');
  print('Root len: ${result.root.len}');

  // Print the full parse tree
  print('\nParse tree:');
  _printTree(result.root, input, '', 0);

  final errors = result.getSyntaxErrors();
  print('\nErrors (${errors.length}):');
  for (final e in errors) {
    final text = e.len > 0 && e.pos + e.len <= input.length
        ? input.substring(e.pos, e.pos + e.len)
        : '(deletion at pos ${e.pos})';
    print('  pos=${e.pos} len=${e.len} "$text"');
  }
}

void _printTree(MatchResult node, String input, String indent, int depth) {
  if (depth > 20) {
    print('$indent... (depth limit)');
    return;
  }
  final text = node.len > 0 && node.pos + node.len <= input.length
      ? '"${input.substring(node.pos, node.pos + node.len)}"'
      : '';
  if (node is SyntaxError) {
    print('$indent[ERROR pos=${node.pos} len=${node.len}] $text');
  } else {
    print('$indent${node.runtimeType} pos=${node.pos} len=${node.len} $text');
    for (final child in node.subClauseMatches) {
      _printTree(child, input, '$indent  ', depth + 1);
    }
  }
}
