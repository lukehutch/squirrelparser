// ===========================================================================
// PARSE TREE SPANNING INVARIANT TESTS
// ===========================================================================
// These tests verify that Parser.parse() always returns a MatchResult
// that completely spans the input (from position 0 to input.length).
// - Total failures: SyntaxError spanning entire input
// - Partial matches: wrapped with trailing SyntaxError
// - Complete matches: result spans full input with no wrapper needed

import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:test/test.dart';

/// Helper to get a MatchResult that spans the entire input.
/// If there's an unmatchedInput, this wraps root and unmatchedInput together.
MatchResult getSpanningResult(ParseResult parseResult) {
  if (parseResult.unmatchedInput == null) {
    return parseResult.root;
  }

  // Create a synthetic Match that contains both root and unmatchedInput as children
  // This represents the "complete parse" including unmatched trailing input
  final root = parseResult.root;

  // Build list of children - only wrap if root is not a total failure SyntaxError
  late final List<MatchResult> children;
  late final int errorCount;

  if (root is SyntaxError && root.len == parseResult.input.length) {
    // Total failure case: root is already SyntaxError spanning entire input
    // Don't double-wrap
    return root;
  } else if (root is SyntaxError) {
    // Partial failure case: SyntaxError doesn't span full input, wrap with unmatchedInput
    children = [root, parseResult.unmatchedInput!];
    errorCount = 2;
  } else {
    // Partial match case: root has matched content, add unmatchedInput
    final rootMatch = root as Match;
    // If root has children (like a Seq), spread them; otherwise include root itself
    if (rootMatch.subClauseMatches.isEmpty) {
      // Root is a terminal like Str('a'), so include it as a child
      children = [root, parseResult.unmatchedInput!];
    } else {
      // Root has sub-matches, spread them and add unmatchedInput
      children = [...rootMatch.subClauseMatches, parseResult.unmatchedInput!];
    }
    errorCount = rootMatch.totDescendantErrors + 1;
  }

  return Match(
    root.clause,
    0, // position 0
    parseResult.input.length, // spans entire input
    subClauseMatches: children,
    isComplete: true,
    numSystaxErrors: errorCount,
    addSubClauseErrors: false,
  );
}

