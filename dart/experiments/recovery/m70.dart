// m70.dart -- I26: THE RECONSTRUCTION IS A PASS TOO.
//
// m69 with the last native recursion removed, and with it the last thing that
// separated the conformant engines from m62 on the depth ladders.
//
// The table said conformance costs two ladder rungs: m62 and m64 reach >=4096
// on both grammars, and every engine that answers the true PEG language --
// m66, m67, m68, m69, cgfr5 -- stops at 1024/2048. The natural reading is that
// the tape is heavy and the tape is the price. That reading is wrong, and the
// stack traces say so:
//
//   * the ladder grammars are lookahead-free, so by I24 the tape never runs
//     on them at all;
//   * the frozen parser alone survives len=4096 on the same input, so the
//     ceiling is not the oracle either;
//   * every overflow is in `_cleanRegret` called from `_build` -- the WITNESS
//     DESCENT.
//
// Instrumented, the descent is linear in the input: 522 frames at len=512,
// 1034 at len=1024, overflow at 1985 on the way to len=2048. It is deep for
// a reason that cannot be tuned away. Under I22 a verified witness IS the
// certificate, so a conformant engine must build and check the witness on the
// cost path; m62 escapes only because its `recoverCost` returns the number
// without ever reconstructing. The ladder gap was the certificate's shadow.
//
// I18 already answered this question once, for the search: the memo entry is
// the fact, the pass over it is a frame, and a frame belongs on a heap stack
// where its depth is bounded by memory rather than by the thread. The witness
// descent is the same shape one level out -- `_build`, `_child` and `_row` are
// three mutually recursive readers of the same fact table -- and it takes the
// same answer. One `_RFrame` carries the node, the seven arguments, and a
// resume point; `_reconstruct` is the driver; `null` on the return channel is
// failure, which is unambiguous because the empty child list is `const []`.
// `_cleanRegret`, `_collect` and `_emit` walk the built tree and go the same
// way, for the same reason.
//
// The result: LRmax goes from 1024 to >=4096 -- deterministic, 10/10 against
// m69's 0/10 -- and the witness is bit-identical to m69's on 471 inputs:
// costs, trees, spans and obligations alike. Nothing else changes; the
// certificate router, the relaxed fixpoint core, the I25 interval alphabet,
// the derived horizon and the (edits, regret) ranking are m69's, verbatim.
//
// WHAT THE RR COLUMN IS MEASURING, AND WHY IT IS NOT THIS ENGINE. The official
// row reads `RRmax 2048`, so the len=4096 rung failed, and the trace is always
// inside a parser and never inside the engine:
//
//   Ref.match <- Seq.match <- First.match <- MemoEntry.match <- Parser.match
//     <- Parser.matchRule <- Parser.parse <- _verify <- _relaxedRecover
//
// It is contingent on the harness. One process per condition:
//
//   the depth isolate alone                    LR >=4096   RR >=4096
//   parent buildSetup(), then depth            LR >=4096   RR >=4096
//   the `main` isolate, then depth             LR >=4096   RR   2048
//   the `lat` isolate, then depth              LR >=4096   RR   2048
//   buildSetup, main, lat, depth (the table)   LR >=4096   RR   2048
//
// and `_marginal.dart` takes the deciding rung 10/10 in fresh isolates. The
// rung flips on which isolates ran before it in the group, which is a fact
// about the measurement.
//
// The reason it is that fragile IS the engine's, and it is measured. Every
// engine here carries a copy of `lib/src/parser` so it is standalone, and
// `_twoparsers.dart` runs the library's parser and this carried copy side by
// side in one isolate on the same RR ladder:
//
//   library Parser (cold)  tops out at >=4096
//   carried Parser (cold)  tops out at >=4096
//   library Parser (warm)  tops out at >=8192
//   carried Parser (warm)  tops out at >=4096
//
// Byte-identical source (`_coregate` claim C), and only the library's copy
// gains the extra rung once its code is optimized. The engine's copy sits in a
// file whose `Clause` hierarchy has more subclasses -- `_Probe` and the relaxed
// clauses -- so its `match` call sites see more receiver types. So the len=4096
// RR rung sits EXACTLY at the carried parser's ceiling, with no margin: it is
// the last rung that parser can do at all, and whether a `_verify` a few frames
// down clears it is decided by a handful of frames.
//
// The tape route is a different story, and finding that out cost this header a
// wrong sentence first. Forcing every input to the tape with a lookahead, the
// tape ALSO overflowed at len=4096, which was written down as the same carried
// parser reached through classification. It was not: traced, the overflow was
// `_tremap <- _tapeRecover`, the tape's own remap of the witness through the
// alignment. That is a reconstruction, so I26 applies to it -- and it had been
// missed precisely because the ladder grammars are lookahead-free, so the tape
// never runs on them and no ladder column could see it. `_tremap` is now a
// post-order walk on an explicit stack like the rest, and the tape clears
// len=4096: ~7.0s there against ~1.8s at 2048, over two runs.
//
// m62 alone escapes, by never parsing anything but the original input -- which
// is exactly the property that leaves it at 3/5 on conformance. The engine
// that checks its answer must parse a second string; that is the cost of a
// certificate, and here it is charged by the oracle rather than by the search.
//
// Zero tuning parameters, as before.
import 'dart:math' as math;
import 'package:squirrel_parser/squirrel_parser.dart' as sp;
import 'package:squirrel_parser/src/recovery/skip_recovery.dart' as spr;

// ===========================================================================
// THE PARSER. A copy of `lib/src/parser`, carried here so this engine is
// standalone and free to modify it: `input` is mutable, `memoTable` is
// public, and every match records a READ EXTENT so a memo entry can be
// reused across an edit (sound exactly when `readEnd < editPos`).
// `_coregate.dart` checks this copy against the frozen library.
//
// NOT counted as this engine's size: it is identical in every engine, and
// the LOC metric reads only between the ERROR RECOVERY markers below.
// ===========================================================================
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

/// The MISMATCH singleton: sentinel len=-1 so even empty matches beat mismatches.
final mismatch = _Mismatch._();

/// Result of matching a clause at a position.
abstract class MatchResult {
  final Clause? clause;
  final int pos;
  final int len;
  const MatchResult(this.clause, this.pos, this.len);
  List<MatchResult> get subClauseMatches;
  bool get isMismatch => false;
}

/// A successful match. Terminals have no children, combinators have one or more.
class Match extends MatchResult {
  @override
  final List<MatchResult> subClauseMatches;

  Match(Clause? clause, int pos, int len, {this.subClauseMatches = const []})
      : super(clause, subClauseMatches.isEmpty ? pos : subClauseMatches.first.pos,
            subClauseMatches.isEmpty ? len : _totalLength(subClauseMatches));
}

