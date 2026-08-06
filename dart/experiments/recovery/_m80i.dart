// m80 -- I38: THE CONTINUATION DOES NOT NEED TO BE PUSHED DOWN IF THE ENDINGS
// ARE PULLED UP.
//
// m80 keeps m79's insights about WHAT a repair is and deletes its machinery for
// searching over repairs, because that machinery was answering the wrong
// question.
//
//   I35  A REPAIR IS A CLAIM ABOUT THE TREE, NOT AN EDIT TO THE EVIDENCE.
//        Positions always index the ORIGINAL input; nothing is ever inserted
//        into, deleted from or substituted in it, not even transiently. Exactly
//        two repair operations, and both are ANNOTATIONS ON THE TREE:
//          SKIP(p,n)  n characters at p that no clause explains -- a
//                     `SyntaxError` span, the node the frozen library already
//                     uses for unmatched input.
//          FILL(c,p)  a clause the grammar requires at p, for which the evidence
//                     shows nothing -- a ZERO-WIDTH `Filled` node, so the tree
//                     gets the right SHAPE without the input gaining a
//                     character.
//
//   I36  SYNTHESIS IS LEGAL EXACTLY WHERE IT CHOOSES NOTHING. FILL a clause iff
//        it has a UNIQUE MINIMAL WITNESS. `')'` has one string of minimal
//        length; `[0-9]` has ten; `"true"/"false"` has two. Synthesising the
//        unique witness adds no information that was not already in the grammar;
//        synthesising one of ten is a choice about content the evidence does not
//        contain, which is fabrication. One rule, and it decides both of the
//        owner's acceptance cases with no tie-break model at all:
//          `,3true`  the Seq needs `,`; `,` is its unique minimal witness, so
//                    FILL is legal and it reads as `,3,true`.
//          `[,2,`    keeping the leading comma needs a Value first, and Value's
//                    minimal witnesses include every digit -- not unique, so
//                    FILL is ILLEGAL and the comma is SKIPped.
//
// A4, PROVED RATHER THAN ASSUMED. A lookahead is a predicate over the evidence,
// and by I35 the evidence never changes, so `&e` / `!e` at p is decided by the
// PURE parser reading the ORIGINAL input at p. No residual, no derivative, no
// product DFA, no obligation in the memo key. This is EXACT for every predicate
// body, including the nested ones the owner explicitly excused.
//
// ---------------------------------------------------------------------------
// I38, AND THE MEASUREMENT THAT FORCED IT.
//
// m79 asked each clause for its ONE best reading. That is wrong, and not by a
// tie-break: which reading a clause should return depends on where the ENCLOSING
// clause needs it to end, and the clause cannot see that. Measured on the 519
// mutant battery, `{"a":1,"bc":[,33,true],"d":...}` is the whole story. At
// position 13 there are two readings of `Value`, both costing 1:
//
//     String,           ends at 24   (fill a `"`, swallow to the next one)
//     skip-then-Number, ends at 16   (drop the stray comma, read `33`)
//
// m79 computed BOTH and returned one. Ranking by evidence-explained returns the
// String, and the rest of the document is then re-read as an object wrapped
// around it -- 115 of m79's 288 shape failures are that one mechanism. Ranking
// by cost leaves the tie, and every tie-break is a coin toss: measured,
// cost-first scores 30/519 against 231/519 and takes 826 s against 308 ms. NO
// ORDERING RESCUES A SINGLE ANSWER, because the information needed to choose is
// not in the sub-parse.
//
// m76/m78 saw the same problem and solved it in the other direction: PUSH the
// continuation down, as an obligation over the repaired suffix, normalised to a
// regular PEG and carried as a parsing-expression derivative in the memo key.
// That is right, and it is about 400 lines of algebra over the grammar.
//
// PULLING THE ENDINGS UP NEEDS NO ALGEBRA AT ALL. Every clause returns a map
// from END POSITION to the cheapest way of reaching it, so a sub-parse offers
// the enclosing clause every ending it can produce and the enclosing clause
// picks. A sequence is then a fold over that map, which is the whole of the
// search. The obligation algebra, the residual, the product DFA and the
// derivative all disappear -- not approximated, not scoped down, deleted -- and
// what replaces them is `Map<int, _Way>`.
//
// I37 SURVIVES, BUT AS A PRUNE AND NOT AS PART OF THE KEY -- and it took a
// measurement to get that right. m79 threaded a budget through every call and
// stamped each memo cell with the budget it was derived under, which is a key of
// (clause, position, budget) in all but name. With the ways map that is
// unnecessary, because a clause's ways no longer depend on what the caller has
// left to spend: `_seq` prunes the COMBINATION rather than the sub-parse. So the
// budget leaves the key, the memo becomes exact on (clause, position), and the
// deepening loop is cleared between rounds instead of stamped. (m79's stamp was
// also wrong: it compared with `>=`, so a cell derived under a large budget
// answered a small-budget question.)
//
// The budget cannot leave ENTIRELY, and the reason is worth stating because I
// tried it first and measured it. Without a cap, a `First` alternative that does
// not apply no longer FAILS -- it computes its full repair search and reports
// what that would have cost, at every position, and the enclosing choice then
// throws the answer away. Clean input pays for repairs nobody asked for:
// measured, `{"a":1,"b":2,"c":3}` took 9.7 ms with no cap and 0.06 ms with one.
// The cap restores the property that makes recovery affordable: AT BUDGET 0 THE
// ENGINE IS THE FROZEN PARSER, so a failing alternative fails at once, and each
// round only opens as much repair as the last round proved necessary.
//
// The ceiling is derived, not tuned: skipping the ENTIRE input and filling the
// top rule is always available if anything is, so `|input| + |witness(top)|`
// bounds every solution that exists, and reaching it means none does.
//
// PEG CONFORMANCE IS PRESERVED BY CONSTRUCTION, at four points and no others. A
// cost-0 reading is what pure PEG returns, so wherever one exists it is taken
// ALONE and no repair is considered: `_element` commits to it, `_first` returns
// the first alternative that has one, `_opt` prefers a free body, and
// `_possessive` keeps only the longest cost-0 chain of a repetition. On
// undamaged input every one of those fires, so the engine IS the frozen parser
// and the tree is identical; recovery is reachable only where pure PEG has
// already failed.
//
// KNOWN LOSS, NAMED. `S <- A 'b'; A <- 'a' &'b';` on `"a"`: the string-repair
// engines insert a `b` and let A's lookahead read the character they just
// invented, scoring 1. Here the lookahead reads the evidence, which is EOF, so
// A's guard is discharged by FILL and the `'b'` is filled again -- the tree is
// right, the cost reads 2 where the old oracle says 1. That is an over-report
// against a metric that assumes the input can be edited, which is the metric
// this engine rejects.

