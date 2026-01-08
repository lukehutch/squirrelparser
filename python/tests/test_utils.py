"""
SQUIRREL PARSER TEST UTILITIES
Shared helper functions for all test files.
"""

from typing import cast, Any
from collections.abc import Mapping
from squirrelparser import (
    Parser, Clause, Ref, Str, Char, CharRange,
    Seq, First, OneOrMore, ZeroOrMore, Optional,
    SyntaxError as SyntaxErrorNode
)
from squirrelparser.match_result import MatchResult


def parse(rules: Mapping[str, Any], input_str: str, top_rule: str = 'S') -> tuple[bool, int, list[str]]:
    """
    Parse input with error recovery and return (success, error_count, skipped).
    top_rule defaults to 'S' for backward compatibility.

    Result always spans input with new invariant.
    Check if the entire result is just a SyntaxError (total failure).
    """
    parser = Parser(rules=cast(Mapping[str, Clause], rules), input_str=input_str)
    result, _used_recovery = parser.parse(top_rule)

    # Result always spans input with new invariant.
    # Check if the entire result is just a SyntaxError (total failure)
    if isinstance(result, SyntaxErrorNode):
        return (False, 1, [result.skipped])

    return (True, count_errors(result), get_skipped_strings(result))


def count_errors(result: MatchResult | None) -> int:
    """Count total syntax errors in a parse tree."""
    if result is None or result.is_mismatch:
        return 0
    count = 1 if isinstance(result, SyntaxErrorNode) else 0
    for child in result.sub_clause_matches:
        count += count_errors(child)
    return count


def get_skipped_strings(result: MatchResult | None) -> list[str]:
    """Get list of skipped strings from syntax errors."""
    skipped = []

    def collect(r: MatchResult | None) -> None:
        if r is None or r.is_mismatch:
            return
        if isinstance(r, SyntaxErrorNode) and not r.is_deletion:
            skipped.append(r.skipped)
        for child in r.sub_clause_matches:
            collect(child)

    collect(result)
    return skipped


def count_deletions(result: MatchResult | None) -> int:
    """Count deletions in parse tree."""
    if result is None or result.is_mismatch:
        return 0
    count = 1 if isinstance(result, SyntaxErrorNode) and result.is_deletion else 0
    for child in result.sub_clause_matches:
        count += count_deletions(child)
    return count


def parse_for_tree(rules: Mapping[str, Any], input_str: str, top_rule: str = 'S') -> MatchResult | None:
    """
    Parse and return the MatchResult directly for tree structure verification.
    top_rule defaults to 'S' for backward compatibility.

    With new invariant, parse() always returns a MatchResult spanning input.
    Return None only if the entire result is a SyntaxError (total failure).
    """
    parser = Parser(rules=cast(Mapping[str, Clause], rules), input_str=input_str)
    result, _used_recovery = parser.parse(top_rule)
    # With new invariant, parse() always returns a MatchResult spanning input
    # Return None only if entire result is a SyntaxError (total failure)
    if isinstance(result, SyntaxErrorNode):
        return None
    return result


def print_tree(result: MatchResult | None, indent: int = 0) -> None:
    """Debug: print tree structure"""
    if result is None:
        print(' ' * indent + 'null')
        return

    prefix = ' ' * indent
    clause = result.clause
    clause_type = type(clause).__name__
    clause_info = clause_type

    if isinstance(clause, Ref):
        clause_info = f'Ref({clause.rule_name})'
    elif isinstance(clause, Str):
        clause_info = f'Str("{clause.text}")'
    elif isinstance(clause, CharRange):
        clause_info = f'CharRange({clause.lo}-{clause.hi})'

    print(f'{prefix}{clause_info} pos={result.pos} len={result.len}')
    for child in result.sub_clause_matches:
        if not child.is_mismatch:
            print_tree(child, indent + 2)


def get_tree_shape(result: MatchResult | None, rules: dict[str, Clause]) -> str:
    """
    Get a simplified tree representation showing rule structure.
    Returns a string like "E(E(E(n),+n),+n)" for left-associative parse.
    """
    if result is None or result.is_mismatch:
        return 'MISMATCH'
    return _build_tree_shape(result, rules)


