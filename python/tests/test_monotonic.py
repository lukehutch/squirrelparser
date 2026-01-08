"""Monotonic Invariant Tests - verify monotonic improvement check applies only to LR clauses"""
from squirrelparser import Str, Seq, First, OneOrMore, ZeroOrMore, Optional, Ref, Parser
from tests.test_utils import parse, parse_for_tree


# Direct LR: E <- E '+n' / 'n'
direct_lr_simple = {
    'E': First(
        Seq(Ref('E'), Str('+n')),
        Str('n')
    ),
}


def test_lr_direct_01_n() -> None:
    """LR-Direct-01-n"""
    r = parse_for_tree(direct_lr_simple, 'n', 'E')
    assert r is not None and r.len == 1, 'should parse n'


def test_lr_direct_02_n_plus_n() -> None:
    """LR-Direct-02-n+n"""
    r = parse_for_tree(direct_lr_simple, 'n+n', 'E')
    assert r is not None and r.len == 3, 'should parse n+n'


def test_lr_direct_03_n_plus_n_plus_n() -> None:
    """LR-Direct-03-n+n+n"""
    r = parse_for_tree(direct_lr_simple, 'n+n+n', 'E')
    assert r is not None and r.len == 5, 'should parse n+n+n'


# Indirect LR: E <- F / 'n'; F <- E '+n'
indirect_lr_simple = {
    'E': First(Ref('F'), Str('n')),
    'F': Seq(Ref('E'), Str('+n')),
}


def test_lr_indirect_01_n() -> None:
    """LR-Indirect-01-n"""
    r = parse_for_tree(indirect_lr_simple, 'n', 'E')
    assert r is not None and r.len == 1, 'should parse n'


def test_lr_indirect_02_n_plus_n() -> None:
    """LR-Indirect-02-n+n"""
    r = parse_for_tree(indirect_lr_simple, 'n+n', 'E')
    assert r is not None and r.len == 3, 'should parse n+n'


def test_lr_indirect_03_n_plus_n_plus_n() -> None:
    """LR-Indirect-03-n+n+n"""
    r = parse_for_tree(indirect_lr_simple, 'n+n+n', 'E')
    assert r is not None and r.len == 5, 'should parse n+n+n'


# Direct Hidden LR: E <- F? E '+n' / 'n'; F <- 'f'
# The optional F? can match empty, making E left-recursive
direct_hidden_lr = {
    'E': First(
        Seq(Optional(Ref('F')), Ref('E'), Str('+n')),
        Str('n')
    ),
    'F': Str('f'),
}


def test_lr_direct_hidden_01_n() -> None:
    """LR-DirectHidden-01-n"""
    r = parse_for_tree(direct_hidden_lr, 'n', 'E')
    assert r is not None and r.len == 1, 'should parse n'


def test_lr_direct_hidden_02_n_plus_n() -> None:
    """LR-DirectHidden-02-n+n"""
    r = parse_for_tree(direct_hidden_lr, 'n+n', 'E')
    assert r is not None and r.len == 3, 'should parse n+n'


def test_lr_direct_hidden_03_n_plus_n_plus_n() -> None:
    """LR-DirectHidden-03-n+n+n"""
    r = parse_for_tree(direct_hidden_lr, 'n+n+n', 'E')
    assert r is not None and r.len == 5, 'should parse n+n+n'


def test_lr_direct_hidden_04_fn_plus_n() -> None:
    """LR-DirectHidden-04-fn+n"""
    # With the 'f' prefix, right-recursive path
    r = parse_for_tree(direct_hidden_lr, 'fn+n', 'E')
    assert r is not None and r.len == 4, 'should parse fn+n'


# Indirect Hidden LR: E <- F E '+n' / 'n'; F <- "abc" / 'd'*
# F can match empty (via 'd'*), making E left-recursive
indirect_hidden_lr = {
    'E': First(
        Seq(Ref('F'), Ref('E'), Str('+n')),
        Str('n')
    ),
    'F': First(Str('abc'), ZeroOrMore(Str('d'))),
}


def test_lr_indirect_hidden_01_n() -> None:
    """LR-IndirectHidden-01-n"""
    r = parse_for_tree(indirect_hidden_lr, 'n', 'E')
    assert r is not None and r.len == 1, 'should parse n'


