// Skip-based error recovery: "leading edge" resumption (PROTOTYPE).
//
// A fundamentally different recovery model from repair_search.dart: instead
// of searching for a minimum-edit repaired *string*, this driver keeps the
// original input untouched and produces a full-coverage parse tree in which
// unparseable regions appear as SyntaxError spans and unfulfillable
// grammar obligations are skipped ("missing").
//
// Model (Luke, 2026-07-21): the only clause types that advance the parse
// position are Seq and Repetition (with >= 1 item). When a parse fails,
// reconstruct the "leading edge": the spine of in-progress Seq/Repetition
// nodes down to the deepest meaningful mismatch - choosing, at each First,
// the alternative that can reach furthest; reopening a stopped repetition
// or empty-matched Optional whose resumed attempt reaches further than the
// enclosing Seq's failed obligation; never descending into lookaheads.
// Then scan for a resumption in increasing COST order, where
//   cost = (characters skipped as a syntax-error span n)
//        + (grammar obligations skipped as "missing"),
// preferring, at equal cost, char-skips over obligation-skips, and deeper
// (more local) frames over shallower ones:
//   - Seq frame: re-try remaining obligations at pos+n, skipping
//     mismatching obligations as missing (a partial restoration of
//     Levenshtein insertions), accepting the first len>0 match;
//   - Repetition frame / reopenable repetition (or empty Optional) inside
//     an already-matched child: try one more item at pos+n;
//   - retract (the skip rule leftward): a greedy repetition inside a matched
//     tail child gives back trailing items so the enclosing Seq's remaining
//     obligations re-match earlier (fixes quote-parity swallowing);
//   - rewind (the skip rule before a matched subclause): a Seq frame gives
//     back trailing MATCHED children and places the span before them (fixes
//     prefix garbage that made a subclause match short but successfully);
//   - Str-as-Seq: a multi-char literal is a Seq of chars, so the (J-j) rule
//     applies inside corrupted keywords ("tQue" resumes mid-token).
// On a hit, insert a SyntaxError span of length n, stitch the synthetic
// match into the tree (outside the parser - the memo table stays pure),
// and continue regular parsing; recover again at the next failure.
// Descent choices are ranked by a budgeted reach metric (deepening into a
// mismatched sub-clause is free - it is the same error localized deeper -
// and only skipping past an obligation pays); because reach has no
// char-skip model, ambiguous rankings are settled by a bounded two-way
// lookahead: evaluate the top-2 choices by their actual best scan score.
// First alternatives are ranked by REAL progress (budget-0 reach: genuine
// matches / prefix agreement) before budgeted reach: an absorber like
// Character* tunnels to the next anchor under one budgeted skip, inflating
// wrong alternatives above the true one, and honest progress cannot be
// faked. Remaining full ties are settled by a k-way consequence eval (up
// to two members of the top class + the best of the next class, by scan
// score) - heuristic ties must never be broken by declaration order.
//
// The parser is used strictly as an unmodified oracle: the driver only ever
// calls Parser.match(clause, pos) against the real input, and all stitching
// of synthetic matches happens driver-side. Termination: every accepted
// resumption either consumes >= 1 character or discharges obligations, and
// the top-level wrapper can always complete by consuming the rest of the
// input as one trailing SyntaxError span.
//
// Known limitations (prototype): left-recursive rules cannot be "reopened"
// (their iteration lives in the memo table, not in a Repetition node), so
// an error after a left-recursive match degrades to a trailing span; only
// the single most promising reopen point is descended into per failure
// (full-item reopen probes are still scanned for all of them).

import '../parser/clause.dart';
import '../parser/combinators.dart';
import '../parser/match_result.dart';
import '../parser/parser.dart';
import '../parser/terminals.dart';

/// Synthetic obligation that matches (len 0) only at end of input.
class _Eof extends Clause {
  const _Eof();
  @override
  MatchResult match(Parser parser, int pos) =>
      pos == parser.input.length ? Match(this, pos, 0) : mismatch;
  @override
  void checkRuleRefs(Map<String, Clause> grammarMap) {}
  @override
  String toString() => '<end of input>';
}

/// A skipped obligation ("missing" content), for reporting.
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

// ---------------------------------------------------------------------------
// Frames

abstract class _Frame {}

/// An in-progress Seq (or the driver's top-level wrapper, seqClause == null).
class _SeqFrame extends _Frame {
  final Clause? seqClause;
  final List<Clause> obligations;
  final int startPos;
  final List<MatchResult> children = [];
  final List<int> childOblig = []; // parallel to children; -1 for spans
  int nextIndex = 0;
  int curr;
  _SeqFrame(this.seqClause, this.obligations, this.startPos) : curr = startPos;
}

/// An in-progress Repetition (failed OneOrMore, or a reopened repetition).
class _RepFrame extends _Frame {
  final Repetition rep;
  final int startPos;
  final List<MatchResult> children = []; // items and spans
  final int seedLen;
  final bool reopened;
  int curr;
  _RepFrame(this.rep, this.startPos, List<MatchResult> seed, this.curr,
      {this.reopened = false})
      : seedLen = seed.length {
    children.addAll(seed);
  }
}

/// Passive wrapper (Ref / First): wraps a delivered match on the way down.
class _WrapFrame extends _Frame {
  final Clause clause;
  _WrapFrame(this.clause);
}

/// Reopen point being descended into: when the completed match arrives,
/// rebuild the already-matched child of the parent _SeqFrame and patch it.
class _ReopenSlot extends _Frame {
  final int childIndex;
  final int obligIndex;
  final MatchResult Function(MatchResult m) rebuild;
  _ReopenSlot(this.childIndex, this.obligIndex, this.rebuild);
}

// ---------------------------------------------------------------------------

