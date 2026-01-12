# ===========================================================================
# PARSE TREE SPANNING INVARIANT TESTS
# ===========================================================================
# These tests verify that Parser.parse() always returns a MatchResult
# that completely spans the input (from position 0 to input.length).
# - Total failures: SyntaxError spanning entire input
# - Partial matches: wrapped with trailing SyntaxError
# - Complete matches: result spans full input with no wrapper needed

from squirrelparser import squirrel_parse_pt
from squirrelparser.match_result import Match, SyntaxError, MatchResult


def get_spanning_result(parse_result) -> MatchResult:
    """
    Helper to get a MatchResult that spans the entire input.
    If there's an unmatched_input, this wraps root and unmatched_input together.
    """
    if parse_result.unmatched_input is None:
        return parse_result.root

    root = parse_result.root

    # Total failure case: root is already SyntaxError spanning entire input
    if isinstance(root, SyntaxError) and root.len == len(parse_result.input):
        return root

    # Create a synthetic Match that contains both root and unmatched_input as children
    if isinstance(root, SyntaxError):
        children = [root, parse_result.unmatched_input]
        error_count = 2
    else:
        root_match = root
        if not root_match.sub_clause_matches:
            children = [root, parse_result.unmatched_input]
        else:
            children = [*root_match.sub_clause_matches, parse_result.unmatched_input]
        error_count = root_match.tot_descendant_errors + 1

    return Match(
        root.clause,
        0,
        len(parse_result.input),
        sub_clause_matches=children,
        is_complete=True,
        num_syntax_errors=error_count,
        add_sub_clause_errors=False,
    )


def has_trailing_error(result: MatchResult, pos: int, length: int) -> bool:
    if isinstance(result, SyntaxError):
        if result.pos == pos and result.len == length:
            return True
    for child in result.sub_clause_matches:
        if has_trailing_error(child, pos, length):
            return True
    return False


def has_syntax_error(result: MatchResult) -> bool:
    if isinstance(result, SyntaxError):
        return True
    for child in result.sub_clause_matches:
        if has_syntax_error(child):
            return True
    return False


def collect_errors(result: MatchResult) -> list[SyntaxError]:
    errors: list[SyntaxError] = []

    def collect(r: MatchResult) -> None:
        if isinstance(r, SyntaxError):
            errors.append(r)
        for child in r.sub_clause_matches:
            collect(child)

    collect(result)
    return errors