import 'package:squirrel_parser/squirrel_parser.dart';

// ---------------------------------------------------------------------------
// The two repair marks. Both are `Match` subclasses, so `treeShape`, `covers`
// and `buildAST` in the frozen library consume them with no changes.

/// Zero-width stand-in for text the grammar DETERMINES must be here, but which
/// the evidence does not show. Legal only where the witness is unique (I36).
class Filled extends Match {
  Filled(Clause? c, int pos, this.text) : super(c, pos, 0);

  /// The unique minimal witness of the filled clause.
  final String text;

  @override
  String toPrettyString(String input, {int indent = 0}) =>
      '${'  ' * indent}<Filled ${clause ?? '?'}>: "$text"\n';
}

// ---------------------------------------------------------------------------

/// Nodes accumulate as a SHARED cons list, most recent first, so extending a
/// partial result is O(1) and every way in the memo shares its prefix with the
/// ways it was grown from.
class _N {
  const _N(this.head, this.tail);
  final _T head;
  final _N? tail;
}

/// A tree node the search has PROMISED but not yet built: either a leaf the
/// matcher already produced, or a clause standing over a cons list of children.
///
/// The distinction is worth its four fields. The search proposes far more
/// subtrees than it keeps -- every losing way at every memo cell built one -- and
/// materialising a `Match` at each wrap copies the whole child list, which is
/// O(subtree) work per cell for a result that is usually discarded. Only the
/// winning way is ever built. Measured, this is 1.12x on the battery and an
/// identical tree: worth keeping, but it is NOT where the time goes.
class _T {
  const _T.leaf(this.leaf)
      : c = null,
        pos = 0,
        kids = null;
  const _T.node(this.c, this.pos, this.kids) : leaf = null;
  final MatchResult? leaf;
  final Clause? c;
  final int pos;
  final _N? kids;
}

