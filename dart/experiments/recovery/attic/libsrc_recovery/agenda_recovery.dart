// Agenda recovery: weighted deductive parsing of the error-closed grammar.
//
// This is the UNIFICATION of semiring_recovery.dart (the eager chart) and
// frontier_recovery.dart (the lazy best-first search): one agenda-based
// evaluator -- Knuth's lightest-derivation algorithm, the generalization of
// Dijkstra to grammars -- over the same closed grammar:
//
//     C -> <span-char> C   (cost 1)      C -> epsilon   (cost 1 terminal,
//                                                        cost 2 composite)
//
// with the same enriched weights (cost, spanChars, editLo, editHi), ordered
// lexicographically by (cost, diameter, first-edit-latest, spanChars).
//
// Items are complete matches (clause, start, end) and dotted partial
// sequences; deduction rules are the clause semantics plus the two closure
// productions; the agenda is a priority queue in weight order. Because
// every rule's conclusion is lex->= each premise (costs add; the edit
// interval can only grow under union, so the diameter can only grow and the
// first edit can only move earlier; span chars add), Knuth's superiority
// condition holds and THE FIRST TIME THE GOAL ITEM POPS IT IS OPTIMAL.
// That single fact deletes, relative to the two implementations it
// replaces: iterative deepening and the optimality certificate (the pop
// order IS the certificate), the within-position fixpoint (worklist order
// replaces it; left recursion is just a cyclic item dependency, handled by
// monotone improvement), pop caps and bailouts (nothing to cap), and the
// entire witness re-derivation machinery (every kept value carries the
// backpointer that produced it).
//
// A multi-char Str literal is desugared to a sequence of Char clauses, so
// the banded edit distance inside literals -- a special-cased DP in the
// chart -- falls out of the uniform closure with no code.
//
// Trailing garbage needs no special case either: the goal is a synthetic
// wrapper sequence [Top, EOF], where EOF matches only at end of input and,
// like every clause, has the span production -- so "the rest is garbage"
// is just EOF with spans prepended.
//
// Evaluation regimes of the ONE algorithm:
//   - a valid input short-circuits through the pure parser (the zero-cost
//     slice, evaluated lazily -- packrat);
//   - a damaged input runs the agenda, which does pika-style bottom-up
//     deduction on the zero slice plus exactly the weighted band the
//     optimum requires (Dijkstra stops at the goal; running it to
//     exhaustion would reproduce the eager chart).
//
// Pareto sets: because the edit interval combines by union (not addition),
// an item may hold several incomparable values (dominance: <= on cost and
// spanChars, interval containment); each kept value is queued. Dominance
// implies lex-<=, so pop order respects dominance and a popped value is
// never dominated later.
//
// The parser stays a pure oracle: predicates consult the unmodified Parser
// on the real text (negation is not monotone under min), and recovery
// works entirely outside it.

import '../parser/clause.dart';
import '../parser/combinators.dart';
import '../parser/match_result.dart';
import '../parser/parser.dart';
import '../parser/terminals.dart';
import 'skip_recovery.dart' show SkipResult, MissingObligation;

/// Weight: (cost, spanChars, editLo, editHi); lo > hi means "no edits".
typedef _V = (int, int, int, int);

const int _inf = 1 << 24;
const _V _zero = (0, 0, _inf, -1);

_V _add(_V a, _V b) => (
      a.$1 + b.$1,
      a.$2 + b.$2,
      a.$3 < b.$3 ? a.$3 : b.$3,
      a.$4 > b.$4 ? a.$4 : b.$4
    );

int _diam(_V a) => a.$4 >= a.$3 ? a.$4 - a.$3 : 0;

/// Lexicographic order: cost, diameter, first-edit-latest, spanChars.
int _cmp(_V a, _V b) {
  if (a.$1 != b.$1) return a.$1 - b.$1;
  final da = _diam(a), db = _diam(b);
  if (da != db) return da - db;
  if (a.$3 != b.$3) return b.$3 - a.$3; // larger lo (later first edit) first
  return a.$2 - b.$2;
}

bool _dom(_V a, _V b) =>
    a.$1 <= b.$1 && a.$2 <= b.$2 && a.$3 >= b.$3 && a.$4 <= b.$4;