def test_lr_indirect_hidden_02_n_plus_n() -> None:
    """LR-IndirectHidden-02-n+n"""
    r = parse_for_tree(indirect_hidden_lr, 'n+n', 'E')
    assert r is not None and r.len == 3, 'should parse n+n'


def test_lr_indirect_hidden_03_n_plus_n_plus_n() -> None:
    """LR-IndirectHidden-03-n+n+n"""
    r = parse_for_tree(indirect_hidden_lr, 'n+n+n', 'E')
    assert r is not None and r.len == 5, 'should parse n+n+n'


def test_lr_indirect_hidden_04_abcn_plus_n() -> None:
    """LR-IndirectHidden-04-abcn+n"""
    # With 'abc' prefix, right-recursive path
    r = parse_for_tree(indirect_hidden_lr, 'abcn+n', 'E')
    assert r is not None and r.len == 6, 'should parse abcn+n'


def test_lr_indirect_hidden_05_ddn_plus_n() -> None:
    """LR-IndirectHidden-05-ddn+n"""
    # With 'dd' prefix, right-recursive path
    r = parse_for_tree(indirect_hidden_lr, 'ddn+n', 'E')
    assert r is not None and r.len == 5, 'should parse ddn+n'


# Multi-step Indirect LR: E <- F '+n' / 'n'; F <- "gh" / J; J <- 'k' / E 'l'
# Three-step indirect cycle: E -> F -> J -> E
multi_step_lr = {
    'E': First(
        Seq(Ref('F'), Str('+n')),
        Str('n')
    ),
    'F': First(Str('gh'), Ref('J')),
    'J': First(
        Str('k'),
        Seq(Ref('E'), Str('l'))
    ),
}


def test_lr_multi_step_01_n() -> None:
    """LR-MultiStep-01-n"""
    r = parse_for_tree(multi_step_lr, 'n', 'E')
    assert r is not None and r.len == 1, 'should parse n'


def test_lr_multi_step_02_gh_plus_n() -> None:
    """LR-MultiStep-02-gh+n"""
    # F matches "gh"
    r = parse_for_tree(multi_step_lr, 'gh+n', 'E')
    assert r is not None and r.len == 4, 'should parse gh+n'


def test_lr_multi_step_03_k_plus_n() -> None:
    """LR-MultiStep-03-k+n"""
    # F -> J -> 'k'
    r = parse_for_tree(multi_step_lr, 'k+n', 'E')
    assert r is not None and r.len == 3, 'should parse k+n'


def test_lr_multi_step_04_nl_plus_n() -> None:
    """LR-MultiStep-04-nl+n"""
    # E <- F '+n' where F <- J where J <- E 'l'
    # So: E matches 'n', then 'l', giving 'nl' for J, for F
    # Then F '+n' gives 'nl+n'
    r = parse_for_tree(multi_step_lr, 'nl+n', 'E')
    assert r is not None and r.len == 4, 'should parse nl+n'


def test_lr_multi_step_05_nl_plus_nl_plus_n() -> None:
    """LR-MultiStep-05-nl+nl+n"""
    # Nested multi-step LR
    r = parse_for_tree(multi_step_lr, 'nl+nl+n', 'E')
    assert r is not None and r.len == 7, 'should parse nl+nl+n'


# Direct + Indirect LR (Interwoven): L <- P '.x' / 'x'; P <- P '(n)' / L
# Two interlocking cycles: L->P->L (indirect) and P->P (direct)
interwoven_lr = {
    'L': First(
        Seq(Ref('P'), Str('.x')),
        Str('x')
    ),
    'P': First(
        Seq(Ref('P'), Str('(n)')),
        Ref('L')
    ),
}


def test_lr_interwoven_01_x() -> None:
    """LR-Interwoven-01-x"""
    r = parse_for_tree(interwoven_lr, 'x', 'L')
    assert r is not None and r.len == 1, 'should parse x'


def test_lr_interwoven_02_x_dot_x() -> None:
    """LR-Interwoven-02-x.x"""
    r = parse_for_tree(interwoven_lr, 'x.x', 'L')
    assert r is not None and r.len == 3, 'should parse x.x'


def test_lr_interwoven_03_x_n_dot_x() -> None:
    """LR-Interwoven-03-x(n).x"""
    r = parse_for_tree(interwoven_lr, 'x(n).x', 'L')
    assert r is not None and r.len == 6, 'should parse x(n).x'


