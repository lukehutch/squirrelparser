"""CST/AST Creation Scenarios tests."""


from squirrelparser import (
    ASTNode,
    CSTNode,
    CSTNodeFactoryFn,
    squirrel_parse_cst,
)


# ============================================================================
# Custom CST Node Classes for Testing
# ============================================================================


class InclusiveNode(CSTNode):
    """A simple CST node that includes all its children."""

    def __init__(
        self, ast_node: ASTNode, children: list[CSTNode], computed_value: str | None = None
    ):
        super().__init__(ast_node, children)
        self.computed_value = computed_value


class ComputedNode(CSTNode):
    """A CST node that computes from children without storing them."""

    def __init__(
        self, ast_node: ASTNode, children: list[CSTNode], child_count: int, concatenated: str
    ):
        super().__init__(ast_node, [])
        self.child_count = child_count
        self.concatenated = concatenated


class TransformedNode(CSTNode):
    """A CST node that transforms children."""

    def __init__(
        self, ast_node: ASTNode, children: list[CSTNode], transformed_labels: list[str]
    ):
        super().__init__(ast_node, children)
        self.transformed_labels = transformed_labels


class SelectiveNode(CSTNode):
    """A CST node that selects specific children."""

    def __init__(
        self, ast_node: ASTNode, children: list[CSTNode], selected_children: list[CSTNode]
    ):
        super().__init__(ast_node, selected_children)
        self.selected_children = selected_children


class TerminalNode(CSTNode):
    """A CST node for terminals."""

    def __init__(self, ast_node: ASTNode, text: str):
        super().__init__(ast_node, [])
        self.text = text


class ErrorNode(CSTNode):
    """A CST node for syntax errors."""

    def __init__(self, ast_node: ASTNode, error_message: str):
        super().__init__(ast_node, [])
        self.error_message = error_message


