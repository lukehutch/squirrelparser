import 'package:squirrel_parser/src/metagrammar.dart';

void main() {
  // Start from Test 4 (which passes) and add things one by one

  print('Test A: Test 4 baseline (should pass)');
  _test(r'''
    JSON <- ~WS Value ~WS ;
    Value <- Object / Array / String / "null" ;
    Object <- "{" ~WS Member* ~WS "}" ;
    Member <- String ~WS ":" ~WS Value ;
    Array <- "[" ~WS Value* ~WS "]" ;
    String <- "\"" (!"\""  .)* "\"" ;
    ~WS <- [ \t\n\r]* ;
  ''');

  print('\nTest B: Add True/False/Null');
  _test(r'''
    JSON <- ~WS Value ~WS ;
    Value <- Object / Array / String / True / False / Null ;
    Object <- "{" ~WS Member* ~WS "}" ;
    Member <- String ~WS ":" ~WS Value ;
    Array <- "[" ~WS Value* ~WS "]" ;
    String <- "\"" (!"\""  .)* "\"" ;
    True <- "true" ;
    False <- "false" ;
    Null <- "null" ;
    ~WS <- [ \t\n\r]* ;
  ''');

  print('\nTest C: Add Number (simple)');
  _test(r'''
    JSON <- ~WS Value ~WS ;
    Value <- Object / Array / String / Number / True / False / Null ;
    Object <- "{" ~WS Member* ~WS "}" ;
    Member <- String ~WS ":" ~WS Value ;
    Array <- "[" ~WS Value* ~WS "]" ;
    String <- "\"" (!"\""  .)* "\"" ;
    Number <- [0-9]+ ;
    True <- "true" ;
    False <- "false" ;
    Null <- "null" ;
    ~WS <- [ \t\n\r]* ;
  ''');

  print('\nTest D: Add terminal refs (LBRACE etc.)');
  _test(r'''
    JSON <- ~WS Value ~WS ;
    Value <- Object / Array / String / Number / True / False / Null ;
    Object <- LBRACE ~WS Member* ~WS RBRACE ;
    Member <- String ~WS COLON ~WS Value ;
    Array <- LBRACK ~WS Value* ~WS RBRACK ;
    String <- QUOTE (!QUOTE .)* QUOTE ;
    Number <- [0-9]+ ;
    True <- "true" ;
    False <- "false" ;
    Null <- "null" ;
    ~WS <- [ \t\n\r]* ;
    LBRACE <- "{" ;
    RBRACE <- "}" ;
    LBRACK <- "[" ;
    RBRACK <- "]" ;
    COLON <- ":" ;
    QUOTE <- "\"" ;
  ''');

  print('\nTest E: Add COMMA (for proper Member list)');
  _test(r'''
    JSON <- ~WS Value ~WS ;
    Value <- Object / Array / String / Number / True / False / Null ;
    Object <- LBRACE (~WS Member (~WS COMMA ~WS Member)*)? ~WS RBRACE ;
    Member <- String ~WS COLON ~WS Value ;
    Array <- LBRACK (~WS Value (~WS COMMA ~WS Value)*)? ~WS RBRACK ;
    String <- QUOTE (!QUOTE .)* QUOTE ;
    Number <- [0-9]+ ;
    True <- "true" ;
    False <- "false" ;
    Null <- "null" ;
    ~WS <- [ \t\n\r]* ;
    LBRACE <- "{" ;
    RBRACE <- "}" ;
    LBRACK <- "[" ;
    RBRACK <- "]" ;
    COMMA <- "," ;
    COLON <- ":" ;
    QUOTE <- "\"" ;
  ''');

  print('\nTest F: Add escape handling in String');
  _test(r'''
    JSON <- ~WS Value ~WS ;
    Value <- Object / Array / String / Number / True / False / Null ;
    Object <- LBRACE (~WS Member (~WS COMMA ~WS Member)*)? ~WS RBRACE ;
    Member <- String ~WS COLON ~WS Value ;
    Array <- LBRACK (~WS Value (~WS COMMA ~WS Value)*)? ~WS RBRACK ;
    String <- QUOTE (!QUOTE (BACKSLASH . / .))* QUOTE ;
    Number <- [0-9]+ ;
    True <- "true" ;
    False <- "false" ;
    Null <- "null" ;
    ~WS <- [ \t\n\r]* ;
    LBRACE <- "{" ;
    RBRACE <- "}" ;
    LBRACK <- "[" ;
    RBRACK <- "]" ;
    COMMA <- "," ;
    COLON <- ":" ;
    QUOTE <- "\"" ;
    BACKSLASH <- "\\" ;
  ''');

  print('\nTest G: Add complex Number');
  _test(r'''
    JSON <- ~WS Value ~WS ;
    Value <- Object / Array / String / Number / True / False / Null ;
    Object <- LBRACE (~WS Member (~WS COMMA ~WS Member)*)? ~WS RBRACE ;
    Member <- String ~WS COLON ~WS Value ;
    Array <- LBRACK (~WS Value (~WS COMMA ~WS Value)*)? ~WS RBRACK ;
    String <- QUOTE (!QUOTE (BACKSLASH . / .))* QUOTE ;
    Number <- MINUS? (ZERO / ONENINE DIGIT*) FRACTION? EXPONENT? ;
    FRACTION <- DOT DIGIT+ ;
    EXPONENT <- E SIGN? DIGIT+ ;
    True <- "true" ;
    False <- "false" ;
    Null <- "null" ;
    ~WS <- [ \t\n\r]* ;
    LBRACE <- "{" ;
    RBRACE <- "}" ;
    LBRACK <- "[" ;
    RBRACK <- "]" ;
    COMMA <- "," ;
    COLON <- ":" ;
    QUOTE <- "\"" ;
    BACKSLASH <- "\\" ;
    DOT <- "." ;
    MINUS <- "-" ;
    ZERO <- "0" ;
    ONENINE <- [1-9] ;
    DIGIT <- [0-9] ;
    E <- [eE] ;
    SIGN <- [+-] ;
  ''');
}

void _test(String grammar) {
  try {
    final result = MetaGrammar.parseGrammar(grammar);
    print('  PASSED: ${result.keys.take(3).toList()}...');
  } catch (e) {
    final errorStr = e.toString();
    final firstLine = errorStr.split('\n').first;
    print('  FAILED: $firstLine');
  }
}
