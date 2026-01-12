"""Tests for MetaGrammar basic syntax."""

from squirrelparser import MetaGrammar, Parser, SyntaxError


class TestBasicSyntax:
    """MetaGrammar - Basic Syntax tests."""

    def test_simple_rule_with_string_literal(self):
        grammar = '''
            Hello <- "hello";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        assert 'Hello' in rules

        parser = Parser(top_rule_name='Hello', rules=rules, input='hello')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 5

    def test_rule_with_character_literal(self):
        grammar = '''
            A <- 'a';
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(top_rule_name='A', rules=rules, input='a')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 1

    def test_sequence_of_literals(self):
        grammar = '''
            AB <- "a" "b";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(top_rule_name='AB', rules=rules, input='ab')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 2

    def test_choice_between_alternatives(self):
        grammar = '''
            AorB <- "a" / "b";
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(top_rule_name='AorB', rules=rules, input='a')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 1

        parser = Parser(top_rule_name='AorB', rules=rules, input='b')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 1

    def test_zero_or_more_repetition(self):
        grammar = '''
            As <- "a"*;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(top_rule_name='As', rules=rules, input='')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 0

        parser = Parser(top_rule_name='As', rules=rules, input='aaa')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 3

    def test_one_or_more_repetition(self):
        grammar = '''
            As <- "a"+;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(top_rule_name='As', rules=rules, input='')
        parse_result = parser.parse()
        result = parse_result.root
        assert isinstance(result, SyntaxError)

        parser = Parser(top_rule_name='As', rules=rules, input='aaa')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 3

    def test_optional(self):
        grammar = '''
            OptA <- "a"?;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(top_rule_name='OptA', rules=rules, input='')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 0

        parser = Parser(top_rule_name='OptA', rules=rules, input='a')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 1

    def test_positive_lookahead(self):
        grammar = '''
            AFollowedByB <- "a" &"b" "b";
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(top_rule_name='AFollowedByB', rules=rules, input='ab')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 2  # Both 'a' and 'b' consumed

        parser = Parser(top_rule_name='AFollowedByB', rules=rules, input='ac')
        parse_result = parser.parse()
        result = parse_result.root
        assert isinstance(result, SyntaxError)

    def test_negative_lookahead(self):
        grammar = '''
            ANotFollowedByB <- "a" !"b" "c";
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(top_rule_name='ANotFollowedByB', rules=rules, input='ac')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 2  # Both 'a' and 'c' consumed

        parser = Parser(top_rule_name='ANotFollowedByB', rules=rules, input='ab')
        parse_result = parser.parse()
        result = parse_result.root
        assert isinstance(result, SyntaxError)

    def test_any_character(self):
        grammar = '''
            AnyOne <- .;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(top_rule_name='AnyOne', rules=rules, input='x')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 1

        parser = Parser(top_rule_name='AnyOne', rules=rules, input='9')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 1

    def test_grouping_with_parentheses(self):
        grammar = '''
            Group <- ("a" / "b") "c";
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(top_rule_name='Group', rules=rules, input='ac')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 2

        parser = Parser(top_rule_name='Group', rules=rules, input='bc')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 2
