/// Error recovery as minimum-cost repair search.
///
/// The parse of an erroneous input is defined as: the PEG parse of the
/// repaired input s* in L(G) that minimizes the Damerau-Levenshtein edit
/// distance from the original input s (unit costs for character deletion,
/// insertion, substitution, and adjacent transposition).
///
/// The search is uniform-cost (Dijkstra): states are candidate repaired
/// strings; the start state is the input itself; expanding a state parses it
/// with the pure squirrel parser over an instrumented grammar (which records
/// where terminals/rules failed and what they expected), and proposes
/// single-edit successors at positions up to the failure frontier. The first
/// state that parses completely is a minimum-cost repair.
///
/// Candidate states are materialized lazily (one string at a time, in
/// deterministic preference order) so that memory stays proportional to the
/// number of states actually parsed, not the number proposed.
///
/// The core parsing algorithm is used unmodified as an oracle; recovery is
/// entirely an outer search. In particular, left recursion needs no special
/// treatment: every candidate is parsed by the ordinary squirrel algorithm.
library;

import '../parser/clause.dart';
import '../parser/combinators.dart';
import '../parser/match_result.dart';
import '../parser/parser.dart';
import '../parser/terminals.dart';
import 'observed_grammar.dart';
import 'witness.dart';

// ---------------------------------------------------------------------------
// Edit operations (for reporting; derived from the final alignment)
// ---------------------------------------------------------------------------

enum EditType { delete, insert, substitute, transpose }

/// A single character edit, in coordinates of the *original* input.
class Edit {
  final EditType type;

  /// Position in the original input where the edit applies.
  final int pos;

  /// The text inserted (for insert/substitute), empty for delete/transpose.
  final String text;

  Edit(this.type, this.pos, [this.text = '']);

  @override
  String toString() => switch (type) {
        EditType.delete => 'delete char at $pos',
        EditType.insert => 'insert "$text" at $pos',
        EditType.substitute => 'replace with "$text" at $pos',
        EditType.transpose => 'transpose at $pos',
      };
}

/// The result of a successful repair.
class RepairResult {
  /// The repaired input string (a member of L(G)).
  final String repaired;

  /// The total edit cost (Damerau-Levenshtein distance from the input).
  final int cost;

  /// The parse of the repaired input.
  final ParseResult parseResult;

  /// The edits, in original-input coordinates, that produce [repaired].
  final List<Edit> edits;

  /// Search statistics.
  final RepairStats stats;

  RepairResult(
      {required this.repaired,
      required this.cost,
      required this.parseResult,
      required this.edits,
      required this.stats});
}

class RepairStats {
  int statesExpanded = 0;
  int statesGenerated = 0;
  int parsesRun = 0;
  int charsParsed = 0;
  bool usedPanicFallback = false;

  @override
  String toString() =>
      'expanded=$statesExpanded materialized=$statesGenerated parses=$parsesRun charsParsed=$charsParsed'
      '${usedPanicFallback ? ' (panic fallback used)' : ''}';
}

// ---------------------------------------------------------------------------
// Candidate edits and lazy search states
// ---------------------------------------------------------------------------

enum _Op { transpose, insert, substitute, delete }

/// A candidate single edit of a source state's string (compact descriptor;
/// the edited string is only materialized when the candidate is dequeued).
class _Cand {
  final _Op op;
  final int j;
  final String text;
  const _Cand(this.op, this.j, [this.text = '']);
}

/// An expanded (parsed) state, holding its candidate list for lazy expansion.
class _Source {
  final int seq; // expansion sequence number (deterministic tie-break)
  final String s;
  final int g;

  /// Positions in [s] holding synthetic characters (inserted or substituted
  /// by the repair so far). Used for the strict progress metric: synthetic
  /// characters do not count as progress through the user's own input.
  final List<int> marks;

  final List<_Cand> cands;

  /// Index into [cands] marking the end of the targeted candidates (observer
  /// -driven edits plus deletes); candidates beyond this point are the
  /// completeness-net tail.
  final int endOfTargeted;

