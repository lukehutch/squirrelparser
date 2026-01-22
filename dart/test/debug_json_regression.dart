import 'package:squirrel_parser/src/metagrammar.dart';
import 'package:squirrel_parser/src/parser/parser.dart';
import 'package:squirrel_parser/src/parser/combinators.dart';

const jsonGrammar = r'''
  JSON     <- ~WS Value ~WS ;
  Value    <- Object / Array / String / Number / True / False / Null ;
  Object   <- LBRACE (~WS Member (~WS COMMA ~WS Member)*)? ~WS RBRACE ;
  Member   <- String ~WS COLON ~WS Value ;
  Array    <- LBRACK (~WS Value (~WS COMMA ~WS Value)*)? ~WS RBRACK ;
  String   <- QUOTE (!QUOTE (BACKSLASH . / .))* QUOTE ;
  Number   <- MINUS? (ZERO / ONENINE DIGIT*) FRACTION? EXPONENT? ;
  FRACTION <- DOT DIGIT+ ;
  EXPONENT <- E SIGN? DIGIT+ ;
  True     <- "true" ;
  False    <- "false" ;
  Null     <- "null" ;
  ~WS      <- [ \t\n\r]* ;
  LBRACE   <- "{" ;
  RBRACE   <- "}" ;
  LBRACK   <- "[" ;
  RBRACK   <- "]" ;
  COMMA    <- "," ;
  COLON    <- ":" ;
  QUOTE    <- "\"" ;
  BACKSLASH <- "\\" ;
  DOT      <- "." ;
  MINUS    <- "-" ;
  ZERO     <- "0" ;
  ONENINE  <- [1-9] ;
  DIGIT    <- [0-9] ;
  E        <- [eE] ;
  SIGN     <- [+-] ;
''';

void main() {
  final grammar = MetaGrammar.parseGrammar(jsonGrammar);

  // Test with error in the middle
  final input = '{"name":@@@,"age":30}';
  print('Input: $input');
  print('Expected: error at pos=8 len=3 "@@@"');
  print('');

  // enableRecoveryDebug();
  final parser = Parser(rules: grammar, topRuleName: 'JSON', input: input);
  final result = parser.parse();
  // disableRecoveryDebug();

  print('\nResult: ${result.hasSyntaxErrors ? "has errors" : "clean"}');
  print('Root isMismatch: ${result.root.isMismatch}');
  print('Root len: ${result.root.len}');

  final errors = result.getSyntaxErrors();
  print('Errors: ${errors.length}');
  for (final e in errors) {
    final text = e.len > 0 && e.pos + e.len <= input.length
        ? input.substring(e.pos, e.pos + e.len)
        : '(deletion at pos ${e.pos})';
    print('  pos=${e.pos} len=${e.len} "$text"');
  }
}
