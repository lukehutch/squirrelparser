import 'package:squirrel_parser/src/parser/combinators.dart';

import 'clause.dart';

/// Result of matching a clause at a position.
///
/// All match types (terminals, single child, multiple children) are unified.
/// They differ only in |children|: terminals (0), single (1), multiple (n).
abstract class MatchResult {
  final Clause? clause;
  final int pos;
  final int len;

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
      {this.isComplete = true, this.isFromLRContext = false});

  List<MatchResult> get subClauseMatches;
  bool get isMismatch => false;

  /// Create a copy of this result with isFromLRContext=true.
  /// Used by MemoEntry to mark results from left-recursive rules (C10).
  MatchResult withLRContext();

  String toPrettyString(String input, {int indent = 0});
}

// Helper functions for Match class
int _totalLength(List<MatchResult> children) => children.isEmpty
    ? 0
    : children.last.pos + children.last.len - children.first.pos;

bool _anyFromLR(List<MatchResult> children) =>
    children.any((r) => r.isFromLRContext);

/// A successful match (unified type for all match results).
/// Terminals have empty children list, combinators have one or more children.
class Match extends MatchResult {
  @override
  final List<MatchResult> subClauseMatches;

  /// Create a match. Automatically computes pos/len/isFromLRContext from children if provided.
  Match(Clause? clause, int pos, int len,
      {this.subClauseMatches = const [],
      bool isComplete = true,
      bool? isFromLRContext})
      : super(
            clause,
            subClauseMatches.isEmpty ? pos : subClauseMatches.first.pos,
            subClauseMatches.isEmpty ? len : _totalLength(subClauseMatches),
            isComplete: isComplete,
            isFromLRContext: isFromLRContext ??
                (subClauseMatches.isEmpty
                    ? false
                    : _anyFromLR(subClauseMatches)));

  @override
  MatchResult withLRContext() => isFromLRContext
      ? this
      : Match(clause, pos, len,
          subClauseMatches: subClauseMatches,
          isComplete: isComplete,
          isFromLRContext: true);

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

/// A mismatch: sentinel len=-1 so even empty matches beat mismatches.
class Mismatch extends Match {
  Mismatch._({bool isFromLRContext = false})
      : super(null, -1, -1, isFromLRContext: isFromLRContext);
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

final mismatch = Mismatch._();

/// Special mismatch indicating LR cycle in progress.
final lrPending = Mismatch._(isFromLRContext: true);

/// A syntax error node: records skipped input or deleted grammar elements.
class SyntaxError extends Match {
  final String skipped; // Characters skipped (insertion error)
  final bool isDeletion; // True if grammar element was deleted

  SyntaxError({
    required int pos,
    required int len,
    this.skipped = '',
    this.isDeletion = false,
  }) : super(null, pos, len, isComplete: true);

  @override
  String toString() => isDeletion ? 'DELETION@$pos' : 'SKIP("$skipped")@$pos';

  @override
  MatchResult withLRContext() => this; // SyntaxErrors don't need LR context

  /// Pretty print the AST tree.
  @override
  String toPrettyString(String input, {int indent = 0}) {
    return '${'  ' * indent}${toString()}\n';
  }
}
