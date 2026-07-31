// m59 -- THE MINIMAL MANIFESTATION: recovery is the parser over a wider value,
// computed as a fixed point per edit-count bucket, each bucket drained once.
//
// This file is the m-line's feature set -- sound and exact under lookahead,
// minimal repairs with the derived tie-break, a rebuilt and VERIFIED witness
// tree, stack-safe on both recursion directions, zero parameters -- rewritten
// from the principles down, with every mechanism that any occasion demoted to
// an optimization deleted. What remains is the irreducible core, and each
// section of it answers to one named requirement:
//
//   I1  THE VALUE. A match is "the cheapest repair to each end"; a mismatch is
//       the empty set. The parser's fixed-point test -- the match did not get
//       longer -- becomes "no key is new and no price is lower", and by I9 that
//       test IS the write (`_keepBest` says whether it improved).
//   I2  A TERMINAL MAY LIE: consume a character it does not accept (SUB) or
//       consume nothing and claim it did (FAB), price one each. Deletion is not
//       a third edit: it is SUB on `Nothing`, repeated (`_junk`).
//   I3  THE ORACLE IS AUTHORITATIVE AS FAR AS THE EDIT-FREE WINDOW REACHES: a
//       zero-cost alternative that ends past where PEG itself committed is
//       unreachable on the repaired string, and is dropped. Four lines.
//   I6/I7  A LOOKAHEAD IS A CONSTRAINT ON THE NEXT CHARACTER EMITTED. It enters
//       a frame as the argument `c`, crosses inside the value's key as `owed`,
//       and is discharged by an emission or by the end of the string. DOWN THE
//       TREE IS THE ARGUMENT, ACROSS THE TREE IS THE VALUE, UP THE TREE IS THE
//       MEMO -- the parser's own left-recursion bit generalized to every fact a
//       frame cannot compute alone.
//   I5  THE WITNESS IS A PROOF, SO CHECK IT: emit s', parse it, report the
//       verdict. One linear parse against a polynomial search.
//   I15 THE BUCKET IS THE ROUND, RUN ONCE. Facts are processed in edit-count
//       order: bucket k is drained to its fixed point (chaotic iteration, LIFO,
//       the memo entry doubling as the message channel), then the goal is read,
//       then k+1. Cost classes are all that exactness needs ordered (A3), so
//       the scheduler is an ARRAY INDEX -- no heap, no priority, no budget
//       argument, no deepening re-runs. A combination priced past the current
//       bucket is deferred and the cell re-dirties itself where it becomes
//       payable, so production stops at the answer the way processing does.
//
//       Termination needs no ceiling: keys are finite and prices only fall, so
//       every bucket empties and an unrepairable input simply runs out of
//       buckets. (`maxCost`, `_goalFromNothing` and its predicate tiers, the
//       packed-Delta cost unit, and the deepening loop are all deleted; a
//       quiet-ROUND stop rule was checked and is UNSOUND -- `S <- A A;
//       A <- "xxxxx";` on "" is quiet for four rounds and answers at ten --
//       but a bucket drain has no quiet rounds, only empty buckets.)
//
// The pricing is A1/A2, unchanged and derived: SUB/FAB/SKIP cost 1; among
// minimum-cost repairs prefer least unjustified information, regret =
// sum(kept w) + 2*sum(skipped h) with FAB charging the whole alphabet. Delta
// is the PAIR (cost, regret) compared lexicographically -- A3 stated directly
// instead of encoded into one scaled integer, which is what deletes the cost
// unit and its derivation.
//
// What was deliberately kept although optional, and why: I4's static fusion of
// a one-character lookahead into the reader beside it (19 lines) -- measured
// answer-neutral, kept so witness trees and work are spelling-invariant and
// bit-identical to m53's. What was deliberately dropped, and what it costs:
// the creation-time oracle seed and its `noLook` pass (the `budget == 0` short
// circuit, ~2x battery), the I11 edge slots (~1.1x), the position-rank heap
// (~1.3x steps): every one is speed, none is an answer.
//
// PARAMETERS: NONE. HEURISTICS: the shortest-head witness tie-break (output),
// I4 (work), the whole-input error span when a witness cannot be rebuilt
// (presentation). Everything else is derived.
import 'dart:math' as math;
import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/recovery/skip_recovery.dart'
    show SkipResult, MissingObligation;


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

  /// Every node denotes a clause -- a sequence's suffix as much as the
  /// sequence -- which is what lets `_build` label any node and the veto ask
  /// the oracle anywhere.
  final Clause orig;
}

