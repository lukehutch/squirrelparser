"""Public Squirrel Parser API."""

from __future__ import annotations

from .cst_node import ASTNode, CSTNode, CSTNodeFactoryFn, build_ast, build_cst
from .meta_grammar import MetaGrammar
from .parser import Parser, ParseResult


def squirrel_parse_cst(
    *,
    grammar_spec: str,
    top_rule_name: str,
    factories: dict[str, CSTNodeFactoryFn],
    input: str,
    allow_syntax_errors: bool = False,
) -> CSTNode:
    """
    Parse input and return a Concrete Syntax Tree (CST).

    Internally, the Abstract Syntax Tree (AST) is built from the parse tree, eliding all nodes that are
    not rule references or terminals. (Transparent rule refs are elided too.)

    The CST is then constructed from the Abstract Syntax Tree (AST) using the provided factory functions.
    This allows for fully custom syntax tree representations. You can decide whether to include, process,
    ignore, or transform any child nodes when your factory methods construct CST nodes from the AST.

    The factories map should contain an entry for each rule name in the grammar, plus:
    - '<Terminal>' for terminal matches (string literals, character classes, etc.)
    - '<SyntaxError>' if allow_syntax_errors is True

    If allow_syntax_errors is False, and a syntax error is encountered in the AST, a ValueError will be
    raised describing only the first syntax error encountered.

    If allow_syntax_errors is True, then you must define a factory for the label '<SyntaxError>',
    in order to decide how to construct CST nodes when there are syntax errors.
    """
    return build_cst(
        squirrel_parse_ast(
            grammar_spec=grammar_spec,
            top_rule_name=top_rule_name,
            input=input,
        ),
        factories,
        allow_syntax_errors,
    )


# ------------------------------------------------------------------------------------------------------------------


def squirrel_parse_ast(
    *,
    grammar_spec: str,
    top_rule_name: str,
    input: str,
) -> ASTNode:
    """
    Call the Squirrel Parser with the given grammar, top rule, and input, and return the
    Abstract Syntax Tree (AST), which consists of only non-transparent rule references and terminals.
    Non-rule-ref AST nodes will have the label '<Terminal>' for terminals and '<SyntaxError>'
    for syntax errors.
    """
    return build_ast(
        squirrel_parse_pt(
            grammar_spec=grammar_spec,
            top_rule_name=top_rule_name,
            input=input,
        )
    )


# ------------------------------------------------------------------------------------------------------------------


def squirrel_parse_pt(
    *,
    grammar_spec: str,
    top_rule_name: str,
    input: str,
) -> ParseResult:
    """
    Call the Squirrel Parser with the given grammar, top rule, and input, and return the raw parse tree (PT).
    This is the lowest-level parsing function.
    """
    return Parser(
        rules=MetaGrammar.parse_grammar(grammar_spec),
        top_rule_name=top_rule_name,
        input=input,
    ).parse()