List<MatchResult> _list(_N? n) {
  final out = <MatchResult>[];
  for (var p = n; p != null; p = p.tail) {
    final t = p.head;
    out.add(t.leaf ??
        Match(t.c, t.pos, 0, subClauseMatches: _list(t.kids)));
  }
  return out.reversed.toList();
}

/// Append [b] after [a]. [b] is at most a couple of nodes -- a wrapped match,
/// optionally behind a skip -- so this is O(1) in practice.
_N? _cat(_N? a, _N? b) => b == null ? a : _N(b.head, _cat(a, b.tail));

/// One way of reaching one end position: what it cost, how much of the input it
/// explained, whether it was SELECTED by synthesis, and the nodes it produced.
class _Way {
  const _Way(this.cost, this.got, this.synth, this.nodes);

  /// THE WHOLE OBJECTIVE: characters discarded by a SKIP plus characters
  /// asserted by a FILL. `cost == 0` is what "pure PEG matched this" means.
  final int cost;

  /// Characters matched. Only ever a tie-break between equal costs.
  final int got;

  /// I43: does this way OPEN with a FILL -- synthesis before any character of
  /// evidence has been read? See [_first].
  final bool synth;

  final _N? nodes;
}

/// I38: end position -> the cheapest way of reaching it. This is the engine's
/// only data structure, and it is what the enclosing clause chooses from.
typedef _Ways = Map<int, _Way>;

const _Ways _none = {};
const _Way _empty = _Way(0, 0, false, null);

/// THE ONE ORDERING IN THE ENGINE, and it only ever compares ways that END AT
/// THE SAME POSITION -- so it is a tie-break, not the search. Cost less; failing
/// that, explain more of the input. It has no parameters.
bool _beats(_Way a, _Way? b) =>
    b == null || a.cost < b.cost || (a.cost == b.cost && a.got > b.got);

/// This round's cap. Every way that enters any map passes through [_put], so
/// this is the only place it has to be enforced -- and since cost is
/// non-negative and additive, a partial way's cost is a lower bound on any
/// completion of it, so the cap prunes exactly rather than approximately.
/// Round 0 sets it to 0, which is what makes that round the frozen parser: no
/// skip loop runs and nothing fills.
int _budget = 0;
int cExpand = 0, cPut = 0;
final Map<String, int> cFam = {};
final Map<String, Set<String>> cCells = {};
void resetCounters() { cExpand = 0; cPut = 0; cFam.clear(); cCells.clear(); }

void _put(_Ways w, int end, _Way v) {
  cPut++;
  if (v.cost <= _budget && _beats(v, w[end])) w[end] = v;
}

/// Concatenate two ways. Synthesis stays "at the head" only while no evidence
/// has been read yet, which is what makes [_Way.synth] mean what I43 needs.
_Way _extend(_Way w, _Way x, _N? nodes) => _Way(w.cost + x.cost,
    w.got + x.got, w.got == 0 ? w.synth || x.synth : w.synth, nodes);

/// PEG's possessive repetition. Among cost-0 ways there is exactly one chain --
/// every cost-0 step is deterministic -- and PEG follows it as far as it goes.
/// Keeping the shorter prefixes would let a repair-free derivation stop early,
/// which pure PEG never does.
_Ways _possessive(_Ways w) {
  var last = -1;
  for (final e in w.entries) {
    if (e.value.cost == 0 && e.key > last) last = e.key;
  }
  if (last < 0) return w;
  return {
    for (final e in w.entries)
      if (e.value.cost != 0 || e.key == last) e.key: e.value
  };
}

/// One memo cell. Nothing is ever evicted; [gen] is the left-recursion
/// generation stamp, exactly as in the frozen `MemoEntry`.
class _Cell {
  _Ways ways = _none;
  bool inPath = false, foundLR = false, done = false;
  int gen = -1;
}

// ---------------------------------------------------------------------------

class SuperDot3 {
  SuperDot3({required Map<String, Clause> rules, required this.topRuleName})
      : rules = {} {
    for (final e in rules.entries) {
      this.rules[e.key.startsWith('~') ? e.key.substring(1) : e.key] = e.value;
    }
  }

  final Map<String, Clause> rules;
  final String topRuleName;

  /// Cost of the last [recover]; -1 if no whole-input tree was reachable.
  int lastCost = -1;

  String _in = '';

  /// Left-recursion generation stamps, one array per memo family, because the
  /// pure tables outlive the round tables and must not be invalidated by them.
  List<int> _pg = const [], _rg = const [];

