// Frontier-unified error recovery (ERROR_RECOVERY_DESIGN.md Sec. 13):
// cost-ordered search over (input position, residual spine) states.
//
//   Parse greedily; when stuck, be GLR locally; charge only for skipped
//   chars and skipped obligations; expand cheapest-then-furthest first.
//
// One priority queue on (cost asc, reach desc, age asc) replaces the skip
// driver's heuristic subsystems (aftermath scoring, two-way/k-way eval,
// conservative-first ranks, re-choice budget gates, applied-once
// signatures):
//   - SNAKE (free): drive the spine with the pure memoized oracle until a
//     mismatch - the Myers-diff diagonal run. States are always post-snake.
//   - EDITS (cost 1 each, the only costed moves): skip one input char
//     (span; a macro edge jumps to the next match of the pending
//     obligation), or skip the pending obligation (missing).
//   - EXPANSION (free): open the failing obligation one level (Seq/Str ->
//     frame at j=0, Ref/Optional -> wrap, First -> one successor PER
//     alternative). This replaces the descent machinery: branch points are
//     enqueued, not ranked; real progress after the snake orders them.
//   - CUTS (free): un-commit matched material - give back trailing
//     children of any frame, or of any nested match within a locality
//     window, reconstructing the frames; a Repetition child can be
//     truncated open (extend/span inside) or closed short (retract).
//     Every reopen/retract/rewind/re-choice of the skip driver is a cut,
//     and a cut state that stalls gets its own edits and cuts - recursive
//     re-descend flattened into the queue.
//   - DEDUP: closed set on (pos, spine hash); the greedy re-derivations
//     that cuts and expansions produce die here.
//   - COMMIT (event boundary): the first popped state that is complete, or
//     whose snake ran stableK chars past its last change with the frontier
//     strictly advanced, is adopted; the queue is discarded and the next
//     event starts from its stall. Multi-error stays linear.
//
// The parser stays a pure oracle: only Parser.match(clause, pos) against
// the untouched input; all synthetic stitching happens driver-side.

import '../parser/clause.dart';
import '../parser/combinators.dart';
import '../parser/match_result.dart';
import '../parser/parser.dart';
import '../parser/terminals.dart';
import 'skip_recovery.dart' show SkipResult, MissingObligation;

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

// ---------------------------------------------------------------------------
// Frames (copied per successor; _FWrap is immutable and shared)

sealed class _F {
  _F copyF();
  int get sig;
}

class _FSeq extends _F {
  final Clause? clause; // null = driver wrapper
  final List<Clause> obligations;
  final int startPos;
  final List<MatchResult> children;
  final List<int> childOblig; // parallel; -1 for spans
  int j; // next obligation
  int curr;
  _FSeq(this.clause, this.obligations, this.startPos, this.children, this.childOblig, this.j,
      this.curr);
  @override
  _FSeq copyF() =>
      _FSeq(clause, obligations, startPos, List.of(children), List.of(childOblig), j, curr);
  @override
  int get sig => Object.hash(1, identityHashCode(clause), startPos, j, curr, children.length);
}

class _FRep extends _F {
  final Repetition rep;
  final int startPos;
  final List<MatchResult> items;
  int curr;
  _FRep(this.rep, this.startPos, this.items, this.curr);
  @override
  _FRep copyF() => _FRep(rep, startPos, List.of(items), curr);
  @override
  int get sig => Object.hash(2, identityHashCode(rep), startPos, items.length, curr);
}

class _FWrap extends _F {
  final Clause clause;
  final int startPos;
  _FWrap(this.clause, this.startPos);
  @override
  _FWrap copyF() => this;
  @override
  int get sig => Object.hash(3, identityHashCode(clause), startPos);
}

// ---------------------------------------------------------------------------