/// Matches only at end of input; span closure turns it into "trailing
/// garbage".
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

/// A multi-char Str desugared to its char sequence (uniform closure inside
/// literals = banded edit distance for free). Reported as the original Str.
class _StrSeq extends Seq {
  final Str orig;
  _StrSeq(this.orig) : super([for (var i = 0; i < orig.text.length; i++) Char(orig.text[i])]);
  @override
  String toString() => orig.toString();
}

/// Goal wrapper: Seq(Top, EOF).
class _Wrap extends Seq {
  _Wrap(Clause top, Clause eof) : super([top, eof]);
  @override
  String toString() => '<goal>';
}

// Backpointer tags.
const int _tTerm = 0; // terminal match axiom
const int _tEps = 1; // epsilon production ("missing")
const int _tEmpty = 2; // free zero-width (Optional/ZeroOrMore empty, EOF)
const int _tPred = 3; // predicate satisfied on the zero slice
const int _tSpan = 4; // span production: a = inner entry (same clause)
const int _tUnary = 5; // Ref/First/Optional wrap: a = child entry
const int _tRepSeed = 6; // first repetition item: a = item entry
const int _tRepExt = 7; // repetition extension: a = rep entry, b = item
const int _tSeq = 8; // completed sequence: a = final partial
const int _tStep = 9; // partial step: a = previous partial (or null), b = child

class _E {
  final bool partial;
  final int cid; // clause id (for partials, the Seq's id)
  final int s; // start
  final int d; // dot (partials only; 0 for completes)
  final int e; // end (for partials, current position)
  final _V v;
  // Backpointer, mutable: an exact-value tie may re-point the incumbent to
  // a preferred derivation (parents reference this entry, not its
  // derivation, so the re-point propagates consistently -- the value is
  // identical by construction).
  int tag;
  _E? a;
  _E? b;
  bool dead = false;
  bool popped = false;
  _E(this.partial, this.cid, this.s, this.d, this.e, this.v, this.tag,
      [this.a, this.b]);
}

class AgendaRecovery {
  final Map<String, Clause> rules;
  final String topRuleName;
  final bool debug;

  AgendaRecovery(
      {required this.rules, required this.topRuleName, this.debug = false});

  late final Map<String, Clause> _rules = () {
    final m = <String, Clause>{};
    rules.forEach((k, v) => m[k.startsWith('~') ? k.substring(1) : k] = v);
    return m;
  }();

  final Map<Clause, Clause> _strSubst = {}; // Str(len>1) -> _StrSeq

  Clause _sub(Clause c) =>
      (c is Str && c.text.length > 1) ? _strSubst.putIfAbsent(c, () => _StrSeq(c)) : c;

  late final _Wrap _wrap = _Wrap(_sub(_top), const _Eof());

  late final Clause _top = () {
    final t = _rules[topRuleName];
    if (t == null) throw ArgumentError('top rule "$topRuleName" not found');
    return t;
  }();

  /// All clause nodes reachable from the wrapper, Strs desugared.
  late final List<Clause> _universe = () {
    final seen = <Clause>{};
    final out = <Clause>[];
    void collect(Clause raw) {
      final c = _sub(raw);
      if (!seen.add(c)) return;
      if (c is Ref) {
        final t = _rules[c.ruleName];
        if (t == null) throw ArgumentError('rule "${c.ruleName}" not found');
        collect(t);
      } else if (c is HasOneSubClause) {
        collect(c.subClause);
      } else if (c is HasMultipleSubClauses) {
        c.subClauses.forEach(collect);
      }
      out.add(c);
    }

    collect(_wrap);
    return out;
  }();

  late final Map<Clause, int> _cid = () {
    final m = <Clause, int>{};
    for (var i = 0; i < _universe.length; i++) {
      m[_universe[i]] = i;
    }
    return m;
  }();

  // Deduction indexes (built once).
  late final Map<int, List<Clause>> _unaryParents = _buildUnary();
  late final Map<int, List<Repetition>> _repParents = _buildRepParents();
  late final Map<int, List<(Seq, int)>> _seqDots = _buildSeqDots();