  _Source(this.seq, this.s, this.g, this.marks, this.cands, this.endOfTargeted);
}

/// A heap entry: either a concrete state to parse (s != null), or a cursor
/// into a source's candidate list (materialized lazily on pop).
class _Entry {
  final int g;
  final int parentSeq;
  final int idx;
  final _Source? source; // cursor entries
  final String? s; // concrete entries (root, macro insertions)
  final List<int>? marks;
  const _Entry(this.g, this.parentSeq, this.idx, {this.source, this.s, this.marks});
}

class _Heap {
  final _items = <_Entry>[];

  bool get isEmpty => _items.isEmpty;
  int get length => _items.length;

  bool _less(_Entry a, _Entry b) {
    if (a.g != b.g) return a.g < b.g;
    if (a.parentSeq != b.parentSeq) return a.parentSeq < b.parentSeq;
    return a.idx < b.idx;
  }

  void push(_Entry e) {
    _items.add(e);
    var i = _items.length - 1;
    while (i > 0) {
      final p = (i - 1) >> 1;
      if (_less(_items[i], _items[p])) {
        final t = _items[i];
        _items[i] = _items[p];
        _items[p] = t;
        i = p;
      } else {
        break;
      }
    }
  }

  _Entry pop() {
    final top = _items.first;
    final last = _items.removeLast();
    if (_items.isNotEmpty) {
      _items[0] = last;
      var i = 0;
      while (true) {
        final l = 2 * i + 1, r = 2 * i + 2;
        var m = i;
        if (l < _items.length && _less(_items[l], _items[m])) m = l;
        if (r < _items.length && _less(_items[r], _items[m])) m = r;
        if (m == i) break;
        final t = _items[i];
        _items[i] = _items[m];
        _items[m] = t;
        i = m;
      }
    }
    return top;
  }
}

// ---------------------------------------------------------------------------
// The repair search
// ---------------------------------------------------------------------------

/// How repairs are searched for.
enum RepairMode {
  /// Uniform-cost (globally minimal) search that commits to the best repair
  /// found so far whenever deepening further stops being productive: after
  /// the targeted single-edit candidates are exhausted with real progress in
  /// hand, at a cost-level boundary with real progress in hand, or at the
  /// state budget. Committed rounds repair errors left-to-right, mirroring
  /// PEG's own leftmost commitment; each round's repair is minimal-cost
  /// among the candidates explored. Single isolated errors are repaired
  /// exactly minimally; independent errors are each repaired minimally.
  committed,

  /// A single unbounded uniform-cost search over all edit combinations: the
  /// result is globally minimal (within the candidate move set), but the
  /// search space grows multiplicatively with the number of simultaneous
  /// errors. Practical for small inputs / few errors; falls back to panic
  /// mode at the state cap.
  global,
}

class RepairSearch {
  /// The grammar (rule names may carry the '~' transparent prefix).
  final Map<String, Clause> rules;
  final String topRuleName;

  final RepairMode mode;

  /// Per-round limit on parsed states. Reaching the limit commits to the
  /// best-progress state (committed mode) or falls back to panic mode.
  /// Null = adaptive.
  final int? maxStatesExpanded;

  /// Only propose edits within this many characters before the failure
  /// frontier. Null = unlimited (full minimality within the move set);
  /// setting a window bounds per-error search cost on large inputs at the
  /// expense of long-range repairs.
  final int? window;

  /// Cap on how many characters of a lookahead-blocked span are considered
  /// for perturbation edits.
  final int blockedSpanCap;

  /// Radius around the failure frontier within which all edit types are
  /// "targeted" candidates (tried before any long-range candidates, and
  /// gating the early commit in committed mode). Evidence-based candidates
  /// (positions where the parse recorded an expectation) are targeted at any
  /// distance.
  final int targetedRadius;

  late final Map<String, String> _witnesses = computeRuleWitnesses(rules);
  late final List<String> _alphabet = grammarAlphabet(rules).toList();
  late final Set<String> _exactAlphabet = _computeExactAlphabet();

