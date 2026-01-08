import 'match_result.dart';
import 'parser.dart';

/// Base class for all grammar clauses.
abstract class Clause {
  /// If true, this clause is transparent in the AST - its children are promoted
  /// to the parent rather than creating a node for this clause.
  final bool transparent;

  const Clause({this.transparent = false});
  MatchResult match(Parser parser, int pos, {Clause? bound});
  @override
  String toString() => runtimeType.toString();
}
