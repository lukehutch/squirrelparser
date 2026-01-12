"""Tests for MetaGrammar character classes."""

from squirrelparser import MetaGrammar, Parser, CharSet, SyntaxError


class TestCharSetTerminalDirectConstruction:
    """CharSet Terminal - Direct Construction tests."""

    def test_charset_range_matches_characters_in_range(self):
        char_set = CharSet.range('a', 'z')
        rules = {'S': char_set}

        parser = Parser(top_rule_name='S', rules=rules, input='a')
        assert not isinstance(parser.parse().root, SyntaxError), 'should match a'

        parser = Parser(top_rule_name='S', rules=rules, input='m')
        assert not isinstance(parser.parse().root, SyntaxError), 'should match m'

        parser = Parser(top_rule_name='S', rules=rules, input='z')
        assert not isinstance(parser.parse().root, SyntaxError), 'should match z'

        parser = Parser(top_rule_name='S', rules=rules, input='A')
        assert isinstance(parser.parse().root, SyntaxError), 'should not match A'

    def test_charset_char_matches_single_character(self):
        char_set = CharSet.char('x')
        rules = {'S': char_set}

        parser = Parser(top_rule_name='S', rules=rules, input='x')
        assert not isinstance(parser.parse().root, SyntaxError), 'should match x'

        parser = Parser(top_rule_name='S', rules=rules, input='y')
        assert isinstance(parser.parse().root, SyntaxError), 'should not match y'

    def test_charset_with_multiple_ranges(self):
        # [a-zA-Z0-9]
        char_set = CharSet([
            (ord('a'), ord('z')),
            (ord('A'), ord('Z')),
            (ord('0'), ord('9')),
        ])
        rules = {'S': char_set}

        # Test lowercase
        parser = Parser(top_rule_name='S', rules=rules, input='a')
        assert not isinstance(parser.parse().root, SyntaxError)
        parser = Parser(top_rule_name='S', rules=rules, input='z')
        assert not isinstance(parser.parse().root, SyntaxError)

        # Test uppercase
        parser = Parser(top_rule_name='S', rules=rules, input='A')
        assert not isinstance(parser.parse().root, SyntaxError)
        parser = Parser(top_rule_name='S', rules=rules, input='Z')
        assert not isinstance(parser.parse().root, SyntaxError)

        # Test digits
        parser = Parser(top_rule_name='S', rules=rules, input='0')
        assert not isinstance(parser.parse().root, SyntaxError)
        parser = Parser(top_rule_name='S', rules=rules, input='9')
        assert not isinstance(parser.parse().root, SyntaxError)

        # Test non-alphanumeric
        parser = Parser(top_rule_name='S', rules=rules, input='!')
        assert isinstance(parser.parse().root, SyntaxError)
        parser = Parser(top_rule_name='S', rules=rules, input=' ')
        assert isinstance(parser.parse().root, SyntaxError)

    def test_charset_with_inversion(self):
        # [^a-z] - matches anything NOT a lowercase letter
        char_set = CharSet([
            (ord('a'), ord('z')),
        ], inverted=True)
        rules = {'S': char_set}

        # Should NOT match lowercase
        parser = Parser(top_rule_name='S', rules=rules, input='a')
        assert isinstance(parser.parse().root, SyntaxError), 'should not match a'
        parser = Parser(top_rule_name='S', rules=rules, input='m')
        assert isinstance(parser.parse().root, SyntaxError), 'should not match m'
        parser = Parser(top_rule_name='S', rules=rules, input='z')
        assert isinstance(parser.parse().root, SyntaxError), 'should not match z'

        # Should match uppercase, digits, symbols
        parser = Parser(top_rule_name='S', rules=rules, input='A')
        assert not isinstance(parser.parse().root, SyntaxError), 'should match A'
        parser = Parser(top_rule_name='S', rules=rules, input='5')
        assert not isinstance(parser.parse().root, SyntaxError), 'should match 5'
        parser = Parser(top_rule_name='S', rules=rules, input='!')
        assert not isinstance(parser.parse().root, SyntaxError), 'should match !'

    def test_charset_with_inverted_multiple_ranges(self):
        # [^a-zA-Z] - matches anything NOT a letter
        char_set = CharSet([
            (ord('a'), ord('z')),
            (ord('A'), ord('Z')),
        ], inverted=True)
        rules = {'S': char_set}

        # Should NOT match letters
        parser = Parser(top_rule_name='S', rules=rules, input='a')
        assert isinstance(parser.parse().root, SyntaxError), 'should not match a'
        parser = Parser(top_rule_name='S', rules=rules, input='Z')
        assert isinstance(parser.parse().root, SyntaxError), 'should not match Z'

        # Should match digits and symbols
        parser = Parser(top_rule_name='S', rules=rules, input='5')
        assert not isinstance(parser.parse().root, SyntaxError), 'should match 5'
        parser = Parser(top_rule_name='S', rules=rules, input='!')
        assert not isinstance(parser.parse().root, SyntaxError), 'should match !'

    def test_charset_not_range_convenience_constructor(self):
        char_set = CharSet.not_range('0', '9')
        rules = {'S': char_set}

        # Should NOT match digits
        parser = Parser(top_rule_name='S', rules=rules, input='5')
        assert isinstance(parser.parse().root, SyntaxError), 'should not match 5'

        # Should match non-digits
        parser = Parser(top_rule_name='S', rules=rules, input='a')
        assert not isinstance(parser.parse().root, SyntaxError), 'should match a'

    def test_charset_to_string_formats_correctly(self):
        assert repr(CharSet.range('a', 'z')) == '[a-z]'
        assert repr(CharSet.char('x')) == '[x]'
        assert repr(CharSet([
            (ord('a'), ord('z')),
            (ord('0'), ord('9')),
        ])) == '[a-z0-9]'
        assert repr(CharSet([
            (ord('a'), ord('z')),
        ], inverted=True)) == '[^a-z]'

    def test_charset_handles_empty_input(self):
        char_set = CharSet.range('a', 'z')
        rules = {'S': char_set}

        parser = Parser(top_rule_name='S', rules=rules, input='')
        assert isinstance(parser.parse().root, SyntaxError), 'should not match empty'


