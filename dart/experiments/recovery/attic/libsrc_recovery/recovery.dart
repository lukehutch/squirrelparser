/// Error recovery for the squirrel parser: minimum-cost repair search.
///
/// Usage:
/// ```dart
/// final rules = MetaGrammar.parseGrammar(grammarSpec);
/// final parser = Parser(rules: rules, topRuleName: top, input: input);
/// final result = parser.parse();                  // pure, linear
/// if (result.hasSyntaxErrors) {
///   final repair = RepairSearch(rules: rules, topRuleName: top).repair(input);
///   // repair.repaired, repair.cost, repair.edits, repair.parseResult
/// }
/// ```
library;

export 'observed_grammar.dart' show FailureObserver, instrumentGrammar;
export 'repair_search.dart';
export 'witness.dart' show computeRuleWitnesses;