/// A reopenable point inside an already-matched child of a Seq frame:
/// a stopped Repetition, or an Optional that matched empty, whose right
/// edge sits exactly at the frame's current position.
class _ReopenCand {
  final int childIndex;
  final int obligIndex;
  final MatchResult Function(MatchResult) wrapChain; // context around it
  final Repetition? rep;
  final int repStart;
  final List<MatchResult> repItems;
  final Optional? optClause;
  // Re-choice: re-attempt a different First alternative from the choice
  // point's own start position (with recovery inside the attempt).
  final First? firstClause;
  final Clause? alt;
  final int altStart;
  _ReopenCand(
      {required this.childIndex,
      required this.obligIndex,
      required this.wrapChain,
      this.rep,
      this.repStart = 0,
      this.repItems = const [],
      this.optClause,
      this.firstClause,
      this.alt,
      this.altStart = 0});

  Clause get itemClause => rep != null ? rep!.subClause : optClause!.subClause;

  /// Build the replacement child match given the new tail (span + item).
  MatchResult buildChild(List<MatchResult> extras) {
    final inner = rep != null
        ? Match(rep, 0, 0, subClauseMatches: [...repItems, ...extras])
        : Match(optClause, 0, 0, subClauseMatches: extras);
    return wrapChain(inner);
  }
}

/// A retractable point: a greedy Repetition inside an already-matched tail
/// child of a Seq frame. The skip rule applied leftward: the repetition may
/// GIVE BACK trailing items so that the following obligations of its
/// enclosing Seq ([post]) re-match earlier - the mirror image of skipping
/// forward over garbage. (Motivating family: quote-parity errors, where
/// Character* swallows everything past a lost '"'.)
class _RetractCand {
  final int childIndex;
  final int obligIndex;
  final Repetition rep;
  final int repStart;
  final List<MatchResult> repItems;
  final List<Clause> post; // enclosing Seq's subclauses after the rep
  /// Rebuild the full replacement frame child from the truncated repetition
  /// match followed by the re-walked post matches.
  final MatchResult Function(List<MatchResult> repAndPost) rebuild;
  _RetractCand(
      {required this.childIndex,
      required this.obligIndex,
      required this.rep,
      required this.repStart,
      required this.repItems,
      required this.post,
      required this.rebuild});
}

class _Hit {
  final int frameIndex;
  final int n; // skipped chars
  // Seq k-walk payload:
  final List<MatchResult> preMatched; // len-0 obligations satisfied before k
  final List<int> preOblig;
  final List<MissingObligation> skipped;
  final MatchResult? match; // the len>0 match (null for completion hits)
  final int? matchOblig;
  final int? q; // position after applying
  // Rep-extend / reopen payload:
  final MatchResult? item;
  final _ReopenCand? reopen;
  // Retract payload:
  final _RetractCand? retract;
  final int? retractK; // items kept
  final List<MatchResult>? retractPost; // re-walked post matches
  // Rewind payload (frame children given back before the span):
  final int? rewind; // children kept
  final int? rewindPos; // position of the first given-back child
  _Hit(this.frameIndex, this.n,
      {this.preMatched = const [],
      this.preOblig = const [],
      this.skipped = const [],
      this.match,
      this.matchOblig,
      this.q,
      this.item,
      this.reopen,
      this.retract,
      this.retractK,
      this.retractPost,
      this.rewind,
      this.rewindPos});
}

// ---------------------------------------------------------------------------

class SkipRecovery {
  final Map<String, Clause> rules; // raw rules (may have '~' prefixes)
  final String topRuleName;
  final int? maxEvents;
  final bool debug;

  SkipRecovery(
      {required this.rules, required this.topRuleName, this.maxEvents, this.debug = false});

  late Parser _parser;
  late String _input;
  final List<_Frame> _stack = [];
  final List<SyntaxError> _spans = [];
  final List<MissingObligation> _missing = [];
  int _events = 0;
  bool _inEval = false;
  int _descendDepth = 0;
  final Set<(Clause, int)> _descendVisited = {};
  // Applied retract signatures (rep clause, rep start, items kept): a retract
  // is never applied twice, or a zero-cost retract could oscillate forever
  // with a reopen-extend re-adding the same items.
  final Set<(Clause, int, int)> _appliedRetracts = {};

  SkipResult recover(String input) {
    _input = input;
    _parser = Parser(rules: rules, topRuleName: topRuleName, input: input);
    _stack.clear();
    _spans.clear();
    _missing.clear();
    _events = 0;
    _inEval = false;
    _appliedRetracts.clear();

    final body = _parser.rules[topRuleName]!;
    _stack.add(_SeqFrame(null, [body, const _Eof()], 0));

    final cap = maxEvents ?? (4 * input.length + 64);
    var forced = false;
    var root = _continue();
    while (root == null) {
      if (_events >= cap) {
        root = _forceFinish();
        forced = true;
        break;
      }
      final fr = _stack.last as _SeqFrame;
      _descendDepth = 0;
      _descendVisited.clear();
      _descendFrom(fr);
      final (hit, hitScore) = _scan();
      if (debug) {
        // ignore: avoid_print
        print('CHOSEN fi=${hit.frameIndex} n=${hit.n} miss=${hit.skipped.length} '
            'rewind=${hit.rewind} retract=${hit.retractK} score=$hitScore');
      }
      _events++;
      _apply(hit);
      root = _continue();
    }
    return SkipResult(root, List.of(_spans), List.of(_missing), _events, forced);
  }

  // -- normal parsing over the frame stack ----------------------------------

