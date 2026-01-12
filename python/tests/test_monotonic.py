"""
SECTION 10: MONOTONIC INVARIANT TESTS (50 tests)

These tests verify that the monotonic improvement check only applies to
left-recursive clauses, not to all clauses. Without this fix, indirect
and interwoven left recursion would fail.
"""

from tests.test_utils import test_parse, parse_for_tree
from squirrelparser.squirrel_parse import squirrel_parse_pt

# ===========================================================================
# ADDITIONAL LR PATTERNS (from Pegged wiki examples)
# ===========================================================================
# These test cases cover various left recursion patterns documented at:
# https://github.com/PhilippeSigaud/Pegged/wiki/Left-Recursion

# --- Direct LR: E <- E '+n' / 'n' ---
DIRECT_LR_SIMPLE = '''
    E <- E "+n" / "n" ;
'''


def test_lr_direct_01_n():
    r = parse_for_tree(DIRECT_LR_SIMPLE, 'n', 'E')
    assert r is not None and r.len == 1, "should parse n"


def test_lr_direct_02_n_plus_n():
    r = parse_for_tree(DIRECT_LR_SIMPLE, 'n+n', 'E')
    assert r is not None and r.len == 3, "should parse n+n"


def test_lr_direct_03_n_plus_n_plus_n():
    r = parse_for_tree(DIRECT_LR_SIMPLE, 'n+n+n', 'E')
    assert r is not None and r.len == 5, "should parse n+n+n"


# --- Indirect LR: E <- F / 'n'; F <- E '+n' ---
INDIRECT_LR_SIMPLE = '''
    E <- F / "n" ;
    F <- E "+n" ;
'''


def test_lr_indirect_01_n():
    r = parse_for_tree(INDIRECT_LR_SIMPLE, 'n', 'E')
    assert r is not None and r.len == 1, "should parse n"


def test_lr_indirect_02_n_plus_n():
    r = parse_for_tree(INDIRECT_LR_SIMPLE, 'n+n', 'E')
    assert r is not None and r.len == 3, "should parse n+n"


def test_lr_indirect_03_n_plus_n_plus_n():
    r = parse_for_tree(INDIRECT_LR_SIMPLE, 'n+n+n', 'E')
    assert r is not None and r.len == 5, "should parse n+n+n"


# --- Direct Hidden LR: E <- F? E '+n' / 'n'; F <- 'f' ---
# The optional F? can match empty, making E left-recursive
DIRECT_HIDDEN_LR = '''
    E <- F? E "+n" / "n" ;
    F <- "f" ;
'''


def test_lr_direct_hidden_01_n():
    r = parse_for_tree(DIRECT_HIDDEN_LR, 'n', 'E')
    assert r is not None and r.len == 1, "should parse n"


def test_lr_direct_hidden_02_n_plus_n():
    r = parse_for_tree(DIRECT_HIDDEN_LR, 'n+n', 'E')
    assert r is not None and r.len == 3, "should parse n+n"


def test_lr_direct_hidden_03_n_plus_n_plus_n():
    r = parse_for_tree(DIRECT_HIDDEN_LR, 'n+n+n', 'E')
    assert r is not None and r.len == 5, "should parse n+n+n"


def test_lr_direct_hidden_04_fn_plus_n():
    # With the 'f' prefix, right-recursive path
    r = parse_for_tree(DIRECT_HIDDEN_LR, 'fn+n', 'E')
    assert r is not None and r.len == 4, "should parse fn+n"


# --- Indirect Hidden LR: E <- F E '+n' / 'n'; F <- "abc" / 'd'* ---
# F can match empty (via 'd'*), making E left-recursive
INDIRECT_HIDDEN_LR = '''
    E <- F E "+n" / "n" ;
    F <- "abc" / "d"* ;
'''


def test_lr_indirect_hidden_01_n():
    r = parse_for_tree(INDIRECT_HIDDEN_LR, 'n', 'E')
    assert r is not None and r.len == 1, "should parse n"


def test_lr_indirect_hidden_02_n_plus_n():
    r = parse_for_tree(INDIRECT_HIDDEN_LR, 'n+n', 'E')
    assert r is not None and r.len == 3, "should parse n+n"


