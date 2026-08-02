// _core2.dart -- `_core.dart` with ONE further change: a mismatch is no longer a
// tombstone. It is a node, with a position, a real consumed length, and the
// subclause results that produced it.
//
// WHY. The recovery engines all have to answer "where does the input stop being
// consistent with the grammar?" -- the FRONTIER -- and today they answer it by
// probing: re-match candidate clauses at candidate positions and see how far
// they get. But the parse already computed the answer and threw it away. A
// singleton `mismatch` with `len == -1` records that a clause failed; it does
// not record that `Str("abc")` failed at pos 4 having agreed with `ab` first,
// so index 6 was reached. Recomputing that is the widening loop's whole cost.
//
// WHAT CHANGES. Two things, and the second only became obvious once the first
// was measured.
//
//   1. `Mismatch` carries `(clause, pos, len, subClauseMatches)`, where `len` is
//      what THIS node consumed directly before failing and the children are what
//      it consumed it with. `len` is DIRECTLY consumed, not deepest reach: a
//      `Seq` that failed in slot 3 spans its first two slots, and slot 3's own
//      extent lives on slot 3's own node. That keeps `pos + len` meaning the
//      same thing for a mismatch as for a match -- the span this node accounts
//      for -- so a mismatch can be read like any other node.
//
//   2. Every node carries `reach`: the end of the input that subtree found
//      consistent with the grammar. Mismatch children alone are NOT enough for
//      this, and the gate is what showed it. A clause that SUCCEEDS discards the
//      attempts it made along the way, and those attempts are frequently the
//      only record of where the input really stopped: JSON's `(Member ...)?` on
//      `{"a:1,...` parses a whole String and fails at the missing `:`, then
//      matches empty, and the `Object` above it reported a frontier of 1 when
//      the input was consistent through 7 -- WORSE than the crude memo-table
//      probe it was meant to replace. Discarded attempts now fold their reach
//      into the parent and are then dropped, so the fact survives and the
//      subtree does not.

// A `dropped` list is therefore constructor-only: it is read for its reach and
// never stored, which is what lets "no mismatch node survives inside a match"
// stay true while the frontier still knows what the mismatches knew.
//
// WHAT MUST NOT CHANGE. Ordinary parsing. Every consumer of a mismatch reads
// only `isMismatch`, with exactly one exception -- the left recursion fixed
// point test in [MemoEntry.match], which compared `len` and relied on the `-1`
// sentinel to mean "shorter than every match". That test is rewritten to ask
// `isMismatch` directly; see the four-case argument there. `_core2gate.dart`
// checks the whole of it against the frozen library.
//
// Inherited unchanged from `_core.dart`:
//
//   1. `input` is MUTABLE, and `memoVersion` resizes with it, so one parser can
//      be re-aimed at a new candidate string without being rebuilt.
//   2. `memoTable` is PUBLIC, so it can be seeded, forked, or selectively
//      invalidated from the recovery code.
//   3. Every match records a READ EXTENT. `Parser.maxRead` is the largest input
//      index whose content could have changed the outcome -- counting "is there
//      a character here at all?" as a read of that index -- and `MemoEntry`
//      brackets its own match to store its own `readEnd`. That is what makes
//      memo reuse SOUND rather than merely fast: an entry memoized at position
//      p survives an edit at position e exactly when `readEnd < e`.
//
// A read extent is NOT a frontier: `Char('z')` at 4 reads index 4 whether or not
// it matches, so `readEnd` always includes the character that broke the parse.
// `reach` below is the frontier's watermark, and the two differ by exactly that.
import 'package:squirrel_parser/squirrel_parser.dart' as sp;
import 'package:squirrel_parser/src/recovery/skip_recovery.dart' as spr;

// CORE BEGIN
String escapeString(String s) {
  final buffer = StringBuffer();
  for (final rune in s.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(switch (char) {
      '\\' => r'\\',
      '"' => r'\"',
      "'" => r"\'",
      '\n' => r'\n',
      '\r' => r'\r',
      '\t' => r'\t',
      '\b' => r'\b',
      _ => (rune <= 0x1f || (rune >= 0x7f && rune <= 0xffff))
          ? '\\u${rune.toRadixString(16).padLeft(4, '0')}'
          : (rune > 0xffff)
              ? '\\u{${rune.toRadixString(16)}}'
              : char,
    });
  }
  return buffer.toString();
}