  /// Continue matching from the current stack state. Returns the finished
  /// root, or null when a mismatch requires a recovery event (the descent
  /// frames for the failure have been pushed).
  MatchResult? _continue() {
    while (true) {
      final fr = _stack.last;
      if (fr is _SeqFrame) {
        var failed = false;
        while (fr.nextIndex < fr.obligations.length) {
          final ob = fr.obligations[fr.nextIndex];
          final r = _parser.match(ob, fr.curr);
          if (r.isMismatch) {
            // No descent here: the main loop ranks and pushes the descent
            // choices (evaluating the top two by scan score).
            failed = true;
            break;
          }
          fr.children.add(r);
          fr.childOblig.add(fr.nextIndex);
          fr.curr += r.len;
          fr.nextIndex++;
        }
        if (failed) return null;
        _stack.removeLast();
        final m = fr.seqClause == null
            ? Match(null, 0, 0, subClauseMatches: fr.children)
            : (fr.children.isEmpty
                ? Match(fr.seqClause, fr.startPos, 0)
                : Match(fr.seqClause, 0, 0, subClauseMatches: fr.children));
        if (_stack.isEmpty) return m; // wrapper finished
        _deliver(m);
      } else if (fr is _RepFrame) {
        while (fr.curr <= _input.length) {
          final r = _parser.match(fr.rep.subClause, fr.curr);
          if (r.isMismatch || r.len == 0) break;
          fr.children.add(r);
          fr.curr += r.len;
        }
        _stack.removeLast();
        final m = fr.children.isEmpty
            ? Match(fr.rep, fr.startPos, 0)
            : Match(fr.rep, 0, 0, subClauseMatches: fr.children);
        _deliver(m);
      } else {
        throw StateError('unexpected top frame ${fr.runtimeType}');
      }
    }
  }

  /// Deliver a completed match to the frame below, unwrapping/patching.
  void _deliver(MatchResult m) {
    var cur = m;
    while (true) {
      final fr = _stack.last;
      if (fr is _WrapFrame) {
        _stack.removeLast();
        cur = Match(fr.clause, 0, 0, subClauseMatches: [cur]);
      } else if (fr is _ReopenSlot) {
        _stack.removeLast();
        final rebuilt = fr.rebuild(cur);
        final parent = _stack.last as _SeqFrame;
        parent.children.length = fr.childIndex;
        parent.childOblig.length = fr.childIndex;
        parent.children.add(rebuilt);
        parent.childOblig.add(fr.obligIndex);
        parent.nextIndex = fr.obligIndex + 1;
        parent.curr = rebuilt.pos + rebuilt.len;
        return;
      } else if (fr is _SeqFrame) {
        fr.children.add(cur);
        fr.childOblig.add(fr.nextIndex);
        fr.curr += cur.len;
        fr.nextIndex++;
        return;
      } else if (fr is _RepFrame) {
        fr.children.add(cur);
        fr.curr += cur.len;
        return;
      }
    }
  }

  // -- descent: build the leading-edge spine --------------------------------

  void _descend(Clause clause, int pos) {
    var c = clause;
    var p = pos;
    while (true) {
      // Cycle guard (left recursion revisits the same clause at the same
      // position): stop the descent here; the frames built so far suffice.
      if (!_descendVisited.add((c, p))) return;
      if (c is Ref) {
        final body = _parser.rules[c.ruleName]!;
        if (!_parser.match(body, p).isMismatch) return; // LR oddity: leaf
        _stack.add(_WrapFrame(c));
        c = body;
        continue;
      }
      if (c is Seq) {
        var curr = p;
        final children = <MatchResult>[];
        var failIdx = -1;
        for (var i = 0; i < c.subClauses.length; i++) {
          final r = _parser.match(c.subClauses[i], curr);
          if (r.isMismatch) {
            failIdx = i;
            break;
          }
          children.add(r);
          curr += r.len;
        }
        if (failIdx < 0) return; // replay matched?! treat as leaf
        final fr = _SeqFrame(c, c.subClauses, p);
        fr.children.addAll(children);
        for (var i = 0; i < children.length; i++) {
          fr.childOblig.add(i);
        }
        fr.nextIndex = failIdx;
        fr.curr = curr;
        _stack.add(fr);
        _descendFrom(fr);
        return;
      }
      if (c is First) {
        // Rank alternatives by REAL progress first (budget-0 reach: how far
        // the alternative gets on genuine matches / prefix agreement alone),
        // budgeted reach second. Budgeted reach alone cannot rank: an
        // absorber (e.g. Character*) tunnels to the next anchor under one
        // budgeted skip, inflating WRONG alternatives (zero real progress)
        // above the true one, whose honest prefix progress is short - and
        // the wrong ones tie, so First order would decide. Progress is the
        // primary key; remaining ties are settled by consequences, like
        // _descendFrom's two-way eval: evaluate up to two members of the
        // top class plus the best of the next class by actual scan score.
        final scored = <(int prog, int reach, int idx, Clause alt)>[];
        for (var i = 0; i < c.subClauses.length; i++) {
          final alt = c.subClauses[i];
          final prog = _bestReach(alt, p, 0, {});
          final fp = _bestReach(alt, p, 2, {});
          if (debug) {
            // ignore: avoid_print
            print('  First@$p alt $alt -> prog $prog reach $fp');
          }
          scored.add((prog, fp, i, alt));
        }
        if (scored.isEmpty) return;
        scored.sort((a, b) => b.$1 != a.$1
            ? b.$1.compareTo(a.$1)
            : b.$2 != a.$2
                ? b.$2.compareTo(a.$2)
                : a.$3.compareTo(b.$3));
        var best = scored.first.$4;
        final topProg = scored.first.$1;
        final topReach = scored.first.$2;
        if (!_inEval &&
            scored.length > 1 &&
            scored[1].$1 == topProg &&
            scored[1].$2 == topReach) {
          final cands = <Clause>[];
          for (final s in scored) {
            if (s.$1 == topProg && s.$2 == topReach && cands.length < 2) {
              cands.add(s.$4);
            }
            if ((s.$1 != topProg || s.$2 != topReach) && (s.$1 > p || s.$2 > p)) {
              cands.add(s.$4);
              break;
            }
          }
          if (cands.length > 1) {
            final base = _stack.length;
            final savedDepth = _descendDepth;
            var bestScore = 0;
            var haveBest = false;
            _inEval = true;
            for (final alt in cands) {
              final savedVisited = Set.of(_descendVisited);
              _stack.add(_WrapFrame(c));
              _descend(alt, p);
              final (_, score) = _scan();
              if (debug) {
                // ignore: avoid_print
                print('  First@$p EVAL $alt -> score $score');
              }
              _stack.length = base;
              _descendDepth = savedDepth;
              _descendVisited
                ..clear()
                ..addAll(savedVisited);
              if (!haveBest || score > bestScore) {
                haveBest = true;
                bestScore = score;
                best = alt;
              }
            }
            _inEval = false;
          }
        }
        _stack.add(_WrapFrame(c));
        c = best;
        continue;
      }
      if (c is Repetition) {
        // A failing Repetition is a OneOrMore with zero items.
        _stack.add(_RepFrame(c, p, const [], p));
        c = c.subClause;
        continue;
      }
      if (c is Str && c.text.length > 1) {
        // The (J-j) Seq rule applied inside a multi-char literal: a Str is a
        // Seq of single chars, so a corrupted keyword ("tQue" for "true")
        // can be resumed mid-token instead of becoming opaque garbage.
        final chars = <Clause>[for (var i = 0; i < c.text.length; i++) Char(c.text[i])];
        var curr = p;
        var failIdx = -1;
        final children = <MatchResult>[];
        for (var i = 0; i < chars.length; i++) {
          final r = _parser.match(chars[i], curr);
          if (r.isMismatch) {
            failIdx = i;
            break;
          }
          children.add(r);
          curr += r.len;
        }
        if (failIdx <= 0) return; // no matched prefix: plain leaf
        final fr = _SeqFrame(c, chars, p);
        fr.children.addAll(children);
        for (var i = 0; i < children.length; i++) {
          fr.childOblig.add(i);
        }
        fr.nextIndex = failIdx;
        fr.curr = curr;
        _stack.add(fr);
        _descendFrom(fr);
        return;
      }
      // Terminal, lookahead, Optional: leaf.
      return;
    }
  }