class _St {
  final List<_F> spine; // frozen; empty iff done != null
  final int pos;
  final int cost;
  final int lastChange; // input position of the last edit/cut
  final bool changed; // any move applied since the event started
  final int cuts; // cut moves along this path (budgeted)
  final List<SyntaxError> spans;
  final List<MissingObligation> missing;
  final MatchResult? done;
  final int age;
  final int spanChars;
  final int editMin; // per-event edit-position extent (compactness)
  final int editMax;
  _St(this.spine, this.pos, this.cost, this.lastChange, this.changed, this.cuts, this.spans,
      this.missing, this.done, this.age, this.editMin, this.editMax)
      : spanChars = spans.fold(0, (a, e) => a + e.len);

  // Whole-event edit diameter. A clustered variant (per-damage-point
  // compactness, gap 8) was tried and REVERTED: it exempts exactly the
  // spread absorber exploits the diameter exists to kill (sweep 466 -> 407),
  // and the genuinely degenerate equal-cost multi-error pairs it aimed at
  // are indistinguishable at every clustering granularity - separating them
  // needs anchor-role priors, not geometry.
  int get diameter => editMax >= editMin ? editMax - editMin : 0;

  int get spineSig {
    var h = 17;
    for (final f in spine) {
      h = h * 31 + f.sig;
    }
    return h;
  }
}

class _Heap {
  final List<_St> a = [];
  bool get isNotEmpty => a.isNotEmpty;
  int get length => a.length;

  static int _cmp(_St x, _St y) {
    if (x.cost != y.cost) return x.cost - y.cost;
    // Within a cost level: compact repairs first (single-point damage means
    // a point repair; a spread same-cost repair is an absorber exploit -
    // measured: two fabricated '\' missings 14 chars apart turned the real
    // closing quotes into content and swallowed the array at cost 2). Then
    // fewer span chars (prefer explaining input as structure over erasing
    // it), then furthest reach. All keys are monotone along paths, so the
    // compound ordering keeps the Dijkstra first-pop-optimal property.
    final xd = x.diameter, yd = y.diameter;
    if (xd != yd) return xd - yd;
    if (x.spanChars != y.spanChars) return x.spanChars - y.spanChars;
    if (x.pos != y.pos) return y.pos - x.pos; // furthest reach first
    return x.age - y.age;
  }

  void add(_St s) {
    a.add(s);
    var i = a.length - 1;
    while (i > 0) {
      final p = (i - 1) >> 1;
      if (_cmp(a[i], a[p]) >= 0) break;
      final t = a[i];
      a[i] = a[p];
      a[p] = t;
      i = p;
    }
  }

  _St removeMin() {
    final top = a.first;
    final last = a.removeLast();
    if (a.isNotEmpty) {
      a[0] = last;
      var i = 0;
      while (true) {
        final l = 2 * i + 1, r = 2 * i + 2;
        var m = i;
        if (l < a.length && _cmp(a[l], a[m]) < 0) m = l;
        if (r < a.length && _cmp(a[r], a[m]) < 0) m = r;
        if (m == i) break;
        final t = a[i];
        a[i] = a[m];
        a[m] = t;
        i = m;
      }
    }
    return top;
  }
}

// ---------------------------------------------------------------------------

class FrontierRecovery {
  final Map<String, Clause> rules;
  final String topRuleName;
  final int window; // cut locality W
  final int stableK; // snake-stability commit distance
  final int? maxEvents;
  final bool debug;

  FrontierRecovery(
      {required this.rules,
      required this.topRuleName,
      this.window = 64,
      this.stableK = 16,
      this.maxEvents,
      this.debug = false});

  late Parser _parser;
  late String _input;
  int _age = 0;

  SkipResult recover(String input) {
    _input = input;
    _parser = Parser(rules: rules, topRuleName: topRuleName, input: input);
    _age = 0;
    final body = _parser.rules[topRuleName]!;
    var st = _snake([_FSeq(null, [body, const _Eof()], 0, [], [], 0, 0)], 0, -1 << 28, false, 0,
        const [], const [], 1 << 28, -1 << 28);
    final cap = maxEvents ?? (4 * input.length + 64);
    var events = 0;
    var forced = false;
    while (st.done == null) {
      if (events >= cap) {
        forced = true;
        break;
      }
      // Normalize: the event's baseline is unchanged/uncommittable.
      st = _St(st.spine, st.pos, st.cost, -1 << 28, false, 0, st.spans, st.missing, null, _age++,
          1 << 28, -1 << 28);
      final nxt = _searchEvent(st);
      if (nxt == null) {
        forced = true;
        break;
      }
      st = nxt;
      events++;
    }
    if (st.done == null) st = _forceFinish(st);
    return SkipResult(st.done!, List.of(st.spans), List.of(st.missing), events, forced);
  }