class _Term extends _Node {
  _Term(super.id, super.orig, this.editable, this.demands);

  /// I2 applies only to a leaf that consumes: a predicate or `Nothing` edits
  /// the derivation, not the string.
  final bool editable;

  /// I6: the class a one-character lookahead demands of the next emission, or
  /// `_free`.
  final int demands;
}

class _Cons extends _Node {
  _Cons(super.id, super.orig);
  late final _Node head;

  /// The rest of the sequence -- or THIS node, which is what a repetition is.
  late _Node tail;
}

class _Alt extends _Node {
  _Alt(super.id, super.orig);
  late final List<_Node> alts;
}

/// One memo cell, and the unit of work. The value is I9's flat triple list
/// `[key, cost, regret, ...]`, written into for the cell's whole life; a cell
/// nobody has settled reads as the empty set, which is the left-recursion seed.
class _Cell {
  _Cell(this.node, this.pos, this.c);
  final _Node node;
  final int pos;
  final int c;
  List<int>? value;

  /// The bucket this cell was last queued into (-1 = none): one int dedupes
  /// the common wake, and a stale duplicate costs one idempotent relaxation.
  int queuedAt = -1;

  /// The reverse edges. Consumed by the wake (I10): a woken reader re-reads
  /// what it still depends on and re-declares itself, so the list holds live
  /// readers only.
  final List<_Cell> readers = [];
}

class SuperDot3 {
  final Map<String, Clause> rules;
  final String topRuleName;
  SuperDot3({required this.rules, required this.topRuleName});

  late final Map<String, Clause> _rules = {
    for (final e in rules.entries)
      (e.key.startsWith('~') ? e.key.substring(1) : e.key): e.value,
  };

  // ---- building the normal form -------------------------------------------

  final Map<Clause, _Node> _nodes = {};
  final List<Clause> _terminals = [];
  int _nodeCount = 0;

  _Node _term(Clause clause, bool editable, int demands) {
    if (editable) _terminals.add(clause);
    return _Term(_nodeCount++, clause, editable, demands);
  }

  /// The empty match: last alternative of every Optional, and the end of every
  /// cons chain. It emits nothing, so it passes an obligation on.
  late final _Node _eps = _term(const Nothing(), false, _free);

  _Cons _selfLoop(_Node head, Clause orig) {
    final loop = _Cons(_nodeCount++, orig)..head = head;
    return loop..tail = loop;
  }

  /// Deletion, whole: `Nothing`, allowed to lie, repeated. Its SUB consumes a
  /// character and emits the empty string. One node for the whole grammar, so
  /// a discarded run is one witness leaf and every terminal shares its column.
  late final _Node _junk =
      _selfLoop(_term(const Nothing(), true, _free), const Nothing());

  /// A4: a gap attaches in front of whatever READS the input next, so every
  /// reader is wrapped with the junk loop, and nothing else mentions deletion.
  _Node _wrap(_Node reader, Clause orig) => _Cons(_nodeCount++, orig)
    ..head = _junk
    ..tail = reader;

  /// The alphabet the parser compares over.
  static const int _lastCodeUnit = 0xFFFF;

  /// The code units a clause accepts as exactly one character, seen through
  /// names and one-character choices, or null.
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

  // ---- I6/I7: the obligation lattice --------------------------------------
  //
  // An obligation is an interned class of code units: "the next character
  // emitted is one of these". `_free` is the top; the empty class is an
  // unsatisfiable debt and needs no special case. END OF INPUT IS A MEMBER OF
  // THE ALPHABET (-1, which `codeUnitAt` never returns), which is the whole
  // difference between `&C` (C) and `!C` (complement of C, plus -1).

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

  /// A match emits the input it consumed, so the character in question is the
  /// one already there.
  bool _permitsFirst(int c, int pos) =>
      c == _free || _has(c, _input.codeUnitAt(pos));

