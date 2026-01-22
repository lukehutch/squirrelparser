import 'package:squirrel_parser/src/metagrammar.dart';

void main() {
  // Build up JSON grammar piece by piece

  print('Test 1: Just JSON and Value');
  _test(r'''
    JSON <- Value ;
    Value <- String / Number / "null" ;
    String <- "\"" (!"\""  .)* "\"" ;
    Number <- [0-9]+ ;
  ''');

  print('\nTest 2: Add Object');
  _test(r'''
    JSON <- Value ;
    Value <- Object / String / "null" ;
    Object <- "{" Member* "}" ;
    Member <- String ":" Value ;
    String <- "\"" (!"\""  .)* "\"" ;
  ''');

  print('\nTest 3: Add WS');
  _test(r'''
    JSON <- ~WS Value ~WS ;
    Value <- Object / String / "null" ;
    Object <- "{" ~WS Member* ~WS "}" ;
    Member <- String ~WS ":" ~WS Value ;
    String <- "\"" (!"\""  .)* "\"" ;
    ~WS <- [ \t\n\r]* ;
  ''');

  print('\nTest 4: Add Array');
  _test(r'''
    JSON <- ~WS Value ~WS ;
    Value <- Object / Array / String / "null" ;
    Object <- "{" ~WS Member* ~WS "}" ;
    Member <- String ~WS ":" ~WS Value ;
    Array <- "[" ~WS Value* ~WS "]" ;
    String <- "\"" (!"\""  .)* "\"" ;
    ~WS <- [ \t\n\r]* ;
  ''');

  print('\nTest 5: Full-ish JSON with proper escapes');
  _test(r'''
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
  ''');
}

void _test(String grammar) {
  try {
    final result = MetaGrammar.parseGrammar(grammar);
    print('  PASSED: ${result.keys.take(3).toList()}...');
  } catch (e) {
    print('  FAILED: $e');
  }
}