/// Base class for all grammar clauses.
abstract class Clause {
  const Clause();
  MatchResult match(Parser parser, int pos);
  @override
  String toString() => runtimeType.toString();
}

abstract class HasOneSubClause extends Clause {
  final Clause subClause;
  const HasOneSubClause(this.subClause);
}

abstract class HasMultipleSubClauses extends Clause {
  final List<Clause> subClauses;
  const HasMultipleSubClauses(this.subClauses);
}

// ---------------------------------------------------------------- match result

int _totalLength(List<MatchResult> children) =>
    children.isEmpty ? 0 : children.last.pos + children.last.len - children.first.pos;

/// The furthest position reached by [own], by any of [kids], or by [dropped] --
/// the reach of what a successful clause tried and then threw away.
///
/// [dropped] is an int and not a node, so that discarding an attempt costs no
/// allocation at all: the sites that discard -- `X?`, the iteration that stops a
/// repetition, a predicate body -- are on the hot success path, and a one
/// element list at each of them was measurably the largest part of this file's
/// overhead over `_core.dart`.
int _reachOf(int own, List<MatchResult> kids, int dropped) {
  var r = own > dropped ? own : dropped;
  for (final k in kids) {
    if (k.reach > r) r = k.reach;
  }
  return r;
}

/// Result of matching a clause at a position.
abstract class MatchResult {
  final Clause? clause;
  final int pos;
  final int len;

  /// THE FRONTIER of this subtree: the end of the input it found consistent with
  /// the grammar. `pos + len` for a clause that matched and never tried anything
  /// else; further whenever something inside it agreed and then failed.
  ///
  /// An int, not a walk over the children, for two reasons. It is O(1) to ask,
  /// which matters because the widening loop asks constantly. And it is the only
  /// way to keep what a SUCCESSFUL clause discarded: an `X?` that matched empty
  /// still learned how far `X` agreed before failing, and that number is often
  /// the only evidence of where the input really stopped making sense -- but the
  /// discarded subtree itself must not be retained, or a parse would hold every
  /// failed attempt it ever made. Folding it into an int keeps the fact and
  /// drops the memory, and it is why no mismatch node survives in a match.
  ///
  /// A watermark, so it RISES: see [raise], and the left recursion fixed point
  /// in [MemoEntry.match], which is the one place a finished node learns that a
  /// later expansion of the same (rule, pos) read further than it did.
  int reach;

  MatchResult(this.clause, this.pos, this.len, this.reach);

  /// Fold a discarded sibling's frontier into this one. Only ever called before
  /// this node has a parent, so no parent's [reach] can go stale behind it.
  void raise(int r) {
    if (r > reach) reach = r;
  }

  List<MatchResult> get subClauseMatches;
  bool get isMismatch => false;
}

/// A successful match. Terminals have no children, combinators have one or more.
class Match extends MatchResult {
  @override
  final List<MatchResult> subClauseMatches;

  Match(Clause? clause, int pos, int len,
      {this.subClauseMatches = const [], int droppedReach = -1})
      : super(
            clause,
            subClauseMatches.isEmpty ? pos : subClauseMatches.first.pos,
            subClauseMatches.isEmpty ? len : _totalLength(subClauseMatches),
            _reachOf(
                subClauseMatches.isEmpty
                    ? pos + len
                    : subClauseMatches.first.pos + _totalLength(subClauseMatches),
                subClauseMatches,
                droppedReach));
}

/// A clause that did not match, and the record of how far it got before that.
///
/// NOT a [Match] subclass, unlike the tombstone it replaces: [Match] recomputes
/// `pos` and `len` from its children, which is exactly what must not happen to a
/// span that is deliberately SHORTER than its children's extent.
///
/// [len] is what this clause consumed directly before failing. For a [Seq] that
/// is its satisfied prefix; for everything else it is 0, because nothing else
/// consumes on its own behalf. The failing subclause's own extent is on the
/// failing subclause's own node, and [reach] is what adds them up.
class Mismatch extends MatchResult {
  @override
  final List<MatchResult> subClauseMatches;

  Mismatch(Clause? clause, int pos, int len,
      {this.subClauseMatches = const [], int droppedReach = -1})
      : super(clause, pos, len,
            _reachOf(pos + len, subClauseMatches, droppedReach));

  @override
  bool get isMismatch => true;

  @override
  String toString() => 'MISMATCH ${clause ?? "_"} @$pos+$len reach=$reach';
}

