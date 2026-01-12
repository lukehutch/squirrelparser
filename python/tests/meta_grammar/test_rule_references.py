"""Tests for MetaGrammar rule references."""

from squirrelparser import MetaGrammar, Parser


class TestRuleReferences:
    """MetaGrammar - Rule References tests."""

    def test_simple_rule_reference(self):
        grammar = '''
            Main <- A "b";
            A <- "a";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(top_rule_name='Main', rules=rules, input='ab')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 2

    def test_multiple_rule_references(self):
        grammar = '''
            Main <- A B C;
            A <- "a";
            B <- "b";
            C <- "c";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(top_rule_name='Main', rules=rules, input='abc')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 3

    def test_recursive_rule(self):
        grammar = '''
            List <- "a" List / "a";
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(top_rule_name='List', rules=rules, input='a')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 1

        parser = Parser(top_rule_name='List', rules=rules, input='aaa')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 3

    def test_mutually_recursive_rules(self):
        grammar = '''
            A <- "a" B / "a";
            B <- "b" A / "b";
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(top_rule_name='A', rules=rules, input='aba')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 3

        parser = Parser(top_rule_name='A', rules=rules, input='bab')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 3

    def test_left_recursive_rule(self):
        grammar = '''
            Expr <- Expr "+" "n" / "n";
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        parser = Parser(top_rule_name='Expr', rules=rules, input='n')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 1

        parser = Parser(top_rule_name='Expr', rules=rules, input='n+n')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 3

        parser = Parser(top_rule_name='Expr', rules=rules, input='n+n+n')
        parse_result = parser.parse()
        result = parse_result.root
        assert result is not None
        assert result.len == 5