class _Mismatch extends Match {
  _Mismatch._() : super(null, -1, -1);
  @override
  bool get isMismatch => true;
}

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
      if (result.isMismatch) return mismatch;
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
    for (int i = 0; i < subClauses.length; i++) {
      final result = subClauses[i].match(parser, pos);
      if (!result.isMismatch) return Match(this, 0, 0, subClauseMatches: [result]);
    }
    return mismatch;
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
    int curr = pos;
    while (curr <= parser.input.length) {
      final result = subClause.match(parser, curr);
      if (result.isMismatch) break;
      // Never consume more than one zero-length subclause match, to prevent an
      // infinite loop (e.g. for the pathological grammar "()*").
      if (result.len == 0) break;
      children.add(result);
      curr += result.len;
    }
    // The loop bound is a question about the input at `curr`, so record it.
    parser.read(curr);
    if (requireOne && children.isEmpty) return mismatch;
    if (children.isEmpty) return Match(this, pos, 0);
    return Match(this, 0, 0, subClauseMatches: children);
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
    if (result.isMismatch) return Match(this, pos, 0);
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
    if (result.isMismatch) return mismatch;
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
    return result.isMismatch ? Match(this, pos, 0) : mismatch;
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
    return result.isMismatch ? mismatch : Match(this, pos, 0);
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
      return mismatch;
    }
    for (int i = 0; i < text.length; i++) {
      if (parser.input.codeUnitAt(pos + i) != text.codeUnitAt(i)) {
        parser.read(pos + i);
        return mismatch;
      }
    }
    parser.read(pos + text.length - 1);
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
    if (pos >= parser.input.length) return mismatch;
    if (parser.input.codeUnitAt(pos) != char.codeUnitAt(0)) return mismatch;
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
    if (pos >= parser.input.length) return mismatch;
    final c = parser.input.codeUnitAt(pos);
    bool inSet = false;
    for (final (lo, hi) in ranges) {
      if (c >= lo && c <= hi) {
        inSet = true;
        break;
      }
    }
    if (inverted ? !inSet : inSet) return Match(this, pos, 1);
    return mismatch;
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
    if (pos >= parser.input.length) return mismatch;
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
      result = mismatch;
      return result!;
    }
    // Bracket this entry's own reads so `readEnd` is its own, not its parent's.
    final saved = parser.maxRead;
    parser.maxRead = -1;
    inRecPath = true;
    do {
      final newResult = clause.match(parser, pos);
      if (result != null && newResult.len <= result!.len) {
        // The match did not grow: fixed point reached. (A match is never
        // overwritten by a mismatch, since MISMATCH has sentinel len -1.)
        break;
      }
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
  }

  /// Match a rule's top clause at a position, using memoization.
  MatchResult match(Clause clause, int pos) {
    if (pos > input.length) return mismatch;
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

// ERROR RECOVERY START

/// log2 of the code-point alphabet, in millibits: what a FAB asserts.
const _widestClass = 20087;

int _width(Clause? clause) {
  if (clause is AnyChar) return _widestClass;
  if (clause is! CharSet) return 0;
  var size = 0;
  for (final (lo, hi) in clause.ranges) {
    size += hi - lo + 1;
  }
  size = clause.inverted ? 0x110000 - size : size;
  return size <= 1 ? 0 : (math.log(size) / math.ln2 * 1000).round();
}

// ---- the normal form: three node kinds, built once per grammar -------------

sealed class _Node {
  _Node(this.id, this.orig);
  final int id;
  final Clause orig;
}

class _Term extends _Node {
  _Term(super.id, super.orig, this.editable);
  final bool editable;
}

class _Cons extends _Node {
  _Cons(super.id, super.orig);
  late final _Node head;
  late _Node tail;
}

class _Alt extends _Node {
  _Alt(super.id, super.orig);
  late final List<_Node> alts;
}

/// A memo entry holds only durable knowledge: the value, the largest budget
/// it has been settled at, and the left-recursion staleness stamp. Membership
/// in the live chain is an index into the frame stack (-1 when parked out).
class _Entry {
  _Entry(this.node, this.pos, this.c);
  final _Node node;
  final int pos;
  final int c;

  /// I1/I9: flat triples `[key, cost, regret, ...]`, written in place for the
  /// entry's whole life. Null = never computed (the left-recursion seed).
  List<int>? value;

  /// A3: the largest budget this entry has been settled at. A bigger request
  /// recomputes (accumulating); a smaller one filters.
  int settledBudget = -1;

  /// `MemoEntry.memoVersion`: stale after a left-recursive widening at this
  /// position bumped the counter.
  int version = 0;

  /// The index of this entry's frame on the live stack, or -1: `inRecPath`
  /// and the parent pointer in one integer.
  int activeDepth = -1;
}

/// The transient half of m60's coroutine: everything about the pass in
/// flight, pooled by depth and reused.
class _Frame {
  late _Entry entry;
  int budget = -1;

  /// The program counter: which child request comes next. For an alternation,
  /// the branch index; for a sequence, 0 is the head and 1+i is the tail under
  /// the head's i-th answer; for a terminal and for the budget-zero walk, 0.
  int pc = 0;

  /// The resolved head entry of a cons, kept from pc 0 so tail requests read
  /// its answers without a lookup.
  _Entry? headEntry;

  /// `foundLeftRec`: a descendant re-entered this frame's entry, so the
  /// completed pass must widen until nothing improves.
  bool foundCycle = false;

  /// Did the current pass improve the value (I9's write-is-the-test)?
  bool improved = false;
}

/// I26: `_Frame` for the reconstruction. `_Frame` carries a pass of the search
/// over the fact table; this carries a pass of the witness descent over the
/// same table, and for the same reason -- its depth is the witness's depth,
/// which on any recursive grammar is the input's length.
///
/// `kind` picks which of the three mutually recursive readers this frame runs:
/// 0 `_build` (a node to one match), 1 `_child` (a node to the child list its
/// parent splices in), 2 `_row` (a `_Cons` spine to its flat child list). The
/// seven arguments they shared are fields; `pc` is where the frame resumes
/// when a frame it pushed returns; everything below `pc` is a local of the
/// recursive original that had to outlive a call.
class _RFrame {
  _RFrame(this.kind, this.node, this.pos, this.key, this.cost, this.reg,
      this.budget, this.c);
  /// Not final: where a reader ended in a TAIL call to another -- `_child` on
  /// a junk-headed spine, `_row` on a node that is not a spine -- the frame is
  /// re-labelled and reused rather than pushed, because a tail call adds no
  /// pending work and so deserves no frame of its own.
  int kind;
  final _Node node;
  final int pos, key, cost, reg, budget, c;
  int pc = 0;

  /// `_Alt`: which alternative is being tried, and the cycle-path token that
  /// must be retracted on the way out however the frame leaves.
  int ai = 0;
  (_Alt, int, int, int, int)? state;

  /// `_Cons`: the head answers, the order they are tried in, the cursor into
  /// that order, and whether the spine is its own tail.
  List<int>? heads;
  List<int>? order;
  int oi = 0;
  bool loops = false;

  /// The head candidate being extended, and the matches that came back for it.
  int headEnd = 0, headOwed = 0, restBudget = 0, restCost = 0, restReg = 0;
  List<MatchResult>? head;
}

class SuperDot3 {
  /// The grammar arrives in library clauses and is converted once into this
  /// file's own. `back` remembers the mapping, so a repaired tree can be handed
  /// out in library clauses and every existing harness keeps working.
  final Map<String, Clause> rules;
  final Map<Clause, sp.Clause> back = {};
  final String topRuleName;
  SuperDot3({required Map<String, sp.Clause> rules, required this.topRuleName})
      : rules = {} {
    this.rules.addAll(rulesToCore(rules, back));
  }

  late final Map<String, Clause> _rules = {
    for (final e in rules.entries)
      (e.key.startsWith('~') ? e.key.substring(1) : e.key): e.value,
  };

  // ---- building the normal form (m59's, verbatim) --------------------------

  final Map<Clause, _Node> _nodes = {};
  final List<Clause> _terminals = [];
  int _nodeCount = 0;

  _Node _term(Clause clause, bool editable) {
    if (editable) _terminals.add(clause);
    return _Term(_nodeCount++, clause, editable);
  }

  late final _Node _eps = _term(const Nothing(), false);

  _Cons _selfLoop(_Node head, Clause orig) {
    final loop = _Cons(_nodeCount++, orig)..head = head;
    return loop..tail = loop;
  }

  late final _Node _junk =
      _selfLoop(_term(const Nothing(), true), const Nothing());

  _Node _wrap(_Node reader, Clause orig) => _Cons(_nodeCount++, orig)
    ..head = _junk
    ..tail = reader;

  static const int _lastCodeUnit = 0xFFFF;

  List<(int, int)>? _oneCharClass(Clause clause,
          [Set<String> seen = const {}]) =>
      switch (clause) {
        AnyChar() => const [(0, _lastCodeUnit)],
        Char(:final char) => [(char.codeUnitAt(0), char.codeUnitAt(0))],
        Str(:final text) when text.length == 1 =>
          [(text.codeUnitAt(0), text.codeUnitAt(0))],
        CharSet(:final ranges, :final inverted) =>
          inverted ? _complement(ranges) : ranges,
        First(:final subClauses) => () {
            final out = <(int, int)>[];
            for (final part in subClauses) {
              final ranges = _oneCharClass(part, seen);
              if (ranges == null) return null;
              out.addAll(ranges);
            }
            return out;
          }(),
        Ref(:final ruleName) when !seen.contains(ruleName) =>
          _oneCharClass(_rules[ruleName]!, {...seen, ruleName}),
        _ => null,
      };

  static List<(int, int)> _complement(List<(int, int)> ranges) {
    final out = <(int, int)>[];
    var next = 0;
    for (final (lo, hi) in [...ranges]..sort((a, b) => a.$1 - b.$1)) {
      if (lo > next) out.add((next, lo - 1));
      next = math.max(next, hi + 1);
    }
    if (next <= _lastCodeUnit) out.add((next, _lastCodeUnit));
    return out;
  }



  // ---- I6/I7: the obligation lattice (m59's, verbatim) ---------------------

  static const int _free = -1;

  _Node _cons(List<Clause> parts, Clause orig) {
    var node = _eps;
    for (var i = parts.length - 1; i >= 0; i--) {
      node = _Cons(_nodeCount++, i == 0 ? orig : Seq(parts.sublist(i)))
        ..head = _node(parts[i])
        ..tail = node;
    }
    return node;
  }

  _Node _node(Clause clause) {
    final known = _nodes[clause];
    if (known != null) return known;
    if (clause is Ref) {
      final node = _Alt(_nodeCount++, clause);
      _nodes[clause] = node;
      node.alts = [_node(_rules[clause.ruleName]!)];
      return node;
    }
    late _Node node;
    if (clause is Seq) {
      node = _cons(clause.subClauses, clause);
    } else if (clause is Str && clause.text.length > 1) {
      node = _cons([for (final c in clause.text.split('')) Str(c)], clause);
    } else if (clause is First) {
      node = _Alt(_nodeCount++, clause)
        ..alts = [for (final s in clause.subClauses) _node(s)];
    } else if (clause is Optional) {
      node = _Alt(_nodeCount++, clause)..alts = [_node(clause.subClause), _eps];
    } else if (clause is Repetition) {
      final loop = _selfLoop(
          _node(clause.subClause),
          clause.requireOne
              ? Repetition(clause.subClause, requireOne: false)
              : clause);
      node = clause.requireOne
          ? (_Cons(_nodeCount++, clause)
            ..head = loop.head
            ..tail = loop)
          : loop;
    } else if (clause is Nothing) {
      node = _eps;
    } else {
      final accepts = _oneCharClass(clause);
      node = _wrap(_term(clause, accepts?.isNotEmpty ?? clause is Terminal),
          clause);
    }
    return _nodes[clause] = node;
  }

  late final _Node _goal =
      _Cons(_nodeCount++, Seq([_rules[topRuleName]!, const Nothing()]))
        ..head = _node(_rules[topRuleName]!)
        ..tail = _wrap(_eps, const Nothing());

  // ---- the derived ceiling (m53's `_goalFromNothing`, over 2-stride pairs) --
  //
  // A1's trivial repair always exists: discard the whole input, fabricate the
  // goal. Its fabrication count is a property of the grammar, priced per
  // obligation owed; a predicate is the one leaf that may not be counted
  // (tier 1), trusted only when every derivation needs one (tier 2), and if
  // even that fails the language is empty and the caller learns it with no
  // search (tier 3). See LESSONS 5n.

  static bool _kb2(List<int> out, int key, int v) {
    for (var i = 0; i < out.length; i += 2) {
      if (out[i] != key) continue;
      if (out[i + 1] <= v) return false;
      out[i + 1] = v;
      return true;
    }
    out
      ..add(key)
      ..add(v);
    return true;
  }

  late final int _goalFromNothing = () {
    final all = <_Node>{};
    void visit(_Node node) {
      if (!all.add(node)) return;
      if (node is _Cons) {
        visit(node.head);
        visit(node.tail);
      } else if (node is _Alt) {
        node.alts.forEach(visit);
      }
    }

    visit(_goal);
    int cheapest(bool trustPredicates) {
      final cost = <int, List<List<int>>>{};
      var improved = true;
      List<List<int>> row(int c) => cost.putIfAbsent(c, () {
            improved = true;
            return List.generate(_nodeCount, (_) => <int>[]);
          });
      List<int> chain(_Cons node, int c) {
        final out = <int>[];
        if (identical(node.tail, node)) _kb2(out, c, 0);
        final heads = row(c)[node.head.id];
        for (var i = 0; i < heads.length; i += 2) {
          final tails = row(heads[i])[node.tail.id];
          for (var j = 0; j < tails.length; j += 2) {
            _kb2(out, tails[j], heads[i + 1] + tails[j + 1]);
          }
        }
        return out;
      }

      List<int> leaf(_Term node, int c) {
        final emits = node.editable ? _oneCharClass(node.orig) : null;
        if (emits != null && emits.isNotEmpty) {
          return const [_free, 1];
        }
        return node.editable ||
                node.orig is Nothing ||
                (trustPredicates && node.orig is! Terminal)
            ? [c, 0]
            : const [];
      }

      row(_free);
      while (improved) {
        improved = false;
        for (final c in cost.keys.toList()) {
          for (final node in all) {
            final now = switch (node) {
              _Term() => leaf(node, c),
              _Cons() => chain(node, c),
              _Alt(:final alts) => () {
                  final out = <int>[];
                  for (final alt in alts) {
                    final from = row(c)[alt.id];
                    for (var i = 0; i < from.length; i += 2) {
                      _kb2(out, from[i], from[i + 1]);
                    }
                  }
                  return out;
                }(),
            };
            final known = row(c)[node.id];
            for (var i = 0; i < now.length; i += 2) {
              if (_kb2(known, now[i], now[i + 1])) improved = true;
            }
          }
        }
      }
      var best = _impossible;
      final top = row(_free)[_goal.id];
      for (var i = 0; i < top.length; i += 2) {
        if (top[i + 1] < best) best = top[i + 1];
      }
      return best;
    }

    final sure = cheapest(false);
    return sure < _impossible ? sure : cheapest(true);
  }();

  static const int _impossible = 1 << 30;

  // ---- per-input state -----------------------------------------------------

  late Parser _parser;
  late String _input;
  late int _inputLen;
  late List<int> _regretPrefix;
  late List<int> _versionAtPos;
  final Map<int, int> _charRegret = {};
  final Map<Clause, int> _widths = {};
  final Map<MatchResult, int> _cleanRegrets = {};
  MatchResult? _clean;
  int _steps = 0, _goalKey = -1, _goalCost = -1, _goalRegret = -1;
  int lastCost = -1, lastRegret = -1, lastSteps = -1;
  bool lastVerified = false;
  int get lastCells => _cells.length;
  double get lastPerCell => _cells.isEmpty ? 0 : _steps / _cells.length;

  int _skipRegret(int from, int to) => _regretPrefix[to] - _regretPrefix[from];
  int _widthOf(Clause clause) =>
      _widths.putIfAbsent(clause, () => _width(clause));

  int _h(int ch) => _charRegret.putIfAbsent(ch, () {
        final probe = Parser(
            rules: rules,
            topRuleName: topRuleName,
            input: String.fromCharCode(ch));
        var best = _widestClass;
        for (final terminal in _terminals) {
          if (terminal.match(probe, 0).len != 1) continue;
          best = math.min(best, _widthOf(terminal));
          if (best == 0) break;
        }
        return best;
      });

  void _buildRegretPrefix() {
    _regretPrefix = [0];
    for (var pos = 0; pos < _inputLen; pos++) {
      _regretPrefix.add(_regretPrefix.last + _h(_input.codeUnitAt(pos)));
    }
  }

  /// I26. A post-order sum over the match tree, on an explicit stack: the
  /// tree is as deep as the input, and this is called from inside the witness
  /// descent, so a native post-order here costs two depths at once.
  int _cleanRegret(MatchResult root) {
    final hit = _cleanRegrets[root];
    if (hit != null) return hit;
    // Pre-order into a list, then fold it backwards. A parent precedes its
    // children in pre-order, so the reverse reaches every child before its
    // parent -- which is all a post-order sum needs, and it costs one list
    // rather than an open/closed flag per node.
    final order = <MatchResult>[];
    final stack = <MatchResult>[root];
    while (stack.isNotEmpty) {
      final m = stack.removeLast();
      if (_cleanRegrets.containsKey(m)) continue;
      order.add(m);
      stack.addAll(m.subClauseMatches);
    }
    for (var i = order.length - 1; i >= 0; i--) {
      final m = order[i];
      final subs = m.subClauseMatches;
      var sum = 0;
      if (subs.isEmpty) {
        sum = _widthOf(m.clause!) * m.len;
      } else {
        for (final sub in subs) {
          sum += _cleanRegrets[sub]!;
        }
      }
      _cleanRegrets[m] = sum;
    }
    return _cleanRegrets[root]!;
  }

  // ---- the value: triples, written in place (m59's, verbatim) --------------

  static bool _keepBest(List<int> out, int key, int cost, int reg) {
    for (var i = 0; i < out.length; i += 3) {
      if (out[i] != key) continue;
      if (out[i + 1] < cost || (out[i + 1] == cost && out[i + 2] <= reg)) {
        return false;
      }
      out[i + 1] = cost;
      out[i + 2] = reg;
      return true;
    }
    out
      ..add(key)
      ..add(cost)
      ..add(reg);
    return true;
  }

  int _key(int end, int owed) => ((owed + 1) << _posShift) | end;
  int _endOf(int key) => key & (_span - 1);
  int _oweOf(int key) => (key >> _posShift) - 1;

  final Map<int, _Entry> _cells = {};
  int _posShift = 0, _span = 0;

  _Entry _entryAt(_Node node, int pos, int c) => _cells.putIfAbsent(
      (((c + 1) * (_nodeCount + 1) + node.id) << _posShift) | pos,
      () => _Entry(node, pos, c));

  // ---- I18: the driver -----------------------------------------------------

  /// Is `e` usable at `budget` as it stands? (A3's filter direction, plus the
  /// left-recursion staleness rule, `MemoEntry` verbatim.)
  bool _settled(_Entry e, int budget) =>
      e.activeDepth < 0 &&
      e.value != null &&
      e.settledBudget >= budget &&
      e.version == _versionAtPos[e.pos];

  final List<_Frame> _stack = [];
  int _depth = -1;

  _Frame _push(_Entry e, int budget) {
    final d = ++_depth;
    if (_stack.length <= d) _stack.add(_Frame());
    e.activeDepth = d;
    e.value ??= <int>[];
    return _stack[d]
      ..entry = e
      ..budget = budget
      ..pc = 0
      ..headEntry = null
      ..foundCycle = false
      ..improved = false;
  }

  /// Run `e` to settlement at `budget`: one explicit DFS. The chain of parked
  /// parents IS the stack below the top, and the native stack never deepens.
  void _run(_Entry e, int budget) {
    if (budget < 0 || _settled(e, budget)) return;
    _push(e, budget);
    while (_depth >= 0) {
      _step(_stack[_depth]);
    }
  }

  /// Advance the top frame until it parks on a child (pushed; the loop steps
  /// it next) or settles (popped; the parent below is the new top, and its
  /// next step re-derives the awaited child from `pc`, finds it settled,
  /// consumes it, and moves on).
  void _step(_Frame f) {
    _steps++;
    final entry = f.entry;
    final node = entry.node;
    final pos = entry.pos;
    final budget = f.budget;
    final c = entry.c;
    // The budget-zero walk: the repaired string IS the input here and
    // everything after this entry is edit-free, so the oracle's one memoized
    // answer settles the whole subtree (LESSONS 5i/5m). No children.
    if (budget == 0) {
      if (f.pc == 0) {
        f.pc = 1;
        final m = node.orig.match(_parser, pos);
        if (!m.isMismatch) {
          _put(f, _key(pos + m.len, _free), 0, _cleanRegret(m));
        }
      }
      return _finish(f);
    }
    switch (node) {
      case _Term(:final editable):
        final m = node.orig.match(_parser, pos);
        if (!m.isMismatch) {
          _put(f, _key(pos + m.len, _free), 0, _cleanRegret(m));
        }
        if (editable) {
          if (pos < _inputLen) {
            _put(f, _key(pos + 1, _free), 1,
                2 * _skipRegret(pos, pos + 1)); // SUB
          }
          _put(f, _key(pos, _free), 1, _widestClass); // FAB
        }
        return _finish(f);
      case _Alt(:final alts):
        while (f.pc < alts.length) {
          final child = _entryAt(alts[f.pc], pos, c);
          if (child.activeDepth >= 0) {
            _stack[child.activeDepth].foundCycle = true; // the LR seed
          } else if (!_settled(child, budget)) {
            _push(child, budget);
            return; // park: the loop steps the new top next
          }
          _mergeAlt(f, alts.length, child);
          f.pc++;
        }
        return _finish(f);
      case _Cons():
        final loops = identical(node.tail, node);
        if (f.pc == 0) {
          if (loops) _put(f, _key(pos, c), 0, 0);
          final head = _entryAt(node.head, pos, c);
          if (head.activeDepth >= 0) {
            _stack[head.activeDepth].foundCycle = true;
          } else if (!_settled(head, budget)) {
            _push(head, budget);
            return; // park
          }
          f.headEntry = head;
          f.pc = 1;
        }
        final heads = f.headEntry!.value ?? const <int>[];
        while ((f.pc - 1) * 3 < heads.length) {
          final i = (f.pc - 1) * 3;
          final headKey = heads[i], hCost = heads[i + 1], hReg = heads[i + 2];
          final headEnd = _endOf(headKey);
          final rest = budget - hCost;
          // The zero-width cut (speed only) and the budget's descent bound.
          if ((loops && headEnd == pos) || rest < 0 || headEnd > _inputLen) {
            f.pc++;
            continue;
          }
          final tail = _entryAt(node.tail, headEnd, _oweOf(headKey));
          if (tail.activeDepth >= 0) {
            _stack[tail.activeDepth].foundCycle = true;
          } else if (!_settled(tail, rest)) {
            _push(tail, rest);
            return; // park
          }
          final rv = tail.value;
          if (rv != null) {
            for (var j = 0; j < rv.length; j += 3) {
              final total = hCost + rv[j + 1];
              if (total <= budget) {
                _put(f, rv[j], total, hReg + rv[j + 2]);
              }
            }
          }
          f.pc++;
        }
        return _finish(f);
    }
  }

  void _put(_Frame f, int key, int cost, int reg) {
    if (_keepBest(f.entry.value!, key, cost, reg)) f.improved = true;
  }

  /// Ordered choice: I3's veto, then the merge. The veto asks the memoized
  /// parser (never the raw combinator -- LESSONS 5m) where PEG itself commits.
  void _mergeAlt(_Frame f, int altCount, _Entry branch) {
    final v = branch.value;
    if (v == null) return;
    final budget = f.budget;
    var committed = -2;
    for (var i = 0; i < v.length; i += 3) {
      final key = v[i], cost = v[i + 1];
      if (cost > budget) continue;
      if (cost == 0 && altCount > 1) {
        if (committed == -2) {
          final oracle = _parser.match(f.entry.node.orig, f.entry.pos);
          committed = oracle.isMismatch ? -1 : f.entry.pos + oracle.len;
        }
        if (_endOf(key) > committed) {
          continue;
        }
      }
      _put(f, key, cost, v[i + 2]);
    }
  }

  /// A pass ended. `MemoEntry.match`'s widening loop: if a descendant closed a
  /// cycle here and the pass improved the value, invalidate this position's
  /// memos and run another pass; otherwise settle and pop -- the parent below
  /// is the new top.
  void _finish(_Frame f) {
    final entry = f.entry;
    if (f.foundCycle && f.improved && f.budget > 0) {
      _versionAtPos[entry.pos]++;
      f.pc = 0;
      f.headEntry = null;
      f.improved = false;
      return; // another widening pass of the same frame
    }
    entry.settledBudget = f.budget;
    entry.version = _versionAtPos[entry.pos];
    entry.activeDepth = -1;
    f.headEntry = null;
    _depth--;
  }

  // ---- reconstruction and verification (I26: a pass, not a recursion) -----

  final List<SyntaxError> _spans = [];
  final List<MissingObligation> _missing = [];
  final Set<(_Alt, int, int, int, int)> _path = {};

  List<int> _ends(_Node node, int pos, int budget, int c) {
    if (pos > _inputLen || budget < 0) return const [];
    final e = _entryAt(node, pos, c);
    _run(e, budget);
    return e.value ?? const [];
  }

  (int, int)? _deltaOf(List<int> v, int key) {
    for (var i = 0; i < v.length; i += 3) {
      if (v[i] == key) return (v[i + 1], v[i + 2]);
    }
    return null;
  }

  /// I26: one pass of the witness descent, off the native stack.
  ///
  /// The mirror of `_Frame`. That one carries a pass of the SEARCH over the
  /// fact table; this one carries a pass of the RECONSTRUCTION over the same
  /// table. `kind` picks which of the three mutually recursive readers the
  /// frame is running -- 0 a node to one match (`_build`), 1 a node to the
  /// child list its parent splices in (`_child`), 2 a `_Cons` spine to its
  /// children (`_row`) -- and `pc` is where it resumes when a frame it pushed
  /// returns. Every field below is a local of the recursive original that had
  /// to outlive a call.
  MatchResult? _build(
      _Node node, int pos, int key, int cost, int reg, int budget, int c) =>
      _reconstruct(0, node, pos, key, cost, reg, budget, c) as MatchResult?;

  Object? _reconstruct(int kind, _Node node0, int pos0, int key0, int cost0,
      int reg0, int budget0, int c0) {
    final st = <_RFrame>[
      _RFrame(kind, node0, pos0, key0, cost0, reg0, budget0, c0)
    ];
    // What the frame that just popped returned. `null` is failure, which is
    // unambiguous: an empty child list is `const []`, and `_build` never
    // answers with a list at all.
    Object? ret;
    while (st.isNotEmpty) {
      final f = st.last;
      final node = f.node;
      if (f.kind == 0) {
        // ---- `_build`: this node, at this key, as one match ---------------
        if (f.pc == 0) {
          final end = _endOf(f.key);
          final orig = node.orig;
          final pure = f.pos > _inputLen ? mismatch : orig.match(_parser, f.pos);
          if (!pure.isMismatch &&
              f.pos + pure.len == end &&
              f.cost == 0 &&
              _cleanRegret(pure) == f.reg &&
              f.key == _key(end, _free)) {
            ret = pure;
            st.removeLast();
            continue;
          }
          switch (node) {
            case _Term():
              ret = Match(orig, f.pos, end - f.pos);
              st.removeLast();
            case _Alt():
              final state = (node, f.pos, f.key, f.cost, f.c);
              if (!_path.add(state)) {
                ret = null;
                st.removeLast();
              } else {
                f.state = state;
                f.pc = 1;
              }
            case _Cons():
              f.pc = 3;
              st.add(_RFrame(
                  2, node, f.pos, f.key, f.cost, f.reg, f.budget, f.c));
          }
          continue;
        }
        if (f.pc == 1) {
          // Alternative `f.ai`, one per visit.
          final alts = (node as _Alt).alts;
          if (f.ai >= alts.length) {
            _path.remove(f.state);
            ret = null;
            st.removeLast();
            continue;
          }
          final alt = alts[f.ai];
          if (_deltaOf(_ends(alt, f.pos, f.budget, f.c), f.key) !=
              (f.cost, f.reg)) {
            f.ai++;
            continue;
          }
          f.pc = 2;
          st.add(
              _RFrame(1, alt, f.pos, f.key, f.cost, f.reg, f.budget, f.c));
          continue;
        }
        // pc 2 (an alternative answered) and pc 3 (the spine answered) share
        // the wrap. Only an alternation has a cycle token to retract, and
        // `f.state` is null when there is none, so the retraction is common
        // code too.
        if (f.pc == 2 && ret == null) {
          f.ai++;
          f.pc = 1;
          continue;
        }
        _path.remove(f.state);
        ret = ret == null
            ? null
            : Match(node.orig, f.pos, _endOf(f.key) - f.pos,
                subClauseMatches: ret as List<MatchResult>);
        st.removeLast();
        continue;
      }
      if (f.kind == 1) {
        // ---- `_child`: this node as the list its parent splices in --------
        if (f.pc == 0) {
          if (identical(node, _junk)) {
            final end = _endOf(f.key);
            ret = end == f.pos
                ? const <MatchResult>[]
                : <MatchResult>[SyntaxError(pos: f.pos, len: end - f.pos)];
            st.removeLast();
            continue;
          }
          if (node is _Cons && identical(node.head, _junk)) {
            f.kind = 2; // tail call: the spine's answer IS this frame's
            continue;
          }
          f.pc = 2;
          st.add(_RFrame(0, node, f.pos, f.key, f.cost, f.reg, f.budget, f.c));
          continue;
        }
        ret = ret == null ? null : <MatchResult>[ret as MatchResult];
        st.removeLast();
        continue;
      }
      // ---- `_row`: a `_Cons` spine, as the flat child list ----------------
      if (f.pc == 0) {
        if (node is! _Cons) {
          if (identical(node, _eps)) {
            ret = f.key == _key(f.pos, f.c) && f.cost == 0 && f.reg == 0
                ? const <MatchResult>[]
                : null;
            st.removeLast();
            continue;
          }
          f.kind = 1; // tail call: not a spine, so it is one child
          continue;
        }
        f.loops = identical(node.tail, node);
        final heads = List<int>.of(_ends(node.head, f.pos, f.budget, f.c));
        f.heads = heads;
        f.order = [for (var i = 0; i < heads.length; i += 3) i]
          ..sort((a, b) {
            final byEnd = _endOf(heads[a]) - _endOf(heads[b]);
            return byEnd != 0 ? byEnd : heads[a] - heads[b];
          });
        f.pc = 2;
        continue;
      }
      if (f.pc == 2) {
        // Head candidate `f.oi`, one per visit.
        final cons = node as _Cons;
        final heads = f.heads!, order = f.order!;
        if (f.oi >= order.length) {
          ret = f.loops && f.key == _key(f.pos, f.c) && f.cost == 0 &&
                  f.reg == 0
              ? const <MatchResult>[]
              : null;
          st.removeLast();
          continue;
        }
        final i = order[f.oi];
        final headKey = heads[i];
        final headEnd = _endOf(headKey);
        final hCost = heads[i + 1], hReg = heads[i + 2];
        if ((f.loops && headEnd == f.pos) ||
            hCost > f.cost ||
            (hCost == f.cost && hReg > f.reg)) {
          f.oi++;
          continue;
        }
        final headOwed = _oweOf(headKey);
        final restBudget = f.budget - hCost;
        final rest =
            _deltaOf(_ends(cons.tail, headEnd, restBudget, headOwed), f.key);
        if (rest == null ||
            rest.$1 != f.cost - hCost ||
            rest.$2 != f.reg - hReg) {
          f.oi++;
          continue;
        }
        f.headEnd = headEnd;
        f.headOwed = headOwed;
        f.restBudget = restBudget;
        f.restCost = rest.$1;
        f.restReg = rest.$2;
        f.pc = 3;
        st.add(_RFrame(
            1, cons.head, f.pos, headKey, hCost, hReg, f.budget, f.c));
        continue;
      }
      if (f.pc == 3) {
        if (ret == null) {
          f.oi++;
          f.pc = 2;
          continue;
        }
        f.head = ret as List<MatchResult>;
        f.pc = 4;
        st.add(_RFrame(2, (node as _Cons).tail, f.headEnd, f.key, f.restCost,
            f.restReg, f.restBudget, f.headOwed));
        continue;
      }
      // pc 4: the tail answered.
      if (ret == null) {
        f.oi++;
        f.pc = 2;
        continue;
      }
      ret = <MatchResult>[...f.head!, ...(ret as List<MatchResult>)];
      st.removeLast();
    }
    return ret;
  }

  /// I26. Pre-order, left to right, on an explicit stack: `_missing` is
  /// consumed in order, so children are pushed in reverse.
  void _collect(MatchResult root) {
    final stack = <MatchResult>[root];
    while (stack.isNotEmpty) {
      final m = stack.removeLast();
      final clause = m.clause;
      if (m is SyntaxError) {
        _spans.add(m);
      } else if (m.subClauseMatches.isEmpty &&
          clause is Terminal &&
          clause is! Nothing) {
        if (m.len == 0) {
          _missing.add(MissingObligation(clause, m.pos));
        } else if (clause.match(_parser, m.pos).isMismatch) {
          _spans.add(SyntaxError(pos: m.pos, len: m.len));
        }
      } else {
        final subs = m.subClauseMatches;
        for (var i = subs.length - 1; i >= 0; i--) {
          stack.add(subs[i]);
        }
      }
    }
  }

  /// I26. Source order, on an explicit stack. The work items are a match to
  /// emit or a `(from, to)` slice of the input to copy verbatim -- the gaps a
  /// recursive `_emit` wrote between its children -- pushed in reverse so they
  /// come off in source order.
  void _emit(MatchResult root, StringBuffer out) {
    final work = <Object>[root];
    while (work.isNotEmpty) {
      final item = work.removeLast();
      if (item is (int, int)) {
        out.write(_input.substring(item.$1, item.$2));
        continue;
      }
      final m = item as MatchResult;
      if (m is SyntaxError) continue;
      final clause = m.clause;
      if (m.subClauseMatches.isEmpty) {
        out.write(clause is Terminal &&
                clause is! Nothing &&
                (m.len == 0 || clause.match(_parser, m.pos).isMismatch)
            ? _spelling(clause)
            : _input.substring(m.pos, m.pos + m.len));
        continue;
      }
      final items = <Object>[];
      var cursor = m.pos;
      for (final child in m.subClauseMatches) {
        if (child.pos > cursor) items.add((cursor, child.pos));
        items.add(child);
        cursor = child.pos + child.len;
      }
      if (cursor < m.pos + m.len) items.add((cursor, m.pos + m.len));
      for (var i = items.length - 1; i >= 0; i--) {
        work.add(items[i]);
      }
    }
  }

  String _spelling(Clause clause) {
    final accepts = _oneCharClass(clause);
    if (accepts != null && accepts.isNotEmpty) {
      return String.fromCharCode(accepts.first.$1);
    }
    return clause is Str ? clause.text : '';
  }

  bool _verify(MatchResult root) {
    final out = StringBuffer();
    _emit(root, out);
    final s = out.toString();
    final check =
        Parser(rules: rules, topRuleName: topRuleName, input: s).parse();
    return !check.hasSyntaxErrors && check.root.len == s.length;
  }

  // ---- entry points --------------------------------------------------------

  SkipResult _relaxedRecover(String input) {
    final cost = _relaxedCost(input);
    _spans.clear();
    _missing.clear();
    _path.clear();
    lastVerified = false;
    if (cost == 0) {
      // A relaxed 0 on an input the pure parse rejects (the conformance
      // cases) has no clean tree to return; report it unverified instead of
      // dereferencing the absent parse.
      if (_clean == null) {
        final error = SyntaxError(pos: 0, len: _inputLen);
        return SkipResult(error, [error], const [], 1, true);
      }
      lastVerified = true;
      return SkipResult(_clean!, const [], const [], 0, false);
    }
    final root = cost < 0
        ? null
        : _build(_goal, 0, _goalKey, _goalCost, _goalRegret, cost, _free);
    if (root == null) {
      final error = SyntaxError(pos: 0, len: _inputLen);
      return SkipResult(error, [error], const [], 1, true);
    }
    _collect(root);
    lastVerified = _verify(root);
    _spans.sort((a, b) => a.pos - b.pos);
    return SkipResult(root, List.of(_spans), List.of(_missing),
        _spans.length + _missing.length, false);
  }

  int _relaxedCost(String input) {
    _input = input;
    _inputLen = input.length;
    _clean = null;
    final goal = _goal;
    final maxCost =
        _goalFromNothing < _impossible ? _inputLen + _goalFromNothing : -1;
    _posShift = (_inputLen + 2).bitLength;
    _span = 1 << _posShift;
    _parser = Parser(rules: rules, topRuleName: topRuleName, input: input);
    final result = _parser.parse();
    if (!result.hasSyntaxErrors) {
      _clean = result.root;
      lastCost = lastRegret = lastSteps = 0;
      return 0;
    }
    _buildRegretPrefix();
    _versionAtPos = List.filled(_inputLen + 2, 0);
    _cells.clear();
    _stack.clear();
    _depth = -1;
    _cleanRegrets.clear();
    _steps = 0;
    // The ladder, with A3's filter: one memo serves every round.
    for (var k = 0; k <= maxCost; k++) {
      final goalEntry = _entryAt(goal, 0, _free);
      _run(goalEntry, k);
      final v = goalEntry.value;
      if (v == null) continue;
      var bestC = _impossible, bestR = _impossible;
      for (var i = 0; i < v.length; i += 3) {
        if (_endOf(v[i]) != _inputLen) continue;
        if (v[i + 1] < bestC || (v[i + 1] == bestC && v[i + 2] < bestR)) {
          bestC = v[i + 1];
          bestR = v[i + 2];
          _goalKey = v[i];
        }
      }
      if (bestC < _impossible) {
        _goalCost = bestC;
        _goalRegret = bestR;
        lastCost = bestC;
        lastRegret = bestR - _skipRegret(0, _inputLen);
        lastSteps = _steps;
        return bestC;
      }
    }
    lastCost = -1;
    lastSteps = _steps;
    return -1;
  }

  // ==== the tape (m65's I20/I21, on the shared substrate) ====================

  /// A wide lookahead is a clause `_looks` cannot read -- the same test as
  /// I4's fusion, reused as the envelope boundary.
  /// I24: any lookahead at all routes to the tape; the lattice-free core is
  /// a floor only on lookahead-free grammars. The walk is also the
  /// closed-world check (twenty-eighth occasion): both halves reason about
  /// the STOCK clause algebra, and an unknown Clause subclass silently
  /// voids every soundness argument -- an opaque wrapper can hide a wide
  /// lookahead from this very test -- so unknown types are rejected loudly.
  late final bool _wideG = () {
    var found = false;
    final seen = <Clause>{};
    void walkC(Clause c) {
      if (!seen.add(c)) return;
      if (c is FollowedBy || c is NotFollowedBy) {
        found = true;
        walkC((c as HasOneSubClause).subClause);
      } else if (c is HasMultipleSubClauses) {
        c.subClauses.forEach(walkC);
      } else if (c is HasOneSubClause) {
        walkC(c.subClause);
      } else if (c is Ref) {
        final t = _rules[c.ruleName];
        if (t != null) walkC(t);
      } else if (c is! Str && c is! Char && c is! CharSet && c is! AnyChar && c is! Nothing) {
        throw ArgumentError(
            'unsupported clause type ${c.runtimeType}: repair soundness is '
            'proved over the stock clause algebra only');
      }
    }

    _rules.values.forEach(walkC);
    return found;
  }();

  /// The grammar's fabrication mass over the lowered terminal list: the
  /// derived widening of the horizon that covers forced-duplication gaps.
  /// The INLINED fabrication mass of the top rule: reference occurrences
  /// count every time (a doubling chain of Refs doubles the mass), because
  /// the forced-duplication gap between the relaxed and true fabrication
  /// floors multiplies with reference duplication -- the definition-level
  /// sum was refuted by exactly that construction (twenty-eighth occasion).
  /// Cycles contribute zero: with undecidable emptiness, -1 remains "no
  /// repair within lastHorizon", never an unconditional answer.
  late final int _massG = () {
    int mass(Clause c, Set<String> path) => switch (c) {
          Str(:final text) => text.length,
          Nothing() => 0,
          Char() || CharSet() || AnyChar() => 1,
          Seq(:final subClauses) =>
            subClauses.fold(0, (a, x) => a + mass(x, path)),
          First(:final subClauses) =>
            subClauses.fold(0, (a, x) => math.max(a, mass(x, path))),
          Repetition(:final subClause) ||
          Optional(:final subClause) ||
          FollowedBy(:final subClause) ||
          NotFollowedBy(:final subClause) =>
            mass(subClause, path),
          Ref(:final ruleName) => path.contains(ruleName)
              ? 0
              : mass(_rules[ruleName]!, {...path, ruleName}),
          _ => 1,
        };
    return mass(_rules[topRuleName.startsWith('~')
            ? topRuleName.substring(1)
            : topRuleName]!,
        {});
  }();

  late final Map<String, Clause> _probed = {
    for (final e in rules.entries) e.key: _px(e.value),
  };

  Clause _px(Clause c) {
    if (c is Seq) return Seq([for (final x in c.subClauses) _px(x)]);
    if (c is First) return First([for (final x in c.subClauses) _px(x)]);
    if (c is OneOrMore) return OneOrMore(_px(c.subClause));
    if (c is ZeroOrMore) return ZeroOrMore(_px(c.subClause));
    if (c is Optional) return Optional(_px(c.subClause));
    if (c is FollowedBy) return FollowedBy(_px(c.subClause));
    if (c is NotFollowedBy) return NotFollowedBy(_px(c.subClause));
    if (c is Repetition) {
      return Repetition(_px(c.subClause), requireOne: c.requireOne);
    }
    if (c is Ref) return c;
    return _Probe(this, c as Terminal);
  }

  bool _touched = false;
  Set<int> _atomSet = {};
  final Map<String, _Cls> _clsMemo = {};
  int _classifies = 0;

  /// I25: the Boolean interval partition of the code-unit line. Every stock
  /// terminal's answer is constant inside one interval, so a single
  /// representative stands in for the whole interval; and unlike a
  /// per-terminal representative the set is closed under intersection.
  late final List<int> _reps = () {
    final cuts = <int>{0};
    final seen = <Clause>{};
    void cut(Clause c) {
      if (!seen.add(c)) return;
      if (c is Char) {
        final u = c.char.codeUnitAt(0);
        cuts..add(u)..add(u + 1);
      } else if (c is Str) {
        for (var i = 0; i < c.text.length; i++) {
          final u = c.text.codeUnitAt(i);
          cuts..add(u)..add(u + 1);
        }
      } else if (c is CharSet) {
        for (final (lo, hi) in c.ranges) {
          cuts..add(lo)..add(hi + 1);
        }
      } else if (c is HasMultipleSubClauses) {
        c.subClauses.forEach(cut);
      } else if (c is HasOneSubClause) {
        cut(c.subClause);
      } else if (c is Ref) {
        final t = _rules[c.ruleName];
        if (t != null) cut(t);
      }
    }

    _rules.values.forEach(cut);
    return cuts.where((u) => u <= _lastCodeUnit).toList()..sort();
  }();

  final Map<Clause, List<int>> _repsOfTerm = {};

  /// Every representative this terminal accepts. Asked of each terminal a
  /// parse touched at the open end, the union of the answers contains a
  /// representative of their intersection whenever one exists.
  List<int> _repsOf(Terminal t) => _repsOfTerm.putIfAbsent(t, () {
        final out = <int>[];
        for (final u in _reps) {
          final probe = Parser(
              rules: rules,
              topRuleName: topRuleName,
              input: String.fromCharCode(u));
          if (t.match(probe, 0).len == 1) out.add(u);
        }
        return out;
      });

  void _noteAtoms(_Probe p, String y, int pos) {
    final inner = p.inner;
    if (inner is Str && inner.text.length > 1) {
      // A multi-character literal names its next character exactly, and that
      // character is a cut point, so the exact answer is already the
      // interval-complete one.
      final off = y.length - pos;
      for (var i = 0; i < off; i++) {
        if (y.codeUnitAt(pos + i) != inner.text.codeUnitAt(i)) return;
      }
      _atomSet.add(inner.text.codeUnitAt(off));
    } else {
      _atomSet.addAll(_repsOf(inner));
    }
  }

  _Cls _classify(String y) => _clsMemo[y] ??= () {
        _classifies++;
        _touched = false;
        _atomSet = <int>{};
        final r =
            Parser(rules: _probed, topRuleName: topRuleName, input: y).parse();
        return _Cls(!r.hasSyntaxErrors, _touched, _atomSet.toList()..sort());
      }();

  late int _n;
  int lastHorizon = -1;
  bool lastFellBack = false;

  final Map<String, int> _tids = {};
  final List<int> _tsi = [], _tsg = [], _tsp = [], _tsop = [], _tsch = [];
  final List<String> _tsy = [];
  final List<int> _theapK = [], _theapV = [];

  static const int _opStart = 0, _opMatch = 1, _opSub = 2, _opFab = 3,
      _opSkip = 4;

  void _thpush(int key, int id) {
    _theapK.add(key);
    _theapV.add(id);
    var i = _theapK.length - 1;
    while (i > 0) {
      final p = (i - 1) >> 1;
      if (_theapK[p] <= _theapK[i]) break;
      final tk = _theapK[p], tv = _theapV[p];
      _theapK[p] = _theapK[i];
      _theapV[p] = _theapV[i];
      _theapK[i] = tk;
      _theapV[i] = tv;
      i = p;
    }
  }

  (int, int) _thpop() {
    final top = (_theapK.first, _theapV.first);
    final lk = _theapK.removeLast(), lv = _theapV.removeLast();
    if (_theapK.isNotEmpty) {
      _theapK[0] = lk;
      _theapV[0] = lv;
      var i = 0;
      while (true) {
        final l = 2 * i + 1, r = l + 1;
        var m = i;
        if (l < _theapK.length && _theapK[l] < _theapK[m]) m = l;
        if (r < _theapK.length && _theapK[r] < _theapK[m]) m = r;
        if (m == i) break;
        final tk = _theapK[m], tv = _theapV[m];
        _theapK[m] = _theapK[i];
        _theapV[m] = _theapV[i];
        _theapK[i] = tk;
        _theapV[i] = tv;
        i = m;
      }
    }
    return top;
  }

  void _tpush(int i, String y, int g, int parent, int op, int ch) {
    final key = '$i|$y';
    final pri = g * (1 << 32) + (_n - i);
    final known = _tids[key];
    if (known != null) {
      if (_tsg[known] <= g) return;
      _tsg[known] = g;
      _tsp[known] = parent;
      _tsop[known] = op;
      _tsch[known] = ch;
      _thpush(pri, known);
      return;
    }
    final id = _tsi.length;
    _tids[key] = id;
    _tsi.add(i);
    _tsy.add(y);
    _tsg.add(g);
    _tsp.add(parent);
    _tsop.add(op);
    _tsch.add(ch);
    _thpush(pri, id);
  }

  int _accepted = -1;

  int _tapeCost(String input) {
    _input = input;
    _n = input.length;
    lastVerified = false;
    _accepted = -1;
    // The horizon (twenty-fifth occasion): inside the envelope the relaxed
    // empty-input answer is a lower fabrication floor; the mass term covers
    // forced-duplication gaps; -1 means "no repair within lastHorizon".
    var fab = 0;
    if (!_wideG) {
      final f = _relaxedCost('');
      if (f > 0) fab = f;
      _input = input;
      _n = input.length;
    }
    lastHorizon = _n + fab + _massG;
    return lastCost = _tapeSearch(lastHorizon);
  }

  int _tapeSearch(int cap) {
    _tids.clear();
    _tsi.clear();
    _tsy.clear();
    _tsg.clear();
    _tsp.clear();
    _tsop.clear();
    _tsch.clear();
    _theapK.clear();
    _theapV.clear();
    _clsMemo.clear();
    _classifies = 0;
    final settled = <int>{};
    final accepts = <int>[];
    var acceptCost = -1;
    _tpush(0, '', 0, -1, _opStart, -1);
    while (_theapK.isNotEmpty) {
      final (pri, id) = _thpop();
      final g = pri >> 32;
      if (g != _tsg[id]) continue; // stale
      if (acceptCost >= 0 && g > acceptCost) break; // the layer is drained
      if (g > cap) break;
      if (!settled.add(id)) continue;
      final i = _tsi[id];
      final layerDone = acceptCost >= 0;
      if (layerDone && i < _n && (_tsop[id] == _opMatch || _tsop[id] == _opStart)) {
        continue;
      }
      final y = _tsy[id];
      final cls = _classify(y);
      if (!cls.member && !cls.open) continue; // dead
      if (cls.member && i == _n) {
        acceptCost = g;
        accepts.add(id);
        continue;
      }
      final expandable = !cls.member || cls.open;
      if (i < _n &&
          expandable &&
          (_tsop[id] == _opSub ||
              _tsop[id] == _opFab ||
              _tsop[id] == _opSkip)) {
        _tpush(_n, y + _input.substring(i), g, id, _opStart, -1);
      }
      if (layerDone) continue;
      if (i < _n) {
        final cu = _input.codeUnitAt(i);
        if (expandable) {
          _tpush(i + 1, y + _input[i], g, id, _opMatch, cu);
        }
        _tpush(i + 1, y, g + 1, id, _opSkip, cu);
        if (expandable) {
          for (final a in cls.atoms) {
            if (a != cu) {
              _tpush(i + 1, y + String.fromCharCode(a), g + 1, id, _opSub, a);
            }
          }
        }
      }
      if (expandable) {
        for (final a in cls.atoms) {
          _tpush(i, y + String.fromCharCode(a), g + 1, id, _opFab, a);
        }
      }
    }
    lastSteps = _classifies;
    if (accepts.isEmpty) {
      return -1; // no repair within the derived horizon
    }
    var bestRank = 1 << 60;
    for (final id in accepts) {
      final (packed, _) = _talign(_tsy[id]);
      final rank = packed % _alignBig +
          _cleanRegret(
              Parser(rules: rules, topRuleName: topRuleName, input: _tsy[id])
                  .parse()
                  .root);
      if (rank < bestRank) {
        bestRank = rank;
        _accepted = id;
      }
    }
    return acceptCost;
  }

  static const int _alignBig = 1 << 40;

  (int, List<(int, int)>) _talign(String y) {
    final m = y.length;
    final dp = List.generate(_n + 1, (_) => List<int>.filled(m + 1, 0));
    final bk = List.generate(_n + 1, (_) => List<int>.filled(m + 1, 0));
    for (var i = 1; i <= _n; i++) {
      dp[i][0] = dp[i - 1][0] + _alignBig + 2 * _h(_input.codeUnitAt(i - 1));
      bk[i][0] = _opSkip;
    }
    for (var j = 1; j <= m; j++) {
      dp[0][j] = dp[0][j - 1] + _alignBig + _widestClass;
      bk[0][j] = _opFab;
    }
    for (var i = 1; i <= _n; i++) {
      final hc = 2 * _h(_input.codeUnitAt(i - 1));
      for (var j = 1; j <= m; j++) {
        final eq = _input.codeUnitAt(i - 1) == y.codeUnitAt(j - 1);
        var best = dp[i - 1][j - 1] + (eq ? 0 : _alignBig + hc);
        var op = eq ? _opMatch : _opSub;
        final skip = dp[i - 1][j] + _alignBig + hc;
        if (skip < best) {
          best = skip;
          op = _opSkip;
        }
        final fabc = dp[i][j - 1] + _alignBig + _widestClass;
        if (fabc < best) {
          best = fabc;
          op = _opFab;
        }
        dp[i][j] = best;
        bk[i][j] = op;
      }
    }
    final script = <(int, int)>[];
    var i = _n, j = m;
    while (i > 0 || j > 0) {
      final op = i == 0
          ? _opFab
          : j == 0
              ? _opSkip
              : bk[i][j];
      script.add((op, op == _opFab ? y.codeUnitAt(j - 1) : -1));
      if (op == _opMatch || op == _opSub) {
        i--;
        j--;
      } else if (op == _opSkip) {
        i--;
      } else {
        j--;
      }
    }
    return (dp[_n][m], script.reversed.toList());
  }

  /// I26, on the tape route. Post-order on an explicit stack: a parent needs
  /// its children already remapped, so a `(m, n)` item means "the top `n`
  /// results are `m`'s children, join them". Each occurrence is rebuilt on its
  /// own, as the recursive form did, so a memo-shared subtree still yields
  /// distinct nodes.
  MatchResult _tremap(MatchResult root, List<int> bnd) {
    final work = <Object>[root];
    final done = <MatchResult>[];
    while (work.isNotEmpty) {
      final item = work.removeLast();
      if (item is (MatchResult, int)) {
        final (m, n) = item;
        final kids = done.sublist(done.length - n);
        done.length -= n;
        done.add(Match(m.clause, bnd[m.pos], bnd[m.pos + m.len] - bnd[m.pos],
            subClauseMatches: kids));
        continue;
      }
      final m = item as MatchResult;
      final subs = m.subClauseMatches;
      if (subs.isEmpty) {
        done.add(
            Match(m.clause, bnd[m.pos], bnd[m.pos + m.len] - bnd[m.pos]));
        continue;
      }
      work.add((m, subs.length));
      for (var i = subs.length - 1; i >= 0; i--) {
        work.add(subs[i]);
      }
    }
    return done.single;
  }

  SkipResult _tapeRecover(String input) {
    final cost = _tapeCost(input);
    if (cost < 0 || _accepted < 0) {
      final error = SyntaxError(pos: 0, len: input.length);
      return SkipResult(error, [error], const [], 1, true);
    }
    final y = _tsy[_accepted];
    final (_, script) = _talign(y);
    final bnd = List<int>.filled(y.length + 1, 0);
    final spans = <SyntaxError>[];
    final missing = <MissingObligation>[];
    var si = 0, j = 0, skipFrom = -1;
    void closeSkip() {
      if (skipFrom >= 0) {
        spans.add(SyntaxError(pos: skipFrom, len: si - skipFrom));
        skipFrom = -1;
      }
    }

    for (final (op, ch) in script) {
      switch (op) {
        case _opMatch || _opSub:
          closeSkip();
          if (j > 0) bnd[j] = si;
          j++;
          si++;
        case _opFab:
          closeSkip();
          if (j > 0) bnd[j] = si;
          j++;
          missing.add(MissingObligation(CharSet([(ch, ch)]), si));
        case _opSkip:
          if (skipFrom < 0) skipFrom = si;
          si++;
      }
    }
    closeSkip();
    bnd[y.length] = _n;
    final check =
        Parser(rules: rules, topRuleName: topRuleName, input: y).parse();
    lastVerified = !check.hasSyntaxErrors && check.root.len == y.length;
    final root = _tremap(check.root, bnd);
    spans.sort((a, b) => a.pos - b.pos);
    return SkipResult(root, List.of(spans), List.of(missing),
        spans.length + missing.length, false);
  }

  // ==== the driver (the twenty-fourth occasion's routing, seams removed) ====

  /// The public result, in library clauses.
  spr.SkipResult recover(String input) => toLibResult(_recoverCore(input), back);

  SkipResult _recoverCore(String input) {
    lastFellBack = false;
    final pure =
        Parser(rules: rules, topRuleName: topRuleName, input: input).parse();
    if (!pure.hasSyntaxErrors) {
      lastCost = 0;
      lastSteps = 0;
      lastVerified = true;
      return SkipResult(pure.root, const [], const [], 0, false);
    }
    if (!_wideG) {
      final r = _relaxedRecover(input);
      if (lastCost == -1) return r; // CFG-empty implies PEG-empty: exact
      if (lastVerified) return r; // the certificate: equality
    }
    lastFellBack = true;
    return _tapeRecover(input);
  }

  int recoverCost(String input) {
    _recoverCore(input); // no tree conversion: cost is what the caller wanted
    return lastCost;
  }
}

/// A terminal that reports when its answer depends on the open end of the
/// emitted text, and which next character would matter there.
class _Probe extends Terminal {
  _Probe(this.owner, this.inner)
      : need = switch (inner) {
          Str(:final text) => text.length,
          Nothing() => 0,
          _ => 1,
        };
  final SuperDot3 owner;
  final Terminal inner;
  final int need;

  @override
  MatchResult match(Parser parser, int pos) {
    if (need > 0 && pos + need > parser.input.length) {
      owner._touched = true;
      owner._noteAtoms(this, parser.input, pos);
    }
    return inner.match(parser, pos);
  }
}

class _Cls {
  _Cls(this.member, this.open, this.atoms);
  final bool member;
  final bool open;
  final List<int> atoms;
}
// ERROR RECOVERY END