def test_lr_interwoven_04_x_n_n_dot_x() -> None:
    """LR-Interwoven-04-x(n)(n).x"""
    r = parse_for_tree(interwoven_lr, 'x(n)(n).x', 'L')
    assert r is not None and r.len == 9, 'should parse x(n)(n).x'


# Multiple Interlocking LR Cycles
# E <- F 'n' / 'n'
# F <- E '+' I* / G '-'
# G <- H 'm' / E
# H <- G 'l'
# I <- '(' A+ ')'
# A <- 'a'
# Cycles: E->F->E, F->G->E, G->H->G
interlocking_lr = {
    'E': First(
        Seq(Ref('F'), Str('n')),
        Str('n')
    ),
    'F': First(
        Seq(Ref('E'), Str('+'), ZeroOrMore(Ref('I'))),
        Seq(Ref('G'), Str('-'))
    ),
    'G': First(
        Seq(Ref('H'), Str('m')),
        Ref('E')
    ),
    'H': Seq(Ref('G'), Str('l')),
    'I': Seq(Str('('), OneOrMore(Ref('A')), Str(')')),
    'A': Str('a'),
}


def test_lr_interlocking_01_n() -> None:
    """LR-Interlocking-01-n"""
    r = parse_for_tree(interlocking_lr, 'n', 'E')
    assert r is not None and r.len == 1, 'should parse n'


def test_lr_interlocking_02_n_plus_n() -> None:
    """LR-Interlocking-02-n+n"""
    # E <- F 'n' where F <- E '+'
    r = parse_for_tree(interlocking_lr, 'n+n', 'E')
    assert r is not None and r.len == 3, 'should parse n+n'


def test_lr_interlocking_03_n_minus_n() -> None:
    """LR-Interlocking-03-n-n"""
    # E <- F 'n' where F <- G '-' where G <- E
    r = parse_for_tree(interlocking_lr, 'n-n', 'E')
    assert r is not None and r.len == 3, 'should parse n-n'


def test_lr_interlocking_04_nlm_minus_n() -> None:
    """LR-Interlocking-04-nlm-n"""
    # G <- H 'm' where H <- G 'l', cycle G->H->G
    r = parse_for_tree(interlocking_lr, 'nlm-n', 'E')
    assert r is not None and r.len == 5, 'should parse nlm-n'


def test_lr_interlocking_05_n_plus_aaa_n() -> None:
    """LR-Interlocking-05-n+(aaa)n"""
    # E '+' I* where I <- '(' A+ ')'
    r = parse_for_tree(interlocking_lr, 'n+(aaa)n', 'E')
    assert r is not None and r.len == 8, 'should parse n+(aaa)n'


def test_lr_interlocking_06_nlm_minus_n_plus_aaa_n() -> None:
    """LR-Interlocking-06-nlm-n+(aaa)n"""
    # Complex combination of all cycles
    r = parse_for_tree(interlocking_lr, 'nlm-n+(aaa)n', 'E')
    assert r is not None and r.len == 12, 'should parse nlm-n+(aaa)n'


# LR Precedence Grammar
# E <- E '+' T / E '-' T / T
# T <- T '*' F / T '/' F / F
# F <- '(' E ')' / 'n'
precedence_grammar = {
    'E': First(
        Seq(Ref('E'), Str('+'), Ref('T')),
        Seq(Ref('E'), Str('-'), Ref('T')),
        Ref('T'),
    ),
    'T': First(
        Seq(Ref('T'), Str('*'), Ref('F')),
        Seq(Ref('T'), Str('/'), Ref('F')),
        Ref('F'),
    ),
    'F': First(
        Seq(Str('('), Ref('E'), Str(')')),
        Str('n')
    ),
}


def test_lr_precedence_01_n() -> None:
    """LR-Precedence-01-n"""
    r = parse_for_tree(precedence_grammar, 'n', 'E')
    assert r is not None and r.len == 1, 'should parse n'


def test_lr_precedence_02_n_plus_n() -> None:
    """LR-Precedence-02-n+n"""
    r = parse_for_tree(precedence_grammar, 'n+n', 'E')
    assert r is not None and r.len == 3, 'should parse n+n'


