import 'package:squirrel_parser/src/parser/combinators.dart';
import 'package:squirrel_parser/src/metagrammar.dart';
import 'package:squirrel_parser/src/parser/parser.dart';

void main() {
  // enableRecoveryDebug();

  const grammarSpec = '''
    S <- E "end" ;
    E <- E "+" "n"+ / "n" ;
  ''';

  final grammar = MetaGrammar.parseGrammar(grammarSpec);
  final input = 'n+nXn+nnend';

  print('Input: $input');
  print('Grammar: S <- E "end" ; E <- E "+" "n"+ / "n" ;');
  print('');

  final parser = Parser(rules: grammar, topRuleName: 'S', input: input);
  final result = parser.parse();
  disableRecoveryDebug();

  print('\nResult: ${result.hasSyntaxErrors ? "has errors" : "clean"}');
  print('Root isMismatch: ${result.root.isMismatch}');
  print('Root len: ${result.root.len}');

  final errors = result.getSyntaxErrors();
  print('Errors: ${errors.length}');
  for (final e in errors) {
    String text;
    if (e.len > 0 && e.pos >= 0 && e.pos + e.len <= input.length) {
      text = input.substring(e.pos, e.pos + e.len);
    } else {
      text = '(deletion at pos ${e.pos})';
    }
    print('  pos=${e.pos} len=${e.len} "$text"');
  }

  // Print the tree structure
  print('\nTree structure:');
  printTree(result.root, input, '', 0);
}

void printTree(dynamic node, String input, String indent, int depth) {
  if (depth > 20) {
    print('$indent... (depth limit)');
    return;
  }
  if (node.isMismatch) {
    print('${indent}MISMATCH');
    return;
  }
  final text = node.len > 0 && node.pos >= 0 && node.pos + node.len <= input.length
      ? '"${input.substring(node.pos, node.pos + node.len)}"'
      : '';
  print('$indent${node.clause?.runtimeType ?? node.runtimeType} pos=${node.pos} len=${node.len} $text');
  for (final child in node.subClauseMatches) {
    printTree(child, input, '$indent  ', depth + 1);
  }
}
