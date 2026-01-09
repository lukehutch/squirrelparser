"""
squirrel_parse - Parse input and return a Concrete Syntax Tree (CST)
"""

from __future__ import annotations

from typing import TYPE_CHECKING, Mapping, cast

from .parser import Parser
from .terminals import Str, Char, CharRange, AnyChar
from .combinators import Ref, get_syntax_errors
from .cst_node import (
    CSTNode,
    CSTNodeFactory,
    CSTFactoryValidationException,
    CSTConstructionException,
    DuplicateRuleNameException,
)

if TYPE_CHECKING:
    from .match_result import MatchResult, SyntaxError

# Import at module level for runtime use
from .clause import Clause


# ============================================================================
# Public CST API
# ============================================================================


def squirrel_parse(
    grammar_text: str,
    input_str: str,
    top_rule: str,
    factories: list[CSTNodeFactory[CSTNode]],
) -> tuple[CSTNode, list[SyntaxError]]:
    """
    Parse input and return a Concrete Syntax Tree (CST), and any syntax errors.

    The CST is constructed directly from the parse tree using the provided factory functions.
    This allows for fully custom syntax tree representations.

    Args:
        grammar_text: The grammar as a PEG metagrammar string
        input_str: The input string to parse
        top_rule: The name of the top-level rule to parse
        factories: List of CST node factories for each grammar rule

    Returns:
        A tuple (cst, syntax_errors) where cst is the root CST node

    Raises:
        CSTFactoryValidationException: if the factory list is invalid
        DuplicateRuleNameException: if any rule name appears more than once
        CSTConstructionException: if CST construction fails
    """
    from .meta_grammar import MetaGrammar

    rules = MetaGrammar.parse_grammar(grammar_text)

    # Convert factories list to map, checking for duplicates
    factories_map = _build_factories_map(factories)

    # Parse the input using the rules
    parser = Parser(cast(Mapping[str, Clause], rules), input_str)
    match_result, _ = parser.parse(top_rule)
    syntax_errors = get_syntax_errors(match_result, input_str)

    # Validate factories
    _validate_cst_factories(rules, factories_map)

    # Build CST from parse tree
    cst = _build_cst(match_result, input_str, factories_map, syntax_errors, top_rule)

    return (cst, syntax_errors)


# ============================================================================
# Private helpers (internal API for package use only)
# ============================================================================


def parse_with_rules(
    rules: Mapping[str, Clause],
    top_rule: str,
    input_str: str,
) -> tuple[MatchResult, list[SyntaxError]]:
    """Parse input with pre-parsed rules and return raw parse tree and errors. For internal use only."""
    return _parse_to_match_result(rules, top_rule, input_str)


# ============================================================================
# Internal implementation helpers
# ============================================================================


def _parse_to_match_result(
    rules: Mapping[str, Clause],
    top_rule: str,
    input_str: str,
) -> tuple[MatchResult, list[SyntaxError]]:
    """Parse with pre-parsed rules and return match result and syntax errors."""
    parser = Parser(rules=rules, input_str=input_str)
    match_result, _ = parser.parse(top_rule)
    syntax_errors = get_syntax_errors(match_result, input_str)
    return (match_result, syntax_errors)


def _build_factories_map(
    factories: list[CSTNodeFactory[CSTNode]],
) -> Mapping[str, CSTNodeFactory[CSTNode]]:
    """Build a factories map from a list, checking for duplicate rule names."""
    result: dict[str, CSTNodeFactory[CSTNode]] = {}
    counts: dict[str, int] = {}

    # Count occurrences
    for factory in factories:
        counts[factory.rule_name] = counts.get(factory.rule_name, 0) + 1

    # Check for duplicates
    for rule_name, count in counts.items():
        if count > 1:
            raise DuplicateRuleNameException(rule_name, count)

    # Build map
    for factory in factories:
        result[factory.rule_name] = factory

    return result


def _validate_cst_factories(
    rules: Mapping[str, Clause],
    factories: Mapping[str, CSTNodeFactory[CSTNode]],
) -> None:
    """Validate that CST factories cover all non-transparent grammar rules."""
    transparent_rules = _get_transparent_rules(rules)
    required_rules = set(rules.keys()) - transparent_rules
    factory_rules = set(factories.keys())

    # Check if any factories are for transparent rules
    factories_for_transparent_rules = factory_rules & transparent_rules
    if factories_for_transparent_rules:
        raise CSTFactoryValidationException(factories_for_transparent_rules, set())

    missing = required_rules - factory_rules
    extra = factory_rules - required_rules

    if missing or extra:
        raise CSTFactoryValidationException(missing, extra)