def test_lr_precedence_03_n_star_n() -> None:
    """LR-Precedence-03-n*n"""
    r = parse_for_tree(precedence_grammar, 'n*n', 'E')
    assert r is not None and r.len == 3, 'should parse n*n'


def test_lr_precedence_04_n_plus_n_star_n() -> None:
    """LR-Precedence-04-n+n*n"""
    # Precedence: n+(n*n) not (n+n)*n
    r = parse_for_tree(precedence_grammar, 'n+n*n', 'E')
    assert r is not None and r.len == 5, 'should parse n+n*n'


def test_lr_precedence_05_n_plus_n_star_n_plus_n_div_n() -> None:
    """LR-Precedence-05-n+n*n+n/n"""
    r = parse_for_tree(precedence_grammar, 'n+n*n+n/n', 'E')
    assert r is not None and r.len == 9, 'should parse n+n*n+n/n'


def test_lr_precedence_06_paren_n_plus_n_star_n() -> None:
    """LR-Precedence-06-(n+n)*n"""
    r = parse_for_tree(precedence_grammar, '(n+n)*n', 'E')
    assert r is not None and r.len == 7, 'should parse (n+n)*n'


def test_lr_recovery_leading_error() -> None:
    """LR-Recovery-leading-error"""
    # Input '+n+n+n+' starts with '+' which is invalid
    ok, err, _ = parse(direct_lr_simple, '+n+n+n+', 'E')
    # Recovery should skip leading '+' and parse rest, or fail
    # The leading '+' can potentially be skipped as garbage
    if ok:
        assert err >= 1, 'should have errors if succeeded'


def test_lr_recovery_trailing_plus() -> None:
    """LR-Recovery-trailing-plus"""
    # Input 'n+n+n+' has trailing '+' with no 'n' after
    parser = Parser(rules=direct_lr_simple, input_str='n+n+n+')
    result, used_recovery = parser.parse('E')
    # Should parse 'n+n+n' and either fail on trailing '+' or recover
    if result is not None and not result.is_mismatch:
        # If it succeeded, it should have used recovery
        assert result.len >= 5, 'should parse at least n+n+n'


# Indirect Left Recursion (Fig7b): A <- B / 'x'; B <- (A 'y') / (A 'x')
fig7b = {
    'A': First(Ref('B'), Str('x')),
    'B': First(
        Seq(Ref('A'), Str('y')),
        Seq(Ref('A'), Str('x'))
    ),
}


def test_m_ilr_01_x() -> None:
    """M-ILR-01-x"""
    r = parse_for_tree(fig7b, 'x', 'A')
    assert r is not None and r.len == 1, 'should parse x'


def test_m_ilr_02_xx() -> None:
    """M-ILR-02-xx"""
    r = parse_for_tree(fig7b, 'xx', 'A')
    assert r is not None and r.len == 2, 'should parse xx'


def test_m_ilr_03_xy() -> None:
    """M-ILR-03-xy"""
    r = parse_for_tree(fig7b, 'xy', 'A')
    assert r is not None and r.len == 2, 'should parse xy'


def test_m_ilr_04_xxy() -> None:
    """M-ILR-04-xxy"""
    r = parse_for_tree(fig7b, 'xxy', 'A')
    assert r is not None and r.len == 3, 'should parse xxy'


def test_m_ilr_05_xxyx() -> None:
    """M-ILR-05-xxyx"""
    r = parse_for_tree(fig7b, 'xxyx', 'A')
    assert r is not None and r.len == 4, 'should parse xxyx'


def test_m_ilr_06_xyx() -> None:
    """M-ILR-06-xyx"""
    r = parse_for_tree(fig7b, 'xyx', 'A')
    assert r is not None and r.len == 3, 'should parse xyx'


# Interwoven Left Recursion (Fig7f): L <- P '.x' / 'x'; P <- P '(n)' / L
fig7f = {
    'L': First(
        Seq(Ref('P'), Str('.x')),
        Str('x')
    ),
    'P': First(
        Seq(Ref('P'), Str('(n)')),
        Ref('L')
    ),
}


def test_m_iw_01_x() -> None:
    """M-IW-01-x"""
    r = parse_for_tree(fig7f, 'x', 'L')
    assert r is not None and r.len == 1, 'should parse x'


