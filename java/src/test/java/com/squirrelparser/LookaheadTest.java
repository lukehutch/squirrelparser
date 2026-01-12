package com.squirrelparser;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

class LookaheadTest {

    @Nested
    class FollowedByTests {

        @Test
        void positiveLookaheadSucceedsWhenPatternMatches() {
            var result = SquirrelParser.squirrelParsePT("Test <- &\"a\" ;", "Test", "abc");
            assertFalse(result.root().isMismatch());
            assertEquals(0, result.root().len()); // Lookahead doesn't consume
        }

        @Test
        void positiveLookaheadFailsWhenPatternDoesNotMatch() {
            var result = SquirrelParser.squirrelParsePT("Test <- &\"a\" ;", "Test", "b");
            assertTrue(result.root() instanceof SyntaxError);
        }

        @Test
        void positiveLookaheadInSequence() {
            var result = SquirrelParser.squirrelParsePT("Test <- \"a\" &\"b\" ;", "Test", "abc");
            assertFalse(result.root().isMismatch());
            assertEquals(1, result.root().len()); // Only 'a' consumed
        }

        @Test
        void positiveLookaheadInSequenceFailsWhenNotFollowed() {
            var result = SquirrelParser.squirrelParsePT("Test <- \"a\" &\"b\" ;", "Test", "ac");
            assertTrue(result.root() instanceof SyntaxError); // Fails because no 'b' after 'a'
        }

        @Test
        void positiveLookaheadWithContinuation() {
            var result = SquirrelParser.squirrelParsePT("Test <- \"a\" &\"b\" \"b\" ;", "Test", "abc");
            assertFalse(result.root().isMismatch());
            assertEquals(2, result.root().len()); // 'a' and 'b' consumed
        }

        @Test
        void positiveLookaheadAtEndOfInput() {
            var result = SquirrelParser.squirrelParsePT("Test <- \"a\" &\"b\" ;", "Test", "a");
            // With error recovery, this succeeds but has syntax errors
            assertTrue(result.hasSyntaxErrors()); // No 'b' to look ahead to
        }

        @Test
        void nestedPositiveLookaheads() {
            var result = SquirrelParser.squirrelParsePT("Test <- &&\"a\" \"a\" ;", "Test", "a");
            assertFalse(result.root().isMismatch());
            assertEquals(1, result.root().len());
        }
    }

    @Nested
    class NotFollowedByTests {

        @Test
        void negativeLookaheadSucceedsWhenPatternDoesNotMatch() {
            var result = SquirrelParser.squirrelParsePT("Test <- !\"a\" ;", "Test", "b");
            assertFalse(result.root().isMismatch());
            assertEquals(0, result.root().len()); // Lookahead doesn't consume
        }

        @Test
        void negativeLookaheadFailsWhenPatternMatches() {
            var result = SquirrelParser.squirrelParsePT("Test <- !\"a\" ;", "Test", "a");
            assertTrue(result.root() instanceof SyntaxError);
        }

        @Test
        void negativeLookaheadInSequence() {
            var result = SquirrelParser.squirrelParsePT("Test <- \"a\" !\"b\" ;", "Test", "ac");
            assertFalse(result.root().isMismatch());
            assertEquals(1, result.root().len()); // Only 'a' consumed
        }

        @Test
        void negativeLookaheadInSequenceFailsWhenFollowed() {
            var result = SquirrelParser.squirrelParsePT("Test <- \"a\" !\"b\" ;", "Test", "ab");
            assertTrue(result.root() instanceof SyntaxError); // Fails because 'a' IS followed by 'b'
        }

        @Test
        void negativeLookaheadWithContinuation() {
            var result = SquirrelParser.squirrelParsePT("Test <- \"a\" !\"b\" \"c\" ;", "Test", "ac");
            assertFalse(result.root().isMismatch());
            assertEquals(2, result.root().len()); // 'a' and 'c' consumed
        }

        @Test
        void negativeLookaheadAtEndOfInput() {
            var result = SquirrelParser.squirrelParsePT("Test <- \"a\" !\"b\" ;", "Test", "a");
            assertFalse(result.root().isMismatch()); // No 'b' following, so succeeds
            assertEquals(1, result.root().len());
        }

        @Test
        void nestedNegativeLookaheads() {
            // !!"a" is the same as &"a"
            var result = SquirrelParser.squirrelParsePT("Test <- !!\"a\" \"a\" ;", "Test", "a");
            assertFalse(result.root().isMismatch());
            assertEquals(1, result.root().len());
        }
    }

    @Nested
    class MixedLookaheadsTests {

        @Test
        void positiveThenNegativeLookahead() {
            String grammar = "Test <- &[a-z] !\"x\" [a-z] ;";

            // Should match any lowercase letter except 'x'
            var result = SquirrelParser.squirrelParsePT(grammar, "Test", "a");
            assertFalse(result.root().isMismatch());

            result = SquirrelParser.squirrelParsePT(grammar, "Test", "x");
            assertTrue(result.root() instanceof SyntaxError);

            result = SquirrelParser.squirrelParsePT(grammar, "Test", "A");
            assertTrue(result.root() instanceof SyntaxError);
        }

