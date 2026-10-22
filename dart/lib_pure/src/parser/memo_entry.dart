import 'clause.dart';
import 'match_result.dart';
import 'parser.dart';
import 'parser_stats.dart';

/// A memo table entry for a (rule, position) pair.
///
/// Contains the main logic of the squirrel parsing algorithm: metadata about
/// the current recursion path and about efforts to expand left recursive
/// cycles is folded into the memo entry, whether or not a match result is
/// stored in it yet.
class MemoEntry {
  /// The best match found so far for this rule at this position.
  MatchResult? result;

  /// True while this (rule, pos) is on the current recursion path.
  /// Used to detect left recursive cycles without a separate visited set.
  bool inRecPath = false;

  /// Set to true by a descendant recursion frame when a left recursive cycle
  /// is detected at this (rule, pos), signalling to this (ancestral) frame
  /// that it should iteratively expand the left recursive cycle.
  bool foundLeftRec = false;

  /// The value of parser.memoVersion[pos] last time this entry was updated.
  /// Ensures memos from previous left recursion expansions do not prevent
  /// re-matching after the cycle has been expanded, without duplicating work.
  int memoVersion = 0;

  /// Match this entry's rule at [pos], handling left recursion and caching.
  MatchResult match(Parser parser, Clause clause, int pos) {
    if (result != null && (inRecPath || memoVersion == parser.memoVersion[pos])) {
      // Memo hit: no work has been done to expand a left recursive cycle at
      // this position since the last match attempt (or this is a cycle back
      // to a (rule, pos) already on the recursion path, with a known result).
      parserStats?.recordCacheHit();
      return result!;
    } else if (inRecPath) {
      // (rule, pos) was visited twice in the same recursion path, with no
      // match result yet: this is the fixed point of a left recursive cycle.
      // Signal the ancestral frame to expand the cycle, and seed the cycle
      // with a mismatch.
      foundLeftRec = true;
      result = mismatch;
      return result!;
    }
    inRecPath = true;
    do {
      parserStats?.recordMatch();
      final newResult = clause.match(parser, pos);
      if (result != null && newResult.len <= result!.len) {
        // The match did not increase in length: fixed point reached.
        // (A match is never overwritten by a mismatch, since MISMATCH has
        // sentinel len -1, and a shorter match never overwrites a longer one.)
        break;
      }
      result = newResult;
      if (!foundLeftRec) {
        // No left recursive cycle was encountered below this frame: done.
        break;
      }
      // Try to expand the left recursive cycle to incorporate the match found
      // so far as a subtree of a longer match.
      parserStats?.recordLRExpansion();
      memoVersion = ++parser.memoVersion[pos];
    } while (true);
    inRecPath = false;
    memoVersion = parser.memoVersion[pos];
    return result!;
  }
}
