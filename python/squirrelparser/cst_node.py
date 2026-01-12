"""AST and CST node classes."""

from __future__ import annotations
from abc import ABC
from typing import TYPE_CHECKING, Callable, Generic, TypeVar

from .match_result import SyntaxError, MatchResult
from .terminals import Terminal
from .combinators import Ref

if TYPE_CHECKING:
    from .parser import ParseResult

T = TypeVar('T', bound='Node')


# ------------------------------------------------------------------------------------------------------------------


class Node(ABC, Generic[T]):
    """Base class for AST and CST nodes."""

    __slots__ = ('label', 'pos', 'len', 'syntax_error', 'children')

    def __init__(
        self,
        *,
        label: str,
        pos: int,
        length: int,
        syntax_error: SyntaxError | None,
        children: list[T],
    ) -> None:
        self.label = label
        self.pos = pos
        self.len = length
        self.syntax_error = syntax_error
        self.children = children

    def get_input_span(self, input_str: str) -> str:
        return input_str[self.pos : self.pos + self.len]

    def __repr__(self) -> str:
        return f'{self.label}: pos: {self.pos}, len: {self.len}'

    def to_pretty_string(self, input_str: str) -> str:
        buffer: list[str] = []
        self._build_tree(input_str, '', buffer, True)
        return ''.join(buffer)

    def _build_tree(self, input_str: str, prefix: str, buffer: list[str], is_root: bool) -> None:
        if not is_root:
            buffer.append('\n')
        buffer.append(prefix)
        buffer.append(self.label)
        if not self.children:
            buffer.append(f': "{self.get_input_span(input_str)}"')

        for i, child in enumerate(self.children):
            is_last = i == len(self.children) - 1
            child_prefix = prefix + ('' if is_root else ('    ' if is_last else '|   '))
            connector = '`---' if is_last else '|---'

            buffer.append('\n')
            buffer.append(prefix)
            buffer.append('' if is_root else connector)

            child._build_tree(input_str, child_prefix, buffer, False)


# ------------------------------------------------------------------------------------------------------------------


class ASTNode(Node['ASTNode']):
    """An AST node representing either a rule match or a terminal match."""

    def __init__(
        self,
        *,
        label: str,
        pos: int,
        length: int,
        syntax_error: SyntaxError | None = None,
        children: list[ASTNode] | None = None,
    ) -> None:
        super().__init__(
            label=label,
            pos=pos,
            length=length,
            syntax_error=syntax_error,
            children=children if children is not None else [],
        )

    @classmethod
    def terminal(cls, terminal_match: MatchResult) -> ASTNode:
        return cls(
            label=Terminal.node_label,
            pos=terminal_match.pos,
            length=terminal_match.len,
        )

    @classmethod
    def non_terminal(cls, label: str, children: list[ASTNode]) -> ASTNode:
        if not children:
            raise ValueError('children must not be empty')
        pos = children[0].pos
        length = children[-1].pos + children[-1].len - pos
        return cls(label=label, pos=pos, length=length, children=children)

    @classmethod
    def syntax_error_node(cls, se: SyntaxError) -> ASTNode:
        return cls(
            label=SyntaxError.node_label,
            pos=se.pos,
            length=se.len,
            syntax_error=se,
        )


# ------------------------------------------------------------------------------------------------------------------


def build_ast(parse_result: ParseResult) -> ASTNode:
    """Build an AST from a parse tree."""
    extra_node = (
        ASTNode.syntax_error_node(parse_result.unmatched_input)
        if parse_result.unmatched_input is not None
        else None
    )

    return _new_ast_node(
        parse_result.top_rule_name,
        parse_result.root,
        parse_result.transparent_rules,
        extra_node,
    )


def _new_ast_node(
    label: str,
    refd_match_result: MatchResult,
    transparent_rules: set[str],
    add_extra_ast_node: ASTNode | None,
) -> ASTNode:
    child_ast_nodes: list[ASTNode] = []
    _collect_child_ast_nodes(refd_match_result, child_ast_nodes, transparent_rules)
    if add_extra_ast_node is not None:
        child_ast_nodes.append(add_extra_ast_node)
    return ASTNode.non_terminal(label, child_ast_nodes)


def _collect_child_ast_nodes(
    match_result: MatchResult,
    collected_ast_nodes: list[ASTNode],
    transparent_rules: set[str],
) -> None:
    if match_result.is_mismatch:
        return
    if isinstance(match_result, SyntaxError):
        collected_ast_nodes.append(ASTNode.syntax_error_node(match_result))
    else:
        clause = match_result.clause
        if isinstance(clause, Terminal):
            collected_ast_nodes.append(ASTNode.terminal(match_result))
        elif isinstance(clause, Ref):
            if clause.rule_name not in transparent_rules:
                collected_ast_nodes.append(
                    _new_ast_node(
                        clause.rule_name,
                        match_result.sub_clause_matches[0],
                        transparent_rules,
                        None,
                    )
                )
        else:
            for sub_clause_match in match_result.sub_clause_matches:
                _collect_child_ast_nodes(sub_clause_match, collected_ast_nodes, transparent_rules)


# ------------------------------------------------------------------------------------------------------------------


class CSTNode(Node['CSTNode'], ABC):
    """Base class for CST nodes."""

    def __init__(self, ast_node: ASTNode, children: list[CSTNode]) -> None:
        super().__init__(
            label=ast_node.label,
            pos=ast_node.pos,
            length=ast_node.len,
            syntax_error=ast_node.syntax_error,
            children=children,
        )


# ------------------------------------------------------------------------------------------------------------------


class CSTNodeFactory:
    """Factory for creating CST nodes from AST nodes."""

    __slots__ = ('rule_name', 'factory')

    def __init__(
        self,
        *,
        rule_name: str,
        factory: Callable[[ASTNode, list[CSTNode]], CSTNode],
    ) -> None:
        self.rule_name = rule_name
        self.factory = factory


# ------------------------------------------------------------------------------------------------------------------


def build_cst(ast: ASTNode, factories: list[CSTNodeFactory], allow_syntax_errors: bool) -> CSTNode:
    """Build a CST from an AST."""
    factories_map: dict[str, CSTNodeFactory] = {}
    for factory in factories:
        if factory.rule_name in factories_map:
            raise ValueError(f'Duplicate factory for rule "{factory.rule_name}"')
        factories_map[factory.rule_name] = factory
    return _build_cst_internal(ast, factories_map, allow_syntax_errors)


def _build_cst_internal(
    ast: ASTNode,
    factories_map: dict[str, CSTNodeFactory],
    allow_syntax_errors: bool,
) -> CSTNode:
    if ast.syntax_error is not None:
        if not allow_syntax_errors:
            raise ValueError(f'Syntax error: {ast.syntax_error}')
        error_factory = factories_map.get('<SyntaxError>')
        if error_factory is None:
            raise ValueError('No factory found for <SyntaxError>')
        return error_factory.factory(ast, [])

    factory = factories_map.get(ast.label)

    if factory is None and ast.label == Terminal.node_label:
        factory = factories_map.get('<Terminal>')

    if factory is None:
        raise ValueError(f'No factory found for rule "{ast.label}"')

    child_cst_nodes = [_build_cst_internal(child, factories_map, allow_syntax_errors) for child in ast.children]
    return factory.factory(ast, child_cst_nodes)
