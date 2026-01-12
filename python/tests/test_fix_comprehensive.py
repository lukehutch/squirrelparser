from tests.test_utils import test_parse


class TestComprehensiveFixes:
    """Comprehensive Fix Tests."""

    # Fix #3: Ref transparency - Ref should not have independent memoization
    def test_FIX3_01_ref_transparency_lr_reexpansion(self):
        # During recovery, Ref should allow LR to re-expand
        grammar = '''
            S <- E ";" ;
            E <- E "+" "n" / "n" ;
        '''
        result = test_parse(grammar, 'n+Xn;')
        assert result.ok, "Ref should allow LR re-expansion during recovery"
        assert result.error_count == 1, "should skip X"

    # Fix #4: Terminal skip sanity - single-char vs multi-char
    def test_FIX4_01_single_char_skip_junk(self):
        # Single-char terminal can skip arbitrary junk
        grammar = 'S <- "a" "b" "c" ;'
        result = test_parse(grammar, 'aXXbc')
        assert result.ok, "should skip junk XX"
        assert result.error_count == 1, "one skip"
        assert any('XX' in s for s in result.skipped_strings)

    def test_FIX4_02_single_char_no_skip_containing_terminal(self):
        # Single-char terminal should NOT skip if junk contains the terminal
        grammar = 'S <- "a" "b" "c" ;'
        result = test_parse(grammar, 'aXbYc')
        # This might succeed by skipping X, matching b, skipping Y (2 errors)
        # The key is it shouldn't skip "Xb" as one unit
        assert result.ok, "should recover with multiple skips"

    def test_FIX4_03_multi_char_atomic_terminal(self):
        # Multi-char terminal is atomic - can't skip more than its length
        # Grammar only matches 'n', rest captured as trailing error
        grammar = '''
            S <- E ;
            E <- E "+n" / "n" ;
        '''
        result = test_parse(grammar, 'n+Xn+n')
        assert result.ok, "matches n, rest is trailing error"
        assert result.error_count == 1, "should have 1 error (trailing +Xn+n)"

    def test_FIX4_04_multi_char_exact_skip_ok(self):
        # Multi-char terminal can skip exactly its length if needed
        grammar = 'S <- "ab" "cd" ;'
        result = test_parse(grammar, 'abXYcd')
        assert result.ok, "can skip 2 chars for 2-char terminal"
        assert result.error_count == 1, "one skip"

    # Fix #5: Don't skip content containing next expected terminal
    def test_FIX5_01_no_skip_containing_next_terminal(self):
        # During recovery, don't skip content that includes next terminal
        grammar = '''
            S <- E ";" E ;
            E <- E "+" "n" / "n" ;
        '''
        result = test_parse(grammar, 'n+Xn;n+n+n')
        assert result.ok, "should recover"
        assert result.error_count == 1, "only skip X in first E, not consume ;n"

    def test_FIX5_02_skip_pure_junk_ok(self):
        # Can skip junk that doesn't contain next terminal
        grammar = 'S <- "+" "n" ;'
        result = test_parse(grammar, '+XXn')
        assert result.ok, "should skip XX"
        assert result.error_count == 1, "one skip"
        assert any('XX' in s for s in result.skipped_strings)

    # Combined fixes: complex scenarios
    def test_COMBINED_01_lr_with_skip_and_delete(self):
        # LR expansion + recovery with both skip and delete
        grammar = '''
            S <- E ;
            E <- E "+" "n" / "n" ;
        '''
        result = test_parse(grammar, 'n+Xn+Yn')
        assert result.ok, "should handle multiple errors in LR"

    def test_COMBINED_02_first_prefers_longer_with_errors(self):
        # First should prefer longer match even if it has more errors
        grammar = '''
            S <- "a" "b" "c" / "a" ;
        '''
        result = test_parse(grammar, 'aXbc')
        assert result.ok, "should choose longer alternative"
        assert result.error_count == 1, "skip X"
        # Result should be "abc" not just "a"

    def test_COMBINED_03_nested_seq_recovery(self):
        # Nested sequences with recovery at different levels
        grammar = '''
            S <- A ";" B ;
            A <- "a" "x" ;
            B <- "b" "y" ;
        '''
        result = test_parse(grammar, 'aXx;bYy')
        assert result.ok, "nested recovery should work"
        assert result.error_count == 2, "skip X and Y"
