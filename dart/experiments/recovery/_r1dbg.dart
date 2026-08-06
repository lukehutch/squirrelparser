// r1.dart -- the squirrel parser, plus frontier-driven syntax-error spans.
//
// The parser is the paper's parser, unchanged in behaviour: memoized recursive
// descent, memoization at RULE granularity only, left recursion expanded
// iteratively by the frame that ENTERED the cycle. On an incomplete parse it
// switches to recovery, in four stages:
//
//   2. frontier finding   walk the failed descent, collecting LEAF mismatches
//                         -- the (clause, pos) pairs where skipping input could
//                         let the parse advance -- in postorder, so the deepest
//                         and earliest candidate is tried first and the repair
//                         stays as local as possible.
//   3. span widening      for l = 1, 2, 3, ..., ask each frontier clause whether
//                         it matches at pos + l. The first that does fixes the
//                         syntax error span [pos, pos+l).
//   4. advancement        drop the memos the repair invalidates, install the
//                         repaired match, and re-descend.
//   5. repeat             until the parse completes or no span helps.
//
// The one modification the design needs is `_match`, the single indirection
// through which every clause match passes. The frozen parser matches inner
// clauses by direct `subClause.match(parser, pos)` calls that never consult the
// memo table, so a repair installed at an inner frontier clause would never be
// read. Routing every match through one place gives repairs a single entry point
// that serves normal parsing and the frontier walk alike.
//
// The engine can only ever SKIP input, never invent it, so the rule against
// inventing a terminal of a class that is not there holds by construction rather
// than by a guard.
import 'package:squirrel_parser/squirrel_parser.dart';

bool trace = false;

/// A match that carries skipped spans beside its children.
///
/// The errors are kept OUT of [subClauseMatches] so that `subClauseMatches[i]`
/// still lines up with the grammar's `subClauses[i]`. It extends [MatchResult]
/// rather than [Match] because `Match` recomputes its own span from its
/// children, and so cannot represent a node that begins with a skipped span.
class Repaired extends MatchResult {
  @override
  final List<MatchResult> subClauseMatches;
  final List<SyntaxError> errors;

  Repaired(super.clause, super.pos, super.len, this.subClauseMatches, this.errors);

  @override
  String toPrettyString(String input, {int indent = 0}) {
    final b = StringBuffer('${'  ' * indent}'
        '${clause is Ref ? clause.toString() : clause.runtimeType.toString()}\n');
    for (final e in errors) {
      b.write(e.toPrettyString(input, indent: indent + 1));
    }
    for (final k in subClauseMatches) {
      b.write(k.toPrettyString(input, indent: indent + 1));
    }
    return b.toString();
  }
}

/// A memo table entry for a (rule, position) pair -- the paper's entry verbatim.
class _Memo {
  MatchResult? result;

  /// True while this (rule, pos) is on the current recursion path.
  bool inPath = false;

  /// Set by a descendant frame to tell this ancestral frame to expand the cycle.
  bool foundLR = false;

  /// The value of [_Squirrel._version] for this position when last updated.
  int version = 0;
}

class Squirrel {
  String _d(Clause c) { final t = c.toString(); return t.length > 30 ? '${t.substring(0,30)}..' : t; }
  final Map<String, Clause> rules = {};
  final Set<String> transparentRules = {};
  final String topRuleName;

  Squirrel({required Map<String, Clause> rules, required this.topRuleName}) {
    for (final e in rules.entries) {
      if (e.key.startsWith('~')) {
        this.rules[e.key.substring(1)] = e.value;
        transparentRules.add(e.key.substring(1));
      } else {
        this.rules[e.key] = e.value;
      }
    }
  }

  late String _in;

  /// Rule-level memo table, exactly as the paper describes it.
  final Map<Clause, Map<int, _Memo>> _memo = {};

  /// Installed repairs, consulted by [_match] before any clause is matched.
  /// Kept separate from [_memo] so the two are invalidated independently.
  final Map<Clause, Map<int, Repaired>> _repairs = {};

  /// Left-recursion cycle depth per position ("cycleDepthForPos" in the paper).
  late List<int> _version;

  /// Frontier state. It outlives a single call stack -- the walk builds it and
  /// the widening loop consumes it -- so it lives on the parser, and is cleared
  /// at the top of every round.
  final List<(Clause, int)> _frontier = [];
  final Map<Clause, Set<int>> _seen = {};

  /// Characters skipped by the repairs installed in the last [recover].
  int lastCost = 0;

  // -- stage 1: the parser -------------------------------------------------

  /// The single point every clause match passes through, so that an installed
  /// repair is seen by normal parsing and by the frontier walk alike.
  MatchResult _match(Clause c, int pos) {
    final r = _repairs[c]?[pos];
    if (r != null) return r;
    if (c is Ref) {
      final body = _memoized(rules[c.ruleName]!, pos);
      return body.isMismatch ? mismatch : Match(c, 0, 0, subClauseMatches: [body]);
    }
    return _apply(c, pos);
  }

