"""
SECTION 12: LINEARITY TESTS (10 tests)

Verify O(N) complexity where N is input length.
Work should scale linearly with input size.
"""

import pytest
from typing import Callable
from dataclasses import dataclass

from squirrelparser.squirrel_parse import squirrel_parse_pt
from squirrelparser.parser_stats import enable_parser_stats, disable_parser_stats


@dataclass
class LinearityResult:
    """Result of linearity test."""
    passed: bool
    ratio_change: float


@pytest.fixture(scope="module", autouse=True)
def setup_parser_stats():
    """Enable stats tracking for linearity tests."""
    enable_parser_stats()
    yield
    disable_parser_stats()


def check_linearity(
    grammar_spec: str,
    top_rule: str,
    make_input: Callable[[int], str],
    sizes: list[int],
) -> LinearityResult:
    """Check linearity helper: returns (passed, ratio_change) where ratio_change < 2 means linear."""
    global parser_stats
    from squirrelparser import parser_stats as ps

    results: list[tuple[int, int, float]] = []

    for size in sizes:
        ps.parser_stats.reset()
        input_str = make_input(size)
        parse_result = squirrel_parse_pt(
            grammar_spec=grammar_spec,
            top_rule_name=top_rule,
            input=input_str,
        )
        result = parse_result.root

        work = ps.parser_stats.total_work
        success = not result.is_mismatch and result.len == len(input_str)
        ratio = work / size if size > 0 else 0.0

        results.append((size, work, ratio))

        if not success:
            return LinearityResult(passed=False, ratio_change=float('inf'))

    # Check ratio doesn't increase significantly
    ratios = [r[2] for r in results]
    if not ratios or ratios[0] == 0:
        return LinearityResult(passed=False, ratio_change=float('inf'))

    ratio_change = ratios[-1] / ratios[0]
    return LinearityResult(passed=ratio_change <= 2.0, ratio_change=ratio_change)


def test_linear_01_simple_rep():
    result = check_linearity(
        'S <- "x"+ ;',
        'S',
        lambda size: 'x' * size,
        [10, 50, 100, 500],
    )
    assert result.passed, f"simple repetition should be linear (ratio change: {result.ratio_change})"


def test_linear_02_direct_lr():
    grammar = '''
        E <- E "+" N / N ;
        N <- [0-9] ;
    '''
    result = check_linearity(
        grammar,
        'E',
        lambda size: '+'.join(str(i % 10) for i in range(size + 1)),
        [5, 10, 20, 50],
    )
    assert result.passed, f"direct LR should be linear (ratio change: {result.ratio_change})"


def test_linear_03_indirect_lr():
    grammar = '''
        A <- B / "x" ;
        B <- A "y" / A "x" ;
    '''
    def make_input(size: int) -> str:
        s = 'x'
        for _ in range(size // 2):
            s += 'xy'
        return s[:max(1, size)]

    result = check_linearity(
        grammar,
        'A',
        make_input,
        [5, 10, 20, 50],
    )
    assert result.passed, f"indirect LR should be linear (ratio change: {result.ratio_change})"


def test_linear_04_interwoven_lr():
    grammar = '''
        L <- P ".x" / "x" ;
        P <- P "(n)" / L ;
    '''
    def make_input(size: int) -> str:
        parts = ['x']
        for i in range(size):
            parts.append('.x' if i % 3 == 0 else '(n)')
        return ''.join(parts)

    result = check_linearity(
        grammar,
        'L',
        make_input,
        [5, 10, 20, 50],
    )
    assert result.passed, f"interwoven LR should be linear (ratio change: {result.ratio_change})"


def test_linear_05_deep_nesting():
    grammar = '''
        E <- "(" E ")" / "x" ;
    '''
    result = check_linearity(
        grammar,
        'E',
        lambda size: '(' * size + 'x' + ')' * size,
        [5, 10, 20, 50],
    )
    assert result.passed, f"deep nesting should be linear (ratio change: {result.ratio_change})"


def test_linear_06_precedence():
    grammar = '''
        E <- E "+" T / T ;
        T <- T "*" F / F ;
        F <- "(" E ")" / N ;
        N <- [0-9] ;
    '''
    def make_input(size: int) -> str:
        parts: list[str] = []
        for i in range(size):
            parts.append(str(i % 10))
            if i < size - 1:
                parts.append('+' if i % 2 == 0 else '*')
        return ''.join(parts)

    result = check_linearity(
        grammar,
        'E',
        make_input,
        [5, 10, 20, 50],
    )
    assert result.passed, f"precedence grammar should be linear (ratio change: {result.ratio_change})"


def test_linear_07_ambiguous():
    grammar = '''
        E <- E "+" E / N ;
        N <- [0-9] ;
    '''
    result = check_linearity(
        grammar,
        'E',
        lambda size: '+'.join(str(i % 10) for i in range(size + 1)),
        [3, 5, 7, 10],  # Smaller sizes for ambiguous grammar
    )
    assert result.passed, f"ambiguous grammar should be linear (ratio change: {result.ratio_change})"


def test_linear_08_long_input():
    grammar = '''
        S <- ("a" "b" "c")+ ;
    '''
    result = check_linearity(
        grammar,
        'S',
        lambda size: 'abc' * size,
        [100, 500, 1000, 2000],
    )
    assert result.passed, f"long input should be linear (ratio change: {result.ratio_change})"


def test_linear_09_long_lr():
    grammar = '''
        E <- E "+" N / N ;
        N <- [0-9] ;
    '''
    result = check_linearity(
        grammar,
        'E',
        lambda size: '+'.join(str(i % 10) for i in range(size)),
        [50, 100, 200, 500],
    )
    assert result.passed, f"long LR input should be linear (ratio change: {result.ratio_change})"


def test_linear_10_recovery():
    grammar = '''
        S <- ("(" "x"+ ")")+ ;
    '''
    def make_input(size: int) -> str:
        parts: list[str] = []
        for i in range(size):
            if i > 0 and i % 10 == 0:
                parts.append('(xZx)')  # Error
            else:
                parts.append('(xx)')
        return ''.join(parts)

    result = check_linearity(
        grammar,
        'S',
        make_input,
        [10, 20, 50, 100],
    )
    assert result.passed, f"recovery should be linear (ratio change: {result.ratio_change})"