  /// Characters the grammar demands verbatim somewhere (Char/Str literals
  /// and single-character sets): the structural "glue" of the language.
  Set<String> _computeExactAlphabet() {
    final out = <String>{};
    final seen = <Clause>{};
    void walk(Clause c) {
      if (!seen.add(c)) return;
      if (c is Char) out.add(c.char);
      if (c is Str) out.addAll(c.text.split(''));
      if (c is CharSet && !c.inverted && c.ranges.length == 1 && c.ranges.first.$1 == c.ranges.first.$2) {
        out.add(String.fromCharCode(c.ranges.first.$1));
      }
      if (c is HasOneSubClause) walk(c.subClause);
      if (c is HasMultipleSubClauses) c.subClauses.forEach(walk);
    }

    rules.values.forEach(walk);
    return out;
  }

  /// Optional hook for debugging/tracing round commits in committed mode.
  void Function(String base, String committed, int g, int frontier)? onRoundCommit;

  /// Optional hook called on every state expansion (for debugging).
  void Function(String s, int g, int frontier)? onExpand;

  RepairSearch(
      {required this.rules,
      required this.topRuleName,
      this.mode = RepairMode.committed,
      this.maxStatesExpanded,
      this.window,
      this.blockedSpanCap = 16,
      this.targetedRadius = 32});

  /// Parse [input]; if it does not fully match, search for a minimum-cost
  /// repair. Returns null only if no repair could be found within limits
  /// (which can only happen if L(G) is effectively empty, or limits are hit
  /// and the panic fallback also fails).
  RepairResult? repair(String input) {
    final stats = RepairStats();
    final observer = FailureObserver();
    final instrumented = instrumentGrammar(rules, observer);

    (bool, int, ParseResult) tryParse(String s) {
      observer.reset();
      stats.parsesRun++;
      stats.charsParsed += s.length;
      final parser = Parser(rules: instrumented, topRuleName: topRuleName, input: s);
      final result = parser.parse();
      // Note: on a total mismatch, ParseResult.root is a SyntaxError node
      // spanning the whole input (not a mismatch), so the matched length must
      // be read as 0 in that case.
      final root = result.root;
      final matchedLen = (root is SyntaxError || root.isMismatch) ? 0 : root.len;
      final ok = !result.hasSyntaxErrors;
      // Failure frontier: the farthest point the parser inspected and failed,
      // or the end of the successfully matched prefix for trailing garbage.
      var frontier = observer.farthestFail;
      if (matchedLen > frontier) frontier = matchedLen;
      if (frontier > s.length) frontier = s.length;
      if (frontier < 0) frontier = 0;
      return (ok, frontier, result);
    }


    // Committed mode: repair errors left-to-right. Each round runs a
    // uniform-cost search from the current base string; the round ends
    // either with a full parse (done) or by committing to the minimal-cost
    // state with maximal strict progress.
    var base = input;
    var totalCost = 0;
    var rounds = 0;
    while (true) {
      final round = _searchRound(base, tryParse, observer, stats);
      if (round == null) {
        return _panicFallback(input, base, totalCost, tryParse, stats);
      }
      totalCost += round.g;
      if (round.success) {
        return RepairResult(
            repaired: round.s,
            cost: totalCost,
            parseResult: round.parseResult!,
            edits: _align(input, round.s),
            stats: stats);
      }
      base = round.s;
      // Safety valve: a stuck loop falls through to panic.
      rounds++;
      if (rounds > 2 * (input.length + 8)) {
        return _panicFallback(input, base, totalCost, tryParse, stats);
      }
    }
  }

