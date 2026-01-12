package com.squirrelparser;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;

import org.junit.jupiter.api.Test;

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
