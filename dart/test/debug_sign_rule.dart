import 'package:squirrel_parser/src/metagrammar.dart';

void main() {
  print('Test 1: Just SIGN rule (isolated)');
  _test(r'''
    SIGN <- [+-] ;
  ''');

  print('\nTest 2: SIGN with + first');
  _test(r'''
    SIGN <- [+] ;
  ''');

  print('\nTest 3: SIGN with - first');
  _test(r'''
    SIGN <- [-] ;
  ''');

  print('\nTest 4: SIGN with + and -');
  _test(r'''
    SIGN <- [+-] ;
  ''');

  print('\nTest 5: Two rules, one is SIGN');
  _test(r'''
    S <- SIGN ;
    SIGN <- [+-] ;
  ''');

  print('\nTest 6: Escape the -');
  _test(r'''
    SIGN <- [+\-] ;
  ''');

  print('\nTest 7: Use range syntax');
  _test(r'''
    SIGN <- [+] / [-] ;
  ''');

  print('\nTest 8: Put - at end');
  _test(r'''
    SIGN <- [-+] ;
  ''');

  print('\nTest 9: Use named char');
  _test(r'''
    Plus <- "+" ;
    Minus <- "-" ;
    SIGN <- Plus / Minus ;
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