def _get_transparent_rules(rules: Mapping[str, Clause]) -> set[str]:
    """Get the set of transparent rule names from the grammar."""
    transparent = set()
    for rule_name, clause in rules.items():
        if clause.transparent:
            transparent.add(rule_name)
    return transparent


def _build_cst(
    match_result: MatchResult,
    input_str: str,
    factories: Mapping[str, CSTNodeFactory[CSTNode]],
    syntax_errors: list[SyntaxError],
    top_rule_name: str,
) -> CSTNode:
    """Build a CST from a parse tree using the provided factories."""
    if match_result.is_mismatch:
        raise CSTConstructionException("Cannot build CST from mismatch result")

    # Get the factory for the top-level rule
    factory = factories.get(top_rule_name)
    if not factory:
        raise CSTConstructionException(f"No factory found for rule: {top_rule_name}")

    # Build child CST nodes from this match result
    clause = match_result.clause
    children: list[CSTNode] = []

    # If the top-level clause is a non-transparent Ref, build a node for it
    if isinstance(clause, Ref) and not clause.transparent:
        child_factory = factories.get(clause.rule_name)
        if child_factory:
            child_children = _build_cst_children(
                match_result, input_str, factories, syntax_errors, child_factory.expected_children
            )
            children.append(child_factory.factory(clause.rule_name, child_factory.expected_children, child_children))
    else:
        # For non-Ref clauses, collect children normally
        children.extend(
            _build_cst_children(match_result, input_str, factories, syntax_errors, factory.expected_children)
        )

    # Create the top-level CST node
    return factory.factory(top_rule_name, factory.expected_children, children)


def _build_cst_node(
    match_result: MatchResult,
    input_str: str,
    factories: Mapping[str, CSTNodeFactory[CSTNode]],
    syntax_errors: list[SyntaxError],
) -> CSTNode:
    """Recursively build CST nodes from a parse tree."""
    # Get the rule name from the clause
    clause = match_result.clause
    if not isinstance(clause, Ref):
        raise CSTConstructionException(f"Expected Ref at top level, got {type(clause).__name__}")

    rule_name = clause.rule_name

    # If this is a transparent rule, skip it and recurse into children
    if clause.transparent:
        transparent_children = [
            m
            for m in match_result.sub_clause_matches
            if not m.is_mismatch and isinstance(m.clause, Ref) and not m.clause.transparent
        ]

        if not transparent_children:
            raise CSTConstructionException(f"Transparent rule {rule_name} has no non-transparent children")
        if len(transparent_children) == 1:
            return _build_cst_node(transparent_children[0], input_str, factories, syntax_errors)
        else:
            raise CSTConstructionException(f"Transparent rule {rule_name} has multiple non-transparent children")

    factory = factories.get(rule_name)
    if not factory:
        raise CSTConstructionException(f"No factory found for rule: {rule_name}")

    # Get child matches
    children = _build_cst_children(match_result, input_str, factories, syntax_errors, factory.expected_children)

    # Call the factory to create the CST node
    return factory.factory(rule_name, factory.expected_children, children)


def _build_cst_children(
    match_result: MatchResult,
    input_str: str,
    factories: Mapping[str, CSTNodeFactory[CSTNode]],
    syntax_errors: list[SyntaxError],
    expected_children: list[str],
) -> list[CSTNode]:
    """Build CST nodes for children of a parse tree node."""
    children: list[CSTNode] = []

    for child in match_result.sub_clause_matches:
        if child.is_mismatch:
            continue

        clause = child.clause

        # Handle terminals - don't create CST nodes for terminals
        if isinstance(clause, (Str, Char, CharRange, AnyChar)):
            continue

        # Handle rule references
        if isinstance(clause, Ref):
            # Skip transparent rules - they're handled in _build_cst_node
            if clause.transparent:
                continue

            child_factory = factories.get(clause.rule_name)
            if child_factory:
                # Recursively build this child node
                cst_child = _build_cst_node(child, input_str, factories, syntax_errors)
                children.append(cst_child)

    return children
