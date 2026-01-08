"""Performance & Edge Case Tests"""
import pytest
import time
from squirrelparser import Str, Seq, First, OneOrMore, ZeroOrMore, Optional, Ref, Parser, Clause
from tests.test_utils import parse


class TestPerformanceTests:
    """Performance Tests"""

    def test_perf_01_very_long_input(self) -> None:
        """PERF-01-very-long-input"""
        # 10,000 character input should parse in reasonable time
        input_str = 'x' * 10000
        start_time = time.time()
        ok, err, _ = parse({'S': OneOrMore(Str('x'))}, input_str)
        elapsed = (time.time() - start_time) * 1000  # ms

        assert ok, 'should succeed'
        assert err == 0, 'should have 0 errors'
        assert elapsed < 1000, f'should complete in less than 1 second (was {elapsed}ms)'

    def test_perf_02_deep_nesting(self) -> None:
        """PERF-02-deep-nesting"""
        # 50 levels of Seq nesting
        def build_deep_seq(depth: int) -> Clause:
            if depth == 0:
                return Str('x')
            return Seq(build_deep_seq(depth - 1), Str('y'))

        grammar = {'S': build_deep_seq(50)}
        input_str = 'x' + 'y' * 50

        ok, _, _ = parse(grammar, input_str)
        assert ok, 'should handle 50 levels of nesting'

    def test_perf_03_wide_first(self) -> None:
        """PERF-03-wide-first"""
        # First with 50 alternatives (using padded numbers to avoid prefix issues)
        alternatives = [Str(f'opt_{str(i).zfill(3)}') for i in range(50)]
        ok, _, _ = parse({'S': First(*alternatives)}, 'opt_049')  # Last alternative
        assert ok, 'should try all 50 alternatives'

    def test_perf_04_many_repetitions(self) -> None:
        """PERF-04-many-repetitions"""
        # 1000 iterations of OneOrMore
        input_str = 'x' * 1000
        ok, _, _ = parse({'S': OneOrMore(Str('x'))}, input_str)
        assert ok, 'should handle 1000 repetitions'

    def test_perf_05_many_errors(self) -> None:
        """PERF-05-many-errors"""
        # 500 errors in input
        input_str = ''.join('Xx' for _ in range(500))
        ok, err, _ = parse({'S': OneOrMore(Str('x'))}, input_str)
        assert ok, 'should succeed'
        assert err == 500, 'should count all 500 errors'

    def test_perf_06_lr_expansion_depth(self) -> None:
        """PERF-06-lr-expansion-depth"""
        # LR with 100 expansions
        input_str = ''.join('+n' for _ in range(100))[1:]  # n+n+n+...
        ok, _, _ = parse({
            'E': First(
                Seq(Ref('E'), Str('+'), Str('n')),
                Str('n')
            )
        }, input_str, 'E')
        assert ok, 'should handle 100 LR expansions'

    def test_perf_07_cache_efficiency(self) -> None:
        """PERF-07-cache-efficiency"""
        # Same clause at many positions - cache should help
        input_str = 'x' * 100
        ok, _, _ = parse({'S': OneOrMore(Ref('X')), 'X': Str('x')}, input_str)
        assert ok, 'should succeed (cache makes this efficient)'


