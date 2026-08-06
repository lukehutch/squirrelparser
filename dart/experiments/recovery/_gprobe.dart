// m62 -- THE MEMO HOLDS FACTS; THE STACK HOLDS THE PASS: m60's recurrence,
// ladder, budget and walk, with the continuation lifted OUT of the memo entry
// onto one explicit frame stack. (Codex's ranked-first candidate of the
// twentieth occasion, built and measured here.)
//
//   I18 THE ENTRY IS A FACT; THE PASS IS A FRAME. Of m60's ten entry fields,
//       six describe the pass in flight (budget, pc, headEntry, foundCycle,
//       improved, parent) and only three describe durable knowledge (value,
//       settledBudget, version). Move the pass onto an explicit DFS stack:
//       the stack's adjacency IS the parent pointer, `running` derives from
//       membership (activeDepth >= 0), and a descendant that reaches an
//       active entry finds the ancestral FRAME by index and sets ITS
//       foundCycle bit -- the same O(1) descendant-to-ancestor message, with
//       the transient half of the coroutine no longer stored per cell. The
//       memo table keeps facts; the chain keeps state; neither pays for the
//       other.
//
// Everything else is m60 verbatim: the curried normal form; I2's lies with
// deletion as SUB on Nothing; I3's oracle veto; I6/I7's obligation channel;
// I5's verified witness; Delta as the pair (cost, regret) lexicographic; the
// budget as A3's filter, the deepening ladder, the budget-zero oracle walk,
// and the derived ceiling `n + fabricate(goal)` with its predicate tiers.
//
// PARAMETERS: NONE. HEURISTICS: shortest-head witness tie-break (output),
// I4's fusion (work), whole-input span on witness failure (presentation).
//
// ===========================================================================
// m75 / I32 -- THE REPAIR IS SCAFFOLDING; THE TREE IS OVER THE INPUT.
//
// m74 treated the repaired STRING as the deliverable: splice the edits, parse
// the result, keep THAT tree, map its positions back. So every fabricated
// character became a node -- asked to repair `[2,33,ture]` it returns a boolean
// the author never wrote, with `ture` gone. Measured over the 519-mutant
// battery, m74 puts 535 such nodes into its trees (`_tree75.dart`).
//
// The repair is not the answer. It only says what shape the recursive descent
// WOULD have taken had the document been well-formed; the answer is that shape
// laid over the ORIGINAL input. The search is untouched -- the witness is read
// out differently:
//
//   input the grammar cannot use   ->  a SyntaxError span, in the tree, at the
//                                      structural position where it was found
//   grammar the input cannot fill  ->  a ZERO-WIDTH span at that position; the
//                                      demanded symbol is NOT written, because
//                                      a wide class cannot say which symbol
//   everything else                ->  the ORACLE's own subtree, verbatim
//
// `_xOf` and `_reindex` go with the remapping. Every span is now an interval of
// the real input: 519/519 tile it, 519/519 cover it, 0 unsupported nodes. This
// is what `SkipResult`'s docstring (skip_recovery.dart:91-96) has always
// promised and no engine delivered -- unparseable regions as SyntaxError
// CHILDREN of the tree.
//
// WHAT THIS DOES NOT DO, stated because it was tried and measured: it does not
// delete the certificate. `_repaired`/`_spelling` survive to put the repair to
// the pure parser for a YES/NO -- their text never reaches the tree. Removing
// that check made m75 answer `2, verified` on inputs whose true cost is -1,
// wrong on 28 of 31 strings over `'a'* "ab"`, a grammar with an EMPTY language
// (`_m75diff.dart`). The obligations are still approximated to one character,
// so the chase is not yet a membership proof, and the parse cannot go until
// they are exact.
// ===========================================================================
import 'dart:math' as math;
import 'package:squirrel_parser/squirrel_parser.dart';
import 'final_table.dart' show buildSetup;
import 'package:squirrel_parser/src/recovery/skip_recovery.dart'
    show SkipResult, MissingObligation;


/// log2 of the code-point alphabet, in millibits: what a FAB asserts.
const _widestClass = 20087;

