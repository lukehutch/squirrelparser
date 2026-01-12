"""Tests for MetaGrammar AST building."""

from squirrelparser import MetaGrammar, Parser, build_ast


class TestAstBuilding:
    """MetaGrammar - AST Building tests."""

    def test_ast_structure_for_simple_grammar(self):
        grammar = '''
            Main <- A B;
            A <- "a";
            B <- "b";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(top_rule_name='Main', rules=rules, input='ab')
        parse_result = parser.parse()
        ast = build_ast(parse_result)

        assert ast is not None
        assert ast.label == 'Main'
        assert len(ast.children) == 2
        assert ast.children[0].label == 'A'
        assert ast.children[1].label == 'B'

    def test_ast_flattens_combinator_nodes(self):
        grammar = '''
            Main <- A+ B*;
            A <- "a";
            B <- "b";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(top_rule_name='Main', rules=rules, input='aaabbb')
        parse_result = parser.parse()
        ast = build_ast(parse_result)

        assert ast is not None
        assert ast.label == 'Main'

        # Should have flattened A and B children, not intermediate repetition nodes
        a_nodes = sum(1 for n in ast.children if n.label == 'A')
        b_nodes = sum(1 for n in ast.children if n.label == 'B')
        assert a_nodes == 3
        assert b_nodes == 3

    def test_ast_text_extraction(self):
        grammar = '''
            Number <- [0-9]+;
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(top_rule_name='Number', rules=rules, input='123')
        parse_result = parser.parse()
        ast = build_ast(parse_result)

        assert ast is not None
        # ast.text property not available; extract from input using position and length
        text = parse_result.input[0:parse_result.root.len]
        assert text == '123'

    def test_ast_for_nested_structures(self):
        grammar = '''
            Expr <- Term (("+" / "-") Term)*;
            Term <- [0-9]+;
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(top_rule_name='Expr', rules=rules, input='1+2-3')
        parse_result = parser.parse()
        ast = build_ast(parse_result)

        assert ast is not None
        assert ast.label == 'Expr'

        # Should have Terms as direct children (flattened)
        term_nodes = [n for n in ast.children if n.label == 'Term']
        assert len(term_nodes) >= 1

    def test_ast_pretty_printing(self):
        grammar = '''
            Main <- A B;
            A <- "a";
            B <- "b";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(top_rule_name='Main', rules=rules, input='ab')
        parse_result = parser.parse()
        ast = build_ast(parse_result)

        assert ast is not None
        pretty_string = ast.to_pretty_string(parse_result.input)
        assert 'Main' in pretty_string
        assert 'A' in pretty_string
        assert 'B' in pretty_string

    def test_ast_allows_zero_children_when_all_sub_rules_are_transparent(self):
        # When a rule only contains transparent rules, the AST node has zero children
        grammar = '''
            Main <- ~A;
            ~A <- "a";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(top_rule_name='Main', rules=rules, input='a')
        parse_result = parser.parse()
        ast = build_ast(parse_result)

        assert ast is not None
        assert ast.label == 'Main'
        assert ast.pos == 0
        assert ast.len == 1
        # Main has zero children because A is transparent
        assert len(ast.children) == 0