  /// Memo tables for a clause's own ways, and for a clause's ways WITH A LEADING
  /// REPAIR. Two tables because they answer different questions at the same
  /// (clause, position), and the second is what a sequence element needs.
  ///
  /// AND TWO FAMILIES OF THEM. `_pc`/`_pe` hold the BUDGET-0 answer -- the frozen
  /// parser's -- which cannot depend on the budget, so they are solved once per
  /// input and shared by every round. `_mc`/`_me` hold the answer under this
  /// round's budget and are cleared when it changes.
  final Map<Clause, Map<int, _Cell>> _pc = {}, _pe = {}, _mc = {}, _me = {};

  // -------------------------------------------------------------------------
  // I36: the unique minimal witness.
  //
  // `(minimum length, the unique string of that length)`. A null string means
  // the minimum is reached by more than one string (or by none), and synthesis
  // would therefore be a CHOICE -- which is exactly what must never happen.
  // Recursive rules need a least fixed point, so lengths start at "unreachable"
  // and the pass repeats until nothing moves.

  static const int _inf = 1 << 29;
  final Map<Clause, (int, String?)> _wit = {};
  bool _witReady = false;
  bool _moved = false;

  void _solveWitnesses() {
    if (_witReady) return;
    _witReady = true;
    do {
      _moved = false;
      for (final body in rules.values) {
        _visitWitness(body, {});
      }
    } while (_moved);
  }

  /// Least fixed point: a clause already on the current path is "unreachable so
  /// far", which is what makes a recursive rule converge upward to its true
  /// minimum rather than declaring itself free.
  void _visitWitness(Clause c, Set<Clause> path) {
    if (!path.add(c)) return;
    (int, String?) v;
    switch (c) {
      case Str s:
        v = (s.text.length, s.text);
      case Char ch:
        v = (ch.char.length, ch.char);
      case CharSet cs:
        // Unique only when the set names exactly one code unit. An inverted set
        // names 65535 of them, so it never qualifies.
        final one = !cs.inverted &&
            cs.ranges.length == 1 &&
            cs.ranges[0].$1 == cs.ranges[0].$2;
        v = (1, one ? String.fromCharCode(cs.ranges[0].$1) : null);
      case AnyChar _:
        v = (1, null); // 65536 choices
      case Nothing _:
        v = (0, '');
      case Seq s:
        var n = 0;
        final w = StringBuffer();
        String? text = '';
        for (final sub in s.subClauses) {
          _visitWitness(sub, path);
          final (ln, t) = _wit[sub] ?? (_inf, null);
          n += ln;
          if (t == null) {
            text = null;
          } else {
            w.write(t);
          }
        }
        v = (n > _inf ? _inf : n, text == null ? null : w.toString());
      case First f:
        var best = _inf;
        String? text;
        var many = false;
        for (final sub in f.subClauses) {
          _visitWitness(sub, path);
          final (ln, t) = _wit[sub] ?? (_inf, null);
          if (ln < best) {
            best = ln;
            text = t;
            many = t == null;
          } else if (ln == best && ln < _inf) {
            // A second way to reach the same minimal length: unique only if it
            // spells the same string.
            if (t == null || t != text) many = true;
          }
        }
        v = (best, many ? null : text);
      case Repetition r:
        _visitWitness(r.subClause, path);
        final (ln, t) = _wit[r.subClause] ?? (_inf, null);
        // `e*` is minimally empty; `e+` is minimally one `e`.
        v = r.requireOne ? (ln, t) : (0, '');
      // These three are minimally empty, but their BODIES still need solving:
      // every clause the engine may be asked to FILL has to be reachable from
      // this walk, and a `,` that lives inside `(... ',' ...)?` is otherwise
      // never visited at all.
      case Optional o:
        _visitWitness(o.subClause, path);
        v = (0, '');
      case FollowedBy f:
        _visitWitness(f.subClause, path);
        v = (0, ''); // zero-width; nothing to synthesise
      case NotFollowedBy n:
        _visitWitness(n.subClause, path);
        v = (0, '');
      case Ref r:
        final body = rules[r.ruleName];
        if (body == null) {
          v = (_inf, null);
        } else {
          _visitWitness(body, path);
          v = _wit[body] ?? (_inf, null);
        }
      default:
        v = (_inf, null);
    }
    path.remove(c);
    final old = _wit[c];
    if (old == null || old.$1 != v.$1 || old.$2 != v.$2) {
      _wit[c] = v;
      _moved = true;
    }
  }