def test_lr_indirect_hidden_03_n_plus_n_plus_n():
    r = parse_for_tree(INDIRECT_HIDDEN_LR, 'n+n+n', 'E')
    assert r is not None and r.len == 5, "should parse n+n+n"


def test_lr_indirect_hidden_04_abcn_plus_n():
    # With 'abc' prefix, right-recursive path
    r = parse_for_tree(INDIRECT_HIDDEN_LR, 'abcn+n', 'E')
    assert r is not None and r.len == 6, "should parse abcn+n"


def test_lr_indirect_hidden_05_ddn_plus_n():
    # With 'dd' prefix, right-recursive path
    r = parse_for_tree(INDIRECT_HIDDEN_LR, 'ddn+n', 'E')
    assert r is not None and r.len == 5, "should parse ddn+n"


# --- Multi-step Indirect LR: E <- F '+n' / 'n'; F <- "gh" / J; J <- 'k' / E 'l' ---
# Three-step indirect cycle: E -> F -> J -> E
MULTI_STEP_LR = '''
    E <- F "+n" / "n" ;
    F <- "gh" / J ;
    J <- "k" / E "l" ;
'''


def test_lr_multi_step_01_n():
    r = parse_for_tree(MULTI_STEP_LR, 'n', 'E')
    assert r is not None and r.len == 1, "should parse n"


def test_lr_multi_step_02_gh_plus_n():
    # F matches "gh"
    r = parse_for_tree(MULTI_STEP_LR, 'gh+n', 'E')
    assert r is not None and r.len == 4, "should parse gh+n"


def test_lr_multi_step_03_k_plus_n():
    # F -> J -> 'k'
    r = parse_for_tree(MULTI_STEP_LR, 'k+n', 'E')
    assert r is not None and r.len == 3, "should parse k+n"


def test_lr_multi_step_04_nl_plus_n():
    # E <- F '+n' where F <- J where J <- E 'l'
    r = parse_for_tree(MULTI_STEP_LR, 'nl+n', 'E')
    assert r is not None and r.len == 4, "should parse nl+n"


def test_lr_multi_step_05_nl_plus_nl_plus_n():
    # Nested multi-step LR
    r = parse_for_tree(MULTI_STEP_LR, 'nl+nl+n', 'E')
    assert r is not None and r.len == 7, "should parse nl+nl+n"


# --- Direct + Indirect LR (Interwoven): L <- P '.x' / 'x'; P <- P '(n)' / L ---
# Two interlocking cycles: L->P->L (indirect) and P->P (direct)
INTERWOVEN_LR = '''
    L <- P ".x" / "x" ;
    P <- P "(n)" / L ;
'''


def test_lr_interwoven_01_x():
    r = parse_for_tree(INTERWOVEN_LR, 'x', 'L')
    assert r is not None and r.len == 1, "should parse x"


def test_lr_interwoven_02_x_dot_x():
    r = parse_for_tree(INTERWOVEN_LR, 'x.x', 'L')
    assert r is not None and r.len == 3, "should parse x.x"


def test_lr_interwoven_03_x_paren_n_dot_x():
    r = parse_for_tree(INTERWOVEN_LR, 'x(n).x', 'L')
    assert r is not None and r.len == 6, "should parse x(n).x"


def test_lr_interwoven_04_x_paren_n_paren_n_dot_x():
    r = parse_for_tree(INTERWOVEN_LR, 'x(n)(n).x', 'L')
    assert r is not None and r.len == 9, "should parse x(n)(n).x"


# --- Multiple Interlocking LR Cycles ---
INTERLOCKING_LR = '''
    E <- F "n" / "n" ;
    F <- E "+" I* / G "-" ;
    G <- H "m" / E ;
    H <- G "l" ;
    I <- "(" A+ ")" ;
    A <- "a" ;
'''


def test_lr_interlocking_01_n():
    r = parse_for_tree(INTERLOCKING_LR, 'n', 'E')
    assert r is not None and r.len == 1, "should parse n"