class TestCSTAstCreation:
    """CST/AST Creation Scenarios tests."""

    # ========================================================================
    # Scenario 1: Factory includes all children (inclusive)
    # ========================================================================

    def test_factory_includes_all_children(self):
        grammar = """
            Expr <- Term ('+' Term)*;
            Term <- [0-9]+;
        """

        factories: dict[str, CSTNodeFactoryFn] = {
            'Expr': lambda ast_node, children: InclusiveNode(ast_node, children),
            'Term': lambda ast_node, children: InclusiveNode(ast_node, children),
            '<Terminal>': lambda ast_node, children: InclusiveNode(ast_node, children),
        }

        cst = squirrel_parse_cst(
            grammar_spec=grammar,
            top_rule_name='Expr',
            factories=factories,
            input='1+2',
        )

        assert cst is not None
        assert isinstance(cst, InclusiveNode)
        assert cst.label == 'Expr'
        assert len(cst.children) > 0

    # ========================================================================
    # Scenario 2: Factory computes from children without storing them
    # ========================================================================

    def test_factory_computes_from_children_without_storing_them(self):
        grammar = """
            Sum <- Number ('+' Number)*;
            Number <- [0-9]+;
        """

        factories: dict[str, CSTNodeFactoryFn] = {
            'Sum': lambda ast_node, children: ComputedNode(
                ast_node,
                children,
                len(children),
                ','.join(c.label for c in children),
            ),
            'Number': lambda ast_node, children: ComputedNode(ast_node, children, 0, 'Number'),
            '<Terminal>': lambda ast_node, children: ComputedNode(ast_node, children, 0, 'Terminal'),
        }

        cst = squirrel_parse_cst(
            grammar_spec=grammar,
            top_rule_name='Sum',
            factories=factories,
            input='42',
        )

        assert cst is not None
        assert isinstance(cst, ComputedNode)
        computed = cst
        assert computed.child_count is not None
        assert computed.concatenated != ''

    # ========================================================================
    # Scenario 3: Factory transforms children
    # ========================================================================

    def test_factory_transforms_children(self):
        grammar = """
            List <- Element (',' Element)*;
            Element <- [a-z]+;
        """

        factories: dict[str, CSTNodeFactoryFn] = {
            'List': lambda ast_node, children: TransformedNode(
                ast_node, children, [c.label.upper() for c in children]
            ),
            'Element': lambda ast_node, children: TransformedNode(ast_node, children, ['ELEMENT']),
            '<Terminal>': lambda ast_node, children: TransformedNode(ast_node, children, ['TERMINAL']),
        }

        cst = squirrel_parse_cst(
            grammar_spec=grammar,
            top_rule_name='List',
            factories=factories,
            input='abc',
        )

        assert cst is not None
        assert isinstance(cst, TransformedNode)
        transformed = cst
        assert len(transformed.transformed_labels) > 0

    # ========================================================================
    # Scenario 4: Factory selects specific children
    # ========================================================================

    def test_factory_selects_specific_children(self):
        grammar = """
            Pair <- '(' First ',' Second ')';
            First <- [a-z]+;
            Second <- [0-9]+;
        """

        factories: dict[str, CSTNodeFactoryFn] = {
            'Pair': lambda ast_node, children: SelectiveNode(
                ast_node,
                children,
                [c for c in children if c.label in ('First', 'Second')],
            ),
            'First': lambda ast_node, children: SelectiveNode(ast_node, children, children),
            'Second': lambda ast_node, children: SelectiveNode(ast_node, children, children),
            '<Terminal>': lambda ast_node, children: SelectiveNode(ast_node, children, []),
        }

        cst = squirrel_parse_cst(
            grammar_spec=grammar,
            top_rule_name='Pair',
            factories=factories,
            input='(abc,123)',
        )

        assert cst is not None
        assert isinstance(cst, SelectiveNode)
        selective = cst
        # Should have 2 selected children: First and Second
        assert len(selective.selected_children) == 2

    # ========================================================================
    # Scenario 5: Terminal handling
    # ========================================================================

    def test_terminals_are_handled_by_factory(self):
        grammar = """
            Text <- Word;
            Word <- [a-z]+;
        """

        factories: dict[str, CSTNodeFactoryFn] = {
            'Text': lambda ast_node, children: InclusiveNode(ast_node, children),
            'Word': lambda ast_node, children: InclusiveNode(ast_node, children),
            '<Terminal>': lambda ast_node, children: TerminalNode(ast_node, 'terminal'),
        }

        cst = squirrel_parse_cst(
            grammar_spec=grammar,
            top_rule_name='Text',
            factories=factories,
            input='hello',
        )

        assert cst is not None
        # Text should have Word children, which have terminal children
        assert len(cst.children) > 0

    # ========================================================================
    # Scenario 6: Syntax error handling
    # ========================================================================

    def test_syntax_errors_are_handled_when_allow_syntax_errors_is_true(self):
        grammar = """
            Expr <- Number;
            Number <- [0-9]+;
        """

        factories: dict[str, CSTNodeFactoryFn] = {
            'Expr': lambda ast_node, children: InclusiveNode(ast_node, children),
            'Number': lambda ast_node, children: InclusiveNode(ast_node, children),
            '<Terminal>': lambda ast_node, children: InclusiveNode(ast_node, children),
            '<SyntaxError>': lambda ast_node, children: ErrorNode(
                ast_node, f'Syntax error at {ast_node.pos}'
            ),
        }

        cst = squirrel_parse_cst(
            grammar_spec=grammar,
            top_rule_name='Expr',
            factories=factories,
            input='abc',
            allow_syntax_errors=True,
        )

        assert cst is not None
        # With syntax errors allowed, we should get an error node

    # ========================================================================
    # Scenario 7: Nested structures with mixed approaches
    # ========================================================================

    def test_nested_structures_with_mixed_factory_approaches(self):
        grammar = """
            Doc <- Section+;
            Section <- Title;
            Title <- [a-z]+;
        """

        factories: dict[str, CSTNodeFactoryFn] = {
            # Inclusive factory
            'Doc': lambda ast_node, children: InclusiveNode(ast_node, children),
            # Selective factory
            'Section': lambda ast_node, children: SelectiveNode(
                ast_node,
                children,
                [c for c in children if c.label == 'Title'],
            ),
            # Computed factory
            'Title': lambda ast_node, children: ComputedNode(
                ast_node, children, len(children), 'Title'
            ),
            # Terminal factory
            '<Terminal>': lambda ast_node, children: TerminalNode(ast_node, 'terminal'),
        }

        cst = squirrel_parse_cst(
            grammar_spec=grammar,
            top_rule_name='Doc',
            factories=factories,
            input='abc',
        )

        assert cst is not None
        assert isinstance(cst, InclusiveNode)

    # ========================================================================
    # Scenario 8: Empty alternatives and optional matching
    # ========================================================================

    def test_handles_optional_matches_without_errors(self):
        grammar = """
            Sentence <- Word (' ' Word)*;
            Word <- [a-z]+;
        """

        factories: dict[str, CSTNodeFactoryFn] = {
            'Sentence': lambda ast_node, children: InclusiveNode(ast_node, children),
            'Word': lambda ast_node, children: InclusiveNode(ast_node, children),
            '<Terminal>': lambda ast_node, children: InclusiveNode(ast_node, children),
        }

        cst = squirrel_parse_cst(
            grammar_spec=grammar,
            top_rule_name='Sentence',
            factories=factories,
            input='hello world test',
        )

        assert cst is not None
