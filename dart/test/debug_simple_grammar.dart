import 'package:squirrel_parser/src/metagrammar.dart';
import 'package:squirrel_parser/src/parser/parser.dart';

void main() {
  // Test 1: Simplest possible grammar
  print('Test 1: Simple grammar');
  try {
    final grammar1 = MetaGrammar.parseGrammar(r'''
      S <- "a" ;
    ''');
    print('  PASSED: $grammar1');
  } catch (e) {
    print('  FAILED: $e');
  }

  // Test 2: Grammar with transparent rule reference
  print('\nTest 2: Transparent rule reference');
  try {
    final grammar2 = MetaGrammar.parseGrammar(r'''
      S <- ~WS "a" ~WS ;
      ~WS <- " "* ;
    ''');
    print('  PASSED: $grammar2');
  } catch (e) {
    print('  FAILED: $e');
  }

  // Test 3: Grammar with character class
  print('\nTest 3: Character class');
  try {
    final grammar3 = MetaGrammar.parseGrammar(r'''
      S <- [a-z]+ ;
    ''');
    print('  PASSED: $grammar3');
  } catch (e) {
    print('  FAILED: $e');
  }

  // Test 4: Grammar with negation
  print('\nTest 4: Negation');
  try {
    final grammar4 = MetaGrammar.parseGrammar(r'''
      S <- "a" !. ;
    ''');
    print('  PASSED: $grammar4');
  } catch (e) {
    print('  FAILED: $e');
  }

  // Test 5: String rule from JSON
  print('\nTest 5: String rule (JSON)');
  try {
    final grammar5 = MetaGrammar.parseGrammar(r'''
      String <- QUOTE (!QUOTE (BACKSLASH . / .))* QUOTE ;
      QUOTE <- "\"" ;
      BACKSLASH <- "\\" ;
    ''');
    print('  PASSED: $grammar5');
  } catch (e) {
    print('  FAILED: $e');
  }

  // Test 6: Minimal JSON
  print('\nTest 6: Minimal JSON');
  try {
    final grammar6 = MetaGrammar.parseGrammar(r'''
      JSON <- Value ;
      Value <- String / "null" ;
      String <- "\"" (!"\""  .)* "\"" ;
    ''');
    print('  PASSED: $grammar6');
  } catch (e) {
    print('  FAILED: $e');
  }
}
