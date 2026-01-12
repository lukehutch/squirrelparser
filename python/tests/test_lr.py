# ===========================================================================
# SECTION 9: LEFT RECURSION (10 tests)
# ===========================================================================

from tests.test_utils import run_test_parse


LR1 = '''
    S <- S "+" T / T ;
    T <- [0-9]+ ;
'''

EXPR = '''
    S <- E ;
    E <- E "+" T / T ;
    T <- T "*" F / F ;
    F <- "(" E ")" / [0-9] ;
'''


def test_lr01_simple():
    result = run_test_parse(LR1, '1+2+3')
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"


def test_lr02_single():
    result = run_test_parse(LR1, '42')
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"


def test_lr03_chain_5():
    result = run_test_parse(LR1, '+'.join(['1'] * 5))
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"


def test_lr04_chain_10():
    result = run_test_parse(LR1, '+'.join(['1'] * 10))
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"


def test_lr05_with_mult():
    result = run_test_parse(EXPR, '1+2*3')
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"


def test_lr06_parens():
    result = run_test_parse(EXPR, '(1+2)*3')
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"


def test_lr07_nested_parens():
    result = run_test_parse(EXPR, '((1+2))')
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"


def test_lr08_direct():
    result = run_test_parse(
        'S <- S "x" / "y" ;',
        'yxxx'
    )
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"


def test_lr09_multi_digit():
    result = run_test_parse(LR1, '12+345+6789')
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"


def test_lr10_complex_expr():
    result = run_test_parse(EXPR, '1+2*3+4*5')
    assert result.ok, "should succeed"
    assert result.error_count == 0, "should have 0 errors"
