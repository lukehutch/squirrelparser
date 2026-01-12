"""
PERFORMANCE & EDGE CASE TESTS

These tests verify performance characteristics and edge cases.
"""

import pytest
import time

from tests.test_utils import test_parse
from squirrelparser.squirrel_parse import squirrel_parse_pt
from squirrelparser.parser import Parser
from squirrelparser.match_result import SyntaxError


class TestPerformanceTests:
    def test_perf_01_very_long_input(self):
        # 10,000 character input should parse in reasonable time
        input_str = 'x' * 10000
        start_time = time.time()
        r = test_parse('S <- "x"+ ;', input_str)
        elapsed = (time.time() - start_time) * 1000  # Convert to ms

        assert r.ok, "should succeed"
        assert r.error_count == 0, "should have 0 errors"
        assert elapsed < 1000, f"should complete in less than 1 second (was {elapsed}ms)"

    def test_perf_02_deep_nesting(self):
        # Deep nesting test (reduced from 50 to 30 for Python's recursion limit)
        import sys
        old_limit = sys.getrecursionlimit()
        sys.setrecursionlimit(3000)  # Increase limit for this test
        try:
            inner = '"x"'
            for _ in range(50):
                inner = f'({inner} "y")'
            grammar_spec = f'S <- {inner} ;'
            input_str = 'x' + 'y' * 50

            r = test_parse(grammar_spec, input_str)
            assert r.ok, "should handle 50 levels of nesting"
        finally:
            sys.setrecursionlimit(old_limit)

    def test_perf_03_wide_first(self):
        # First with 50 alternatives (using padded numbers to avoid prefix issues)
        alternatives = ' / '.join(f'"opt_{i:03d}"' for i in range(50))
        grammar_spec = f'S <- {alternatives} ;'

        r = test_parse(grammar_spec, 'opt_049')
        assert r.ok, "should try all 50 alternatives"

    def test_perf_04_many_repetitions(self):
        # 1000 iterations of OneOrMore
        input_str = 'x' * 1000
        r = test_parse('S <- "x"+ ;', input_str)
        assert r.ok, "should handle 1000 repetitions"

    def test_perf_05_many_errors(self):
        # 500 errors in input
        input_str = ''.join('Xx' for _ in range(500))
        r = test_parse('S <- "x"+ ;', input_str)
        assert r.ok, "should succeed"
        assert r.error_count == 500, "should count all 500 errors"

    def test_perf_06_lr_expansion_depth(self):
        # LR with 100 expansions
        input_str = ''.join('+n' for _ in range(100))[1:]  # n+n+n+...
        r = test_parse(
            'E <- E "+" "n" / "n" ;',
            input_str,
            'E',
        )
        assert r.ok, "should handle 100 LR expansions"

    def test_perf_07_cache_efficiency(self):
        # Same clause at many positions - cache should help
        input_str = 'x' * 100
        grammar = '''
            S <- X+ ;
            X <- "x" ;
        '''
        r = test_parse(grammar, input_str)
        assert r.ok, "should succeed (cache makes this efficient)"


