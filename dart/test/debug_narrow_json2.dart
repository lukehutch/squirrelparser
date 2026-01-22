import 'package:squirrel_parser/src/metagrammar.dart';

void main() {
  // Narrow down from Test F (passes) to Test G (fails)
  // The difference is the complex Number rule

  print('Test F baseline (should pass)');
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

  print('\nTest G1: Add just DIGIT');
  _test(r'''
    JSON <- ~WS Value ~WS ;
    Value <- Object / Array / String / Number / True / False / Null ;
    Object <- LBRACE (~WS Member (~WS COMMA ~WS Member)*)? ~WS RBRACE ;
    Member <- String ~WS COLON ~WS Value ;
    Array <- LBRACK (~WS Value (~WS COMMA ~WS Value)*)? ~WS RBRACK ;
    String <- QUOTE (!QUOTE (BACKSLASH . / .))* QUOTE ;
    Number <- DIGIT+ ;
    DIGIT <- [0-9] ;
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

  print('\nTest G2: Add ZERO and ONENINE');
  _test(r'''
    JSON <- ~WS Value ~WS ;
    Value <- Object / Array / String / Number / True / False / Null ;
    Object <- LBRACE (~WS Member (~WS COMMA ~WS Member)*)? ~WS RBRACE ;
    Member <- String ~WS COLON ~WS Value ;
    Array <- LBRACK (~WS Value (~WS COMMA ~WS Value)*)? ~WS RBRACK ;
    String <- QUOTE (!QUOTE (BACKSLASH . / .))* QUOTE ;
    Number <- ZERO / ONENINE DIGIT* ;
    DIGIT <- [0-9] ;
    ZERO <- "0" ;
    ONENINE <- [1-9] ;
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

  print('\nTest G3: Add MINUS optional');
  _test(r'''
    JSON <- ~WS Value ~WS ;
    Value <- Object / Array / String / Number / True / False / Null ;
    Object <- LBRACE (~WS Member (~WS COMMA ~WS Member)*)? ~WS RBRACE ;
    Member <- String ~WS COLON ~WS Value ;
    Array <- LBRACK (~WS Value (~WS COMMA ~WS Value)*)? ~WS RBRACK ;
    String <- QUOTE (!QUOTE (BACKSLASH . / .))* QUOTE ;
    Number <- MINUS? (ZERO / ONENINE DIGIT*) ;
    DIGIT <- [0-9] ;
    ZERO <- "0" ;
    ONENINE <- [1-9] ;
    MINUS <- "-" ;
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

  print('\nTest G4: Add DOT and FRACTION');
  _test(r'''
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
  ''');

  print('\nTest G5: Add E, SIGN, EXPONENT');
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
  ''');
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
