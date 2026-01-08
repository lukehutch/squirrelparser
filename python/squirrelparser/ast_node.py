"""AST node representation for the Squirrel Parser."""

from __future__ import annotations
from dataclasses import dataclass
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .match_result import MatchResult

from .terminals import Str, Char, CharRange, AnyChar
from .combinators import Ref
from .match_result import SyntaxError as SyntaxErrorNode


@dataclass
class ASTNode:
    """An AST node representing either a rule match or a terminal match.

    AST nodes have:
    - A label (the rule name or terminal type)
    - A position and length in the input
    - Children (other AST nodes)
    - The matched text
    """

    label: str
    pos: int
    len: int
    children: list[ASTNode]
    _input: str

    @property
    def text(self) -> str:
        """Get the text matched by this node."""
        return self._input[self.pos:self.pos + self.len]

    def get_child(self, index: int) -> ASTNode:
        """Get a child by index."""
        return self.children[index]

    def __str__(self) -> str:
        return f'ASTNode({self.label}, "{self.text}", children: {len(self.children)})'

    def to_pretty_string(self, indent: int = 0) -> str:
        """Pretty print the AST tree."""
        lines = []
        prefix = '  ' * indent
        if self.children:
            lines.append(f'{prefix}{self.label}')
        else:
            lines.append(f'{prefix}{self.label}: "{self.text}"')

        for child in self.children:
            lines.append(child.to_pretty_string(indent + 1))

        return '\n'.join(lines)


def build_ast(match: MatchResult | None, input_str: str, top_rule: str | None = None) -> ASTNode | None:
    """Build an AST from a parse tree.

    The AST only includes:
    - Ref nodes (rule references) with their rule name as label
    - Terminal nodes (Str, Char, CharRange, AnyChar) with text as label

    All intermediate combinator nodes (Seq, First, etc.) are flattened out,
    with their children promoted to be children of the nearest ancestral rule.

    For top-level combinator matches, creates a synthetic node with the given top_rule label.

    Args:
        match: The match result
        input_str: The input string
        top_rule: Optional rule name for synthetic top-level nodes (combinators)

    Returns:
        The AST node, or None if match is None/mismatch and no top_rule provided
    """
    if match is None or match.is_mismatch:
        return None

    ast = _build_ast_node(match, input_str)

    # If top-level match is a combinator and we have a top_rule label, build synthetic node
    if ast is None and top_rule:
        children = _collect_children_for_ast(match, input_str)
        ast = ASTNode(
            label=top_rule,
            pos=match.pos,
            len=match.len,
            children=children,
            _input=input_str,
        )

    return ast


def _build_ast_node(match: MatchResult, input_str: str) -> ASTNode | None:
    """Build an AST node from a match result."""
    clause = match.clause

    # Handle Ref nodes - these become AST nodes with the rule name as label
    # UNLESS they're marked as transparent, in which case we flatten them
    if isinstance(clause, Ref):
        if clause.transparent:
            # Transparent rule - don't create a node, just return None
            return None
        # Get children by recursively processing the wrapped match
        children = _collect_children(match, input_str)
        return ASTNode(
            label=clause.rule_name,
            pos=match.pos,
            len=match.len,
            children=children,
            _input=input_str,
        )

    # Handle terminal nodes - these become leaf AST nodes
    if isinstance(clause, (Str, Char, CharRange, AnyChar)):
        return ASTNode(
            label=type(clause).__name__,
            pos=match.pos,
            len=match.len,
            children=[],
            _input=input_str,
        )

    # For all other nodes (combinators), flatten and collect children
    # This shouldn't normally be called at the top level, but handle it anyway
    return None


def _collect_children(match: MatchResult, input_str: str) -> list[ASTNode]:
    """Collect children for an AST node by flattening combinators."""
    result = []

    for child in match.sub_clause_matches:
        if child.is_mismatch:
            continue
        if isinstance(child, SyntaxErrorNode):  # Skip error nodes in AST
            continue

        clause = child.clause

        # If child is a Ref or terminal, add it as an AST node
        if isinstance(clause, (Ref, Str, Char, CharRange, AnyChar)):
            node = _build_ast_node(child, input_str)
            if node is not None:
                result.append(node)
        # Otherwise, it's a combinator - recursively collect its children
        else:
            result.extend(_collect_children(child, input_str))

    return result


def _collect_children_for_ast(match: MatchResult, input_str: str) -> list[ASTNode]:
    """Collect children for AST building when top-level match is a combinator.

    Used by parse_to_ast() to build synthetic AST nodes.
    """
    result = []

    for child in match.sub_clause_matches:
        if child.is_mismatch:
            continue
        if isinstance(child, SyntaxErrorNode):  # Skip error nodes in AST
            continue

        clause = child.clause

        # If child is a Ref, create an AST node for it (unless transparent)
        if isinstance(clause, Ref):
            if not clause.transparent:
                children = _collect_children(child, input_str)
                node = ASTNode(
                    label=clause.rule_name,
                    pos=child.pos,
                    len=child.len,
                    children=children,
                    _input=input_str,
                )
                result.append(node)
            # Transparent rules are completely skipped - don't create node and don't include their children
        # Include terminals as leaf nodes
        elif isinstance(clause, (Str, Char, CharRange, AnyChar)):
            node = _build_ast_node(child, input_str)
            if node is not None:
                result.append(node)
        # For other combinators, recursively collect their children
        else:
            result.extend(_collect_children_for_ast(child, input_str))

    return result
