"""Tests for the CST (Concrete Syntax Tree) API"""

import pytest
from squirrelparser import (
    MetaGrammar,
    CSTNode,
    CSTNodeFactory,
    CSTFactoryValidationException,
    DuplicateRuleNameException,
    squirrel_parse,
    parse_to_match_result_for_testing,
    parse_with_rule_map_for_testing,
)


class SimpleCST(CSTNode):
    """Simple test CST node for testing"""

    def __init__(self, name: str, children: list[CSTNode] | None = None, value: str | None = None) -> None:
        super().__init__(name)
        self.children = children or []
        self.value = value

    def __str__(self) -> str:
        return self.value if self.value else self.name


class TestCST:
    """Tests for CST functionality"""

    def test_parse_tree_methods_exist_and_work(self) -> None:
        """parse tree methods exist and work"""
        grammar = '''
            Greeting <- "hello" Name;
            Name <- [a-z]+;
        '''

        rules = MetaGrammar.parse_grammar(grammar)
        pt, errors = parse_to_match_result_for_testing(rules, 'Greeting', 'helloworld')

        assert pt is not None
        assert not pt.is_mismatch
        assert len(errors) == 0

    def test_cst_factory_validation_catches_missing_factories(self) -> None:
        """CST factory validation catches missing factories"""
        grammar = '''
            Greeting <- "hello" Name;
            Name <- [a-z]+;
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        # Only provide factory for Greeting, missing Name
        factories = [
            CSTNodeFactory(
                'Greeting',
                ['Name'],
                lambda ruleName, expectedChildren, children: SimpleCST(ruleName, children),
            ),
        ]

        with pytest.raises(CSTFactoryValidationException):
            parse_with_rule_map_for_testing(rules, 'Greeting', 'hello world', factories)  # type: ignore[arg-type]

    def test_cst_factory_validation_catches_extra_factories(self) -> None:
        """CST factory validation catches extra factories"""
        grammar = '''
            Greeting <- "hello";
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        # Provide factory for Greeting and extra Name
        factories = [
            CSTNodeFactory(
                'Greeting',
                [],
                lambda ruleName, expectedChildren, children: SimpleCST(ruleName),
            ),
            CSTNodeFactory(
                'ExtraRule',
                [],
                lambda ruleName, expectedChildren, children: SimpleCST(ruleName),
            ),
        ]

        with pytest.raises(CSTFactoryValidationException):
            parse_with_rule_map_for_testing(rules, 'Greeting', 'hello', factories)  # type: ignore[arg-type]

    def test_basic_cst_construction_works(self) -> None:
        """basic CST construction works"""
        grammar = '''
            Main <- Item;
            Item <- "test";
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        factories = [
            CSTNodeFactory(
                'Main',
                ['Item'],
                lambda ruleName, expectedChildren, children: SimpleCST(ruleName, children),
            ),
            CSTNodeFactory(
                'Item',
                ['<Terminal>'],
                lambda ruleName, expectedChildren, children: SimpleCST(ruleName, value='test'),
            ),
        ]

        cst, errors = parse_with_rule_map_for_testing(rules, 'Main', 'test', factories)  # type: ignore[arg-type]

        assert cst is not None
        assert cst.name == 'Main'
        assert len(errors) == 0

    def test_squirrel_parse_is_the_main_public_api(self) -> None:
        """squirrelParse is the main public API"""
        grammar = '''
            Test <- "hello";
        '''

        factories = [
            CSTNodeFactory(
                'Test',
                ['<Terminal>'],
                lambda ruleName, expectedChildren, children: SimpleCST(ruleName, value='hello'),
            ),
        ]

        cst, errors = squirrel_parse(grammar, 'hello', 'Test', factories)  # type: ignore[arg-type]

        assert cst is not None
        assert cst.name == 'Test'
        assert len(errors) == 0

    def test_duplicate_rule_names_throw_exception(self) -> None:
        """duplicate rule names throw DuplicateRuleNameException"""
        grammar = '''
            Main <- "test";
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        # Provide two factories with the same rule name
        factories = [
            CSTNodeFactory(
                'Main',
                [],
                lambda ruleName, expectedChildren, children: SimpleCST(ruleName),
            ),
            CSTNodeFactory(
                'Main',
                [],
                lambda ruleName, expectedChildren, children: SimpleCST(ruleName),
            ),
        ]

        with pytest.raises(DuplicateRuleNameException):
            parse_with_rule_map_for_testing(rules, 'Main', 'test', factories)  # type: ignore[arg-type]

    def test_transparent_rules_are_excluded_from_cst_factories(self) -> None:
        """transparent rules are excluded from CST factories"""
        grammar = '''
            Expr <- ~Whitespace Term ~Whitespace;
            ~Whitespace <- ' '*;
            Term <- "x";
        '''

        rules = MetaGrammar.parse_grammar(grammar)

        # Should only need factories for Expr and Term, not Whitespace (which is transparent)
        factories = [
            CSTNodeFactory(
                'Expr',
                ['Term'],
                lambda ruleName, expectedChildren, children: SimpleCST(ruleName, children),
            ),
            CSTNodeFactory(
                'Term',
                ['<Terminal>'],
                lambda ruleName, expectedChildren, children: SimpleCST(ruleName, value='x'),
            ),
        ]

        # This should work without a factory for Whitespace
        cst, errors = parse_with_rule_map_for_testing(rules, 'Expr', ' x ', factories)  # type: ignore[arg-type]

        assert cst is not None
        assert len(errors) == 0
