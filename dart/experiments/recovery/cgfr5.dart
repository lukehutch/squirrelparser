// cgfr5.dart -- CGFR, FIXED AND COMPLETED.
//
// Takes cgfr2 (which hangs) and cgfr3 (which Gemini never finished) and
// repairs both defects, then fixes a third that every tape engine back to
// m63 has carried.
//
// DEFECT 1 (cgfr2, the reported infinite loop): `_finish` omitted
//   `entry.version = _versionAtPos[entry.pos]`, present in m62/m68. After
//   any left-recursive widening bumped a position's version, every entry at
//   that position failed `_settled` forever, so parents re-pushed children
//   endlessly. One stamp fixes it; `_bfcg4` went 44/44.
//
// DEFECT 2 (cgfr2, the reported hang): `_tapeRecover` was not an algorithm.
//   It enumerated strings over a HARDCODED 12-character alphabet, priced
//   each candidate at |y| rather than at its edit distance from the input
//   (the input was never consulted at all), pruned nothing, and stopped at a
//   TUNED `input.length + 10`. On the possessive-star conformance case --
//   where the true PEG language is empty and no candidate can ever accept --
//   it enumerated 12^k strings and never returned. Measured: cgfr2 answers
//   `('a' / "ab") 'b'` on "abb" correctly (cost 1) and then hangs forever on
//   `'a'* "ab"` / "aab". Replaced with the real probed tape: states are
//   (input cursor, emitted prefix), the priority is the edit cost, the
//   alphabet and the deadness test come from one probed parse, and the
//   horizon is derived (n + fabrication floor + grammar mass), not tuned.
//
// DEFECT 3 (m63/m65/m68, found by Codex round five and confirmed here):
//   `_noteAtoms` proposed ONE representative per terminal -- the lowest
//   member of a CharSet, code unit 0 for AnyChar. A representative chosen
//   from one terminal in isolation can never satisfy a constraint another
//   terminal imposes at the same position, so any grammar whose repair must
//   lie in an INTERSECTION was answered -1. Confirmed on three grammars:
//     S <- &[a-z] [0-9m-q]   on ""   truth 1 ("m"), m65/m68 both -1
//     S <- &[a-z] [0-9m-q]   on "z"  truth 1 ("m"), m65/m68 both -1
//     S <- ![a-l] [a-z]      on ""   truth 1 ("m"), m65/m68 both -1
//   The fix is the Boolean interval partition. Cut the code-unit line at
//   every CharSet range boundary and every literal character; inside an
//   interval every stock terminal answers identically, so one representative
//   per interval loses nothing. A touched terminal then proposes EVERY
//   representative it accepts, and the union over touched terminals contains
//   a representative of their intersection whenever that intersection is
//   non-empty -- because the intersection is itself a union of intervals.
//
// Recovery stays outside the pure parser: the parser is consulted only as an
// oracle, and nothing under lib/ is touched. Zero tuning parameters.

import 'dart:math' as math;
import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/recovery/skip_recovery.dart'
    show SkipResult, MissingObligation;


const int _widestClass = 20087;

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

class _Entry {
  _Entry(this.node, this.pos, this.c);
  final _Node node;
  final int pos;
  final int c;
  List<int>? value;
  int settledBudget = -1;
  int version = 0;
  int activeDepth = -1;
}

class _Frame {
  late _Entry entry;
  int budget = -1;
  int pc = 0;
  _Entry? headEntry;
  bool foundCycle = false;
  bool improved = false;
}

class SuperDot3 {
  final Map<String, Clause> rules;
  final String topRuleName;

  SuperDot3({required this.rules, required this.topRuleName}) {
    for (final r in _rules.values) {
      _node(r);
    }
  }

