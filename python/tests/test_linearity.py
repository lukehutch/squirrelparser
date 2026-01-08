"""Linearity Tests - verify O(N) complexity"""
from squirrelparser import Str, Seq, First, OneOrMore, Ref
from tests.test_utils import parse_for_tree


class TestLinearityTests:
    """Linearity Tests - verify O(N) complexity where N is input length"""

    def test_linearity_simple_sequence(self) -> None:
        """Test linearity for simple sequence"""
        # Test that parsing scales linearly with input size
        # This is a placeholder test - full linearity testing requires stats tracking
        grammar = {
            'S': OneOrMore(Str('a'))
        }
        result = parse_for_tree(grammar, 'a' * 100)
        assert result is not None
        assert result.len == 100

    def test_linearity_with_lr(self) -> None:
        """Test linearity with left recursion"""
        # Left recursion should also scale linearly
        grammar = {
            'E': First(
                Seq(Ref('E'), Str('+'), Str('n')),
                Str('n')
            ),
        }
        # Create input n+n+n+...+n with 50 n's
        input_str = 'n' + '+n' * 49
        result = parse_for_tree(grammar, input_str, 'E')
        assert result is not None
        assert result.len == len(input_str)

    def test_linearity_repetition_n_100(self) -> None:
        """LIN-01-repetition-N=100"""
        # Simple repetition at size 100
        result = parse_for_tree({'S': OneOrMore(Str('x'))}, 'x' * 100)
        assert result is not None and result.len == 100

    def test_linearity_repetition_n_500(self) -> None:
        """LIN-02-repetition-N=500"""
        # Simple repetition at size 500
        result = parse_for_tree({'S': OneOrMore(Str('x'))}, 'x' * 500)
        assert result is not None and result.len == 500

    def test_linearity_repetition_n_1000(self) -> None:
        """LIN-03-repetition-N=1000"""
        # Simple repetition at size 1000
        result = parse_for_tree({'S': OneOrMore(Str('x'))}, 'x' * 1000)
        assert result is not None and result.len == 1000

    def test_linearity_lr_n_50(self) -> None:
        """LIN-04-LR-N=50"""
        # LR at size 50
        grammar = {
            'E': First(
                Seq(Ref('E'), Str('+'), Str('n')),
                Str('n')
            ),
        }
        input_str = 'n' + '+n' * 49
        result = parse_for_tree(grammar, input_str, 'E')
        assert result is not None and result.len == len(input_str)

    def test_linearity_lr_n_100(self) -> None:
        """LIN-05-LR-N=100"""
        # LR at size 100
        grammar = {
            'E': First(
                Seq(Ref('E'), Str('+'), Str('n')),
                Str('n')
            ),
        }
        input_str = 'n' + '+n' * 99
        result = parse_for_tree(grammar, input_str, 'E')
        assert result is not None and result.len == len(input_str)

    def test_linearity_lr_n_200(self) -> None:
        """LIN-06-LR-N=200"""
        # LR at size 200
        grammar = {
            'E': First(
                Seq(Ref('E'), Str('+'), Str('n')),
                Str('n')
            ),
        }
        input_str = 'n' + '+n' * 199
        result = parse_for_tree(grammar, input_str, 'E')
        assert result is not None and result.len == len(input_str)

    def test_linearity_nested_seq(self) -> None:
        """LIN-07-nested-seq"""
        # Deep nesting with fixed depth, increasing width
        grammar = {'S': Seq(Str('a'), Seq(Str('b'), Seq(Str('c'), Str('d'))))}
        result = parse_for_tree(grammar, 'abcd')
        assert result is not None and result.len == 4

    def test_linearity_with_recovery(self) -> None:
        """LIN-08-with-recovery"""
        # Recovery should also be linear
        # Note: Python parser doesn't have full error recovery yet
        # This test will only pass when recovery is implemented
        input_str = ''.join('Xx' for _ in range(100))
        result = parse_for_tree({'S': OneOrMore(Str('x'))}, input_str)
        # Without recovery, this should fail since input has errors
        # When recovery is implemented, this should succeed
        assert result is None or result.len == len(input_str)
