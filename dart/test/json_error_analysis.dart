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

const String testJson = '''{
  "name": "JSON Tree Viewer",
  "version": 1.0,
  "features": ["tree view", "syntax highlighting", "live parsing"],
  "config": {
    "theme": "dark",
    "autoSave": true
  },
  "active": true,
  "metadata": null
}''';

void analyzeParseResult(String input, String description) {
  print('\n${"=" * 80}');
  print('TEST: $description');
  print('${"=" * 80}');
  print('Input:\n$input');
  print('-' * 80);

  final parseResult = squirrelParsePT(
    grammarSpec: jsonGrammar,
    topRuleName: 'JSON',
    input: input,
  );

  print('Has syntax errors: ${parseResult.hasSyntaxErrors}');

  final errors = parseResult.getSyntaxErrors();
  print('Number of syntax errors: ${errors.length}');

  for (var i = 0; i < errors.length; i++) {
    final e = errors[i];
    print('\nError $i: pos=${e.pos}, len=${e.len}');
    final errorText = input.substring(e.pos, (e.pos + e.len).clamp(0, input.length));
    print('Error text: "${errorText.replaceAll('\n', '\\n')}"');

    // Show context: what comes before and after
    final beforeStart = (e.pos - 20).clamp(0, input.length);
    final afterEnd = (e.pos + e.len + 20).clamp(0, input.length);
    if (beforeStart < e.pos) {
      print('Before: "...${input.substring(beforeStart, e.pos).replaceAll('\n', '\\n')}"');
    }
    if (e.pos + e.len < afterEnd) {
      print('After: "${input.substring(e.pos + e.len, afterEnd).replaceAll('\n', '\\n')}..."');
    }
  }

  // Build and print AST
  final ast = buildAST(parseResult: parseResult);
  print('\nAST:');
  print(ast.toPrettyString(input));
}

String mutateAt(String input, int pos, String replacement) {
  if (pos >= input.length) return input;
  return input.substring(0, pos) + replacement + input.substring(pos + 1);
}

String insertAt(String input, int pos, String insertion) {
  return input.substring(0, pos) + insertion + input.substring(pos);
}

String deleteAt(String input, int pos, [int length = 1]) {
  if (pos >= input.length) return input;
  return input.substring(0, pos) + input.substring((pos + length).clamp(0, input.length));
}

void main() {
  // First, analyze the clean input
  analyzeParseResult(testJson, 'Clean JSON (no errors)');

  // Test 1: Mutate a character in the middle of a string
  var mutated = mutateAt(testJson, 12, 'X'); // Mutate inside "name"
  analyzeParseResult(mutated, 'Mutate char inside "name" string');

  // Test 2: Delete opening quote of "name"
  mutated = deleteAt(testJson, 4, 1); // Delete first quote of "name"
  analyzeParseResult(mutated, 'Delete opening quote of "name"');

  // Test 3: Delete closing brace of config object
  final configClosePos = testJson.indexOf('},\n  "active"');
  mutated = deleteAt(testJson, configClosePos, 1);
  analyzeParseResult(mutated, 'Delete closing brace of config object');

  // Test 4: Insert extra comma after "version": 1.0
  final versionPos = testJson.indexOf('1.0,');
  mutated = insertAt(testJson, versionPos + 3, ',');
  analyzeParseResult(mutated, 'Insert extra comma after version');

  // Test 5: Delete comma between "name" and "version"
  final firstCommaPos = testJson.indexOf(',\n  "version"');
  mutated = deleteAt(testJson, firstCommaPos, 1);
  analyzeParseResult(mutated, 'Delete comma between name and version');

  // Test 6: Corrupt "true" to "tru"
  final truePos = testJson.indexOf(': true');
  mutated = deleteAt(testJson, truePos + 6, 1); // Delete 'e' from 'true'
  analyzeParseResult(mutated, 'Corrupt "true" to "tru"');

  // Test 7: Delete colon after "theme"
  final themeColonPos = testJson.indexOf('"theme":');
  mutated = deleteAt(testJson, themeColonPos + 7, 1);
  analyzeParseResult(mutated, 'Delete colon after "theme"');

  // Test 8: Add garbage in middle of array
  final arrayMiddlePos = testJson.indexOf('"syntax highlighting"');
  mutated = insertAt(testJson, arrayMiddlePos, '@@@');
  analyzeParseResult(mutated, 'Add garbage before "syntax highlighting"');

  // Test 9: Delete opening bracket of features array
  final featuresPos = testJson.indexOf('["tree view"');
  mutated = deleteAt(testJson, featuresPos, 1);
  analyzeParseResult(mutated, 'Delete opening bracket of features array');

  // Test 10: Replace "null" with invalid value
  final nullPos = testJson.indexOf('null');
  mutated = testJson.substring(0, nullPos) + 'undefined' + testJson.substring(nullPos + 4);
  analyzeParseResult(mutated, 'Replace "null" with "undefined"');

  // Print summary of error spans
  print('\n\n${"=" * 80}');
  print('SUMMARY: Error span analysis');
  print('${"=" * 80}');
  print('Input length: ${testJson.length} characters');
}
