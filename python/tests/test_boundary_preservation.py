# ===========================================================================
# BOUNDARY PRESERVATION TESTS
# ===========================================================================
# These tests verify that recovery doesn't consume content meant for
# subsequent grammar elements (preserve structural boundaries).

from tests.test_utils import test_parse


class TestBoundaryPreservation:

    def test_bnd01_dont_consume_next_terminal(self):
        # Recovery should skip 'X' but not consume 'b' (needed by next element)
        result = test_parse('S <- "a" "b" ;', 'aXb')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error"
        assert 'X' in result.skipped_strings, "should skip X"
        # Verify 'b' was matched by second element, not consumed during recovery

    def test_bnd02_dont_partially_consume_next_terminal(self):
        # Multi-char terminals are atomic - recovery can't consume part of 'cd'
        result = test_parse('S <- "ab" "cd" ;', 'abXcd')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error"
        assert 'X' in result.skipped_strings, "should skip X"
        # 'cd' should be matched atomically by second element

    def test_bnd03_recovery_in_first_doesnt_poison_alternatives(self):
        # First alternative fails cleanly, second succeeds
        result = test_parse('S <- "a" "b" / "c" "d" ;', 'cd')
        assert result.ok is True, "should succeed (second alternative)"
        assert result.error_count == 0, "should have 0 errors (clean match)"

    def test_bnd04_first_alternative_with_recovery_vs_second_clean(self):
        # First alternative needs recovery, second is clean
        # Should prefer first (longer match, see FIX #2)
        result = test_parse('S <- "a" "b" "c" / "a" ;', 'aXbc')
        assert result.ok is True, "should succeed"
        # FIX #2: Prefer longer matches over fewer errors
        assert result.error_count == 1, "should choose first alternative (longer despite error)"

    def test_bnd05_boundary_with_nested_repetition(self):
        # Repetition with bound should stop at delimiter
        result = test_parse('S <- "x"+ ";" "y"+ ;', 'xxx;yyy')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"
        # x+ stops at ';', y+ stops at EOF

    def test_bnd06_boundary_with_recovery_before_delimiter(self):
        # Recovery happens, but delimiter is preserved
        result = test_parse('S <- "x"+ ";" "y"+ ;', 'xxXx;yyy')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error"
        assert 'X' in result.skipped_strings, "should skip X"
        # ';' should not be consumed during recovery of x+

    def test_bnd07_probe_respects_boundaries(self):
        # ZeroOrMore probes ahead to find boundary
        result = test_parse('S <- "x"* ("y" / "z") ;', 'xxxz')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"
        # ZeroOrMore should probe, find 'z' matches First, stop before it

    def test_bnd08_complex_boundary_nesting(self):
        # Nested sequences with multiple boundaries
        result = test_parse('S <- ("a"+ "+") ("b"+ "=") ;', 'aaa+bbb=')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"
        # Each repetition stops at its delimiter

    def test_bnd09_boundary_with_eof(self):
        # No explicit boundary - should consume until EOF
        result = test_parse('S <- "x"+ ;', 'xxxxx')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors"
        # Consumes all x's (no boundary to stop at)

    def test_bnd10_recovery_near_boundary(self):
        # Error just before boundary - should not cross boundary
        result = test_parse('S <- "x"+ ";" ;', 'xxX;')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error"
        assert 'X' in result.skipped_strings, "should skip X"
        # ';' should remain for second element
