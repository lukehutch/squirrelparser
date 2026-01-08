"""
SECTION 11: ALL SIX FIXES WITH MONOTONIC INVARIANT (20 tests)
Verify all six error recovery fixes work correctly with the monotonic
invariant fix applied.
"""
from typing import cast, Mapping
from squirrelparser import Str, CharRange, Seq, First, OneOrMore, Optional, Ref, Parser, Clause
from tests.test_utils import parse, count_deletions


# --- FIX #1: isComplete propagation with LR ---
expr_lr = {
    'E': First(
        Seq(Ref('E'), Str('+'), Ref('N')),
        Ref('N')
    ),
    'N': OneOrMore(CharRange('0', '9')),
}


def test_f1_lr_clean() -> None:
    """F1-LR-clean"""
    ok, err, skip = parse(expr_lr, '1+2+3', 'E')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_f1_lr_recovery() -> None:
    """F1-LR-recovery"""
    ok, err, skip = parse(expr_lr, '1+Z2+3', 'E')
    assert ok, 'should succeed'
    assert err >= 1, 'should have at least 1 error'
    assert any('Z' in s for s in skip), 'should skip Z'


# --- FIX #2: Discovery-only incomplete marking with LR ---
rep_lr = {
    'E': First(
        Seq(Ref('E'), Str('+'), Ref('T')),
        Ref('T')
    ),
    'T': OneOrMore(Str('x')),
}


def test_f2_lr_clean() -> None:
    """F2-LR-clean"""
    ok, err, skip = parse(rep_lr, 'x+xx+xxx', 'E')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_f2_lr_error() -> None:
    """F2-LR-error"""
    ok, err, skip = parse(rep_lr, 'x+xZx+xxx', 'E')
    assert ok, 'should succeed'
    assert err >= 1, 'should have at least 1 error'


# --- FIX #3: Cache isolation with LR ---
cache_lr = {
    'S': Seq(Str('['), Ref('E'), Str(']')),
    'E': First(
        Seq(Ref('E'), Str('+'), Ref('N')),
        Ref('N')
    ),
    'N': OneOrMore(Str('x')),
}


def test_f3_lr_clean() -> None:
    """F3-LR-clean"""
    ok, err, skip = parse(cache_lr, '[x+xx]')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_f3_lr_recovery() -> None:
    """F3-LR-recovery"""
    ok, err, skip = parse(cache_lr, '[x+Zxx]')
    assert ok, 'should succeed'
    assert err >= 1, 'should have at least 1 error'


# --- FIX #4: Pre-element bound check with LR ---
bound_lr = {
    'S': OneOrMore(Seq(Str('['), Ref('E'), Str(']'))),
    'E': First(
        Seq(Ref('E'), Str('+'), Ref('N')),
        Ref('N')
    ),
    'N': OneOrMore(CharRange('0', '9')),
}


def test_f4_lr_clean() -> None:
    """F4-LR-clean"""
    ok, err, skip = parse(bound_lr, '[1+2][3+4]')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_f4_lr_recovery() -> None:
    """F4-LR-recovery"""
    ok, err, skip = parse(bound_lr, '[1+Z2][3+4]')
    assert ok, 'should succeed'
    assert err >= 1, 'should have at least 1 error'


# --- FIX #5: Optional fallback incomplete with LR ---
opt_lr = {
    'S': Seq(Ref('E'), Optional(Str(';'))),
    'E': First(
        Seq(Ref('E'), Str('+'), Ref('N')),
        Ref('N')
    ),
    'N': OneOrMore(CharRange('0', '9')),
}


def test_f5_lr_with_opt() -> None:
    """F5-LR-with-opt"""
    ok, err, skip = parse(opt_lr, '1+2+3;')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_f5_lr_without_opt() -> None:
    """F5-LR-without-opt"""
    ok, err, skip = parse(opt_lr, '1+2+3')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


# --- FIX #6: Conservative EOF recovery with LR ---
eof_lr = {
    'S': Seq(Ref('E'), Str('!')),
    'E': First(
        Seq(Ref('E'), Str('+'), Ref('N')),
        Ref('N')
    ),
    'N': OneOrMore(CharRange('0', '9')),
}


def test_f6_lr_clean() -> None:
    """F6-LR-clean"""
    ok, err, skip = parse(eof_lr, '1+2+3!')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_f6_lr_deletion() -> None:
    """F6-LR-deletion"""
    parser = Parser(rules=cast(Mapping[str, Clause], eof_lr), input_str='1+2+3')
    result, _ = parser.parse('S')
    assert result is not None and not result.is_mismatch, 'should succeed with recovery'
    assert count_deletions(result) >= 1, 'should have at least 1 deletion'


# --- Combined: Expression grammar with all features ---
full_grammar = {
    'Program': OneOrMore(Seq(Ref('Expr'), Optional(Str(';')))),
    'Expr': First(
        Seq(Ref('Expr'), Str('+'), Ref('Term')),
        Ref('Term')
    ),
    'Term': First(
        Seq(Ref('Term'), Str('*'), Ref('Factor')),
        Ref('Factor')
    ),
    'Factor': First(
        Seq(Str('('), Ref('Expr'), Str(')')),
        Ref('Num')
    ),
    'Num': OneOrMore(CharRange('0', '9')),
}


def test_full_clean_simple() -> None:
    """FULL-clean-simple"""
    ok, err, skip = parse(full_grammar, '1+2*3', 'Program')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_full_clean_semi() -> None:
    """FULL-clean-semi"""
    ok, err, skip = parse(full_grammar, '1+2;3*4', 'Program')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_full_clean_nested() -> None:
    """FULL-clean-nested"""
    ok, err, skip = parse(full_grammar, '(1+2)*(3+4)', 'Program')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_full_recovery_skip() -> None:
    """FULL-recovery-skip"""
    ok, err, skip = parse(full_grammar, '1+Z2*3', 'Program')
    assert ok, 'should succeed'
    assert err >= 1, 'should have at least 1 error'


# --- Deep left recursion ---
deep_lr = {
    'E': First(
        Seq(Ref('E'), Str('+'), Ref('N')),
        Ref('N')
    ),
    'N': CharRange('0', '9'),
}


def test_deep_lr_clean() -> None:
    """DEEP-LR-clean"""
    ok, err, skip = parse(deep_lr, '1+2+3+4+5+6+7+8+9', 'E')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_deep_lr_recovery() -> None:
    """DEEP-LR-recovery"""
    ok, err, skip = parse(deep_lr, '1+2+Z3+4+5', 'E')
    assert ok, 'should succeed'
    assert err >= 1, 'should have at least 1 error'
