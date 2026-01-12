package com.squirrelparser;

import com.squirrelparser.*;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class EscapeSequencesTest {

    @Test
    void newlineEscape() {
        String grammar = """
            Newline <- "\\n";
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "Newline", "\n");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
        assertEquals(1, result.len());
    }

    @Test
    void tabEscape() {
        String grammar = """
            Tab <- "\\t";
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "Tab", "\t");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
        assertEquals(1, result.len());
    }

    @Test
    void backslashEscape() {
        String grammar = """
            Backslash <- "\\\\";
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "Backslash", "\\");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
        assertEquals(1, result.len());
    }

    @Test
    void quoteEscapes() {
        String grammar = """
            DoubleQuote <- "\\"";
            SingleQuote <- '\\'';
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);

        Parser parser = new Parser(rules, "DoubleQuote", "\"");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);

        parser = new Parser(rules, "SingleQuote", "'");
        parseResult = parser.parse();
        result = parseResult.root();
        assertNotNull(result);
    }

    @Test
    void escapedSequenceInString() {
        String grammar = """
            Message <- "Hello\\nWorld";
        """;

        Map<String, Clause> rules = MetaGrammar.parseGrammar(grammar);
        Parser parser = new Parser(rules, "Message", "Hello\nWorld");
        ParseResult parseResult = parser.parse();
        MatchResult result = parseResult.root();
        assertNotNull(result);
        assertEquals(11, result.len());
    }
}
