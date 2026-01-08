"""MetaGrammar - Character Classes Tests"""
from squirrelparser import Parser
from squirrelparser.meta_grammar import MetaGrammar


class TestMetaGrammarCharacterClasses:
    """MetaGrammar - Character Classes"""

    def test_simple_character_range(self) -> None:
        """simple character range"""
        from squirrelparser import SyntaxError as SyntaxErrorNode
        grammar = '''
            Digit <- [0-9];
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(rules=rules, input_str='5')
        result, _ = parser.parse('Digit')
        assert result is not None
        assert result.len == 1

        parser = Parser(rules=rules, input_str='a')
        result, _ = parser.parse('Digit')
        # With spanning invariant, total failure returns SyntaxError
        assert isinstance(result, SyntaxErrorNode), 'non-matching character should return SyntaxError'

    def test_multiple_character_ranges(self) -> None:
        """multiple character ranges"""
        from squirrelparser import SyntaxError as SyntaxErrorNode
        grammar = '''
            AlphaNum <- [a-zA-Z0-9];
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(rules=rules, input_str='a')
        result, _ = parser.parse('AlphaNum')
        assert result is not None

        parser = Parser(rules=rules, input_str='Z')
        result, _ = parser.parse('AlphaNum')
        assert result is not None

        parser = Parser(rules=rules, input_str='5')
        result, _ = parser.parse('AlphaNum')
        assert result is not None

        parser = Parser(rules=rules, input_str='!')
        result, _ = parser.parse('AlphaNum')
        # With spanning invariant, total failure returns SyntaxError
        assert isinstance(result, SyntaxErrorNode), 'non-matching character should return SyntaxError'

    def test_character_class_with_individual_characters(self) -> None:
        """character class with individual characters"""
        from squirrelparser import SyntaxError as SyntaxErrorNode
        grammar = '''
            Vowel <- [aeiou];
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(rules=rules, input_str='a')
        result, _ = parser.parse('Vowel')
        assert result is not None

        parser = Parser(rules=rules, input_str='e')
        result, _ = parser.parse('Vowel')
        assert result is not None

        parser = Parser(rules=rules, input_str='b')
        result, _ = parser.parse('Vowel')
        # With spanning invariant, total failure returns SyntaxError
        assert isinstance(result, SyntaxErrorNode), 'non-matching vowel should return SyntaxError'

    def test_negated_character_class(self) -> None:
        """negated character class"""
        from squirrelparser import SyntaxError as SyntaxErrorNode
        grammar = '''
            NotDigit <- [^0-9];
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(rules=rules, input_str='a')
        result, _ = parser.parse('NotDigit')
        assert result is not None

        parser = Parser(rules=rules, input_str='5')
        result, _ = parser.parse('NotDigit')
        # With spanning invariant, total failure returns SyntaxError
        assert isinstance(result, SyntaxErrorNode), 'digit should not match [^0-9]'

    def test_escaped_characters_in_character_class(self) -> None:
        """escaped characters in character class"""
        from squirrelparser import SyntaxError as SyntaxErrorNode
        grammar = r'''
            Special <- [\t\n];
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(rules=rules, input_str='\t')
        result, _ = parser.parse('Special')
        assert result is not None

        parser = Parser(rules=rules, input_str='\n')
        result, _ = parser.parse('Special')
        assert result is not None

        parser = Parser(rules=rules, input_str=' ')
        result, _ = parser.parse('Special')
        # With spanning invariant, total failure returns SyntaxError
        assert isinstance(result, SyntaxErrorNode), 'space should not match [\\t\\n]'