class TestMetaGrammarCharacterClasses:
    """MetaGrammar - Character Classes tests."""

    def test_simple_character_range(self):
        grammar = '''
            Digit <- [0-9];
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(top_rule_name='Digit', rules=rules, input='5')
        parse_result = parser.parse()
        result = parse_result.root
        assert not isinstance(result, SyntaxError), 'should match digit'
        assert result.len == 1

        parser = Parser(top_rule_name='Digit', rules=rules, input='a')
        parse_result = parser.parse()
        result = parse_result.root
        assert isinstance(result, SyntaxError), 'should fail on non-digit'

    def test_multiple_character_ranges(self):
        grammar = '''
            AlphaNum <- [a-zA-Z0-9];
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(top_rule_name='AlphaNum', rules=rules, input='a')
        parse_result = parser.parse()
        result = parse_result.root
        assert not isinstance(result, SyntaxError)

        parser = Parser(top_rule_name='AlphaNum', rules=rules, input='Z')
        parse_result = parser.parse()
        result = parse_result.root
        assert not isinstance(result, SyntaxError)

        parser = Parser(top_rule_name='AlphaNum', rules=rules, input='5')
        parse_result = parser.parse()
        result = parse_result.root
        assert not isinstance(result, SyntaxError)

        parser = Parser(top_rule_name='AlphaNum', rules=rules, input='!')
        parse_result = parser.parse()
        result = parse_result.root
        assert isinstance(result, SyntaxError), 'should fail on non-alphanumeric'

    def test_character_class_with_individual_characters(self):
        grammar = '''
            Vowel <- [aeiou];
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(top_rule_name='Vowel', rules=rules, input='a')
        parse_result = parser.parse()
        result = parse_result.root
        assert not isinstance(result, SyntaxError)

        parser = Parser(top_rule_name='Vowel', rules=rules, input='e')
        parse_result = parser.parse()
        result = parse_result.root
        assert not isinstance(result, SyntaxError)

        parser = Parser(top_rule_name='Vowel', rules=rules, input='b')
        parse_result = parser.parse()
        result = parse_result.root
        assert isinstance(result, SyntaxError), 'should fail on consonant'

    def test_negated_character_class(self):
        grammar = '''
            NotDigit <- [^0-9];
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(top_rule_name='NotDigit', rules=rules, input='a')
        parse_result = parser.parse()
        result = parse_result.root
        assert not isinstance(result, SyntaxError)

        parser = Parser(top_rule_name='NotDigit', rules=rules, input='5')
        parse_result = parser.parse()
        result = parse_result.root
        assert isinstance(result, SyntaxError), 'should fail on digit'

    def test_escaped_characters_in_character_class(self):
        grammar = r'''
            Special <- [\t\n];
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(top_rule_name='Special', rules=rules, input='\t')
        parse_result = parser.parse()
        result = parse_result.root
        assert not isinstance(result, SyntaxError)

        parser = Parser(top_rule_name='Special', rules=rules, input='\n')
        parse_result = parser.parse()
        result = parse_result.root
        assert not isinstance(result, SyntaxError)

        parser = Parser(top_rule_name='Special', rules=rules, input=' ')
        parse_result = parser.parse()
        result = parse_result.root
        assert isinstance(result, SyntaxError), 'should fail on space'