def test_m_iw_02_x_dot_x() -> None:
    """M-IW-02-x.x"""
    r = parse_for_tree(fig7f, 'x.x', 'L')
    assert r is not None and r.len == 3, 'should parse x.x'


def test_m_iw_03_x_n_dot_x() -> None:
    """M-IW-03-x(n).x"""
    r = parse_for_tree(fig7f, 'x(n).x', 'L')
    assert r is not None and r.len == 6, 'should parse x(n).x'


def test_m_iw_04_x_n_n_dot_x() -> None:
    """M-IW-04-x(n)(n).x"""
    r = parse_for_tree(fig7f, 'x(n)(n).x', 'L')
    assert r is not None and r.len == 9, 'should parse x(n)(n).x'


def test_m_iw_05_x_dot_x_n_n_dot_x_dot_x() -> None:
    """M-IW-05-x.x(n)(n).x.x"""
    r = parse_for_tree(fig7f, 'x.x(n)(n).x.x', 'L')
    assert r is not None and r.len == 13, 'should parse x.x(n)(n).x.x'


# Optional-Dependent Left Recursion (Fig7d): A <- 'x'? (A 'y' / A / 'y')
fig7d = {
    'A': Seq(
        Optional(Str('x')),
        First(
            Seq(Ref('A'), Str('y')),
            Ref('A'),
            Str('y')
        )
    ),
}


def test_m_od_01_y() -> None:
    """M-OD-01-y"""
    r = parse_for_tree(fig7d, 'y', 'A')
    assert r is not None and r.len == 1, 'should parse y'


def test_m_od_02_xy() -> None:
    """M-OD-02-xy"""
    r = parse_for_tree(fig7d, 'xy', 'A')
    assert r is not None and r.len == 2, 'should parse xy'


def test_m_od_03_xxyyy() -> None:
    """M-OD-03-xxyyy"""
    r = parse_for_tree(fig7d, 'xxyyy', 'A')
    assert r is not None and r.len == 5, 'should parse xxyyy'


# Input-Dependent Left Recursion (Fig7c): A <- B / 'z'; B <- ('x' A) / (A 'y')
fig7c = {
    'A': First(Ref('B'), Str('z')),
    'B': First(
        Seq(Str('x'), Ref('A')),
        Seq(Ref('A'), Str('y'))
    ),
}


def test_m_id_01_z() -> None:
    """M-ID-01-z"""
    r = parse_for_tree(fig7c, 'z', 'A')
    assert r is not None and r.len == 1, 'should parse z'


def test_m_id_02_xz() -> None:
    """M-ID-02-xz"""
    r = parse_for_tree(fig7c, 'xz', 'A')
    assert r is not None and r.len == 2, 'should parse xz'


def test_m_id_03_zy() -> None:
    """M-ID-03-zy"""
    r = parse_for_tree(fig7c, 'zy', 'A')
    assert r is not None and r.len == 2, 'should parse zy'


def test_m_id_04_xxzyyy() -> None:
    """M-ID-04-xxzyyy"""
    r = parse_for_tree(fig7c, 'xxzyyy', 'A')
    assert r is not None and r.len == 6, 'should parse xxzyyy'


# Triple-nested indirect LR
triple_lr = {
    'A': First(Ref('B'), Str('a')),
    'B': First(Ref('C'), Str('b')),
    'C': First(
        Seq(Ref('A'), Str('x')),
        Str('c')
    ),
}


def test_m_tlr_01_a() -> None:
    """M-TLR-01-a"""
    r = parse_for_tree(triple_lr, 'a', 'A')
    assert r is not None and r.len == 1, 'should parse a'


def test_m_tlr_02_ax() -> None:
    """M-TLR-02-ax"""
    r = parse_for_tree(triple_lr, 'ax', 'A')
    assert r is not None and r.len == 2, 'should parse ax'


def test_m_tlr_03_axx() -> None:
    """M-TLR-03-axx"""
    r = parse_for_tree(triple_lr, 'axx', 'A')
    assert r is not None and r.len == 3, 'should parse axx'


def test_m_tlr_04_axxx() -> None:
    """M-TLR-04-axxx"""
    r = parse_for_tree(triple_lr, 'axxx', 'A')
    assert r is not None and r.len == 4, 'should parse axxx'