  /// A frame's obligation at nextIndex just failed: rank the descent
  /// choices, and when the ranking is ambiguous (>= 2 choices), evaluate the
  /// top two by their actual best scan score - a bounded two-way lookahead -
  /// because the reach metric has no char-skip model and saturates on
  /// tunnels of real matches, so it cannot rank reliably on its own.
  /// Evaluation descents don't re-evaluate nested choices (_inEval), keeping
  /// the work linear: one two-way branch per ambiguous level.
  void _descendFrom(_SeqFrame fr) {
    _descendDepth++;
    if (_descendDepth > 64 || _stack.length > 300) {
      _descend(fr.obligations[fr.nextIndex], fr.curr); // runaway guard
      return;
    }
    final choices = _rankedChoices(fr);
    if (_inEval || choices.length == 1) {
      _pushChoice(fr, choices.first);
      return;
    }
    final base = _stack.length;
    final savedDepth = _descendDepth;
    var bestCi = 0;
    var bestScore = 0;
    var haveBest = false;
    _inEval = true;
    for (var ci = 0; ci < 2; ci++) {
      final savedVisited = Set.of(_descendVisited);
      _pushChoice(fr, choices[ci]);
      final (_, score) = _scan();
      _stack.length = base;
      _descendDepth = savedDepth;
      _descendVisited
        ..clear()
        ..addAll(savedVisited);
      if (!haveBest || score > bestScore) {
        haveBest = true;
        bestScore = score;
        bestCi = ci;
      }
    }
    _inEval = false;
    _pushChoice(fr, choices[bestCi]);
  }

  /// Rank descent choices for a failing frame: the failing obligation itself
  /// (cand == null), reopenable points inside matched tail children, and
  /// First re-choices. Sorted by reach (desc); conservative choices
  /// (obligation, then reopens) win ties over speculative re-choices.
  List<_ReopenCand?> _rankedChoices(_SeqFrame fr) {
    final ob = fr.obligations[fr.nextIndex];
    final curr = fr.curr;
    final scored = <(int reach, int rank, _ReopenCand? cand)>[
      (_bestReach(ob, curr, 2, {}), 0, null),
    ];
    for (final cand in _reopenCands(fr)) {
      if (cand.alt != null) {
        // A re-choice replaces a SUCCESSFUL parse, so demand the alternative
        // be near-clean (budget 1): with the full budget, speculative
        // re-choices tunnel past real matches ("1,5" re-read as an Array
        // after skipping '[') and outrank the true failure's fix.
        final reach = _bestReach(cand.alt!, cand.altStart, 1, {});
        if (reach <= curr) continue; // no better than the current choice
        scored.add((reach, 2, cand));
      } else {
        scored.add((_bestReach(cand.itemClause, curr, 2, {}), 1, cand));
      }
    }
    scored.sort((a, b) => b.$1 != a.$1 ? b.$1.compareTo(a.$1) : a.$2.compareTo(b.$2));
    return [for (final s in scored) s.$3];
  }

  /// Push the descent frames for one ranked choice.
  void _pushChoice(_SeqFrame fr, _ReopenCand? choice) {
    final curr = fr.curr;
    final ro = choice;
    if (ro == null) {
      _descend(fr.obligations[fr.nextIndex], curr);
      return;
    }
    if (ro.alt != null) {
      final first = ro.firstClause!;
      _stack.add(_ReopenSlot(ro.childIndex, ro.obligIndex,
          (m) => ro.wrapChain(Match(first, 0, 0, subClauseMatches: [m]))));
      _descend(ro.alt!, ro.altStart);
    } else if (ro.rep != null) {
      _stack.add(_ReopenSlot(ro.childIndex, ro.obligIndex, ro.wrapChain));
      _stack.add(_RepFrame(ro.rep!, ro.repStart, ro.repItems, curr, reopened: true));
      _descend(ro.rep!.subClause, curr);
    } else {
      final opt = ro.optClause!;
      _stack.add(_ReopenSlot(ro.childIndex, ro.obligIndex,
          (m) => ro.wrapChain(Match(opt, 0, 0, subClauseMatches: [m]))));
      _descend(opt.subClause, curr);
    }
    // If the descent produced no frames above a slot, drop the bare slot.
    if (_stack.last is _ReopenSlot) _stack.removeLast();
  }