  // -- event search ----------------------------------------------------------

  _St? _searchEvent(_St start) {
    final heap = _Heap();
    heap.add(start);
    final closed = <int>{};
    final seenCost = <int, int>{};
    final popCap = 2000 + 8 * _input.length;
    var pops = 0;
    _St? bestProgress;
    void push(_St st) {
      if (st.done == null) {
        final key = Object.hash(st.pos, st.spineSig);
        final v = (st.cost << 42) + ((st.diameter & ((1 << 20) - 1)) << 21) +
            (st.spanChars & ((1 << 20) - 1));
        final prev = seenCost[key];
        if (prev != null && prev <= v) return;
        seenCost[key] = v;
      }
      heap.add(st);
    }

    // Commit on completion only (uniform-cost to done). Two stability-
    // commit designs were tried and rejected by measurement: an immediate
    // "snake ran stableK past the last edit" commit is unsound (absorbers
    // manufacture fake stability: skip '"' -> Character* snakes to the next
    // quote; a cost-2 repair became a committed cost-5 cascade), and a
    // deferred-acceptance hold (explore cand.cost + 2 further, prefer the
    // longest clean run) fixed long-input quality but let cost-0 cut-only
    // reinterpretations and cheap fake-stable tunnels preempt done states
    // (sweep 466 -> 412). Bounding events for long inputs needs an
    // admissible remaining-cost heuristic (right-side island index - the
    // pika lesson) rather than a stability proxy; until then the pop cap
    // bails out to best progress.
    while (heap.isNotEmpty && pops < popCap) {
      final s = heap.removeMin();
      if (s.changed && s.done != null) return s;
      final key = Object.hash(s.pos, s.spineSig);
      if (!closed.add(key)) continue;
      pops++;
      if (s.changed &&
          s.pos > start.pos &&
          (bestProgress == null || s.pos - s.cost > bestProgress.pos - bestProgress.cost)) {
        bestProgress = s;
      }
      _successors(s, push);
    }
    if (debug) {
      // ignore: avoid_print
      print('event: pops=$pops heap=${heap.length} bailout=${bestProgress != null}');
    }
    return bestProgress; // pop-cap bailout: best progress made, or null
  }

  // -- snake -----------------------------------------------------------------

  /// Drive [sp] (owned, mutable) with the pure oracle until a mismatch or
  /// completion; returns the post-snake state.
  _St _snake(List<_F> sp, int cost, int lastChange, bool changed, int cuts,
      List<SyntaxError> spans, List<MissingObligation> missing, int eMin, int eMax) {
    while (true) {
      final top = sp.last;
      if (top is _FSeq) {
        while (top.j < top.obligations.length) {
          final r = _parser.match(top.obligations[top.j], top.curr);
          if (r.isMismatch) {
            return _St(sp, top.curr, cost, lastChange, changed, cuts, spans, missing, null, _age++, eMin, eMax);
          }
          top.children.add(r);
          top.childOblig.add(top.j);
          top.curr += r.len;
          top.j++;
        }
        final m = top.clause == null
            ? Match(null, 0, 0, subClauseMatches: top.children)
            : (top.children.isEmpty
                ? Match(top.clause, top.startPos, 0)
                : Match(top.clause, 0, 0, subClauseMatches: top.children));
        sp.removeLast();
        if (sp.isEmpty) {
          return _St(const [], top.curr, cost, lastChange, changed, cuts, spans, missing, m, _age++, eMin, eMax);
        }
        _deliver(sp, m);
      } else if (top is _FRep) {
        while (top.curr <= _input.length) {
          final r = _parser.match(top.rep.subClause, top.curr);
          if (r.isMismatch || r.len == 0) break;
          top.items.add(r);
          top.curr += r.len;
        }
        // Always stall: closing is a (free) move, so edits can still land
        // inside the repetition (extend across a span).
        return _St(sp, top.curr, cost, lastChange, changed, cuts, spans, missing, null, _age++, eMin, eMax);
      } else {
        throw StateError('snake on ${top.runtimeType}');
      }
    }
  }