  /// The one discharge that is not an emission, asked only at the top.
  bool _permitsEnd(int c) => c == _free || _has(c, _endMark);

  List<(int, int)>? _looks(Clause clause) => switch (clause) {
        FollowedBy(:final subClause) => _oneCharClass(subClause),
        NotFollowedBy(:final subClause) => switch (_oneCharClass(subClause)) {
            final looked? => [..._complement(looked), (_endMark, _endMark)],
            null => null,
          },
        _ => null,
      };

  /// I4: `&C T` IS the class C∩T when both are one character wide -- kept as a
  /// work-and-witness normalization (measured answer-neutral in m49).
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
      // A leaf. Only a consuming terminal may lie; an unfused one-character
      // lookahead carries its class as an obligation and, deciding nothing
      // about where it stands, takes no junk wrapper.
      final accepts = _oneCharClass(clause);
      final looks = _looks(clause);
      final leaf = _term(clause, accepts?.isNotEmpty ?? clause is Terminal,
          looks == null ? _free : _intern(looks));
      node = looks == null ? _wrap(leaf, clause) : leaf;
    }
    return _nodes[clause] = node;
  }

  /// The goal: the top rule, then the one gap with no reader after it.
  late final _Node _goal =
      _Cons(_nodeCount++, Seq([_rules[topRuleName]!, const Nothing()]))
        ..head = _node(_rules[topRuleName]!)
        ..tail = _wrap(_eps, const Nothing());

  // ---- per-input state ----------------------------------------------------

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

  /// h(c): the narrowest class in G accepting the character, decided by the
  /// oracle so nothing here re-implements what a terminal means.
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

  /// A2 absolute pricing makes a clean subtree's regret a closed form.
  int _cleanRegret(MatchResult m) =>
      _cleanRegrets[m] ??= m.subClauseMatches.isEmpty
          ? _widthOf(m.clause!) * m.len
          : m.subClauseMatches.fold(0, (sum, sub) => sum + _cleanRegret(sub));

  // ---- the value: triples, written in place -------------------------------

  /// Delta is the PAIR (cost, regret), lexicographic (A3). Record it for `key`
  /// unless a better one is there, and SAY WHETHER IT IMPROVED (I9: the fixed
  /// point test is the write).
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

  /// I7's key: where a derivation ended and what it still owes there, packed.
  int _key(int end, int owed) => ((owed + 1) << _posShift) | end;
  int _endOf(int key) => key & (_span - 1);
  int _oweOf(int key) => (key >> _posShift) - 1;

  final Map<int, _Cell> _cells = {};
  int _posShift = 0, _span = 0;

  _Cell? _cellAt(_Node node, int pos, int c, [_Cell? reader]) {
    if (pos > _inputLen) return null;
    final cell = _cells.putIfAbsent(
        (((c + 1) * (_nodeCount + 1) + node.id) << _posShift) | pos, () {
      final fresh = _Cell(node, pos, c);
      _dirty(fresh, _k);
      return fresh;
    });
    if (reader != null) cell.readers.add(reader);
    return cell;
  }

  // ---- I15: the bucket queue ----------------------------------------------

  final List<List<_Cell>> _buckets = [];
  int _k = 0;
  late List<int> _out;
  bool _improved = false;

  /// The min bucket a combination was deferred to this relaxation, so the cell
  /// re-dirties itself where production becomes payable.
  int _deferred = 1 << 30;

  void _dirty(_Cell cell, int k) {
    if (cell.queuedAt == k) return;
    cell.queuedAt = k;
    while (_buckets.length <= k) {
      _buckets.add([]);
    }
    _buckets[k].add(cell);
  }

  void _put(int key, int cost, int reg) {
    if (cost > _k) {
      if (cost < _deferred) _deferred = cost;
      return;
    }
    if (_keepBest(_out, key, cost, reg)) _improved = true;
  }

  void _relax(_Cell cell) {
    _steps++;
    _out = cell.value ??= <int>[];
    _improved = false;
    _deferred = 1 << 30;
    _compute(cell);
    if (_deferred < 1 << 30) _dirty(cell, _deferred);
    if (!_improved) return;
    // I10: the wake consumes the reverse edge; a woken reader re-declares
    // itself by re-reading.
    for (final reader in cell.readers) {
      _dirty(reader, _k);
    }
    cell.readers.clear();
  }

  // ---- the recurrence: one case per node kind ------------------------------

  void _compute(_Cell cell) {
    final node = cell.node;
    final pos = cell.pos;
    final c = cell.c;
    switch (node) {
      case _Cons():
        final loops = identical(node.tail, node);
        // A repetition may stop where it stands, owing what it was given.
        if (loops) _put(_key(pos, c), 0, 0);
        final heads = _cellAt(node.head, pos, c, cell)?.value;
        if (heads == null) return;
        for (var i = 0; i < heads.length; i += 3) {
          final headKey = heads[i], hCost = heads[i + 1], hReg = heads[i + 2];
          final headEnd = _endOf(headKey);
          // The zero-width cut: re-entering the identical state is left
          // recursion, absorbed by the fixed point; skipping it is speed only.
          if (loops && headEnd == pos) continue;
          if (hCost > _k) {
            if (hCost < _deferred) _deferred = hCost;
            continue;
          }
          // I7, whole: the tail is asked under what the head still owes.
          final rest = _cellAt(node.tail, headEnd, _oweOf(headKey), cell)?.value;
          if (rest == null) continue;
          for (var j = 0; j < rest.length; j += 3) {
            _put(rest[j], hCost + rest[j + 1], hReg + rest[j + 2]);
          }
        }
      case _Alt(:final alts):
        // I3: where PEG itself committed on the input, a free-riding cheaper
        // end is unreachable on s'. Ask the MEMO (the raw call returns a
        // left-recursive seed at a rule body).
        final oracle = _parser.match(node.orig, pos);
        final committed = oracle.isMismatch ? -1 : pos + oracle.len;
        for (final alt in alts) {
          final ends = _cellAt(alt, pos, c, cell)?.value;
          if (ends == null) continue;
          for (var i = 0; i < ends.length; i += 3) {
            final key = ends[i], cost = ends[i + 1];
            if (cost == 0 &&
                alts.length > 1 &&
                _endOf(key) > committed &&
                (committed >= 0 || _oweOf(key) == _free)) {
              continue;
            }
            _put(key, cost, ends[i + 2]);
          }
        }
      case _Term(:final editable, :final demands):
        // A lookahead is the plainest node: consumes nothing, emits nothing,
        // adds its class to the debt. No oracle call -- it reads s'.
        if (demands != _free) {
          _put(_key(pos, _meet(c, demands)), 0, 0);
          return;
        }
        final m = node.orig.match(_parser, pos);
        if (!m.isMismatch) {
          if (m.len == 0) {
            _put(_key(pos, c), 0, _cleanRegret(m));
          } else if (_permitsFirst(c, pos)) {
            _put(_key(pos + m.len, _free), 0, _cleanRegret(m));
          }
        }
        if (!editable) return;
        // I2 meets I7: both lies emit what the terminal accepts, so one class
        // decides both; a silent lie (`Nothing`: deletion) passes the debt on.
        final emits = _oneCharClass(node.orig);
        final silent = emits == null || emits.isEmpty;
        if (!silent && !_permits(c, emits)) return;
        final owed = silent ? c : _free;
        if (pos < _inputLen) {
          _put(_key(pos + 1, owed), 1, 2 * _skipRegret(pos, pos + 1)); // SUB
        }
        _put(_key(pos, owed), 1, _widestClass); // FAB
    }
  }

  // ---- reconstruction: replay, shortest head first -------------------------

  final List<SyntaxError> _spans = [];
  final List<MissingObligation> _missing = [];
  final Set<(_Alt, int, int, int, int)> _path = {};

  List<int> _peek(_Node node, int pos, int c) => pos > _inputLen
      ? const []
      : _cells[(((c + 1) * (_nodeCount + 1) + node.id) << _posShift) | pos]
              ?.value ??
          const [];

  /// The (cost, regret) recorded for `key`, or null.
  (int, int)? _deltaOf(List<int> v, int key) {
    for (var i = 0; i < v.length; i += 3) {
      if (v[i] == key) return (v[i + 1], v[i + 2]);
    }
    return null;
  }

  MatchResult? _build(_Node node, int pos, int key, int cost, int reg, int c) {
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
        // A lying leaf may not lie freely: it emits within what is owed.
        final accepts = c == _free ? null : _oneCharClass(orig);
        return Match(
            accepts == null ? orig : CharSet(_intersect(accepts, _classes[c])),
            pos,
            end - pos);
      case _Alt(:final alts):
        final state = (node, pos, key, cost, c);
        if (!_path.add(state)) return null;
        for (final alt in alts) {
          if (_deltaOf(_peek(alt, pos, c), key) != (cost, reg)) continue;
          final m = _child(alt, pos, key, cost, reg, c);
          if (m != null) {
            _path.remove(state);
            return Match(orig, pos, end - pos, subClauseMatches: m);
          }
        }
        _path.remove(state);
        return null;
      case _Cons():
        final children = _row(node, pos, key, cost, reg, c);
        return children == null
            ? null
            : Match(orig, pos, end - pos, subClauseMatches: children);
    }
  }

  /// A discarded run is ONE leaf; the wrapper it rides in is spliced, so a
  /// clean parse reconstructs to exactly the pure parser's tree.
  List<MatchResult>? _child(
      _Node node, int pos, int key, int cost, int reg, int c) {
    if (identical(node, _junk)) {
      final end = _endOf(key);
      return end == pos ? const [] : [SyntaxError(pos: pos, len: end - pos)];
    }
    if (node is _Cons && identical(node.head, _junk)) {
      return _row(node, pos, key, cost, reg, c);
    }
    final m = _build(node, pos, key, cost, reg, c);
    return m == null ? null : [m];
  }

  List<MatchResult>? _row(
      _Node node, int pos, int key, int cost, int reg, int c) {
    if (node is! _Cons) {
      return identical(node, _eps)
          ? (key == _key(pos, c) && cost == 0 && reg == 0 ? const [] : null)
          : _child(node, pos, key, cost, reg, c);
    }
    final loops = identical(node.tail, node);
    final heads = _peek(node.head, pos, c);
    // The one output-affecting heuristic: among Delta-tied decompositions take
    // the shortest head, so discarded text stays outside subtrees.
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
      final rest = _deltaOf(_peek(node.tail, headEnd, headOwed), key);
      if (rest == null || rest.$1 != cost - hCost || rest.$2 != reg - hReg) {
        continue;
      }
      final head = _child(node.head, pos, headKey, hCost, hReg, c);
      if (head == null) continue;
      final tail = _row(node.tail, headEnd, key, rest.$1, rest.$2, headOwed);
      if (tail != null) return [...head, ...tail];
    }
    return loops && key == _key(pos, c) && cost == 0 && reg == 0
        ? const []
        : null;
  }

  /// Diagnostics are read off the finished tree: a SKIP is a SyntaxError leaf,
  /// a FAB a zero-width terminal, a SUB a terminal the parser rejects there.
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

  // ---- I5: the witness is a proof, so check it ----------------------------

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

  // ---- entry points -------------------------------------------------------

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
        : _build(_goal, 0, _goalKey, _goalCost, _goalRegret, _free);
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
    _buckets.clear();
    _cleanRegrets.clear();
    _steps = 0;
    _k = 0;
    final goalCell = _cellAt(goal, 0, _free)!;
    // Drain bucket k to its fixed point, read the goal, move to k+1. The
    // first bucket holding a satisfying fact holds the minimum, complete with
    // its regret ties. Running out of buckets IS unrepairability: keys are
    // finite and prices only fall, so nothing is ever left pending.
    for (_k = 0; _k < _buckets.length; _k++) {
      final bucket = _buckets[_k];
      while (bucket.isNotEmpty) {
        final cell = bucket.removeLast();
        cell.queuedAt = -1;
        _relax(cell);
      }
      final v = goalCell.value;
      if (v == null) continue;
      var bestC = 1 << 30, bestR = 1 << 30;
      for (var i = 0; i < v.length; i += 3) {
        if (_endOf(v[i]) != _inputLen || !_permitsEnd(_oweOf(v[i]))) continue;
        if (v[i + 1] < bestC || (v[i + 1] == bestC && v[i + 2] < bestR)) {
          bestC = v[i + 1];
          bestR = v[i + 2];
          _goalKey = v[i];
        }
      }
      if (bestC < 1 << 30) {
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
