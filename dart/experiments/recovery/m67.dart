// m67 -- ONE ENGINE: the relaxed search, the certificate, and the tape,
// hoisted into a single class over a single substrate.
//
//   I23 THE ROUTER WAS A SEAM, NOT A DESIGN. m66 proved the semantics
//       (verified relaxation, tape appeal) by composing two engines that each
//       carried their own copy of the machinery -- two relaxed cores, three
//       pure parses, two width tables, two one-character-class analyses.
//       Hoisting both searches into one class dissolves the duplicates: ONE
//       relaxed core serves the fast path, the envelope floor, and the
//       fabrication floor; ONE _oneCharClass/_looks analysis is
//       simultaneously I4's fusion test and the envelope boundary (a wide
//       lookahead IS a clause _looks cannot read); ONE width/regret table
//       prices the relaxed lattice, the tape's edit weights, and the
//       post-search ranking; ONE set of result fields is written directly by
//       whichever search answers. The composition's semantics are unchanged
//       and re-verified: certificate (verified witness = equality,
//       unconditional in its upper-bound half), floor (envelope only),
//       horizon (n + floor + fabrication mass, forced by undecidability).
//
// The relaxed half is m62 verbatim (I18 and ancestors); the tape half is m65
// verbatim (I20/I21); the driver is the twenty-fourth occasion's routing
// with the seams removed. PARAMETERS: NONE.
import 'dart:math' as math;
import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/recovery/skip_recovery.dart'
    show SkipResult, MissingObligation;

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

  static List<(int, int)> _intersect(List<(int, int)> a, List<(int, int)> b) => [
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

  bool _permits(int c, List<(int, int)>? emits) =>
      c == _free || (emits != null && _intersect(emits, _classes[c]).isNotEmpty);

  bool _has(int c, int ch) {
    for (final (lo, hi) in _classes[c]) {
      if (ch >= lo && ch <= hi) return true;
    }
    return false;
  }

  bool _permitsFirst(int c, int pos) =>
      c == _free || _has(c, _input.codeUnitAt(pos));

  bool _permitsEnd(int c) => c == _free || _has(c, _endMark);

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
        if (_permitsEnd(top[i]) && top[i + 1] < best) best = top[i + 1];
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

  int _cleanRegret(MatchResult m) =>
      _cleanRegrets[m] ??= m.subClauseMatches.isEmpty
          ? _widthOf(m.clause!) * m.len
          : m.subClauseMatches.fold(0, (sum, sub) => sum + _cleanRegret(sub));

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
          if (m.len == 0) {
            _put(f, _key(pos, c), 0, _cleanRegret(m));
          } else if (_permitsFirst(c, pos)) {
            _put(f, _key(pos + m.len, _free), 0, _cleanRegret(m));
          }
        }
      }
      return _finish(f);
    }
    switch (node) {
      case _Term(:final editable, :final demands):
        if (demands != _free) {
          _put(f, _key(pos, _meet(c, demands)), 0, 0);
          return _finish(f);
        }
        final m = node.orig.match(_parser, pos);
        if (!m.isMismatch) {
          if (m.len == 0) {
            _put(f, _key(pos, c), 0, _cleanRegret(m));
          } else if (_permitsFirst(c, pos)) {
            _put(f, _key(pos + m.len, _free), 0, _cleanRegret(m));
          }
        }
        if (editable) {
          final emits = _oneCharClass(node.orig);
          final silent = emits == null || emits.isEmpty;
          if (silent || _permits(c, emits)) {
            final owed = silent ? c : _free;
            if (pos < _inputLen) {
              _put(f, _key(pos + 1, owed), 1,
                  2 * _skipRegret(pos, pos + 1)); // SUB
            }
            _put(f, _key(pos, owed), 1, _widestClass); // FAB
          }
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
        if (_endOf(key) > committed &&
            (committed >= 0 || _oweOf(key) == _free)) {
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

  // ---- reconstruction and verification (m59's, with `_run` reads) ----------

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

  MatchResult? _build(
      _Node node, int pos, int key, int cost, int reg, int budget, int c) {
    final end = _endOf(key);
    final orig = node.orig;
    final pure = pos > _inputLen ? mismatch : orig.match(_parser, pos);
    if (!pure.isMismatch &&
        pos + pure.len == end &&
        cost == 0 &&
        _cleanRegret(pure) == reg &&
        (pure.len == 0
            ? key == _key(pos, c)
            : key == _key(end, _free) && _permitsFirst(c, pos))) {
      return pure;
    }
    switch (node) {
      case _Term():
        final accepts = c == _free ? null : _oneCharClass(orig);
        return Match(
            accepts == null ? orig : CharSet(_intersect(accepts, _classes[c])),
            pos,
            end - pos);
      case _Alt(:final alts):
        final state = (node, pos, key, cost, c);
        if (!_path.add(state)) return null;
        for (final alt in alts) {
          if (_deltaOf(_ends(alt, pos, budget, c), key) != (cost, reg)) {
            continue;
          }
          final m = _child(alt, pos, key, cost, reg, budget, c);
          if (m != null) {
            _path.remove(state);
            return Match(orig, pos, end - pos, subClauseMatches: m);
          }
        }
        _path.remove(state);
        return null;
      case _Cons():
        final children = _row(node, pos, key, cost, reg, budget, c);
        return children == null
            ? null
            : Match(orig, pos, end - pos, subClauseMatches: children);
    }
  }

  List<MatchResult>? _child(
      _Node node, int pos, int key, int cost, int reg, int budget, int c) {
    if (identical(node, _junk)) {
      final end = _endOf(key);
      return end == pos ? const [] : [SyntaxError(pos: pos, len: end - pos)];
    }
    if (node is _Cons && identical(node.head, _junk)) {
      return _row(node, pos, key, cost, reg, budget, c);
    }
    final m = _build(node, pos, key, cost, reg, budget, c);
    return m == null ? null : [m];
  }

  List<MatchResult>? _row(
      _Node node, int pos, int key, int cost, int reg, int budget, int c) {
    if (node is! _Cons) {
      return identical(node, _eps)
          ? (key == _key(pos, c) && cost == 0 && reg == 0 ? const [] : null)
          : _child(node, pos, key, cost, reg, budget, c);
    }
    final loops = identical(node.tail, node);
    final heads = List<int>.of(_ends(node.head, pos, budget, c));
    final order = [for (var i = 0; i < heads.length; i += 3) i]
      ..sort((a, b) {
        final byEnd = _endOf(heads[a]) - _endOf(heads[b]);
        return byEnd != 0 ? byEnd : heads[a] - heads[b];
      });
    for (final i in order) {
      final headKey = heads[i];
      final headEnd = _endOf(headKey);
      if (loops && headEnd == pos) continue;
      final hCost = heads[i + 1], hReg = heads[i + 2];
      if (hCost > cost || (hCost == cost && hReg > reg)) continue;
      final headOwed = _oweOf(headKey);
      final restBudget = budget - hCost;
      final rest =
          _deltaOf(_ends(node.tail, headEnd, restBudget, headOwed), key);
      if (rest == null || rest.$1 != cost - hCost || rest.$2 != reg - hReg) {
        continue;
      }
      final head = _child(node.head, pos, headKey, hCost, hReg, budget, c);
      if (head == null) continue;
      final tail =
          _row(node.tail, headEnd, key, rest.$1, rest.$2, restBudget, headOwed);
      if (tail != null) return [...head, ...tail];
    }
    return loops && key == _key(pos, c) && cost == 0 && reg == 0
        ? const []
        : null;
  }

  void _collect(MatchResult m) {
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
      m.subClauseMatches.forEach(_collect);
    }
  }

  void _emit(MatchResult m, StringBuffer out) {
    if (m is SyntaxError) return;
    final clause = m.clause;
    if (m.subClauseMatches.isEmpty) {
      out.write(clause is Terminal &&
              clause is! Nothing &&
              (m.len == 0 || clause.match(_parser, m.pos).isMismatch)
          ? _spelling(clause)
          : _input.substring(m.pos, m.pos + m.len));
      return;
    }
    var cursor = m.pos;
    for (final child in m.subClauseMatches) {
      if (child.pos > cursor) out.write(_input.substring(cursor, child.pos));
      _emit(child, out);
      cursor = child.pos + child.len;
    }
    if (cursor < m.pos + m.len) {
      out.write(_input.substring(cursor, m.pos + m.len));
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
        if (_endOf(v[i]) != _inputLen || !_permitsEnd(_oweOf(v[i]))) continue;
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
  late final bool _wideG = () {
    var found = false;
    final seen = <Clause>{};
    void walkC(Clause c) {
      if (found || !seen.add(c)) return;
      if (c is FollowedBy || c is NotFollowedBy) {
        if (_looks(c) == null) found = true;
        walkC((c as HasOneSubClause).subClause);
      } else if (c is HasMultipleSubClauses) {
        c.subClauses.forEach(walkC);
      } else if (c is HasOneSubClause) {
        walkC(c.subClause);
      } else if (c is Ref) {
        final t = _rules[c.ruleName];
        if (t != null) walkC(t);
      }
    }

    _rules.values.forEach(walkC);
    return found;
  }();

  /// The grammar's fabrication mass over the lowered terminal list: the
  /// derived widening of the horizon that covers forced-duplication gaps.
  late final int _massG = () {
    _goal; // force the builder
    var m = 0;
    for (final t in _terminals) {
      m += t is Str ? t.text.length : 1;
    }
    return m;
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

  void _noteAtoms(_Probe p, String y, int pos) {
    final inner = p.inner;
    if (inner is Str) {
      final off = y.length - pos;
      for (var i = 0; i < off; i++) {
        if (y.codeUnitAt(pos + i) != inner.text.codeUnitAt(i)) return;
      }
      _atomSet.add(inner.text.codeUnitAt(off));
    } else if (inner is Char) {
      _atomSet.add(inner.char.codeUnitAt(0));
    } else if (inner is CharSet) {
      _atomSet.add(_lowestOf(inner));
    } else if (inner is AnyChar) {
      _atomSet.add(0);
    }
  }

  static int _lowestOf(CharSet cs) {
    if (!cs.inverted) {
      var lo = 0x10000;
      for (final (a, _) in cs.ranges) {
        lo = math.min(lo, a);
      }
      return lo;
    }
    for (var c = 0; c < 0x10000; c++) {
      var inSet = false;
      for (final (a, b) in cs.ranges) {
        if (c >= a && c <= b) {
          inSet = true;
          break;
        }
      }
      if (!inSet) return c;
    }
    return 0;
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

  MatchResult _tremap(MatchResult m, List<int> bnd) {
    final pos = bnd[m.pos], end = bnd[m.pos + m.len];
    if (m.subClauseMatches.isEmpty) {
      return Match(m.clause, pos, end - pos);
    }
    return Match(m.clause, pos, end - pos,
        subClauseMatches: [for (final c in m.subClauseMatches) _tremap(c, bnd)]);
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

  SkipResult recover(String input) {
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
    recover(input);
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
