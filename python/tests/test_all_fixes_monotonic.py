"""
SECTION 11: ALL SIX FIXES WITH MONOTONIC INVARIANT (20 tests)

Verify all six error recovery fixes work correctly with the monotonic
invariant fix applied.
"""

from tests.test_utils import test_parse, count_deletions
from squirrelparser.squirrel_parse import squirrel_parse_pt

# --- FIX #1: isComplete propagation with LR ---
EXPR_LR = '''
    E <- E "+" N / N ;
    N <- [0-9]+ ;
'''


def test_f1_lr_clean():
    r = test_parse(EXPR_LR, '1+2+3', 'E')
    assert r.ok, "should succeed"
    assert r.error_count == 0, "should have 0 errors"


def test_f1_lr_recovery():
    r = test_parse(EXPR_LR, '1+Z2+3', 'E')
    assert r.ok, "should succeed"
    assert r.error_count >= 1, "should have at least 1 error"
    assert any('Z' in s for s in r.skipped_strings), "should skip Z"


# --- FIX #2: Discovery-only incomplete marking with LR ---
REP_LR = '''
    E <- E "+" T / T ;
    T <- "x"+ ;
'''


def test_f2_lr_clean():
    r = test_parse(REP_LR, 'x+xx+xxx', 'E')
    assert r.ok, "should succeed"
    assert r.error_count == 0, "should have 0 errors"


def test_f2_lr_error():
    r = test_parse(REP_LR, 'x+xZx+xxx', 'E')
    assert r.ok, "should succeed"
    assert r.error_count >= 1, "should have at least 1 error"


# --- FIX #3: Cache isolation with LR ---
CACHE_LR = '''
    S <- "[" E "]" ;
    E <- E "+" N / N ;
    N <- "x"+ ;
'''


def test_f3_lr_clean():
    r = test_parse(CACHE_LR, '[x+xx]')
    assert r.ok, "should succeed"
    assert r.error_count == 0, "should have 0 errors"


def test_f3_lr_recovery():
    r = test_parse(CACHE_LR, '[x+Zxx]')
    assert r.ok, "should succeed"
    assert r.error_count >= 1, "should have at least 1 error"


# --- FIX #4: Pre-element bound check with LR ---
BOUND_LR = '''
    S <- ("[" E "]")+ ;
    E <- E "+" N / N ;
    N <- [0-9]+ ;
'''


def test_f4_lr_clean():
    r = test_parse(BOUND_LR, '[1+2][3+4]')
    assert r.ok, "should succeed"
    assert r.error_count == 0, "should have 0 errors"


def test_f4_lr_recovery():
    r = test_parse(BOUND_LR, '[1+Z2][3+4]')
    assert r.ok, "should succeed"
    assert r.error_count >= 1, "should have at least 1 error"


# --- FIX #5: Optional fallback incomplete with LR ---
OPT_LR = '''
    S <- E ";"? ;
    E <- E "+" N / N ;
    N <- [0-9]+ ;
'''


def test_f5_lr_with_opt():
    r = test_parse(OPT_LR, '1+2+3;')
    assert r.ok, "should succeed"
    assert r.error_count == 0, "should have 0 errors"


def test_f5_lr_without_opt():
    r = test_parse(OPT_LR, '1+2+3')
    assert r.ok, "should succeed"
    assert r.error_count == 0, "should have 0 errors"


# --- FIX #6: Conservative EOF recovery with LR ---
EOF_LR = '''
    S <- E "!" ;
    E <- E "+" N / N ;
    N <- [0-9]+ ;
'''


def test_f6_lr_clean():
    r = test_parse(EOF_LR, '1+2+3!')
    assert r.ok, "should succeed"
    assert r.error_count == 0, "should have 0 errors"


def test_f6_lr_deletion():
    parse_result = squirrel_parse_pt(
        grammar_spec=EOF_LR,
        top_rule_name='S',
        input='1+2+3',
    )
    result = parse_result.root
    assert not result.is_mismatch, "should succeed with recovery"
    assert count_deletions([result]) >= 1, "should have at least 1 deletion"


# --- Combined: Expression grammar with all features ---
FULL_GRAMMAR = '''
    Program <- (Expr ";"?)+ ;
    Expr <- Expr "+" Term / Term ;
    Term <- Term "*" Factor / Factor ;
    Factor <- "(" Expr ")" / Num ;
    Num <- [0-9]+ ;
'''


def test_full_clean_simple():
    r = test_parse(FULL_GRAMMAR, '1+2*3', 'Program')
    assert r.ok, "should succeed"
    assert r.error_count == 0, "should have 0 errors"


def test_full_clean_semi():
    r = test_parse(FULL_GRAMMAR, '1+2;3*4', 'Program')
    assert r.ok, "should succeed"
    assert r.error_count == 0, "should have 0 errors"


def test_full_clean_nested():
    r = test_parse(FULL_GRAMMAR, '(1+2)*(3+4)', 'Program')
    assert r.ok, "should succeed"
    assert r.error_count == 0, "should have 0 errors"


def test_full_recovery_skip():
    r = test_parse(FULL_GRAMMAR, '1+Z2*3', 'Program')
    assert r.ok, "should succeed"
    assert r.error_count >= 1, "should have at least 1 error"


# --- Deep left recursion ---
DEEP_LR = '''
    E <- E "+" N / N ;
    N <- [0-9] ;
'''


def test_deep_lr_clean():
    r = test_parse(DEEP_LR, '1+2+3+4+5+6+7+8+9', 'E')
    assert r.ok, "should succeed"
    assert r.error_count == 0, "should have 0 errors"


def test_deep_lr_recovery():
    r = test_parse(DEEP_LR, '1+2+Z3+4+5', 'E')
    assert r.ok, "should succeed"
    assert r.error_count >= 1, "should have at least 1 error"
