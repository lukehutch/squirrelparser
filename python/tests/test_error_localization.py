# ===========================================================================
# ERROR LOCALIZATION TESTS (Non-Cascading Verification)
# ===========================================================================
# These tests verify that errors don't cascade - each error is localized
# to its specific location without affecting subsequent parsing.

from tests.test_utils import test_parse


class TestErrorLocalization:

    def test_cascade01_error_in_first_element_doesnt_affect_second(self):
        # Error in first element, second element parses cleanly
        grammar = 'S <- "a" "b" "c" ;'
        result = test_parse(grammar, 'aXbc')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have exactly 1 error (at position 1)"
        assert 'X' in result.skipped_strings, "should skip X"
        # Error localized to position 1, doesn't cascade to 'b' or 'c'

    def test_cascade02_error_in_nested_structure(self):
        # Error inside inner Seq, doesn't affect outer Seq
        grammar = '''
            S <- ("a" "b") "c" ;
        '''
        result = test_parse(grammar, 'aXbc')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have exactly 1 error"
        assert 'X' in result.skipped_strings, "should skip X"
        # Error in inner Seq (between 'a' and 'b'), outer Seq continues normally

    def test_cascade03_lr_error_doesnt_cascade_to_next_expansion(self):
        # Error in one LR expansion iteration, next iteration clean
        grammar = '''
            E <- E "+" "n" / "n" ;
        '''
        result = test_parse(grammar, 'n+Xn+n', 'E')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have exactly 1 error"
        assert 'X' in result.skipped_strings, "should skip X"
        # Expansion: n (base), n+[skip X]n, n+Xn+n
        # First '+' clean, second '+' has error, third '+' clean
        # Error localized to second iteration

    def test_cascade04_multiple_independent_errors(self):
        # Multiple errors in different parts of parse, all localized
        grammar = '''
            S <- ("a" "b") ("c" "d") ("e" "f") ;
        '''
        result = test_parse(grammar, 'aXbcYdeZf')
        assert result.ok is True, "should succeed"
        assert result.error_count == 3, "should have 3 independent errors"
        assert 'X' in result.skipped_strings, "should skip X"
        assert 'Y' in result.skipped_strings, "should skip Y"
        assert 'Z' in result.skipped_strings, "should skip Z"
        # Each error localized to its respective Seq

    def test_cascade05_error_before_repetition(self):
        # Error before repetition, repetition parses cleanly
        grammar = '''
            S <- "a" "b"+ ;
        '''
        result = test_parse(grammar, 'aXbbb')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error"
        assert 'X' in result.skipped_strings, "should skip X"
        # Error at position 1, OneOrMore starts cleanly at position 2

    def test_cascade06_error_after_repetition(self):
        # Repetition clean, error after it
        grammar = '''
            S <- "a"+ "b" ;
        '''
        result = test_parse(grammar, 'aaaXb')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error"
        assert 'X' in result.skipped_strings, "should skip X"
        # OneOrMore matches 3 a's cleanly, then error, then 'b'

    def test_cascade07_error_in_first_alternative_doesnt_poison_second(self):
        # First alternative has error, second alternative clean
        grammar = '''
            S <- "a" "b" / "c" ;
        '''
        result = test_parse(grammar, 'c')
        assert result.ok is True, "should succeed"
        assert result.error_count == 0, "should have 0 errors (second alternative clean)"
        # First tries and fails, second succeeds cleanly - no cascade

    def test_cascade08_recovery_version_increments_correctly(self):
        # Each recovery increments version, ensuring proper cache invalidation
        grammar = '''
            S <- ("a" "b") ("c" "d") ;
        '''
        result = test_parse(grammar, 'aXbcYd')
        assert result.ok is True, "should succeed"
        assert result.error_count == 2, "should have 2 errors"
        # Two recoveries, each increments version, no cache pollution

    def test_cascade09_error_at_deeply_nested_level(self):
        # Error very deep in nesting, doesn't affect outer levels
        grammar = '''
            S <- ((("a" "b") "c") "d") "e" ;
        '''
        result = test_parse(grammar, 'aXbcde')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error at deepest level"
        assert 'X' in result.skipped_strings, "should skip X"
        # Error localized despite 4 levels of nesting

    def test_cascade10_error_recovery_doesnt_leave_parser_in_bad_state(self):
        # After recovery, parser continues with clean state
        grammar = '''
            S <- ("a" "b") "c" ("d" "e") ;
        '''
        result = test_parse(grammar, 'abXcde')
        assert result.ok is True, "should succeed"
        assert result.error_count == 1, "should have 1 error"
        # After skipping X at position 2, matches 'c' at position 3, then 'de'
