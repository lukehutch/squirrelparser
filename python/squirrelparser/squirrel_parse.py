"""
squirrel_parse convenience function - parses input and returns both AST and syntax errors.
"""

from __future__ import annotations
from typing import TYPE_CHECKING
from collections.abc import Mapping

from .parser import Parser
from .ast_node import ASTNode, build_ast
from .combinators import get_syntax_errors

if TYPE_CHECKING:
    from .clause import Clause
    from .match_result import SyntaxError


def squirrel_parse(
    grammar_str: str,
    input_str: str,
    top_rule: str
) -> tuple[ASTNode, list[SyntaxError]]:
    """
    Convenience function to parse input and return both AST and syntax errors.

    Args:
        grammar_str: The grammar as a PEG metagrammar string
        input_str: The input string to parse
        top_rule: The name of the top-level rule to parse

    Returns:
        A tuple (ast, syntax_errors) where ast is always non-null (possibly empty)
    """
    from .meta_grammar import MetaGrammar
    parsed_rules = MetaGrammar.parse_grammar(grammar_str)
    return _squirrel_parse_internal(parsed_rules, top_rule, input_str)


def squirrel_parse_with_rule_map(
    rules: Mapping[str, Clause],
    top_rule: str,
    input_str: str
) -> tuple[ASTNode, list[SyntaxError]]:
    """
    Convenience function to parse input and return both AST and syntax errors.

    Args:
        rules: The grammar rules map
        top_rule: The name of the top-level rule to parse
        input_str: The input string to parse

    Returns:
        A tuple (ast, syntax_errors) where ast is always non-null (possibly empty)
    """
    return _squirrel_parse_internal(rules, top_rule, input_str)


def _squirrel_parse_internal(
    rules: Mapping[str, Clause],
    top_rule: str,
    input_str: str
) -> tuple[ASTNode, list[SyntaxError]]:
    """Internal implementation shared by public methods."""
    parser = Parser(rules=rules, input_str=input_str)
    match_result, _ = parser.parse(top_rule)

    ast = build_ast(match_result, input_str, top_rule)
    # Provide fallback empty AST node if buildAST returns None
    if ast is None:
        ast = ASTNode(label=top_rule, pos=match_result.pos, len=match_result.len, children=[], _input=input_str)
    syntax_errors = get_syntax_errors(match_result, input_str)

    return (ast, syntax_errors)
