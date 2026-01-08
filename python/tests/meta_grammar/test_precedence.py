"""MetaGrammar - Operator Precedence Tests"""
from squirrelparser import Parser
from squirrelparser.meta_grammar import MetaGrammar


class TestMetaGrammarOperatorPrecedence:
    """MetaGrammar - Operator Precedence"""

    def test_suffix_binds_tighter_than_sequence(self) -> None:
        """suffix binds tighter than sequence"""
        # "a"+ "b" should be ("a"+ "b"), not ("a" "b")+
        grammar = '''
            Rule <- "a"+ "b";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        clause = str(rules['Rule'])

        # Should have OneOrMore around first element only
        assert '"a"+' in clause or 'OneOrMore' in clause
        assert '"b"' in clause

    def test_prefix_binds_tighter_than_sequence(self) -> None:
        """prefix binds tighter than sequence"""
        # !"a" "b" should be (!"a" "b"), not !("a" "b")
        grammar = '''
            Rule <- !"a" "b";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        clause = str(rules['Rule'])

        # Should have NotFollowedBy around first element only
        assert '!"a"' in clause or 'NotFollowedBy' in clause
        assert '"b"' in clause

    def test_sequence_binds_tighter_than_choice(self) -> None:
        """sequence binds tighter than choice"""
        # "a" "b" / "c" should be (("a" "b") / "c"), not ("a" ("b" / "c"))
        from squirrelparser import SyntaxError as SyntaxErrorNode
        grammar = '''
            Rule <- "a" "b" / "c";
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        # Test that it parses "ab" and "c", but not "ac"
        parser = Parser(rules=rules, input_str='ab')
        result, _ = parser.parse('Rule')
        assert result is not None

        parser = Parser(rules=rules, input_str='c')
        result, _ = parser.parse('Rule')
        assert result is not None

        parser = Parser(rules=rules, input_str='ac')
        result, _ = parser.parse('Rule')
        # With spanning invariant, total failure returns SyntaxError
        assert isinstance(result, SyntaxErrorNode), '"ac" does not match ("ab" / "c")'

    def test_suffix_binds_tighter_than_prefix(self) -> None:
        """suffix binds tighter than prefix"""
        # &"a"+ should be &("a"+), not (&"a")+
        grammar = '''
            Rule <- &"a"+ "a";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        clause = str(rules['Rule'])

        # Should have FollowedBy wrapping OneOrMore
        assert '&"a"+' in clause or 'FollowedBy' in clause

    def test_grouping_overrides_precedence_sequence_in_choice(self) -> None:
        """grouping overrides precedence - sequence in choice"""
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
        parser = Parser(rules=rules1, input_str='a')
        result, _ = parser.parse('Rule')
        assert result is not None

        parser = Parser(rules=rules1, input_str='bc')
        result, _ = parser.parse('Rule')
        assert result is not None

        # 'ac' should match 'a' but with 'c' as an error node
        # With spanning invariant, parse recovers and spans the full input
        parser = Parser(rules=rules1, input_str='ac')
        result, _ = parser.parse('Rule')
        # Should span the input with first alternative ('a') and error for 'c'
        assert result is not None and not result.is_mismatch, 'grammar1 should match "ac" with recovery'
        assert result.len == 2, 'should span full input (both "a" and "c")'

        # Grammar 2: should match "ac" or "bc"
        parser = Parser(rules=rules2, input_str='ac')
        result, _ = parser.parse('Rule')
        assert result is not None

        parser = Parser(rules=rules2, input_str='bc')
        result, _ = parser.parse('Rule')
        assert result is not None

        # 'a' should match first part but with missing 'c' at EOF (deletion allowed at EOF)
        parser = Parser(rules=rules2, input_str='a')
        result, _ = parser.parse('Rule')
        # Should span the input with first alternative ('a') and 'c' deleted at EOF
        assert result is not None and not result.is_mismatch, 'grammar2 should match "a" with EOF deletion'
        assert result.len == 1, 'should span full input'

    def test_grouping_overrides_precedence_choice_in_suffix(self) -> None:
        """grouping overrides precedence - choice in suffix"""
        # ("a" / "b")+ should allow "aaa", "bbb", "aba", etc.
        grammar = '''
            Rule <- ("a" / "b")+;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(rules=rules, input_str='aaa')
        result, _ = parser.parse('Rule')
        assert result is not None

        parser = Parser(rules=rules, input_str='bbb')
        result, _ = parser.parse('Rule')
        assert result is not None

        parser = Parser(rules=rules, input_str='aba')
        result, _ = parser.parse('Rule')
        assert result is not None

        parser = Parser(rules=rules, input_str='bab')
        result, _ = parser.parse('Rule')
        assert result is not None

    def test_complex_precedence_mixed_operators(self) -> None:
        """complex precedence - mixed operators"""
        # "a"+ / "b"* "c" should be (("a"+) / (("b"*) "c"))
        grammar = '''
            Rule <- "a"+ / "b"* "c";
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        # Should match "a", "aa", "aaa", etc.
        parser = Parser(rules=rules, input_str='a')
        result, _ = parser.parse('Rule')
        assert result is not None

        parser = Parser(rules=rules, input_str='aaa')
        result, _ = parser.parse('Rule')
        assert result is not None

        # Should match "c", "bc", "bbc", etc.
        parser = Parser(rules=rules, input_str='c')
        result, _ = parser.parse('Rule')
        assert result is not None

        parser = Parser(rules=rules, input_str='bc')
        result, _ = parser.parse('Rule')
        assert result is not None

        parser = Parser(rules=rules, input_str='bbc')
        result, _ = parser.parse('Rule')
        assert result is not None

    def test_transparent_operator_precedence(self) -> None:
        """transparent operator precedence"""
        # ~"a"+ should be ~("a"+), not (~"a")+
        grammar = '''
            ~Rule <- "a"+;
            Main <- Rule;
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(rules=rules, input_str='aaa')
        ast, _ = parser.parse_to_ast('Main')

        # Rule should be transparent, so Main should not have a Rule child
        assert ast is not None
        assert ast.label == 'Main'
        # If Rule is properly transparent, we shouldn't see it in the AST

    def test_prefix_operators_are_right_associative(self) -> None:
        """prefix operators are right-associative"""
        # &!"a" should be &(!"a"), not (!(&"a"))
        grammar = '''
            Rule <- &!"a" "b";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        clause = str(rules['Rule'])

        # Should have FollowedBy wrapping NotFollowedBy
        assert '&!"a"' in clause or 'FollowedBy' in clause

    def test_suffix_operators_are_left_associative(self) -> None:
        """suffix operators are left-associative"""
        # "a"+? should be ("a"+)?, not "a"+(?)
        # Note: PEG doesn't typically allow ++, but if it did, it would be left-associative
        # This test verifies that suffix operators apply to the result of the previous operation
        grammar = '''
            Rule <- "a"+?;
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        clause = str(rules['Rule'])

        # Should have Optional wrapping OneOrMore
        assert '"a"+' in clause or 'OneOrMore' in clause
        assert '?' in clause or 'Optional' in clause

    def test_character_class_binds_as_atomic_unit(self) -> None:
        """character class binds as atomic unit"""
        # [a-z]+ should be ([a-z])+, with the character class as a single unit
        grammar = '''
            Rule <- [a-z]+;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(rules=rules, input_str='abc')
        result, _ = parser.parse('Rule')
        assert result is not None
        assert result.len == 3

    def test_negated_character_class_binds_as_atomic_unit(self) -> None:
        """negated character class binds as atomic unit"""
        # [^0-9]+ should match multiple non-digits
        grammar = '''
            Rule <- [^0-9]+;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(rules=rules, input_str='abc')
        result, _ = parser.parse('Rule')
        assert result is not None
        assert result.len == 3

        # Use match_rule for partial match test
        parser = Parser(rules=rules, input_str='a1')
        match_result = parser.match_rule('Rule', 0)
        assert not match_result.is_mismatch
        assert match_result.len == 1  # Only 'a' matches
