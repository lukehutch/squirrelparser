package com.squirrelparser.metagrammar;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;

import java.util.Map;

import org.junit.jupiter.api.Test;

import com.squirrelparser.Clause;
import com.squirrelparser.MatchResult;
import com.squirrelparser.MetaGrammar;
import com.squirrelparser.Parser;

/**
 * MetaGrammar - Escape Sequences Tests
 * Port of escape_sequences_test.dart
 */
class EscapeSequencesTest {

    @Test
    void testNewlineEscape() {
        String grammar = """
            Newline <- "\\n";
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "\n");
        MatchResult result = parser.parse("Newline");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(1, result.len());
    }

    @Test
    void testTabEscape() {
        String grammar = """
            Tab <- "\\t";
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "\t");
        MatchResult result = parser.parse("Tab");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(1, result.len());
    }

    @Test
    void testBackslashEscape() {
        String grammar = """
            Backslash <- "\\\\";
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "\\");
        MatchResult result = parser.parse("Backslash");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(1, result.len());
    }

    @Test
    void testQuoteEscapes() {
        String grammar = """
            DoubleQuote <- "\\"";
            SingleQuote <- '\\'';
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "\"");
        MatchResult result = parser.parse("DoubleQuote");
        assertNotNull(result);
        assertFalse(result.isMismatch());

        parser = new Parser(rules, "'");
        result = parser.parse("SingleQuote");
        assertNotNull(result);
        assertFalse(result.isMismatch());
    }

    @Test
    void testEscapedSequenceInString() {
        String grammar = """
            Message <- "Hello\\nWorld";
            """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "Hello\nWorld");
        MatchResult result = parser.parse("Message");
        assertNotNull(result);
        assertFalse(result.isMismatch());
        assertEquals(11, result.len());
    }
}
