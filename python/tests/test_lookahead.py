from squirrelparser import squirrel_parse_pt
from squirrelparser.match_result import SyntaxError


class TestFollowedBy:

    def test_positive_lookahead_succeeds_when_pattern_matches(self):
        result = squirrel_parse_pt(
            grammar_spec='Test <- &"a" ;',
            top_rule_name='Test',
            input='abc',
        )
        assert result.root.is_mismatch is False
        assert result.root.len == 0  # Lookahead doesn't consume

    def test_positive_lookahead_fails_when_pattern_does_not_match(self):
        result = squirrel_parse_pt(
            grammar_spec='Test <- &"a" ;',
            top_rule_name='Test',
            input='b',
        )
        assert isinstance(result.root, SyntaxError)

    def test_positive_lookahead_in_sequence(self):
        result = squirrel_parse_pt(
            grammar_spec='Test <- "a" &"b" ;',
            top_rule_name='Test',
            input='abc',
        )
        assert result.root.is_mismatch is False
        assert result.root.len == 1  # Only 'a' consumed

    def test_positive_lookahead_in_sequence_fails_when_not_followed(self):
        result = squirrel_parse_pt(
            grammar_spec='Test <- "a" &"b" ;',
            top_rule_name='Test',
            input='ac',
        )
        assert isinstance(result.root, SyntaxError)  # Fails because no 'b' after 'a'

    def test_positive_lookahead_with_continuation(self):
        result = squirrel_parse_pt(
            grammar_spec='Test <- "a" &"b" "b" ;',
            top_rule_name='Test',
            input='abc',
        )
        assert result.root.is_mismatch is False
        assert result.root.len == 2  # 'a' and 'b' consumed

    def test_positive_lookahead_at_end_of_input(self):
        result = squirrel_parse_pt(
            grammar_spec='Test <- "a" &"b" ;',
            top_rule_name='Test',
            input='a',
        )
        # With error recovery, this succeeds but has syntax errors
        assert result.has_syntax_errors is True  # No 'b' to look ahead to

    def test_nested_positive_lookaheads(self):
        result = squirrel_parse_pt(
            grammar_spec='Test <- &&"a" "a" ;',
            top_rule_name='Test',
            input='a',
        )
        assert result.root.is_mismatch is False
        assert result.root.len == 1


class TestNotFollowedBy:

    def test_negative_lookahead_succeeds_when_pattern_does_not_match(self):
        result = squirrel_parse_pt(
            grammar_spec='Test <- !"a" ;',
            top_rule_name='Test',
            input='b',
        )
        assert result.root.is_mismatch is False
        assert result.root.len == 0  # Lookahead doesn't consume

    def test_negative_lookahead_fails_when_pattern_matches(self):
        result = squirrel_parse_pt(
            grammar_spec='Test <- !"a" ;',
            top_rule_name='Test',
            input='a',
        )
        assert isinstance(result.root, SyntaxError)

    def test_negative_lookahead_in_sequence(self):
        result = squirrel_parse_pt(
            grammar_spec='Test <- "a" !"b" ;',
            top_rule_name='Test',
            input='ac',
        )
        assert result.root.is_mismatch is False
        assert result.root.len == 1  # Only 'a' consumed

    def test_negative_lookahead_in_sequence_fails_when_followed(self):
        result = squirrel_parse_pt(
            grammar_spec='Test <- "a" !"b" ;',
            top_rule_name='Test',
            input='ab',
        )
        assert isinstance(result.root, SyntaxError)  # Fails because 'a' IS followed by 'b'

    def test_negative_lookahead_with_continuation(self):
        result = squirrel_parse_pt(
            grammar_spec='Test <- "a" !"b" "c" ;',
            top_rule_name='Test',
            input='ac',
        )
        assert result.root.is_mismatch is False
        assert result.root.len == 2  # 'a' and 'c' consumed

    def test_negative_lookahead_at_end_of_input(self):
        result = squirrel_parse_pt(
            grammar_spec='Test <- "a" !"b" ;',
            top_rule_name='Test',
            input='a',
        )
        assert result.root.is_mismatch is False  # No 'b' following, so succeeds
        assert result.root.len == 1

    def test_nested_negative_lookaheads(self):
        # !!"a" is the same as &"a"
        result = squirrel_parse_pt(
            grammar_spec='Test <- !!"a" "a" ;',
            top_rule_name='Test',
            input='a',
        )
        assert result.root.is_mismatch is False
        assert result.root.len == 1