/// The end of the input this subtree found consistent with the grammar.
///
/// A field read. It is a function only so that call sites read as a question
/// about the tree rather than as an attribute of a node.
int frontier(MatchResult m) => m.reach;

/// A span of input that could not be matched.
class SyntaxError extends Match {
  SyntaxError({required int pos, required int len}) : super(null, pos, len);
  @override
  String toString() => '$len characters of unexpected input at pos $pos';
}

// ------------------------------------------------------------------ combinators

/// Sequence: matches all sub-clauses in order.
class Seq extends HasMultipleSubClauses {
  const Seq(super.subClauses);

  @override
  MatchResult match(Parser parser, int pos) {
    final children = <MatchResult>[];
    int curr = pos;
    for (int i = 0; i < subClauses.length; i++) {
      final result = subClauses[i].match(parser, curr);
      if (result.isMismatch) {
        // The satisfied prefix is [pos, curr) and it is real: those slots each
        // matched. The failing slot goes in as the last child, carrying its own
        // reach, so the two together are the whole of what this Seq learned.
        // `children` is dead after this, so it is extended rather than copied.
        children.add(result);
        return Mismatch(this, pos, curr - pos, subClauseMatches: children);
      }
      children.add(result);
      curr += result.len;
    }
    if (children.isEmpty) return Match(this, pos, 0);
    return Match(this, 0, 0, subClauseMatches: children);
  }

  @override
  String toString() => '(${subClauses.join(' ')})';
}

/// Ordered choice: matches the first successful sub-clause.
class First extends HasMultipleSubClauses {
  const First(super.subClauses);

  @override
  MatchResult match(Parser parser, int pos) {
    List<MatchResult>? failed;
    var failedReach = -1;
    for (int i = 0; i < subClauses.length; i++) {
      final result = subClauses[i].match(parser, pos);
      if (!result.isMismatch) {
        // The arms that lost still read the input, and one of them may have
        // agreed further than the arm that won -- `("abcd" / "ab") 'z'` on
        // `abcX` commits to `ab` and breaks at 2, but the input was consistent
        // through 3. Their reach is kept; their subtrees are not.
        return Match(this, 0, 0,
            subClauseMatches: [result], droppedReach: failedReach);
      }
      (failed ??= <MatchResult>[]).add(result);
      if (result.reach > failedReach) failedReach = result.reach;
    }
    // A First consumes nothing of its own: every arm started at `pos` and every
    // arm failed. All of them are kept, because the arm that reached furthest is
    // not in general the last one tried, and the frontier is over all of them.
    return Mismatch(this, pos, 0, subClauseMatches: failed ?? const []);
  }

  @override
  String toString() => '(${subClauses.join(' / ')})';
}

/// Base class for repetition (OneOrMore, ZeroOrMore).
class Repetition extends HasOneSubClause {
  final bool requireOne;
  const Repetition(super.subClause, {required this.requireOne});

  @override
  MatchResult match(Parser parser, int pos) {
    final children = <MatchResult>[];
    MatchResult? last;
    int curr = pos;
    while (curr <= parser.input.length) {
      final result = subClause.match(parser, curr);
      last = result;
      if (result.isMismatch) break;
      // Never consume more than one zero-length subclause match, to prevent an
      // infinite loop (e.g. for the pathological grammar "()*").
      if (result.len == 0) break;
      children.add(result);
      curr += result.len;
    }
    // The loop bound is a question about the input at `curr`, so record it.
    parser.read(curr);
    if (requireOne && children.isEmpty) {
      // Zero iterations, so nothing consumed; the attempt that ended the loop is
      // the only thing this node learned, and it is what reached furthest.
      return Mismatch(this, pos, 0,
          subClauseMatches: last == null ? const [] : [last]);
    }
    // The attempt that STOPPED a successful repetition is where the input
    // stopped looking like another iteration -- `("ab")*` on `ababaX` halts at
    // 4 having agreed with the `a` at 4. Kept as reach, dropped as a node.
    final tail = last == null ? -1 : last.reach;
    if (children.isEmpty) return Match(this, pos, 0, droppedReach: tail);
    return Match(this, 0, 0, subClauseMatches: children, droppedReach: tail);
  }
}

class OneOrMore extends Repetition {
  const OneOrMore(super.subClause) : super(requireOne: true);
  @override
  String toString() => '$subClause+';
}

