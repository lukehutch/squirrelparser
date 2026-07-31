// m61 -- THE PARSER IS THE HOST: m60's recurrence with the driver deleted.
// A recovery cell IS a clause. Hand it to the frozen parser, and the parser's
// own memo table performs the memoization, the cycle seeding, the widening
// loop, and the staleness rule that m49 through m60 rebuilt by hand.
//
//   I17 A MEMO ENTRY IS A FIXPOINT ENGINE. `MemoEntry.match` is not
//       left-recursion support that happens to cache; it is a bottom-seeded
//       Kleene iteration with per-position invalidation, and nothing in it
//       cares that the value it grows is a parse length. Wrap the m-line cell
//       (node, obligation, budget) as a Clause whose match() computes the
//       value set and reports growth through `len` (a pass counter: strictly
//       larger when the set improved, equal when it did not, so the parser's
//       fixed-point test `newResult.len <= result.len` drives SET growth),
//       and every field of m60's _Entry lands on machinery the parser already
//       owns: running = inRecPath, foundCycle = foundLeftRec, version =
//       memoVersion, value = result -- and the coroutine (pc / parent /
//       headEntry) returns to the native stack, whose ceiling is measured.
//       The budget, A3's filter, becomes the third coordinate of the KEY:
//       settling at a budget is the memo hit itself, and reuse across ladder
//       rungs is the memo's own, with no settledBudget protocol. Soundness of
//       the per-position invalidation granularity is I8's: reads never move
//       backward in position, so a provisional value can only have been
//       consumed at the position that widens.
//
// Everything else is the line's settled core, verbatim from m60: the curried
// normal form; I2's lies with deletion as SUB on Nothing; I3's oracle veto;
// I6/I7's obligation channel (down the argument, across the value, up the
// memo); I5's verified witness; A1/A2 pricing with Delta as the pair
// (cost, regret) compared lexicographically; the deepening ladder, the
// budget-zero oracle walk, and the derived ceiling `n + fabricate(goal)`.
//
// PARAMETERS: NONE. HEURISTICS: shortest-head witness tie-break (output),
// I4's fusion (work), whole-input span on witness failure (presentation).
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

/// The m-line cell as a Clause: the (node, obligation, budget) triple the
/// driver keyed its table by, handed to the parser as a grammar object.
class _Cell extends Clause {
  _Cell(this.owner, this.node, this.c, this.budget);
  final SuperDot3 owner;
  final _Node node;
  final int c;
  final int budget;

  @override
  MatchResult match(Parser parser, int pos) => owner._eval(this, pos);

  @override
  void checkRuleRefs(Map<String, Clause> grammarMap) {}
}

/// The value as a match result: the parser's memo stores what the driver's
/// table held. `len` is the growth counter `MemoEntry.match` iterates on.
class _CellMatch extends Match {
  _CellMatch(int pos, this.kv, int passes) : super(null, pos, passes);
  final List<int> kv;
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