  Map<int, List<Clause>> _buildUnary() {
    final m = <int, List<Clause>>{};
    for (final c in _universe) {
      if (c is Ref) {
        m.putIfAbsent(_cid[_sub(_rules[c.ruleName]!)]!, () => []).add(c);
      } else if (c is First) {
        for (final s in c.subClauses) {
          m.putIfAbsent(_cid[_sub(s)]!, () => []).add(c);
        }
      } else if (c is Optional) {
        m.putIfAbsent(_cid[_sub(c.subClause)]!, () => []).add(c);
      }
    }
    return m;
  }

  Map<int, List<Repetition>> _buildRepParents() {
    final m = <int, List<Repetition>>{};
    for (final c in _universe) {
      if (c is Repetition) {
        m.putIfAbsent(_cid[_sub(c.subClause)]!, () => []).add(c);
      }
    }
    return m;
  }

  Map<int, List<(Seq, int)>> _buildSeqDots() {
    final m = <int, List<(Seq, int)>>{};
    for (final c in _universe) {
      if (c is Seq) {
        for (var i = 0; i < c.subClauses.length; i++) {
          m.putIfAbsent(_cid[_sub(c.subClauses[i])]!, () => []).add((c, i));
        }
      }
    }
    return m;
  }

  int _epsCost(Clause c) =>
      (c is Terminal ||
              c is _StrSeq ||
              c is NotFollowedBy ||
              c is FollowedBy)
          ? 1
          : 2;

  // ---- per-recover() state ----
  late String input;
  late int n;
  Parser? _oracle;
  late List<_E> _heap;
  late Map<int, Map<int, List<_E>>> _completes; // cid*(n+1)+s -> end -> Pareto
  late Map<int, List<_E>> _partialsAt; // (cid*64+d)*(n+1)+pos -> partials
  late Map<int, List<_E>> _repEnding; // repCid*(n+1)+end -> rep completes
  late List<MissingObligation> _missing;

  int lastTotalCost = -1;
  int lastPops = -1;
  int lastPushes = -1;

  // ---- heap ----

  void _hpush(_E x) {
    _heap.add(x);
    var i = _heap.length - 1;
    while (i > 0) {
      final p = (i - 1) >> 1;
      if (_cmp(_heap[p].v, x.v) <= 0) break;
      _heap[i] = _heap[p];
      i = p;
    }
    _heap[i] = x;
  }

  _E _hpop() {
    final top = _heap[0];
    final last = _heap.removeLast();
    if (_heap.isNotEmpty) {
      var i = 0;
      while (true) {
        final l = 2 * i + 1, r = 2 * i + 2;
        var m = i;
        _E mv = last;
        if (l < _heap.length && _cmp(_heap[l].v, mv.v) < 0) {
          m = l;
          mv = _heap[l];
        }
        if (r < _heap.length && _cmp(_heap[r].v, mv.v) < 0) {
          m = r;
        }
        if (m == i) break;
        _heap[i] = _heap[m];
        i = m;
      }
      _heap[i] = last;
    }
    return top;
  }

  // ---- item insertion with Pareto dominance ----

  /// Witness preference at exact-value ties, mirroring the chart's
  /// extraction order: normal production before span before epsilon, and
  /// among First alternatives the lower (PEG) index.
  int _bpRank(int tag) => tag == _tEps ? 2 : (tag == _tSpan ? 1 : 0);

  int _altIndex(int cid, _E? child) {
    final p = _universe[cid];
    if (p is! First || child == null) return 0;
    final cc = _universe[child.cid];
    for (var i = 0; i < p.subClauses.length; i++) {
      if (identical(_sub(p.subClauses[i]), cc)) return i;
    }
    return 0;
  }

