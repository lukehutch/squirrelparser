import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/parser/combinators.dart';

const String jsonGrammar = '''
JSON <- WS Value WS;
Value <- Object / Array / String / Number / Boolean / Null;
Object <- LBRACE WS (Member (WS COMMA WS Member)*)? WS RBRACE;
Member <- String WS COLON WS Value;
Array <- LBRACKET WS (Value (WS COMMA WS Value)*)? WS RBRACKET;
String <- QUOTE Character* QUOTE;
~Character <- [^"\\\\] / (BACKSLASH Escape);
~Escape <- QUOTE / BACKSLASH / SLASH / 'b' / 'f' / 'n' / 'r' / 't' / ('u' [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F]);
Number <- Integer Fraction? Exponent?;
Integer <- MINUS? (([1-9] [0-9]+) / [0-9]);
Fraction <- DOT [0-9]+;
Exponent <- EXP (PLUS / MINUS)? [0-9]+;
Boolean <- "true" / "false";
Null <- "null";

~WS <- [ \\t\\n\\r]*;
~LBRACE <- '{';
~RBRACE <- '}';
~LBRACKET <- '[';
~RBRACKET <- ']';
~COLON <- ':';
~COMMA <- ',';
~QUOTE <- '"';
~BACKSLASH <- '\\\\';
~SLASH <- '/';
~DOT <- '.';
~MINUS <- '-';
~PLUS <- '+';
~EXP <- 'e' / 'E';
''';

void main() {
  // enableRecoveryDebug();

  // Case 7: Replace "Alice" with @@@
  final input = '{"name":@@@,"age":30,"active":true,"scores":[95,87,92]}';

  print('Input: $input');
  print('Expected: error ONLY at positions 8-10 (@@@)');
  print('');

  final parseResult = squirrelParsePT(
    grammarSpec: jsonGrammar,
    topRuleName: 'JSON',
    input: input,
  );

  final errors = <SyntaxError>[];
  void collectErrors(MatchResult result) {
    if (result is SyntaxError) {
      errors.add(result);
    }
    for (final child in result.subClauseMatches) {
      collectErrors(child);
    }
  }
  collectErrors(parseResult.root);

  print('Errors found: ${errors.length}');
  for (final e in errors) {
    final text = e.len > 0 ? input.substring(e.pos, e.pos + e.len) : '(deletion)';
    print('  pos=${e.pos} len=${e.len} "$text"');
    if (e.len == 0 && e.clause != null) {
      print('    deleted clause: ${e.clause}');
    }
  }

  print('');
  print('Parse tree structure (showing first 3 levels):');
  printTree(parseResult.root, input, '', 0);
}

void printTree(MatchResult node, String input, String indent, int depth) {
  if (depth > 8) {
    return;
  }
  if (node.isMismatch) {
    print('${indent}MISMATCH');
    return;
  }

  String clauseInfo;
  if (node is SyntaxError) {
    final text = node.len > 0 ? '"${input.substring(node.pos, node.pos + node.len)}"' : '(deletion)';
    clauseInfo = 'SyntaxError pos=${node.pos} len=${node.len} $text';
  } else {
    final text = node.len > 0 && node.pos >= 0 && node.pos + node.len <= input.length
        ? '"${input.substring(node.pos, node.pos + node.len)}"'
        : '';
    clauseInfo = '${node.clause?.runtimeType ?? node.runtimeType} pos=${node.pos} len=${node.len} $text';
  }
  print('$indent$clauseInfo');

  for (final child in node.subClauseMatches) {
    printTree(child, input, '$indent  ', depth + 1);
  }
}