class ZeroOrMore extends Repetition {
  const ZeroOrMore(super.subClause) : super(requireOne: false);
  @override
  String toString() => '$subClause*';
}

/// Optional: matches zero or one instance.
class Optional extends HasOneSubClause {
  const Optional(super.subClause);

  @override
  MatchResult match(Parser parser, int pos) {
    final result = subClause.match(parser, pos);
    // Matching empty is not the same as learning nothing. This is the single
    // biggest source of a lost frontier: JSON's `(Member ...)?` on `{"a:1,...`
    // parses a whole String and fails at the missing `:`, and without the reach
    // the Object above it reports a frontier of 1 instead of 7.
    if (result.isMismatch) {
      return Match(this, pos, 0, droppedReach: result.reach);
    }
    return Match(this, 0, 0, subClauseMatches: [result]);
  }

  @override
  String toString() => '$subClause?';
}

/// Reference to a named rule: the only clause that recurses through the memo
/// table, so memoization happens at rule granularity.
class Ref extends Clause {
  final String ruleName;
  const Ref(this.ruleName);

  @override
  MatchResult match(Parser parser, int pos) {
    final clause = parser.rules[ruleName];
    if (clause == null) throw ArgumentError('Rule "$ruleName" not found');
    final result = parser.match(clause, pos);
    // The rule's own mismatch is the memoized one, so this child is SHARED, not
    // rebuilt: the frontier walks a DAG, and the memo table is what stops the
    // recursion the user warned about from duplicating any work.
    if (result.isMismatch) return Mismatch(this, pos, 0, subClauseMatches: [result]);
    return Match(this, 0, 0, subClauseMatches: [result]);
  }

  @override
  String toString() => ruleName;
}

/// Negative lookahead: succeeds if sub-clause fails, consumes nothing.
class NotFollowedBy extends HasOneSubClause {
  const NotFollowedBy(super.subClause);

  @override
  MatchResult match(Parser parser, int pos) {
    final result = subClause.match(parser, pos);
    // Failing means the body MATCHED: the child of this mismatch is a Match, and
    // it spans the forbidden text. Kept, because "what was here instead" is the
    // most specific thing a `!` failure knows.
    //
    // Succeeding means the body failed, and how far it agreed before failing is
    // a fact about the input like any other. A predicate consumes nothing, but
    // `reach` is not about consumption -- it is about where the input stopped
    // being consistent with anything the grammar could read.
    return result.isMismatch
        ? Match(this, pos, 0, droppedReach: result.reach)
        : Mismatch(this, pos, 0, subClauseMatches: [result]);
  }

  @override
  String toString() => '!$subClause';
}

/// Positive lookahead: succeeds if sub-clause succeeds, consumes nothing.
class FollowedBy extends HasOneSubClause {
  const FollowedBy(super.subClause);

  @override
  MatchResult match(Parser parser, int pos) {
    final result = subClause.match(parser, pos);
    // Succeeding consumes nothing but proves the body's whole span agreed, so
    // the match it throws away is exactly a reach it should keep.
    return result.isMismatch
        ? Mismatch(this, pos, 0, subClauseMatches: [result])
        : Match(this, pos, 0, droppedReach: result.reach);
  }

  @override
  String toString() => '&$subClause';
}

// -------------------------------------------------------------------- terminals

abstract class Terminal extends Clause {
  const Terminal();
}

/// Matches a literal string.
class Str extends Terminal {
  final String text;
  const Str(this.text);

  @override
  MatchResult match(Parser parser, int pos) {
    if (pos + text.length > parser.input.length) {
      parser.read(pos + text.length - 1);
      // Runs off the end. The prefix that IS there may still agree, and how much
      // of it does is the whole reason this clause knows more than "no": the
      // loop below is the only work `_core.dart` skips that this file does.
      var i = 0;
      while (pos + i < parser.input.length &&
          parser.input.codeUnitAt(pos + i) == text.codeUnitAt(i)) {
        i++;
      }
      parser.agreed(pos + i);
      return Mismatch(this, pos, i);
    }
    for (int i = 0; i < text.length; i++) {
      if (parser.input.codeUnitAt(pos + i) != text.codeUnitAt(i)) {
        parser.read(pos + i);
        parser.agreed(pos + i);
        return Mismatch(this, pos, i);
      }
    }
    parser.read(pos + text.length - 1);
    parser.agreed(pos + text.length);
    return Match(this, pos, text.length);
  }

  @override
  String toString() => '"${escapeString(text)}"';
}