  /// How far could [c] starting at [p] plausibly reach if at most [budget]
  /// mismatching obligations may be skipped (input characters may not)? A
  /// matched composite is also entered ("deepened"): its plain match may
  /// stop short of what a recovered continuation inside it could reach.
  /// The budget is what keeps this discriminating: a genuine nearby fix
  /// needs one or two skips, while tunneling through arbitrary text needs
  /// many. Used to rank descent choices; approximate (the budget is not
  /// threaded back out of deepened subtrees) but memoized-cheap.
  int _bestReach(Clause c, int p, int budget, Set<(Clause, int)> visited) {
    if (p > _input.length) return p;
    if (!visited.add((c, p))) return p;
    var best = p;
    final r = _parser.match(c, p);
    if (!r.isMismatch) best = p + r.len;
    if (c is Ref) {
      final inner = _bestReach(_parser.rules[c.ruleName]!, p, budget, visited);
      return inner > best ? inner : best;
    }
    if (c is Seq) {
      // The walk position q advances along REAL matches only; a "deepened"
      // reach (hypothetical recovery inside a sub-clause) forks off into
      // [best] and terminates there - it must never advance q, or later
      // obligations would be evaluated at an imaginary position. A bounded
      // char-skip (the obligation matches a little further on) DOES yield a
      // real position, so it may advance q.
      var q = p;
      var left = budget;
      for (final sub in c.subClauses) {
        final rs = _parser.match(sub, q);
        if (rs.isMismatch) {
          // Deepening into the mismatched sub-clause is free: the error is
          // the SAME error, localized deeper (it pays where it bottoms out).
          // Only skipping PAST the obligation on the walk costs budget -
          // charging both made a shallow wrong branch (1 skip) outrank the
          // true error buried 3 levels down (3 charges for one error).
          final deeper = _bestReach(sub, q, left, visited);
          if (deeper > best) best = deeper;
          if (left == 0) break;
          left--;
          // (obligation skipped, continue the real walk at q)
        } else {
          final deeper = _bestReach(sub, q, left, visited);
          if (deeper > best) best = deeper;
          q += rs.len;
        }
        if (q > best) best = q;
      }
      return best;
    }
    if (c is First) {
      for (final alt in c.subClauses) {
        final reach = _bestReach(alt, p, budget, visited);
        if (reach > best) best = reach;
      }
      return best;
    }
    if (c is Repetition) {
      var q = p;
      while (q <= _input.length) {
        final rs = _parser.match(c.subClause, q);
        if (rs.isMismatch || rs.len == 0) break;
        q += rs.len;
      }
      final reach = _bestReach(c.subClause, q, budget, visited);
      if (reach > q) q = reach;
      return q > best ? q : best;
    }
    if (c is Optional) {
      final inner = _bestReach(c.subClause, p, budget, visited);
      return inner > best ? inner : best;
    }
    if (c is Str && c.text.length > 1) {
      // Partial-prefix reach: how far into the literal does the input agree?
      var i = 0;
      while (i < c.text.length &&
          p + i < _input.length &&
          _input.codeUnitAt(p + i) == c.text.codeUnitAt(i)) {
        i++;
      }
      if (p + i > best) best = p + i;
      return best;
    }
    return best; // terminal / lookahead
  }

  /// Test hook: evaluate the reach metric on [input] without recovering.
  int debugReach(String input, Clause c, int p, int budget) {
    _input = input;
    _parser = Parser(rules: rules, topRuleName: topRuleName, input: input);
    return _bestReach(c, p, budget, {});
  }

  // -- reopen collection ----------------------------------------------------

  /// Reopenable points in the matched tail children of [fr] (children whose
  /// right edge sits exactly at fr.curr, not separated by a span).
  List<_ReopenCand> _reopenCands(_SeqFrame fr) {
    final out = <_ReopenCand>[];
    for (var i = fr.children.length - 1; i >= 0; i--) {
      final child = fr.children[i];
      if (fr.childOblig[i] < 0) break; // a span: nothing contiguous beyond
      if (child.pos + child.len != fr.curr) break;
      _collectReopens(child, fr.curr, (m) => m, i, fr.childOblig[i], out);
    }
    return out;
  }

  void _collectReopens(MatchResult m, int atPos, MatchResult Function(MatchResult) wrap,
      int childIndex, int obligIndex, List<_ReopenCand> out) {
    if (m.pos + m.len != atPos) return;
    final clause = m.clause;
    if (clause == null || clause is NotFollowedBy || clause is FollowedBy) return;
    if (clause is Repetition) {
      // Deeper reopens inside the last item first.
      final items = m.subClauseMatches;
      if (items.isNotEmpty) {
        _collectReopens(items.last, atPos, (nc) {
          final nl = List.of(items);
          nl[nl.length - 1] = nc;
          return wrap(Match(clause, 0, 0, subClauseMatches: nl));
        }, childIndex, obligIndex, out);
      }
      out.add(_ReopenCand(
          childIndex: childIndex,
          obligIndex: obligIndex,
          wrapChain: wrap,
          rep: clause,
          repStart: m.pos,
          repItems: List.of(items)));
      return;
    }
    if (clause is Optional) {
      if (m.subClauseMatches.isEmpty) {
        out.add(_ReopenCand(
            childIndex: childIndex, obligIndex: obligIndex, wrapChain: wrap, optClause: clause));
        return;
      }
      _collectReopens(m.subClauseMatches.first, atPos,
          (nc) => wrap(Match(clause, 0, 0, subClauseMatches: [nc])), childIndex, obligIndex, out);
      return;
    }
    if (clause is First) {
      if (m.subClauseMatches.length == 1) {
        _collectReopens(m.subClauseMatches.first, atPos,
            (nc) => wrap(Match(clause, 0, 0, subClauseMatches: [nc])), childIndex, obligIndex, out);
        // Re-choice: a different alternative, re-attempted (with recovery)
        // from this choice point's start. Only mismatching alternatives: a
        // plain-matching one was legitimately rejected by ordered choice.
        final chosen = m.subClauseMatches.first.clause;
        for (final alt in clause.subClauses) {
          if (identical(alt, chosen)) continue;
          if (!_parser.match(alt, m.pos).isMismatch) continue;
          out.add(_ReopenCand(
              childIndex: childIndex,
              obligIndex: obligIndex,
              wrapChain: wrap,
              firstClause: clause,
              alt: alt,
              altStart: m.pos));
        }
      }
      return;
    }
    if (clause is Ref) {
      if (m.subClauseMatches.length == 1) {
        _collectReopens(m.subClauseMatches.first, atPos,
            (nc) => wrap(Match(clause, 0, 0, subClauseMatches: [nc])), childIndex, obligIndex, out);
      }
      return;
    }
    if (clause is Seq) {
      final children = m.subClauseMatches;
      for (var i = children.length - 1; i >= 0; i--) {
        if (children[i].pos + children[i].len != atPos) break;
        _collectReopens(children[i], atPos, (nc) {
          final nl = List.of(children);
          nl[i] = nc;
          // Trailing len-0 siblings after i are dropped; they carry no
          // content and would be out of position after the reopen.
          return wrap(Match(clause, 0, 0, subClauseMatches: nl.sublist(0, i + 1)));
        }, childIndex, obligIndex, out);
      }
      return;
    }
    // Terminal: nothing.
  }