  /// Memoize a rule's top clause, expanding any left recursive cycle beneath it.
  MatchResult _memoized(Clause body, int pos) {
    if (pos > _in.length) return mismatch;
    final e = (_memo[body] ??= {}).putIfAbsent(pos, _Memo.new);
    if (e.result != null && (e.inPath || e.version == _version[pos])) {
      return e.result!;
    }
    if (e.inPath) {
      // Second visit on the same path with no result yet: the fixed point of a
      // left recursive cycle. Seed with a mismatch and tell the ancestral frame.
      e.foundLR = true;
      return e.result = mismatch;
    }
    e.inPath = true;
    while (true) {
      final r = _match(body, pos);
      if (e.result != null && r.len <= e.result!.len) break;
      e.result = r;
      if (!e.foundLR) break;
      e.version = ++_version[pos];
    }
    e.inPath = false;
    e.version = _version[pos];
    return e.result!;
  }

  MatchResult _apply(Clause c, int pos) {
    if (c is Seq) {
      final kids = <MatchResult>[];
      var curr = pos;
      for (final s in c.subClauses) {
        final r = _match(s, curr);
        if (r.isMismatch) return mismatch;
        kids.add(r);
        curr += r.len;
      }
      return kids.isEmpty ? Match(c, pos, 0) : Match(c, 0, 0, subClauseMatches: kids);
    }
    if (c is First) {
      for (final s in c.subClauses) {
        final r = _match(s, pos);
        if (!r.isMismatch) return Match(c, 0, 0, subClauseMatches: [r]);
      }
      return mismatch;
    }
    if (c is Repetition) {
      final kids = <MatchResult>[];
      var curr = pos;
      while (curr <= _in.length) {
        final r = _match(c.subClause, curr);
        // A zero-length repetition would loop forever ("()*").
        if (r.isMismatch || r.len == 0) break;
        kids.add(r);
        curr += r.len;
      }
      if (c.requireOne && kids.isEmpty) return mismatch;
      return kids.isEmpty ? Match(c, pos, 0) : Match(c, 0, 0, subClauseMatches: kids);
    }
    if (c is Optional) {
      final r = _match(c.subClause, pos);
      return r.isMismatch ? Match(c, pos, 0) : Match(c, 0, 0, subClauseMatches: [r]);
    }
    if (c is FollowedBy) {
      return _match(c.subClause, pos).isMismatch ? mismatch : Match(c, pos, 0);
    }
    if (c is NotFollowedBy) {
      return _match(c.subClause, pos).isMismatch ? Match(c, pos, 0) : mismatch;
    }
    return _terminal(c, pos);
  }

  MatchResult _terminal(Clause c, int pos) {
    if (c is Str) {
      if (pos + c.text.length > _in.length) return mismatch;
      for (var i = 0; i < c.text.length; i++) {
        if (_in.codeUnitAt(pos + i) != c.text.codeUnitAt(i)) return mismatch;
      }
      return Match(c, pos, c.text.length);
    }
    if (c is Char) {
      if (pos >= _in.length || _in.codeUnitAt(pos) != c.char.codeUnitAt(0)) {
        return mismatch;
      }
      return Match(c, pos, 1);
    }
    if (c is CharSet) {
      if (pos >= _in.length) return mismatch;
      final ch = _in.codeUnitAt(pos);
      var inSet = false;
      for (final (lo, hi) in c.ranges) {
        if (ch >= lo && ch <= hi) {
          inSet = true;
          break;
        }
      }
      return (c.inverted ? !inSet : inSet) ? Match(c, pos, 1) : mismatch;
    }
    if (c is AnyChar) return pos >= _in.length ? mismatch : Match(c, pos, 1);
    if (c is Nothing) return Match(c, pos, 0);
    throw StateError('unknown clause type ${c.runtimeType}');
  }

  // -- stage 2: frontier finding -------------------------------------------

  void _add(Clause c, int pos) {
    if ((_seen[c] ??= {}).add(pos)) _frontier.add((c, pos));
  }

