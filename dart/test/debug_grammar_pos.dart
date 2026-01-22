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
  print('Total length: ${jsonGrammar.length}');
  print('First 20 chars: "${jsonGrammar.substring(0, 20)}"');
  print('Char at pos 14: "${jsonGrammar.substring(14, 15)}"');
  print('Substring 14-40: "${jsonGrammar.substring(14, 40)}"');
  print('Substring 308-350: "${jsonGrammar.substring(308, 350)}"');

  // Show positions around key error points
  for (final pos in [14, 308, 548, 553]) {
    final start = pos > 10 ? pos - 10 : 0;
    final end = pos + 10 < jsonGrammar.length ? pos + 10 : jsonGrammar.length;
    print('Around pos $pos: "${jsonGrammar.substring(start, end)}"');
  }
}
