"""Tests for MetaGrammar empty parentheses (Nothing)."""

from squirrelparser import MetaGrammar, Parser


class TestEmptyParentheses:
    """MetaGrammar - Empty Parentheses (Nothing) tests."""

    def test_empty_parentheses_matches_empty_string(self):
        grammar = '''
            Empty <- ();
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        assert 'Empty' in rules

        parser = Parser(top_rule_name='Empty', rules=rules, input='')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 0

    def test_empty_parentheses_in_sequence(self):
        grammar = '''
            AB <- "a" () "b";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(top_rule_name='AB', rules=rules, input='ab')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 2

    def test_parenthesized_expression_with_content(self):
        grammar = '''
            Parens <- ("hello");
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(top_rule_name='Parens', rules=rules, input='hello')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 5

    def test_nested_empty_parentheses(self):
        grammar = '''
            Nested <- (());
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(top_rule_name='Nested', rules=rules, input='')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 0

    def test_empty_parentheses_with_optional_repetition(self):
        grammar = '''
            Opt <- ()* "test";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(top_rule_name='Opt', rules=rules, input='test')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 4

    def test_empty_parentheses_in_choice(self):
        grammar = '''
            Choice <- "a" / ();
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        # Should match 'a'
        parser1 = Parser(top_rule_name='Choice', rules=rules, input='a')
        parse_result1 = parser1.parse()
        result1 = parse_result1.root
        assert result1 is not None
        assert result1.len == 1

        # Should match empty string
        parser2 = Parser(top_rule_name='Choice', rules=rules, input='')
        parse_result2 = parser2.parse()
        result2 = parse_result2.root
        assert result2 is not None
        assert result2.len == 0

    def test_rule_referencing_nothing(self):
        grammar = '''
            Nothing <- ();
            A <- Nothing "a";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(top_rule_name='A', rules=rules, input='a')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 1