  void _deliver(List<_F> sp, MatchResult m) {
    var cur = m;
    while (true) {
      final top = sp.last;
      if (top is _FWrap) {
        sp.removeLast();
        cur = Match(top.clause, 0, 0, subClauseMatches: [cur]);
      } else if (top is _FSeq) {
        top.children.add(cur);
        top.childOblig.add(top.j);
        top.curr = cur.pos + cur.len;
        top.j++;
        return;
      } else if (top is _FRep) {
        top.items.add(cur);
        top.curr = cur.pos + cur.len;
        return;
      } else {
        throw StateError('deliver into ${top.runtimeType}');
      }
    }
  }

  List<_F> _copy(List<_F> sp) => [for (final f in sp) f.copyF()];

  List<SyntaxError> _pruneSp(List<SyntaxError> spans, int cutPos) =>
      [for (final e in spans) if (e.pos < cutPos) e];

  List<MissingObligation> _pruneMs(List<MissingObligation> ms, int cutPos) =>
      [for (final m in ms) if (m.pos < cutPos) m];

  // -- successors ------------------------------------------------------------

  void _successors(_St s, void Function(_St) push) {
    final sp = s.spine;
    if (sp.isEmpty) return;
    final top = sp.last;
    if (top is _FSeq) {
      final ob = top.obligations[top.j];
      final p = top.curr;
      // Expansion (free): open the failing obligation, branchful.
      for (final ext in _expansions(sp, ob, p)) {
        push(_snake(_copy(sp)..addAll(ext), s.cost, s.lastChange, s.changed, s.cuts, s.spans,
            s.missing, s.editMin, s.editMax));
      }
      // Skip obligation (cost 1) - never EOF.
      if (ob is! _Eof) {
        final c2 = _copy(sp);
        (c2.last as _FSeq).j++;
        push(_snake(c2, s.cost + 1, p, true, s.cuts, s.spans,
            [...s.missing, MissingObligation(ob, p)],
            p < s.editMin ? p : s.editMin, p > s.editMax ? p : s.editMax));
      }
      _spanSuccs(s, ob, p, push);
    } else if (top is _FRep) {
      final p = top.curr;
      final item = top.rep.subClause;
      for (final ext in _expansions(sp, item, p)) {
        push(_snake(_copy(sp)..addAll(ext), s.cost, s.lastChange, s.changed, s.cuts, s.spans,
            s.missing, s.editMin, s.editMax));
      }
      // Close (free with items or ZeroOrMore; a failed OneOrMore closes
      // empty at cost 1 with a missing item).
      final c2 = _copy(sp);
      final r2 = c2.removeLast() as _FRep;
      final m = r2.items.isEmpty
          ? Match(r2.rep, r2.startPos, 0)
          : Match(r2.rep, 0, 0, subClauseMatches: r2.items);
      _deliver(c2, m);
      if (r2.items.isEmpty && r2.rep.requireOne) {
        push(_snake(c2, s.cost + 1, p, true, s.cuts, s.spans,
            [...s.missing, MissingObligation(item, p)],
            p < s.editMin ? p : s.editMin, p > s.editMax ? p : s.editMax));
      } else {
        push(_snake(c2, s.cost, s.lastChange, s.changed, s.cuts, s.spans, s.missing, s.editMin,
            s.editMax));
      }
      _spanSuccs(s, item, p, push);
    }
    _cutSuccs(s, push);
  }