  /// The text a FILL of [c] would stand for, or null if synthesis would be a
  /// choice. Zero-width clauses return `''`, which fills for free.
  String? _witness(Clause c) {
    final v = _wit[c];
    if (v == null || v.$1 >= _inf) return null;
    return v.$2;
  }

  // -------------------------------------------------------------------------
  // Entry points.

  /// Recover a whole-input tree over [s]. The input is never modified.
  ///
  /// The top rule is required to span the whole input: anything it does not
  /// explain is a trailing SKIP and is charged for. That is what makes the cost
  /// a GLOBAL objective, and what stops a construct closing early and leaving
  /// the rest as somebody else's problem.
  MatchResult recover(String s) {
    _in = s;
    _solveWitnesses();

    final top = rules[topRuleName];
    if (top == null) throw ArgumentError('Rule "$topRuleName" not found');

    // Budget 0 forbids repair outright, so the first round is exactly the frozen
    // parser and undamaged input never pays for a search it does not need. Each
    // later round allows one more character, and THE FIRST ROUND THAT SUCCEEDS
    // IS OPTIMAL BY CONSTRUCTION: it explored every reading worth no more than
    // its budget, so nothing cheaper was missed. Stepping by one rather than
    // doubling is what keeps the successful round's budget at the true cost
    // instead of up to twice it, and cost is small once a repair is charged only
    // for what it captures.
    final cap = 2 * s.length + (_witness(top)?.length ?? 0) + 1;
    _pc.clear();
    _pe.clear();
    _pg = List.filled(s.length + 1, 0);
    for (_budget = 0; _budget <= cap; _budget = _budget == 0 ? 1 : _budget * 2) {
      _mc.clear();
      _me.clear();
      _rg = List.filled(s.length + 1, 0);

      _Way? best;
      for (final e in _element(top, 0).entries) {
        final trail = s.length - e.key;
        final cand = _Way(
            e.value.cost + trail,
            e.value.got,
            e.value.synth,
            trail > 0
                ? _N(_T.leaf(SyntaxError(pos: e.key, len: trail)),
                    e.value.nodes)
                : e.value.nodes);
        if (cand.cost <= _budget && _beats(cand, best)) best = cand;
      }
      if (best != null) {
        lastCost = best.cost;
        return Match(null, 0, s.length, subClauseMatches: _list(best.nodes));
      }
    }
    lastCost = -1;
    return SyntaxError(pos: 0, len: s.length);
  }

  /// The repair cost of [s], or -1 if no whole-input tree was reachable.
  int recoverCost(String s) {
    recover(s);
    return lastCost;
  }

  // -------------------------------------------------------------------------
  // The matcher. Both entry points memoise on (clause, position), because a
  // clause's ways no longer depend on anything else.

  /// A clause's own ways, with left recursion handled exactly as the frozen
  /// `MemoEntry` handles it: the frame that ENTERED the cycle iterates, the
  /// frame that CLOSED it only signals.
  _Ways _clause(Clause c, int pos) =>
      _fix(_budget == 0 ? _pc : _mc, c, pos, _expand);

  /// A clause's ways WITH A LEADING REPAIR allowed -- what a sequence element,
  /// a repetition iteration or an optional body needs.
  _Ways _element(Clause c, int pos) =>
      _fix(_budget == 0 ? _pe : _me, c, pos, _repair);

