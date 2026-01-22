import 'package:squirrel_parser/src/metagrammar.dart';

void main() {
  // Narrow from G4 (passes) to G5 (fails)
  // G5 adds: EXPONENT, E, SIGN

  print('Test G4 baseline (should pass)');
  final g4 = r'''
    JSON <- ~WS Value ~WS ;
    Value <- Object / Array / String / Number / True / False / Null ;
    Object <- LBRACE (~WS Member (~WS COMMA ~WS Member)*)? ~WS RBRACE ;
    Member <- String ~WS COLON ~WS Value ;
    Array <- LBRACK (~WS Value (~WS COMMA ~WS Value)*)? ~WS RBRACK ;
    String <- QUOTE (!QUOTE (BACKSLASH . / .))* QUOTE ;
    Number <- MINUS? (ZERO / ONENINE DIGIT*) FRACTION? ;
    FRACTION <- DOT DIGIT+ ;
    DIGIT <- [0-9] ;
    ZERO <- "0" ;
    ONENINE <- [1-9] ;
    MINUS <- "-" ;
    DOT <- "." ;
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
  ''';
  _test(g4);

  print('\nTest G5a: Add just E rule');
  final g5a = r'''
    JSON <- ~WS Value ~WS ;
    Value <- Object / Array / String / Number / True / False / Null ;
    Object <- LBRACE (~WS Member (~WS COMMA ~WS Member)*)? ~WS RBRACE ;
    Member <- String ~WS COLON ~WS Value ;
    Array <- LBRACK (~WS Value (~WS COMMA ~WS Value)*)? ~WS RBRACK ;
    String <- QUOTE (!QUOTE (BACKSLASH . / .))* QUOTE ;
    Number <- MINUS? (ZERO / ONENINE DIGIT*) FRACTION? ;
    FRACTION <- DOT DIGIT+ ;
    DIGIT <- [0-9] ;
    ZERO <- "0" ;
    ONENINE <- [1-9] ;
    MINUS <- "-" ;
    DOT <- "." ;
    E <- [eE] ;
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
  ''';
  _test(g5a);

  print('\nTest G5b: Add E and SIGN rules');
  final g5b = r'''
    JSON <- ~WS Value ~WS ;
    Value <- Object / Array / String / Number / True / False / Null ;
    Object <- LBRACE (~WS Member (~WS COMMA ~WS Member)*)? ~WS RBRACE ;
    Member <- String ~WS COLON ~WS Value ;
    Array <- LBRACK (~WS Value (~WS COMMA ~WS Value)*)? ~WS RBRACK ;
    String <- QUOTE (!QUOTE (BACKSLASH . / .))* QUOTE ;
    Number <- MINUS? (ZERO / ONENINE DIGIT*) FRACTION? ;
    FRACTION <- DOT DIGIT+ ;
    DIGIT <- [0-9] ;
    ZERO <- "0" ;
    ONENINE <- [1-9] ;
    MINUS <- "-" ;
    DOT <- "." ;
    E <- [eE] ;
    SIGN <- [+-] ;
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
  ''';
  _test(g5b);

  print('\nTest G5c: Add EXPONENT rule (uses E)');
  final g5c = r'''
    JSON <- ~WS Value ~WS ;
    Value <- Object / Array / String / Number / True / False / Null ;
    Object <- LBRACE (~WS Member (~WS COMMA ~WS Member)*)? ~WS RBRACE ;
    Member <- String ~WS COLON ~WS Value ;
    Array <- LBRACK (~WS Value (~WS COMMA ~WS Value)*)? ~WS RBRACK ;
    String <- QUOTE (!QUOTE (BACKSLASH . / .))* QUOTE ;
    Number <- MINUS? (ZERO / ONENINE DIGIT*) FRACTION? ;
    FRACTION <- DOT DIGIT+ ;
    EXPONENT <- E DIGIT+ ;
    DIGIT <- [0-9] ;
    ZERO <- "0" ;
    ONENINE <- [1-9] ;
    MINUS <- "-" ;
    DOT <- "." ;
    E <- [eE] ;
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
  ''';
  _test(g5c);

  print('\nTest G5d: Add EXPONENT? to Number');
  final g5d = r'''
    JSON <- ~WS Value ~WS ;
    Value <- Object / Array / String / Number / True / False / Null ;
    Object <- LBRACE (~WS Member (~WS COMMA ~WS Member)*)? ~WS RBRACE ;
    Member <- String ~WS COLON ~WS Value ;
    Array <- LBRACK (~WS Value (~WS COMMA ~WS Value)*)? ~WS RBRACK ;
    String <- QUOTE (!QUOTE (BACKSLASH . / .))* QUOTE ;
    Number <- MINUS? (ZERO / ONENINE DIGIT*) FRACTION? EXPONENT? ;
    FRACTION <- DOT DIGIT+ ;
    EXPONENT <- E DIGIT+ ;
    DIGIT <- [0-9] ;
    ZERO <- "0" ;
    ONENINE <- [1-9] ;
    MINUS <- "-" ;
    DOT <- "." ;
    E <- [eE] ;
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
  ''';
  _test(g5d);

  print('\nTest G5e: Add SIGN? to EXPONENT');
  final g5e = r'''
    JSON <- ~WS Value ~WS ;
    Value <- Object / Array / String / Number / True / False / Null ;
    Object <- LBRACE (~WS Member (~WS COMMA ~WS Member)*)? ~WS RBRACE ;
    Member <- String ~WS COLON ~WS Value ;
    Array <- LBRACK (~WS Value (~WS COMMA ~WS Value)*)? ~WS RBRACK ;
    String <- QUOTE (!QUOTE (BACKSLASH . / .))* QUOTE ;
    Number <- MINUS? (ZERO / ONENINE DIGIT*) FRACTION? EXPONENT? ;
    FRACTION <- DOT DIGIT+ ;
    EXPONENT <- E SIGN? DIGIT+ ;
    DIGIT <- [0-9] ;
    ZERO <- "0" ;
    ONENINE <- [1-9] ;
    MINUS <- "-" ;
    DOT <- "." ;
    E <- [eE] ;
    SIGN <- [+-] ;
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
  ''';
  _test(g5e);
}

void _test(String grammar) {
  try {
    final result = MetaGrammar.parseGrammar(grammar);
    print('  PASSED: ${result.keys.toList()}');
  } catch (e) {
    final errorStr = e.toString();
    final lines = errorStr.split('\n');
    print('  FAILED: ${lines.take(3).join('\n  ')}');
  }
}