class TestEdgeCaseTests:
    def test_edge_01_empty_input(self):
        # Various grammars with empty input
        zm = test_parse('S <- "x"* ;', '')
        assert zm.ok, "ZeroOrMore should succeed on empty"

        om = test_parse('S <- "x"+ ;', '')
        assert not om.ok, "OneOrMore should fail on empty"

        opt = test_parse('S <- "x"? ;', '')
        assert opt.ok, "Optional should succeed on empty"

        # Empty sequence (no elements) matches empty input
        parse_result = squirrel_parse_pt(
            grammar_spec='S <- ""? ;',  # Optional empty string
            top_rule_name='S',
            input='',
        )
        assert not parse_result.root.is_mismatch, "empty pattern should succeed on empty"

    def test_edge_02_input_with_only_errors(self):
        # Input is all garbage
        r = test_parse('S <- "abc" ;', 'XYZ')
        assert not r.ok, "should fail (no valid content)"

    def test_edge_03_grammar_with_only_optional_zeromore(self):
        # Grammar that accepts empty: Seq([ZeroOrMore(...), Optional(...)])
        r = test_parse('S <- "x"* "y"? ;', '')
        assert r.ok, "should succeed (both match empty)"
        assert r.error_count == 0, "should have 0 errors"

    def test_edge_04_single_char_terminals(self):
        # All single-character terminals
        r = test_parse('S <- "a" "b" "c" ;', 'abc')
        assert r.ok, "should succeed"
        assert r.error_count == 0, "should have 0 errors"

    def test_edge_05_very_long_terminal(self):
        # Multi-hundred-char terminal
        long_str = 'x' * 500
        r = test_parse(f'S <- "{long_str}" ;', long_str)
        assert r.ok, "should match very long terminal"

    def test_edge_06_unicode_handling(self):
        # Unicode characters in terminals and input
        r = test_parse(
            'S <- "\u3053\u3093\u306b\u3061\u306f" "\u4e16\u754c" ;',
            '\u3053\u3093\u306b\u3061\u306f\u4e16\u754c',  # "Hello" "World" in Japanese
        )
        assert r.ok, "should handle Unicode"
        assert r.error_count == 0, "should have 0 errors"

    def test_edge_07_mixed_unicode_and_ascii(self):
        # Mix of Unicode and ASCII with errors
        r = test_parse(
            'S <- "hello" "\u4e16\u754c" ;',
            'helloX\u4e16\u754c',
        )
        assert r.ok, "should succeed"
        assert r.error_count == 1, "should have 1 error"
        assert 'X' in r.skipped_strings, "should skip X"

    def test_edge_08_newlines_and_whitespace(self):
        # Newlines and whitespace as errors
        r = test_parse('S <- "a" "b" ;', 'a\n\tb')
        assert r.ok, "should succeed"
        assert r.error_count == 1, "should have 1 error (newline+tab)"

    def test_edge_09_eof_at_various_positions(self):
        # EOF at different points in grammar
        cases = [
            ('ab', 2),  # EOF after full match
            ('a', 1),   # EOF after partial match
            ('', 0),    # EOF at start
        ]

        for input_str, _ in cases:
            parse_result = squirrel_parse_pt(
                grammar_spec='S <- "a" "b" ;',
                top_rule_name='S',
                input=input_str,
            )
            result = parse_result.root
            assert not isinstance(result, SyntaxError) or input_str == '', \
                f'result should exist or input empty for "{input_str}"'

    def test_edge_10_recovery_with_moderate_skip(self):
        # Recovery with moderate skip distance
        r = test_parse(
            'S <- "a" "b" "c" ;',
            'aXXXXXXXXXbc',
        )
        assert r.ok, "should succeed (skip to find b)"
        assert r.error_count == 1, "should have 1 error (skip region)"
        assert len(r.skipped_strings[0]) > 5, "should skip multiple chars"

    def test_edge_11_alternating_success_failure(self):
        # Pattern that alternates between success and failure
        r = test_parse(
            'S <- ("a" "b")+ ;',
            'abXabYabZab',
        )
        assert r.ok, "should succeed"
        assert r.error_count == 3, "should have 3 errors"

    def test_edge_12_boundary_at_every_position(self):
        # Multiple sequences with delimiters
        r = test_parse(
            'S <- "a"+ "," "b"+ "," "c"+ ;',
            'aaa,bbb,ccc',
        )
        assert r.ok, "should succeed (multiple boundaries)"

    def test_edge_13_no_grammar_rules(self):
        # Empty grammar (edge case that should fail gracefully)
        with pytest.raises(ValueError):
            Parser(rules={}, top_rule_name='S', input='x').parse()

    def test_edge_14_circular_ref_with_base_case(self):
        # A -> A | 'x' (left-recursive with base case)
        # Should work correctly with LR detection
        parse_result = squirrel_parse_pt(
            grammar_spec='A <- A "y" / "x" ;',
            top_rule_name='A',
            input='xy',
        )
        result = parse_result.root
        assert not result.is_mismatch, "left-recursive with base case should work"

    def test_edge_15_all_printable_ascii(self):
        # Test all printable ASCII characters
        ascii_chars = ''.join(chr(i) for i in range(32, 127))

        # Escape special characters for the grammar spec string literal
        escaped = (ascii_chars
            .replace('\\', '\\\\')
            .replace('"', '\\"')
            .replace('\n', '\\n')
            .replace('\r', '\\r')
            .replace('\t', '\\t'))

        r = test_parse(f'S <- "{escaped}" ;', ascii_chars)
        assert r.ok, "should handle all printable ASCII"