// ---- the tie-break, replacing regret --------------------------------------
//
// Among repairs that already tie on EDIT COUNT, two things can still separate
// them, and they are not the same thing and cannot be added:
//
//   INVENTION -- bits the repair asserts that the input did not justify. A
//     fabricated character drawn from class C costs log2|C|; if C is a
//     singleton the grammar FORCED it and the repair invented nothing.
//   LOSS      -- input characters the repair does not preserve.
//
// There is no exchange rate between a bit and a character, and inventing one
// would be exactly the arbitrary constant this engine is not allowed to have.
// So they are ordered, not summed, and the order is forced rather than
// chosen: an invented character is unfalsifiable -- nothing downstream can
// tell it from real data -- while a destroyed character is still sitting in
// the input the caller already holds. Invention corrupts; loss only omits.
//
//   (edits, invention, loss)  lexicographic
//
// Packed into the one secondary slot as `invention * (inputLen+1) + loss`,
// since loss is bounded by the input length.

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
  _Term(super.id, super.orig, this.editable, this.demands);
  final bool editable;
  final int demands;
}

class _Cons extends _Node {
  _Cons(super.id, super.orig);
  late final _Node head;
  late _Node tail;
}

class _Alt extends _Node {
  _Alt(super.id, super.orig);
  late final List<_Node> alts;

  /// I27. `guards[i]` is what the character at this position owes because
  /// branches `0..i-1` had to fail here for branch `i` to be reached. Filled
  /// on first use, once desugaring has finished writing `alts`.
  List<int>? guards;
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

  /// How long the head list was when this frame last read it. Ordering costs
  /// one thing appending never could: a split can land BEHIND a parked
  /// cursor, where an appended one was always ahead of it.
  int headLen = -1;
}

class SuperDot3 {
  final Map<String, Clause> rules;
  final String topRuleName;
  SuperDot3({required this.rules, required this.topRuleName});

  late final Map<String, Clause> _rules = {
    for (final e in rules.entries)
      (e.key.startsWith('~') ? e.key.substring(1) : e.key): e.value,
  };

  // ---- building the normal form (m59's, verbatim) --------------------------

  final Map<Clause, _Node> _nodes = {};
  final List<Clause> _terminals = [];
  int _nodeCount = 0;

  _Node _term(Clause clause, bool editable, int demands) {
    if (editable) _terminals.add(clause);
    return _Term(_nodeCount++, clause, editable, demands);
  }

  late final _Node _eps = _term(const Nothing(), false, _free);

  _Cons _selfLoop(_Node head, Clause orig) {
    final loop = _Cons(_nodeCount++, orig)..head = head;
    return loop..tail = loop;
  }

  late final _Node _junk =
      _selfLoop(_term(const Nothing(), true, _free), const Nothing());

  _Node _wrap(_Node reader, Clause orig) => _Cons(_nodeCount++, orig)
    ..head = _junk
    ..tail = reader;

  static const int _lastCodeUnit = 0xFFFF;