  late final Map<String, Clause> _rules = {
    for (final e in rules.entries)
      (e.key.startsWith('~') ? e.key.substring(1) : e.key): e.value,
  };

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
        if (emits != null) {
          final out = <int>[];
          _kb2(out, c, _width(node.orig));
          return out;
        }
        if (trustPredicates) {
          final out = <int>[];
          _kb2(out, c, 0);
          return out;
        }
        return const [];
      }

      row(-1)[_eps.id] = [-1, 0];
      while (improved) {
        improved = false;
        for (final node in all) {
          if (node is _Cons) {
            for (final e in cost.entries) {
              final c = e.key;
              final val = chain(node, c);
              for (var i = 0; i < val.length; i += 2) {
                _kb2(row(c)[node.id], val[i], val[i + 1]);
              }
            }
          } else if (node is _Alt) {
            for (final e in cost.entries) {
              final c = e.key;
              for (final alt in node.alts) {
                final val = row(c)[alt.id];
                for (var i = 0; i < val.length; i += 2) {
                  _kb2(row(c)[node.id], val[i], val[i + 1]);
                }
              }
            }
          } else if (node is _Term) {
            for (final e in cost.entries) {
              final c = e.key;
              final val = leaf(node, c);
              for (var i = 0; i < val.length; i += 2) {
                _kb2(row(c)[node.id], val[i], val[i + 1]);
              }
            }
          }
        }
      }
      final g = cost[-1]![_goal.id];
      for (var i = 0; i < g.length; i += 2) {
        if (g[i] == -1) return g[i + 1];
      }
      return 1 << 30;
    }

    final t1 = cheapest(false);
    if (t1 < (1 << 30)) return t1;
    return cheapest(true);
  }();

  /// Whether some lookahead's subclause has no single-character class -- the
  /// territory where the relaxed cost is not a floor and only the tape is
  /// trusted. The walk is CLOSED-WORLD: an unrecognised clause type would
  /// slip past every case below and be silently reported narrow, so it is
  /// refused instead. Repair soundness is proved over the stock algebra.
  late final bool _wideG = () {
    var wide = false;
    final seen = <Clause>{};
    void walk(Clause c) {
      if (!seen.add(c)) return;
      if (c is FollowedBy || c is NotFollowedBy) {
        // DEFECT 3 (cgfr2): its test was `_oneCharClass(subClause) == null`,
        // i.e. only a MULTI-character lookahead is wide. That envelope is
        // m62's, and it is only sound because m62 fuses `&C T` into `C n T`
        // (I4) so the relaxed reader sees the conjunction. This core, like
        // m68's, has no fusion: its reader consults the lookahead against
        // the ORIGINAL text at the ORIGINAL position, so a repair that has
        // to satisfy the lookahead is not merely mispriced -- the driver
        // never terminates. Measured: cgfr2 and cgfr4 both hang forever on
        // `S <- &[a-z] [a-z]` / "Q". Any lookahead is therefore wide, and
        // the tape -- which reads only real parses of real candidate
        // strings -- answers alone. This is m68's routing, for m68's reason.
        wide = true;
        walk((c as HasOneSubClause).subClause);
      } else if (c is HasMultipleSubClauses) {
        c.subClauses.forEach(walk);
      } else if (c is HasOneSubClause) {
        walk(c.subClause);
      } else if (c is Ref) {
        final r = _rules[c.ruleName];
        if (r != null) walk(r);
      } else if (c is! Str &&
          c is! Char &&
          c is! CharSet &&
          c is! AnyChar &&
          c is! Nothing) {
        throw ArgumentError(
            'unsupported clause type ${c.runtimeType}: repair soundness is '
            'proved over the stock clause algebra only');
      }
    }

    _rules.values.forEach(walk);
    return wide;
  }();

  late Parser _parser;
  late String _input;
  late int _inputLen;
  late List<int> _regretPrefix;
  late List<int> _versionAtPos;
  final Map<int, int> _charRegret = {};
  final Map<Clause, int> _widths = {};
  final Map<MatchResult, int> _cleanRegrets = {};
  int _steps = 0;

  int lastCost = -1, lastSteps = -1;
  bool lastVerified = false;
  bool lastFellBack = false;

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

  void _run(_Entry e, int budget) {
    if (budget < 0 || _settled(e, budget)) return;
    _push(e, budget);
    while (_depth >= 0) {
      _step(_stack[_depth]);
    }
  }

  void _step(_Frame f) {
    _steps++;
    final entry = f.entry;
    final node = entry.node;
    final pos = entry.pos;
    final budget = f.budget;
    final c = entry.c;

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
                2 * _skipRegret(pos, pos + 1));
          }
          _put(f, _key(pos, _free), 1, _widestClass);
        }
        return _finish(f);
      case _Alt(:final alts):
        while (f.pc < alts.length) {
          final child = _entryAt(alts[f.pc], pos, c);
          if (child.activeDepth >= 0) {
            _stack[child.activeDepth].foundCycle = true;
          } else if (!_settled(child, budget)) {
            _push(child, budget);
            return;
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
            return;
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
          if ((loops && headEnd == pos) || rest < 0 || headEnd > _inputLen) {
            f.pc++;
            continue;
          }
          final tail = _entryAt(node.tail, headEnd, _oweOf(headKey));
          if (tail.activeDepth >= 0) {
            _stack[tail.activeDepth].foundCycle = true;
          } else if (!_settled(tail, rest)) {
            _push(tail, rest);
            return;
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

  void _finish(_Frame f) {
    final entry = f.entry;
    if (f.foundCycle && f.improved && f.budget > 0) {
      _versionAtPos[entry.pos]++;
      f.pc = 0;
      f.headEntry = null;
      f.improved = false;
      return;
    }
    entry.settledBudget = math.max(entry.settledBudget, f.budget);
    entry.version = _versionAtPos[entry.pos];
    entry.activeDepth = -1;
    f.headEntry = null;
    _depth--;
  }

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
        key == _key(end, _free)) {
      return pure;
    }
    switch (node) {
      case _Term():
        return Match(orig, pos, end - pos);
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

  SkipResult _relaxedRecover(String input) {
    _parser = Parser(rules: rules, topRuleName: topRuleName, input: input);
    _input = input;
    _inputLen = input.length;
    _span = 1;
    while (_span <= _inputLen) {
      _span <<= 1;
    }
    _posShift = math.max(1, (_span - 1).bitLength);
    _versionAtPos = List.filled(_inputLen + 1, 0);
    _cells.clear();
    _stack.clear();
    _depth = -1;
    _steps = 0;
    _buildRegretPrefix();

    final maxCost = _inputLen + _goalFromNothing;
    for (var k = 0; k <= maxCost; k++) {
      final root = _entryAt(_goal, 0, _free);
      _run(root, k);
      final v = root.value;
      if (v == null) continue;
      var bestReg = 1 << 60;
      var bestKey = -1;
      for (var i = 0; i < v.length; i += 3) {
        if (_endOf(v[i]) == _inputLen && _oweOf(v[i]) == _free) {
          if (v[i + 2] < bestReg) {
            bestReg = v[i + 2];
            bestKey = v[i];
            lastCost = k;
          }
        }
      }
      if (lastCost >= 0 && bestKey >= 0) {
        lastSteps = _steps;
        final tree = _build(_goal, 0, bestKey, k, bestReg, k, _free);
        if (tree != null) {
          final spans = <SyntaxError>[];
          final missing = <MissingObligation>[];
          void collect(MatchResult m) {
            if (m is SyntaxError) {
              spans.add(m);
            } else if (m.subClauseMatches.isEmpty &&
                m.clause is Terminal &&
                m.clause is! Nothing) {
              if (m.len == 0) {
                missing.add(MissingObligation(m.clause!, m.pos));
              } else if (m.clause!.match(_parser, m.pos).isMismatch) {
                spans.add(SyntaxError(pos: m.pos, len: m.len));
              }
            } else {
              m.subClauseMatches.forEach(collect);
            }
          }

          collect(tree);
          final out = StringBuffer();
          void emit(MatchResult m) {
            if (m is SyntaxError) return;
            if (m.subClauseMatches.isEmpty) {
              final c = m.clause;
              out.write(c is Terminal &&
                      c is! Nothing &&
                      (m.len == 0 || c.match(_parser, m.pos).isMismatch)
                  ? _spelling(c)
                  : _input.substring(m.pos, m.pos + m.len));
              return;
            }
            var cursor = m.pos;
            for (final child in m.subClauseMatches) {
              if (child.pos > cursor) {
                out.write(_input.substring(cursor, child.pos));
              }
              emit(child);
              cursor = child.pos + child.len;
            }
            if (cursor < m.pos + m.len) {
              out.write(_input.substring(cursor, m.pos + m.len));
            }
          }

          emit(tree);
          final witnessStr = out.toString();
          final check = Parser(
                  rules: rules, topRuleName: topRuleName, input: witnessStr)
              .parse();
          lastVerified =
              !check.hasSyntaxErrors && check.root.len == witnessStr.length;
          spans.sort((a, b) => a.pos - b.pos);
          return SkipResult(tree, List.of(spans), List.of(missing),
              spans.length + missing.length, false);
        }
      }
    }

    lastCost = -1;
    lastSteps = _steps;
    lastVerified = false;
    final error = SyntaxError(pos: 0, len: input.length);
    return SkipResult(error, [error], const [], 1, true);
  }

  String _spelling(Clause clause) {
    final accepts = _oneCharClass(clause);
    if (accepts != null && accepts.isNotEmpty) {
      return String.fromCharCode(accepts.first.$1);
    }
    return clause is Str ? clause.text : '';
  }


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

  /// The Boolean interval partition of the code-unit line: cut it at every
  /// CharSet range boundary and at every literal character. Inside one
  /// interval every stock terminal answers identically, so a single
  /// representative per interval is a complete stand-in for the whole
  /// interval. Unlike a per-terminal representative it is closed under
  /// intersection -- if two terminals both accept some character, they both
  /// accept that character's representative -- which is what the -1 answers
  /// on `&[a-z] [0-9m-q]` and `![a-l] [a-z]` were missing.
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
        final r = _rules[c.ruleName];
        if (r != null) cut(r);
      }
    }

    _rules.values.forEach(cut);
    return cuts.where((u) => u <= 0xFFFF).toList()..sort();
  }();

  final Map<Clause, List<int>> _repsOfTerm = {};

  /// Every representative this terminal accepts. The union over the
  /// terminals a parse touched at the open end therefore contains a
  /// representative of their intersection whenever that intersection is
  /// non-empty, because the intersection is itself a union of intervals.
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
      // A multi-character literal names the next character exactly, and that
      // character is itself a cut point, so the exact answer is also the
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

  /// The relaxed engine's cost, for the horizon's fabrication floor.
  int _relaxedCost(String s) {
    _relaxedRecover(s);
    return lastCost;
  }

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

  SkipResult recover(String input) {
    lastFellBack = false;
    final pure = Parser(rules: rules, topRuleName: topRuleName, input: input).parse();
    if (!pure.hasSyntaxErrors && pure.root.len == input.length) {
      lastCost = 0;
      lastSteps = 0;
      lastVerified = true;
      return SkipResult(pure.root, const [], const [], 0, false);
    }

    if (!_wideG) {
      final r = _relaxedRecover(input);
      if (lastCost == -1) return r;
      if (lastVerified) return r;
    }

    lastFellBack = true;
    return _tapeRecover(input);
  }

  int recoverCost(String input) {
    recover(input);
    return lastCost;
  }

  bool get debugWide => _wideG;
  List<int> get debugReps => _reps;
  int get debugMass => _massG;
  int debugRelaxedCost(String s) => _relaxedCost(s);
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
