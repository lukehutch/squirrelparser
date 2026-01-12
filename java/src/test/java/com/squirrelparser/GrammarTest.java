package com.squirrelparser;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Grammar parsing tests.
 */
class GrammarTest {

    @Test
    void parsesSimpleGrammar() {
        String simpleGrammar = """
            Test <- "hello";
            """;

        assertDoesNotThrow(() -> MetaGrammar.parseGrammar(simpleGrammar));
    }

    @Test
    void parsesMultilineGrammar() {
        String multilineGrammar = """
            JSON <- Value;
            Value <- "test";
            """;

        assertDoesNotThrow(() -> MetaGrammar.parseGrammar(multilineGrammar));
    }
}