  List<(int, int)>? _oneCharClass(Clause clause,
          [Set<String> seen = const {}]) =>
      switch (clause) {
        AnyChar() => const [(0, _lastCodeUnit)],
        Char(:final char) => [(char.codeUnitAt(0), char.codeUnitAt(0))],
        Str(:final text) when text.length == 1 => [
            (text.codeUnitAt(0), text.codeUnitAt(0))
          ],
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

  static List<(int, int)> _intersect(List<(int, int)> a, List<(int, int)> b) =>
      [
        for (final (alo, ahi) in a)
          for (final (blo, bhi) in b)
            if (alo <= bhi && blo <= ahi)
              (math.max(alo, blo), math.min(ahi, bhi)),
      ];

  // ---- I6/I7: the obligation lattice (m59's, verbatim) ---------------------

  static const int _free = -1;
  static const int _endMark = -1;
  final List<List<(int, int)>> _classes = [];
  final Map<String, int> _classIndex = {};

  int _intern(List<(int, int)> ranges) {
    final norm = <(int, int)>[];
    for (final r in [...ranges]..sort((a, b) => a.$1 - b.$1)) {
      if (r.$2 < r.$1) continue;
      if (norm.isNotEmpty && r.$1 <= norm.last.$2 + 1) {
        if (r.$2 > norm.last.$2) norm[norm.length - 1] = (norm.last.$1, r.$2);
      } else {
        norm.add(r);
      }
    }
    final key = norm.map((r) => '${r.$1}-${r.$2}').join(',');
    return _classIndex[key] ??= (_classes..add(norm)).length - 1;
  }

  int _meet(int a, int b) => a == _free
      ? b
      : b == _free
          ? a
          : _intern(_intersect(_classes[a], _classes[b]));

  /// An obligation no character can discharge. `_free` is a sentinel, not an
  /// index, so it can never be the empty class.
  bool _unmeetable(int c) => c != _free && _classes[c].isEmpty;

  bool _permits(int c, List<(int, int)>? emits) =>
      c == _free ||
      (emits != null && _intersect(emits, _classes[c]).isNotEmpty);

  /// Does obligation `c` admit the character `ch`? `_endMark` is the character
  /// past the end, which only a lookahead complement contains, so asking about
  /// it is asking whether the obligation can be discharged by stopping.
  bool _has(int c, int ch) {
    if (c == _free) return true;
    for (final (lo, hi) in _classes[c]) {
      if (ch >= lo && ch <= hi) return true;
    }
    return false;
  }

  /// I27: WHAT AN ORDERED CHOICE OWES IS A FORWARD OBLIGATION, NOT A BACKWARD
  /// CHECK. Branch `i` is legal exactly where branches `0..i-1` fail, so a
  /// branch that reads one character hands the NEXT reader the complement of
  /// that character's class, and the obligation rides in the memo key.
  final Map<Clause, int> _notFirstOf = {};

  int _notFirst(Clause branch, int carried) => _meet(
      carried,
      _notFirstOf[branch] ??= switch (_oneCharClass(branch)) {
        final looked? =>
          _intern([..._complement(looked), (_endMark, _endMark)]),
        null => _free,
      });

  /// The running obligation down an `_Alt`'s branch list, cached per node.
  ///
  /// A branch that reads one character can never violate a guard its own class
  /// already satisfies -- `Escape <- '\"' / '\\\\' / '/' / ...` is nine of those --
  /// and since the obligation is part of the memo key, carrying a guard that
  /// cannot fire splits every cell below it for nothing. Dropping it is not an
  /// approximation: the branch emits and reads only from its own class, so the
  /// guard is implied by taking the branch at all.
  List<int> _guardsOf(_Alt node) {
    final known = node.guards;
    if (known != null) return known;
    final g = <int>[];
    var acc = _free;
    for (final a in node.alts) {
      final emits = acc == _free ? null : _oneCharClass(a.orig);
      final e = emits == null ? _free : _intern(emits);
      g.add(e != _free && _meet(acc, e) == e ? _free : acc);
      acc = _notFirst(a.orig, acc);
    }
    return node.guards = g;
  }

  List<(int, int)>? _looks(Clause clause) => switch (clause) {
        FollowedBy(:final subClause) => _oneCharClass(subClause),
        NotFollowedBy(:final subClause) => switch (_oneCharClass(subClause)) {
            final looked? => [..._complement(looked), (_endMark, _endMark)],
            null => null,
          },
        _ => null,
      };

  Clause? _fuse(Clause lookahead, Clause reader) {
    if (reader is! Terminal) return null;
    final reads = _oneCharClass(reader);
    if (reads == null) return null;
    final looks = _looks(lookahead);
    return looks == null ? null : CharSet(_intersect(looks, reads));
  }

  _Node _cons(List<Clause> parts, Clause orig) {
    final fused = <Clause>[];
    for (var i = parts.length - 1; i >= 0; i--) {
      final f = fused.isEmpty ? null : _fuse(parts[i], fused.first);
      if (f == null) {
        fused.insert(0, parts[i]);
      } else {
        fused[0] = f;
      }
    }
    var node = _eps;
    for (var i = fused.length - 1; i >= 0; i--) {
      node = _Cons(_nodeCount++, i == 0 ? orig : Seq(fused.sublist(i)))
        ..head = _node(fused[i])
        ..tail = node;
    }
    return node;
  }

  /// The clauses the GRAMMAR contains, by identity. Desugaring invents spine
  /// nodes -- `Seq(sublist)` at each fusion step, `_junk`, `_eps`, the goal
  /// wrapper -- and those are plumbing, not structure. A tree node is opened
  /// exactly when the clause behind it is one the grammar author wrote, which
  /// is precisely the set that reaches `_node`.
  final Set<Clause> _real = Set<Clause>.identity();

  _Node _node(Clause clause) {
    _real.add(clause);
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
      final looks = _looks(clause);
      final leaf = _term(clause, accepts?.isNotEmpty ?? clause is Terminal,
          looks == null ? _free : _intern(looks));
      node = looks == null ? _wrap(leaf, clause) : leaf;
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
        if (node.demands != _free) return [_meet(c, node.demands), 0];
        final emits = node.editable ? _oneCharClass(node.orig) : null;
        if (emits != null && emits.isNotEmpty) {
          return _permits(c, emits) ? [_free, 1] : const [];
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
        if (_has(top[i], _endMark) && top[i + 1] < best) best = top[i + 1];
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
  late List<int> _versionAtPos;
  final Map<Clause, int> _widths = {};
  MatchResult? _clean;
  // I29's payoff, in one declaration: the goal needs only its KEY. Cost and
  // regret used to be carried because `_build` had to re-derive which child
  // produced them; a cell holds exactly one triple per key, so the reason
  // reads them back for free and the chase never asks.
  int _steps = 0, _goalKey = -1;
  int lastCost = -1, lastRegret = -1, lastSteps = -1;
  bool lastVerified = false;

  /// I28: false on the cheap pass, true when the guards are being enforced.
  bool _guarded = false;
  int get lastCells => _cells.length;
  double get lastPerCell => _cells.isEmpty ? 0 : _steps / _cells.length;

  int _widthOf(Clause clause) => _widths[clause] ??= _width(clause);

  /// Radix for packing (invention, loss): one more than the largest loss.
  int get _lossSpan => _inputLen + 1;


  // ---- the value: triples, written in place (m59's, verbatim) --------------

  /// I29. Every value in this engine is written by this one funnel, and it
  /// writes only on a strict improvement in `(cost, regret)`. At that instant
  /// the thing that produced the value is a local variable, so keep it: one
  /// more int, and the witness stops having to be searched for. Acyclicity is
  /// then a proof rather than a check -- every edge adds a non-negative
  /// increment, so a cycle in the back-pointers would force every increment to
  /// zero and every value equal, which contradicts the strict drop that the
  /// cell written LAST on that cycle must have made.
  /// I30, and I31 is what forces it here. A new answer goes in at its place in
  /// SPLIT order -- by end, then by obligation -- and not at the back, because
  /// the list is what a `_Cons` offers as head candidates and PEG takes the
  /// reading a recursive-descent parser reaches first: the SHORTEST head, not
  /// the cheapest. m73 could leave the list in arrival order because `_build`
  /// re-sorted the candidates when it reconstructed; the chase has no
  /// reconstruction to sort in, so the order the search wrote IS the answer,
  /// and shape reads 513 instead of 517 if it is wrong. Split order is a TOTAL
  /// order computable from the key alone, so the walk that looks for the key
  /// bisects, and a search that misses has stopped exactly where the new key
  /// belongs -- the ordering pays for its own lookup.
  bool _keepBest(List<int> out, int key, int cost, int reg, int why) {
    final end = _endOf(key);
    var lo = 0, hi = out.length >> 2;
    while (lo < hi) {
      final mid = (lo + hi) >> 1, k = out[mid << 2], e = _endOf(k);
      if (e < end || (e == end && k < key)) {
        lo = mid + 1;
      } else if (k == key) {
        final i = mid << 2;
        if (out[i + 1] < cost || (out[i + 1] == cost && out[i + 2] <= reg)) {
          return false;
        }
        out[i + 1] = cost;
        out[i + 2] = reg;
        out[i + 3] = why;
        return true;
      } else {
        hi = mid;
      }
    }
    out.insertAll(lo << 2, [key, cost, reg, why]);
    return true;
  }

  // I29's alphabet of reasons. A NEGATIVE reason is a leaf shape; a
  // non-negative one is data -- an alternation's winning branch index, or the
  // head key that fixed a sequence's split -- and which of the two it is the
  // node decides, not the number. In order: the oracle's own match settles this
  // cell; a lookahead obligation, no text at all; spend the characters under
  // `key` on this leaf; write this leaf's spelling, reading nothing; the
  // repetition declined to go round again; never written, so the chase has
  // walked off the table.
  static const int _wPure = -1, _wDemand = -2, _wSub = -3;
  static const int _wFab = -4, _wStop = -5, _wNone = -6;

  int _key(int end, int owed) => ((owed + 1) << _posShift) | end;
  int _endOf(int key) => key & (_span - 1);
  int _oweOf(int key) => (key >> _posShift) - 1;

  final Map<int, _Entry> _cells = {};
  int _posShift = 0, _span = 0;

  _Entry _entryAt(_Node node, int pos, int c) {
    final k = (((c + 1) * (_nodeCount + 1) + node.id) << _posShift) | pos;
    return _cells[k] ?? (_cells[k] = _Entry(node, pos, c));
  }

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

  /// Ask for `e` at `budget`, which is the only thing any of the three child
  /// requests ever does: an entry already on the chain is a left-recursive
  /// cycle, so tell that frame and take whatever it has so far rather than
  /// wait; an unsettled one parks this frame behind it and answers `true`.
  bool _demand(_Entry e, int budget) {
    if (e.activeDepth >= 0) {
      _stack[e.activeDepth].foundCycle = true; // the LR seed
    } else if (!_settled(e, budget)) {
      _push(e, budget);
      return true; // park: the loop steps the new top next
    }
    return false;
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
          // I27 again, and this is where it leaks if it is applied only to the
          // search. The walk is edit-free WITHIN this subtree, so the oracle
          // settles where the star ends -- but the TAIL is a different entry
          // with its own budget, and it can still fabricate at exactly the
          // position the star claimed to stop at. The stop's proof has to be
          // handed forward here too, or the search's obligation is discarded
          // by the very shortcut that was supposed to be exact.
          // Reading nothing carries the obligation forward; reading a character
          // discharges it, and then the character has to be one the obligation
          // allows. Emptiness is the whole difference, so `base` is it. The
          // `owed == base` escape is what keeps a guard from vetoing a walk
          // that never took one: only a star narrows `base`, and a narrowing
          // that emptied the class is the one thing the walk must not do.
          final loop = _guarded && node is _Cons && identical(node.tail, node)
              ? node
              : null;
          final empty = m.len == 0;
          if (empty || _has(c, _input.codeUnitAt(pos))) {
            final base = empty ? c : _free;
            final owed = loop == null ? base : _notFirst(loop.head.orig, base);
            if (owed == base || !_unmeetable(owed)) {
              _put(f, _key(pos + m.len, owed), 0, 0, _wPure);
            }
          }
        }
      }
      return _finish(f);
    }
    switch (node) {
      case _Term(:final editable, :final demands):
        if (demands != _free) {
          _put(f, _key(pos, _meet(c, demands)), 0, 0, _wDemand);
          return _finish(f);
        }
        final m = node.orig.match(_parser, pos);
        if (!m.isMismatch && (m.len == 0 || _has(c, _input.codeUnitAt(pos)))) {
          _put(f, _key(pos + m.len, m.len == 0 ? c : _free), 0, 0, _wPure);
        }
        if (!editable) return _finish(f);
        final emits = _oneCharClass(node.orig);
        final silent = emits == null || emits.isEmpty;
        if (silent || _permits(c, emits)) {
          final owed = silent ? c : _free;
          if (pos < _inputLen) {
            _put(f, _key(pos + 1, owed), 1, _widthOf(node.orig) * _lossSpan + 1,
                _wSub); // SUB: invents |class| bits, loses 1 char
          }
          _put(f, _key(pos, owed), 1, _widthOf(node.orig) * _lossSpan,
              _wFab); // FAB: invents |class| bits, loses nothing
        }
        return _finish(f);
      case _Alt(:final alts):
        final guards = _guarded ? _guardsOf(node) : null;
        while (f.pc < alts.length) {
          final owe = guards == null ? c : _meet(c, guards[f.pc]); // I27
          if (owe != c && _unmeetable(owe)) {
            f.pc++; // no repaired character reaches this branch
            continue;
          }
          final child = _entryAt(alts[f.pc], pos, owe);
          if (_demand(child, budget)) return;
          _mergeAlt(f, alts.length, child, f.pc);
          f.pc++;
        }
        return _finish(f);
      case _Cons():
        final loops = identical(node.tail, node);
        if (f.pc == 0) {
          if (loops) {
            final owed = _guarded ? _notFirst(node.head.orig, c) : c; // I27
            if (owed == c || !_unmeetable(owed)) {
              _put(f, _key(pos, owed), 0, 0, _wStop);
            }
          }
          final head = _entryAt(node.head, pos, c);
          if (_demand(head, budget)) return;
          f.headEntry = head;
          f.pc = 1;
          f.headLen = -1;
        }
        final heads = f.headEntry!.value ?? const <int>[];
        // The list grew while this frame was parked, so a split may have
        // landed behind the cursor. Re-offering one is free -- `_put` is
        // idempotent -- and growth is bounded by the number of splits.
        if (heads.length != f.headLen) {
          f.headLen = heads.length;
          f.pc = 1;
        }
        while ((f.pc - 1) * 4 < heads.length) {
          final i = (f.pc - 1) * 4;
          final headKey = heads[i], hCost = heads[i + 1], hReg = heads[i + 2];
          final headEnd = _endOf(headKey);
          final rest = budget - hCost;
          // The zero-width cut (speed only) and the budget's descent bound.
          if ((loops && headEnd == pos) || rest < 0 || headEnd > _inputLen) {
            f.pc++;
            continue;
          }
          final tail = _entryAt(node.tail, headEnd, _oweOf(headKey));
          if (_demand(tail, rest)) return;
          final rv = tail.value;
          if (rv != null) {
            for (var j = 0; j < rv.length; j += 4) {
              final total = hCost + rv[j + 1];
              if (total <= budget) {
                _put(f, rv[j], total, hReg + rv[j + 2], headKey);
              }
            }
          }
          f.pc++;
        }
        return _finish(f);
    }
  }