/// Matches a single character.
class Char extends Terminal {
  final String char;
  const Char(this.char) : assert(char.length == 1);

  @override
  MatchResult match(Parser parser, int pos) {
    parser.read(pos);
    // `agreed` sits on each branch rather than once at the top, so the matching
    // path -- the hot one -- pays for a single watermark update, not two.
    if (pos >= parser.input.length || parser.input.codeUnitAt(pos) != char.codeUnitAt(0)) {
      parser.agreed(pos);
      return Mismatch(this, pos, 0);
    }
    parser.agreed(pos + 1);
    return Match(this, pos, 1);
  }

  @override
  String toString() => "'${escapeString(char)}'";
}

/// Matches a single character in a set of code unit ranges.
class CharSet extends Terminal {
  final List<(int, int)> ranges;
  final bool inverted;
  const CharSet(this.ranges, {this.inverted = false});

  CharSet.range(String lo, String hi)
      : ranges = [(lo.codeUnitAt(0), hi.codeUnitAt(0))],
        inverted = false;
  CharSet.char(String c)
      : ranges = [(c.codeUnitAt(0), c.codeUnitAt(0))],
        inverted = false;
  CharSet.notRange(String lo, String hi)
      : ranges = [(lo.codeUnitAt(0), hi.codeUnitAt(0))],
        inverted = true;

  @override
  MatchResult match(Parser parser, int pos) {
    parser.read(pos);
    if (pos >= parser.input.length) {
      parser.agreed(pos);
      return Mismatch(this, pos, 0);
    }
    final c = parser.input.codeUnitAt(pos);
    bool inSet = false;
    for (final (lo, hi) in ranges) {
      if (c >= lo && c <= hi) {
        inSet = true;
        break;
      }
    }
    if (inverted ? !inSet : inSet) {
      parser.agreed(pos + 1);
      return Match(this, pos, 1);
    }
    parser.agreed(pos);
    return Mismatch(this, pos, 0);
  }

  @override
  String toString() {
    final buf = StringBuffer('[');
    if (inverted) buf.write('^');
    for (final (lo, hi) in ranges) {
      if (lo == hi) {
        buf.write(escapeString(String.fromCharCode(lo)));
      } else {
        buf.write(escapeString(String.fromCharCode(lo)));
        buf.write('-');
        buf.write(escapeString(String.fromCharCode(hi)));
      }
    }
    buf.write(']');
    return buf.toString();
  }
}

/// Matches any single character.
class AnyChar extends Terminal {
  const AnyChar();

  @override
  MatchResult match(Parser parser, int pos) {
    parser.read(pos);
    if (pos >= parser.input.length) {
      parser.agreed(pos);
      return Mismatch(this, pos, 0);
    }
    parser.agreed(pos + 1);
    return Match(this, pos, 1);
  }

  @override
  String toString() => '.';
}

/// Matches nothing - always succeeds without consuming any input.
class Nothing extends Terminal {
  const Nothing();

  @override
  MatchResult match(Parser parser, int pos) => Match(this, pos, 0);

  @override
  String toString() => '()';
}

// ------------------------------------------------------------------ memo entry

/// A memo table entry for a (rule, position) pair. Holds the main logic of the
/// squirrel algorithm: left recursion metadata folded into the entry itself.
class MemoEntry {
  MatchResult? result;

  /// True while this (rule, pos) is on the current recursion path.
  bool inRecPath = false;

  /// Set by a descendant frame when a left recursive cycle is detected here.
  bool foundLeftRec = false;

  /// The value of parser.memoVersion[pos] last time this entry was updated.
  int memoVersion = 0;

  /// The largest input index that could have changed this entry's result.
  /// Reusable across an edit at position e exactly when `readEnd < e`.
  int readEnd = -1;