class TestMixedLookaheads:

    def test_positive_then_negative_lookahead(self):
        grammar = 'Test <- &[a-z] !"x" [a-z] ;'

        # Should match any lowercase letter except 'x'
        result = squirrel_parse_pt(grammar_spec=grammar, top_rule_name='Test', input='a')
        assert result.root.is_mismatch is False

        result = squirrel_parse_pt(grammar_spec=grammar, top_rule_name='Test', input='x')
        assert isinstance(result.root, SyntaxError)

        result = squirrel_parse_pt(grammar_spec=grammar, top_rule_name='Test', input='A')
        assert isinstance(result.root, SyntaxError)

    def test_lookahead_in_choice(self):
        grammar = 'Test <- &"a" "a" / &"b" "b" ;'

        result = squirrel_parse_pt(grammar_spec=grammar, top_rule_name='Test', input='a')
        assert result.root.is_mismatch is False
        assert result.root.len == 1

        result = squirrel_parse_pt(grammar_spec=grammar, top_rule_name='Test', input='b')
        assert result.root.is_mismatch is False
        assert result.root.len == 1

        result = squirrel_parse_pt(grammar_spec=grammar, top_rule_name='Test', input='c')
        assert isinstance(result.root, SyntaxError)

    def test_lookahead_with_repetition(self):
        grammar = 'Test <- (!"." [a-z])* ;'

        # Match lowercase letters until '.', then parser has unmatched input
        result = squirrel_parse_pt(grammar_spec=grammar, top_rule_name='Test', input='abc.def')
        assert result.root.is_mismatch is False
        # The grammar itself only matches 'abc', but error recovery captures trailing '.def'
        assert result.has_syntax_errors is True

        result = squirrel_parse_pt(grammar_spec=grammar, top_rule_name='Test', input='.abc')
        assert result.root.is_mismatch is False
        # With error recovery, unmatched '.abc' is captured as syntax error
        assert result.has_syntax_errors is True


class TestLookaheadWithReferences:

    def test_positive_lookahead_with_rule_reference(self):
        result = squirrel_parse_pt(
            grammar_spec='''
                Test <- &Digit Digit ;
                Digit <- [0-9] ;
            ''',
            top_rule_name='Test',
            input='5',
        )
        assert result.root.is_mismatch is False
        assert result.root.len == 1

    def test_negative_lookahead_with_rule_reference(self):
        grammar = '''
            Test <- !Digit [a-z] ;
            Digit <- [0-9] ;
        '''

        result = squirrel_parse_pt(grammar_spec=grammar, top_rule_name='Test', input='a')
        assert result.root.is_mismatch is False

        result = squirrel_parse_pt(grammar_spec=grammar, top_rule_name='Test', input='5')
        assert isinstance(result.root, SyntaxError)


class TestLookaheadIntegration:

    def test_lookahead_with_full_input_consumption(self):
        result = squirrel_parse_pt(
            grammar_spec='Test <- "a" &"b" "b" ;',
            top_rule_name='Test',
            input='ab',
        )
        assert result.root is not None
        assert result.root.len == 2  # Both 'a' and 'b' consumed

    def test_negative_lookahead_with_full_input_consumption(self):
        result = squirrel_parse_pt(
            grammar_spec='Test <- "a" !"b" "c" ;',
            top_rule_name='Test',
            input='ac',
        )
        assert result.root is not None
        assert result.root.len == 2  # 'a' and 'c' consumed

    def test_identifier_parser_with_lookahead_valid(self):
        # Parse identifiers that don't start with a digit
        result = squirrel_parse_pt(
            grammar_spec='Identifier <- ![0-9] [a-zA-Z0-9_]+ ;',
            top_rule_name='Identifier',
            input='abc123',
        )
        assert result.root is not None
        assert result.root.len == 6

    def test_identifier_parser_with_lookahead_invalid_starts_with_digit(self):
        # Parse identifiers that don't start with a digit
        result = squirrel_parse_pt(
            grammar_spec='Identifier <- ![0-9] [a-zA-Z0-9_]+ ;',
            top_rule_name='Identifier',
            input='123abc',
        )
        # With error recovery, this may recover by skipping digits, so check for errors
        assert result.has_syntax_errors is True  # Starts with digit, should have errors

    def test_keyword_vs_identifier_with_lookahead(self):
        # Parse 'if' only when not followed by alphanumeric (i.e., as keyword)
        grammar = 'Keyword <- "if" ![a-zA-Z0-9_] ;'

        # Valid keyword (all input consumed)
        result = squirrel_parse_pt(grammar_spec=grammar, top_rule_name='Keyword', input='if')
        assert result.root is not None  # 'if' as keyword
        assert result.root.len == 2

        # Invalid - 'ifx' is not just 'if'
        result = squirrel_parse_pt(grammar_spec=grammar, top_rule_name='Keyword', input='ifx')
        # Total failure: result is SyntaxError spanning entire input
        assert isinstance(result.root, SyntaxError)

    def test_comment_parser_with_lookahead(self):
        # Parse // style comments until end of line
        result = squirrel_parse_pt(
            grammar_spec=r'''Comment <- "//" (!'\n' .)* '\n' ;''',
            top_rule_name='Comment',
            input='//hello world\n',
        )
        assert result.root is not None
        assert result.root.len == 14  # All input consumed

    def test_string_literal_parser_with_lookahead(self):
        # Parse string literals with escape sequences
        grammar = r'''String <- '"' ("\\" . / !'"' .)* '"' ;'''

        result = squirrel_parse_pt(grammar_spec=grammar, top_rule_name='String', input='"hello"')
        assert result.root is not None

        result = squirrel_parse_pt(grammar_spec=grammar, top_rule_name='String', input='"hello\\"world"')
        assert result.root is not None
