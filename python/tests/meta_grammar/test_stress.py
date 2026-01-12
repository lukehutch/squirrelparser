"""Tests for MetaGrammar stress tests."""

from squirrelparser import MetaGrammar, Parser, build_ast


class TestStressTests:
    """MetaGrammar - Stress Tests."""

    def test_deeply_nested_parentheses(self):
        # Test parser can handle deeply nested groupings
        grammar = '''
            Rule <- ((((("a")))));
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(top_rule_name='Rule', rules=rules, input='a')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 1

    def test_many_choice_alternatives(self):
        # Stress test with 20 alternatives
        grammar = '''
            Rule <- "a" / "b" / "c" / "d" / "e" / "f" / "g" / "h" / "i" / "j" /
                    "k" / "l" / "m" / "n" / "o" / "p" / "q" / "r" / "s" / "t" ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        # Test first alternative
        parser = Parser(top_rule_name='Rule', rules=rules, input='a')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        # Test middle alternative
        parser = Parser(top_rule_name='Rule', rules=rules, input='j')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        # Test last alternative
        parser = Parser(top_rule_name='Rule', rules=rules, input='t')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

    def test_deeply_nested_choices_and_sequences(self):
        # Complex nesting: (a (b / c) d (e / f / g))
        grammar = '''
            Rule <- "a" ("b" / "c") "d" ("e" / "f" / "g");
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(top_rule_name='Rule', rules=rules, input='abde')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        parser = Parser(top_rule_name='Rule', rules=rules, input='acdg')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        parser = Parser(top_rule_name='Rule', rules=rules, input='acdf')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

    def test_long_sequence(self):
        # Test a very long sequence
        grammar = '''
            Rule <- "a" "b" "c" "d" "e" "f" "g" "h" "i" "j"
                    "k" "l" "m" "n" "o" "p" "q" "r" "s" "t";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(top_rule_name='Rule', rules=rules, input='abcdefghijklmnopqrst')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 20

    def test_stacked_repetition_operators(self):
        # Test multiple suffix operators: (a+)?*
        # This is a bit pathological but should parse
        grammar = '''
            Rule <- ("a"+)?;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        # Empty input (optional matches)
        parser = Parser(top_rule_name='Rule', rules=rules, input='')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        # One 'a'
        parser = Parser(top_rule_name='Rule', rules=rules, input='a')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        # Multiple 'a's
        parser = Parser(top_rule_name='Rule', rules=rules, input='aaa')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

    def test_complex_lookahead_combinations(self):
        # Test &!&! pattern
        grammar = '''
            Rule <- &![0-9] [a-z]+ ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        # Should match letters not preceded by digits
        parser = Parser(top_rule_name='Rule', rules=rules, input='hello')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        # Should fail on digit start
        parser = Parser(top_rule_name='Rule', rules=rules, input='5hello')
        match_result = parser.match_rule('Rule', 0)
        assert match_result.is_mismatch

    def test_character_class_edge_cases(self):
        # Test character classes with many ranges
        grammar = '''
            Rule <- [a-zA-Z0-9_-.@]+ ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(top_rule_name='Rule', rules=rules, input='Test_123-name.email@')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

    def test_negated_character_class_with_multiple_ranges(self):
        # Everything except digits and whitespace
        grammar = r'''
            Rule <- [^0-9 \t\n\r]+ ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(top_rule_name='Rule', rules=rules, input='hello')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        # Should stop at first digit
        parser = Parser(top_rule_name='Rule', rules=rules, input='test123')
        match_result = parser.match_rule('Rule', 0)
        assert match_result.len == 4  # Matches 'test'

    def test_multiple_transparent_rules_interacting(self):
        grammar = r'''
            ~Space <- " " ;
            ~Tab <- "\t" ;
            ~WS <- (Space / Tab)+ ;
            Main <- WS "hello" WS "world" WS ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(top_rule_name='Main', rules=rules, input='  \thello\t  world \t')
        parse_result = parser.parse()
        ast = build_ast(parse_result)

        assert ast is not None
        # Should have 2 children: "hello" and "world" (WS nodes are transparent)
        assert len(ast.children) == 2

    def test_deeply_nested_rule_references(self):
        grammar = '''
            A <- B ;
            B <- C ;
            C <- D ;
            D <- E ;
            E <- "x" ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(top_rule_name='A', rules=rules, input='x')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

    def test_complex_escape_sequences(self):
        # Test escape sequences: newline, tab, quotes
        grammar = r'''
            Rule <- "line1\n\tquote\"test" ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(top_rule_name='Rule', rules=rules, input='line1\n\tquote"test')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 17

    def test_comments_in_various_positions(self):
        grammar = '''
            # Leading comment
            Rule <- # inline comment
                    "a" # after token
                    "b" # another
                    ; # end comment
            # Trailing comment
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(top_rule_name='Rule', rules=rules, input='ab')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

    def test_mutual_recursion_between_rules(self):
        grammar = '''
            A <- "a" B / "a" ;
            B <- "b" A / "b" ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        # Just 'a'
        parser = Parser(top_rule_name='A', rules=rules, input='a')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        # 'aba'
        parser = Parser(top_rule_name='A', rules=rules, input='aba')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        # 'ababa'
        parser = Parser(top_rule_name='A', rules=rules, input='ababa')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

    def test_complex_lookahead_in_repetition(self):
        # Match characters until we see "end"
        grammar = '''
            Rule <- (!"end" .)* "end" ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(top_rule_name='Rule', rules=rules, input='hello world end')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 15  # "hello world end"

    def test_optional_with_lookahead(self):
        # Optional digit followed by letter, but only if not followed by digit
        grammar = '''
            Rule <- ([0-9] ![0-9])? [a-z]+ ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        # Just letters
        parser = Parser(top_rule_name='Rule', rules=rules, input='hello')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        # Digit then letters
        parser = Parser(top_rule_name='Rule', rules=rules, input='5hello')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

    def test_zero_or_more_with_complex_content(self):
        # Pairs of letters and digits, zero or more times
        grammar = '''
            Rule <- ([a-z] [0-9])* ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        # Empty
        parser = Parser(top_rule_name='Rule', rules=rules, input='')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        # One pair
        parser = Parser(top_rule_name='Rule', rules=rules, input='a5')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        # Multiple pairs
        parser = Parser(top_rule_name='Rule', rules=rules, input='a5b3c7')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

    def test_choice_with_lookahead_conditions(self):
        # Match different patterns based on lookahead
        grammar = '''
            Rule <- &[a-z] Lowercase / &[A-Z] Uppercase / Digit ;
            Lowercase <- [a-z]+ ;
            Uppercase <- [A-Z]+ ;
            Digit <- [0-9]+ ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(top_rule_name='Rule', rules=rules, input='hello')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        parser = Parser(top_rule_name='Rule', rules=rules, input='WORLD')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        parser = Parser(top_rule_name='Rule', rules=rules, input='123')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

    def test_nested_optional_and_repetition(self):
        # Optional groups with repetition inside
        grammar = '''
            Rule <- ("a"+ "b"?)* ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(top_rule_name='Rule', rules=rules, input='')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        parser = Parser(top_rule_name='Rule', rules=rules, input='abaab')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        parser = Parser(top_rule_name='Rule', rules=rules, input='aaabaaaa')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

    def test_any_char_with_repetition_and_bounds(self):
        # Exactly 5 characters
        grammar = '''
            Rule <- . . . . . ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(top_rule_name='Rule', rules=rules, input='hello')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 5

    def test_complex_sequence_with_all_operator_types(self):
        # Combine all operators in one rule
        grammar = '''
            Rule <- &[a-z] [a-z]+ ![0-9] ("_" [a-z]+)* ([0-9]+)? ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        # Basic identifier
        parser = Parser(top_rule_name='Rule', rules=rules, input='hello')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        # With underscores
        parser = Parser(top_rule_name='Rule', rules=rules, input='hello_world_test')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        # With trailing digits
        parser = Parser(top_rule_name='Rule', rules=rules, input='test_var123')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

    def test_pathological_backtracking_case(self):
        # A pattern that could cause excessive backtracking in naive parsers
        grammar = '''
            Rule <- "a"* "a"* "a"* "a"* "b" ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(top_rule_name='Rule', rules=rules, input='aaaaab')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 6

    def test_rule_with_mixed_transparent_and_non_transparent_references(self):
        grammar = '''
            Main <- A ~B C ;
            A <- "a" ;
            ~B <- "b" ;
            C <- "c" ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(top_rule_name='Main', rules=rules, input='abc')
        parse_result = parser.parse()
        ast = build_ast(parse_result)

        assert ast is not None
        assert ast.label == 'Main'
        # Transparent rules (marked with ~) should not appear in the AST
        # So only A and C should be present, not B
        assert len(ast.children) == 2
        assert ast.children[0].label == 'A'
        assert ast.children[1].label == 'C'

    def test_character_class_with_special_characters(self):
        # Test characters including dot, underscore, hyphen
        grammar = '''
            Rule <- [a-z.@_]+ ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(top_rule_name='Rule', rules=rules, input='test.name_value@')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

    def test_very_long_rule_name(self):
        grammar = '''
            ThisIsAVeryLongRuleNameToTestThatLongIdentifiersWork <- "test" ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        assert 'ThisIsAVeryLongRuleNameToTestThatLongIdentifiersWork' in rules

    def test_multiple_consecutive_lookaheads(self):
        # Multiple positive lookaheads in sequence
        grammar = '''
            Rule <- &[a-z] &[a-c] "a" ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(top_rule_name='Rule', rules=rules, input='a')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        # Should fail for 'd' (doesn't match second lookahead)
        parser = Parser(top_rule_name='Rule', rules=rules, input='d')
        match_result = parser.match_rule('Rule', 0)
        assert match_result.is_mismatch

    def test_choice_with_potentially_empty_matches(self):
        # Test choice where alternatives can match varying lengths
        grammar = '''
            Rule <- "a"+ / "b"+ / "" ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        # 'aaa' matches first alternative
        parser = Parser(top_rule_name='Rule', rules=rules, input='aaa')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        # 'bbb' matches second alternative
        parser = Parser(top_rule_name='Rule', rules=rules, input='bbb')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        # Empty input matches third alternative
        parser = Parser(top_rule_name='Rule', rules=rules, input='')
        match_result = parser.match_rule('Rule', 0)
        assert not match_result.is_mismatch
        assert match_result.len == 0

    def test_negated_lookahead_with_alternatives(self):
        # Not followed by keyword
        grammar = '''
            Rule <- !(Keyword ![a-z]) [a-z]+ ;
            Keyword <- "if" / "while" / "for" ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        # Regular identifier works
        parser = Parser(top_rule_name='Rule', rules=rules, input='hello')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        # Keyword prefix works (iffy)
        parser = Parser(top_rule_name='Rule', rules=rules, input='iffy')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None

        # Pure keyword should fail
        parser = Parser(top_rule_name='Rule', rules=rules, input='if')
        match_result = parser.match_rule('Rule', 0)
        assert match_result.is_mismatch

    def test_repetition_of_grouped_alternation(self):
        # Repeat a choice multiple times
        grammar = '''
            Rule <- ("a" / "b" / "c")+ ;
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(top_rule_name='Rule', rules=rules, input='abccbaabccc')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 11