  MatchResult match(Parser parser, Clause clause, int pos) {
    if (result != null && (inRecPath || memoVersion == parser.memoVersion[pos])) {
      // Memo hit. The caller still depends on everything this entry read.
      if (readEnd > parser.maxRead) parser.maxRead = readEnd;
      return result!;
    } else if (inRecPath) {
      // (rule, pos) visited twice on one recursion path with no result yet:
      // the fixed point of a left recursive cycle. Signal the ancestral frame.
      foundLeftRec = true;
      result = Mismatch(clause, pos, 0);
      return result!;
    }
    // Bracket this entry's own reads so `readEnd` is its own, not its parent's.
    final saved = parser.maxRead;
    parser.maxRead = -1;
    inRecPath = true;
    do {
      final newResult = clause.match(parser, pos);
      if (result != null &&
          (newResult.isMismatch ||
              (!result!.isMismatch && newResult.len <= result!.len))) {
        // The match did not grow: fixed point reached.
        //
        // THE ONE PLACE THE `-1` SENTINEL WAS LOAD BEARING. `_core.dart` writes
        // this as `newResult.len <= result!.len` and leans on MISMATCH having
        // len -1, so that a mismatch loses to every match and ties with itself.
        // A mismatch now carries a REAL consumed length, and a mismatch of len 5
        // would beat a match of len 3 and overwrite it, collapsing the left
        // recursive expansion. So the test asks `isMismatch` instead. The four
        // cases, each identical to what the sentinel used to produce:
        //
        //   new mismatch, old mismatch -> break   (was -1 <= -1)
        //   new mismatch, old match    -> break, keeping the match  (was -1 <= n)
        //   new match, old mismatch    -> grow    (was n > -1)
        //   new match, old match       -> compare lengths, unchanged
        //
        // The expansion being thrown away here still read the input, and on
        // `E <- E '+' T / T` over `1+a22` it is the ONLY thing that ever looked
        // at index 2 -- the kept result is the bare `1` from the round before.
        // Its frontier comes along even though its tree does not.
        result!.raise(newResult.reach);
        break;
      }
      if (result != null) newResult.raise(result!.reach);
      result = newResult;
      if (!foundLeftRec) break;
      memoVersion = ++parser.memoVersion[pos];
    } while (true);
    inRecPath = false;
    memoVersion = parser.memoVersion[pos];
    readEnd = parser.maxRead;
    parser.maxRead = saved > readEnd ? saved : readEnd;
    return result!;
  }
}

// ---------------------------------------------------------------------- parser

/// A memoizing recursive descent (packrat) parser that directly supports left
/// recursive PEG grammars.
class Parser {
  final Map<String, Clause> rules;
  final Set<String> transparentRules;
  final String topRuleName;

  /// The input. Mutable: assign through [retarget] to keep memoVersion sized.
  String input;

  /// The memo table, public so recovery can seed or invalidate it.
  final Map<Clause, Map<int, MemoEntry>> memoTable = {};

  /// How many times a left recursive cycle has been expanded at each position.
  List<int> memoVersion;

  /// The largest input index read since this watermark was last reset.
  int maxRead = -1;

  /// The furthest input position any terminal AGREED up to, anywhere in the
  /// parse -- including inside branches that were later discarded.
  ///
  /// This is the frontier as a global watermark, and it exists to check the one
  /// computed from the tree: the tree's version is per-subtree and is the one
  /// recovery needs, but it can only see nodes the tree kept. Where the two
  /// disagree, the parse dropped something. `_core2gate.dart` is that check.
  int reach = -1;

  Parser({required Map<String, Clause> rules, required this.topRuleName, required this.input})
      : rules = {},
        transparentRules = {},
        memoVersion = List.filled(input.length + 1, 0) {
    for (final entry in rules.entries) {
      if (entry.key.startsWith('~')) {
        this.rules[entry.key.substring(1)] = entry.value;
        transparentRules.add(entry.key.substring(1));
      } else {
        this.rules[entry.key] = entry.value;
      }
    }
  }

  /// Record that the outcome could depend on the input at [i] -- including the
  /// question "is there a character at [i] at all?".
  void read(int i) {
    if (i > maxRead) maxRead = i;
  }

  /// Record that the input up to (not including) [i] agreed with some terminal.
  void agreed(int i) {
    if (i > reach) reach = i;
  }

  /// Point this parser at a new input, discarding every memo entry that could
  /// have read at or past [editPos]. With `editPos == 0` this is a full reset.
  void retarget(String newInput, int editPos) {
    input = newInput;
    if (memoVersion.length < newInput.length + 1) {
      memoVersion = List.filled(newInput.length + 1, 0);
    } else {
      memoVersion.fillRange(0, memoVersion.length, 0);
    }
    for (final byPos in memoTable.values) {
      byPos.removeWhere((pos, e) => pos >= editPos || e.readEnd >= editPos);
    }
    maxRead = -1;
    reach = -1;
  }

