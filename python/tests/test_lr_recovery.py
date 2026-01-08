"""Left Recursion Error Recovery Tests"""
from typing import cast, Mapping
from squirrelparser import Str, Seq, First, Ref, Parser, Clause
from tests.test_utils import parse


# directLR grammar for error recovery tests
direct_lr = {
    'S': Ref('E'),
    'E': First(
        Seq(Ref('E'), Str('+n')),
        Str('n')
    ),
}

# precedenceLR grammar for error recovery tests
precedence_lr = {
    'S': Ref('E'),
    'E': First(
        Seq(Ref('E'), Str('+'), Ref('T')),
        Seq(Ref('E'), Str('-'), Ref('T')),
        Ref('T')
    ),
    'T': First(
        Seq(Ref('T'), Str('*'), Ref('F')),
        Seq(Ref('T'), Str('/'), Ref('F')),
        Ref('F')
    ),
    'F': First(
        Seq(Str('('), Ref('E'), Str(')')),
        Str('n')
    ),
}


def test_lr_recovery_01_leading_error() -> None:
    """LR-Recovery-01-leading-error"""
    # Input '+n+n+n+' starts with '+' which is invalid (need 'n' first)
    # and ends with '+' which is also invalid (need 'n' after)
    ok, err, _ = parse(direct_lr, '+n+n+n+')
    # This should fail because we can't recover a valid parse
    # The leading '+' prevents any initial 'n' match
    assert not ok, 'should fail (leading + is unrecoverable)'


def test_lr_recovery_02_internal_error() -> None:
    """LR-Recovery-02-internal-error"""
    # Input 'n+Xn+n' has garbage 'X' between + and n
    # With spanning invariant, parser recovers from internal errors
    ok, err, skip = parse(direct_lr, 'n+Xn+n')
    assert ok, 'should recover from internal error'
    assert err == 1, 'should have 1 error (X)'
    assert '+Xn+n' in skip or 'X' in str(skip), 'should skip the problem region'


def test_lr_recovery_03_trailing_junk() -> None:
    """LR-Recovery-03-trailing-junk"""
    # Input 'n+n+nXXX' has trailing garbage
    # With spanning invariant, parser recovers from trailing errors
    ok, err, skip = parse(direct_lr, 'n+n+nXXX')
    assert ok, 'should recover from trailing garbage'
    assert err == 1, 'should have 1 error (XXX)'
    assert 'XXX' in skip, 'should skip trailing garbage'


def test_lr_recovery_04_missing_operand() -> None:
    """LR-Recovery-04-missing-operand"""
    # Input 'n+*n' has missing operand between + and *
    # Parser recovers by skipping the extra '+' to parse as 'n*n'
    ok, err, skip = parse(precedence_lr, 'n+*n')
    assert ok, 'should recover by skipping +'
    assert err == 1, 'one error: skip +'
    assert skip == ['+']


def test_lr_recovery_05_double_op() -> None:
    """LR-Recovery-05-double-op"""
    # Input 'n++n' has double operator
    # Parser recovers by skipping the extra '+' to parse as 'n+n'
    ok, err, skip = parse(precedence_lr, 'n++n')
    assert ok, 'should recover by skipping +'
    assert err == 1, 'one error: skip +'
    assert skip == ['+']


def test_lr_recovery_06_unclosed_paren() -> None:
    """LR-Recovery-06-unclosed-paren"""
    # Input '(n+n' has unclosed paren
    parser = Parser(
        rules=cast(Mapping[str, Clause], precedence_lr),
        input_str='(n+n',
    )
    result, used_recovery = parser.parse('S')
    # With recovery, should insert missing ')'
    assert result is not None and not result.is_mismatch, 'should succeed with recovery'


def test_lr_recovery_07_extra_close_paren() -> None:
    """LR-Recovery-07-extra-close-paren"""
    # Input 'n+n)' has extra close paren
    # With spanning invariant, parser recovers from trailing garbage
    ok, err, skip = parse(precedence_lr, 'n+n)')
    assert ok, 'should recover from extra close paren'
    assert err == 1, 'should have 1 error'
    assert ')' in skip, 'should skip the extra paren'


def test_mask_01_error_at_t_level_after_star() -> None:
    """MASK-01-error-at-T-level-after-star"""
    # F1-LR-05 case: T -> T*F | F. Input "n+n*Xn".
    # Error is at 'X'.
    # Current behavior: 2 errors (recovery at E level).
    # Optimal behavior (future goal): 1 error (recovery at F level).
    # This is a known limitation: Ref can mask deeper recovery opportunities.
    grammar = {
        'E': First(
            Seq(Ref('E'), Str('+'), Ref('T')),
            Ref('T')
        ),
        'T': First(
            Seq(Ref('T'), Str('*'), Ref('F')),
            Ref('F')
        ),
        'F': First(
            Seq(Str('('), Ref('E'), Str(')')),
            Str('n')
        ),
    }
    ok, err, skip = parse(grammar, 'n+n*Xn', 'E')
    assert ok, 'should recover'
    assert err == 2, 'current: 2 errors (suboptimal, but correct)'
    assert any('*' in s or 'X' in s for s in skip), 'should skip * and/or X'
