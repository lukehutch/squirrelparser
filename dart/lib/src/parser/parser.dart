import 'ast_node.dart';
import 'clause.dart';
import 'combinators.dart';
import 'match_result.dart';
import 'memo_entry.dart';
import 'terminals.dart';

/// The squirrel parser with bounded error recovery.
class Parser {
  final Map<String, Clause> rules;
  final String input;
  final Map<Clause, Map<int, MemoEntry>> _memoTable = {};
  final List<int> memoVersion;

  /// Phase 1 (Discovery): inRecoveryPhase = false
  /// Phase 2 (Recovery): inRecoveryPhase = true
  bool inRecoveryPhase = false;

  Parser({required this.rules, required this.input})
      : memoVersion = List.filled(input.length + 1, 0);

  /// Match a clause at a position, using memoization.
  MatchResult match(Clause clause, int pos, {Clause? bound}) {
    if (pos > input.length) return mismatch;

    // C5 (Ref Transparency): Don't memoize Ref independently
    if (clause is Ref) {
      return clause.match(this, pos, bound: bound);
    }

    var memoEntry = _memoTable
        .putIfAbsent(clause, () => {})
        .putIfAbsent(pos, MemoEntry.new);
    return memoEntry.match(this, clause, pos, bound);
  }

  /// Match a named rule at a position.
  MatchResult matchRule(String ruleName, int pos) {
    final clause = rules[ruleName];
    if (clause == null) {
      throw ArgumentError('Rule "$ruleName" not found');
    }
    return match(clause, pos);
  }

  /// Get the MemoEntry for a clause at a position (if it exists).
  MemoEntry? getMemoEntry(Clause clause, int pos) {
    return _memoTable[clause]?[pos];
  }

  /// Probe: Temporarily switch to Phase 1 to check if clause can match.
  MatchResult probe(Clause clause, int pos) {
    final savedPhase = inRecoveryPhase;
    inRecoveryPhase = false;
    final result = match(clause, pos);
    inRecoveryPhase = savedPhase;
    return result;
  }

  /// Check if clause can match non-zero characters at position.
  bool canMatchNonzeroAt(Clause clause, int pos) {
    final result = probe(clause, pos);
    return !result.isMismatch && result.len > 0;
  }

  /// Enable recovery mode (Phase 2).
  void enableRecovery() {
    inRecoveryPhase = true;
  }

  /// Parse input with two-phase error recovery.
  ///
  /// Returns (result, usedRecovery) where:
  ///   - result always spans the entire input (invariant: pos=0, len=input.length)
  ///   - usedRecovery = true if Phase 2 was needed
  ///
  /// If the grammar cannot match the input at all, returns a SyntaxError
  /// spanning the entire input. If there is trailing unmatched input,
  /// it is wrapped in a SyntaxError and included in the result.
  (MatchResult, bool) parse(String topRuleName) {
    // Phase 1: Discovery
    var result = matchRule(topRuleName, 0);
    if (!result.isMismatch && result.len == input.length) {
      return (result, false);
    }

    // Phase 2: Recovery
    enableRecovery();
    result = matchRule(topRuleName, 0);

    // Ensure result spans the entire input (new invariant)
    return (_ensureSpansInput(result), true);
  }

  /// Ensure the result spans the entire input.
  /// - If result is a mismatch, return SyntaxError spanning entire input
  /// - If result doesn't consume all input, wrap with trailing SyntaxError
  MatchResult _ensureSpansInput(MatchResult result) {
    if (result.isMismatch) {
      // Total failure: entire input is an error
      return SyntaxError(
        pos: 0,
        len: input.length,
        skipped: input,
      );
    }

    if (result.len == input.length) {
      // Already spans entire input
      return result;
    }

    // Partial match: wrap with trailing SyntaxError
    final trailing = SyntaxError(
      pos: result.len,
      len: input.length - result.len,
      skipped: input.substring(result.len),
    );

    // Create a wrapper Match that includes the original result and trailing error
    return Match(
      result.clause,
      0,
      0,
      subClauseMatches: [result, trailing],
      isComplete: false,
    );
  }

  /// Parse input and return an AST instead of a parse tree.
  ///
  /// Returns (ast, usedRecovery) where:
  ///   - ast always spans the entire input
  ///   - usedRecovery = true if Phase 2 was needed
  (ASTNode, bool) parseToAST(String topRuleName) {
    final (parseTree, usedRecovery) = parse(topRuleName);

    // If the parse tree top-level is not a Ref (e.g., when matching the Grammar rule directly),
    // create a synthetic root AST node with the rule name
    final ast = buildAST(parseTree, input);
    if (ast == null) {
      // Parse tree is a combinator at top level - wrap it in a synthetic rule node
      final children = _collectChildrenForAST(parseTree, input);
      final syntheticAST = ASTNode(
        label: topRuleName,
        pos: parseTree.pos,
        len: parseTree.len,
        children: children,
        input: input,
      );
      return (syntheticAST, usedRecovery);
    }
    return (ast, usedRecovery);
  }

  /// Helper to collect children for AST building (exposed for parseToAST).
  List<ASTNode> _collectChildrenForAST(MatchResult match, String input) {
    final result = <ASTNode>[];

    for (final child in match.subClauseMatches) {
      if (child.isMismatch) continue;
      if (child is SyntaxError) continue;

      final clause = child.clause;

      // If child is a Ref, create an AST node for it (unless transparent)
      if (clause is Ref) {
        if (!clause.transparent) {
          final children = _collectChildren(child, input);
          final node = ASTNode(
            label: clause.ruleName,
            pos: child.pos,
            len: child.len,
            children: children,
            input: input,
          );
          result.add(node);
        }
        // Transparent rules are completely skipped - don't create node and don't include their children
      }
      // Include terminals as leaf nodes
      else if (clause is Str ||
          clause is Char ||
          clause is CharRange ||
          clause is AnyChar) {
        final node = buildAST(child, input);
        if (node != null) {
          result.add(node);
        }
      }
      // For other combinators, recursively collect their children
      else {
        result.addAll(_collectChildrenForAST(child, input));
      }
    }

    return result;
  }

  /// Helper to collect children from a match result.
  List<ASTNode> _collectChildren(MatchResult match, String input) {
    final result = <ASTNode>[];

    for (final child in match.subClauseMatches) {
      if (child.isMismatch) continue;
      if (child is SyntaxError) continue;

      final clause = child.clause;

      // If child is a Ref or terminal, add it as an AST node
      if (clause is Ref || clause is Str ||
          clause is Char ||
          clause is CharRange ||
          clause is AnyChar) {
        final node = buildAST(child, input);
        if (node != null) {
          result.add(node);
        }
      }
      // Otherwise, it's a combinator - recursively collect its children
      else {
        result.addAll(_collectChildren(child, input));
      }
    }

    return result;
  }
}