  /// Match a rule's top clause at a position, using memoization.
  MatchResult match(Clause clause, int pos) {
    if (pos > input.length) return Mismatch(clause, pos, 0);
    final memoEntry =
        memoTable.putIfAbsent(clause, () => {}).putIfAbsent(pos, MemoEntry.new);
    return memoEntry.match(this, clause, pos);
  }

  /// Match a named rule at a position.
  MatchResult matchRule(String ruleName, int pos) {
    final clause = rules[ruleName];
    if (clause == null) throw ArgumentError('Rule "$ruleName" not found');
    return match(clause, pos);
  }

  MemoEntry? getMemoEntry(Clause clause, int pos) => memoTable[clause]?[pos];

  /// The largest input position of any mismatch recorded in the memo table, or
  /// -1 if there is none: the approximate position of the first syntax error.
  int syntaxErrorPosition() {
    var maxPos = -1;
    for (final entriesForClause in memoTable.values) {
      for (final entry in entriesForClause.entries) {
        if (entry.value.result?.isMismatch == true && entry.key > maxPos) {
          maxPos = entry.key;
        }
      }
    }
    return maxPos;
  }

  /// Parse the input, starting by matching the top rule at position 0. The core
  /// algorithm performs no error recovery.
  ParseResult parse() {
    final result = matchRule(topRuleName, 0);
    return ParseResult(
      input: input,
      root: !result.isMismatch ? result : SyntaxError(pos: 0, len: input.length),
      topRuleName: topRuleName,
      transparentRules: transparentRules,
      hasSyntaxErrors: result.isMismatch || result.len != input.length,
      unmatchedInput: !result.isMismatch && result.len < input.length
          ? SyntaxError(pos: result.len, len: input.length - result.len)
          : null,
    );
  }
}

/// The result of parsing the input.
class ParseResult {
  final String input;
  final MatchResult root;
  final String topRuleName;
  final Set<String> transparentRules;
  final bool hasSyntaxErrors;
  final SyntaxError? unmatchedInput;

  ParseResult(
      {required this.input,
      required this.root,
      required this.topRuleName,
      required this.transparentRules,
      required this.hasSyntaxErrors,
      this.unmatchedInput});
}

// ----------------------------------------------------------- recovery contract
// The output shape every engine returns. It lives here, outside the marked
// region, because it is the same contract for all of them and counting it would
// charge each engine for the same boilerplate.

class MissingObligation {
  final Clause clause;
  final int pos;
  MissingObligation(this.clause, this.pos);
  @override
  String toString() => 'missing $clause at $pos';
}

class SkipResult {
  /// Full-coverage parse tree over the original input; unparseable regions
  /// appear as SyntaxError children, in position order.
  final MatchResult root;

  /// Skipped input spans (each also present in the tree as a SyntaxError).
  final List<SyntaxError> errorSpans;

  /// Obligations that were skipped as missing.
  final List<MissingObligation> missing;

  /// Number of recovery events (0 = input was valid).
  final int recoveryEvents;

  /// True if the event cap was hit and the tail was force-wrapped.
  final bool forced;

  SkipResult(this.root, this.errorSpans, this.missing, this.recoveryEvents, this.forced);

  int get charsSkipped => errorSpans.fold(0, (a, e) => a + e.len);
  bool get clean => recoveryEvents == 0;
}

// ------------------------------------------------------- library <-> core glue
// The engine's public API speaks the library's types, so the grammar is lowered
// in at construction and the witness tree is raised back out at the boundary.

/// Lower a library clause tree into this core's clause types. [back] records the
/// inverse so the witness tree can be raised again.
Clause toCore(sp.Clause c, Map<sp.Clause, Clause> memo, Map<Clause, sp.Clause> back) {
  final hit = memo[c];
  if (hit != null) return hit;
  Clause out;
  if (c is sp.Str) {
    out = Str(c.text);
  } else if (c is sp.Char) {
    out = Char(c.char);
  } else if (c is sp.CharSet) {
    out = CharSet(c.ranges, inverted: c.inverted);
  } else if (c is sp.AnyChar) {
    out = AnyChar();
  } else if (c is sp.Nothing) {
    out = Nothing();
  } else if (c is sp.Ref) {
    out = Ref(c.ruleName);
  } else if (c is sp.Seq) {
    out = Seq([for (final s in c.subClauses) toCore(s, memo, back)]);
  } else if (c is sp.First) {
    out = First([for (final s in c.subClauses) toCore(s, memo, back)]);
  } else if (c is sp.OneOrMore) {
    out = OneOrMore(toCore(c.subClause, memo, back));
  } else if (c is sp.ZeroOrMore) {
    out = ZeroOrMore(toCore(c.subClause, memo, back));
  } else if (c is sp.Optional) {
    out = Optional(toCore(c.subClause, memo, back));
  } else if (c is sp.FollowedBy) {
    out = FollowedBy(toCore(c.subClause, memo, back));
  } else if (c is sp.NotFollowedBy) {
    out = NotFollowedBy(toCore(c.subClause, memo, back));
  } else {
    throw ArgumentError('unknown clause ${c.runtimeType}');
  }
  memo[c] = out;
  back[out] = c;
  return out;
}

