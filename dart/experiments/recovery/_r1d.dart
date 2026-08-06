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
//                         it matches at pos + l. A span that does is a candidate
//                         syntax error [pos, pos+l).
//   4. advancement        install the candidate and re-descend. Keep it only if
//                         the parse now explains more of the input than before;
//                         otherwise take it back and go on widening. This is
//                         what lets a repair higher in the tree supersede a
//                         deeper one that could not continue.
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
// than by a guard. The price is stated plainly: a truncated document, whose only
// repair is a missing closing token, is beyond what this design can express.
import 'package:squirrel_parser/squirrel_parser.dart';

/// A match that carries skipped spans beside its children.
///
/// It extends [MatchResult] rather than [Match] because `Match` recomputes its
/// own span from its children, and so cannot represent a node that begins with a
/// skipped span. Its clause is null: the node is a wrapper saying "a span was
/// skipped here and then the clause matched", not a second occurrence of the
/// clause, and claiming otherwise would name every repaired rule twice.
class Repaired extends MatchResult {
  /// The grammar's own children, at the grammar's own indices -- the separation
  /// the brief asks for, so that child `i` still means subclause `i`.
  final List<MatchResult> children;
  final List<SyntaxError> errors;

  Repaired(int pos, int len, this.children, this.errors) : super(null, pos, len);

  /// Children and skipped spans together, in input order.
  ///
  /// Keeping the errors out of this would make the tree describe less than the
  /// whole input, and every consumer that walks a match -- coverage checks,
  /// skeletons, printers -- would see a hole exactly where the repair is.
  @override
  List<MatchResult> get subClauseMatches =>
      [...children, ...errors]..sort((a, b) => a.pos - b.pos);

