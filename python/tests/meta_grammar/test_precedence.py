"""Tests for MetaGrammar operator precedence."""

from squirrelparser import MetaGrammar, Parser, SyntaxError


class TestOperatorPrecedence:
    """MetaGrammar - Operator Precedence tests."""

    def test_suffix_binds_tighter_than_sequence(self):
        # "a"+ "b" should be ("a"+ "b"), not ("a" "b")+
        grammar = '''
            Rule <- "a"+ "b";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        clause = repr(rules['Rule'])

        # Should have OneOrMore around first element only
        assert '"a"+' in clause
        assert '"b"' in clause

    def test_prefix_binds_tighter_than_sequence(self):
        # !"a" "b" should be (!"a" "b"), not !("a" "b")
        grammar = '''
            Rule <- !"a" "b";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        clause = repr(rules['Rule'])

        # Should have NotFollowedBy around first element only
        assert '!"a"' in clause
        assert '"b"' in clause

    def test_sequence_binds_tighter_than_choice(self):
        # "a" "b" / "c" should be (("a" "b") / "c"), not ("a" ("b" / "c"))
        grammar = '''
            Rule <- "a" "b" / "c";
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        # Test that it parses "ab" and "c", but not "ac"
        parser = Parser(top_rule_name='Rule', rules=rules, input='ab')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        parser = Parser(top_rule_name='Rule', rules=rules, input='c')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        parser = Parser(top_rule_name='Rule', rules=rules, input='ac')
        parse_result = parser.parse()
        result = parse_result.root
        assert isinstance(result, SyntaxError)

    def test_suffix_binds_tighter_than_prefix(self):
        # &"a"+ should be &("a"+), not (&"a")+
        grammar = '''
            Rule <- &"a"+ "a";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        clause = repr(rules['Rule'])

        # Should have FollowedBy wrapping OneOrMore
        assert '&"a"+' in clause

    def test_grouping_overrides_precedence_sequence_in_choice(self):
        # "a" / "b" "c" should parse as ("a" / ("b" "c"))
        # ("a" / "b") "c" should parse differently
        grammar1 = '''
            Rule <- "a" / "b" "c";
        '''

        grammar2 = '''
            Rule <- ("a" / "b") "c";
        '''

        rules1 = MetaGrammar.parse_grammar(grammar1)
        rules2 = MetaGrammar.parse_grammar(grammar2)

        # Grammar 1: should match "a" or "bc"
        parser = Parser(top_rule_name='Rule', rules=rules1, input='a')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        parser = Parser(top_rule_name='Rule', rules=rules1, input='bc')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        # 'ac' should not fully match - only matches 'a', leaving 'c'
        parser = Parser(top_rule_name='Rule', rules=rules1, input='ac')
        match_result = parser.match_rule('Rule', 0)
        assert match_result.is_mismatch or match_result.len != 2  # Either mismatch or doesn't consume all

        # Grammar 2: should match "ac" or "bc"
        parser = Parser(top_rule_name='Rule', rules=rules2, input='ac')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        parser = Parser(top_rule_name='Rule', rules=rules2, input='bc')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        # 'a' should not match grammar2 - needs 'c' after choice
        parser = Parser(top_rule_name='Rule', rules=rules2, input='a')
        match_result = parser.match_rule('Rule', 0)
        assert match_result.is_mismatch

    def test_grouping_overrides_precedence_choice_in_suffix(self):
        # ("a" / "b")+ should allow "aaa", "bbb", "aba", etc.
        grammar = '''
            Rule <- ("a" / "b")+;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(top_rule_name='Rule', rules=rules, input='aaa')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        parser = Parser(top_rule_name='Rule', rules=rules, input='bbb')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        parser = Parser(top_rule_name='Rule', rules=rules, input='aba')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        parser = Parser(top_rule_name='Rule', rules=rules, input='bab')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

    def test_complex_precedence_mixed_operators(self):
        # "a"+ / "b"* "c" should be (("a"+) / (("b"*) "c"))
        grammar = '''
            Rule <- "a"+ / "b"* "c";
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        # Should match "a", "aa", "aaa", etc.
        parser = Parser(top_rule_name='Rule', rules=rules, input='a')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        parser = Parser(top_rule_name='Rule', rules=rules, input='aaa')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        # Should match "c", "bc", "bbc", etc.
        parser = Parser(top_rule_name='Rule', rules=rules, input='c')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        parser = Parser(top_rule_name='Rule', rules=rules, input='bc')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        parser = Parser(top_rule_name='Rule', rules=rules, input='bbc')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

    def test_transparent_operator_precedence(self):
        # ~"a"+ should be ~("a"+), not (~"a")+
        grammar = '''
            ~Rule <- "a"+;
            Main <- Rule;
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(top_rule_name='Main', rules=rules, input='aaa')
        parse_result = parser.parse()

        # Rule should be transparent, so it should be successfully parsed
        result = parse_result.root
        assert result is not None
        assert result.len == 3  # Should match the full input 'aaa'

    def test_prefix_operators_are_right_associative(self):
        # &!"a" should be &(!"a"), not (!(&"a"))
        grammar = '''
            Rule <- &!"a" "b";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        clause = repr(rules['Rule'])

        # Should have FollowedBy wrapping NotFollowedBy
        assert '&!"a"' in clause

    def test_suffix_operators_are_left_associative(self):
        # "a"+? should be ("a"+)?, not "a"+(?)
        # This test verifies that suffix operators apply to the result of the previous operation
        grammar = '''
            Rule <- "a"+?;
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        clause = repr(rules['Rule'])

        # Should have Optional wrapping OneOrMore
        assert '"a"+' in clause
        assert '?' in clause

    def test_character_class_binds_as_atomic_unit(self):
        # [a-z]+ should be ([a-z])+, with the character class as a single unit
        grammar = '''
            Rule <- [a-z]+;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(top_rule_name='Rule', rules=rules, input='abc')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 3

    def test_negated_character_class_binds_as_atomic_unit(self):
        # [^0-9]+ should match multiple non-digits
        grammar = '''
            Rule <- [^0-9]+;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(top_rule_name='Rule', rules=rules, input='abc')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 3

        # Use match_rule for partial match test
        parser = Parser(top_rule_name='Rule', rules=rules, input='a1')
        match_result = parser.match_rule('Rule', 0)
        assert not match_result.is_mismatch
        assert match_result.len == 1  # Only 'a' matches