  // -- retract collection ---------------------------------------------------

  /// Retractable repetitions inside the matched tail children of [fr].
  List<_RetractCand> _retractCands(_SeqFrame fr) {
    final out = <_RetractCand>[];
    for (var i = fr.children.length - 1; i >= 0; i--) {
      final child = fr.children[i];
      if (fr.childOblig[i] < 0) break; // a span: nothing contiguous beyond
      if (child.pos + child.len != fr.curr) break;
      _collectRetracts(child, (m) => m, i, fr.childOblig[i], out, 0);
    }
    return out;
  }

  /// Walk the rightmost spine of [m] looking for greedy repetitions whose
  /// trailing items could be given back. Only the innermost enclosing Seq's
  /// following subclauses become re-walk obligations; outer levels are
  /// entered through their trailing content child only (trailing len-0
  /// siblings are dropped, as in _collectReopens).
  void _collectRetracts(MatchResult m, MatchResult Function(MatchResult) wrap,
      int childIndex, int obligIndex, List<_RetractCand> out, int depth) {
    if (depth > 32) return;
    final clause = m.clause;
    if (clause == null || clause is NotFollowedBy || clause is FollowedBy) return;
    if (clause is Ref || clause is First || clause is Optional) {
      if (m.subClauseMatches.length == 1) {
        _collectRetracts(
            m.subClauseMatches.first,
            (nc) => wrap(Match(clause, 0, 0, subClauseMatches: [nc])),
            childIndex,
            obligIndex,
            out,
            depth + 1);
      }
      return;
    }
    if (clause is Repetition) {
      // A repetition that IS the frame child (no enclosing Seq level here):
      // giving back items returns characters directly to the frame.
      final items = m.subClauseMatches;
      if (items.isNotEmpty) {
        out.add(_RetractCand(
            childIndex: childIndex,
            obligIndex: obligIndex,
            rep: clause,
            repStart: m.pos,
            repItems: List.of(items),
            post: const [],
            rebuild: (tail) => wrap(tail.first)));
      }
      return;
    }
    if (clause is Seq) {
      final children = m.subClauseMatches;
      // Any child that is (through single-child wrappers) a repetition with
      // items: candidate with post = the Seq's subclauses after it. Only for
      // pristine matches (one child per subclause): a synthetic match from an
      // earlier recovery may contain spans, misaligning children/subclauses.
      final aligned = children.length == clause.subClauses.length;
      for (var i = 0; aligned && i < children.length; i++) {
        var node = children[i];
        MatchResult Function(MatchResult) w = (x) => x;
        while (true) {
          final nc = node.clause;
          if ((nc is Ref || nc is First || nc is Optional) &&
              node.subClauseMatches.length == 1) {
            final capC = nc;
            final capW = w;
            w = (x) => capW(Match(capC, 0, 0, subClauseMatches: [x]));
            node = node.subClauseMatches.first;
            continue;
          }
          break;
        }
        final nodeClause = node.clause;
        if (nodeClause is Repetition && node.subClauseMatches.isNotEmpty) {
          final pre = children.sublist(0, i);
          final capW = w;
          out.add(_RetractCand(
              childIndex: childIndex,
              obligIndex: obligIndex,
              rep: nodeClause,
              repStart: node.pos,
              repItems: List.of(node.subClauseMatches),
              post: clause.subClauses.sublist(i + 1),
              rebuild: (tail) => wrap(Match(clause, 0, 0,
                  subClauseMatches: [...pre, capW(tail.first), ...tail.sublist(1)]))));
        }
      }
      // Spine recursion into the trailing content child (skip len-0 tails).
      for (var i = children.length - 1; i >= 0; i--) {
        if (children[i].len == 0) continue;
        final keep = children.sublist(0, i);
        _collectRetracts(children[i], (nc) {
          return wrap(Match(clause, 0, 0, subClauseMatches: [...keep, nc]));
        }, childIndex, obligIndex, out, depth + 1);
        break;
      }
      return;
    }
    // Terminal: nothing.
  }

  // -- scanning for a resumption --------------------------------------------

