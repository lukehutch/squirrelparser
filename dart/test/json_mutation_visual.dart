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

// Original valid JSON
const String originalJson = '{"name":"Alice","age":30,"active":true,"scores":[95,87,92]}';

class Mutation {
  final String name;
  final String mutatedJson;
  final Set<int> mutationPositions;
  final bool isDeletion;

  Mutation(this.name, this.mutatedJson, this.mutationPositions, {this.isDeletion = false});
}

List<Mutation> generateMutations() {
  final mutations = <Mutation>[];

  // 1. Delete opening brace
  mutations.add(Mutation(
    'Delete opening {',
    originalJson.substring(1),
    {0},
    isDeletion: true,
  ));

  // 2. Delete closing brace
  mutations.add(Mutation(
    'Delete closing }',
    originalJson.substring(0, originalJson.length - 1),
    {originalJson.length - 1},
    isDeletion: true,
  ));

  // 3. Delete first quote of "name"
  mutations.add(Mutation(
    'Delete opening quote of "name"',
    originalJson.substring(0, 1) + originalJson.substring(2),
    {1},
    isDeletion: true,
  ));

  // 4. Delete closing quote of "name"
  mutations.add(Mutation(
    'Delete closing quote of "name"',
    originalJson.substring(0, 6) + originalJson.substring(7),
    {6},
    isDeletion: true,
  ));

  // 5. Delete colon after "name"
  mutations.add(Mutation(
    'Delete colon after "name"',
    originalJson.substring(0, 7) + originalJson.substring(8),
    {7},
    isDeletion: true,
  ));

  // 6. Delete comma after "Alice"
  mutations.add(Mutation(
    'Delete comma after "Alice"',
    originalJson.substring(0, 15) + originalJson.substring(16),
    {15},
    isDeletion: true,
  ));

  // 7. Replace "Alice" with garbage
  mutations.add(Mutation(
    'Replace "Alice" with @@@',
    '{"name":@@@,"age":30,"active":true,"scores":[95,87,92]}',
    {8, 9, 10},
  ));

  // 8. Insert garbage before value
  mutations.add(Mutation(
    'Insert @@@ before "Alice"',
    '{"name":@@@"Alice","age":30,"active":true,"scores":[95,87,92]}',
    {8, 9, 10},
  ));

  // 9. Delete "true" keyword
  mutations.add(Mutation(
    'Delete "true" keyword',
    '{"name":"Alice","age":30,"active":,"scores":[95,87,92]}',
    {34},
    isDeletion: true,
  ));

  // 10. Corrupt "true" to "tru"
  mutations.add(Mutation(
    'Corrupt "true" to "tru"',
    '{"name":"Alice","age":30,"active":tru,"scores":[95,87,92]}',
    {37},
    isDeletion: true,
  ));

  // 11. Delete opening bracket of array
  mutations.add(Mutation(
    'Delete [ of scores array',
    '{"name":"Alice","age":30,"active":true,"scores":95,87,92]}',
    {48},
    isDeletion: true,
  ));

  // 12. Delete closing bracket of array
  mutations.add(Mutation(
    'Delete ] of scores array',
    '{"name":"Alice","age":30,"active":true,"scores":[95,87,92}',
    {58},
    isDeletion: true,
  ));

  // 13. Insert garbage in array
  mutations.add(Mutation(
    'Insert @@@ in array',
    '{"name":"Alice","age":30,"active":true,"scores":[95,@@@,87,92]}',
    {52, 53, 54},
  ));

  // 14. Delete comma in array
  mutations.add(Mutation(
    'Delete comma between 95 and 87',
    '{"name":"Alice","age":30,"active":true,"scores":[95 87,92]}',
    {51},
    isDeletion: true,
  ));

  // 15. Replace number with garbage
  mutations.add(Mutation(
    'Replace 30 with ###',
    '{"name":"Alice","age":###,"active":true,"scores":[95,87,92]}',
    {22, 23, 24},
  ));

  // 16. Delete key "age" entirely
  mutations.add(Mutation(
    'Delete "age" key',
    '{"name":"Alice",:30,"active":true,"scores":[95,87,92]}',
    {16, 17, 18, 19, 20},
    isDeletion: true,
  ));

  // 17. Extra comma at end of object
  mutations.add(Mutation(
    'Extra comma before }',
    '{"name":"Alice","age":30,"active":true,"scores":[95,87,92],}',
    {59},
  ));

  // 18. Double comma
  mutations.add(Mutation(
    'Double comma after "Alice"',
    '{"name":"Alice",,"age":30,"active":true,"scores":[95,87,92]}',
    {16},
  ));

  // 19. Missing value for key
  mutations.add(Mutation(
    'Missing value for "name"',
    '{"name":,"age":30,"active":true,"scores":[95,87,92]}',
    {8},
    isDeletion: true,
  ));

  // 20. Replace colon with equals
  mutations.add(Mutation(
    'Replace : with = after "name"',
    '{"name"="Alice","age":30,"active":true,"scores":[95,87,92]}',
    {7},
  ));

  // 21. Unquoted key
  mutations.add(Mutation(
    'Unquoted key name',
    '{name:"Alice","age":30,"active":true,"scores":[95,87,92]}',
    {1, 2, 3, 4},
  ));

  // 22. Single quotes instead of double
  mutations.add(Mutation(
    "Single quotes for value",
    "{\"name\":'Alice',\"age\":30,\"active\":true,\"scores\":[95,87,92]}",
    {8, 14},
  ));

  // 23. Trailing garbage
  mutations.add(Mutation(
    'Trailing garbage XXX',
    '{"name":"Alice","age":30,"active":true,"scores":[95,87,92]}XXX',
    {60, 61, 62},
  ));

  // 24. Leading garbage
  mutations.add(Mutation(
    'Leading garbage XXX',
    'XXX{"name":"Alice","age":30,"active":true,"scores":[95,87,92]}',
    {0, 1, 2},
  ));

  // 25. Valid deletion (remove a member)
  mutations.add(Mutation(
    'Delete "active":true (still valid)',
    '{"name":"Alice","age":30,"scores":[95,87,92]}',
    {},
    isDeletion: true,
  ));

  // 26. Replace array element with garbage
  mutations.add(Mutation(
    'Replace 95 with @',
    '{"name":"Alice","age":30,"active":true,"scores":[@,87,92]}',
    {49},
  ));

  // 27. Multiple errors
  mutations.add(Mutation(
    'Two garbage values',
    '{"name":@@@,"age":###,"active":true,"scores":[95,87,92]}',
    {8, 9, 10, 18, 19, 20},
  ));

  // 28. Delete scores key
  mutations.add(Mutation(
    'Delete "scores" key',
    '{"name":"Alice","age":30,"active":true,:[95,87,92]}',
    {40, 41, 42, 43, 44, 45, 46, 47, 48},
    isDeletion: true,
  ));

  // 29. Truncate in middle
  mutations.add(Mutation(
    'Truncate after "age":',
    '{"name":"Alice","age":',
    {22},
    isDeletion: true,
  ));

  // 30. Garbage between pairs
  mutations.add(Mutation(
    'Insert GARBAGE between pairs',
    '{"name":"Alice" GARBAGE "age":30,"active":true,"scores":[95,87,92]}',
    {16, 17, 18, 19, 20, 21, 22},
  ));

  return mutations;
}