  /// WHAT THE FROZEN PARSER SAYS AT (c, pos), asked at any budget. Every way it
  /// can contain costs 0, so a non-empty answer IS a repair-free reading.
  ///
  /// I39: A PEG DECISION COMMITS TO A CHOICE, NOT TO AN ENDING. Ordered choice,
  /// `e?` preferring its body, an element preferring a real match -- each turns
  /// on whether a repair-free reading EXISTS, and this answers that WITHOUT
  /// collapsing the map of endings. Collapsing it is m79's error one level up:
  /// it discards the endings the enclosing clause needed, and the search buys
  /// them back at a far higher price. Measured, collapsing turned `[2,33true]`
  /// from a cost-1 filled comma into a cost-2 reading of the whole document as
  /// one string, and drove single-character transpositions to costs of 24 and 33.
  ///
  /// ASKING IT FIRST IS ALSO THE WHOLE OF THE ENGINE'S SPEED, and that took a
  /// measurement. `_first` used to evaluate each alternative AT THE FULL BUDGET
  /// before discovering a later one was free -- so at every position where a
  /// `Value` is a `Number`, it ran a complete repair search inside `String` and
  /// threw it away. The cap that makes recovery affordable was being defeated
  /// inside every ordered choice in the grammar. Measured on the battery (519
  /// mutants, everything else held fixed, `_ab80.dart`): 5033 ms -> 3195 ms,
  /// 1.58x, with an identical cost sum of 975, so it is not an approximation --
  /// a free reading beats every repaired one under [_beats] anyway, so the
  /// repair search it skips could never have won.
  _Ways _pure(Clause c, int pos) {
    final save = _budget;
    _budget = 0;
    final r = _clause(c, pos);
    _budget = save;
    return r;
  }

  _Ways _fix(Map<Clause, Map<int, _Cell>> memo, Clause c, int pos,
      _Ways Function(Clause, int) body) {
    if (pos > _in.length) return _none;
    final gen = _budget == 0 ? _pg : _rg;
    final cell = (memo[c] ??= {}).putIfAbsent(pos, _Cell.new);
    if (cell.inPath) {
      // Second visit with no result yet: the fixed point of a left recursive
      // cycle. Signal the ancestral frame and answer with the seed so far.
      cell.foundLR = true;
      return cell.ways;
    }
    if (cell.done && cell.gen == gen[pos]) return cell.ways;
    cell
      ..inPath = true
      ..ways = _none
      ..foundLR = false;
    while (true) {
      cExpand++;
      final tag = '${identical(memo, _pc) ? 'pc' : identical(memo, _pe) ? 'pe' : identical(memo, _mc) ? 'mc' : 'me'}@$_budget';
      cFam[tag] = (cFam[tag] ?? 0) + 1;
      (cCells[tag] ??= {}).add('${c.hashCode}:$pos');
      final r = body(c, pos);
      if (!_grows(r, cell.ways)) break;
      cell.ways = r;
      if (!cell.foundLR) break;
      cell.gen = ++gen[pos];
    }
    cell
      ..inPath = false
      ..done = true
      ..gen = gen[pos];
    return cell.ways;
  }

  /// Does [a] strictly improve on [b] anywhere? This is the left-recursion
  /// termination test -- the frozen parser's "the new result must be strictly
  /// longer", lifted to a map of end positions.
  bool _grows(_Ways a, _Ways b) {
    for (final e in a.entries) {
      if (_beats(e.value, b[e.key])) return true;
    }
    return false;
  }

  // -------------------------------------------------------------------------

  _Ways _expand(Clause c, int pos) {
    switch (c) {
      case Ref r:
        final body = rules[r.ruleName];
        if (body == null) throw ArgumentError('Rule "${r.ruleName}" not found');
        return _wrap(r, pos, _clause(body, pos));

      case Seq s:
        return _wrap(s, pos, _seq(s.subClauses, pos));

      case First f:
        return _first(f, pos);

      case Repetition r:
        // I41: POSSESSIVENESS IS HOW PEG RESOLVES A REPETITION WHEN NOTHING IS
        // BROKEN, AND IT HAS NO AUTHORITY ONCE THE PARSE HAS ALREADY FAILED.
        // Dropping the shorter free chains is right at budget 0 -- it is what
        // makes this engine PEG rather than a general parser, and the deepening
        // loop runs budget 0 FIRST, so wherever a pure parse exists it is still
        // the answer. But at budget 0 those chains are also the only thing
        // standing between a repair and the honest reading: in `{"a:1,"bc":...}`
        // the free chain runs `"a:1,"` straight through the delimiter, and
        // stopping at `"a"` and filling the quote is then unreachable, so the
        // engine escapes the quote instead and keeps the wrong key. Where a
        // repair is in play, stopping early is a candidate like any other and
        // the cost function decides between them.
        return _wrap(
            r, pos, _budget == 0 ? _possessive(_rep(r, pos)) : _rep(r, pos));

      case Optional o:
        return _opt(o, pos);

      case FollowedBy f:
        // A4: predicates read the ORIGINAL input, at cost 0.
        if (_pure(f.subClause, pos).isNotEmpty) {
          return {pos: _Way(0, 0, false, _N(_T.leaf(Match(f, pos, 0)), null))};
        }
        // The evidence does not show it. If the grammar DETERMINES what belongs
        // here (I36) the guard may be discharged by asserting it; otherwise the
        // guard stands and the match fails.
        final w = _witness(f.subClause);
        if (w == null || w.length > _budget) return _none;
        return {pos: _Way(w.length, 0, true, _N(_T.leaf(Filled(f, pos, w)), null))};

      case NotFollowedBy n:
        // A negative guard can only be satisfied by REMOVING evidence, and
        // removal is a SKIP, which belongs to the enclosing sequence. There is
        // nothing to synthesise, so this stays exactly pure PEG.
        if (_pure(n.subClause, pos).isNotEmpty) {
          return _none;
        }
        return {pos: _Way(0, 0, false, _N(_T.leaf(Match(n, pos, 0)), null))};

      case Terminal t:
        final m = _term(t, pos);
        return m == null
            ? _none
            : {
                pos + m.len: _Way(0, m.len, false, _N(_T.leaf(m), null))
              };

      default:
        return _none;
    }
  }

