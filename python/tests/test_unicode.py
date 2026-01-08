"""
SECTION 10: UNICODE AND SPECIAL (10 tests)
"""

from squirrelparser import Str, Seq, OneOrMore
from .test_utils import parse


def test_u01_greek() -> None:
    ok, err, skip = parse({'S': OneOrMore(Str('α'))}, 'αβα')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert 'β' in skip, 'should skip β'


def test_u02_chinese() -> None:
    ok, err, skip = parse({'S': OneOrMore(Str('中'))}, '中文中')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert '文' in skip, 'should skip 文'


def test_u03_arabic_clean() -> None:
    ok, err, _ = parse({'S': OneOrMore(Str('م'))}, 'ممم')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_u04_newline() -> None:
    ok, err, skip = parse({'S': OneOrMore(Str('x'))}, 'x\nx')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert '\n' in skip, 'should skip newline'


def test_u05_tab() -> None:
    ok, err, _ = parse({
        'S': Seq(Str('a'), Str('\t'), Str('b'))
    }, 'a\tb')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'


def test_u06_space() -> None:
    ok, err, skip = parse({'S': OneOrMore(Str('x'))}, 'x x')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert ' ' in skip, 'should skip space'


def test_u07_multi_space() -> None:
    ok, err, skip = parse({'S': OneOrMore(Str('x'))}, 'x   x')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert '   ' in skip, 'should skip spaces'


def test_u08_japanese() -> None:
    ok, err, skip = parse({'S': OneOrMore(Str('日'))}, '日本日')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert '本' in skip, 'should skip 本'


def test_u09_korean() -> None:
    ok, err, skip = parse({'S': OneOrMore(Str('한'))}, '한글한')
    assert ok, 'should succeed'
    assert err == 1, 'should have 1 error'
    assert '글' in skip, 'should skip 글'


def test_u10_mixed_scripts() -> None:
    ok, err, _ = parse({
        'S': Seq(Str('α'), Str('中'), Str('!'))
    }, 'α中!')
    assert ok, 'should succeed'
    assert err == 0, 'should have 0 errors'
