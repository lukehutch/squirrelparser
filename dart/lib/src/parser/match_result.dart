import 'package:squirrel_parser/src/parser/combinators.dart';

import 'clause.dart';

// Helper functions for Match class
int _totalLength(List<MatchResult> children) =>
    children.isEmpty ? 0 : children.last.pos + children.last.len - children.first.pos;

bool _anyFromLR(List<MatchResult> children) => children.any((r) => r.isFromLRContext);

final mismatch = _Mismatch._();

/// Special mismatch indicating LR cycle in progress.
final lrPending = _Mismatch._(isFromLRContext: true);

// -----------------------------------------------------------------------------------------------------------------

/// Result of matching a clause at a position.
///
/// All match types (terminals, single child, multiple children) are unified.
/// They differ only in |children|: terminals (0), single (1), multiple (n).
abstract class MatchResult {
  final Clause? clause;
  final int pos;
  final int len;

  // Total number of syntax errors among this MatchResult and its descendants
  final int totDescendantErrors;

  /// CONSTRAINT C6 (Completeness Propagation): Signals whether this is a
  /// maximal parse. A complete result means the grammar matched all input
  /// it could, with no recovery needed. Incomplete means parsing could
  /// continue but was blocked.
  final bool isComplete;

  /// CONSTRAINT C10 (LR-Recovery Separation): Signals that this result came
  /// from within a left-recursive expansion. Recovery must not be attempted
  /// at results with this flag set.
  final bool isFromLRContext;

  const MatchResult(this.clause, this.pos, this.len,
      {this.isComplete = true, this.isFromLRContext = false, this.totDescendantErrors = 0});

  List<MatchResult> get subClauseMatches;
  bool get isMismatch => false;

  /// Create a copy of this result with isFromLRContext=true.
  /// Used by MemoEntry to mark results from left-recursive rules (C10).
  MatchResult withLRContext();

  String toPrettyString(String input, {int indent = 0});
}

// -----------------------------------------------------------------------------------------------------------------

/// A successful match (unified type for all match results).
/// Terminals have empty children list, combinators have one or more children.
class Match extends MatchResult {
  @override
  final List<MatchResult> subClauseMatches;

  /// Create a match. Automatically computes pos/len/isFromLRContext from children if provided.
  Match(Clause? clause, int pos, int len,
      {this.subClauseMatches = const [],
      bool isComplete = true,
      bool? isFromLRContext,
      int numSystaxErrors = 0,
      bool addSubClauseErrors = true})
      : super(clause, subClauseMatches.isEmpty ? pos : subClauseMatches.first.pos,
            subClauseMatches.isEmpty ? len : _totalLength(subClauseMatches),
            isComplete: isComplete,
            isFromLRContext: isFromLRContext ?? (subClauseMatches.isEmpty ? false : _anyFromLR(subClauseMatches)),
            totDescendantErrors: addSubClauseErrors
                ? numSystaxErrors + subClauseMatches.fold(0, (s, r) => s + r.totDescendantErrors)
                : numSystaxErrors);

  @override
  MatchResult withLRContext() => isFromLRContext
      ? this
      : Match(clause, pos, len,
          subClauseMatches: subClauseMatches,
          isComplete: isComplete,
          isFromLRContext: true,
          numSystaxErrors: totDescendantErrors,
          addSubClauseErrors: false);

  @override
  String toPrettyString(String input, {int indent = 0}) {
    final buffer = StringBuffer();
    buffer.write('  ' * indent);
    buffer.write(clause is Ref ? clause.toString() : clause.runtimeType.toString());
    if (subClauseMatches.isEmpty) {
      buffer.write(': "${input.substring(pos, pos + len)}"');
    }
    buffer.writeln();
    for (final child in subClauseMatches) {
      buffer.write(child.toPrettyString(input, indent: indent + 1));
    }
    return buffer.toString();
  }
}

// -----------------------------------------------------------------------------------------------------------------

/// A mismatch: sentinel len=-1 so even empty matches beat mismatches.
class _Mismatch extends Match {
  _Mismatch._({bool isFromLRContext = false}) : super(null, -1, -1, isFromLRContext: isFromLRContext);
  @override
  bool get isMismatch => true;

  @override
  MatchResult withLRContext() => lrPending;

  /// Pretty print the AST tree.
  @override
  String toPrettyString(String input, {int indent = 0}) {
    return '${'  ' * indent}MISMATCH\n';
  }
}

// -----------------------------------------------------------------------------------------------------------------

/// A syntax error node: records skipped input or deleted grammar elements.
/// if len == 0, then this was a deletion of a grammar element, and clause is the deleted clause.
/// if len > 0, then this was an insertion of skipped input.
class SyntaxError extends Match {
  SyntaxError({
    required int pos,
    required int len,
    Clause? deletedClause,
  }) : super(deletedClause, pos, len, isComplete: true, numSystaxErrors: 1);

  /// The AST/CST node label for syntax errors.
  static const String nodeLabel = '<SyntaxError>';

  @override
  MatchResult withLRContext() => this; // SyntaxErrors don't need LR context

  @override
  String toString() =>
      // If len == 0, this is a deletion of a grammar element;
      // if len > 0, this is an insertion of skipped input.
      len == 0
          ? 'Missing grammar element ${clause.runtimeType} at pos $pos'
          : '$len characters of unexpected input at pos $pos';

  /// Pretty print the AST tree.
  @override
  String toPrettyString(String input, {int indent = 0}) {
    return '${'  ' * indent}<SyntaxError>: ${toString()}\n';
  }
}
