"""MetaGrammar - AST Building Tests"""
from squirrelparser import Parser
from squirrelparser.meta_grammar import MetaGrammar


class TestMetaGrammarASTBuilding:
    """MetaGrammar - AST Building"""

    def test_ast_structure_for_simple_grammar(self) -> None:
        """AST structure for simple grammar"""
        grammar = '''
            Main <- A B;
            A <- "a";
            B <- "b";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(rules=rules, input_str='ab')
        ast, _ = parser.parse_to_ast('Main')

        assert ast is not None
        assert ast.label == 'Main'
        assert len(ast.children) == 2
        assert ast.children[0].label == 'A'
        assert ast.children[1].label == 'B'

    def test_ast_flattens_combinator_nodes(self) -> None:
        """AST flattens combinator nodes"""
        grammar = '''
            Main <- A+ B*;
            A <- "a";
            B <- "b";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(rules=rules, input_str='aaabbb')
        ast, _ = parser.parse_to_ast('Main')

        assert ast is not None
        assert ast.label == 'Main'

        # Should have flattened A and B children, not intermediate repetition nodes
        a_nodes = sum(1 for n in ast.children if n.label == 'A')
        b_nodes = sum(1 for n in ast.children if n.label == 'B')
        assert a_nodes == 3
        assert b_nodes == 3

    def test_ast_text_extraction(self) -> None:
        """AST text extraction"""
        grammar = '''
            Number <- [0-9]+;
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(rules=rules, input_str='123')
        ast, _ = parser.parse_to_ast('Number')

        assert ast is not None
        assert ast.text == '123'

    def test_ast_for_nested_structures(self) -> None:
        """AST for nested structures"""
        grammar = '''
            Expr <- Term (("+" / "-") Term)*;
            Term <- [0-9]+;
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(rules=rules, input_str='1+2-3')
        ast, _ = parser.parse_to_ast('Expr')

        assert ast is not None
        assert ast.label == 'Expr'

        # Should have Terms as direct children (flattened)
        term_nodes = [n for n in ast.children if n.label == 'Term']
        assert len(term_nodes) >= 1

    def test_ast_pretty_printing(self) -> None:
        """AST pretty printing"""
        grammar = '''
            Main <- A B;
            A <- "a";
            B <- "b";
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        parser = Parser(rules=rules, input_str='ab')
        ast, _ = parser.parse_to_ast('Main')

        assert ast is not None
        pretty_string = ast.to_pretty_string()
        assert 'Main' in pretty_string
        assert 'A' in pretty_string
        assert 'B' in pretty_string