  /// Enumerate candidate resumptions and pick the one maximizing
  /// (aftermath - cost), where cost = skipped chars + skipped obligations
  /// and aftermath = how far pure (recovery-free) parsing continues after
  /// applying the hit. This makes the choice consequence-aware: a cheap
  /// resumption that strands the rest of the input loses to a slightly
  /// costlier one after which parsing flows on. Ties: lower cost, then
  /// deeper frame, then smaller skip.
  (_Hit, int) _scan() {
    final reopens = <int, List<_ReopenCand>>{};
    final retracts = <int, List<_RetractCand>>{};
    for (var fi = 0; fi < _stack.length; fi++) {
      final fr = _stack[fi];
      if (fr is _SeqFrame) {
        reopens[fi] = _reopenCands(fr);
        retracts[fi] = _retractCands(fr);
      }
    }
    if (debug) {
      // ignore: avoid_print
      print('--- scan; stack:');
      for (var fi = 0; fi < _stack.length; fi++) {
        final fr = _stack[fi];
        // ignore: avoid_print
        print('  [$fi] ${fr is _SeqFrame ? 'Seq(${fr.seqClause}) next=${fr.nextIndex} curr=${fr.curr}' : fr is _RepFrame ? 'Rep(${fr.rep}) curr=${fr.curr}' : fr is _WrapFrame ? 'Wrap(${fr.clause.runtimeType})' : 'Slot'}');
      }
    }
    _Hit? best;
    var bestScore = 0;
    var bestCost = 0;
    void consider(_Hit hit, int cost) {
      final score = _aftermath(hit) - cost;
      if (debug && score > 0) {
        // ignore: avoid_print
        print('  hit fi=${hit.frameIndex} n=${hit.n} miss=${hit.skipped.length} '
            '${hit.retract != null ? 'retract(k=${hit.retractK})' : hit.reopen != null ? 'reopen' : hit.item != null ? 'extend' : hit.match != null ? 'real(${hit.match!.clause})' : 'completion'} cost=$cost score=$score');
      }
      if (best == null ||
          score > bestScore ||
          (score == bestScore &&
              (cost < bestCost ||
                  (cost == bestCost &&
                      (hit.frameIndex > best!.frameIndex ||
                          (hit.frameIndex == best!.frameIndex && hit.n < best!.n)))))) {
        best = hit;
        bestScore = score;
        bestCost = cost;
      }
    }

    for (var fi = _stack.length - 1; fi >= 0; fi--) {
      final fr = _stack[fi];
      if (fr is _SeqFrame) {
        final maxN = _input.length - fr.curr;
        for (var n = 0; n <= maxN; n++) {
          for (final hit in _kwalk(fr, fi, n)) {
            consider(hit, n + hit.skipped.length);
          }
          // Rewind probes: give back trailing MATCHED children and place the
          // span BEFORE them (the skip rule applied before an already-matched
          // subclause): a bogus prefix can make a subclause match short but
          // successfully, leaving no failing frame at the real error.
          if (n >= 1) {
            var backed = 0;
            for (var keep = fr.children.length - 1;
                keep >= 0 && backed < 3 && fr.childOblig[keep] >= 0;
                keep--) {
              if (fr.children[keep].len == 0) continue;
              backed++;
              if (fr.children[keep].pos + n > _input.length) continue;
              for (final hit in _kwalk(fr, fi, n, rewind: keep)) {
                consider(hit, n + hit.skipped.length);
              }
            }
          }
          if (n >= 1) {
            for (final cand in reopens[fi]!) {
              if (cand.alt != null) continue; // re-choice: descent only
              final item = _parser.match(cand.itemClause, fr.curr + n);
              if (!item.isMismatch && item.len > 0) {
                consider(
                    _Hit(fi, n, item: item, reopen: cand, q: fr.curr + n + item.len), n);
              }
            }
          }
        }
        // Retract probes: give back trailing repetition items, re-walk the
        // enclosing Seq's remaining obligations from the truncation point
        // (missing allowed, no char skip), and let aftermath decide.
        for (final cand in retracts[fi]!) {
          final items = cand.repItems;
          final minK = cand.rep.requireOne ? 1 : 0;
          for (var k = items.length - 1; k >= minK; k--) {
            if (_appliedRetracts.contains((cand.rep, cand.repStart, k))) continue;
            final t = k == 0 ? cand.repStart : items[k - 1].pos + items[k - 1].len;
            var q = t;
            final post = <MatchResult>[];
            final missing = <MissingObligation>[];
            for (final ob in cand.post) {
              final r = _parser.match(ob, q);
              if (r.isMismatch) {
                missing.add(MissingObligation(ob, q));
                continue;
              }
              post.add(r);
              q += r.len;
            }
            // No-op guard: same end, nothing missing = same state, would loop.
            if (missing.isEmpty && q == fr.curr) continue;
            // Cost = missing obligations only: the given-back characters are
            // re-parsed by the post walk / enclosing frames, not reported as
            // errors, so they carry no cost (consistent with kwalk's
            // n + missing model, with n = 0 error chars here).
            consider(
                _Hit(fi, fr.curr - t, // "n" = chars given back (tie-break only)
                    skipped: missing,
                    retract: cand,
                    retractK: k,
                    retractPost: post,
                    q: q),
                missing.length);
          }
        }
      } else if (fr is _RepFrame) {
        final maxN = _input.length - fr.curr;
        for (var n = 1; n <= maxN; n++) {
          final item = _parser.match(fr.rep.subClause, fr.curr + n);
          if (!item.isMismatch && item.len > 0) {
            consider(_Hit(fi, n, item: item, q: fr.curr + n + item.len), n);
          }
        }
        // Close a failed OneOrMore empty ("missing item") - but never a
        // reopened rep that hasn't extended: rebuilding the identical child
        // is a no-op that loops forever while accumulating junk missing.
        if (!fr.reopened || fr.children.length > fr.seedLen) {
          consider(
              _Hit(fi, 0, skipped: [MissingObligation(fr.rep.subClause, fr.curr)], q: fr.curr), 1);
        }
      }
    }
    if (best == null) throw StateError('no resumption found (should be impossible)');
    return (best!, bestScore);
  }

  /// The (at most two) k-walk hits for frame [fr] with a skip of [n]: the
  /// "real" hit that resumes at the first len>0 obligation match (skipping
  /// mismatching obligations as missing), and/or the "completion" hit that
  /// discharges all remaining obligations.
  List<_Hit> _kwalk(_SeqFrame fr, int fi, int n, {int? rewind}) {
    final startOblig = rewind == null ? fr.nextIndex : fr.childOblig[rewind];
    final startPos = rewind == null ? fr.curr : fr.children[rewind].pos;
    final q0 = startPos + n;
    if (q0 > _input.length) return const [];
    var q = q0;
    final pre = <MatchResult>[];
    final preOb = <int>[];
    final skipped = <MissingObligation>[];
    for (var j = startOblig; j < fr.obligations.length; j++) {
      final ob = fr.obligations[j];
      final r = _parser.match(ob, q);
      if (r.isMismatch) {
        if (ob is _Eof) return const []; // never skip EOF as missing
        skipped.add(MissingObligation(ob, q));
        continue;
      }
      if (r.len > 0) {
        if (n == 0 && skipped.isEmpty) return const []; // nothing was wrong
        return [
          _Hit(fi, n,
              preMatched: pre,
              preOblig: preOb,
              skipped: skipped,
              match: r,
              matchOblig: j,
              q: q + r.len,
              rewind: rewind,
              rewindPos: rewind == null ? null : startPos)
        ];
      }
      pre.add(r);
      preOb.add(j);
      q += r.len;
    }
    // Completion: all remaining obligations consumed (len-0 or missing).
    if (n == 0 && skipped.isEmpty) return const [];
    if (fr.seqClause != null && startPos == fr.startPos) return const [];
    return [
      _Hit(fi, n,
          preMatched: pre,
          preOblig: preOb,
          skipped: skipped,
          q: q,
          rewind: rewind,
          rewindPos: rewind == null ? null : startPos)
    ];
  }

