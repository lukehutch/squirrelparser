"""MetaGrammar - Rule References Tests"""
from squirrelparser import Parser
from squirrelparser.meta_grammar import MetaGrammar


class TestMetaGrammarRuleReferences:
    """MetaGrammar - Rule References"""

    def test_simple_rule_reference(self) -> None:
        """simple rule reference"""
        grammar = '''
            Main <- A "b";
            A <- "a";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(rules=rules, input_str='ab')
        result, _ = parser.parse('Main')
        assert result is not None
        assert result.len == 2

    def test_multiple_rule_references(self) -> None:
        """multiple rule references"""
        grammar = '''
            Main <- A B C;
            A <- "a";
            B <- "b";
            C <- "c";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(rules=rules, input_str='abc')
        result, _ = parser.parse('Main')
        assert result is not None
        assert result.len == 3

    def test_recursive_rule(self) -> None:
        """recursive rule"""
        grammar = '''
            List <- "a" List / "a";
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(rules=rules, input_str='a')
        result, _ = parser.parse('List')
        assert result is not None
        assert result.len == 1

        parser = Parser(rules=rules, input_str='aaa')
        result, _ = parser.parse('List')
        assert result is not None
        assert result.len == 3

    def test_mutually_recursive_rules(self) -> None:
        """mutually recursive rules"""
        grammar = '''
            A <- "a" B / "a";
            B <- "b" A / "b";
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(rules=rules, input_str='aba')
        result, _ = parser.parse('A')
        assert result is not None
        assert result.len == 3

        parser = Parser(rules=rules, input_str='bab')
        result, _ = parser.parse('B')
        assert result is not None
        assert result.len == 3

    def test_left_recursive_rule(self) -> None:
        """left-recursive rule"""
        grammar = '''
            Expr <- Expr "+" "n" / "n";
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(rules=rules, input_str='n')
        result, _ = parser.parse('Expr')
        assert result is not None
        assert result.len == 1

        parser = Parser(rules=rules, input_str='n+n')
        result, _ = parser.parse('Expr')
        assert result is not None
        assert result.len == 3

        parser = Parser(rules=rules, input_str='n+n+n')
        result, _ = parser.parse('Expr')
        assert result is not None
        assert result.len == 5