  void _addComplete(int cid, int s, int e, _V v, int tag, [_E? a, _E? b]) {
    final key = cid * (n + 1) + s;
    final byEnd = _completes.putIfAbsent(key, () => {});
    final list = byEnd.putIfAbsent(e, () => []);
    for (final x in list) {
      if (!x.dead && _dom(x.v, v)) {
        if (x.v == v) {
          final rn = _bpRank(tag), ro = _bpRank(x.tag);
          final better = rn < ro ||
              (rn == ro &&
                  tag == _tUnary &&
                  x.tag == _tUnary &&
                  _altIndex(cid, a) < _altIndex(cid, x.a));
          if (better) {
            x.tag = tag;
            x.a = a;
            x.b = b;
          }
        }
        return;
      }
    }
    for (final x in list) {
      if (!x.dead && _dom(v, x.v)) x.dead = true;
    }
    final entry = _E(false, cid, s, 0, e, v, tag, a, b);
    list.add(entry);
    _hpush(entry);
    lastPushes++;
    if (_universe[cid] is Repetition && _isChainState(entry)) {
      _repEnding.putIfAbsent(cid * (n + 1) + e, () => []).add(entry);
    }
  }

  /// Repetition states that may take further items: the free empty
  /// (ZeroOrMore) and genuine chains. NOT an epsilon'd repetition (the
  /// whole obligation was skipped) and NOT a zero-width single take (the
  /// pure parser stops a repetition at a zero-length item).
  bool _isChainState(_E x) =>
      x.tag == _tEmpty ||
      ((x.tag == _tRepSeed || x.tag == _tRepExt) && x.e > x.s);

  void _addPartial(Seq seq, int s, int d, int pos, _V v, _E? prev, _E child) {
    final cid = _cid[seq]!;
    // A finished partial becomes the complete Seq item.
    if (d == seq.subClauses.length) {
      final p = _E(true, cid, s, d, pos, v, _tStep, prev, child);
      _addComplete(cid, s, pos, v, _tSeq, p);
      return;
    }
    final key = (cid * 64 + d) * (n + 1) + pos;
    final list = _partialsAt.putIfAbsent(key, () => []);
    // The bucket is a SCAN index (all partials expecting child d at pos);
    // dominance only applies between partials of the same item, i.e. the
    // same start.
    for (final x in list) {
      if (x.s == s && !x.dead && _dom(x.v, v)) return;
    }
    for (final x in list) {
      if (x.s == s && !x.dead && _dom(v, x.v)) x.dead = true;
    }
    final entry = _E(true, cid, s, d, pos, v, _tStep, prev, child);
    list.add(entry);
    _hpush(entry);
    lastPushes++;
  }

  // ---- recover ----

  SkipResult recover(String input) {
    this.input = input;
    n = input.length;
    _oracle = Parser(rules: rules, topRuleName: topRuleName, input: input);
    // The zero-cost slice, evaluated lazily: the pure parser. Valid input
    // never reaches the agenda.
    final pure = _oracle!.parse();
    if (!pure.hasSyntaxErrors) {
      return SkipResult(pure.root, const [], const [], 0, false);
    }

    _heap = [];
    _completes = {};
    _partialsAt = {};
    _repEnding = {};
    _missing = [];
    lastPops = 0;
    lastPushes = 0;
    _axioms();

    final wrapCid = _cid[_wrap]!;
    _E? goal;
    while (_heap.isNotEmpty) {
      // Once the goal has popped, keep draining its equal-key plateau:
      // same-value arrivals may re-point witnesses to preferred derivations
      // (first alternative, normal-over-fabrication). Values below the goal
      // key cannot appear (superiority), so this stays exact.
      if (goal != null && _cmp(_heap[0].v, goal.v) > 0) break;
      final x = _hpop();
      if (x.dead || x.popped) continue;
      x.popped = true;
      lastPops++;
      if (!x.partial && x.cid == wrapCid && x.s == 0 && x.e == n) {
        goal ??= x;
        continue;
      }
      if (x.partial) {
        _firePartial(x);
      } else {
        _fireComplete(x);
      }
    }
    if (goal == null) throw StateError('agenda exhausted without goal');
    lastTotalCost = goal.v.$1;

    final root = _build(goal);
    final raw = <SyntaxError>[];
    void walk(MatchResult m) {
      if (m is SyntaxError) {
        raw.add(m);
        return;
      }
      m.subClauseMatches.forEach(walk);
    }

    walk(root);
    raw.sort((a, b) => a.pos.compareTo(b.pos));
    final spans = <SyntaxError>[];
    for (final s in raw) {
      if (spans.isNotEmpty && spans.last.pos + spans.last.len == s.pos) {
        final last = spans.removeLast();
        spans.add(SyntaxError(pos: last.pos, len: last.len + s.len));
      } else {
        spans.add(s);
      }
    }
    _missing.sort((a, b) => a.pos.compareTo(b.pos));
    return SkipResult(root, spans, _missing, 1, false);
  }

