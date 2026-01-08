"""MetaGrammar - Basic Syntax Tests"""
from squirrelparser import Parser
from squirrelparser.meta_grammar import MetaGrammar


class TestMetaGrammarBasicSyntax:
    """MetaGrammar - Basic Syntax"""

    def test_simple_rule_with_string_literal(self) -> None:
        """simple rule with string literal"""
        grammar = '''
            Hello <- "hello";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        assert 'Hello' in rules

        parser = Parser(rules=rules, input_str='hello')
        result, _ = parser.parse('Hello')
        assert result is not None
        assert result.len == 5

    def test_rule_with_character_literal(self) -> None:
        """rule with character literal"""
        grammar = '''
            A <- 'a';
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(rules=rules, input_str='a')
        result, _ = parser.parse('A')
        assert result is not None
        assert result.len == 1

    def test_sequence_of_literals(self) -> None:
        """sequence of literals"""
        grammar = '''
            AB <- "a" "b";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(rules=rules, input_str='ab')
        result, _ = parser.parse('AB')
        assert result is not None
        assert result.len == 2

    def test_choice_between_alternatives(self) -> None:
        """choice between alternatives"""
        grammar = '''
            AorB <- "a" / "b";
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(rules=rules, input_str='a')
        result, _ = parser.parse('AorB')
        assert result is not None
        assert result.len == 1

        parser = Parser(rules=rules, input_str='b')
        result, _ = parser.parse('AorB')
        assert result is not None
        assert result.len == 1

    def test_zero_or_more_repetition(self) -> None:
        """zero or more repetition"""
        grammar = '''
            As <- "a"*;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(rules=rules, input_str='')
        result, _ = parser.parse('As')
        assert result is not None
        assert result.len == 0

        parser = Parser(rules=rules, input_str='aaa')
        result, _ = parser.parse('As')
        assert result is not None
        assert result.len == 3

    def test_one_or_more_repetition(self) -> None:
        """one or more repetition"""
        from squirrelparser import SyntaxError as SyntaxErrorNode
        grammar = '''
            As <- "a"+;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(rules=rules, input_str='')
        result, _ = parser.parse('As')
        # With spanning invariant, total failure returns SyntaxError
        assert isinstance(result, SyntaxErrorNode), 'OneOrMore on empty input should return SyntaxError'

        parser = Parser(rules=rules, input_str='aaa')
        result, _ = parser.parse('As')
        assert result is not None
        assert result.len == 3

    def test_optional(self) -> None:
        """optional"""
        grammar = '''
            OptA <- "a"?;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(rules=rules, input_str='')
        result, _ = parser.parse('OptA')
        assert result is not None
        assert result.len == 0

        parser = Parser(rules=rules, input_str='a')
        result, _ = parser.parse('OptA')
        assert result is not None
        assert result.len == 1

    def test_positive_lookahead(self) -> None:
        """positive lookahead"""
        from squirrelparser import SyntaxError as SyntaxErrorNode
        grammar = '''
            AFollowedByB <- "a" &"b" "b";
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(rules=rules, input_str='ab')
        result, _ = parser.parse('AFollowedByB')
        assert result is not None
        assert result.len == 2  # Both 'a' and 'b' consumed

        parser = Parser(rules=rules, input_str='ac')
        result, _ = parser.parse('AFollowedByB')
        # With spanning invariant, total failure returns SyntaxError
        assert isinstance(result, SyntaxErrorNode), 'lookahead assertion failure should return SyntaxError'

    def test_negative_lookahead(self) -> None:
        """negative lookahead"""
        from squirrelparser import SyntaxError as SyntaxErrorNode
        grammar = '''
            ANotFollowedByB <- "a" !"b" "c";
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(rules=rules, input_str='ac')
        result, _ = parser.parse('ANotFollowedByB')
        assert result is not None
        assert result.len == 2  # Both 'a' and 'c' consumed

        parser = Parser(rules=rules, input_str='ab')
        result, _ = parser.parse('ANotFollowedByB')
        # With spanning invariant, total failure returns SyntaxError
        assert isinstance(result, SyntaxErrorNode), 'negative lookahead assertion failure should return SyntaxError'

    def test_any_character(self) -> None:
        """any character"""
        grammar = '''
            AnyOne <- .;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(rules=rules, input_str='x')
        result, _ = parser.parse('AnyOne')
        assert result is not None
        assert result.len == 1

        parser = Parser(rules=rules, input_str='9')
        result, _ = parser.parse('AnyOne')
        assert result is not None
        assert result.len == 1

    def test_grouping_with_parentheses(self) -> None:
        """grouping with parentheses"""
        grammar = '''
            Group <- ("a" / "b") "c";
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(rules=rules, input_str='ac')
        result, _ = parser.parse('Group')
        assert result is not None
        assert result.len == 2

        parser = Parser(rules=rules, input_str='bc')
        result, _ = parser.parse('Group')
        assert result is not None
        assert result.len == 2
