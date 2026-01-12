"""CST - Concrete Syntax Tree tests."""

import pytest

from squirrelparser import (
    ASTNode,
    CSTNode,
    CSTNodeFactoryFn,
    squirrel_parse_cst,
    squirrel_parse_pt,
)


class SimpleCST(CSTNode):
    """Simple test CST node for testing."""

    def __init__(self, ast_node: ASTNode, children: list[CSTNode], value: str | None = None):
        super().__init__(ast_node, children)
        self.value = value


class TestCST:
    """CST - Concrete Syntax Tree tests."""

    def test_parse_tree_methods_exist_and_work(self):
        grammar = """
            Greeting <- "hello" Name;
            Name <- [a-z]+;
        """

        parse_result = squirrel_parse_pt(
            grammar_spec=grammar,
            top_rule_name='Greeting',
            input='helloworld',
        )

        assert parse_result is not None
        assert not parse_result.root.is_mismatch
        assert len(parse_result.get_syntax_errors()) == 0

    def test_cst_factory_validation_catches_missing_factories(self):
        grammar = """
            Greeting <- "hello" Name;
            Name <- [a-z]+;
        """

        # Only provide factory for Greeting, missing Name and <Terminal>
        factories: dict[str, CSTNodeFactoryFn] = {
            'Greeting': lambda ast_node, children: SimpleCST(ast_node, children),
        }

        with pytest.raises(ValueError):
            squirrel_parse_cst(
                grammar_spec=grammar,
                top_rule_name='Greeting',
                factories=factories,
                input='hello world',
            )

    def test_cst_factory_validation_catches_extra_factories(self):
        grammar = """
            Greeting <- "hello";
        """

        # Provide factory for Greeting and extra Name
        factories: dict[str, CSTNodeFactoryFn] = {
            'Greeting': lambda ast_node, children: SimpleCST(ast_node, children),
            'ExtraRule': lambda ast_node, children: SimpleCST(ast_node, children),
        }

        with pytest.raises(ValueError):
            squirrel_parse_cst(
                grammar_spec=grammar,
                top_rule_name='Greeting',
                factories=factories,
                input='hello',
            )

    def test_basic_cst_construction_works(self):
        grammar = """
            Main <- Item;
            Item <- "test";
        """

        factories: dict[str, CSTNodeFactoryFn] = {
            'Main': lambda ast_node, children: SimpleCST(ast_node, children),
            'Item': lambda ast_node, children: SimpleCST(ast_node, children, 'test'),
            '<Terminal>': lambda ast_node, children: SimpleCST(ast_node, children),
        }

        cst = squirrel_parse_cst(
            grammar_spec=grammar,
            top_rule_name='Main',
            factories=factories,
            input='test',
        )

        assert cst is not None
        assert cst.label == 'Main'

    def test_squirrel_parse_is_the_main_public_api(self):
        grammar = """
            Test <- "hello";
        """

        factories: dict[str, CSTNodeFactoryFn] = {
            'Test': lambda ast_node, children: SimpleCST(ast_node, children, 'hello'),
            '<Terminal>': lambda ast_node, children: SimpleCST(ast_node, children),
        }

        cst = squirrel_parse_cst(
            grammar_spec=grammar,
            top_rule_name='Test',
            factories=factories,
            input='hello',
        )

        assert cst is not None
        assert cst.label == 'Test'

    def test_transparent_rules_are_excluded_from_cst_factories(self):
        grammar = """
            Expr <- ~Whitespace Term ~Whitespace;
            ~Whitespace <- ' '*;
            Term <- "x";
        """

        # Should only need factories for Expr and Term, not Whitespace (which is transparent)
        factories: dict[str, CSTNodeFactoryFn] = {
            'Expr': lambda ast_node, children: SimpleCST(ast_node, children),
            'Term': lambda ast_node, children: SimpleCST(ast_node, children, 'x'),
            '<Terminal>': lambda ast_node, children: SimpleCST(ast_node, children),
        }

        # This should work without a factory for Whitespace
        cst = squirrel_parse_cst(
            grammar_spec=grammar,
            top_rule_name='Expr',
            factories=factories,
            input=' x ',
        )

        assert cst is not None