  void _buildRegretPrefix() {
    _regretPrefix = [0];
    for (var pos = 0; pos < _inputLen; pos++) {
      final ch = _input.codeUnitAt(pos);
      final narrowest = _charRegret.putIfAbsent(ch, () {
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
      _regretPrefix.add(_regretPrefix.last + narrowest);
    }
  }

  int _cleanRegret(MatchResult m) =>
      _cleanRegrets[m] ??= m.subClauseMatches.isEmpty
          ? _widthOf(m.clause!) * m.len
          : m.subClauseMatches.fold(0, (sum, sub) => sum + _cleanRegret(sub));

  // ---- the value: triples in a fresh list per pass (I9 without in-place) ---

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

  final Map<(int, int, int), _Cell> _cells = {};
  int _posShift = 0, _span = 0;

  _Cell _cellAt(_Node node, int c, int budget) => _cells.putIfAbsent(
      (node.id, c, budget), () => _Cell(this, node, c, budget));

  // ---- I17: the host -------------------------------------------------------

  /// Read a cell's value through the parser: memoization, the cycle seed
  /// (MISMATCH reads as the empty set), widening, and staleness are all
  /// `MemoEntry.match`'s. A budget below zero or a position past the end is
  /// the empty set without a cell.
  List<int> _ends(_Node node, int pos, int budget, int c) {
    if (pos > _inputLen || budget < 0) return const [];
    final m = _parser.match(_cellAt(node, c, budget), pos);
    return m is _CellMatch ? m.kv : const <int>[];
  }

  /// Did `now` improve on `before` (a key added, or a key's (cost, regret)
  /// lexicographically lowered)? Values are budget-fixed and children are
  /// monotone, so regression is impossible and one direction suffices.
  static bool _grew(List<int> now, List<int> before) {
    for (var i = 0; i < now.length; i += 3) {
      var found = false;
      for (var j = 0; j < before.length; j += 3) {
        if (before[j] != now[i]) continue;
        found = true;
        if (now[i + 1] < before[j + 1] ||
            (now[i + 1] == before[j + 1] && now[i + 2] < before[j + 2])) {
          return true;
        }
        break;
      }
      if (!found) return true;
    }
    return false;
  }

  /// Package a pass's set with the growth counter the host iterates on.
  MatchResult _seal(_Cell cell, int pos, List<int> out) {
    final prev = _parser.getMemoEntry(cell, pos)?.result;
    final base = prev is _CellMatch ? prev : null;
    final passes = base == null ? 0 : base.len;
    return _CellMatch(
        pos, out, _grew(out, base?.kv ?? const <int>[]) ? passes + 1 : passes);
  }

  /// One pass of the recurrence: m60's `_step`, in direct style, with every
  /// park/resume replaced by a plain memoized read.
  MatchResult _eval(_Cell cell, int pos) {
    _steps++;
    final node = cell.node;
    final c = cell.c;
    final budget = cell.budget;
    final out = <int>[];
    // The budget-zero walk: the repaired string IS the input here and
    // everything after this cell is edit-free, so the oracle's one memoized
    // answer settles the whole subtree (LESSONS 5i/5m). No children.
    if (budget == 0) {
      final m = node.orig.match(_parser, pos);
      if (!m.isMismatch) {
        if (m.len == 0) {
          _keepBest(out, _key(pos, c), 0, _cleanRegret(m));
        } else if (_permitsFirst(c, pos)) {
          _keepBest(out, _key(pos + m.len, _free), 0, _cleanRegret(m));
        }
      }
      return _seal(cell, pos, out);
    }
    switch (node) {
      case _Term(:final editable, :final demands):
        if (demands != _free) {
          _keepBest(out, _key(pos, _meet(c, demands)), 0, 0);
          return _seal(cell, pos, out);
        }
        final m = node.orig.match(_parser, pos);
        if (!m.isMismatch) {
          if (m.len == 0) {
            _keepBest(out, _key(pos, c), 0, _cleanRegret(m));
          } else if (_permitsFirst(c, pos)) {
            _keepBest(out, _key(pos + m.len, _free), 0, _cleanRegret(m));
          }
        }
        if (editable) {
          final emits = _oneCharClass(node.orig);
          final silent = emits == null || emits.isEmpty;
          if (silent || _permits(c, emits)) {
            final owed = silent ? c : _free;
            if (pos < _inputLen) {
              _keepBest(out, _key(pos + 1, owed), 1,
                  2 * _skipRegret(pos, pos + 1)); // SUB
            }
            _keepBest(out, _key(pos, owed), 1, _widestClass); // FAB
          }
        }
      case _Alt(:final alts):
        for (final alt in alts) {
          _mergeAlt(out, node, pos, budget, alts.length,
              _ends(alt, pos, budget, c));
        }
      case _Cons():
        final loops = identical(node.tail, node);
        if (loops) _keepBest(out, _key(pos, c), 0, 0);
        final heads = _ends(node.head, pos, budget, c);
        for (var i = 0; i < heads.length; i += 3) {
          final headKey = heads[i], hCost = heads[i + 1], hReg = heads[i + 2];
          final headEnd = _endOf(headKey);
          final rest = budget - hCost;
          // The zero-width cut (speed only) and the budget's descent bound.
          if ((loops && headEnd == pos) || rest < 0 || headEnd > _inputLen) {
            continue;
          }
          final rv = _ends(node.tail, headEnd, rest, _oweOf(headKey));
          for (var j = 0; j < rv.length; j += 3) {
            final total = hCost + rv[j + 1];
            if (total <= budget) {
              _keepBest(out, rv[j], total, hReg + rv[j + 2]);
            }
          }
        }
    }
    return _seal(cell, pos, out);
  }

  /// Ordered choice: I3's veto, then the merge. The veto asks the memoized
  /// parser (never the raw combinator -- LESSONS 5m) where PEG itself commits.
  void _mergeAlt(List<int> out, _Node node, int pos, int budget, int altCount,
      List<int> v) {
    var committed = -2;
    for (var i = 0; i < v.length; i += 3) {
      final key = v[i], cost = v[i + 1];
      if (cost > budget) continue;
      if (cost == 0 && altCount > 1) {
        if (committed == -2) {
          final oracle = _parser.match(node.orig, pos);
          committed = oracle.isMismatch ? -1 : pos + oracle.len;
        }
        if (_endOf(key) > committed &&
            (committed >= 0 || _oweOf(key) == _free)) {
          continue;
        }
      }
      _keepBest(out, key, cost, v[i + 2]);
    }
  }

  // ---- reconstruction and verification (m60's, with `_ends` reads) ---------

  final List<SyntaxError> _spans = [];
  final List<MissingObligation> _missing = [];
  final Set<(_Alt, int, int, int, int)> _path = {};

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

  SkipResult recover(String input) {
    final cost = recoverCost(input);
    _spans.clear();
    _missing.clear();
    _path.clear();
    lastVerified = false;
    if (cost == 0) {
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

  int recoverCost(String input) {
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
    _cells.clear();
    _cleanRegrets.clear();
    _steps = 0;
    // The ladder: each rung is a new goal cell; every rung below it is memo.
    for (var k = 0; k <= maxCost; k++) {
      final v = _ends(goal, 0, k, _free);
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
}
// ERROR RECOVERY END
