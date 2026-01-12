// ===========================================================================
// SECTION 12: LINEARITY TESTS (10 tests)
// ===========================================================================
// Verify O(N) complexity where N is input length.
// Work should scale linearly with input size.

import 'package:test/test.dart';

import 'package:squirrel_parser/squirrel_parser.dart';

void main() {
  group('Linearity Tests', () {
    setUpAll(() {
      // Enable stats tracking for linearity tests
      parserStats = ParserStats();
    });

    tearDownAll(() {
      // Disable stats tracking after linearity tests
      parserStats = null;
    });

    /// Test linearity helper: returns (passed, ratio_change) where ratio_change < 2 means linear.
    (bool, double) testLinearity(
        String grammarSpec,
        String topRule,
        String Function(int size) makeInput,
        List<int> sizes) {
      final results = <(int, int, double)>[];

      for (final size in sizes) {
        parserStats!.reset();
        final input = makeInput(size);
        final parseResult = squirrelParsePT(
          grammarSpec: grammarSpec,
          topRuleName: topRule,
          input: input,
        );
        final result = parseResult.root;

        final work = parserStats!.totalWork;
        final success = !result.isMismatch && result.len == input.length;
        final ratio = size > 0 ? work / size : 0.0;

        results.add((size, work, ratio));

        if (!success) {
          return (false, double.infinity);
        }
      }

      // Check ratio doesn't increase significantly
      final ratios = results.map((r) => r.$3).toList();
      if (ratios.isEmpty || ratios.first == 0) return (false, double.infinity);

      final ratioChange = ratios.last / ratios.first;
      return (ratioChange <= 2.0, ratioChange);
    }

    test('LINEAR-01-simple-rep', () {
      final (passed, change) = testLinearity(
        'S <- "x"+ ;',
        'S',
        (size) => 'x' * size,
        [10, 50, 100, 500],
      );
      expect(passed, isTrue,
          reason: 'simple repetition should be linear (ratio change: $change)');
    });

    test('LINEAR-02-direct-lr', () {
      const grammar = '''
        E <- E "+" N / N ;
        N <- [0-9] ;
      ''';
      final (passed, change) = testLinearity(
        grammar,
        'E',
        (size) {
          final nums = List.generate(size + 1, (i) => '${i % 10}');
          return nums.join('+');
        },
        [5, 10, 20, 50],
      );
      expect(passed, isTrue,
          reason: 'direct LR should be linear (ratio change: $change)');
    });

    test('LINEAR-03-indirect-lr', () {
      const grammar = '''
        A <- B / "x" ;
        B <- A "y" / A "x" ;
      ''';
      final (passed, change) = testLinearity(
        grammar,
        'A',
        (size) {
          var s = 'x';
          for (var i = 0; i < size ~/ 2; i++) {
            s += 'xy';
          }
          return s.substring(0, size > 0 ? size : 1);
        },
        [5, 10, 20, 50],
      );
      expect(passed, isTrue,
          reason: 'indirect LR should be linear (ratio change: $change)');
    });

    test('LINEAR-04-interwoven-lr', () {
      const grammar = '''
        L <- P ".x" / "x" ;
        P <- P "(n)" / L ;
      ''';
      final (passed, change) = testLinearity(
        grammar,
        'L',
        (size) {
          final parts = ['x'];
          for (var i = 0; i < size; i++) {
            parts.add(i % 3 == 0 ? '.x' : '(n)');
          }
          return parts.join();
        },
        [5, 10, 20, 50],
      );
      expect(passed, isTrue,
          reason: 'interwoven LR should be linear (ratio change: $change)');
    });

    test('LINEAR-05-deep-nesting', () {
      const grammar = '''
        E <- "(" E ")" / "x" ;
      ''';
      final (passed, change) = testLinearity(
        grammar,
        'E',
        (size) => '${'(' * size}x${')' * size}',
        [5, 10, 20, 50],
      );
      expect(passed, isTrue,
          reason: 'deep nesting should be linear (ratio change: $change)');
    });

    test('LINEAR-06-precedence', () {
      const grammar = '''
        E <- E "+" T / T ;
        T <- T "*" F / F ;
        F <- "(" E ")" / N ;
        N <- [0-9] ;
      ''';
      final (passed, change) = testLinearity(
        grammar,
        'E',
        (size) {
          final parts = <String>[];
          for (var i = 0; i < size; i++) {
            parts.add('${i % 10}');
            if (i < size - 1) {
              parts.add(i % 2 == 0 ? '+' : '*');
            }
          }
          return parts.join();
        },
        [5, 10, 20, 50],
      );
      expect(passed, isTrue,
          reason:
              'precedence grammar should be linear (ratio change: $change)');
    });

    test('LINEAR-07-ambiguous', () {
      const grammar = '''
        E <- E "+" E / N ;
        N <- [0-9] ;
      ''';
      final (passed, change) = testLinearity(
        grammar,
        'E',
        (size) {
          final nums = List.generate(size + 1, (i) => '${i % 10}');
          return nums.join('+');
        },
        [3, 5, 7, 10], // Smaller sizes for ambiguous grammar
      );
      expect(passed, isTrue,
          reason: 'ambiguous grammar should be linear (ratio change: $change)');
    });

    test('LINEAR-08-long-input', () {
      const grammar = '''
        S <- ("a" "b" "c")+ ;
      ''';
      final (passed, change) = testLinearity(
        grammar,
        'S',
        (size) => 'abc' * size,
        [100, 500, 1000, 2000],
      );
      expect(passed, isTrue,
          reason: 'long input should be linear (ratio change: $change)');
    });

    test('LINEAR-09-long-lr', () {
      const grammar = '''
        E <- E "+" N / N ;
        N <- [0-9] ;
      ''';
      final (passed, change) = testLinearity(
        grammar,
        'E',
        (size) {
          final nums = List.generate(size, (i) => '${i % 10}');
          return nums.join('+');
        },
        [50, 100, 200, 500],
      );
      expect(passed, isTrue,
          reason: 'long LR input should be linear (ratio change: $change)');
    });

    test('LINEAR-10-recovery', () {
      const grammar = '''
        S <- ("(" "x"+ ")")+ ;
      ''';
      final (passed, change) = testLinearity(
        grammar,
        'S',
        (size) {
          final parts = <String>[];
          for (var i = 0; i < size; i++) {
            if (i > 0 && i % 10 == 0) {
              parts.add('(xZx)'); // Error
            } else {
              parts.add('(xx)');
            }
          }
          return parts.join();
        },
        [10, 20, 50, 100],
      );
      expect(passed, isTrue,
          reason: 'recovery should be linear (ratio change: $change)');
    });
  });
}