  /// One round of uniform-cost search from [base]. Returns:
  /// - a success outcome (full parse), or
  /// - in committed mode, a committed best-progress state, or
  /// - null if the search exhausted its limits without progress.
  _RoundOutcome? _searchRound(String base, (bool, int, ParseResult) Function(String) tryParse,
      FailureObserver observer, RepairStats stats) {
    final heap = _Heap();
    final visited = <String>{};
    var sourceSeq = 0;

    heap.push(_Entry(0, -1, 0, s: base, marks: const []));

    // Strict progress: number of the user's own (non-synthetic) characters
    // successfully consumed before the failure frontier. Raw progress: the
    // frontier adjusted for net length change (deleted characters count as
    // "explained"). Strict progress governs commits at level boundaries;
    // raw progress is the budget-exhaustion fallback.
    var baseStrict = -1;
    var baseRaw = -1;
    _Committable? bestStrict;
    _Committable? bestRaw;
    var expandedThisRound = 0;
    var lastPoppedG = 0;
    var baseSourceExhaustedTargeted = false;

    final budget = maxStatesExpanded ?? (3 * (targetedRadius + 8) * (_alphabet.length + 4) + 16000);

    // Boundary and early commits require *strict* progress (real user
    // characters consumed): synthetic insertions and substitutions do not
    // count, so a repair that merely papers over the frontier does not
    // trigger a premature commit.
    _RoundOutcome? commitIfStrictProgress() {
      if (mode != RepairMode.committed) return null;
      final best = bestStrict;
      if (best == null) return null;
      onRoundCommit?.call(base, best.s, best.g, best.raw);
      return _RoundOutcome(best.s, best.g, success: false);
    }

    while (!heap.isEmpty) {
      final entry = heap.pop();

      String s;
      List<int> marks;
      final source = entry.source;
      if (source != null) {
        // Cursor entry: materialize the next unseen candidate of the source.
        var idx = entry.idx;
        String? s2;
        _Cand? cand;
        while (idx < source.cands.length) {
          cand = source.cands[idx];
          final applied = _applyCand(source.s, cand);
          stats.statesGenerated++;
          if (applied != null && !visited.contains(applied)) {
            s2 = applied;
            break;
          }
          idx++;
        }
        // Early commit: once the base state's targeted candidates have all
        // been examined, further single edits are the exhaustive long-range
        // tail; if real (strict) progress is already in hand, commit to it
        // instead of materializing the tail.
        if (source.seq == 1 && !baseSourceExhaustedTargeted && idx >= source.endOfTargeted) {
          baseSourceExhaustedTargeted = true;
          final committed = commitIfStrictProgress();
          if (committed != null) return committed;
        }
        if (s2 == null) continue; // source exhausted
        // Re-push the sibling cursor for the rest of the candidate list.
        if (idx + 1 < source.cands.length) {
          heap.push(_Entry(entry.g, source.seq, idx + 1, source: source));
        }
        s = s2;
        marks = _applyMarks(source.marks, cand!);
      } else {
        s = entry.s!;
        marks = entry.marks ?? const [];
        if (visited.contains(s)) continue;
      }

      visited.add(s);

      // Cost-level boundary: all states of lower cost have been examined.
      if (entry.g > lastPoppedG) {
        final committed = commitIfStrictProgress();
        if (committed != null) return committed;
        lastPoppedG = entry.g;
      }

      stats.statesExpanded++;
      expandedThisRound++;

      final (ok, frontier, parseResult) = tryParse(s);
      if (ok) {
        return _RoundOutcome(s, entry.g, success: true, parseResult: parseResult);
      }

      final raw = frontier - (s.length - base.length);
      var synthBefore = 0;
      for (final m in marks) {
        if (m < frontier) synthBefore++;
      }
      final strict = frontier - synthBefore;
      onExpand?.call(s, entry.g, raw);

      if (baseStrict < 0) {
        baseStrict = strict;
        baseRaw = raw;
      } else if (entry.g > 0) {
        // Best strict-progress state; ties broken by raw progress (a state
        // that additionally *accounted for* more of the original input — by
        // attributing characters as deletions — is a better commit).
        final bs = bestStrict;
        if ((bs == null || strict > bs.strict || (strict == bs.strict && raw > bs.raw)) &&
            strict > baseStrict) {
          bestStrict = _Committable(s, entry.g, strict, raw);
        }
        final br = bestRaw;
        if ((br == null || raw > br.raw) && raw > baseRaw) {
          bestRaw = _Committable(s, entry.g, strict, raw);
        }
      }

      if (expandedThisRound >= budget) {
        // Budget exhausted. In committed mode, commit to the best progress
        // found so far (strict preferred, raw as fallback); else give up.
        if (mode == RepairMode.committed) {
          final best = bestStrict ?? bestRaw;
          if (best != null) {
            onRoundCommit?.call(base, best.s, best.g, best.raw);
            return _RoundOutcome(best.s, best.g, success: false);
          }
        }
        return null;
      }

      // Build this state's candidate list from the observer's failure data,
      // and enqueue a cursor for it plus eager macro (witness) insertions.
      // The candidate window extends to the consulted horizon: the farthest
      // position any character test read in this parse, successful lookahead
      // reads included. Edits beyond the horizon cannot change the parse (the
      // trace replays identically), so [0, horizon] is a complete window;
      // edits between the frontier and the horizon CAN matter (e.g. breaking
      // a positive lookahead that succeeded on damaged input).
      var horizon = observer.horizon;
      if (horizon < frontier) horizon = frontier;
      if (horizon > s.length) horizon = s.length;
      final built = _buildCands(s, frontier, horizon, observer);
      final src = _Source(++sourceSeq, s, entry.g, marks, built.cands, built.endOfTargeted);
      if (src.cands.isNotEmpty) {
        heap.push(_Entry(entry.g + 1, src.seq, 0, source: src));
      }
      var macroIdx = 1 << 20;
      for (final (j, w) in built.macros) {
        final s2 = s.substring(0, j) + w + s.substring(j);
        final marks2 = [
          for (final m in marks) m >= j ? m + w.length : m,
          for (var k = 0; k < w.length; k++) j + k,
        ];
        heap.push(_Entry(entry.g + w.length, src.seq, macroIdx++, s: s2, marks: marks2));
        stats.statesGenerated++;
      }
    }
    return null;
  }