  void _spanSuccs(_St s, Clause ob, int p, void Function(_St) push) {
    if (p >= _input.length) return;
    push(_spanned(s, p, 1));
    // Macro edge: jump the span to the next position where the pending
    // obligation matches (redundant shortcut; keeps long garbage linear).
    var q = p + 1;
    while (q <= _input.length && _parser.match(ob, q).isMismatch) {
      q++;
    }
    if (q <= _input.length && q > p + 1) push(_spanned(s, p, q - p));
  }

  _St _spanned(_St s, int p, int k) {
    final sp = _copy(s.spine);
    final err = SyntaxError(pos: p, len: k);
    final top = sp.last;
    if (top is _FSeq) {
      top.children.add(err);
      top.childOblig.add(-1);
      top.curr += k;
    } else if (top is _FRep) {
      top.items.add(err);
      top.curr += k;
    }
    return _snake(sp, s.cost + k, p + k, true, s.cuts, [...s.spans, err], s.missing,
        p < s.editMin ? p : s.editMin, p + k - 1 > s.editMax ? p + k - 1 : s.editMax);
  }

  // -- expansion -------------------------------------------------------------

  /// Open [c] at [p] one level, branchful: each returned extension is a
  /// list of frames to append to the spine. Guarded against re-opening a
  /// clause already open at the same position (left recursion).
  List<List<_F>> _expansions(List<_F> sp, Clause c, int p) {
    final guard = <int>{};
    for (final f in sp) {
      if (f is _FSeq && f.clause != null && f.startPos == p) {
        guard.add(identityHashCode(f.clause));
      } else if (f is _FWrap && f.startPos == p) {
        guard.add(identityHashCode(f.clause));
      } else if (f is _FRep && f.startPos == p) {
        guard.add(identityHashCode(f.rep));
      }
    }
    final out = <List<_F>>[];
    _expandInto(c, p, const [], guard, out, 0);
    return out;
  }

  void _expandInto(
      Clause c, int p, List<_F> prefix, Set<int> guard, List<List<_F>> out, int depth) {
    if (depth > 32 || out.length > 24) return;
    if (!guard.add(identityHashCode(c))) return;
    if (c is Ref) {
      _expandInto(_parser.rules[c.ruleName]!, p, [...prefix, _FWrap(c, p)], guard, out, depth + 1);
    } else if (c is First) {
      for (final alt in c.subClauses) {
        _expandInto(alt, p, [...prefix, _FWrap(c, p)], guard, out, depth + 1);
      }
    } else if (c is Optional) {
      // Enter branch only: the empty branch is the snake's own greedy path.
      _expandInto(c.subClause, p, [...prefix, _FWrap(c, p)], guard, out, depth + 1);
    } else if (c is Seq) {
      out.add([...prefix, _FSeq(c, c.subClauses, p, [], [], 0, p)]);
    } else if (c is Str && c.text.length > 1) {
      out.add([
        ...prefix,
        _FSeq(c, [for (var i = 0; i < c.text.length; i++) Char(c.text[i])], p, [], [], 0, p)
      ]);
    } else if (c is Repetition) {
      out.add([...prefix, _FRep(c, p, [], p)]);
    }
    // Terminals, predicates, Nothing: no expansion.
  }

  // -- cuts ------------------------------------------------------------------

