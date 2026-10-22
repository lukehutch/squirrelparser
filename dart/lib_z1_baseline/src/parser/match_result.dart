import 'combinators.dart';

import 'clause.dart';

// Helper function for Match class
int _totalLength(List<MatchResult> children) =>
    children.isEmpty ? 0 : children.last.pos + children.last.len - children.first.pos;

/// A zero-information mismatch, kept for callers outside the core parser that
/// only need "this did not match" and have nothing to say about how far it got.
///
/// The core parser no longer returns this: every mismatch it produces is a
/// fresh [Mismatch] carrying the input it consumed before failing and the
/// subclause results it had accumulated. See [Mismatch].
const mismatch = Mismatch(null, -1, -1);

// -----------------------------------------------------------------------------------------------------------------

/// Result of matching a clause at a position.
///
/// All match types (terminals, single child, multiple children) are unified.
/// They differ only in |children|: terminals (0), single (1), multiple (n).
abstract class MatchResult {
  final Clause? clause;
  final int pos;
  final int len;

  const MatchResult(this.clause, this.pos, this.len);

  List<MatchResult> get subClauseMatches;
  bool get isMismatch => false;

  String toPrettyString(String input, {int indent = 0});
}

// -----------------------------------------------------------------------------------------------------------------

/// A successful match (unified type for all match results).
/// Terminals have empty children list, combinators have one or more children.
class Match extends MatchResult {
  @override
  final List<MatchResult> subClauseMatches;

  /// Create a match. Automatically computes pos/len from children if provided.
  Match(Clause? clause, int pos, int len, {this.subClauseMatches = const []})
      : super(clause, subClauseMatches.isEmpty ? pos : subClauseMatches.first.pos,
            subClauseMatches.isEmpty ? len : _totalLength(subClauseMatches));

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

/// A clause that did not match at a position, and HOW FAR IT GOT.
///
/// A mismatch used to be one shared tombstone with `len == -1`, which made
/// "even an empty match beats a mismatch" true by arithmetic. It carried no
/// information, so the end of the validly-parsed input could only be
/// approximated -- by scanning the whole memo table for the largest position at
/// which anything failed ([Parser.syntaxErrorPosition]), which is a position,
/// not a place in the tree.
///
/// Each mismatch is now its own node:
///
/// - [len] is the input CONSUMED BY [subClauseMatches] BEFORE THE FAILURE. It
///   is **not** a match length. `pos + len` is the exact frontier of this
///   subtree: the point up to which the input was read and accepted.
/// - [subClauseMatches] are the results this clause had accumulated, matches
///   and mismatches alike, so the frontier can be located by descending rather
///   than by searching. Holding them costs memory the old tombstone did not
///   spend; it buys a connected tree at the frontier instead of a bare integer.
///
/// **`len` is meaningless unless you know it is a mismatch.** Nothing may
/// compare it against a match's length without testing [isMismatch] first --
/// the old `-1` made that safe by accident, and it no longer is. The one place
/// in the parser that depended on it is [MemoEntry.match], which now tests
/// [isMismatch] explicitly.
class Mismatch extends MatchResult {
  @override
  final List<MatchResult> subClauseMatches;

  /// Unlike [Match], pos and len are taken as given, never recomputed from the
  /// children: a mismatch's children include the one that failed, whose own
  /// span is not input this clause accepted.
  const Mismatch(super.clause, super.pos, super.len, {this.subClauseMatches = const []});

  @override
  bool get isMismatch => true;

  /// The exact end of the input this subtree read and accepted.
  int get frontier => pos + len;

  @override
  String toPrettyString(String input, {int indent = 0}) {
    final buffer = StringBuffer();
    buffer.write('  ' * indent);
    buffer.write('MISMATCH ');
    buffer.write(clause is Ref ? clause.toString() : clause.runtimeType.toString());
    buffer.writeln(' at $pos, read $len');
    for (final child in subClauseMatches) {
      buffer.write(child.toPrettyString(input, indent: indent + 1));
    }
    return buffer.toString();
  }
}

// -----------------------------------------------------------------------------------------------------------------

/// A syntax error node: records a span of input that could not be matched.
///
/// The core parsing algorithm never produces SyntaxError nodes; this is only
/// used at the [ParseResult] level to wrap unmatched trailing input (or the
/// whole input, if the top rule did not match at all).
class SyntaxError extends Match {
  SyntaxError({required int pos, required int len}) : super(null, pos, len);

  /// The AST/CST node label for syntax errors.
  static const String nodeLabel = '<SyntaxError>';

  @override
  String toString() => '$len characters of unexpected input at pos $pos';

  /// Pretty print the AST tree.
  @override
  String toPrettyString(String input, {int indent = 0}) {
    return '${'  ' * indent}<SyntaxError>: ${toString()}\n';
  }
}
