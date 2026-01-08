import 'match_result.dart';

/// Count total syntax errors in a parse tree.
int countErrors(MatchResult? result) {
  if (result == null || result.isMismatch) return 0;
  int count = (result is SyntaxError) ? 1 : 0;
  for (final child in result.subClauseMatches) {
    count += countErrors(child);
  }
  return count;
}

/// Get list of skipped strings from syntax errors.
List<String> getSkippedStrings(MatchResult? result) {
  final skipped = <String>[];
  void collect(MatchResult? r) {
    if (r == null || r.isMismatch) return;
    if (r is SyntaxError && !r.isDeletion) {
      skipped.add(r.skipped);
    }
    for (final child in r.subClauseMatches) {
      collect(child);
    }
  }

  collect(result);
  return skipped;
}

/// Get syntax errors from a parse tree.
///
/// The parse tree is expected to span the entire input (invariant from Parser.parse()).
/// All syntax errors are already embedded in the tree as SyntaxError nodes.
List<SyntaxError> getSyntaxErrors(MatchResult result) {
  final syntaxErrors = <SyntaxError>[];
  void collect(MatchResult r) {
    if (r.isMismatch) return;
    if (r is SyntaxError) {
      syntaxErrors.add(r);
    }
    for (final child in r.subClauseMatches) {
      collect(child);
    }
  }

  collect(result);
  return syntaxErrors;
}
