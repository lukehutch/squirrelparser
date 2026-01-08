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
        Map<String, Clause> Function(int size) makeRules,
        String Function(int size) makeInput,
        String topRule,
        List<int> sizes) {
      final results = <(int, int, double)>[];

      for (final size in sizes) {
        parserStats!.reset();
        final rules = makeRules(size);
        final input = makeInput(size);
        final parser = Parser(rules: rules, input: input);
        final (result, _) = parser.parse(topRule);

        final work = parserStats!.totalWork;
        final success =
            !result.isMismatch && result.len == input.length;
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
        (size) => {'S': OneOrMore(Str('x'))},
        (size) => 'x' * size,
        'S',
        [10, 50, 100, 500],
      );
      expect(passed, isTrue,
          reason: 'simple repetition should be linear (ratio change: $change)');
    });

    test('LINEAR-02-direct-lr', () {
      final (passed, change) = testLinearity(
        (size) => {
          'E': First([
            Seq([Ref('E'), Str('+'), Ref('N')]),
            Ref('N')
          ]),
          'N': CharRange('0', '9'),
        },
        (size) {
          final nums = List.generate(size + 1, (i) => '${i % 10}');
          return nums.join('+');
        },
        'E',
        [5, 10, 20, 50],
      );
      expect(passed, isTrue,
          reason: 'direct LR should be linear (ratio change: $change)');
    });

    test('LINEAR-03-indirect-lr', () {
      final (passed, change) = testLinearity(
        (size) => {
          'A': First([Ref('B'), Str('x')]),
          'B': First([
            Seq([Ref('A'), Str('y')]),
            Seq([Ref('A'), Str('x')])
          ]),
        },
        (size) {
          var s = 'x';
          for (var i = 0; i < size ~/ 2; i++) {
            s += 'xy';
          }
          return s.substring(0, size > 0 ? size : 1);
        },
        'A',
        [5, 10, 20, 50],
      );
      expect(passed, isTrue,
          reason: 'indirect LR should be linear (ratio change: $change)');
    });

    test('LINEAR-04-interwoven-lr', () {
      final (passed, change) = testLinearity(
        (size) => {
          'L': First([
            Seq([Ref('P'), Str('.x')]),
            Str('x')
          ]),
          'P': First([
            Seq([Ref('P'), Str('(n)')]),
            Ref('L')
          ]),
        },
        (size) {
          final parts = ['x'];
          for (var i = 0; i < size; i++) {
            parts.add(i % 3 == 0 ? '.x' : '(n)');
          }
          return parts.join();
        },
        'L',
        [5, 10, 20, 50],
      );
      expect(passed, isTrue,
          reason: 'interwoven LR should be linear (ratio change: $change)');
    });

    test('LINEAR-05-deep-nesting', () {
      final (passed, change) = testLinearity(
        (size) => {
          'E': First([
            Seq([Str('('), Ref('E'), Str(')')]),
            Str('x')
          ]),
        },
        (size) => '${'(' * size}x${')' * size}',
        'E',
        [5, 10, 20, 50],
      );
      expect(passed, isTrue,
          reason: 'deep nesting should be linear (ratio change: $change)');
    });

    test('LINEAR-06-precedence', () {
      final (passed, change) = testLinearity(
        (size) => {
          'E': First([
            Seq([Ref('E'), Str('+'), Ref('T')]),
            Ref('T')
          ]),
          'T': First([
            Seq([Ref('T'), Str('*'), Ref('F')]),
            Ref('F')
          ]),
          'F': First([
            Seq([Str('('), Ref('E'), Str(')')]),
            Ref('N')
          ]),
          'N': CharRange('0', '9'),
        },
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
        'E',
        [5, 10, 20, 50],
      );
      expect(passed, isTrue,
          reason:
              'precedence grammar should be linear (ratio change: $change)');
    });

    test('LINEAR-07-ambiguous', () {
      final (passed, change) = testLinearity(
        (size) => {
          'E': First([
            Seq([Ref('E'), Str('+'), Ref('E')]),
            Ref('N')
          ]),
          'N': CharRange('0', '9'),
        },
        (size) {
          final nums = List.generate(size + 1, (i) => '${i % 10}');
          return nums.join('+');
        },
        'E',
        [3, 5, 7, 10], // Smaller sizes for ambiguous grammar
      );
      expect(passed, isTrue,
          reason: 'ambiguous grammar should be linear (ratio change: $change)');
    });

    test('LINEAR-08-long-input', () {
      final (passed, change) = testLinearity(
        (size) => {
          'S': OneOrMore(Seq([Str('a'), Str('b'), Str('c')])),
        },
        (size) => 'abc' * size,
        'S',
        [100, 500, 1000, 2000],
      );
      expect(passed, isTrue,
          reason: 'long input should be linear (ratio change: $change)');
    });

    test('LINEAR-09-long-lr', () {
      final (passed, change) = testLinearity(
        (size) => {
          'E': First([
            Seq([Ref('E'), Str('+'), Ref('N')]),
            Ref('N')
          ]),
          'N': CharRange('0', '9'),
        },
        (size) {
          final nums = List.generate(size, (i) => '${i % 10}');
          return nums.join('+');
        },
        'E',
        [50, 100, 200, 500],
      );
      expect(passed, isTrue,
          reason: 'long LR input should be linear (ratio change: $change)');
    });

    test('LINEAR-10-recovery', () {
      final (passed, change) = testLinearity(
        (size) => {
          'S': OneOrMore(Seq([Str('('), OneOrMore(Str('x')), Str(')')])),
        },
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
        'S',
        [10, 20, 50, 100],
      );
      expect(passed, isTrue,
          reason: 'recovery should be linear (ratio change: $change)');
    });
  });
}
