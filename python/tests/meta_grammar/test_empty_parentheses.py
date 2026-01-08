"""MetaGrammar - Empty Parentheses (Nothing) Tests"""
from squirrelparser import Parser
from squirrelparser.meta_grammar import MetaGrammar


class TestMetaGrammarEmptyParentheses:
    """MetaGrammar - Empty Parentheses (Nothing)"""

    def test_empty_parentheses_matches_empty_string(self) -> None:
        """empty parentheses matches empty string"""
        grammar = '''
            Empty <- ();
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        assert 'Empty' in rules

        parser = Parser(rules=rules, input_str='')
        result, _ = parser.parse('Empty')
        assert result is not None
        assert result.len == 0

    def test_empty_parentheses_in_sequence(self) -> None:
        """empty parentheses in sequence"""
        grammar = '''
            AB <- "a" () "b";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(rules=rules, input_str='ab')
        result, _ = parser.parse('AB')
        assert result is not None
        assert result.len == 2

    def test_parenthesized_expression_with_content(self) -> None:
        """parenthesized expression with content"""
        grammar = '''
            Parens <- ("hello");
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(rules=rules, input_str='hello')
        result, _ = parser.parse('Parens')
        assert result is not None
        assert result.len == 5

    def test_nested_empty_parentheses(self) -> None:
        """nested empty parentheses"""
        grammar = '''
            Nested <- (());
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(rules=rules, input_str='')
        result, _ = parser.parse('Nested')
        assert result is not None
        assert result.len == 0

    def test_empty_parentheses_with_optional_repetition(self) -> None:
        """empty parentheses with optional repetition"""
        grammar = '''
            Opt <- ()* "test";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(rules=rules, input_str='test')
        result, _ = parser.parse('Opt')
        assert result is not None
        assert result.len == 4

    def test_empty_parentheses_in_choice(self) -> None:
        """empty parentheses in choice"""
        grammar = '''
            Choice <- "a" / ();
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        # Should match 'a'
        parser1 = Parser(rules=rules, input_str='a')
        result1, _ = parser1.parse('Choice')
        assert result1 is not None
        assert result1.len == 1

        # Should match empty string
        parser2 = Parser(rules=rules, input_str='')
        result2, _ = parser2.parse('Choice')
        assert result2 is not None
        assert result2.len == 0

    def test_rule_referencing_nothing(self) -> None:
        """rule referencing nothing"""
        grammar = '''
            Nothing <- ();
            A <- Nothing "a";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(rules=rules, input_str='a')
        result, _ = parser.parse('A')
        assert result is not None
        assert result.len == 1
