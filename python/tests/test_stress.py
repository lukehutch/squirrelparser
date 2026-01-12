"""
SECTION 11: STRESS TESTS (20 tests)
"""

from tests.test_utils import test_parse


def test_st01_1000_clean():
    r = test_parse('S <- "ab"+ ;', 'ab' * 500)
    assert r.ok, "should succeed"
    assert r.error_count == 0, "should have 0 errors"


def test_st02_1000_err():
    r = test_parse('S <- "ab"+ ;', 'ab' * 250 + 'XX' + 'ab' * 249)
    assert r.ok, "should succeed"
    assert r.error_count == 1, "should have 1 error"


def test_st03_100_groups():
    grammar = 'S <- ("(" "x"+ ")")+ ;'
    r = test_parse(grammar, '(xx)' * 100)
    assert r.ok, "should succeed"
    assert r.error_count == 0, "should have 0 errors"


def test_st04_100_groups_err():
    input_str = ''.join('(xZx)' if i % 10 == 5 else '(xx)' for i in range(100))
    grammar = 'S <- ("(" "x"+ ")")+ ;'
    r = test_parse(grammar, input_str)
    assert r.ok, "should succeed"
    assert r.error_count == 10, "should have 10 errors"


def test_st05_deep_nesting():
    grammar = '''
        S <- "(" A ")" ;
        A <- "(" A ")" / "x" ;
    '''
    r = test_parse(grammar, '(' * 15 + 'x' + ')' * 15)
    assert r.ok, "should succeed"
    assert r.error_count == 0, "should have 0 errors"


def test_st06_50_alts():
    alts = ' / '.join(f'"opt{i}"' for i in range(50))
    grammar = f'S <- {alts} / "match" ;'
    r = test_parse(grammar, 'match')
    assert r.ok, "should succeed"
    assert r.error_count == 0, "should have 0 errors"


def test_st07_500_chars():
    r = test_parse('S <- "x"+ ;', 'x' * 500)
    assert r.ok, "should succeed"
    assert r.error_count == 0, "should have 0 errors"


def test_st08_500_plus_5err():
    input_str = 'x' * 100
    for i in range(5):
        input_str += 'Z' + 'x' * 99
    r = test_parse('S <- "x"+ ;', input_str)
    assert r.ok, "should succeed"
    assert r.error_count == 5, "should have 5 errors"


def test_st09_100_seq():
    elems = ' '.join('"x"' for _ in range(100))
    grammar = f'S <- {elems} ;'
    r = test_parse(grammar, 'x' * 100)
    assert r.ok, "should succeed"
    assert r.error_count == 0, "should have 0 errors"


def test_st10_50_optional():
    elems = ' '.join('"x"?' for _ in range(50))
    grammar = f'S <- {elems} "!" ;'
    r = test_parse(grammar, 'x' * 25 + '!')
    assert r.ok, "should succeed"
    assert r.error_count == 0, "should have 0 errors"


def test_st11_nested_rep():
    grammar = 'S <- ("x"+)+ ;'
    r = test_parse(grammar, 'x' * 200)
    assert r.ok, "should succeed"
    assert r.error_count == 0, "should have 0 errors"


def test_st12_long_err_span():
    r = test_parse('S <- "ab"+ ;', 'ab' + 'X' * 200 + 'ab')
    assert r.ok, "should succeed"
    assert r.error_count == 1, "should have 1 error"


def test_st13_many_short_err():
    input_str = ''.join('abX' for _ in range(30)) + 'ab'
    r = test_parse('S <- "ab"+ ;', input_str)
    assert r.ok, "should succeed"
    assert r.error_count == 30, "should have 30 errors"


def test_st14_2000_clean():
    r = test_parse('S <- "x"+ ;', 'x' * 2000)
    assert r.ok, "should succeed"
    assert r.error_count == 0, "should have 0 errors"


def test_st15_2000_err():
    r = test_parse('S <- "x"+ ;', 'x' * 1000 + 'ZZ' + 'x' * 998)
    assert r.ok, "should succeed"
    assert r.error_count == 1, "should have 1 error"


def test_st16_200_groups():
    grammar = 'S <- ("(" "x"+ ")")+ ;'
    r = test_parse(grammar, '(xx)' * 200)
    assert r.ok, "should succeed"
    assert r.error_count == 0, "should have 0 errors"


def test_st17_200_groups_20err():
    input_str = ''.join('(xZx)' if i % 10 == 0 else '(xx)' for i in range(200))
    grammar = 'S <- ("(" "x"+ ")")+ ;'
    r = test_parse(grammar, input_str)
    assert r.ok, "should succeed"
    assert r.error_count == 20, "should have 20 errors"


def test_st18_50_errors():
    input_str = ''.join('abZ' for _ in range(50)) + 'ab'
    r = test_parse('S <- "ab"+ ;', input_str)
    assert r.ok, "should succeed"
    assert r.error_count == 50, "should have 50 errors"


def test_st19_deep_l5():
    grammar = '''
        S <- "1" (
          "2" (
            "3" (
              "4" (
                "5" "x"+ "5"
              ) "4"
            ) "3"
          ) "2"
        ) "1" ;
    '''
    r = test_parse(grammar, '12345xZx54321')
    assert r.ok, "should succeed"
    assert r.error_count == 1, "should have 1 error"
    assert 'Z' in r.skipped_strings, "should skip Z"


def test_st20_very_deep_nest():
    grammar = '''
        S <- "(" A ")" ;
        A <- "(" A ")" / "x" ;
    '''
    r = test_parse(grammar, '(' * 20 + 'x' + ')' * 20)
    assert r.ok, "should succeed"
    assert r.error_count == 0, "should have 0 errors"
