import 'match_result.dart';
import 'parser.dart';

/// Base class for all grammar clauses.
abstract class Clause {
  const Clause();
  MatchResult match(Parser parser, int pos, {Clause? bound});
  void checkRuleRefs(Map<String, Clause> grammarMap);
  @override
  String toString() => runtimeType.toString();
}