  /// Un-commit matched material: for every frame on the spine, and (within
  /// the locality window) every nested match reachable through trailing
  /// children, emit states with the tail given back and the interrupted
  /// obligation pending - each also pre-branched through _expansions so
  /// non-greedy choices (other alternatives, entered Optionals) exist.
  /// The reconstructed enclosing frames are threaded down the recursion as
  /// a spine-builder [ctx] (delivering a nested truncation into the
  /// top-level context dropped the intermediate structure and produced
  /// non-covering trees).
  void _cutSuccs(_St s, void Function(_St) push) {
    if (s.cuts >= 2) return; // undo budget: single-point damage needs few
    final minPos = s.pos - window;
    for (var fi = s.spine.length - 1; fi >= 0; fi--) {
      final f = s.spine[fi];
      final fiC = fi;
      if (f is _FSeq) {
        var backed = 0;
        for (var i = f.children.length - 1; i >= 0 && backed < 6; i--) {
          if (f.childOblig[i] < 0) break; // never cut across an earlier span
          final ch = f.children[i];
          if (ch.pos < minPos) break;
          final iC = i;
          List<_F> ctx() {
            final sp2 = <_F>[for (var x = 0; x < fiC; x++) s.spine[x].copyF()];
            final f0 = s.spine[fiC] as _FSeq;
            final f2 = f0.copyF();
            f2.children.length = iC;
            f2.childOblig.length = iC;
            f2.j = f0.childOblig[iC];
            f2.curr = ch.pos;
            sp2.add(f2);
            return sp2;
          }

          _emitCut(s, ctx, f.obligations[f.childOblig[i]], ch.pos, push);
          _cutInto(s, ch, ctx, push, 0);
          if (ch.len > 0) backed++;
        }
      } else if (f is _FRep) {
        var backed = 0;
        for (var k = f.items.length - 1; k >= 0 && backed < 6; k--) {
          final it = f.items[k];
          if (it is SyntaxError) break;
          if (it.pos < minPos) break;
          // Give back items k.. : reopen mid-repetition.
          final sp2 = _copy(s.spine);
          final r2 = sp2[fi] as _FRep;
          r2.items.length = k;
          r2.curr = it.pos;
          sp2.length = fi + 1;
          push(_snake(sp2, s.cost, it.pos, true, s.cuts + 1, _pruneSp(s.spans, it.pos),
              _pruneMs(s.missing, it.pos), s.editMin, s.editMax));
          backed++;
        }
      }
    }
  }

  /// Emit the reopened state at a cut point (pending obligation [ob] at
  /// [p] on the spine built by [ctx]) plus its expansion branches, so
  /// non-greedy choices exist where the snake would just re-derive the
  /// original greedy reading.
  void _emitCut(_St s, List<_F> Function() ctx, Clause ob, int p, void Function(_St) push) {
    final sp = _pruneSp(s.spans, p);
    final ms = _pruneMs(s.missing, p);
    push(_snake(ctx(), s.cost, p, true, s.cuts + 1, sp, ms, s.editMin, s.editMax));
    for (final ext in _expansions(ctx(), ob, p)) {
      push(_snake(ctx()..addAll(ext), s.cost, p, true, s.cuts + 1, sp, ms, s.editMin, s.editMax));
    }
  }