def test_lr_interlocking_02_n_plus_n():
    r = parse_for_tree(INTERLOCKING_LR, 'n+n', 'E')
    assert r is not None and r.len == 3, "should parse n+n"


def test_lr_interlocking_03_n_minus_n():
    r = parse_for_tree(INTERLOCKING_LR, 'n-n', 'E')
    assert r is not None and r.len == 3, "should parse n-n"


def test_lr_interlocking_04_nlm_minus_n():
    r = parse_for_tree(INTERLOCKING_LR, 'nlm-n', 'E')
    assert r is not None and r.len == 5, "should parse nlm-n"


def test_lr_interlocking_05_n_plus_aaa_n():
    r = parse_for_tree(INTERLOCKING_LR, 'n+(aaa)n', 'E')
    assert r is not None and r.len == 8, "should parse n+(aaa)n"


def test_lr_interlocking_06_nlm_minus_n_plus_aaa_n():
    r = parse_for_tree(INTERLOCKING_LR, 'nlm-n+(aaa)n', 'E')
    assert r is not None and r.len == 12, "should parse nlm-n+(aaa)n"


# --- LR Precedence Grammar ---
PRECEDENCE_GRAMMAR = '''
    E <- E "+" T / E "-" T / T ;
    T <- T "*" F / T "/" F / F ;
    F <- "(" E ")" / "n" ;
'''


def test_lr_precedence_01_n():
    r = parse_for_tree(PRECEDENCE_GRAMMAR, 'n', 'E')
    assert r is not None and r.len == 1, "should parse n"


def test_lr_precedence_02_n_plus_n():
    r = parse_for_tree(PRECEDENCE_GRAMMAR, 'n+n', 'E')
    assert r is not None and r.len == 3, "should parse n+n"


def test_lr_precedence_03_n_times_n():
    r = parse_for_tree(PRECEDENCE_GRAMMAR, 'n*n', 'E')
    assert r is not None and r.len == 3, "should parse n*n"


def test_lr_precedence_04_n_plus_n_times_n():
    r = parse_for_tree(PRECEDENCE_GRAMMAR, 'n+n*n', 'E')
    assert r is not None and r.len == 5, "should parse n+n*n"


def test_lr_precedence_05_n_plus_n_times_n_plus_n_div_n():
    r = parse_for_tree(PRECEDENCE_GRAMMAR, 'n+n*n+n/n', 'E')
    assert r is not None and r.len == 9, "should parse n+n*n+n/n"


def test_lr_precedence_06_paren_n_plus_n_times_n():
    r = parse_for_tree(PRECEDENCE_GRAMMAR, '(n+n)*n', 'E')
    assert r is not None and r.len == 7, "should parse (n+n)*n"


# --- LR Error Recovery ---
def test_lr_recovery_leading_error():
    result = test_parse(DIRECT_LR_SIMPLE, '+n+n+n+', 'E')
    if result.ok:
        assert result.error_count >= 1, "should have errors if succeeded"


def test_lr_recovery_trailing_plus():
    parse_result = squirrel_parse_pt(
        grammar_spec=DIRECT_LR_SIMPLE,
        top_rule_name='E',
        input='n+n+n+',
    )
    result = parse_result.root
    if not result.is_mismatch:
        assert result.len >= 5, "should parse at least n+n+n"


# --- Indirect Left Recursion (Fig7b): A <- B / 'x'; B <- (A 'y') / (A 'x') ---
FIG7B = '''
    A <- B / "x" ;
    B <- A "y" / A "x" ;
'''


def test_m_ilr_01_x():
    r = parse_for_tree(FIG7B, 'x', 'A')
    assert r is not None and r.len == 1, "should parse x"


def test_m_ilr_02_xx():
    r = parse_for_tree(FIG7B, 'xx', 'A')
    assert r is not None and r.len == 2, "should parse xx"


def test_m_ilr_03_xy():
    r = parse_for_tree(FIG7B, 'xy', 'A')
    assert r is not None and r.len == 2, "should parse xy"


def test_m_ilr_04_xxy():
    r = parse_for_tree(FIG7B, 'xxy', 'A')
    assert r is not None and r.len == 3, "should parse xxy"