  /// Build the ordered candidate list for a failed state. Order encodes the
  /// deterministic preference among equal-cost repairs: positions closest to
  /// the failure frontier first; at each position transpose > exact-insert >
  /// exact-substitute > delete > filler; then the long-range sweep of
  /// frontier-expected characters; then lookahead-block perturbations; then
  /// the whole-alphabet completeness net (character-major).
  ({List<_Cand> cands, int endOfTargeted, List<(int, String)> macros}) _buildCands(
      String s, int frontier, int horizon, FailureObserver observer) {
    final cands = <_Cand>[];
    final macros = <(int, String)>[];
    final jmin = window == null ? 0 : (frontier - window!).clamp(0, frontier);
    final jlocal = (frontier - targetedRadius).clamp(jmin, frontier);

    final exactExpected = observer.exactExpectedAt;
    final fillerExpected = observer.fillerExpectedAt;
    final failedRules = observer.failedRulesAt;
    final blockedSpans = observer.blockedSpans;

    void perPosition(int j) {
      // Transpose adjacent characters at j (Damerau): restores the user's
      // own content exactly, in place.
      if (j + 1 < s.length && s[j] != s[j + 1]) {
        cands.add(_Cand(_Op.transpose, j));
      }
      // Insert a character the grammar demands verbatim at j.
      for (final c in exactExpected[j] ?? const <String>{}) {
        cands.add(_Cand(_Op.insert, j, c));
      }
      // Substitute with an exactly-expected character at j.
      for (final c in exactExpected[j] ?? const <String>{}) {
        if (j < s.length && s[j] != c) {
          cands.add(_Cand(_Op.substitute, j, c));
        }
      }
      // Delete the character at j.
      if (j < s.length) {
        cands.add(_Cand(_Op.delete, j));
      }
      // Insert / substitute a filler character (arbitrary representative of
      // a failed character class) at j.
      for (final c in fillerExpected[j] ?? const <String>{}) {
        cands.add(_Cand(_Op.insert, j, c));
        if (j < s.length && s[j] != c) {
          cands.add(_Cand(_Op.substitute, j, c));
        }
      }
      // Witness of an entire failed rule: single-character witnesses join
      // the unit-cost stream; longer ones become eager macro states.
      for (final ruleName in failedRules[j] ?? const <String>{}) {
        final w = _witnesses[ruleName];
        if (w == null || w.isEmpty) continue;
        if (w.length == 1) {
          cands.add(_Cand(_Op.insert, j, w));
        } else {
          macros.add((j, w));
        }
      }
    }

    // Targeted tier 1: all edit types near the frontier.
    for (var j = frontier; j >= jlocal; j--) {
      perPosition(j);
    }

    // Targeted tier 2: evidence-based candidates farther back — positions
    // where this parse actually recorded an expectation. PEG failure data is
    // dense (rules fail at most positions during a normal parse), so only
    // the closest positions to the frontier are targeted; the rest of the
    // window is covered by the long-range tail.
    if (jlocal > jmin) {
      const evidenceCap = 48;
      final evidencePositions = <int>{
        for (final p in exactExpected.keys)
          if (p >= jmin && p < jlocal) p,
        for (final p in fillerExpected.keys)
          if (p >= jmin && p < jlocal) p,
        for (final p in failedRules.keys)
          if (p >= jmin && p < jlocal) p,
      }.toList()
        ..sort((a, b) => b.compareTo(a));
      for (final j in evidencePositions.take(evidenceCap)) {
        perPosition(j);
      }
    }

    // Targeted tier 3 — local delimiter sweep: structural characters that
    // are exactly expected at the frontier, or that *occur* nearby (the
    // grammar's verbatim "glue" visible in the error neighborhood, e.g. a
    // quote), may belong at an earlier position: a missing or damaged
    // delimiter makes a clause over- or under-consume its span, and
    // re-inserting the delimiter re-segments the input. Nearest-first.
    final localSweepChars = <String>{
      ...exactExpected[frontier] ?? const <String>{},
      for (var j = jlocal; j < frontier && j < s.length; j++)
        if (_exactAlphabet.contains(s[j])) s[j],
    };
    for (final c in localSweepChars) {
      for (var j = frontier - 1; j >= jlocal; j--) {
        cands.add(_Cand(_Op.insert, j, c));
      }
    }
    for (final c in localSweepChars) {
      for (var j = frontier - 1; j >= jlocal; j--) {
        if (j < s.length && s[j] != c) {
          cands.add(_Cand(_Op.substitute, j, c));
        }
      }
    }

    // Targeted tier 4 — frontier-local completeness net: all alphabet
    // characters in the immediate neighborhood of the frontier. Covers
    // repairs whose evidence is shadowed by PEG's committed choice: when an
    // earlier alternative of a First succeeded (e.g. Number matching the
    // "5" of "5rue"), the expectations of untried later alternatives (the
    // "t" of "true") are never recorded.
    final jnet = (frontier - 4).clamp(jmin, frontier);
    for (final c in _alphabet) {
      for (var j = frontier; j >= jnet; j--) {
        cands.add(_Cand(_Op.insert, j, c));
        if (j < s.length && s[j] != c) {
          cands.add(_Cand(_Op.substitute, j, c));
        }
      }
    }

    // Consulted region beyond the failure frontier: positions the parse read
    // (via successful lookaheads or matched-then-discarded branches) without
    // failing there. An edit here can flip a lookahead's outcome and change
    // the parse, so completeness requires every edit type over the full
    // region up to the horizon; nearest the frontier first.
    for (var j = frontier + 1; j <= horizon; j++) {
      if (j + 1 < s.length && s[j] != s[j + 1]) {
        cands.add(_Cand(_Op.transpose, j));
      }
      if (j < s.length) {
        cands.add(_Cand(_Op.delete, j));
      }
      for (final c in _alphabet) {
        cands.add(_Cand(_Op.insert, j, c));
        if (j < s.length && s[j] != c) {
          cands.add(_Cand(_Op.substitute, j, c));
        }
      }
    }

    // Perturbation edits inside lookahead-blocked spans: when a
    // NotFollowedBy failed because its subclause matched, breaking that
    // match (by deleting or substituting a character inside the span) may be
    // the minimal repair, even though no terminal failed there.
    for (final (spanPos, spanLen) in blockedSpans) {
      final end = (spanPos + spanLen).clamp(0, s.length);
      final cap = (spanPos + blockedSpanCap).clamp(0, end);
      for (var j = spanPos; j < cap; j++) {
        cands.add(_Cand(_Op.delete, j));
        for (final c in _alphabet) {
          if (s[j] != c) {
            cands.add(_Cand(_Op.substitute, j, c));
          }
        }
      }
    }

    final endOfTargeted = cands.length;

    // Long-range tail, tier 1 — sweep: characters that are exactly expected
    // at the frontier may actually belong at an earlier position, when a
    // clause over-consumed input on its way to the failure (e.g. an
    // unterminated string whose closing quote belongs mid-span, far before
    // the eventual failure at end of input).
    final frontierExact = exactExpected[frontier] ?? const <String>{};
    for (final c in frontierExact) {
      for (var j = jlocal - 1; j >= jmin; j--) {
        cands.add(_Cand(_Op.insert, j, c));
      }
    }
    for (final c in frontierExact) {
      for (var j = jlocal - 1; j >= jmin; j--) {
        if (j < s.length && s[j] != c) {
          cands.add(_Cand(_Op.substitute, j, c));
        }
      }
    }

    // Long-range tail, tier 2 — far deletions and transpositions.
    for (var j = jlocal - 1; j >= jmin; j--) {
      if (j + 1 < s.length && s[j] != s[j + 1]) {
        cands.add(_Cand(_Op.transpose, j));
      }
      if (j < s.length) {
        cands.add(_Cand(_Op.delete, j));
      }
    }

    // Long-range tail, tier 3 — completeness net: whole-alphabet insertions
    // and substitutions over the full candidate window, covering repairs at
    // positions where the failed parse recorded no expectation at all —
    // e.g. an alternative shadowed by an earlier committed choice, or a
    // delimiter that belongs deep inside a span that was matched (wrongly)
    // without complaint. Character-major order: structurally significant
    // characters (which appear early in the grammar) take precedence over
    // escape-character tricks.
    for (final c in _alphabet) {
      for (var j = frontier; j >= jmin; j--) {
        cands.add(_Cand(_Op.insert, j, c));
        if (j < s.length && s[j] != c) {
          cands.add(_Cand(_Op.substitute, j, c));
        }
      }
    }

    return (cands: cands, endOfTargeted: endOfTargeted, macros: macros);
  }