Map<String, Clause> rulesToCore(Map<String, sp.Clause> rules, Map<Clause, sp.Clause> back) {
  final memo = <sp.Clause, Clause>{};
  return {for (final e in rules.entries) e.key: toCore(e.value, memo, back)};
}

/// Raise a core match tree back into the library's types.
sp.MatchResult toLib(MatchResult m, Map<Clause, sp.Clause> back) {
  if (m is SyntaxError) return sp.SyntaxError(pos: m.pos, len: m.len);
  // A returned tree holds matches and syntax errors and nothing else. A mismatch
  // that got this far would be silently rebuilt as an `sp.Match` whose span is
  // recomputed from its children -- a wrong span on a node that should not
  // exist -- so it is an error here rather than a puzzle downstream.
  if (m.isMismatch) throw StateError('mismatch survived into the returned tree: $m');
  final kids = [for (final k in m.subClauseMatches) toLib(k, back)];
  final c = m.clause;
  return sp.Match(c == null ? null : fromCore(c, back), m.pos, m.len,
      subClauseMatches: kids);
}

/// Raise a core clause back into the library's types. Usually a lookup in
/// [back], but an engine may INVENT a clause that was never lowered -- a
/// fabricated `CharSet` naming a missing character, say -- so anything absent is
/// rebuilt structurally rather than dropped.
sp.Clause fromCore(Clause c, Map<Clause, sp.Clause> back) {
  final hit = back[c];
  if (hit != null) return hit;
  if (c is Str) return sp.Str(c.text);
  if (c is Char) return sp.Char(c.char);
  if (c is CharSet) return sp.CharSet(c.ranges, inverted: c.inverted);
  if (c is AnyChar) return const sp.AnyChar();
  if (c is Nothing) return const sp.Nothing();
  if (c is Ref) return sp.Ref(c.ruleName);
  if (c is Seq) return sp.Seq([for (final s in c.subClauses) fromCore(s, back)]);
  if (c is First) return sp.First([for (final s in c.subClauses) fromCore(s, back)]);
  if (c is OneOrMore) return sp.OneOrMore(fromCore(c.subClause, back));
  if (c is ZeroOrMore) return sp.ZeroOrMore(fromCore(c.subClause, back));
  if (c is Optional) return sp.Optional(fromCore(c.subClause, back));
  if (c is FollowedBy) return sp.FollowedBy(fromCore(c.subClause, back));
  if (c is NotFollowedBy) return sp.NotFollowedBy(fromCore(c.subClause, back));
  throw ArgumentError('unknown core clause ${c.runtimeType}');
}

/// Raise a whole recovery result into the library's types: the boundary every
/// engine crosses exactly once, on the way out of `recover`.
spr.SkipResult toLibResult(SkipResult r, Map<Clause, sp.Clause> back) => spr.SkipResult(
      toLib(r.root, back),
      [for (final e in r.errorSpans) sp.SyntaxError(pos: e.pos, len: e.len)],
      [for (final m in r.missing) spr.MissingObligation(fromCore(m.clause, back), m.pos)],
      r.recoveryEvents,
      r.forced,
    );
// CORE END

void main() {
  final back = <Clause, sp.Clause>{};
  final rules = rulesToCore(sp.MetaGrammar.parseGrammar("S <- 'a'+ \"bcd\";\n"), back);
  for (final s in ['aabcd', 'aabcX', 'aab', 'X']) {
    final p = Parser(rules: rules, topRuleName: 'S', input: s);
    final r = p.matchRule('S', 0);
    print('"$s" -> ${r.isMismatch ? "MISMATCH" : "match len ${r.len}"} '
        'frontier=${frontier(r)} watermark=${p.reach} maxRead=${p.maxRead}');
  }
}