  /// Simulate pure (recovery-free) continuation after applying [hit],
  /// without mutating any frame: how far does parsing get before the next
  /// mismatch? Reaching input.length means the whole parse completes.
  int _aftermath(_Hit hit) {
    var pos = hit.q!;
    int? resumeOblig; // override for the next _SeqFrame below
    for (var level = hit.frameIndex; level >= 0; level--) {
      final fr = _stack[level];
      if (fr is _WrapFrame) continue;
      if (fr is _ReopenSlot) {
        resumeOblig = fr.obligIndex + 1;
        continue;
      }
      if (fr is _SeqFrame) {
        int startIdx;
        if (level == hit.frameIndex) {
          startIdx = hit.reopen != null
              ? hit.reopen!.obligIndex + 1
              : hit.retract != null
                  ? hit.retract!.obligIndex + 1
                  : (hit.match != null ? hit.matchOblig! + 1 : fr.obligations.length);
        } else {
          startIdx = (resumeOblig ?? fr.nextIndex) + (resumeOblig == null ? 1 : 0);
        }
        resumeOblig = null;
        for (var j = startIdx; j < fr.obligations.length; j++) {
          final r = _parser.match(fr.obligations[j], pos);
          if (r.isMismatch) return pos;
          pos += r.len;
        }
      } else if (fr is _RepFrame) {
        while (pos <= _input.length) {
          final r = _parser.match(fr.rep.subClause, pos);
          if (r.isMismatch || r.len == 0) break;
          pos += r.len;
        }
      }
    }
    return pos;
  }

  void _apply(_Hit hit) {
    _stack.length = hit.frameIndex + 1;
    final fr = _stack[hit.frameIndex];
    if (hit.retract != null) {
      final seq = fr as _SeqFrame;
      final cand = hit.retract!;
      _appliedRetracts.add((cand.rep, cand.repStart, hit.retractK!));
      final keep = cand.repItems.sublist(0, hit.retractK!);
      final repM = keep.isEmpty
          ? Match(cand.rep, cand.repStart, 0)
          : Match(cand.rep, 0, 0, subClauseMatches: keep);
      final child = cand.rebuild([repM, ...hit.retractPost!]);
      seq.children.length = cand.childIndex;
      seq.childOblig.length = cand.childIndex;
      seq.children.add(child);
      seq.childOblig.add(cand.obligIndex);
      seq.nextIndex = cand.obligIndex + 1;
      seq.curr = child.pos + child.len;
      _missing.addAll(hit.skipped);
      return;
    }
    if (hit.reopen != null) {
      final seq = fr as _SeqFrame;
      final cand = hit.reopen!;
      final extras = <MatchResult>[];
      if (hit.n > 0) {
        final span = SyntaxError(pos: seq.curr, len: hit.n);
        extras.add(span);
        _spans.add(span);
      }
      extras.add(hit.item!);
      final child = cand.buildChild(extras);
      seq.children.length = cand.childIndex;
      seq.childOblig.length = cand.childIndex;
      seq.children.add(child);
      seq.childOblig.add(cand.obligIndex);
      seq.nextIndex = cand.obligIndex + 1;
      seq.curr = child.pos + child.len;
      return;
    }
    if (fr is _RepFrame) {
      if (hit.item != null) {
        if (hit.n > 0) {
          final span = SyntaxError(pos: fr.curr, len: hit.n);
          fr.children.add(span);
          _spans.add(span);
        }
        fr.children.add(hit.item!);
        fr.curr = fr.curr + hit.n + hit.item!.len;
      } else {
        _missing.addAll(hit.skipped); // close-empty; _continue finishes it
      }
      return;
    }
    final seq = fr as _SeqFrame;
    if (hit.rewind != null) {
      seq.children.length = hit.rewind!;
      seq.childOblig.length = hit.rewind!;
      seq.curr = hit.rewindPos!;
    }
    if (hit.n > 0) {
      final span = SyntaxError(pos: seq.curr, len: hit.n);
      seq.children.add(span);
      seq.childOblig.add(-1);
      _spans.add(span);
    }
    for (var i = 0; i < hit.preMatched.length; i++) {
      seq.children.add(hit.preMatched[i]);
      seq.childOblig.add(hit.preOblig[i]);
    }
    _missing.addAll(hit.skipped);
    if (hit.match != null) {
      seq.children.add(hit.match!);
      seq.childOblig.add(hit.matchOblig!);
      seq.nextIndex = hit.matchOblig! + 1;
    } else {
      seq.nextIndex = seq.obligations.length;
    }
    seq.curr = hit.q!;
  }

  MatchResult _forceFinish() {
    // Emergency: wrap everything not yet consumed at the wrapper level.
    final wrapper = _stack.first as _SeqFrame;
    final consumed = wrapper.children.isEmpty
        ? 0
        : wrapper.children.last.pos + wrapper.children.last.len;
    if (consumed < _input.length) {
      final span = SyntaxError(pos: consumed, len: _input.length - consumed);
      wrapper.children.add(span);
      _spans.add(span);
    }
    return Match(null, 0, 0, subClauseMatches: wrapper.children);
  }
}
