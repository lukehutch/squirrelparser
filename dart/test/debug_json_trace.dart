import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/parser/combinators.dart';
import 'package:squirrel_parser/src/parser/parser.dart';

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

void main() {
  enableRecoveryDebug();
  Parser.enableBoundsDebug();

  final input = '{"name":@@@,"age":30}';

  print('Input: $input');
  print('Length: ${input.length}');
  print('');
  print('Position map:');
  for (var i = 0; i < input.length; i++) {
    print('  $i: "${input[i]}"');
  }
  print('');
  print('=== Starting parse ===');
  print('');

  final grammar = MetaGrammar.parseGrammar(jsonGrammar);
  final parser = Parser(rules: grammar, topRuleName: 'JSON', input: input);
  parser.parse();

  disableRecoveryDebug();
  Parser.disableBoundsDebug();
}
