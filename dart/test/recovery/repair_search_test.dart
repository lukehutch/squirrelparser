// Tests for the minimum-cost repair search (error recovery).

import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/recovery/recovery.dart';
import 'package:test/test.dart';

RepairResult? doRepair(String grammarSpec, String input, {String top = 'S', int? window}) {
  final rules = MetaGrammar.parseGrammar(grammarSpec);
  return RepairSearch(rules: rules, topRuleName: top, window: window).repair(input);
}

void expectRepair(String grammarSpec, String input, String expectedRepaired, int expectedCost,
    {String top = 'S'}) {
  final r = doRepair(grammarSpec, input, top: top);
  expect(r, isNotNull, reason: 'repair should be found for "$input"');
  expect(r!.cost, equals(expectedCost), reason: 'cost for "$input" -> "${r.repaired}"');
  expect(r.repaired, equals(expectedRepaired), reason: 'repaired string for "$input"');
}

void main() {
  group('Basic single-error repairs', () {
    test('valid input needs no repair (cost 0)', () {
      expectRepair('S <- "a" "b" "c" ;', 'abc', 'abc', 0);
    });

    test('inserted garbage char is deleted', () {
      expectRepair('S <- "a" "b" "c" ;', 'aXbc', 'abc', 1);
    });

    test('missing char is inserted', () {
      expectRepair('S <- "a" "b" "c" ;', 'ac', 'abc', 1);
    });

    test('wrong char is substituted', () {
      expectRepair('S <- "a" "b" "c" ;', 'aXc', 'abc', 1);
    });

    test('transposed chars are transposed back (cost 1, Damerau)', () {
      expectRepair('S <- "a" "b" "c" ;', 'acb', 'abc', 1);
    });

    test('missing char at end is inserted', () {
      expectRepair('S <- "a" "b" "c" ;', 'ab', 'abc', 1);
    });

    test('missing char at start is inserted', () {
      expectRepair('S <- "a" "b" "c" ;', 'bc', 'abc', 1);
    });

    test('trailing garbage is deleted', () {
      expectRepair('S <- "a" "b" ;', 'abX', 'ab', 1);
    });

    test('completely empty input for nonempty grammar', () {
      expectRepair('S <- "a" ;', '', 'a', 1);
    });
  });

  group('Multi-error repairs', () {
    test('two independent insertions are both deleted', () {
      expectRepair('S <- "a" "b" "c" "d" ;', 'aXbcYd', 'abcd', 2);
    });

    test('two missing chars are both inserted', () {
      expectRepair('S <- "a" "b" "c" "d" ;', 'ad', 'abcd', 2);
    });

    test('mixed insertion and deletion', () {
      expectRepair('S <- "a" "b" "c" ;', 'Xac', 'abc', 2);
    });
  });

  group('Repairs before the failure point', () {
    test('missing open quote is inserted where it belongs', () {
      // Grammar: a "string" is quote, non-quote chars, quote; then colon+digit.
      // Input is missing the opening quote: the parse fails far past the
      // actual error location; minimal repair must place the quote early.
      const g = 'S <- Str ":" [0-9] ;\nStr <- \'"\' [a-z]* \'"\' ;';
      final r = doRepair(g, 'ab":1');
      expect(r, isNotNull);
      expect(r!.cost, equals(1));
      expect(r.repaired, equals('"ab":1'));
    });
  });

  group('Choice and repetition repairs', () {
    test('choice picks the cheapest alternative to repair toward', () {
      // 'nQn' should become 'n+n' (substitute) rather than something longer.
      const g = 'S <- "n" "+" "n" / "n" "-" "n" ;';
      final r = doRepair(g, 'nQn');
      expect(r, isNotNull);
      expect(r!.cost, equals(1));
      expect(r.repaired, equals('n+n'));
    });

    test('missing separator in a list', () {
      const g = 'S <- "[" N ("," N)* "]" ;\nN <- [0-9] ;';
      expectRepair(g, '[1 2]'.replaceAll(' ', ''), '[12]'.replaceAll('12', '1,2'), 1);
    });

    test('garbage inside a repetition', () {
      const g = 'S <- [a-z]+ ;';
      expectRepair(g, 'abZcd'.replaceAll('Z', 'Q'), 'abcd', 1);
    });

    test('unclosed bracket is closed', () {
      const g = 'S <- "[" [a-z]* "]" ;';
      expectRepair(g, '[abc', '[abc]', 1);
    });
  });

  group('Left recursion composes with recovery', () {
    const exprGrammar = '''
      E <- E "+" T / T ;
      T <- T "*" F / F ;
      F <- "(" E ")" / [0-9] ;
    ''';

    test('valid left-recursive expression needs no repair', () {
      expectRepair(exprGrammar, '1+2*3', '1+2*3', 0, top: 'E');
    });

    test('missing operand in left-recursive expression', () {
      final r = doRepair(exprGrammar, '1+*3', top: 'E');
      expect(r, isNotNull);
      expect(r!.cost, equals(1));
      // Any single edit yielding a valid expression is acceptable; deleting
      // either operator or inserting an operand all cost 1.
      final ok = ['1*3', '1+3', '1+0*3', '1+1*3', '13'].contains(r.repaired) ||
          RegExp(r'^1\+[0-9]\*3$').hasMatch(r.repaired);
      expect(ok, isTrue, reason: 'got "${r.repaired}"');
    });

    test('garbage in left-recursive expression', () {
      final r = doRepair(exprGrammar, '1+2Q*3', top: 'E');
      expect(r, isNotNull);
      expect(r!.cost, equals(1));
      expect(r.repaired, equals('1+2*3'));
    });

    test('unbalanced parens in left-recursive expression', () {
      final r = doRepair(exprGrammar, '(1+2*3', top: 'E');
      expect(r, isNotNull);
      expect(r!.cost, equals(1));
      expect(r.repaired, equals('(1+2*3)'));
    });
  });

  group('Edit reporting', () {
    test('edits are reported in original coordinates', () {
      final r = doRepair('S <- "a" "b" "c" ;', 'aXbc');
      expect(r, isNotNull);
      expect(r!.edits.length, equals(1));
      expect(r.edits.first.type, equals(EditType.delete));
      expect(r.edits.first.pos, equals(1));
    });

    test('insertion edit is reported', () {
      final r = doRepair('S <- "a" "b" "c" ;', 'ac');
      expect(r, isNotNull);
      expect(r!.edits.length, equals(1));
      expect(r.edits.first.type, equals(EditType.insert));
      expect(r.edits.first.text, equals('b'));
    });
  });
}
