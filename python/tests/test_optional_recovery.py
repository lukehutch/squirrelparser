# ===========================================================================
# OPTIONAL WITH RECOVERY TESTS
# ===========================================================================
# These tests verify Optional behavior with and without recovery.

from tests.test_utils import test_parse


class TestOptionalRecovery:

    def test_opt01_optional_matches_cleanly(self):
        # Optional matches its content cleanly
        result = test_parse('S <- "a"? "b" ;', 'ab')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"
        # Optional matches 'a', then 'b'

    def test_opt02_optional_falls_through_cleanly(self):
        # Optional doesn't match, falls through
        result = test_parse('S <- "a"? "b" ;', 'b')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"
        # Optional returns empty match (len=0), then 'b' matches

    def test_opt03_optional_with_recovery_attempt(self):
        # Optional content needs recovery - should Optional try recovery or fall through?
        # Current behavior: Optional tries recovery
        result = test_parse('S <- ("a" "b")? ;', 'aXb')
        assert result.ok is True, "should succeed"
        # If Optional attempts recovery: err=1, skip=['X']
        # If Optional falls through: err=0, but incomplete parse
        assert result.error_count == 1, "Optional should attempt recovery"
        assert 'X' in result.skipped_strings, "should skip X"

    def test_opt04_optional_in_sequence(self):
        # Optional in middle of sequence
        result = test_parse('S <- "a" "b"? "c" ;', 'ac')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"
        # 'a' matches, Optional falls through, 'c' matches

    def test_opt05_nested_optional(self):
        # Optional(Optional(...))
        result = test_parse('S <- "a"?? "b" ;', 'b')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"
        # Both optionals return empty

    def test_opt06_optional_with_first(self):
        # Optional(First([...]))
        result = test_parse('S <- ("a" / "b")? "c" ;', 'bc')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"
        # Optional matches First's second alternative 'b'

    def test_opt07_optional_with_repetition(self):
        # Optional(OneOrMore(...))
        result = test_parse('S <- "x"+? "y" ;', 'xxxy')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"
        # Optional matches OneOrMore which matches 3 x's

    def test_opt08_optional_at_eof(self):
        # Optional at end of grammar
        result = test_parse('S <- "a" "b"? ;', 'a')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"
        # 'a' matches, Optional at EOF returns empty

    def test_opt09_multiple_optionals(self):
        # Multiple optionals in sequence
        result = test_parse('S <- "a"? "b"? "c" ;', 'c')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"
        # Both optionals return empty, 'c' matches

    def test_opt10_optional_vs_zeroormore(self):
        # Optional(Str(x)) vs ZeroOrMore(Str(x))
        # Optional: matches 0 or 1 time
        # ZeroOrMore: matches 0 or more times
        opt = test_parse('S <- "x"? "y" ;', 'xxxy')
        # Optional matches first 'x', remaining "xxy" for rest
        # Str('y') sees "xxy", uses recovery to skip "xx", matches 'y'
        assert opt.ok is True, "Optional matches 1, recovery handles rest"
        assert opt.error_count == 1, "should have 1 error (skipped xx)"

        zm = test_parse('S <- "x"* "y" ;', 'xxxy')
        assert zm.ok is True, "ZeroOrMore matches all 3, then y"
        assert zm.error_count == 0, "should have 0 errors (clean match)"

    def test_opt11_optional_with_complex_content(self):
        # Optional(Seq([complex structure]))
        result = test_parse(
            'S <- ("if" "(" "x" ")")? "body" ;',
            'if(x)body'
        )
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"

    def test_opt12_optional_incomplete_phase1(self):
        # In Phase 1, if Optional's content is incomplete, should Optional be marked incomplete?
        # This is testing the "mark Optional fallback incomplete" (Modification 5)
        result = test_parse('S <- "a"? "b" ;', 'Xb')
        # Phase 1: Optional tries 'a' at 0, sees 'X', fails
        #   Optional falls through (returns empty), marked incomplete
        # Phase 2: Re-evaluates, Optional might try recovery? Or still fall through?
        assert result.ok is True, "should succeed"
        # If Optional tries recovery in Phase 2, would skip X and fail to find 'a'
        # Then falls through, 'b' matches
