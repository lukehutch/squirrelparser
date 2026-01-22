import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/parser/parser.dart';
import 'package:squirrel_parser/src/parser/combinators.dart';
import 'package:squirrel_parser/src/parser/memo_entry.dart';
import 'package:squirrel_parser/src/metagrammar.dart';

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
  final input = '{"name":@@@,"age":30,"active":true,"scores":[95,87,92]}';
  print('Input: $input');
  print('Length: ${input.length}');
  print('');
  
  // Enable debug AFTER parsing metagrammar
  final grammar = MetaGrammar.parseGrammar(jsonGrammar);
  
  // Now enable debug
  enableRecoveryDebug();
  enableMemoDebug();
  
  // Parse manually
  final parser = Parser(rules: grammar, topRuleName: 'JSON', input: input);
  final parseResult = parser.parse();
  
  disableRecoveryDebug();
  
  print('\nSyntax errors:');
  final errors = parseResult.getSyntaxErrors();
  for (var i = 0; i < errors.length; i++) {
    final e = errors[i];
    final text = e.len > 0 
        ? input.substring(e.pos, (e.pos + e.len).clamp(0, input.length))
        : '(deletion at pos ${e.pos})';
    print('  $i: pos=${e.pos} len=${e.len} "$text"');
  }
}
