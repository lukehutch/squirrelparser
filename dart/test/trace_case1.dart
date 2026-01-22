import 'package:squirrel_parser/squirrel_parser.dart';

const String jsonGrammar = r'''
JSON <- WS Value WS;
Value <- Object / Array / String / Number / Boolean / Null;
Object <- LBRACE WS (Member (WS COMMA WS Member)*)? WS RBRACE;
Member <- String WS COLON WS Value;
Array <- LBRACKET WS (Value (WS COMMA WS Value)*)? WS RBRACKET;
String <- QUOTE Character* QUOTE;
~Character <- [^"\\] / (BACKSLASH Escape);
~Escape <- QUOTE / BACKSLASH / SLASH / 'b' / 'f' / 'n' / 'r' / 't' / ('u' [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F]);
Number <- Integer Fraction? Exponent?;
Integer <- MINUS? (([1-9] [0-9]+) / [0-9]);
Fraction <- DOT [0-9]+;
Exponent <- EXP (PLUS / MINUS)? [0-9]+;
Boolean <- "true" / "false";
Null <- "null";

~WS <- [ \t\n\r]*;
~LBRACE <- '{';
~RBRACE <- '}';
~LBRACKET <- '[';
~RBRACKET <- ']';
~COLON <- ':';
~COMMA <- ',';
~QUOTE <- '"';
~BACKSLASH <- '\\';
~SLASH <- '/';
~DOT <- '.';
~MINUS <- '-';
~PLUS <- '+';
~EXP <- 'e' / 'E';
''';

void printTree(MatchResult result, String input, {int indent = 0}) {
  final prefix = '  ' * indent;
  if (result is SyntaxError) {
    final text = result.len > 0 && result.pos >= 0 && result.pos + result.len <= input.length
        ? '"${input.substring(result.pos, result.pos + result.len)}"'
        : '(deletion)';
    print('$prefix ERROR pos=${result.pos} len=${result.len} $text');
  } else if (result is Match) {
    print('$prefix ${result.clause.runtimeType}: pos=${result.pos} len=${result.len}');
    for (final child in result.subClauseMatches) {
      printTree(child, input, indent: indent + 1);
    }
  }
}

void main() {
  final input = '"name":"Alice","age":30,"active":true,"scores":[95,87,92]}';
  print('Input: $input');
  print('Length: ${input.length}');
  print('');

  final parseResult = squirrelParsePT(
    grammarSpec: jsonGrammar,
    topRuleName: 'JSON',
    input: input,
  );

  print('Parse tree:');
  printTree(parseResult.root, input);

  print('');
  print('Unmatched input: ${parseResult.unmatchedInput}');

  final errors = <SyntaxError>[];
  collectErrors(parseResult.root, errors);
  if (parseResult.unmatchedInput != null) {
    errors.add(parseResult.unmatchedInput!);
  }
  print('');
  print('Errors: ${errors.length}');
  for (final e in errors) {
    final text = e.len > 0 && e.pos >= 0 && e.pos + e.len <= input.length
        ? '"${input.substring(e.pos, e.pos + e.len)}"'
        : '(deletion)';
    print('  pos=${e.pos} len=${e.len} $text');
  }
}

void collectErrors(MatchResult result, List<SyntaxError> errors) {
  if (result is SyntaxError) {
    errors.add(result);
  }
  for (final child in result.subClauseMatches) {
    collectErrors(child, errors);
  }
}