  /// Apply a candidate edit; returns null for no-op edits.
  String? _applyCand(String s, _Cand cand) {
    final j = cand.j;
    switch (cand.op) {
      case _Op.transpose:
        if (j + 1 >= s.length || s[j] == s[j + 1]) return null;
        return s.substring(0, j) + s[j + 1] + s[j] + s.substring(j + 2);
      case _Op.insert:
        if (j > s.length) return null;
        return s.substring(0, j) + cand.text + s.substring(j);
      case _Op.substitute:
        if (j >= s.length || s[j] == cand.text) return null;
        return s.substring(0, j) + cand.text + s.substring(j + 1);
      case _Op.delete:
        if (j >= s.length) return null;
        return s.substring(0, j) + s.substring(j + 1);
    }
  }

  /// Track synthetic-character positions across an edit.
  List<int> _applyMarks(List<int> marks, _Cand cand) {
    final j = cand.j;
    switch (cand.op) {
      case _Op.transpose:
        return [
          for (final m in marks)
            m == j
                ? j + 1
                : m == j + 1
                    ? j
                    : m
        ];
      case _Op.insert:
        return [for (final m in marks) m >= j ? m + cand.text.length : m, j];
      case _Op.substitute:
        return marks.contains(j) ? marks : [...marks, j];
      case _Op.delete:
        return [
          for (final m in marks)
            if (m != j) m > j ? m - 1 : m
        ];
    }
  }

