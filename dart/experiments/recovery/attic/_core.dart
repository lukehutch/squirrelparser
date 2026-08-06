// _core.dart -- the portable parser core that every standalone engine carries.
//
// This is a copy of `lib/src/parser/{clause,combinators,terminals,match_result,
// memo_entry,parser}.dart` with three deliberate changes, and nothing else:
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
// `parserStats` is dropped (profiling only). Behaviour is otherwise identical
// to the frozen library, which `_coregate.dart` checks differentially.
//
// This file compiles on its own so it stays type-checked. Engines inline the
// span between the CORE BEGIN and CORE END markers rather than importing it,
// because the point of the copy is that an engine may tune its own core.
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
// CORE END

void main() {
  final back = <Clause, sp.Clause>{};
  final rules = rulesToCore(sp.MetaGrammar.parseGrammar("S <- 'a'+ 'b';\n"), back);
  final p = Parser(rules: rules, topRuleName: 'S', input: 'aab');
  final r = p.parse();
  print('parsed=${!r.hasSyntaxErrors} len=${r.root.len} maxRead=${p.maxRead}');
}