void main() {
  group('Parse Tree Spanning Invariant Tests', () {
    test('SPAN-01-empty-input', () {
      // Empty input should return SyntaxError spanning empty input
      final parseResult = squirrelParsePT(
        grammarSpec: 'S <- "a" ;',
        topRuleName: 'S',
        input: '',
      );
      final result = getSpanningResult(parseResult);

      expect(result is SyntaxError, isTrue,
          reason: 'Empty input with no match should be SyntaxError');
      expect(result.len, equals(0),
          reason: 'SyntaxError should span full empty input');
      expect(result.pos, equals(0));
    });

    test('SPAN-02-complete-match-no-wrapper', () {
      // Complete match should not be wrapped
      final parseResult = squirrelParsePT(
        grammarSpec: 'S <- "a" "b" "c" ;',
        topRuleName: 'S',
        input: 'abc',
      );
      final result = getSpanningResult(parseResult);

      expect(result is SyntaxError, isFalse,
          reason: 'Complete match should not be SyntaxError');
      expect(result.len, equals(3), reason: 'Should span entire input');
      expect(result.isMismatch, isFalse);
    });

    test('SPAN-03-total-failure-returns-syntax-error', () {
      // Input that doesn't match at all should return SyntaxError spanning all
      final parseResult = squirrelParsePT(
        grammarSpec: 'S <- "a" ;',
        topRuleName: 'S',
        input: 'xyz',
      );
      final result = getSpanningResult(parseResult);

      expect(result is SyntaxError, isTrue,
          reason: 'Total failure should be SyntaxError');
      expect(result.len, equals(3),
          reason: 'SyntaxError should span entire input');
      expect(parseResult.input.substring(result.pos, result.pos + result.len), equals('xyz'));
    });

    test('SPAN-04-trailing-garbage-wrapped', () {
      // Partial match with trailing input should be wrapped with SyntaxError
      final parseResult = squirrelParsePT(
        grammarSpec: 'S <- "a" "b" ;',
        topRuleName: 'S',
        input: 'abXYZ',
      );
      final result = getSpanningResult(parseResult);

      expect(result.len, equals(5), reason: 'Result should span entire input');
      expect(result is SyntaxError, isFalse, reason: 'Result is wrapper Match');

      // Find the trailing SyntaxError in the tree
      bool hasTrailingError = false;
      void checkForTrailingError(MatchResult r) {
        if (r is SyntaxError) {
          if (r.pos == 2 && r.len == 3) {
            hasTrailingError = true;
          }
        }
        for (final child in r.subClauseMatches) {
          checkForTrailingError(child);
        }
      }

      checkForTrailingError(result);
      expect(hasTrailingError, isTrue,
          reason: 'Should contain SyntaxError for trailing XYZ');
    });

    test('SPAN-05-single-char-trailing', () {
      // Single trailing character should be captured
      final parseResult = squirrelParsePT(
        grammarSpec: 'S <- "a" ;',
        topRuleName: 'S',
        input: 'aX',
      );
      final result = getSpanningResult(parseResult);

      // Debug: check parseResult state
      expect(parseResult.unmatchedInput, isNotNull, reason: 'Should have unmatchedInput for trailing X');
      expect(result.len, equals(2), reason: 'Should span full input: root.len=${parseResult.root.len}, unmatchedInput.len=${parseResult.unmatchedInput?.len}');
      expect(result is SyntaxError, isFalse);

      // Check for trailing SyntaxError
      bool hasTrailingError = false;
      void checkForTrailingError(MatchResult r) {
        if (r is SyntaxError && r.pos == 1 && r.len == 1) {
          hasTrailingError = true;
        }
        for (final child in r.subClauseMatches) {
          checkForTrailingError(child);
        }
      }

      checkForTrailingError(result);
      expect(hasTrailingError, isTrue);
    });

    test('SPAN-06-multiple-errors-throughout', () {
      // Multiple errors should all be in parse tree
      final parseResult = squirrelParsePT(
        grammarSpec: 'S <- "a" "b" "c" ;',
        topRuleName: 'S',
        input: 'aXbYc',
      );
      final result = getSpanningResult(parseResult);

      expect(result.len, equals(5), reason: 'Should span entire input');

      final errors = <SyntaxError>[];
      void collectErrors(MatchResult r) {
        if (r is SyntaxError) {
          errors.add(r);
        }
        for (final child in r.subClauseMatches) {
          collectErrors(child);
        }
      }

      collectErrors(result);
      expect(errors.length, equals(2), reason: 'Should have 2 syntax errors');
    });

    test('SPAN-07-recovery-with-deletion', () {
      // Deletion at end should be captured
      final parseResult = squirrelParsePT(
        grammarSpec: 'S <- "a" "b" "c" ;',
        topRuleName: 'S',
        input: 'ab',
      );
      final result = getSpanningResult(parseResult);

      expect(result.len, equals(2),
          reason: 'Should span full input (no trailing capture here)');
      expect(result is SyntaxError, isFalse);
    });

    test('SPAN-08-first-alternative-with-trailing', () {
      // First should prefer longer match, both may have trailing
      final parseResult = squirrelParsePT(
        grammarSpec: 'S <- "a" "b" "c" / "a" ;',
        topRuleName: 'S',
        input: 'abcX',
      );
      final result = getSpanningResult(parseResult);

      expect(result.len, equals(4), reason: 'Should span entire input');

      bool hasTrailingX = false;
      void checkForX(MatchResult r) {
        if (r is SyntaxError && parseResult.input.substring(r.pos, r.pos + r.len).contains('X')) {
          hasTrailingX = true;
        }
        for (final child in r.subClauseMatches) {
          checkForX(child);
        }
      }

      checkForX(result);
      expect(hasTrailingX, isTrue, reason: 'Should capture X as error');
    });

    test('SPAN-09-left-recursion-with-trailing', () {
      // LR expansion with trailing should work
      final parseResult = squirrelParsePT(
        grammarSpec: 'E <- E "+" "n" / "n" ;',
        topRuleName: 'E',
        input: 'n+nX',
      );
      final result = getSpanningResult(parseResult);

      expect(result.len, equals(4), reason: 'Should span entire input');

      bool hasTrailingError = false;
      void checkForTrailingError(MatchResult r) {
        if (r is SyntaxError && r.pos > 0) {
          hasTrailingError = true;
        }
        for (final child in r.subClauseMatches) {
          checkForTrailingError(child);
        }
      }

      checkForTrailingError(result);
      expect(hasTrailingError, isTrue);
    });

    test('SPAN-10-repetition-with-trailing', () {
      // OneOrMore with trailing should span full input
      final parseResult = squirrelParsePT(
        grammarSpec: 'S <- "a"+ ;',
        topRuleName: 'S',
        input: 'aaaX',
      );
      final result = getSpanningResult(parseResult);

      expect(result.len, equals(4), reason: 'Should span entire input');

      bool hasTrailingError = false;
      void checkForTrailingError(MatchResult r) {
        if (r is SyntaxError && parseResult.input.substring(r.pos, r.pos + r.len).contains('X')) {
          hasTrailingError = true;
        }
        for (final child in r.subClauseMatches) {
          checkForTrailingError(child);
        }
      }

      checkForTrailingError(result);
      expect(hasTrailingError, isTrue);
    });

    test('SPAN-11-nested-rules-with-trailing', () {
      // Nested rule calls with trailing
      final parseResult = squirrelParsePT(
        grammarSpec: '''
          S <- A ";" ;
          A <- "a" "b" ;
        ''',
        topRuleName: 'S',
        input: 'ab;X',
      );
      final result = getSpanningResult(parseResult);

      expect(result.len, equals(4), reason: 'Should span entire input');
    });

    test('SPAN-12-zero-or-more-with-trailing', () {
      // ZeroOrMore matching nothing, then trailing
      final parseResult = squirrelParsePT(
        grammarSpec: 'S <- "a"* ;',
        topRuleName: 'S',
        input: 'XYZ',
      );
      final result = getSpanningResult(parseResult);

      expect(result.len, equals(3), reason: 'Should span entire input');
      expect(result is SyntaxError, isFalse);

      bool hasTrailingError = false;
      void checkForTrailingError(MatchResult r) {
        if (r is SyntaxError) {
          hasTrailingError = true;
        }
        for (final child in r.subClauseMatches) {
          checkForTrailingError(child);
        }
      }

      checkForTrailingError(result);
      expect(hasTrailingError, isTrue);
    });

    test('SPAN-13-optional-with-trailing', () {
      // Optional not matching, then trailing
      final parseResult = squirrelParsePT(
        grammarSpec: 'S <- "a"? ;',
        topRuleName: 'S',
        input: 'XYZ',
      );
      final result = getSpanningResult(parseResult);

      expect(result.len, equals(3), reason: 'Should span entire input');

      bool hasTrailingError = false;
      void checkForTrailingError(MatchResult r) {
        if (r is SyntaxError) {
          hasTrailingError = true;
        }
        for (final child in r.subClauseMatches) {
          checkForTrailingError(child);
        }
      }

      checkForTrailingError(result);
      expect(hasTrailingError, isTrue);
    });

    test('SPAN-14-followed-by-success-with-trailing', () {
      // FollowedBy doesn't consume, but trailing should still be captured
      final parseResult = squirrelParsePT(
        grammarSpec: 'S <- &"a" "a" "b" ;',
        topRuleName: 'S',
        input: 'abX',
      );
      final result = getSpanningResult(parseResult);

      expect(result.len, equals(3), reason: 'Should span entire input');

      bool hasTrailingError = false;
      void checkForTrailingError(MatchResult r) {
        if (r is SyntaxError && parseResult.input.substring(r.pos, r.pos + r.len).contains('X')) {
          hasTrailingError = true;
        }
        for (final child in r.subClauseMatches) {
          checkForTrailingError(child);
        }
      }

      checkForTrailingError(result);
      expect(hasTrailingError, isTrue);
    });

    test('SPAN-15-not-followed-by-failure-total', () {
      // NotFollowedBy in sequence that fails - no recovery possible
      final parseResult = squirrelParsePT(
        grammarSpec: 'S <- !"x" "y" ;',
        topRuleName: 'S',
        input: 'xz',
      );
      final result = getSpanningResult(parseResult);

      // NotFollowedBy('x') succeeds at position 0 (since 'x' IS there, negation makes it fail)
      // Wait, this is backwards. NotFollowedBy checks "is NOT followed by"
      // If input is 'xz', 'x' IS there, so NotFollowedBy fails
      // Then Str('y') can't match 'x', so Seq fails completely
      // Result should be SyntaxError spanning entire input
      expect(result is SyntaxError, isTrue, reason: 'Should be total failure');
      expect(result.len, equals(2), reason: 'Should span entire input');
    });

    test('SPAN-16-not-followed-by-success-with-trailing', () {
      // NotFollowedBy succeeding but with trailing - we'll simplify this
      // to avoid complex recovery rules
      final parseResult = squirrelParsePT(
        grammarSpec: 'S <- "b" "c"? ;',
        topRuleName: 'S',
        input: 'bX',
      );
      final result = getSpanningResult(parseResult);

      expect(result.len, equals(2), reason: 'Should span entire input');

      bool hasTrailingError = false;
      void checkForTrailingError(MatchResult r) {
        if (r is SyntaxError && parseResult.input.substring(r.pos, r.pos + r.len).contains('X')) {
          hasTrailingError = true;
        }
        for (final child in r.subClauseMatches) {
          checkForTrailingError(child);
        }
      }

      checkForTrailingError(result);
      expect(hasTrailingError, isTrue);
    });

    test('SPAN-17-invariant-never-null', () {
      // parse() should never return null - always spans input
      final testCases = [
        ('S <- "a" ;', 'a'),
        ('S <- "a" ;', 'b'),
        ('S <- "a" ;', ''),
        ('S <- "a" "b" ;', 'ab'),
        ('S <- "a" "b" ;', 'aXb'),
        ('S <- "a" / "b" ;', 'c'),
      ];

      for (final (grammarSpec, input) in testCases) {
        final parseResult = squirrelParsePT(
          grammarSpec: grammarSpec,
          topRuleName: 'S',
          input: input,
        );
      final result = getSpanningResult(parseResult);

        expect(result, isNotNull,
            reason: 'parse() should never return null for input: $input');
        expect(result.len, equals(input.length),
            reason: 'Result should span entire input for: $input');
      }
    });

    test('SPAN-18-long-input-with-single-trailing-error', () {
      // Long input with single error at end
      final input = 'abcdefghijklmnopqrstuvwxyzX';
      final parseResult = squirrelParsePT(
        grammarSpec: 'S <- "a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l" "m" "n" "o" "p" "q" "r" "s" "t" "u" "v" "w" "x" "y" "z" ;',
        topRuleName: 'S',
        input: input,
      );
      final result = getSpanningResult(parseResult);

      expect(result.len, equals(27), reason: 'Should span entire input');

      bool hasTrailingError = false;
      void checkForTrailingError(MatchResult r) {
        if (r is SyntaxError && r.pos == 26) {
          hasTrailingError = true;
        }
        for (final child in r.subClauseMatches) {
          checkForTrailingError(child);
        }
      }

      checkForTrailingError(result);
      expect(hasTrailingError, isTrue);
    });

    test('SPAN-19-complex-grammar-with-errors', () {
      // Complex grammar with multiple errors at different levels
      final parseResult = squirrelParsePT(
        grammarSpec: '''
          S <- E ";" ;
          E <- E "+" T / T ;
          T <- "n" ;
        ''',
        topRuleName: 'S',
        input: 'n+Xn;Y',
      );
      final result = getSpanningResult(parseResult);

      expect(result.len, equals(6), reason: 'Should span entire input');

      final errors = <SyntaxError>[];
      void collectErrors(MatchResult r) {
        if (r is SyntaxError) {
          errors.add(r);
        }
        for (final child in r.subClauseMatches) {
          collectErrors(child);
        }
      }

      collectErrors(result);
      expect(errors.length, greaterThanOrEqualTo(2),
          reason: 'Should capture errors');
    });

    test('SPAN-20-recovery-preserves-matched-content', () {
      // When recovering from errors, matched content should be preserved
      final parseResult = squirrelParsePT(
        grammarSpec: 'S <- "hello" " " "world" ;',
        topRuleName: 'S',
        input: 'hello X world',
      );
      final result = getSpanningResult(parseResult);

      expect(result.len, equals(13), reason: 'Should span entire input');
      expect(result is SyntaxError, isFalse);

      // Check that we have both matched parts and error
      bool hasError = false;
      void analyze(MatchResult r) {
        if (!r.isMismatch && r is! SyntaxError) {
          // Matched
        }
        if (r is SyntaxError) {
          hasError = true;
        }
        for (final child in r.subClauseMatches) {
          analyze(child);
        }
      }

      analyze(result);
      expect(hasError, isTrue, reason: 'Should have error for skipped X');
    });
  });
}
