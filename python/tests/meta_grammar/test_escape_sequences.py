"""Tests for MetaGrammar escape sequences."""

from squirrelparser import MetaGrammar, Parser


class TestEscapeSequences:
    """MetaGrammar - Escape Sequences tests."""

    def test_newline_escape(self):
        grammar = r'''
            Newline <- "\n";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(top_rule_name='Newline', rules=rules, input='\n')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 1

    def test_tab_escape(self):
        grammar = r'''
            Tab <- "\t";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(top_rule_name='Tab', rules=rules, input='\t')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 1

    def test_backslash_escape(self):
        grammar = r'''
            Backslash <- "\\";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(top_rule_name='Backslash', rules=rules, input='\\')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 1

    def test_quote_escapes(self):
        grammar = r'''
            DoubleQuote <- "\"";
            SingleQuote <- '\'';
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(top_rule_name='DoubleQuote', rules=rules, input='"')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        parser = Parser(top_rule_name='SingleQuote', rules=rules, input="'")
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

    def test_escaped_sequence_in_string(self):
        grammar = r'''
            Message <- "Hello\nWorld";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(top_rule_name='Message', rules=rules, input='Hello\nWorld')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 11