  void _axioms() {
    for (final c in _universe) {
      final ci = _cid[c]!;
      if (c is Char) {
        final ch = c.char.codeUnitAt(0);
        for (var p = 0; p < n; p++) {
          if (input.codeUnitAt(p) == ch) _addComplete(ci, p, p + 1, _zero, _tTerm);
        }
      } else if (c is CharSet) {
        for (var p = 0; p < n; p++) {
          if (_csMatch(c, input.codeUnitAt(p))) {
            _addComplete(ci, p, p + 1, _zero, _tTerm);
          }
        }
      } else if (c is Str) {
        // Only single-char Strs remain after desugaring.
        final ch = c.text.codeUnitAt(0);
        for (var p = 0; p < n; p++) {
          if (input.codeUnitAt(p) == ch) _addComplete(ci, p, p + 1, _zero, _tTerm);
        }
      } else if (c is AnyChar) {
        for (var p = 0; p < n; p++) {
          _addComplete(ci, p, p + 1, _zero, _tTerm);
        }
      } else if (c is Nothing) {
        for (var p = 0; p <= n; p++) {
          _addComplete(ci, p, p, _zero, _tEmpty);
        }
      } else if (c is Repetition && !c.requireOne) {
        for (var p = 0; p <= n; p++) {
          _addComplete(ci, p, p, _zero, _tEmpty);
        }
      } else if (c is Optional) {
        for (var p = 0; p <= n; p++) {
          _addComplete(ci, p, p, _zero, _tEmpty);
        }
      } else if (c is NotFollowedBy) {
        for (var p = 0; p <= n; p++) {
          if (c.subClause.match(_oracle!, p).isMismatch) {
            _addComplete(ci, p, p, _zero, _tPred);
          }
        }
      } else if (c is FollowedBy) {
        for (var p = 0; p <= n; p++) {
          if (!c.subClause.match(_oracle!, p).isMismatch) {
            _addComplete(ci, p, p, _zero, _tPred);
          }
        }
      } else if (c is _Eof) {
        _addComplete(ci, n, n, _zero, _tEmpty);
      }
      // Epsilon production for every clause except the goal scaffolding.
      if (c is! _Eof && c is! _Wrap) {
        final ec = _epsCost(c);
        for (var p = 0; p <= n; p++) {
          _addComplete(ci, p, p, (ec, 0, p, p), _tEps);
        }
      }
    }
  }

  bool _csMatch(CharSet cs, int ch) {
    var inSet = false;
    for (final (lo, hi) in cs.ranges) {
      if (ch >= lo && ch <= hi) {
        inSet = true;
        break;
      }
    }
    return cs.inverted ? !inSet : inSet;
  }

