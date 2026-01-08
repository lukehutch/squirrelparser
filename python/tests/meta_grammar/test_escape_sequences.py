"""MetaGrammar - Escape Sequences Tests"""
from squirrelparser import Parser
from squirrelparser.meta_grammar import MetaGrammar


class TestMetaGrammarEscapeSequences:
    """MetaGrammar - Escape Sequences"""

    def test_newline_escape(self) -> None:
        """newline escape"""
        grammar = r'''
            Newline <- "\n";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(rules=rules, input_str='\n')
        result, _ = parser.parse('Newline')
        assert result is not None
        assert result.len == 1

    def test_tab_escape(self) -> None:
        """tab escape"""
        grammar = r'''
            Tab <- "\t";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(rules=rules, input_str='\t')
        result, _ = parser.parse('Tab')
        assert result is not None
        assert result.len == 1

    def test_backslash_escape(self) -> None:
        """backslash escape"""
        grammar = r'''
            Backslash <- "\\";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(rules=rules, input_str='\\')
        result, _ = parser.parse('Backslash')
        assert result is not None
        assert result.len == 1

    def test_quote_escapes(self) -> None:
        """quote escapes"""
        grammar = r'''
            DoubleQuote <- "\"";
            SingleQuote <- '\'';
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(rules=rules, input_str='"')
        result, _ = parser.parse('DoubleQuote')
        assert result is not None

        parser = Parser(rules=rules, input_str="'")
        result, _ = parser.parse('SingleQuote')
        assert result is not None

    def test_escaped_sequence_in_string(self) -> None:
        """escaped sequence in string"""
        grammar = r'''
            Message <- "Hello\nWorld";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(rules=rules, input_str='Hello\nWorld')
        result, _ = parser.parse('Message')
        assert result is not None
        assert result.len == 11
