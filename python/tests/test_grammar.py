"""Grammar parsing tests."""


from squirrelparser import MetaGrammar


class TestGrammar:
    """Grammar parsing tests."""

    def test_parses_simple_grammar(self):
        simple_grammar = """
            Test <- "hello";
        """

        # Should not raise any exceptions
        MetaGrammar.parse_grammar(simple_grammar)

    def test_parses_multiline_grammar(self):
        multiline_grammar = """
            JSON <- Value;
            Value <- "test";
        """

        # Should not raise any exceptions
        MetaGrammar.parse_grammar(multiline_grammar)