void collectSyntaxErrors(MatchResult result, List<SyntaxError> errors) {
  if (result is SyntaxError) {
    errors.add(result);
  }
  for (final child in result.subClauseMatches) {
    collectSyntaxErrors(child, errors);
  }
}

void visualizeMutation(int index, Mutation mutation) {
  print('');
  print('${"=" * 80}');
  print('${index + 1}. ${mutation.name}');
  print('${"=" * 80}');

  final parseResult = squirrelParsePT(
    grammarSpec: jsonGrammar,
    topRuleName: 'JSON',
    input: mutation.mutatedJson,
  );

  final errors = <SyntaxError>[];
  collectSyntaxErrors(parseResult.root, errors);

  // Include unmatched input only if parse was otherwise successful
  // (i.e., truly trailing garbage, not partial parse failure)
  if (parseResult.unmatchedInput != null && errors.isEmpty) {
    errors.add(parseResult.unmatchedInput!);
  }

  // Build error span markers
  final markers = List.filled(mutation.mutatedJson.length + 1, ' ');

  // Mark all error spans with ^
  for (final error in errors) {
    if (error.len == 0) {
      if (error.pos < markers.length) {
        markers[error.pos] = '|'; // Deletion marker
      }
    } else {
      for (int i = error.pos; i < error.pos + error.len && i < markers.length; i++) {
        markers[i] = '^';
      }
    }
  }

  print(mutation.mutatedJson);
  print(markers.join(''));

  // Count actual errors (non-zero-length or unique positions)
  final uniqueErrors = errors.where((e) => e.len > 0).toList();
  final zeroLenCount = errors.where((e) => e.len == 0).length;

  if (errors.isEmpty) {
    print('No syntax errors detected.');
  } else {
    print('Errors: ${uniqueErrors.length} spans${zeroLenCount > 0 ? " + $zeroLenCount deletions" : ""}');
  }
}

void main() {
  print('Original valid JSON:');
  print(originalJson);
  print('');
  print('Legend: ^ = error span, | = deletion point');

  final mutations = generateMutations();

  for (var i = 0; i < mutations.length; i++) {
    visualizeMutation(i, mutations[i]);
  }
}