  @override
  String toPrettyString(String input, {int indent = 0}) {
    final b = StringBuffer();
    for (final k in subClauseMatches) {
      b.write(k.toPrettyString(input, indent: indent));
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

  /// The position's cycle depth when this entry was last updated.
  int version = 0;
}

class Squirrel {
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
  final Map<Clause, Map<int, Repaired>> _repairs = {};

  /// Left-recursion cycle depth per position.
  late List<int> _version;

  /// Frontier state. It outlives a single call stack -- the walk builds it and
  /// the widening loop consumes it -- so it lives on the parser, and is rebuilt
  /// at the top of every round.
  final List<(Clause, int)> _frontier = [];
  final Map<Clause, Set<int>> _seen = {};

  /// (clause, pos) pairs already walked this round, and whether that walk
  /// reached a leaf. Walking is idempotent, so the memo only saves work -- but
  /// entering the key BEFORE the walk is also what stops a left-recursive
  /// cycle, exactly as the parser's own `inPath` does.
  final Map<(Clause, int), bool> _walked = {};

  /// Memo for [_salvage]. A null entry means "in progress", so a clause that
  /// re-enters itself at the same position gets a mismatch -- the paper's own
  /// answer to a left-recursive cycle seed. Only valid for the repairs it was
  /// computed under, so [_forget] drops it together with the parse memo.
  final Map<Clause, Map<int, MatchResult?>> _salvaged = {};

  /// Sites already tried. The brief commits on the FIRST new match of a clause
  /// at a position; a site tried once is no longer new, and refusing it again is
  /// what makes the round loop terminate.
  final Map<Clause, Set<int>> _tried = {};

  /// What the last [recover] left unaccounted for: characters its repairs
  /// skipped, plus obligations the input never supplied. Read off the emitted
  /// tree, so it charges for exactly what the tree says and nothing else.
  int lastCost = 0;

  // -- stage 1: the parser -------------------------------------------------

  /// The single point every clause match passes through, so that an installed
  /// repair is seen by normal parsing and by the frontier walk alike.
  MatchResult _match(Clause c, int pos) =>
      _repairs[c]?[pos] ?? (c is Ref ? _rule(c, pos) : _apply(c, pos));

  MatchResult _rule(Ref c, int pos) {
    final body = _memoized(rules[c.ruleName]!, pos);
    return body.isMismatch ? mismatch : Match(c, 0, 0, subClauseMatches: [body]);
  }

  /// Memoize a rule's top clause, expanding any left recursive cycle beneath it.
  MatchResult _memoized(Clause body, int pos) {
    if (pos > _in.length) return mismatch;
    final e = (_memo[body] ??= {}).putIfAbsent(pos, _Memo.new);
    if (e.result != null && (e.inPath || e.version == _version[pos])) {
      return e.result!;
    }
    if (e.inPath) {
      // Second visit on the same path with no result yet: the seed of a left
      // recursive cycle. Return a mismatch and tell the ancestral frame.
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
      for (var i = 0; i < c.subClauses.length; i++) {
        final r = _match(c.subClauses[i], curr);
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
        // A zero-length iteration would loop forever ("()*").
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

  /// Record a candidate. Only a clause that actually mismatches here is one: a
  /// clause that already matches needs no span skipped in front of it, which is
  /// what keeps an `Optional` or a `ZeroOrMore` from matching vacuously at l=1
  /// and making every repair explain nothing.
  /// Returns whether [c] mismatches at [pos] -- that is, whether this IS a leaf
  /// mismatch, whether or not the frontier had room to record it.
  bool _add(Clause c, int pos) {
    if (!_match(c, pos).isMismatch) return false;
    if (!(_tried[c]?.contains(pos) ?? false) && (_seen[c] ??= {}).add(pos)) {
      _frontier.add((c, pos));
    }
    return true;
  }

  /// Walk beneath [c] at [pos], and record [c] itself only if the walk reached
  /// no leaf. Returns whether anything was reached, [c] included.
  ///
  /// This is the brief's own distinction: a clause that mismatched BECAUSE its
  /// subclauses mismatched is an interior node of the failure, and the frontier
  /// is the leaves. Repairing an interior node means skipping input that its own
  /// descent already derived -- which is how `{"a":` loses its object and comes
  /// back as the top-level string `"a"`. A clause the walk found nothing beneath
  /// has no deeper evidence, so it is a leaf itself.
  bool _leaf(Clause c, int pos) => _walk(c, pos) || _add(c, pos);

  /// Collect the LEAF mismatches beneath [c] at [pos], deepest first, and say
  /// whether any were found.
  ///
  /// Memoized and cycle-guarded: a left-recursive rule reaches itself at the
  /// same position, and the descent would not otherwise end.
  bool _walk(Clause c, int pos) {
    final key = (c, pos);
    final done = _walked[key];
    if (done != null) return done;
    _walked[key] = false; // In progress; a re-entry here is a cycle seed.
    return _walked[key] = _descend(c, pos);
  }

  /// [_walk] without the memo. [c] always mismatches at [pos].
  bool _descend(Clause c, int pos) {
    if (_repairs[c]?[pos] != null) return false; // Already repaired here.
    if (c is Ref) return _walk(rules[c.ruleName]!, pos);
    if (c is First) {
      // All the arms failed, but they are not equally witnessed: an arm that
      // derived part of the input has evidence for it, and repairing a
      // different arm would mean discarding what that evidence already
      // committed to. So only the best-derived arms contribute candidates.
      // Where no arm derived anything the input says nothing, and every arm
      // ties, so nothing is lost. `_salvage` measures it, which keeps this rule
      // and the emit rule the same rule.
      final got = [
        for (final s in c.subClauses) _salvage(s, pos),
      ].map((r) => r.isMismatch ? 0 : r.len).toList();
      final best = got.reduce((a, b) => a > b ? a : b);
      var any = false;
      for (var i = 0; i < c.subClauses.length; i++) {
        if (got[i] == best && _walk(c.subClauses[i], pos)) any = true;
      }
      return any;
    }
    if (c is Seq) {
      var any = false;
      var curr = pos;
      for (var i = 0; i < c.subClauses.length; i++) {
        final r = _match(c.subClauses[i], curr);
        if (!r.isMismatch) {
          // Do not look for mismatches inside a subclause that matched -- but
          // something inside it may still have STOPPED short, and that stopping
          // point is a boundary the enclosing match cannot show.
          if (_stops(r)) any = true;
          curr += r.len;
          continue;
        }
        // ONLY the subclause that failed. The brief also offers every later one
        // at this position, but reaching such a repair means the sequence
        // matched with the elements before it absent -- a production asserted
        // without its required parts, which is inventing structure by deleting.
        return _leaf(c.subClauses[i], curr) || any;
      }
      return any;
    }
    if (c is Repetition) {
      var any = false;
      var curr = pos;
      while (curr <= _in.length) {
        final r = _match(c.subClause, curr);
        if (r.isMismatch || r.len == 0) break;
        if (_stops(r)) any = true;
        curr += r.len;
      }
      return _leaf(c.subClause, curr) || any;
    }
    if (c is Optional) return false; // Never mismatches; see [_stops].
    // A predicate consumes nothing, so a repair BENEATH one would be invisible
    // to the enclosing parse. The predicate itself is the leaf.
    return _add(c, pos); // Also a terminal that failed: the leaf itself.
  }

  /// A repetition or an option inside a MATCHED subtree stopped where its body
  /// mismatched, and swallowed that mismatch. Those stopping points are frontier
  /// candidates too, and for a match that merely ended early they are the only
  /// ones there are.
  bool _stops(MatchResult m) {
    var any = false;
    for (final k in m.subClauseMatches) {
      if (_stops(k)) any = true;
    }
    final c = m.clause;
    if (c is First && m.subClauseMatches.length == 1) {
      // The arms BEFORE the one that matched all failed, and one of them may
      // have got much further before it did -- `1++2` parses as the bare `Term`
      // `1`, and the whole story is in the `Expr` arm that reached `1+` and
      // stopped. A shorter arm winning is a stopping point like any other.
      final took = m.subClauseMatches.first.clause;
      for (final s in c.subClauses) {
        if (identical(s, took)) break;
        if (_match(s, m.pos).isMismatch && _leaf(s, m.pos)) any = true;
      }
    }
    final body = c is Repetition
        ? c.subClause
        : c is Optional
            ? c.subClause
            : null;
    if (body == null) return any;
    final end = m.pos + m.len;
    if (!_match(body, end).isMismatch) return any;
    return _leaf(body, end) || any;
  }

  // -- stages 3, 4 and 5 ---------------------------------------------------

  /// Re-descend from the top rule with the repairs currently installed, and
  /// measure how much of the input the parse explains.
  /// Drop everything computed under the repairs as they were.
  void _forget() {
    _memo.clear();
    _salvaged.clear();
  }

  MatchResult _parse() {
    _forget();
    _version = List.filled(_in.length + 1, 0);
    return _memoized(rules[topRuleName]!, 0);
  }

  /// What a tree leaves unaccounted for: characters DELETED, then obligations
  /// left OPEN. Everything is measured this way -- which alternative the input
  /// witnesses, whether a repair is worth installing, and what finally gets
  /// emitted -- so all three answer one question.
  ///
  /// The measure used to be how much the parse EXPLAINS, maximized. That is a
  /// different question, and it fails on `x:q` against `Pair <- Key ':' Value`:
  /// it deletes the real `:` so `Key` can swallow `q` and reach the end of the
  /// input, leaving BOTH `':'` and `Value` unfilled. A longer derivation bought
  /// with two more open obligations is not a better one.
  ///
  /// The two kinds are ORDERED, not summed. Deleting a character contradicts
  /// evidence the input actually supplied; a gap only records evidence it never
  /// supplied. The input is primal, so no number of gaps justifies destroying
  /// one real character that already matched. `{ a=1; b=2;` is the case that
  /// forces it: reading it as a `Block` whose `'}'` never arrived costs two
  /// gaps, and deleting the `{` so the statements stand alone costs two
  /// characters. Summed, they tie -- and the tie falls toward throwing away the
  /// block the healthy prefix had already established.
  (int, int) _cost(MatchResult root) {
    final t = root.isMismatch ? _salvage(rules[topRuleName]!, 0) : root;
    if (t.isMismatch) return (_in.length + 1, 0);
    final (del, gap) = _edits(t);
    return (del + (_in.length - t.len), gap);
  }

  static bool _cheaper((int, int) a, (int, int) b) =>
      a.$1 != b.$1 ? a.$1 < b.$1 : a.$2 < b.$2;

  /// Edits recorded inside [m]: a skipped span deletes its characters, and a
  /// zero-width mark is one obligation the input never supplied.
  (int, int) _edits(MatchResult m) {
    var del = 0, gap = 0;
    void walk(MatchResult k) {
      if (k is SyntaxError) {
        if (k.len == 0) {
          gap++;
        } else {
          del += k.len;
        }
      }
      k.subClauseMatches.forEach(walk);
    }

    walk(m);
    return (del, gap);
  }

  /// Widen the span until some site lowers the cost, install the site that
  /// lowers it most, and return the new tree; null when nothing helps.
  ///
  /// Taking the BEST rather than the first is what makes a shallower repair able
  /// to supersede a deeper one: both may cost a little less, and the deeper one
  /// is reached first, but only one of them carries the parse on. Among equals
  /// the earliest in postorder wins, which is the deepest and most local.
  MatchResult? _round(MatchResult root, (int, int) base) {
    _frontier.clear();
    _seen.clear();
    _walked.clear();
    if (root.isMismatch) {
      _walk(rules[topRuleName]!, 0);
    } else {
      _stops(root);
    }
    for (var l = 1; l <= _in.length; l++) {
      Clause? bestClause;
      Repaired? bestRepair;
      var bestPos = -1;
      var best = base;
      for (final (c, p) in _frontier) {
        if (p + l > _in.length) continue;
        // A zero-length match is a real repair when the clause is zero-width: a
        // predicate that failed here can succeed a few characters along, and
        // that IS the recovery. Nothing vacuous gets through, because [_add]
        // already refused every clause that matches at `p` and the advancement
        // test below already refuses every repair that explains no more.
        final r = _match(c, p + l);
        if (r.isMismatch) continue;
        final repair =
            Repaired(p, l + r.len, [r], [SyntaxError(pos: p, len: l)]);
        (_repairs[c] ??= {})[p] = repair;
        final got = _cost(_parse());
        // Taking the repair back has to take back everything computed with it:
        // the memo still holds results that read it, and the walk and the emit
        // that follow would read those instead of the parse as it really is.
        _repairs[c]!.remove(p);
        _forget();
        if (_cheaper(got, best)) {
          best = got;
          bestClause = c;
          bestPos = p;
          bestRepair = repair;
        }
      }
      if (bestClause == null) continue; // No site helped; widen the span.
      _repairs[bestClause]![bestPos] = bestRepair!;
      (_tried[bestClause] ??= {}).add(bestPos);
      return _parse();
    }
    return null;
  }

  /// The longest derivation the grammar can build over a prefix from [pos],
  /// keeping what matched instead of discarding it.
  ///
  /// This is the pruning half of supersession: when no span completes the parse,
  /// the part of the tree that could not be recovered is dropped and the part
  /// that WAS derived is kept. Returning a bare syntax error instead would throw
  /// away a real derivation because its tail is missing. It runs once, at emit,
  /// so ordinary matching keeps PEG semantics exactly.
  MatchResult _salvage(Clause c, int pos) {
    final at = _salvaged[c] ??= {};
    if (at.containsKey(pos)) return at[pos] ?? mismatch;
    at[pos] = null;
    return at[pos] = _partial(c, pos);
  }

  MatchResult _partial(Clause c, int pos) {
    final whole = _match(c, pos);
    if (!whole.isMismatch) return whole;
    if (c is Ref) {
      final r = _salvage(rules[c.ruleName]!, pos);
      return r.isMismatch ? mismatch : Match(c, 0, 0, subClauseMatches: [r]);
    }
    if (c is First) {
      // Among alternatives that all failed, the one that derived the most is the
      // one the input gives the most evidence for.
      MatchResult best = mismatch;
      for (final s in c.subClauses) {
        final r = _salvage(s, pos);
        if (!r.isMismatch && (best.isMismatch || r.len > best.len)) best = r;
      }
      return best.isMismatch ? mismatch : Match(c, 0, 0, subClauseMatches: [best]);
    }
    if (c is Seq) {
      final kids = <MatchResult>[];
      var curr = pos;
      for (var i = 0; i < c.subClauses.length; i++) {
        final r = _match(c.subClauses[i], curr);
        if (!r.isMismatch) {
          kids.add(r);
          curr += r.len;
          continue;
        }
        // Slot `i` is where the production stops. A partial derivation of it is
        // still evidence, so keep it and count the slot as begun; otherwise the
        // slot is untouched and counts as outstanding too.
        final p = _salvage(c.subClauses[i], curr);
        var open = i;
        if (!p.isMismatch) {
          kids.add(p);
          curr += p.len;
          open = i + 1;
        }
        // Every subclause from `open` on is required by the grammar and
        // unsupplied by the input. Emitting the prefix alone would report a
        // production that was never derived, with nothing in the tree saying
        // which parts are missing -- `Pair <- Key ':' Value` on `x:` came back
        // as a complete-looking parse at cost 0. One zero-width mark per
        // unfilled slot says how many obligations are outstanding, without
        // inventing a single character to fill them.
        // Third horn of the trilemma: report nothing at all. A production the
        // input did not finish is not reported, so there is no short Seq and no
        // zero-width node -- the evidence in the prefix is simply discarded and
        // the parent sees a mismatch.
        if (open < c.subClauses.length) return mismatch;
        break;
      }
      return kids.isEmpty ? mismatch : Match(c, 0, 0, subClauseMatches: kids);
    }
    if (c is Repetition) {
      final kids = <MatchResult>[];
      var curr = pos;
      while (curr <= _in.length) {
        final r = _match(c.subClause, curr);
        if (r.isMismatch || r.len == 0) break;
        kids.add(r);
        curr += r.len;
      }
      final p = _salvage(c.subClause, curr);
      if (!p.isMismatch) kids.add(p);
      return kids.isEmpty ? mismatch : Match(c, 0, 0, subClauseMatches: kids);
    }
    return mismatch; // An option, a predicate or a terminal has no partial form.
  }

  /// Parse [s], recovering from syntax errors. Always covers the whole input.
  MatchResult recover(String s) {
    _in = s;
    _repairs.clear();
    _tried.clear();
    var root = _parse();
    // Every round repairs a site no round has repaired before, so the loop
    // cannot revisit a state; there are at most |G| * n sites. It also lowers a
    // non-negative integer each time, which is the shorter argument.
    while (root.isMismatch || root.len != s.length) {
      final next = _round(root, _cost(root));
      if (next == null) break;
      root = next;
    }
    if (root.isMismatch) root = _salvage(rules[topRuleName]!, 0);
    if (root.isMismatch) {
      root =
          Repaired(0, s.length, const [], [SyntaxError(pos: 0, len: s.length)]);
    } else if (root.len < s.length) {
      root = Repaired(0, s.length, [root],
          [SyntaxError(pos: root.len, len: s.length - root.len)]);
    }
    // The tree is the whole account, so read the cost straight off it rather
    // than tallying it as the rounds go: a repair the emit did not keep must not
    // be charged for, and a gap the emit introduced must be.
    final (del, gap) = _edits(root);
    lastCost = del + gap;
    return root;
  }

  int recoverCost(String s) {
    recover(s);
    return lastCost;
  }
}
