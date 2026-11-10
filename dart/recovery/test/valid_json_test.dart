import 'package:squirrel_parser/src/metagrammar.dart';
import 'package:squirrel_parser/src/parser/parser.dart';

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
  final grammar = MetaGrammar.parseGrammar(jsonGrammar);

  // Valid JSON
  final input = '{"name":"John","age":30,"active":true,"scores":[95,87,92]}';
  final parser = Parser(rules: grammar, topRuleName: 'JSON', input: input);
  final result = parser.parse();

  print('Input: $input');
  print('Has errors: ${result.hasSyntaxErrors}');
  final errors = result.getSyntaxErrors();
  if (errors.isNotEmpty) {
    print('Errors:');
    for (final e in errors) {
      print('  pos=${e.pos} len=${e.len}');
    }
  }
}