  /// Descend into the nested match [m], whose producing obligation is
  /// pending on the spine that [ctx] reconstructs. Emits cut states for
  /// the structures inside and recurses along the trailing spine.
  void _cutInto(_St s, MatchResult m, List<_F> Function() ctx, void Function(_St) push, int depth) {
    if (depth > 24) return;
    final minPos = s.pos - window;
    final c = m.clause;
    if (c == null || c is NotFollowedBy || c is FollowedBy) return;
    if (c is Ref || c is First || c is Optional) {
      if (m.subClauseMatches.length == 1) {
        _cutInto(s, m.subClauseMatches.first, () => ctx()..add(_FWrap(c, m.pos)), push, depth + 1);
      } else if (c is Optional && m.subClauseMatches.isEmpty && m.pos >= minPos) {
        // Empty Optional: the enter branch.
        for (final ext in _expansions(ctx(), c.subClause, m.pos)) {
          push(_snake((ctx()..add(_FWrap(c, m.pos)))..addAll(ext), s.cost, m.pos, true,
              s.cuts + 1, _pruneSp(s.spans, m.pos), _pruneMs(s.missing, m.pos), s.editMin,
              s.editMax));
        }
      }
      return;
    }
    if (c is Seq) {
      final children = m.subClauseMatches;
      if (children.length != c.subClauses.length) return; // synthetic: skip
      var backed = 0;
      for (var k = children.length - 1; k >= 0 && backed < 6; k--) {
        final ch = children[k];
        if (ch.pos < minPos) break;
        final kC = k;
        List<_F> ctx2() => ctx()
          ..add(_FSeq(c, c.subClauses, m.pos, [for (var x = 0; x < kC; x++) children[x]],
              [for (var x = 0; x < kC; x++) x], kC, ch.pos));
        _emitCut(s, ctx2, c.subClauses[k], ch.pos, push);
        _cutInto(s, ch, ctx2, push, depth + 1);
        // Only the trailing content child is descended into: deeper cuts in
        // earlier children cannot rejoin this Seq's remaining obligations
        // without re-parsing what follows, which a cut of a later child
        // already covers.
        if (ch.len > 0) backed++;
        if (ch.len > 0 && k < children.length - 1) break;
      }
      return;
    }
    if (c is Repetition) {
      final items = m.subClauseMatches;
      var backed = 0;
      for (var k = items.length; k >= 0 && backed < 8; k--) {
        final t = k == 0 ? m.pos : items[k - 1].pos + items[k - 1].len;
        if (t < minPos) break;
        if (k < items.length && !(c.requireOne && k == 0)) {
          // Closed short (retract): deliver the truncated repetition into
          // the reconstructed context and let its obligations continue at t.
          final trunc = k == 0
              ? Match(c, m.pos, 0)
              : Match(c, 0, 0, subClauseMatches: [for (var x = 0; x < k; x++) items[x]]);
          final sp2 = ctx();
          _deliver(sp2, trunc);
          push(_snake(sp2, s.cost, t, true, s.cuts + 1, _pruneSp(s.spans, t),
              _pruneMs(s.missing, t), s.editMin, s.editMax));
        }
        // Open at k (extend / edit inside the repetition).
        final sp3 = ctx()..add(_FRep(c, m.pos, [for (var x = 0; x < k; x++) items[x]], t));
        push(_snake(sp3, s.cost, t, true, s.cuts + 1, _pruneSp(s.spans, t),
            _pruneMs(s.missing, t), s.editMin, s.editMax));
        backed++;
      }
      if (items.isNotEmpty) {
        final tLast = items[items.length - 1].pos;
        _cutInto(
            s,
            items.last,
            () => ctx()
              ..add(_FRep(
                  c, m.pos, [for (var x = 0; x < items.length - 1; x++) items[x]], tLast)),
            push,
            depth + 1);
      }
      return;
    }
    // Terminals (incl. Str): expansions at the cut point cover them.
  }

  // -- forced completion -----------------------------------------------------

  _St _forceFinish(_St s) {
    final sp = _copy(s.spine);
    final spans = List.of(s.spans);
    var top = sp.last;
    var pos = top is _FSeq ? top.curr : (top as _FRep).curr;
    if (pos < _input.length) {
      final err = SyntaxError(pos: pos, len: _input.length - pos);
      if (top is _FSeq) {
        top.children.add(err);
        top.childOblig.add(-1);
        top.curr = _input.length;
      } else if (top is _FRep) {
        top.items.add(err);
        top.curr = _input.length;
      }
      spans.add(err);
      pos = _input.length;
    }
    // Deliver everything upward as-is.
    MatchResult? done;
    while (sp.isNotEmpty) {
      final f = sp.removeLast();
      MatchResult m;
      if (f is _FSeq) {
        m = f.clause == null
            ? Match(null, 0, 0, subClauseMatches: f.children)
            : (f.children.isEmpty
                ? Match(f.clause, f.startPos, 0)
                : Match(f.clause, 0, 0, subClauseMatches: f.children));
      } else if (f is _FRep) {
        m = f.items.isEmpty
            ? Match(f.rep, f.startPos, 0)
            : Match(f.rep, 0, 0, subClauseMatches: f.items);
      } else {
        continue; // bare wrap with nothing delivered: drop
      }
      if (sp.isEmpty) {
        done = m;
      } else {
        _deliver(sp, m);
      }
    }
    return _St(const [], pos, s.cost, s.lastChange, true, s.cuts, spans, s.missing, done, _age++,
        s.editMin, s.editMax);
  }
}
