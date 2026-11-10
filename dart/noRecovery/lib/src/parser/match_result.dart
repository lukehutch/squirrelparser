import 'combinators.dart';

import 'clause.dart';

// Helper function for Match class
int _totalLength(List<MatchResult> children) =>
    children.isEmpty ? 0 : children.last.pos + children.last.len - children.first.pos;

/// The MISMATCH singleton: sentinel len=-1 so even empty matches beat mismatches.
final mismatch = _Mismatch._();

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

/// A mismatch: sentinel len=-1 so even empty matches beat mismatches.
class _Mismatch extends Match {
  _Mismatch._() : super(null, -1, -1);
  @override
  bool get isMismatch => true;

  @override
  String toPrettyString(String input, {int indent = 0}) {
    return '${'  ' * indent}MISMATCH\n';
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