class TestSpanningInvariant:

    def test_span01_empty_input(self):
        parse_result = squirrel_parse_pt(
            grammar_spec='S <- "a" ;',
            top_rule_name='S',
            input='',
        )
        result = get_spanning_result(parse_result)

        assert isinstance(result, SyntaxError), "Empty input with no match should be SyntaxError"
        assert result.len == 0, "SyntaxError should span full empty input"
        assert result.pos == 0

    def test_span02_complete_match_no_wrapper(self):
        parse_result = squirrel_parse_pt(
            grammar_spec='S <- "a" "b" "c" ;',
            top_rule_name='S',
            input='abc',
        )
        result = get_spanning_result(parse_result)

        assert not isinstance(result, SyntaxError), "Complete match should not be SyntaxError"
        assert result.len == 3, "Should span entire input"
        assert result.is_mismatch is False

    def test_span03_total_failure_returns_syntax_error(self):
        parse_result = squirrel_parse_pt(
            grammar_spec='S <- "a" ;',
            top_rule_name='S',
            input='xyz',
        )
        result = get_spanning_result(parse_result)

        assert isinstance(result, SyntaxError), "Total failure should be SyntaxError"
        assert result.len == 3, "SyntaxError should span entire input"

    def test_span04_trailing_garbage_wrapped(self):
        parse_result = squirrel_parse_pt(
            grammar_spec='S <- "a" "b" ;',
            top_rule_name='S',
            input='abXYZ',
        )
        result = get_spanning_result(parse_result)

        assert result.len == 5, "Result should span entire input"
        assert not isinstance(result, SyntaxError), "Result is wrapper Match"
        assert has_trailing_error(result, 2, 3), "Should contain SyntaxError for trailing XYZ"

    def test_span05_single_char_trailing(self):
        parse_result = squirrel_parse_pt(
            grammar_spec='S <- "a" ;',
            top_rule_name='S',
            input='aX',
        )
        result = get_spanning_result(parse_result)

        assert parse_result.unmatched_input is not None, "Should have unmatched_input for trailing X"
        assert result.len == 2, "Should span full input"
        assert not isinstance(result, SyntaxError)
        assert has_trailing_error(result, 1, 1)

    def test_span06_multiple_errors_throughout(self):
        parse_result = squirrel_parse_pt(
            grammar_spec='S <- "a" "b" "c" ;',
            top_rule_name='S',
            input='aXbYc',
        )
        result = get_spanning_result(parse_result)

        assert result.len == 5, "Should span entire input"

        errors = collect_errors(result)
        assert len(errors) == 2, "Should have 2 syntax errors"

    def test_span07_recovery_with_deletion(self):
        parse_result = squirrel_parse_pt(
            grammar_spec='S <- "a" "b" "c" ;',
            top_rule_name='S',
            input='ab',
        )
        result = get_spanning_result(parse_result)

        assert result.len == 2, "Should span full input (no trailing capture here)"
        assert not isinstance(result, SyntaxError)

    def test_span08_first_alternative_with_trailing(self):
        parse_result = squirrel_parse_pt(
            grammar_spec='S <- "a" "b" "c" / "a" ;',
            top_rule_name='S',
            input='abcX',
        )
        result = get_spanning_result(parse_result)

        assert result.len == 4, "Should span entire input"
        assert has_syntax_error(result), "Should capture X as error"

    def test_span09_left_recursion_with_trailing(self):
        parse_result = squirrel_parse_pt(
            grammar_spec='E <- E "+" "n" / "n" ;',
            top_rule_name='E',
            input='n+nX',
        )
        result = get_spanning_result(parse_result)

        assert result.len == 4, "Should span entire input"
        assert has_syntax_error(result)

    def test_span10_repetition_with_trailing(self):
        parse_result = squirrel_parse_pt(
            grammar_spec='S <- "a"+ ;',
            top_rule_name='S',
            input='aaaX',
        )
        result = get_spanning_result(parse_result)

        assert result.len == 4, "Should span entire input"
        assert has_syntax_error(result)

    def test_span11_nested_rules_with_trailing(self):
        parse_result = squirrel_parse_pt(
            grammar_spec='''
                S <- A ";" ;
                A <- "a" "b" ;
            ''',
            top_rule_name='S',
            input='ab;X',
        )
        result = get_spanning_result(parse_result)

        assert result.len == 4, "Should span entire input"

    def test_span12_zero_or_more_with_trailing(self):
        parse_result = squirrel_parse_pt(
            grammar_spec='S <- "a"* ;',
            top_rule_name='S',
            input='XYZ',
        )
        result = get_spanning_result(parse_result)

        assert result.len == 3, "Should span entire input"
        assert not isinstance(result, SyntaxError)
        assert has_syntax_error(result)

    def test_span13_optional_with_trailing(self):
        parse_result = squirrel_parse_pt(
            grammar_spec='S <- "a"? ;',
            top_rule_name='S',
            input='XYZ',
        )
        result = get_spanning_result(parse_result)

        assert result.len == 3, "Should span entire input"
        assert has_syntax_error(result)

    def test_span14_followed_by_success_with_trailing(self):
        parse_result = squirrel_parse_pt(
            grammar_spec='S <- &"a" "a" "b" ;',
            top_rule_name='S',
            input='abX',
        )
        result = get_spanning_result(parse_result)

        assert result.len == 3, "Should span entire input"
        assert has_trailing_error(result, 2, 1)

    def test_span15_not_followed_by_failure_total(self):
        parse_result = squirrel_parse_pt(
            grammar_spec='S <- !"x" "y" ;',
            top_rule_name='S',
            input='xz',
        )
        result = get_spanning_result(parse_result)

        assert isinstance(result, SyntaxError), "Should be total failure"
        assert result.len == 2, "Should span entire input"

    def test_span16_not_followed_by_success_with_trailing(self):
        parse_result = squirrel_parse_pt(
            grammar_spec='S <- "b" "c"? ;',
            top_rule_name='S',
            input='bX',
        )
        result = get_spanning_result(parse_result)

        assert result.len == 2, "Should span entire input"
        assert has_trailing_error(result, 1, 1)

    def test_span17_invariant_never_null(self):
        test_cases = [
            ('S <- "a" ;', 'a'),
            ('S <- "a" ;', 'b'),
            ('S <- "a" ;', ''),
            ('S <- "a" "b" ;', 'ab'),
            ('S <- "a" "b" ;', 'aXb'),
            ('S <- "a" / "b" ;', 'c'),
        ]

        for grammar_spec, input_str in test_cases:
            parse_result = squirrel_parse_pt(
                grammar_spec=grammar_spec,
                top_rule_name='S',
                input=input_str,
            )
            result = get_spanning_result(parse_result)

            assert result is not None, f"parse() should never return None for input: {input_str}"
            assert result.len == len(input_str), f"Result should span entire input for: {input_str}"

    def test_span18_long_input_with_single_trailing_error(self):
        input_str = "abcdefghijklmnopqrstuvwxyzX"
        parse_result = squirrel_parse_pt(
            grammar_spec='S <- "a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l" "m" "n" "o" "p" "q" "r" "s" "t" "u" "v" "w" "x" "y" "z" ;',
            top_rule_name='S',
            input=input_str,
        )
        result = get_spanning_result(parse_result)

        assert result.len == 27, "Should span entire input"
        assert has_trailing_error(result, 26, 1)

    def test_span19_complex_grammar_with_errors(self):
        parse_result = squirrel_parse_pt(
            grammar_spec='''
                S <- E ";" ;
                E <- E "+" T / T ;
                T <- "n" ;
            ''',
            top_rule_name='S',
            input='n+Xn;Y',
        )
        result = get_spanning_result(parse_result)

        assert result.len == 6, "Should span entire input"

        errors = collect_errors(result)
        assert len(errors) >= 2, "Should capture errors"

    def test_span20_recovery_preserves_matched_content(self):
        parse_result = squirrel_parse_pt(
            grammar_spec='S <- "hello" " " "world" ;',
            top_rule_name='S',
            input='hello X world',
        )
        result = get_spanning_result(parse_result)

        assert result.len == 13, "Should span entire input"
        assert not isinstance(result, SyntaxError)
        assert has_syntax_error(result), "Should have error for skipped X"
