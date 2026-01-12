"""Test utilities for Squirrel Parser tests."""

from dataclasses import dataclass

from squirrelparser.squirrel_parse import squirrel_parse_pt
from squirrelparser.match_result import SyntaxError, MatchResult
from squirrelparser.combinators import Ref, Seq, First
from squirrelparser.terminals import Str


@dataclass
class ParseTestResult:
    """Result of parsing with error recovery."""
    ok: bool
    error_count: int
    skipped_strings: list[str]


def run_test_parse(grammar_spec: str, input_str: str, top_rule: str = 'S') -> ParseTestResult:
    """Parse input with error recovery and return (success, errorCount, skippedStrings)."""
    parse_result = squirrel_parse_pt(
        grammar_spec=grammar_spec,
        top_rule_name=top_rule,
        input=input_str,
    )

    result = parse_result.root
    is_complete_failure = isinstance(result, SyntaxError) and result.len == len(parse_result.input)
    ok = not is_complete_failure

    tot_errors = result.tot_descendant_errors
    if parse_result.unmatched_input is not None and parse_result.unmatched_input.pos >= 0:
        tot_errors += 1

    skipped_strings = get_skipped_strings([result], input_str)
    if parse_result.unmatched_input is not None and parse_result.unmatched_input.pos >= 0:
        unmatched = parse_result.unmatched_input
        skipped_strings.append(parse_result.input[unmatched.pos:unmatched.pos + unmatched.len])

    return ParseTestResult(ok=ok, error_count=tot_errors, skipped_strings=skipped_strings)


# Export for use in other test files
test_parse = run_test_parse
test_parse.__test__ = False  # Prevent pytest from collecting this as a test


def get_syntax_errors(results: list[MatchResult]) -> list[SyntaxError]:
    """Collect all SyntaxError nodes from the parse tree."""
    errors: list[SyntaxError] = []

    def collect(r: MatchResult) -> None:
        if not r.is_mismatch:
            if isinstance(r, SyntaxError):
                errors.append(r)
            else:
                for child in r.sub_clause_matches:
                    collect(child)

    for result in results:
        collect(result)
    return errors


def count_deletions(results: list[MatchResult]) -> int:
    """Count deletions in parse tree (SyntaxErrors with len == 0)."""
    return len([e for e in get_syntax_errors(results) if e.len == 0])


def get_skipped_strings(results: list[MatchResult], input_str: str) -> list[str]:
    """Get list of skipped strings from syntax errors (SyntaxErrors with len > 0)."""
    return [input_str[e.pos:e.pos + e.len] for e in get_syntax_errors(results) if e.len > 0]


def parse_for_tree(grammar_spec: str, input_str: str, top_rule: str = 'S') -> MatchResult | None:
    """
    Parse and return the MatchResult for tree structure verification.
    Returns None if the entire input is a SyntaxError.
    """
    parse_result = squirrel_parse_pt(
        grammar_spec=grammar_spec,
        top_rule_name=top_rule,
        input=input_str,
    )
    result = parse_result.root
    return None if isinstance(result, SyntaxError) else result


def count_rule_depth(result: MatchResult | None, rule_name: str) -> int:
    """Count occurrences of a rule in the parse tree."""
    if result is None or result.is_mismatch:
        return 0
    count = 0
    if isinstance(result.clause, Ref) and result.clause.rule_name == rule_name:
        count = 1
    for child in result.sub_clause_matches:
        if not child.is_mismatch:
            count += count_rule_depth(child, rule_name)
    return count


def is_left_associative(result: MatchResult | None, rule_name: str) -> bool:
    """Check if tree has left-associative binding for a rule."""
    if result is None or result.is_mismatch:
        return False

    instances = _find_rule_instances(result, rule_name)
    if len(instances) < 2:
        return False

    for instance in instances:
        first_child_result = _get_first_semantic_child(instance, rule_name)
        if not first_child_result[1] or first_child_result[0] is None:
            continue

        nested_result = _get_first_semantic_child(first_child_result[0], rule_name)
        if nested_result[1]:
            return True
    return False


def verify_operator_count(result: MatchResult | None, op_str: str, expected_ops: int) -> bool:
    """Verify operator count in parse tree."""
    if result is None or result.is_mismatch:
        return False
    return _count_operators(result, op_str) == expected_ops


def _find_rule_instances(result: MatchResult, rule_name: str) -> list[MatchResult]:
    """Find all instances of a rule in the parse tree."""
    instances: list[MatchResult] = []
    if isinstance(result.clause, Ref) and result.clause.rule_name == rule_name:
        instances.append(result)
    for child in result.sub_clause_matches:
        if not child.is_mismatch:
            instances.extend(_find_rule_instances(child, rule_name))
    return instances


def _get_first_semantic_child(result: MatchResult, rule_name: str) -> tuple[MatchResult | None, bool]:
    """Get first semantic child and whether it's the same rule."""
    children = [c for c in result.sub_clause_matches if not c.is_mismatch]
    if not children:
        return (None, False)

    first_child = children[0]
    while isinstance(first_child.clause, (Seq, First)):
        inner_children = [c for c in first_child.sub_clause_matches if not c.is_mismatch]
        if not inner_children:
            return (None, False)
        first_child = inner_children[0]

    is_same_rule = isinstance(first_child.clause, Ref) and first_child.clause.rule_name == rule_name
    return (first_child, is_same_rule)


def _count_operators(result: MatchResult, op_str: str) -> int:
    """Count operator occurrences in parse tree."""
    count = 0
    if isinstance(result.clause, Str) and result.clause.text == op_str:
        count = 1
    for child in result.sub_clause_matches:
        if not child.is_mismatch:
            count += _count_operators(child, op_str)
    return count