  /// Collect the LEAF mismatches beneath [c] at [pos], deepest first.
  ///
  /// A leaf mismatch is one reached by recursing deeper, not one a clause
  /// inherited from a failing subclause -- so a `First` whose arms all failed
  /// contributes its arms' leaves and nothing of its own.
  void _walk(Clause c, int pos) {
    // Already repaired here: the parse skips forward past this span instead.
    if (_repairs[c]?[pos] != null) return;
    if (c is Ref) return _walk(rules[c.ruleName]!, pos);
    if (c is First) {
      for (final s in c.subClauses) {
        _walk(s, pos);
      }
      return;
    }
    if (c is Seq) {
      var curr = pos;
      for (var i = 0; i < c.subClauses.length; i++) {
        final r = _match(c.subClauses[i], curr);
        if (!r.isMismatch) {
          curr += r.len;
          continue; // Do not recurse into a subclause that matched.
        }
        _walk(c.subClauses[i], curr);
        // Every subclause from the failure onwards is a candidate at the same
        // position: this is what lets a repair skip a subclause that is missing
        // outright and resume at a later element of the sequence.
        for (var j = i; j < c.subClauses.length; j++) {
          _add(c.subClauses[j], curr);
        }
        return;
      }
      return;
    }
    if (c is Repetition) {
      var curr = pos;
      while (curr <= _in.length) {
        final r = _match(c.subClause, curr);
        if (r.isMismatch || r.len == 0) break;
        curr += r.len;
      }
      _walk(c.subClause, curr);
      _add(c.subClause, curr);
      return;
    }
    if (c is Optional) return; // Never mismatches.
    // A predicate consumes nothing, so a repair BENEATH one would be invisible
    // to the enclosing parse. The predicate itself is the leaf.
    if (c is FollowedBy || c is NotFollowedBy) return _add(c, pos);
    _add(c, pos); // A terminal that failed: the leaf mismatch itself.
  }

  /// When the top rule matched but stopped short, nothing mismatched, so [_walk]
  /// never fires. The only boundaries a successful match leaves are the
  /// repetitions on its rightmost spine, where the body failed.
  void _walkShort(MatchResult m) {
    if (m.subClauseMatches.isNotEmpty) _walkShort(m.subClauseMatches.last);
    final c = m.clause;
    if (c is Repetition) {
      final end = m.pos + m.len;
      _walk(c.subClause, end);
      _add(c.subClause, end);
    }
  }

  // -- stages 3 and 4: widen the span, then advance ------------------------

  /// Find and install one repair. Returns false when no span helps.
  bool _round(MatchResult root) {
    _frontier.clear();
    _seen.clear();
    if (root.isMismatch) {
      _walk(rules[topRuleName]!, 0);
    } else {
      _walkShort(root);
    }
    if (trace) {
      print('    frontier (${_frontier.length}):');
      for (final (c, p) in _frontier) {
        print('      @$p  ${c.runtimeType}  ${_d(c)}');
      }
    }
    for (var l = 1; l <= _in.length; l++) {
      for (final (c, p) in _frontier) {
        if (p + l > _in.length) continue;
        final r = _match(c, p + l);
        // A zero-length match explains nothing, so skipping l characters to
        // reach it is a deletion, not a repair. Without this the Seq rule above
        // would let any Optional or ZeroOrMore after the failure point succeed
        // vacuously at l = 1 and every repair would be empty.
        if (r.isMismatch || r.len == 0) continue;
        if (trace) print('    INSTALL l=$l at $p ${_d(c)} -> matched ${r.len}');
        _install(c, p, l, r);
        return true;
      }
    }
    return false;
  }

  void _install(Clause c, int p, int l, MatchResult r) {
    // Drop exactly the memos the repair can change: a mismatch at or before the
    // repair, whose descent could have reached it and would now succeed; and a
    // match reaching it, which could now extend or take an earlier First arm.
    // Everything else consulted nothing that changed, which is what keeps this
    // from degenerating into a full re-parse per repair.
    for (final byPos in _memo.values) {
      byPos.removeWhere((q, e) {
        final res = e.result;
        return res == null || (res.isMismatch ? q <= p : q + res.len >= p);
      });
    }
    (_repairs[c] ??= {})[p] =
        Repaired(c, p, l + r.len, [r], [SyntaxError(pos: p, len: l)]);
    lastCost += l;
  }

  // -- stage 5: iterate ----------------------------------------------------

  /// Parse [s], recovering from syntax errors. Always covers the whole input.
  MatchResult recover(String s) {
    _in = s;
    _memo.clear();
    _repairs.clear();
    _version = List.filled(s.length + 1, 0);
    lastCost = 0;
    final top = rules[topRuleName]!;
    var root = _memoized(top, 0);
    // Each repair adds at least one character to the union of skipped spans, so
    // there can be at most one round per character of input.
    for (var round = 0; round <= s.length; round++) {
      if (!root.isMismatch && root.len == s.length) break;
      if (trace) print('  round $round: root=${root.isMismatch ? "MISMATCH" : "len ${root.len}/${s.length}"}');
      if (!_round(root)) { if (trace) print('    no span helps'); break; }
      root = _memoized(top, 0);
    }
    if (root.isMismatch) {
      lastCost = s.length;
      return Repaired(null, 0, s.length, const [], [SyntaxError(pos: 0, len: s.length)]);
    }
    if (root.len < s.length) {
      lastCost += s.length - root.len;
      return Repaired(root.clause, 0, s.length, [root],
          [SyntaxError(pos: root.len, len: s.length - root.len)]);
    }
    return root;
  }

  int recoverCost(String s) {
    recover(s);
    return lastCost;
  }
}
