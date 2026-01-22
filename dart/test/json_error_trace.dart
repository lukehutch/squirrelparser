import 'package:squirrel_parser/squirrel_parser.dart';

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

// Simple object test case
const String simpleObject = '{"a": 1, "b": 2}';

void printMatchTree(MatchResult result, String input, {int indent = 0}) {
  final prefix = '  ' * indent;
  final typeName = result.runtimeType.toString();

  if (result is SyntaxError) {
    final errorText = input.substring(result.pos, (result.pos + result.len).clamp(0, input.length));
    print('$prefix<SyntaxError> pos=${result.pos} len=${result.len} text="${errorText.replaceAll('\n', '\\n')}"');
  } else {
    final clauseName = result.clause?.toString() ?? '?';
    final text = input.substring(result.pos, (result.pos + result.len).clamp(0, input.length));
    final displayText = text.length > 30 ? '${text.substring(0, 30)}...' : text;
    print('$prefix$clauseName pos=${result.pos} len=${result.len} complete=${result.isComplete} errors=${result.totDescendantErrors}');
    for (final child in result.subClauseMatches) {
      printMatchTree(child, input, indent: indent + 1);
    }
  }
}

void testInput(String input, String description) {
  print('\n${"=" * 80}');
  print('TEST: $description');
  print('Input: $input');
  print('${"=" * 80}');

  final parseResult = squirrelParsePT(
    grammarSpec: jsonGrammar,
    topRuleName: 'JSON',
    input: input,
  );

  print('\nParse tree:');
  printMatchTree(parseResult.root, input);

  print('\nAST:');
  final ast = buildAST(parseResult: parseResult);
  print(ast.toPrettyString(input));

  final errors = parseResult.getSyntaxErrors();
  print('\nErrors (${errors.length}):');
  for (var i = 0; i < errors.length; i++) {
    final e = errors[i];
    final text = input.substring(e.pos, (e.pos + e.len).clamp(0, input.length));
    print('  $i: pos=${e.pos} len=${e.len} "${text.replaceAll('\n', '\\n')}"');
  }
}

void main() {
  // Test 1: Clean simple object
  testInput(simpleObject, 'Clean simple object');

  // Test 2: Delete opening quote of first key
  testInput('{a": 1, "b": 2}', 'Delete opening quote of first key');

  // Test 3: Delete comma between members
  testInput('{"a": 1 "b": 2}', 'Delete comma between members');

  // Test 4: Delete colon after first key
  testInput('{"a" 1, "b": 2}', 'Delete colon after first key');

  // Test 5: Add garbage in value position
  testInput('{"a": @@@, "b": 2}', 'Add garbage in value position');

  // Test 6: Delete closing brace
  testInput('{"a": 1, "b": 2', 'Delete closing brace');

  // Test 7: Nested object with error in inner object
  testInput('{"outer": {"inner": @@@}}', 'Nested object with error in inner');

  // Test 8: Simple deeply nested
  testInput('{"a": {"b": {"c": 1}}}', 'Clean nested object');

  // Test 9: Error in deeply nested
  testInput('{"a": {"b": {"c": @@@}}}', 'Error in deeply nested object');
}