def test_m_ilr_05_xxyx():
    r = parse_for_tree(FIG7B, 'xxyx', 'A')
    assert r is not None and r.len == 4, "should parse xxyx"


def test_m_ilr_06_xyx():
    r = parse_for_tree(FIG7B, 'xyx', 'A')
    assert r is not None and r.len == 3, "should parse xyx"


# --- Interwoven Left Recursion (Fig7f): L <- P '.x' / 'x'; P <- P '(n)' / L ---
FIG7F = '''
    L <- P ".x" / "x" ;
    P <- P "(n)" / L ;
'''


def test_m_iw_01_x():
    r = parse_for_tree(FIG7F, 'x', 'L')
    assert r is not None and r.len == 1, "should parse x"


def test_m_iw_02_x_dot_x():
    r = parse_for_tree(FIG7F, 'x.x', 'L')
    assert r is not None and r.len == 3, "should parse x.x"


def test_m_iw_03_x_paren_n_dot_x():
    r = parse_for_tree(FIG7F, 'x(n).x', 'L')
    assert r is not None and r.len == 6, "should parse x(n).x"


def test_m_iw_04_x_paren_n_paren_n_dot_x():
    r = parse_for_tree(FIG7F, 'x(n)(n).x', 'L')
    assert r is not None and r.len == 9, "should parse x(n)(n).x"


def test_m_iw_05_x_dot_x_paren_n_paren_n_dot_x_dot_x():
    r = parse_for_tree(FIG7F, 'x.x(n)(n).x.x', 'L')
    assert r is not None and r.len == 13, "should parse x.x(n)(n).x.x"


# --- Optional-Dependent Left Recursion (Fig7d): A <- 'x'? (A 'y' / A / 'y') ---
FIG7D = '''
    A <- "x"? (A "y" / A / "y") ;
'''


def test_m_od_01_y():
    r = parse_for_tree(FIG7D, 'y', 'A')
    assert r is not None and r.len == 1, "should parse y"


def test_m_od_02_xy():
    r = parse_for_tree(FIG7D, 'xy', 'A')
    assert r is not None and r.len == 2, "should parse xy"


def test_m_od_03_xxyyy():
    r = parse_for_tree(FIG7D, 'xxyyy', 'A')
    assert r is not None and r.len == 5, "should parse xxyyy"


# --- Input-Dependent Left Recursion (Fig7c): A <- B / 'z'; B <- ('x' A) / (A 'y') ---
FIG7C = '''
    A <- B / "z" ;
    B <- "x" A / A "y" ;
'''


def test_m_id_01_z():
    r = parse_for_tree(FIG7C, 'z', 'A')
    assert r is not None and r.len == 1, "should parse z"


def test_m_id_02_xz():
    r = parse_for_tree(FIG7C, 'xz', 'A')
    assert r is not None and r.len == 2, "should parse xz"


def test_m_id_03_zy():
    r = parse_for_tree(FIG7C, 'zy', 'A')
    assert r is not None and r.len == 2, "should parse zy"


def test_m_id_04_xxzyyy():
    r = parse_for_tree(FIG7C, 'xxzyyy', 'A')
    assert r is not None and r.len == 6, "should parse xxzyyy"


# --- Triple-nested indirect LR ---
TRIPLE_LR = '''
    A <- B / "a" ;
    B <- C / "b" ;
    C <- A "x" / "c" ;
'''


def test_m_tlr_01_a():
    r = parse_for_tree(TRIPLE_LR, 'a', 'A')
    assert r is not None and r.len == 1, "should parse a"


def test_m_tlr_02_ax():
    r = parse_for_tree(TRIPLE_LR, 'ax', 'A')
    assert r is not None and r.len == 2, "should parse ax"


def test_m_tlr_03_axx():
    r = parse_for_tree(TRIPLE_LR, 'axx', 'A')
    assert r is not None and r.len == 3, "should parse axx"


def test_m_tlr_04_axxx():
    r = parse_for_tree(TRIPLE_LR, 'axxx', 'A')
    assert r is not None and r.len == 4, "should parse axxx"