  /// Panic fallback: deterministically delete one character at the failure
  /// frontier and re-parse, until the input parses or is exhausted. This
  /// bounds worst-case recovery at O(n) parses.
  RepairResult? _panicFallback(String original, String s, int gSoFar,
      (bool, int, ParseResult) Function(String) tryParse, RepairStats stats) {
    stats.usedPanicFallback = true;
    var cur = s;
    var cost = gSoFar;
    while (true) {
      final (ok, frontier, parseResult) = tryParse(cur);
      if (ok) {
        return RepairResult(
            repaired: cur,
            cost: cost,
            parseResult: parseResult,
            edits: _align(original, cur),
            stats: stats);
      }
      if (cur.isEmpty) {
        // Deletion alone cannot reach L(G): as a last resort, try the
        // shortest witness of the top rule (a minimal valid "program").
        final topWitness =
            _witnesses[topRuleName.startsWith('~') ? topRuleName.substring(1) : topRuleName];
        if (topWitness != null) {
          final (okW, _, parseW) = tryParse(topWitness);
          if (okW) {
            return RepairResult(
                repaired: topWitness,
                cost: cost + topWitness.length,
                parseResult: parseW,
                edits: _align(original, topWitness),
                stats: stats);
          }
        }
        return null;
      }
      final j = frontier.clamp(0, cur.length - 1);
      cur = cur.substring(0, j) + cur.substring(j + 1);
      cost += 1;
    }
  }
}

