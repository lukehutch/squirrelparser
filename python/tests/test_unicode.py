# ===========================================================================
# SECTION 10: UNICODE AND SPECIAL (10 tests)
# ===========================================================================

from tests.test_utils import test_parse


class TestUnicode:

    def test_u01_greek(self):
        result = test_parse('S <- "α"+ ;', 'αβα')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error"
        assert 'β' in result.skipped_strings, "should skip β"

    def test_u02_chinese(self):
        result = test_parse('S <- "中"+ ;', '中文中')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error"
        assert '文' in result.skipped_strings, "should skip 文"

    def test_u03_arabic_clean(self):
        result = test_parse('S <- "م"+ ;', 'ممم')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"

    def test_u04_newline(self):
        result = test_parse('S <- "x"+ ;', 'x\nx')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error"
        assert '\n' in result.skipped_strings, "should skip newline"

    def test_u05_tab(self):
        result = test_parse(r'S <- "a" "\t" "b" ;', 'a\tb')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"

    def test_u06_space(self):
        result = test_parse('S <- "x"+ ;', 'x x')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error"
        assert ' ' in result.skipped_strings, "should skip space"

    def test_u07_multi_space(self):
        result = test_parse('S <- "x"+ ;', 'x   x')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error"
        assert '   ' in result.skipped_strings, "should skip spaces"

    def test_u08_japanese(self):
        result = test_parse('S <- "日"+ ;', '日本日')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error"
        assert '本' in result.skipped_strings, "should skip 本"

    def test_u09_korean(self):
        result = test_parse('S <- "한"+ ;', '한글한')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error"
        assert '글' in result.skipped_strings, "should skip 글"

    def test_u10_mixed_scripts(self):
        result = test_parse('S <- "α" "中" "!" ;', 'α中!')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"