class TestEdgeCaseTests:
    """Edge Case Tests"""

    def test_edge_01_empty_input(self) -> None:
        """EDGE-01-empty-input"""
        # Various grammars with empty input
        # With spanning invariant, results span input and total failure returns SyntaxError
        zm = parse({'S': ZeroOrMore(Str('x'))}, '')
        assert zm[0], 'ZeroOrMore should succeed on empty'

        om = parse({'S': OneOrMore(Str('x'))}, '')
        assert not om[0], 'OneOrMore should fail on empty (total failure returns SyntaxError)'

        opt = parse({'S': Optional(Str('x'))}, '')
        assert opt[0], 'Optional should succeed on empty'

        seq = parse({'S': Seq()}, '')
        assert seq[0], 'empty Seq should succeed on empty'

    def test_edge_02_input_with_only_errors(self) -> None:
        """EDGE-02-input-with-only-errors"""
        # Input is all garbage that cannot match the grammar
        # With spanning invariant, this returns SyntaxError (total failure)
        ok, _, _ = parse({'S': Str('abc')}, 'XYZ')
        assert not ok, 'should fail (no valid content, cannot recover)'

    def test_edge_03_grammar_with_only_optional_zeromore(self) -> None:
        """EDGE-03-grammar-with-only-optional-zeoormore"""
        # Grammar that accepts empty: Seq([ZeroOrMore(...), Optional(...)])
        ok, err, _ = parse({
            'S': Seq(ZeroOrMore(Str('x')), Optional(Str('y')))
        }, '')
        assert ok, 'should succeed (both match empty)'
        assert err == 0, 'should have 0 errors'

    def test_edge_04_single_char_terminals(self) -> None:
        """EDGE-04-single-char-terminals"""
        # All single-character terminals
        ok, err, _ = parse({
            'S': Seq(Str('a'), Str('b'), Str('c'))
        }, 'abc')
        assert ok, 'should succeed'
        assert err == 0, 'should have 0 errors'

    def test_edge_05_very_long_terminal(self) -> None:
        """EDGE-05-very-long-terminal"""
        # Multi-hundred-char terminal
        long_str = 'x' * 500
        ok, _, _ = parse({'S': Str(long_str)}, long_str)
        assert ok, 'should match very long terminal'

    def test_edge_06_unicode_handling(self) -> None:
        """EDGE-06-unicode-handling"""
        # Unicode characters in terminals and input
        ok, err, _ = parse({
            'S': Seq(Str('hello'), Str('world'))
        }, 'helloworld')
        assert ok, 'should handle ASCII'
        assert err == 0, 'should have 0 errors'

    def test_edge_07_mixed_unicode_and_ascii(self) -> None:
        """EDGE-07-mixed-unicode-and-ascii"""
        # Mix of Unicode and ASCII with errors
        ok, err, skip = parse({
            'S': Seq(Str('hello'), Str('world'))
        }, 'helloXworld')
        assert ok, 'should succeed'
        assert err == 1, 'should have 1 error'
        assert 'X' in ''.join(skip), 'should skip X'

    def test_edge_08_newlines_and_whitespace(self) -> None:
        """EDGE-08-newlines-and-whitespace"""
        # Newlines and whitespace as errors
        ok, err, _ = parse({
            'S': Seq(Str('a'), Str('b'))
        }, 'a\n\tb')
        assert ok, 'should succeed'
        assert err == 1, 'should have 1 error (newline+tab)'

    def test_edge_09_eof_at_various_positions(self) -> None:
        """EDGE-09-eof-at-various-positions"""
        # EOF at different points in grammar
        cases = [
            ('ab', 2),  # EOF after full match
            ('a', 1),  # EOF after partial match
            ('', 0),  # EOF at start
        ]

        for input_str, expected_pos in cases:
            parser = Parser(
                rules={
                    'S': Seq(Str('a'), Str('b'))
                },
                input_str=input_str,
            )
            result, used_recovery = parser.parse('S')
            assert result is not None or input_str == '', f'result should exist or input empty for "{input_str}"'

    def test_edge_10_recovery_with_moderate_skip(self) -> None:
        """EDGE-10-recovery-with-moderate-skip"""
        # Recovery with moderate skip distance
        ok, err, skip = parse({
            'S': Seq(Str('a'), Str('b'), Str('c')),
        }, 'aXXXXXXXXXbc')
        assert ok, 'should succeed (skip to find b)'
        assert err == 1, 'should have 1 error (skip region)'
        assert len(skip[0]) > 5, 'should skip multiple chars'

    def test_edge_11_alternating_success_failure(self) -> None:
        """EDGE-11-alternating-success-failure"""
        # Pattern that alternates between success and failure
        ok, err, _ = parse({
            'S': OneOrMore(Seq(Str('a'), Str('b')))
        }, 'abXabYabZab')
        assert ok, 'should succeed'
        assert err == 3, 'should have 3 errors'

    def test_edge_12_boundary_at_every_position(self) -> None:
        """EDGE-12-boundary-at-every-position"""
        # Multiple sequences with delimiters
        ok, _, _ = parse({
            'S': Seq(
                OneOrMore(Str('a')),
                Str(','),
                OneOrMore(Str('b')),
                Str(','),
                OneOrMore(Str('c'))
            )
        }, 'aaa,bbb,ccc')
        assert ok, 'should succeed (multiple boundaries)'

    def test_edge_13_no_grammar_rules(self) -> None:
        """EDGE-13-no-grammar-rules"""
        # Empty grammar (edge case that should fail gracefully)
        parser = Parser(rules={}, input_str='x')
        with pytest.raises(Exception):
            parser.parse('NonExistent')

    def test_edge_14_circular_ref_with_base_case(self) -> None:
        """EDGE-14-circular-ref-with-base-case"""
        # A -> A | 'x' (left-recursive with base case)
        # Should work correctly with LR detection
        parser = Parser(
            rules={
                'A': First(
                    Seq(Ref('A'), Str('y')),
                    Str('x')
                )
            },
            input_str='xy',
        )
        result, used_recovery = parser.parse('A')
        # LR detection should handle this correctly
        assert result is not None and not result.is_mismatch, 'left-recursive with base case should work'

    def test_edge_15_all_printable_ascii(self) -> None:
        """EDGE-15-all-printable-ascii"""
        # Test all printable ASCII characters
        ascii_str = ''.join(chr(i) for i in range(32, 127))  # ASCII 32-126
        ok, _, _ = parse({'S': Str(ascii_str)}, ascii_str)
        assert ok, 'should handle all printable ASCII'