  void _put(_Frame f, int key, int cost, int reg, int why) {
    if (_keepBest(f.entry.value!, key, cost, reg, why)) f.improved = true;
  }

  /// Ordered choice: I3's veto, then the merge. The veto asks the memoized
  /// parser (never the raw combinator -- LESSONS 5m) where PEG itself commits.
  void _mergeAlt(_Frame f, int altCount, _Entry branch, int which) {
    final v = branch.value;
    if (v == null) return;
    final budget = f.budget;
    var committed = -2;
    for (var i = 0; i < v.length; i += 4) {
      final key = v[i], cost = v[i + 1];
      if (cost > budget) continue;
      if (cost == 0 && altCount > 1) {
        if (committed == -2) {
          final oracle = _parser.match(f.entry.node.orig, f.entry.pos);
          committed = oracle.isMismatch ? -1 : f.entry.pos + oracle.len;
        }
        if (_endOf(key) > committed &&
            (committed >= 0 || _oweOf(key) == _free)) {
          continue;
        }
      }
      _put(f, key, cost, v[i + 2], which);
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

  // ---- I31: the repaired string is the witness, and its parse is the tree --
  //
  // The old block did the same job twice. `_build` searched the table for a
  // derivation and turned it into a tree; `_emit` walked that tree back into a
  // string; `_verify` handed the string to a fresh parser, which built its own
  // tree and threw it away. Two machines, one answer -- and the search is the
  // larger half: measured on m73 with all three arms on one clock (n=21), the
  // certificate costs 43.6 ms of the battery, of which `_build` is 24.3 and
  // emit-plus-the-whole-re-parse 19.3. So deleting the search is worth more
  // than deleting the parse, and the parse is the half that also hands back
  // the tree.
  //
  // I29 removes the reason to search at all: every value already carries the
  // reason it was written, so the derivation is a chase down back-pointers,
  // not a hunt. And a chase down to the leaves does not need a tree -- it
  // needs the EDIT LIST, which is all the leaves have to say. Apply the edits
  // and you have y. The parser that must accept y to certify the repair is
  // also the parser that computes y's tree, so take the tree it already built
  // and re-index it onto the input. Reconstruction and verification stop being
  // two passes because they were always one.

  /// `(pos, drop, text, what)`: at input position `pos`, delete `drop`
  /// characters and write `text` in their place, because clause `what` asked.
  final List<(int, int, String, Clause)> _edits = [];

  int _reasonAt(_Node node, int pos, int c, int key) {
    final v = _entryAt(node, pos, c).value ?? const <int>[];
    for (var i = 0; i < v.length; i += 4) {
      if (v[i] == key) return v[i + 3];
    }
    return _wNone;
  }

  /// Walk the reasons from the goal down to the leaves, left to right, so the
  /// edits come out in ascending position and the repaired string is a single
  /// forward splice. Iterative, so the witness costs no VM stack: the depth
  /// that used to sink `_row` into the input's length now lives in `st`.
  /// Open a tree node for `node`, or pass the sink through. Two clauses are
  /// the same structure when they are the same object, so a self-loop (a
  /// repetition's cons chained to itself) and a wrapped reader (`_wrap` puts
  /// the skip loop and the leaf under one clause) each enter their clause ONCE,
  /// however many times the chase steps through them.
  ///
  /// The span is written now and the children poured in later, which `Match`
  /// permits: it re-derives its span from its children only when they are
  /// already there (match_result.dart:40) and it keeps the list it was handed.
  List<MatchResult> _open(
      List<MatchResult> sink, Clause orig, Clause? owner, int pos, int end) {
    if (identical(orig, owner) || !_real.contains(orig)) return sink;
    final kids = <MatchResult>[];
    sink.add(Match(orig, pos, end - pos, subClauseMatches: kids));
    return kids;
  }

  /// Walk the reasons from the goal down to the leaves, left to right, BUILDING
  /// as it goes. Iterative, so the witness costs no VM stack.
  ///
  /// This is also the whole soundness check, and it is a lookup rather than a
  /// parse: an edit-free step claims the oracle reads that stretch, so ask the
  /// oracle. If the clean match is absent or the wrong length, the witness has
  /// contradicted a fact the parser already established, and the derivation is
  /// rejected -- I5's rule (the witness is a proof, so check it) and m43's
  /// (the oracle is authoritative as far as the edit-free window reaches),
  /// applied without re-parsing anything.
  bool _chase(int cost, List<MatchResult> out) {
    final st = <(_Node, int, int, int, List<MatchResult>, Clause?)>[
      (_goal, 0, _free, _goalKey, out, null)
    ];
    while (st.isNotEmpty) {
      final (node, pos, c, key, sink, owner) = st.removeLast();
      final why = _reasonAt(node, pos, c, key);
      final end = _endOf(key);
      switch (why) {
        case _wNone:
          return false;
        case _wSub:
          // Input the grammar cannot use. It stays exactly where it is, in the
          // tree, at the structural position that failed -- and the clause that
          // wanted something else records that it went unfilled. The character
          // is NOT replaced by the one the grammar wanted: that would put a
          // symbol in the tree that nothing in the document supports.
          sink.add(SyntaxError(pos: pos, len: end - pos));
          _edits.add((pos, end - pos, _spelling(node.orig), node.orig));
        case _wFab:
          // Grammar the input cannot fill. The demanded symbol is NOT written
          // into the tree -- nothing in the document supports it, and a wide
          // class could not say which symbol anyway. What is real, and is
          // recorded, is the POSITION at which the descent needed something and
          // found nothing: a zero-width error span, sitting between the
          // characters that do exist.
          sink.add(SyntaxError(pos: pos, len: 0));
          _edits.add((pos, 0, _spelling(node.orig), node.orig));
        case _wPure || _wDemand || _wStop:
          if (end > pos) {
            final m = node.orig.match(_parser, pos);
            if (m.isMismatch || m.len != end - pos) return false;
            sink.add(m); // the oracle's own subtree, taken verbatim
          }
        default:
          final into = _open(sink, node.orig, owner, pos, end);
          final own = identical(into, sink) ? owner : node.orig;
          switch (node) {
            case _Alt(:final alts):
              final guards = _guarded ? _guardsOf(node) : null;
              st.add((
                alts[why],
                pos,
                guards == null ? c : _meet(c, guards[why]),
                key,
                into,
                own
              ));
            case _Cons():
              // Tail first so the head pops first: left to right.
              st.add((node.tail, _endOf(why), _oweOf(why), key, into, own));
              st.add((node.head, pos, c, why, into, own));
            case _Term():
              return false; // a leaf never writes a structural reason
          }
      }
    }
    // Every edit costs exactly one, so the chase reaching a different total
    // means it did not walk the derivation the goal was priced from.
    return _edits.length == cost;
  }

  /// The cheapest text a leaf accepts. Used ONLY to ask the pure parser
  /// whether the repair is in the language -- it is never written into the
  /// tree, which is why a wide class may spell itself arbitrarily here without
  /// putting an invented symbol in front of a caller.
  String _spelling(Clause c) => switch (_oneCharClass(c)) {
        [(final lo, _), ...] => String.fromCharCode(lo),
        _ => c is Str ? c.text : '',
      };

  String _repaired() {
    final out = StringBuffer();
    var cursor = 0;
    for (final (pos, drop, text, _) in _edits) {
      out
        ..write(_input.substring(cursor, pos))
        ..write(text);
      cursor = pos + drop;
    }
    return (out..write(_input.substring(cursor))).toString();
  }

  // ---- entry points --------------------------------------------------------

  MatchResult? _root;

  /// I28's question: does this answer carry its own proof? A clean parse is
  /// one by construction, and "no repair exists" needs none. Everything else
  /// has to produce the witness -- and under I32 producing the witness IS
  /// building the tree, so there is nothing left to verify afterwards and
  /// nothing to re-parse. `_chase` fails exactly when the derivation
  /// contradicts the oracle or does not add up to the price it was sold at.
  bool _certified(int cost) {
    _edits.clear();
    _root = null;
    lastVerified = false;
    if (cost < 0) return true;
    if (cost == 0) return lastVerified = (_root = _clean) != null;
    final out = <MatchResult>[];
    if (!_chase(cost, out)) return false;
    // MEASURED, not assumed: with the obligations still approximated to one
    // character, the chase's own checks are NOT a membership proof. Dropping
    // this parse made m75 answer 2, verified, on inputs whose true cost is -1
    // (`_m75diff.dart`, 28 of 31 strings on `'a'* "ab"`). So the repair is
    // still put to the pure parser -- but only for a yes/no. Its tree is
    // discarded: the tree the caller gets was built over the INPUT by the
    // chase above, and no character invented here ever reaches it.
    final y = _repaired();
    final check =
        Parser(rules: rules, topRuleName: topRuleName, input: y).parse();
    if (check.hasSyntaxErrors || check.root.len != y.length) return false;
    _root = out.length == 1 && out.first.len == _inputLen
        ? out.first
        : Match(null, 0, _inputLen, subClauseMatches: out);
    return lastVerified = true;
  }

  SkipResult recover(String input) {
    recoverCost(input);
    final root = _root;
    if (root == null) {
      final error = SyntaxError(pos: 0, len: _inputLen);
      return SkipResult(error, [error], const [], 1, true);
    }
    // The edits are the report, and now they are two facts rather than one.
    // Input the grammar could not use is a span over exactly those characters;
    // the clause that wanted something there went unfilled either way, so every
    // edit also names an obligation. m74 reported a substitution as a bare
    // deletion and dropped what it wrote -- the write is gone, so the
    // obligation is the only honest half left, and it is now always recorded.
    final spans = <SyntaxError>[];
    final missing = <MissingObligation>[];
    for (final (pos, drop, _, what) in _edits) {
      if (drop > 0) spans.add(SyntaxError(pos: pos, len: drop));
      missing.add(MissingObligation(what, pos));
    }
    return SkipResult(
        root, spans, missing, spans.length + missing.length, false);
  }

  /// I28. Relax, demand the certificate, tighten exactly when it fails to come.
  int recoverCost(String input) {
    _guarded = false;
    final relaxed = _pass(input);
    if (_certified(relaxed)) return relaxed;
    _guarded = true;
    final tight = _pass(input);
    _certified(tight);
    return tight;
  }

  int _pass(String input) {
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
    _versionAtPos = List.filled(_inputLen + 2, 0);
    _cells.clear();
    _stack.clear();
    _depth = -1;
    _steps = 0;
    // The ladder, with A3's filter: one memo serves every round.
    for (var k = 0; k <= maxCost; k++) {
      final goalEntry = _entryAt(goal, 0, _free);
      _run(goalEntry, k);
      final v = goalEntry.value;
      if (v == null) continue;
      var bestC = _impossible, bestR = _impossible;
      for (var i = 0; i < v.length; i += 4) {
        final key = v[i];
        if (_endOf(key) != _inputLen || !_has(_oweOf(key), _endMark)) continue;
        if (v[i + 1] < bestC || (v[i + 1] == bestC && v[i + 2] < bestR)) {
          bestC = v[i + 1];
          bestR = v[i + 2];
          _goalKey = key;
        }
      }
      if (bestC < _impossible) {
        lastCost = bestC;
        lastRegret = bestR;
        lastSteps = _steps;
        return bestC;
      }
    }
    lastCost = -1;
    lastSteps = _steps;
    return -1;
  }
}

// ---- scratch probe (untracked): D-C, the string-swallowing tie-break --------
String _show(MatchResult m, String input, [int d = 0]) {
  final pad = '  ' * d;
  final sb = StringBuffer();
  final c = m.clause;
  if (m is SyntaxError) {
    sb.writeln(m.len == 0
        ? '$pad<missing @${m.pos}>'
        : '$pad<error "${input.substring(m.pos, m.pos + m.len)}">');
  } else {
    final name = c is Ref ? c.ruleName : (c?.runtimeType.toString() ?? '.');
    sb.write('$pad$name');
    sb.writeln(m.subClauseMatches.isEmpty
        ? ' "${input.substring(m.pos, m.pos + m.len)}"'
        : '');
  }
  for (final k in m.subClauseMatches) {
    sb.write(_show(k, input, d + 1));
  }
  return sb.toString();
}

void main() {
  final rules = buildSetup().$1;
  final e = SuperDot3(rules: rules, topRuleName: 'JSON');
  const b021 = '{"a":1,"bc":2[,33,true],"d":{"e":null},"f":"gh"}';
  final r = e.recover(b021);
  print('input      $b021');
  print('cost ${e.lastCost}  regret ${e.lastRegret}  '
      'verified ${e.lastVerified}');
  print('repaired   ${e._repaired()}');
  print(_show(r.root, b021));
}
