"""MetaGrammar - Stress Tests"""
from squirrelparser import Parser
from squirrelparser.meta_grammar import MetaGrammar


class TestMetaGrammarStressTests:
    """MetaGrammar - Stress Tests"""

    def test_deeply_nested_parentheses(self) -> None:
        """deeply nested parentheses"""
        # Test parser can handle deeply nested groupings
        grammar = '''
            Rule <- ((((("a")))));
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(rules=rules, input_str='a')
        result, _ = parser.parse('Rule')
        assert result is not None
        assert result.len == 1

    def test_many_choice_alternatives(self) -> None:
        """many choice alternatives"""
        # Stress test with 20 alternatives
        grammar = '''
            Rule <- "a" / "b" / "c" / "d" / "e" / "f" / "g" / "h" / "i" / "j" /
                    "k" / "l" / "m" / "n" / "o" / "p" / "q" / "r" / "s" / "t" ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        # Test first alternative
        parser = Parser(rules=rules, input_str='a')
        result, _ = parser.parse('Rule')
        assert result is not None

        # Test middle alternative
        parser = Parser(rules=rules, input_str='j')
        result, _ = parser.parse('Rule')
        assert result is not None

        # Test last alternative
        parser = Parser(rules=rules, input_str='t')
        result, _ = parser.parse('Rule')
        assert result is not None

    def test_deeply_nested_choices_and_sequences(self) -> None:
        """deeply nested choices and sequences"""
        # Complex nesting: (a (b / c) d (e / f / g))
        grammar = '''
            Rule <- "a" ("b" / "c") "d" ("e" / "f" / "g");
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(rules=rules, input_str='abde')
        result, _ = parser.parse('Rule')
        assert result is not None

        parser = Parser(rules=rules, input_str='acdg')
        result, _ = parser.parse('Rule')
        assert result is not None

        parser = Parser(rules=rules, input_str='acdf')
        result, _ = parser.parse('Rule')
        assert result is not None

    def test_long_sequence(self) -> None:
        """long sequence"""
        # Test a very long sequence
        grammar = '''
            Rule <- "a" "b" "c" "d" "e" "f" "g" "h" "i" "j"
                    "k" "l" "m" "n" "o" "p" "q" "r" "s" "t";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(rules=rules, input_str='abcdefghijklmnopqrst')
        result, _ = parser.parse('Rule')
        assert result is not None
        assert result.len == 20

    def test_stacked_repetition_operators(self) -> None:
        """stacked repetition operators"""
        # Test multiple suffix operators: (a+)?*
        # This is a bit pathological but should parse
        grammar = '''
            Rule <- ("a"+)?;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        # Empty input (optional matches)
        parser = Parser(rules=rules, input_str='')
        result, _ = parser.parse('Rule')
        assert result is not None

        # One 'a'
        parser = Parser(rules=rules, input_str='a')
        result, _ = parser.parse('Rule')
        assert result is not None

        # Multiple 'a's
        parser = Parser(rules=rules, input_str='aaa')
        result, _ = parser.parse('Rule')
        assert result is not None

    def test_complex_lookahead_combinations(self) -> None:
        """complex lookahead combinations"""
        # Test &!&! pattern
        grammar = '''
            Rule <- &![0-9] [a-z]+ ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        # Should match letters not preceded by digits
        parser = Parser(rules=rules, input_str='hello')
        result, _ = parser.parse('Rule')
        assert result is not None

        # Should fail on digit start
        parser = Parser(rules=rules, input_str='5hello')
        match_result = parser.match_rule('Rule', 0)
        assert match_result.is_mismatch

    def test_character_class_edge_cases(self) -> None:
        """character class edge cases"""
        # Test character classes with many ranges
        grammar = r'''
            Rule <- [a-zA-Z0-9_\-\.@]+ ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(rules=rules, input_str='Test_123-name.email@')
        result, _ = parser.parse('Rule')
        assert result is not None

    def test_negated_character_class_with_multiple_ranges(self) -> None:
        """negated character class with multiple ranges"""
        # Everything except digits and whitespace
        grammar = r'''
            Rule <- [^0-9 \t\n\r]+ ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(rules=rules, input_str='hello')
        result, _ = parser.parse('Rule')
        assert result is not None

        # Should stop at first digit
        parser = Parser(rules=rules, input_str='test123')
        match_result = parser.match_rule('Rule', 0)
        assert match_result.len == 4  # Matches 'test'

    def test_multiple_transparent_rules_interacting(self) -> None:
        """multiple transparent rules interacting"""
        grammar = '''
            ~Space <- " " ;
            ~Tab <- "\t" ;
            ~WS <- (Space / Tab)+ ;
            Main <- WS "hello" WS "world" WS ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(rules=rules, input_str='  \thello\t  world \t')
        ast, _ = parser.parse_to_ast('Main')

        assert ast is not None
        # Should have 2 children: "hello" and "world" (WS nodes are transparent)
        assert len(ast.children) == 2

    def test_deeply_nested_rule_references(self) -> None:
        """deeply nested rule references"""
        grammar = '''
            A <- B ;
            B <- C ;
            C <- D ;
            D <- E ;
            E <- "x" ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(rules=rules, input_str='x')
        result, _ = parser.parse('A')
        assert result is not None

    def test_complex_escape_sequences(self) -> None:
        """complex escape sequences"""
        # Test escape sequences: newline, tab, quotes
        grammar = r'''
            Rule <- "line1\n\tquote\"test" ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(rules=rules, input_str='line1\n\tquote"test')
        result, _ = parser.parse('Rule')
        assert result is not None
        assert result.len == 17

    def test_comments_in_various_positions(self) -> None:
        """comments in various positions"""
        grammar = '''
            # Leading comment
            Rule <- # inline comment
                    "a" # after token
                    "b" # another
                    ; # end comment
            # Trailing comment
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(rules=rules, input_str='ab')
        result, _ = parser.parse('Rule')
        assert result is not None

    def test_mutual_recursion_between_rules(self) -> None:
        """mutual recursion between rules"""
        grammar = '''
            A <- "a" B / "a" ;
            B <- "b" A / "b" ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        # Just 'a'
        parser = Parser(rules=rules, input_str='a')
        result, _ = parser.parse('A')
        assert result is not None

        # 'aba'
        parser = Parser(rules=rules, input_str='aba')
        result, _ = parser.parse('A')
        assert result is not None

        # 'ababa'
        parser = Parser(rules=rules, input_str='ababa')
        result, _ = parser.parse('A')
        assert result is not None

    def test_complex_lookahead_in_repetition(self) -> None:
        """complex lookahead in repetition"""
        # Match characters until we see "end"
        grammar = '''
            Rule <- (!"end" .)* "end" ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(rules=rules, input_str='hello world end')
        result, _ = parser.parse('Rule')
        assert result is not None
        assert result.len == 15  # "hello world end"

    def test_optional_with_lookahead(self) -> None:
        """optional with lookahead"""
        # Optional digit followed by letter, but only if not followed by digit
        grammar = '''
            Rule <- ([0-9] ![0-9])? [a-z]+ ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        # Just letters
        parser = Parser(rules=rules, input_str='hello')
        result, _ = parser.parse('Rule')
        assert result is not None

        # Digit then letters
        parser = Parser(rules=rules, input_str='5hello')
        result, _ = parser.parse('Rule')
        assert result is not None

    def test_zero_or_more_with_complex_content(self) -> None:
        """zero-or-more with complex content"""
        # Pairs of letters and digits, zero or more times
        grammar = '''
            Rule <- ([a-z] [0-9])* ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        # Empty
        parser = Parser(rules=rules, input_str='')
        result, _ = parser.parse('Rule')
        assert result is not None

        # One pair
        parser = Parser(rules=rules, input_str='a5')
        result, _ = parser.parse('Rule')
        assert result is not None

        # Multiple pairs
        parser = Parser(rules=rules, input_str='a5b3c7')
        result, _ = parser.parse('Rule')
        assert result is not None

    def test_choice_with_lookahead_conditions(self) -> None:
        """choice with lookahead conditions"""
        # Match different patterns based on lookahead
        grammar = '''
            Rule <- &[a-z] Lowercase / &[A-Z] Uppercase / Digit ;
            Lowercase <- [a-z]+ ;
            Uppercase <- [A-Z]+ ;
            Digit <- [0-9]+ ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(rules=rules, input_str='hello')
        result, _ = parser.parse('Rule')
        assert result is not None

        parser = Parser(rules=rules, input_str='WORLD')
        result, _ = parser.parse('Rule')
        assert result is not None

        parser = Parser(rules=rules, input_str='123')
        result, _ = parser.parse('Rule')
        assert result is not None

    def test_nested_optional_and_repetition(self) -> None:
        """nested optional and repetition"""
        # Optional groups with repetition inside
        grammar = '''
            Rule <- ("a"+ "b"?)* ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(rules=rules, input_str='')
        result, _ = parser.parse('Rule')
        assert result is not None

        parser = Parser(rules=rules, input_str='abaab')
        result, _ = parser.parse('Rule')
        assert result is not None

        parser = Parser(rules=rules, input_str='aaabaaaa')
        result, _ = parser.parse('Rule')
        assert result is not None

    def test_any_char_with_repetition_and_bounds(self) -> None:
        """any char with repetition and bounds"""
        # Exactly 5 characters
        grammar = '''
            Rule <- . . . . . ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(rules=rules, input_str='hello')
        result, _ = parser.parse('Rule')
        assert result is not None
        assert result.len == 5

    def test_complex_sequence_with_all_operator_types(self) -> None:
        """complex sequence with all operator types"""
        # Combine all operators in one rule
        grammar = '''
            Rule <- &[a-z] [a-z]+ ![0-9] ("_" [a-z]+)* ([0-9]+)? ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        # Basic identifier
        parser = Parser(rules=rules, input_str='hello')
        result, _ = parser.parse('Rule')
        assert result is not None

        # With underscores
        parser = Parser(rules=rules, input_str='hello_world_test')
        result, _ = parser.parse('Rule')
        assert result is not None

        # With trailing digits
        parser = Parser(rules=rules, input_str='test_var123')
        result, _ = parser.parse('Rule')
        assert result is not None

    def test_pathological_backtracking_case(self) -> None:
        """pathological backtracking case"""
        # A pattern that could cause excessive backtracking in naive parsers
        grammar = '''
            Rule <- "a"* "a"* "a"* "a"* "b" ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(rules=rules, input_str='aaaaab')
        result, _ = parser.parse('Rule')
        assert result is not None
        assert result.len == 6

    def test_rule_with_mixed_transparent_and_non_transparent_references(self) -> None:
        """rule with mixed transparent and non-transparent references"""
        grammar = '''
            Main <- A ~B C ;
            A <- "a" ;
            ~B <- "b" ;
            C <- "c" ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(rules=rules, input_str='abc')
        ast, _ = parser.parse_to_ast('Main')

        assert ast is not None
        assert ast.label == 'Main'
        # All three children are present (B appears even though marked transparent)
        assert len(ast.children) == 3
        assert ast.children[0].label == 'A'
        assert ast.children[1].label == 'B'
        assert ast.children[2].label == 'C'

    def test_character_class_with_special_characters(self) -> None:
        """character class with special characters"""
        # Test characters including dot, underscore, hyphen
        grammar = '''
            Rule <- [a-z.@_]+ ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(rules=rules, input_str='test.name_value@')
        result, _ = parser.parse('Rule')
        assert result is not None

    def test_very_long_rule_name(self) -> None:
        """very long rule name"""
        grammar = '''
            ThisIsAVeryLongRuleNameToTestThatLongIdentifiersWork <- "test" ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        assert 'ThisIsAVeryLongRuleNameToTestThatLongIdentifiersWork' in rules

    def test_multiple_consecutive_lookaheads(self) -> None:
        """multiple consecutive lookaheads"""
        # Multiple positive lookaheads in sequence
        grammar = '''
            Rule <- &[a-z] &[a-c] "a" ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(rules=rules, input_str='a')
        result, _ = parser.parse('Rule')
        assert result is not None

        # Should fail for 'd' (doesn't match second lookahead)
        parser = Parser(rules=rules, input_str='d')
        match_result = parser.match_rule('Rule', 0)
        assert match_result.is_mismatch

    def test_choice_with_potentially_empty_matches(self) -> None:
        """choice with potentially empty matches"""
        # Test choice where alternatives can match varying lengths
        grammar = '''
            Rule <- "a"+ / "b"+ / "" ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        # 'aaa' matches first alternative
        parser = Parser(rules=rules, input_str='aaa')
        result, _ = parser.parse('Rule')
        assert result is not None

        # 'bbb' matches second alternative
        parser = Parser(rules=rules, input_str='bbb')
        result, _ = parser.parse('Rule')
        assert result is not None

        # Empty input matches third alternative
        parser = Parser(rules=rules, input_str='')
        match_result = parser.match_rule('Rule', 0)
        assert not match_result.is_mismatch
        assert match_result.len == 0

    def test_negated_lookahead_with_alternatives(self) -> None:
        """negated lookahead with alternatives"""
        # Not followed by keyword
        grammar = '''
            Rule <- !(Keyword ![a-z]) [a-z]+ ;
            Keyword <- "if" / "while" / "for" ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        # Regular identifier works
        parser = Parser(rules=rules, input_str='hello')
        result, _ = parser.parse('Rule')
        assert result is not None

        # Keyword prefix works (iffy)
        parser = Parser(rules=rules, input_str='iffy')
        result, _ = parser.parse('Rule')
        assert result is not None

        # Pure keyword should fail
        parser = Parser(rules=rules, input_str='if')
        match_result = parser.match_rule('Rule', 0)
        assert match_result.is_mismatch

    def test_repetition_of_grouped_alternation(self) -> None:
        """repetition of grouped alternation"""
        # Repeat a choice multiple times
        grammar = '''
            Rule <- ("a" / "b" / "c")+ ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(rules=rules, input_str='abccbaabccc')
        result, _ = parser.parse('Rule')
        assert result is not None
        assert result.len == 11