def _build_tree_shape(result: MatchResult, rules: dict[str, Clause]) -> str:
    """Internal helper for building tree shape."""
    clause = result.clause

    # For Ref clauses, show the rule name and recurse into the referenced match
    if isinstance(clause, Ref):
        children = result.sub_clause_matches
        if not children:
            return clause.rule_name
        # Get the shape of what the ref matched
        child_shapes = [
            _build_tree_shape(c, rules)
            for c in children
            if not c.is_mismatch
        ]
        if not child_shapes:
            return clause.rule_name
        if len(child_shapes) == 1:
            return f'{clause.rule_name}({child_shapes[0]})'
        return f'{clause.rule_name}({",".join(child_shapes)})'

    # For Str terminals, show the matched string in quotes
    if isinstance(clause, Str):
        return f"'{clause.text}'"

    # For Char terminals, show the character
    if isinstance(clause, Char):
        return f"'{clause.ch}'"

    # For CharRange terminals, show the range
    if isinstance(clause, CharRange):
        return f'[{clause.lo}-{clause.hi}]'

    # For Seq, First, show children
    if isinstance(clause, (Seq, First)):
        child_shapes = [
            _build_tree_shape(c, rules)
            for c in result.sub_clause_matches
            if not c.is_mismatch
        ]
        if not child_shapes:
            return '()'
        if len(child_shapes) == 1:
            return child_shapes[0]
        return f'({",".join(child_shapes)})'

    # For repetition operators
    if isinstance(clause, (OneOrMore, ZeroOrMore)):
        child_shapes = [
            _build_tree_shape(c, rules)
            for c in result.sub_clause_matches
            if not c.is_mismatch
        ]
        if not child_shapes:
            return '[]'
        return f'[{",".join(child_shapes)}]'

    # For Optional
    if isinstance(clause, Optional):
        child_shapes = [
            _build_tree_shape(c, rules)
            for c in result.sub_clause_matches
            if not c.is_mismatch
        ]
        if not child_shapes:
            return '?()'
        return f'?({",".join(child_shapes)})'

    # Default: show clause type
    return type(clause).__name__


def is_left_associative(result: MatchResult | None, rule_name: str) -> bool:
    """
    Check if tree has left-associative BINDING (not just left-recursive structure).

    For true left-associativity like ((0+1)+2):
    - The LEFT child E should itself be a recursive application (E op X), not just base case
    - This means the left E's first child is also an E

    For right-associative binding like 0+(1+2) from ambiguous grammar:
    - The LEFT child E is just the base case (no E child)
    - The RIGHT child E does all the work
    """
    if result is None or result.is_mismatch:
        return False

    # Find all instances of the rule in the tree
    instances = _find_rule_instances(result, rule_name)
    if len(instances) < 2:
        return False

    # For left-associativity, check if ANY instance's LEFT CHILD E
    # is itself an application of the recursive pattern (not just base case)
    for instance in instances:
        first_child, is_same_rule = _get_first_semantic_child(instance, rule_name)
        if not is_same_rule or first_child is None:
            continue

        # Now check if this first_child E is itself recursive (not just base case)
        # A recursive E will have another E as its first child
        nested_first, nested_is_same = _get_first_semantic_child(first_child, rule_name)
        if nested_is_same:
            # The left E has another E as its first child -> truly left-associative
            return True

    return False


def _get_first_semantic_child(result: MatchResult, rule_name: str) -> tuple[MatchResult | None, bool]:
    """
    Get the first semantic child of a result, drilling through Seq/First wrappers.
    Returns (child, is_same_rule) where is_same_rule indicates if child is Ref(rule_name).
    """
    children = [c for c in result.sub_clause_matches if not c.is_mismatch]
    if not children:
        return (None, False)

    first_child = children[0]

    # Drill through Seq/First to find actual first element
    while isinstance(first_child.clause, (Seq, First)):
        inner_children = [c for c in first_child.sub_clause_matches if not c.is_mismatch]
        if not inner_children:
            return (None, False)
        first_child = inner_children[0]

    is_same_rule = isinstance(first_child.clause, Ref) and first_child.clause.rule_name == rule_name
    return (first_child, is_same_rule)


def _find_rule_instances(result: MatchResult, rule_name: str) -> list[MatchResult]:
    """Find all MatchResults where clause is Ref(rule_name)"""
    instances = []

    if isinstance(result.clause, Ref) and result.clause.rule_name == rule_name:
        instances.append(result)

    for child in result.sub_clause_matches:
        if not child.is_mismatch:
            instances.extend(_find_rule_instances(child, rule_name))

    return instances


def count_rule_depth(result: MatchResult | None, rule_name: str) -> int:
    """Count the total occurrences of a rule in the parse tree."""
    if result is None or result.is_mismatch:
        return 0
    return _count_depth(result, rule_name)


def _count_depth(result: MatchResult, rule_name: str) -> int:
    """Internal helper for counting rule depth."""
    clause = result.clause
    count = 0

    if isinstance(clause, Ref) and clause.rule_name == rule_name:
        count = 1

    # Recurse into ALL children to find all occurrences
    for child in result.sub_clause_matches:
        if not child.is_mismatch:
            count += _count_depth(child, rule_name)

    return count


def verify_operator_count(result: MatchResult | None, op_str: str, expected_ops: int) -> bool:
    """
    Verify that for input with N operators, we have N+1 base terms and N operator applications.
    For "n+n+n" we expect 3 'n' terms and 2 '+n' applications in a left-assoc tree.
    """
    if result is None or result.is_mismatch:
        return False
    count = _count_operators(result, op_str)
    return count == expected_ops


def _count_operators(result: MatchResult, op_str: str) -> int:
    """Internal helper for counting operators."""
    count = 0
    if isinstance(result.clause, Str) and result.clause.text == op_str:
        count = 1
    for child in result.sub_clause_matches:
        if not child.is_mismatch:
            count += _count_operators(child, op_str)
    return count