  void _fireComplete(_E x) {
    final c = _universe[x.cid];
    // Span production: C -> <char> C (prepend one garbage char).
    if (x.s > 0 && c is! _Wrap) {
      _addComplete(
          x.cid, x.s - 1, x.e, _add(x.v, (1, 1, x.s - 1, x.s - 1)), _tSpan, x);
    }
    // Unary parents (Ref / First / Optional).
    final ups = _unaryParents[x.cid];
    if (ups != null) {
      for (final p in ups) {
        _addComplete(_cid[p]!, x.s, x.e, x.v, _tUnary, x);
      }
    }
    // Repetition parents.
    final reps = _repParents[x.cid];
    if (reps != null) {
      for (final rep in reps) {
        final rc = _cid[rep]!;
        if (x.e > x.s) {
          _addComplete(rc, x.s, x.e, x.v, _tRepSeed, x); // first item
          // Extend previously popped rep states ending at x.s.
          final ending = _repEnding[rc * (n + 1) + x.s];
          if (ending != null) {
            for (final r in ending) {
              if (r.popped && !r.dead) {
                _addComplete(rc, r.s, x.e, _add(r.v, x.v), _tRepExt, r, x);
              }
            }
          }
        } else if (rep.requireOne && x.v.$1 >= 1) {
          // A zero-width item only as a repair (the pure parser mismatches
          // OneOrMore on a zero-width first item).
          _addComplete(rc, x.s, x.s, x.v, _tRepSeed, x);
        }
      }
    }
    // Repetition self: extend with popped items starting at x.e.
    if (c is Repetition && _isChainState(x)) {
      final itemCid = _cid[_sub(c.subClause)]!;
      final byEnd = _completes[itemCid * (n + 1) + x.e];
      if (byEnd != null) {
        byEnd.forEach((e2, list) {
          if (e2 <= x.e) return;
          for (final it in list) {
            if (it.popped && !it.dead) {
              _addComplete(x.cid, x.s, e2, _add(x.v, it.v), _tRepExt, x, it);
            }
          }
        });
      }
    }
    // Sequence stepping.
    final dots = _seqDots[x.cid];
    if (dots != null) {
      for (final (seq, d) in dots) {
        if (d == 0) {
          _addPartial(seq, x.s, 1, x.e, x.v, null, x);
        } else {
          final key = (_cid[seq]! * 64 + d) * (n + 1) + x.s;
          final parts = _partialsAt[key];
          if (parts != null) {
            for (final p in parts) {
              if (p.popped && !p.dead) {
                _addPartial(seq, p.s, d + 1, x.e, _add(p.v, x.v), p, x);
              }
            }
          }
        }
      }
    }
  }

  void _firePartial(_E x) {
    final seq = _universe[x.cid] as Seq;
    final want = _cid[_sub(seq.subClauses[x.d])]!;
    final byEnd = _completes[want * (n + 1) + x.e];
    if (byEnd != null) {
      byEnd.forEach((e2, list) {
        for (final it in list) {
          if (it.popped && !it.dead) {
            _addPartial(seq, x.s, x.d + 1, e2, _add(x.v, it.v), x, it);
          }
        }
      });
    }
  }

  // ---- tree building from backpointers ----

  Clause _outClause(_E x) {
    final c = _universe[x.cid];
    return c is _StrSeq ? c.orig : c;
  }

  MatchResult _build(_E x) {
    switch (x.tag) {
      case _tTerm:
        return Match(_outClause(x), x.s, x.e - x.s);
      case _tEps:
        final c = _universe[x.cid];
        _missing.add(MissingObligation(c is _StrSeq ? c.orig : c, x.s));
        return Match(_outClause(x), x.s, 0);
      case _tEmpty:
      case _tPred:
        return Match(_outClause(x), x.s, 0);
      case _tSpan:
        final inner = _build(x.a!);
        final kids = <MatchResult>[SyntaxError(pos: x.s, len: 1)];
        if (inner.subClauseMatches.isNotEmpty) {
          kids.addAll(inner.subClauseMatches); // same clause: splice
        } else if (inner.len > 0) {
          kids.add(inner);
        }
        return Match(_outClause(x), 0, 0, subClauseMatches: kids);
      case _tUnary:
        return Match(_outClause(x), 0, 0, subClauseMatches: [_build(x.a!)]);
      case _tRepSeed:
        return Match(_outClause(x), 0, 0, subClauseMatches: [_build(x.a!)]);
      case _tRepExt:
        final items = <_E>[];
        _E cur = x;
        while (cur.tag == _tRepExt) {
          items.add(cur.b!);
          cur = cur.a!;
        }
        items.add(cur.a!); // the seed's item
        final kids = [for (final it in items.reversed) _build(it)];
        return Match(_outClause(x), 0, 0, subClauseMatches: kids);
      case _tSeq:
        final children = <_E>[];
        _E? p = x.a; // final partial
        while (p != null) {
          children.add(p.b!);
          p = p.a;
        }
        final kids = [for (final ch in children.reversed) _build(ch)];
        return Match(_outClause(x), 0, 0, subClauseMatches: kids);
      default:
        throw StateError('bad backpointer tag ${x.tag}');
    }
  }
}