  /// Terminals, matched against the original input. Deliberately a copy of the
  /// frozen library's terminal semantics rather than a call into it, so the
  /// engine owns every decision it makes about the evidence.
  Match? _term(Terminal t, int pos) {
    switch (t) {
      case Str s:
        if (pos + s.text.length > _in.length) return null;
        for (var i = 0; i < s.text.length; i++) {
          if (_in.codeUnitAt(pos + i) != s.text.codeUnitAt(i)) return null;
        }
        return Match(s, pos, s.text.length);
      case Char c:
        if (pos >= _in.length) return null;
        return _in.codeUnitAt(pos) == c.char.codeUnitAt(0)
            ? Match(c, pos, 1)
            : null;
      case CharSet cs:
        if (pos >= _in.length) return null;
        final u = _in.codeUnitAt(pos);
        var inSet = false;
        for (final (lo, hi) in cs.ranges) {
          if (u >= lo && u <= hi) {
            inSet = true;
            break;
          }
        }
        return (cs.inverted ? !inSet : inSet) ? Match(cs, pos, 1) : null;
      case AnyChar _:
        return pos < _in.length ? Match(t, pos, 1) : null;
      case Nothing _:
        return Match(t, pos, 0);
      default:
        return null;
    }
  }

  /// Re-parent every way's nodes under one node for [c].
  _Ways _wrap(Clause c, int pos, _Ways w) => {
        for (final e in w.entries)
          e.key: _Way(
              e.value.cost,
              e.value.got,
              e.value.synth, _N(_T.node(c, pos, e.value.nodes), null)),
      };

  // -------------------------------------------------------------------------

  /// A sequence is a FOLD over the ways map: carry every end position the prefix
  /// can reach, and extend each of them by the next element. This is the whole
  /// of the search, and it is where the enclosing clause's need for a particular
  /// ending finally meets the sub-parse that can supply it.
  _Ways _seq(List<Clause> subs, int pos) {
    var ways = <int, _Way>{pos: _empty};
    for (final sub in subs) {
      final next = <int, _Way>{};
      for (final e in ways.entries) {
        final w = e.value;
        for (final x in _element(sub, e.key).entries) {
          _put(next, x.key,
              _extend(w, x.value, _cat(w.nodes, x.value.nodes)));
        }
      }
      if (next.isEmpty) return _none;
      ways = next;
    }
    return ways;
  }