/// A state eligible for committing (with its progress measures).
class _Committable {
  final String s;
  final int g;
  final int strict;
  final int raw;
  _Committable(this.s, this.g, this.strict, this.raw);
}

/// Outcome of one search round: either a full parse ([success] true) or a
/// committed best-progress state to continue from.
class _RoundOutcome {
  final String s;
  final int g;
  final bool success;
  final ParseResult? parseResult;
  _RoundOutcome(this.s, this.g, {required this.success, this.parseResult});
}

// ---------------------------------------------------------------------------
// Alignment: recover the edit list from (original, repaired) by
// Damerau-Levenshtein traceback, for error reporting in original coordinates.
// ---------------------------------------------------------------------------

List<Edit> _align(String a, String b) {
  final n = a.length, m = b.length;
  // Guard against quadratic blowup on very large inputs: alignment is only
  // for reporting, so skip it if the table would be excessive.
  if (n * m > 25000000) return const [];
  final d = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (var i = 0; i <= n; i++) {
    d[i][0] = i;
  }
  for (var j = 0; j <= m; j++) {
    d[0][j] = j;
  }
  for (var i = 1; i <= n; i++) {
    for (var j = 1; j <= m; j++) {
      final sub = d[i - 1][j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1);
      var best = sub;
      if (d[i - 1][j] + 1 < best) best = d[i - 1][j] + 1; // delete a[i-1]
      if (d[i][j - 1] + 1 < best) best = d[i][j - 1] + 1; // insert b[j-1]
      if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
        if (d[i - 2][j - 2] + 1 < best) best = d[i - 2][j - 2] + 1; // transpose
      }
      d[i][j] = best;
    }
  }
  // Traceback.
  final edits = <Edit>[];
  var i = n, j = m;
  while (i > 0 || j > 0) {
    if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1] && d[i][j] == d[i - 2][j - 2] + 1) {
      edits.add(Edit(EditType.transpose, i - 2));
      i -= 2;
      j -= 2;
    } else if (i > 0 && j > 0 && d[i][j] == d[i - 1][j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)) {
      if (a[i - 1] != b[j - 1]) {
        edits.add(Edit(EditType.substitute, i - 1, b[j - 1]));
      }
      i--;
      j--;
    } else if (i > 0 && d[i][j] == d[i - 1][j] + 1) {
      edits.add(Edit(EditType.delete, i - 1));
      i--;
    } else {
      edits.add(Edit(EditType.insert, i, b[j - 1]));
      j--;
    }
  }
  return edits.reversed.toList();
}