        @Test
        void lookaheadInChoice() {
            String grammar = "Test <- &\"a\" \"a\" / &\"b\" \"b\" ;";

            var result = SquirrelParser.squirrelParsePT(grammar, "Test", "a");
            assertFalse(result.root().isMismatch());
            assertEquals(1, result.root().len());

            result = SquirrelParser.squirrelParsePT(grammar, "Test", "b");
            assertFalse(result.root().isMismatch());
            assertEquals(1, result.root().len());

            result = SquirrelParser.squirrelParsePT(grammar, "Test", "c");
            assertTrue(result.root() instanceof SyntaxError);
        }

        @Test
        void lookaheadWithRepetition() {
            String grammar = "Test <- (!\".\" [a-z])* ;";

            // Match lowercase letters until '.', then parser has unmatched input
            var result = SquirrelParser.squirrelParsePT(grammar, "Test", "abc.def");
            assertFalse(result.root().isMismatch());
            // The grammar itself only matches 'abc', but error recovery captures trailing '.def'
            assertTrue(result.hasSyntaxErrors());

            result = SquirrelParser.squirrelParsePT(grammar, "Test", ".abc");
            assertFalse(result.root().isMismatch());
            // With error recovery, unmatched '.abc' is captured as syntax error
            assertTrue(result.hasSyntaxErrors());
        }
    }

    @Nested
    class LookaheadWithReferencesTests {

        @Test
        void positiveLookaheadWithRuleReference() {
            var result = SquirrelParser.squirrelParsePT("""
                Test <- &Digit Digit ;
                Digit <- [0-9] ;
            """, "Test", "5");
            assertFalse(result.root().isMismatch());
            assertEquals(1, result.root().len());
        }

        @Test
        void negativeLookaheadWithRuleReference() {
            String grammar = """
                Test <- !Digit [a-z] ;
                Digit <- [0-9] ;
            """;

            var result = SquirrelParser.squirrelParsePT(grammar, "Test", "a");
            assertFalse(result.root().isMismatch());

            result = SquirrelParser.squirrelParsePT(grammar, "Test", "5");
            assertTrue(result.root() instanceof SyntaxError);
        }
    }

    @Nested
    class IntegrationTests {

        @Test
        void lookaheadWithFullInputConsumption() {
            var result = SquirrelParser.squirrelParsePT("Test <- \"a\" &\"b\" \"b\" ;", "Test", "ab");
            assertNotNull(result.root());
            assertEquals(2, result.root().len()); // Both 'a' and 'b' consumed
        }

        @Test
        void negativeLookaheadWithFullInputConsumption() {
            var result = SquirrelParser.squirrelParsePT("Test <- \"a\" !\"b\" \"c\" ;", "Test", "ac");
            assertNotNull(result.root());
            assertEquals(2, result.root().len()); // 'a' and 'c' consumed
        }

        @Test
        void identifierParserWithLookaheadValid() {
            // Parse identifiers that don't start with a digit
            var result = SquirrelParser.squirrelParsePT("""
                Identifier <- ![0-9] [a-zA-Z0-9_]+ ;
            """, "Identifier", "abc123");
            assertNotNull(result.root());
            assertEquals(6, result.root().len());
        }

        @Test
        void identifierParserWithLookaheadInvalidStartsWithDigit() {
            // Parse identifiers that don't start with a digit
            var result = SquirrelParser.squirrelParsePT("""
                Identifier <- ![0-9] [a-zA-Z0-9_]+ ;
            """, "Identifier", "123abc");
            // With error recovery, this may recover by skipping digits, so check for errors
            assertTrue(result.hasSyntaxErrors()); // Starts with digit, should have errors
        }

        @Test
        void keywordVsIdentifierWithLookahead() {
            // Parse 'if' only when not followed by alphanumeric (i.e., as keyword)
            String grammar = """
                Keyword <- "if" ![a-zA-Z0-9_] ;
            """;

            // Valid keyword (all input consumed)
            var result = SquirrelParser.squirrelParsePT(grammar, "Keyword", "if");
            assertNotNull(result.root()); // 'if' as keyword
            assertEquals(2, result.root().len());

            // Invalid - 'ifx' is not just 'if'
            result = SquirrelParser.squirrelParsePT(grammar, "Keyword", "ifx");
            // Total failure: result is SyntaxError spanning entire input
            assertTrue(result.root() instanceof SyntaxError);
        }

        @Test
        void commentParserWithLookahead() {
            // Parse // style comments until end of line
            var result = SquirrelParser.squirrelParsePT("""
                Comment <- "//" (!'\\n' .)* '\\n' ;
            """, "Comment", "//hello world\n");
            assertNotNull(result.root());
            assertEquals(14, result.root().len()); // All input consumed
        }

        @Test
        void stringLiteralParserWithLookahead() {
            // Parse string literals with escape sequences
            String grammar = """
                String <- '"' ("\\\\" . / !'"' .)* '"' ;
            """;

            var result = SquirrelParser.squirrelParsePT(grammar, "String", "\"hello\"");
            assertNotNull(result.root());

            result = SquirrelParser.squirrelParsePT(grammar, "String", "\"hello\\\"world\"");
            assertNotNull(result.root());
        }
    }
}