  /// Ordered choice. A cost-0 alternative is what pure PEG returns, so the FIRST
  /// alternative that has one is taken alone and the rest are never tried. Only
  /// where no alternative is free does the choice open, and then every ending
  /// every alternative can reach is offered to the enclosing clause.
  ///
  /// I43: A REPAIR MAY NOT MAKE THE CHOICE. I36 says synthesis must not choose
  /// the TEXT; this says it must not choose the SHAPE either. A way that OPENS
  /// with a FILL was selected by text that is not there, so here -- and only here,
  /// because this is the only construct in PEG that decides between shapes -- it
  /// is refused. Synthesis may still COMPLETE an alternative the evidence has
  /// already committed to, which is every case that matters:
  ///     `[2,33true]`   fill the `,`; the list was already a list      ALLOWED
  ///     `{"a":1`       fill the `}`; the object was already an object ALLOWED
  ///     `{"e":ull}`    fill a `"` to make `ull` a String              REFUSED
  ///     `{"a"1:...}`   fill a `\` to make the `"` escape content      REFUSED
  ///
  /// Measured, the last two were the battery's largest failure buckets: the `\`
  /// alone is 172 of 519 mutants, because one invented character costs 1 and buys
  /// the reclassification of a real delimiter into string content. No cost model
  /// prices that correctly -- I tried, and the character it captures is matched by
  /// a PRECISE terminal, so there is nothing to charge for. It is not a pricing
  /// error, it is a category error, and the fix is a prohibition.
  _Ways _first(First f, int pos) {
    // The pure table DECIDES THE CHOICE; the chosen alternative is then returned
    // at the full budget, because I39 says committing to a choice is not
    // committing to an ending.
    for (final a in f.subClauses) {
      if (_pure(a, pos).isNotEmpty) return _wrap(f, pos, _clause(a, pos));
    }
    if (_budget == 0) return _none;
    final out = <int, _Way>{};
    for (final a in f.subClauses) {
      for (final e in _clause(a, pos).entries) {
        if (!e.value.synth) _put(out, e.key, e.value);
      }
    }
    return _wrap(f, pos, out);
  }

  /// Repetition as reachability: every end position an iteration chain can
  /// reach, cheapest first. It terminates because an iteration must explain
  /// evidence, so it must advance.
  _Ways _rep(Repetition r, int pos) {
    final reach = <int, _Way>{pos: _empty};
    var frontier = <int>{pos};
    while (frontier.isNotEmpty) {
      final next = <int>{};
      for (final e in frontier) {
        final w = reach[e]!;
        for (final x in _element(r.subClause, e).entries) {
          // A repetition exists to consume evidence. An iteration that explains
          // no characters is not evidence of a repetition -- and it is also what
          // would make a fillable body loop forever. One rule retires both, and
          // it subsumes the frozen parser's zero-length guard.
          if (x.value.got == 0) continue;
          final cand = _extend(w, x.value, _cat(w.nodes, x.value.nodes));
          if (cand.cost <= _budget && _beats(cand, reach[x.key])) {
            reach[x.key] = cand;
            next.add(x.key);
          }
        }
      }
      frontier = next;
    }
    // `e+` needs one iteration, and an iteration always advances, so the start
    // position is exactly the zero-iteration way. Where the body is fillable the
    // enclosing `_element` supplies the FILL.
    if (r.requireOne) reach.remove(pos);
    return reach;
  }

  /// `e?`. PEG prefers the body, so a free body retires the empty alternative.
  _Ways _opt(Optional o, int pos) {
    if (_pure(o.subClause, pos).isNotEmpty) {
      return _wrap(o, pos, _element(o.subClause, pos));
    }
    if (_budget == 0) return _wrap(o, pos, {pos: _empty});
    final out = {..._element(o.subClause, pos)};
    _put(out, pos, _empty);
    return _wrap(o, pos, out);
  }

  // -------------------------------------------------------------------------

  /// THE ONLY PLACE A REPAIR IS INTRODUCED. Three ways to satisfy a required
  /// clause: match it outright; SKIP characters that explain nothing and then
  /// match it; or, if and only if the grammar determines the text (I36), FILL
  /// it. Every ending any of them reaches is returned, because which one is
  /// right is not knowable here.
  ///
  /// A cost-0 direct match commits, so on undamaged input this is exactly
  /// `clause.match(parser, pos)` and costs the same.
  _Ways _repair(Clause sub, int pos) {
    if (_budget == 0) return _pure(sub, pos);
    final direct = _clause(sub, pos);
    if (_pure(sub, pos).isNotEmpty) return direct;

    final out = {...direct};
    for (var k = 1; k <= _budget && pos + k <= _in.length; k++) {
      final skip = SyntaxError(pos: pos, len: k);
      for (final e in _clause(sub, pos + k).entries) {
        _put(
            out,
            e.key,
            _Way(k + e.value.cost, e.value.got, e.value.synth,
                _cat(_N(_T.leaf(skip), null), e.value.nodes)));
      }
    }

    final w = _witness(sub);
    if (w != null && w.length <= _budget) {
      _put(out, pos, _Way(w.length, 0, true, _N(_T.leaf(Filled(sub, pos, w)), null)));
    }
    return out;
  }
}
