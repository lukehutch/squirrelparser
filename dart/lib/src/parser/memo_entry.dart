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
      // Positioned, so that a seed which escapes into a tree still reports the
      // right frontier: the cycle has read nothing here.
      result = Mismatch(clause, pos, 0);
      return result!;
    }
    inRecPath = true;
    do {
      parserStats?.recordMatch();
      final newResult = clause.match(parser, pos);
      // THE FIXED POINT IS TESTED ON isMismatch, NOT ON LENGTH. This used to
      // read `newResult.len <= result!.len`, which was correct only because a
      // mismatch was a shared tombstone with `len == -1`: no match could lose
      // to one, and a mismatch could never replace a match. A mismatch now
      // carries the input it consumed before failing, so its `len` is >= 0 and
      // that arithmetic would let a mismatch that read far overwrite a short
      // match. Both directions are now stated outright.
      if (result != null && (newResult.isMismatch || (!result!.isMismatch && newResult.len <= result!.len))) {
        // Either the new attempt failed -- a match is never replaced by a
        // mismatch -- or it did not grow. Fixed point reached.
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
