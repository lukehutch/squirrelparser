// _codex79.dart -- AST-first PEG recovery prototype.
//
// The parser never constructs a repaired string.  A fact is a path through the
// grammar over positions in the original input, containing ordinary terminal
// matches and SyntaxError nodes.  Predicates consult only cost-zero facts at
// their original position.  Recovery has one error constructor:
//
//   Error(actual span, expected clause?)
//
// A non-empty span is unsupported evidence.  An empty span is admitted only
// for a singleton terminal, and a recovered named rule must contain independent
// exact evidence.  Consequently a comma or brace can be absent inside an
// evidenced Array/Object, but a [0-9] value cannot be fabricated.
//
// _FactClause is the bridge to the frozen parser.  It puts recovery facts in a
// MatchResult stored by the existing MemoEntry.  Its synthetic len is a growth
// generation, so MemoEntry's own left-recursion entrant performs the fixed
// point.  The demand-local budget is curried into that clause's identity.  A
// memoVersion bump broadens localized facts into synchronization-span facts in
// place; no memo entry is removed and no second Parser is created.

import 'dart:math' as math;

import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/recovery/skip_recovery.dart'
    show MissingObligation, SkipResult;

typedef _Shape = (String, int, int);

class _Fact {
  const _Fact({
    required this.end,
    required this.cost,
    required this.nodes,
    required this.evidence,
    required this.shapes,
    required this.missing,
    required this.skipped,
    this.branch = -1,
    this.firstEvidence = 0x3fffffff,
    this.firstAmbiguous = 0x3fffffff,
  });

  final int end;
  final int cost;
  final List<MatchResult> nodes;
  final Set<int> evidence;
  final Set<_Shape> shapes;
  final List<MissingObligation> missing;
  final int skipped;
  final int branch;
  final int firstEvidence;
  final int firstAmbiguous;
}

class _FactMatch extends Match {
  _FactMatch(super.clause, super.pos, super.len, this.facts);

  final List<_Fact> facts;
}

class _FactClause extends Clause {
  const _FactClause(this.owner, this.original, this.budget);

  final AstFirstParser owner;
  final Clause original;
  final int budget;

  @override
  MatchResult match(Parser parser, int pos) {
    if (!identical(parser, owner)) {
      throw StateError('a recovery cell was used by another Parser');
    }
    return owner._computeCell(this, pos);
  }

  @override
  void checkRuleRefs(Map<String, Clause> grammarMap) {}

  @override
  String toString() => '<facts[$budget] $original>';
}

class _End extends Clause {
  const _End();

  @override
  MatchResult match(Parser parser, int pos) =>
      throw UnsupportedError('_End is evaluated by AstFirstParser');

  @override
  void checkRuleRefs(Map<String, Clause> grammarMap) {}

  @override
  String toString() => '<original end>';
}

class _Goal extends Clause {
  const _Goal(this.body, this.end);

  final Clause body;
  final _End end;

  @override
  MatchResult match(Parser parser, int pos) =>
      throw UnsupportedError('_Goal is evaluated by AstFirstParser');

  @override
  void checkRuleRefs(Map<String, Clause> grammarMap) {}

  @override
  String toString() => '<goal>';
}

class _RepState {
  const _RepState(this.fact, this.count);
  final _Fact fact;
  final int count;
}

/// A single Parser instance whose one frozen memo table stores both strict and
/// recovered facts.  Construct one instance per input and call [recover] once.
class AstFirstParser extends Parser {
  AstFirstParser({
    required super.rules,
    required super.topRuleName,
    required super.input,
  }) {
    _end = const _End();
    _goal = _Goal(rules[topRuleName]!, _end);
    _clauseCount = _countClauses(rules[topRuleName]!);
  }

  final Map<(Clause, int), _FactClause> _factClauses = {};
  final Map<Str, List<Char>> _literalParts = Map<Str, List<Char>>.identity();
  final Map<Terminal, int?> _singletons = Map<Terminal, int?>.identity();
  final Set<(Clause, int)> _touched = {};
  late final _End _end;
  late final _Goal _goal;
  late final int _clauseCount;
  int _budget = 0;
  bool _allowSpans = false;
  int _spanLimit = 0;
  bool _ran = false;

  int lastCost = -1;
  int lastCells = 0;
  int lastBudget = -1;

  _FactClause _cell(Clause clause, int budget) => _factClauses
      .putIfAbsent((clause, budget), () => _FactClause(this, clause, budget));

  List<_Fact> _demand(Clause clause, int pos, {int? budget}) {
    final allowed = budget ?? _budget;
    if (allowed < 0 || pos > input.length) return const [];
    final result = match(_cell(clause, allowed), pos);
    if (result is! _FactMatch) return const [];
    return _visible(clause, result.facts, allowed);
  }

  MatchResult _computeCell(_FactClause cell, int pos) {
    _touched.add((cell.original, pos));
    final previous = getMemoEntry(cell, pos)?.result;
    final old = previous is _FactMatch ? previous.facts : const <_Fact>[];
    final savedBudget = _budget;
    _budget = cell.budget;
    final List<_Fact> raw;
    if (cell.budget == 0 && cell.original is! _Goal && cell.original is! _End) {
      final pure = _pureFact(cell.original, pos);
      raw = pure == null ? const [] : [pure];
    } else {
      raw = _raw(cell.original, pos);
    }
    _budget = savedBudget;
    final (merged, changed) = _mergeDurable(old, raw);

    if (previous == null) return _FactMatch(cell, pos, 0, merged);
    if (previous.isMismatch && merged.isEmpty) return mismatch;
    final generation = previous is _FactMatch ? previous.len : -1;
    return _FactMatch(cell, pos, changed ? generation + 1 : generation, merged);
  }

  (List<_Fact>, bool) _mergeDurable(List<_Fact> old, List<_Fact> fresh) {
    final byKey = <(int, int, int), _Fact>{
      for (final fact in old) (fact.end, fact.cost, fact.branch): fact,
    };
    var changed = old.isEmpty && fresh.isNotEmpty;
    for (final fact in fresh) {
      final key = (fact.end, fact.cost, fact.branch);
      final prior = byKey[key];
      if (prior == null || _better(fact, prior)) {
        byKey[key] = fact;
        changed = true;
      }
    }
    if (!changed) return (old, false);
    final out = byKey.values.toList()
      ..sort((a, b) {
        var d = a.cost - b.cost;
        if (d != 0) return d;
        d = a.end - b.end;
        if (d != 0) return d;
        return a.branch - b.branch;
      });
    return (List.unmodifiable(out), true);
  }

  List<_Fact> _prune(Iterable<_Fact> facts) {
    final byKey = <(int, int, int), _Fact>{};
    for (final fact in facts) {
      if (fact.cost > _budget || fact.end > input.length) continue;
      final key = (fact.end, fact.cost, fact.branch);
      final old = byKey[key];
      if (old == null || _better(fact, old)) byKey[key] = fact;
    }
    return byKey.values.toList();
  }

  bool _better(_Fact a, _Fact b) {
    if (a.skipped != b.skipped) return a.skipped < b.skipped;
    if (a.shapes.length != b.shapes.length) {
      return a.shapes.length > b.shapes.length;
    }
    if (a.evidence.length != b.evidence.length) {
      return a.evidence.length > b.evidence.length;
    }
    if (a.missing.length != b.missing.length) {
      return a.missing.length < b.missing.length;
    }
    return a.branch < b.branch;
  }

  List<_Fact> _visible(Clause clause, List<_Fact> durable, int budget) {
    var facts = durable.where((f) => f.cost <= budget).toList();
    final exact = facts.where((f) => f.cost == 0).toList();
    if (exact.isEmpty) return facts;

    if (clause is First) {
      final committed = exact.map((f) => f.branch).reduce(math.min);
      return facts.where((f) => f.cost != 0 || f.branch == committed).toList();
    }
    if (clause is Optional) {
      final bodySucceeded = exact.any((f) => f.branch == 0);
      if (bodySucceeded) return facts.where((f) => f.branch == 0).toList();
    }

    // At cost zero every PEG clause is deterministic.  Memo growth may retain
    // earlier left-recursion seeds, so expose only the longest exact fixed point
    // while retaining nonzero alternatives for the enclosing recovery choice.
    var chosen = exact.first;
    for (final fact in exact.skip(1)) {
      if (fact.end > chosen.end ||
          fact.end == chosen.end && _better(fact, chosen)) {
        chosen = fact;
      }
    }
    facts = [chosen, ...facts.where((f) => f.cost != 0)];
    return facts;
  }

  _Fact? _pureFact(Clause clause, int pos) {
    final result = match(clause, pos);
    if (result.isMismatch) return null;
    final evidence = <int>{};
    final shapes = <_Shape>{};
    void collect(MatchResult node) {
      final c = node.clause;
      if (c is Terminal && node.len > 0) {
        for (var i = node.pos; i < node.pos + node.len; i++) {
          evidence.add(i);
        }
      } else if (c is Ref && !transparentRules.contains(c.ruleName)) {
        shapes.add((c.ruleName, node.pos, node.pos + node.len));
      }
      node.subClauseMatches.forEach(collect);
    }

    collect(result);
    return _Fact(
      end: pos + result.len,
      cost: 0,
      nodes: [result],
      evidence: evidence,
      shapes: shapes,
      missing: const [],
      skipped: 0,
      firstEvidence: evidence.isEmpty ? 0x3fffffff : evidence.reduce(math.min),
    );
  }

  _Fact _empty(int pos) => _Fact(
        end: pos,
        cost: 0,
        nodes: const [],
        evidence: const {},
        shapes: const {},
        missing: const [],
        skipped: 0,
      );

  _Fact _join(_Fact a, _Fact b) => _Fact(
        end: b.end,
        cost: a.cost + b.cost,
        nodes: _concatNodes(a.nodes, b.nodes),
        evidence: {...a.evidence, ...b.evidence},
        shapes: {...a.shapes, ...b.shapes},
        missing: [...a.missing, ...b.missing],
        skipped: a.skipped + b.skipped,
        firstEvidence: math.min(a.firstEvidence, b.firstEvidence),
        firstAmbiguous: math.min(a.firstAmbiguous, b.firstAmbiguous),
      );

  _Fact _withNode(_Fact fact, MatchResult node, {int branch = -1}) => _Fact(
        end: fact.end,
        cost: fact.cost,
        nodes: [node],
        evidence: fact.evidence,
        shapes: fact.shapes,
        missing: fact.missing,
        skipped: fact.skipped,
        branch: branch,
        firstEvidence: fact.firstEvidence,
        firstAmbiguous: fact.firstAmbiguous,
      );

  List<MatchResult> _concatNodes(
      List<MatchResult> left, List<MatchResult> right) {
    if (left.isEmpty) return List.of(right);
    if (right.isEmpty) return List.of(left);
    final out = List<MatchResult>.of(left);
    final a = out.last;
    final b = right.first;
    if (a is SyntaxError &&
        b is SyntaxError &&
        a.len > 0 &&
        b.len > 0 &&
        a.pos + a.len == b.pos) {
      out[out.length - 1] = SyntaxError(pos: a.pos, len: a.len + b.len);
      out.addAll(right.skip(1));
    } else {
      out.addAll(right);
    }
    return out;
  }

  MatchResult _asNode(
      Clause clause, int pos, int end, List<MatchResult> children) {
    if (children.length == 1 && identical(children.first.clause, clause)) {
      return children.first;
    }
    if (children.isEmpty) return Match(clause, pos, end - pos);
    // A repaired Terminal must not hide its SyntaxError children behind the
    // AST builder's terminal-leaf rule.
    return Match(clause is Terminal ? null : clause, pos, end - pos,
        subClauseMatches: children);
  }

  List<_Fact> _raw(Clause clause, int pos) {
    if (clause is _Goal) return _rawGoal(clause, pos);
    if (clause is _End) return _rawEnd(pos);
    if (clause is Str) return _rawLiteral(clause, pos);
    if (clause is Terminal) return _rawTerminal(clause, pos);
    if (clause is Seq) return _rawSeq(clause, pos);
    if (clause is First) return _rawFirst(clause, pos);
    if (clause is Ref) return _rawRef(clause, pos);
    if (clause is Optional) return _rawOptional(clause, pos);
    if (clause is Repetition) return _rawRepetition(clause, pos);
    if (clause is FollowedBy) {
      return _strict(clause.subClause, pos) == null
          ? const []
          : [_withNode(_empty(pos), Match(clause, pos, 0))];
    }
    if (clause is NotFollowedBy) {
      return _strict(clause.subClause, pos) != null
          ? const []
          : [_withNode(_empty(pos), Match(clause, pos, 0))];
    }
    throw UnsupportedError('clause ${clause.runtimeType}');
  }

  List<_Fact> _rawGoal(_Goal goal, int pos) {
    final out = <_Fact>[];
    for (final body in _demand(goal.body, pos)) {
      // A damaged top-level AST must have at least one exact input code unit.
      if (body.cost > 0 && body.evidence.isEmpty) continue;
      for (final end
          in _demand(goal.end, body.end, budget: _budget - body.cost)) {
        final joined = _join(body, end);
        if (joined.cost <= _budget) out.add(joined);
      }
    }
    return _prune(out);
  }

  List<_Fact> _rawEnd(int pos) {
    if (pos == input.length) return [_empty(pos)];
    final n = input.length - pos;
    if (_budget < 1) return const [];
    return [
      _Fact(
        end: input.length,
        cost: 1,
        nodes: [SyntaxError(pos: pos, len: n)],
        evidence: const {},
        shapes: const {},
        missing: const [],
        skipped: n,
      )
    ];
  }

  List<_Fact> _rawTerminal(Terminal terminal, int pos) {
    if (terminal is Nothing) {
      return [_withNode(_empty(pos), Match(terminal, pos, 0))];
    }
    return _singleOptions(terminal, pos);
  }

  List<_Fact> _rawLiteral(Str literal, int pos) {
    if (literal.text.isEmpty) {
      return [_withNode(_empty(pos), Match(literal, pos, 0))];
    }
    if (pos + literal.text.length <= input.length &&
        input.startsWith(literal.text, pos)) {
      return [
        _Fact(
          end: pos + literal.text.length,
          cost: 0,
          nodes: [Match(literal, pos, literal.text.length)],
          evidence: {for (var i = pos; i < pos + literal.text.length; i++) i},
          shapes: const {},
          missing: const [],
          skipped: 0,
          firstEvidence: pos,
        )
      ];
    }

    final parts = _literalParts.putIfAbsent(
        literal, () => [for (final c in literal.text.split('')) Char(c)]);
    var states = [_empty(pos)];
    for (final part in parts) {
      final next = <_Fact>[];
      for (final state in states) {
        for (final piece in _singleOptions(part, state.end,
            budget: _budget - state.cost, repairEvenOnExact: true)) {
          final joined = _join(state, piece);
          if (joined.cost <= _budget) next.add(joined);
        }
      }
      states = _prune(next);
      if (states.isEmpty) break;
    }
    return states;
  }

  List<_Fact> _singleOptions(Terminal terminal, int pos,
      {int? budget, bool repairEvenOnExact = false}) {
    final allowed = budget ?? _budget;
    final out = <_Fact>[];
    final singleton = _singleton(terminal);
    final maxDrop = allowed == 0 || !_allowSpans
        ? 0
        : math.min(_spanLimit, input.length - pos);
    for (var drop = 0; drop <= maxDrop; drop++) {
      final at = pos + drop;
      final exact = _terminalHas(terminal, at);
      if (exact) {
        final errorCost = drop == 0 ? 0 : 1;
        final nodes = <MatchResult>[
          if (drop > 0) SyntaxError(pos: pos, len: drop),
          Match(terminal, at, 1),
        ];
        out.add(_Fact(
          end: at + 1,
          cost: errorCost,
          nodes: nodes,
          evidence: {at},
          shapes: const {},
          missing: const [],
          skipped: drop,
          firstEvidence: at,
        ));
        if (drop == 0 && !repairEvenOnExact) break;
      }

      // A non-empty error node occupies this expected slot without asserting
      // that the actual character belonged to the terminal's class.
      if (drop == 0 && !exact && at < input.length && allowed >= 1) {
        out.add(_Fact(
          end: at + 1,
          cost: 1,
          nodes: [SyntaxError(pos: pos, len: drop + 1)],
          evidence: const {},
          shapes: const {},
          missing: [MissingObligation(terminal, at)],
          skipped: drop + 1,
          firstAmbiguous: singleton == null ? at : 0x3fffffff,
        ));
      }

      // With no actual span, the expected symbol itself must carry zero new
      // information.  Cardinality one is the first half of that proof; Ref and
      // the goal enforce the independent-evidence half.
      final missingCost = 1 + (drop > 0 ? 1 : 0);
      if (singleton != null &&
          (drop == 0 || at == input.length) &&
          missingCost <= allowed) {
        out.add(_Fact(
          end: at,
          cost: missingCost,
          nodes: [
            if (drop > 0) SyntaxError(pos: pos, len: drop),
            SyntaxError(pos: at, len: 0),
          ],
          evidence: const {},
          shapes: const {},
          missing: [MissingObligation(terminal, at)],
          skipped: drop,
        ));
      }
    }
    return _prune(out);
  }

  bool _terminalHas(Terminal terminal, int pos) {
    if (pos >= input.length) return false;
    final x = input.codeUnitAt(pos);
    if (terminal is Char) return x == terminal.char.codeUnitAt(0);
    if (terminal is CharSet) {
      final inside = terminal.ranges.any((r) => x >= r.$1 && x <= r.$2);
      return terminal.inverted ? !inside : inside;
    }
    if (terminal is AnyChar) return true;
    if (terminal is Str && terminal.text.length == 1) {
      return x == terminal.text.codeUnitAt(0);
    }
    return false;
  }

  int? _singleton(Terminal terminal) {
    if (_singletons.containsKey(terminal)) return _singletons[terminal];
    return _singletons[terminal] = _computeSingleton(terminal);
  }

  int? _computeSingleton(Terminal terminal) {
    if (terminal is Char) return terminal.char.codeUnitAt(0);
    if (terminal is Str && terminal.text.length == 1) {
      return terminal.text.codeUnitAt(0);
    }
    if (terminal is! CharSet) return null;

    final ranges = <(int, int)>[];
    for (final raw in [...terminal.ranges]..sort((a, b) => a.$1 - b.$1)) {
      final lo = math.max(0, raw.$1);
      final hi = math.min(0xffff, raw.$2);
      if (lo > hi) continue;
      if (ranges.isNotEmpty && lo <= ranges.last.$2 + 1) {
        if (hi > ranges.last.$2) {
          ranges[ranges.length - 1] = (ranges.last.$1, hi);
        }
      } else {
        ranges.add((lo, hi));
      }
    }
    final covered = ranges.fold<int>(0, (n, r) => n + r.$2 - r.$1 + 1);
    final accepted = terminal.inverted ? 0x10000 - covered : covered;
    if (accepted != 1) return null;
    if (!terminal.inverted) return ranges.first.$1;
    var cursor = 0;
    for (final range in ranges) {
      if (cursor < range.$1) return cursor;
      cursor = range.$2 + 1;
    }
    return cursor <= 0xffff ? cursor : null;
  }

  List<_Fact> _rawSeq(Seq seq, int pos) {
    var states = [_empty(pos)];
    for (final child in seq.subClauses) {
      final next = <_Fact>[];
      for (final state in states) {
        for (final part
            in _demand(child, state.end, budget: _budget - state.cost)) {
          final joined = _join(state, part);
          if (joined.cost <= _budget) next.add(joined);
        }
      }
      states = _prune(next);
      if (states.isEmpty) return const [];
    }
    return _prune(states.map((state) =>
        _withNode(state, _asNode(seq, pos, state.end, state.nodes))));
  }

  List<_Fact> _rawFirst(First first, int pos) {
    final byAlt = <List<_Fact>>[];
    int? committed;
    for (var i = 0; i < first.subClauses.length; i++) {
      final facts = _demand(first.subClauses[i], pos);
      byAlt.add(facts);
      if (committed == null && facts.any((f) => f.cost == 0)) committed = i;
    }
    final out = <_Fact>[];
    for (final i in Iterable<int>.generate(byAlt.length)) {
      final alt = first.subClauses[i];
      for (final fact in byAlt[i]) {
        // Only zero-cost facts commit.  Under damage, a repaired earlier or
        // later branch may recover more grounded AST than the clean prefix.
        // At budget zero this is byte-for-byte ordinary ordered choice.
        if (fact.cost == 0 && committed != null && i != committed) continue;
        final child = _asNode(alt, pos, fact.end, fact.nodes);
        final node =
            Match(first, pos, fact.end - pos, subClauseMatches: [child]);
        out.add(_withNode(fact, node, branch: i));
      }
    }
    return _prune(out);
  }

  List<_Fact> _rawRef(Ref ref, int pos) {
    final body = rules[ref.ruleName];
    if (body == null) throw ArgumentError('Rule "${ref.ruleName}" not found');
    final transparent = transparentRules.contains(ref.ruleName);
    final out = <_Fact>[];
    for (final fact in _demand(body, pos)) {
      if (!transparent && fact.cost > 0 && fact.evidence.isEmpty) continue;
      if (!transparent && fact.firstAmbiguous < fact.firstEvidence) continue;
      final bodyNode = _asNode(body, pos, fact.end, fact.nodes);
      final refNode =
          Match(ref, pos, fact.end - pos, subClauseMatches: [bodyNode]);
      final shapes = <_Shape>{...fact.shapes};
      if (!transparent && (fact.cost == 0 || fact.evidence.isNotEmpty)) {
        shapes.add((ref.ruleName, pos, fact.end));
      }
      out.add(_Fact(
        end: fact.end,
        cost: fact.cost,
        nodes: [refNode],
        evidence: fact.evidence,
        shapes: shapes,
        missing: fact.missing,
        skipped: fact.skipped,
        firstEvidence: fact.firstEvidence,
      ));
    }
    return _prune(out);
  }

  List<_Fact> _rawOptional(Optional optional, int pos) {
    final body = _demand(optional.subClause, pos);
    final exactBody = body.any((f) => f.cost == 0);
    final out = <_Fact>[];
    if (!exactBody) {
      out.add(_withNode(_empty(pos), Match(optional, pos, 0), branch: 1));
    }
    for (final fact in body) {
      final child = _asNode(optional.subClause, pos, fact.end, fact.nodes);
      final node =
          Match(optional, pos, fact.end - pos, subClauseMatches: [child]);
      out.add(_withNode(fact, node, branch: 0));
    }
    return _prune(out);
  }

  List<_Fact> _rawRepetition(Repetition repetition, int pos) {
    final queue = <_RepState>[_RepState(_empty(pos), 0)];
    final reached = <(int, int), _Fact>{(pos, 0): queue.first.fact};
    final finished = <_Fact>[];
    var cursor = 0;
    while (cursor < queue.length) {
      final state = queue[cursor++];
      final bodies = _demand(repetition.subClause, state.fact.end,
              budget: _budget - state.fact.cost)
          .where((f) => f.end > state.fact.end)
          .toList();
      final exact = bodies.where((f) => f.cost == 0).toList();
      if (exact.isEmpty) {
        if (!repetition.requireOne || state.count > 0) {
          finished.add(state.fact);
        }
        for (final body in bodies.where((f) => f.cost > 0)) {
          // A repaired iteration must be grounded by a real terminal and move
          // over original input.  Missing-only loops can never manufacture AST.
          if (body.evidence.isEmpty) continue;
          _enqueueRep(repetition, state, body, queue, reached);
        }
      } else {
        var chosen = exact.first;
        for (final fact in exact.skip(1)) {
          if (fact.end > chosen.end ||
              fact.end == chosen.end && _better(fact, chosen)) {
            chosen = fact;
          }
        }
        _enqueueRep(repetition, state, chosen, queue, reached);
      }
    }

    return _prune(finished.map((fact) =>
        _withNode(fact, _asNode(repetition, pos, fact.end, fact.nodes))));
  }

  void _enqueueRep(Repetition repetition, _RepState state, _Fact body,
      List<_RepState> queue, Map<(int, int), _Fact> reached) {
    final item =
        _asNode(repetition.subClause, state.fact.end, body.end, body.nodes);
    final bodyAsItem = _withNode(body, item);
    final joined = _join(state.fact, bodyAsItem);
    if (joined.cost > _budget) return;
    final key = (joined.end, joined.cost);
    final old = reached[key];
    if (old == null || _better(joined, old)) {
      reached[key] = joined;
      queue.add(_RepState(joined, state.count + 1));
    }
  }

  _Fact? _strict(Clause clause, int pos) {
    final exact =
        _demand(clause, pos, budget: 0).where((f) => f.cost == 0).toList();
    if (exact.isEmpty) return null;
    var chosen = exact.first;
    for (final fact in exact.skip(1)) {
      if (fact.end > chosen.end ||
          fact.end == chosen.end && _better(fact, chosen)) {
        chosen = fact;
      }
    }
    return chosen;
  }

  int _countClauses(Clause root) {
    final seen = Set<Clause>.identity();
    final seenRules = <String>{};
    void visit(Clause clause) {
      if (!seen.add(clause)) return;
      if (clause is Ref) {
        if (seenRules.add(clause.ruleName)) {
          final body = rules[clause.ruleName];
          if (body != null) visit(body);
        }
      } else if (clause is HasOneSubClause) {
        visit(clause.subClause);
      } else if (clause is HasMultipleSubClauses) {
        clause.subClauses.forEach(visit);
      }
    }

    visit(root);
    return seen.length;
  }

  _Fact? _bestComplete(List<_Fact> facts) {
    _Fact? best;
    for (final fact in facts) {
      if (fact.end != input.length || fact.cost > _budget) continue;
      if (best == null ||
          fact.cost < best.cost ||
          fact.cost == best.cost && _better(fact, best)) {
        best = fact;
      }
    }
    return best;
  }

  /// Build one full-coverage tree over [input].  This method never invokes
  /// Parser.parse and never creates another Parser.
  SkipResult recover() {
    if (_ran) throw StateError('AstFirstParser performs exactly one parse');
    _ran = true;

    // Every rejected code unit costs at most n.  Between two grounded input
    // positions an acyclic grammar path contains at most C clauses; a recovered
    // repetition must consume grounded evidence.  n + (n+1)C is therefore a
    // constructive finite bound, not a tuned cut-off.
    final maxBudget = input.length + (input.length + 1) * _clauseCount;
    _Fact? answer;
    // First settle the smallest nonzero layer with localized error nodes only.
    // A complete cost-one proof is globally minimal; most damage never needs a
    // synchronization scan at all.
    for (_budget = 0; _budget <= math.min(1, maxBudget); _budget++) {
      answer = _bestComplete(_demand(_goal, 0, budget: _budget));
      if (answer != null) break;
    }
    if (answer?.cost != 0) {
      final localized = answer;
      _allowSpans = true;
      _spanLimit = localized?.skipped ?? input.length;
      // The same entries are retained.  A generation bump makes the localized
      // facts lower bounds for a wider recomputation, exactly as LR widening
      // invalidates dependent facts without deleting them.
      for (var pos = 0; pos < memoVersion.length; pos++) {
        memoVersion[pos]++;
      }
      answer = null;
      for (_budget = 1; _budget <= maxBudget; _budget++) {
        answer = _bestComplete(_demand(_goal, 0, budget: _budget));
        if (answer != null) break;
      }
    }
    lastCells = _touched.length;
    lastBudget = _budget;

    if (answer == null) {
      lastCost = -1;
      final error = SyntaxError(pos: 0, len: input.length);
      return SkipResult(error, [error], const [], 1, true);
    }

    lastCost = answer.cost;
    final root = answer.nodes.length == 1 &&
            answer.nodes.first.pos == 0 &&
            answer.nodes.first.len == input.length
        ? answer.nodes.first
        : Match(null, 0, input.length, subClauseMatches: answer.nodes);
    final spans = <SyntaxError>[];
    void collect(MatchResult node) {
      if (node is SyntaxError && node.len > 0) spans.add(node);
      for (final child in node.subClauseMatches) {
        collect(child);
      }
    }

    collect(root);
    return SkipResult(root, spans, answer.missing, answer.cost, false);
  }
}

// ---------------------------------------------------------------------------
// Executable verification harness.

const _jsonGrammar = r'''
JSON <- WS Value WS;
Value <- Object / Array / String / Number / Boolean / Null;
Object <- '{' WS (Member (WS ',' WS Member)*)? WS '}';
Member <- String WS ':' WS Value;
Array <- '[' WS (Value (WS ',' WS Value)*)? WS ']';
String <- '"' Character* '"';
Character <- [^"\\] / ('\\' Escape);
Escape <- '"' / '\\' / '/' / 'b' / 'f' / 'n' / 'r' / 't' / ('u' [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F]);
Number <- Integer Fraction? Exponent?;
Integer <- '-'? (([1-9] [0-9]+) / [0-9]);
Fraction <- '.' [0-9]+;
Exponent <- ("e" / "E") ("+" / "-")? [0-9]+;
Boolean <- "true" / "false";
Null <- "null";
~WS <- [ \t\n\r]*;

Tail <- ',' Value (',' Value)*;
ArrayPrefix <- '[' Value (',' Value)* ','?;
''';

const _structural = <String>{
  'Object',
  'Array',
  'Member',
  'String',
  'Number',
  'Boolean',
  'Null',
  'Value',
};

String _treeShape(MatchResult root) {
  final out = StringBuffer();
  void walk(MatchResult node) {
    final clause = node.clause;
    if (clause is Ref && _structural.contains(clause.ruleName)) {
      out.write('${clause.ruleName}(');
      node.subClauseMatches.forEach(walk);
      out.write(')');
    } else {
      node.subClauseMatches.forEach(walk);
    }
  }

  walk(root);
  return out.toString();
}

bool _covers(MatchResult root, int length) {
  var cursor = 0;
  var okay = true;
  void walk(MatchResult node) {
    if (!okay) return;
    if (node is SyntaxError || node.subClauseMatches.isEmpty) {
      if (node.len == 0) return;
      if (node.pos != cursor) okay = false;
      cursor = node.pos + node.len;
      return;
    }
    node.subClauseMatches.forEach(walk);
  }

  walk(root);
  return okay && cursor == length;
}

String _errors(SkipResult result, String input) => [
      for (final span in result.errorSpans)
        'unexpected "${input.substring(span.pos, span.pos + span.len)}"@${span.pos}',
      for (final hole in result.missing) 'missing ${hole.clause}@${hole.pos}',
    ].join(', ');

SkipResult _runOne(Map<String, Clause> rules, String top, String input) {
  final parser = AstFirstParser(rules: rules, topRuleName: top, input: input);
  final result = parser.recover();
  print('$top "$input" -> cost=${parser.lastCost}, '
      'budget=${parser.lastBudget}, cells=${parser.lastCells}');
  print('  ${_errors(result, input)}');
  return result;
}

List<String> _battery(Map<String, Clause> rules) {
  const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';
  bool clean(String input) {
    final parsed =
        Parser(rules: rules, topRuleName: 'JSON', input: input).parse();
    return !parsed.hasSyntaxErrors && parsed.root.len == input.length;
  }

  final mutants = <String>[];
  for (var i = 0; i < base.length; i++) {
    mutants.add(base.substring(0, i) + base.substring(i + 1));
    if (i + 1 < base.length && base[i] != base[i + 1]) {
      mutants.add(
          base.substring(0, i) + base[i + 1] + base[i] + base.substring(i + 2));
    }
  }
  for (var i = 0; i <= base.length; i++) {
    for (final char in ['Q', 'z', '}', '"', ',', '5']) {
      mutants.add(base.substring(0, i) + char + base.substring(i));
      if (i < base.length && base[i] != char) {
        mutants.add(base.substring(0, i) + char + base.substring(i + 1));
      }
    }
  }
  return mutants.where((input) => !clean(input)).toList();
}

List<String> _latencyCases() {
  const big = '{"users":[{"id":1,"name":"ann","tags":["x","y"]},'
      '{"id":2,"name":"bob","tags":["z"]},{"id":3,"name":"cyd","tags":[]}],'
      '"total":3,"ok":true}';
  final out = <String>[];
  for (final k in [4, 16, 64]) {
    out.add(big.substring(0, 30) + big.substring(30 + k));
    out.add(big.substring(0, 30) + ('@' * k) + big.substring(30));
    final chars = big.substring(30, 30 + k).split('')
      ..shuffle(math.Random(12345 + k));
    out.add(big.substring(0, 30) + chars.join() + big.substring(30 + k));
  }
  for (final k in [4, 16, 64]) {
    final items = [
      for (var i = 0; i < k; i++) '{"id":$i,"name":"n$i","ok":true}'
    ];
    final doc = '{"items":[${items.join(',')}],"total":$k}';
    final middle = doc.length ~/ 2;
    out.add('${doc.substring(0, middle)}Q${doc.substring(middle + 1)}');
  }
  return out;
}

void main(List<String> args) {
  final rules = MetaGrammar.parseGrammar(_jsonGrammar);

  final tail = _runOne(rules, 'Tail', ',3true');
  final tailOkay = tail.errorSpans.isEmpty &&
      tail.missing.any((m) => m.pos == 2 && m.clause.toString().contains(','));
  if (!tailOkay) throw StateError(',3true did not insert its forced comma');

  final prefix = _runOne(rules, 'ArrayPrefix', '[,2,');
  final prefixOkay = prefix.errorSpans.any((e) => e.pos == 1 && e.len == 1) &&
      !prefix.missing.any((m) => m.pos == 1);
  if (!prefixOkay) throw StateError('[,2, did not reject its leading comma');
  print('hard cases: 2/2');

  const embeddedBase = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';
  final commaDoc = embeddedBase.substring(0, 16) +
      embeddedBase[17] +
      embeddedBase[16] +
      embeddedBase.substring(18);
  final commaParser =
      AstFirstParser(rules: rules, topRuleName: 'JSON', input: commaDoc);
  final commaResult = commaParser.recover();
  final leadingDoc = embeddedBase.substring(0, 13) + embeddedBase.substring(14);
  final leadingParser =
      AstFirstParser(rules: rules, topRuleName: 'JSON', input: leadingDoc);
  final leadingResult = leadingParser.recover();
  final embeddedOkay = commaParser.lastCost == 1 &&
      commaResult.missing
          .any((m) => m.pos == 18 && m.clause.toString().contains(',')) &&
      leadingParser.lastCost == 1 &&
      leadingResult.errorSpans.any((e) => e.pos == 13 && e.len == 1);
  print('embedded hard JSON: ${embeddedOkay ? '2/2' : 'FAILED'}');
  if (!embeddedOkay) throw StateError('embedded hard JSON regression');

  final lrRules = MetaGrammar.parseGrammar(
      "E <- E '+' T / T;\nT <- T '*' F / F;\nF <- [0-9];\n");
  final lrParser =
      AstFirstParser(rules: lrRules, topRuleName: 'E', input: '1++2');
  final lrResult = lrParser.recover();
  final lrOkay = lrParser.lastCost == 1 && _covers(lrResult.root, 4);
  print('left-recursion recovery: ${lrOkay ? 'ok' : 'FAILED'}');
  if (!lrOkay) throw StateError('left-recursion fixed point regression');

  final pegRules = MetaGrammar.parseGrammar("S <- ('a' / 'a' 'b') 'c';\n");
  final pegParser =
      AstFirstParser(rules: pegRules, topRuleName: 'S', input: 'abc');
  pegParser.recover();
  final emptyLookRules = MetaGrammar.parseGrammar("S <- &'x' 'y';\n");
  final emptyLookParser =
      AstFirstParser(rules: emptyLookRules, topRuleName: 'S', input: 'y');
  emptyLookParser.recover();
  final regularLookRules =
      MetaGrammar.parseGrammar("S <- &('a' 'b'*) 'a' 'b'*;\n");
  final regularLookParser =
      AstFirstParser(rules: regularLookRules, topRuleName: 'S', input: 'abbb');
  regularLookParser.recover();
  final predicateOkay = pegParser.lastCost > 0 &&
      emptyLookParser.lastCost == -1 &&
      regularLookParser.lastCost == 0;
  print('PEG choice/predicate checks: ${predicateOkay ? 'ok' : 'FAILED'} '
      '(choice=${pegParser.lastCost}, emptyLook=${emptyLookParser.lastCost}, '
      'regularLook=${regularLookParser.lastCost})');
  if (!predicateOkay) throw StateError('PEG/predicate regression');

  const valid = <String>[
    embeddedBase,
    '[]',
    '{}',
    '  [1, 2, [3, {"x": -4.5e+6}], false, null]  ',
    '{"s":"a\\u00ffb\\n\\t","n":-0.5,"deep":{"a":{"b":{"c":[[[1]]]}}}}',
    '"just a string"',
    '0',
  ];
  var validOkay = 0;
  for (final input in valid) {
    final parser =
        AstFirstParser(rules: rules, topRuleName: 'JSON', input: input);
    final result = parser.recover();
    if (parser.lastCost == 0 &&
        result.clean &&
        _covers(result.root, input.length)) {
      validOkay++;
    }
  }
  print('final_table valid JSON: $validOkay/${valid.length}');
  if (validOkay != valid.length) throw StateError('valid JSON regression');

  if (args.contains('--latency')) {
    final cases = _latencyCases();
    for (final input in cases) {
      AstFirstParser(rules: rules, topRuleName: 'JSON', input: input).recover();
    }
    var totalUs = 0;
    for (final (index, input) in cases.indexed) {
      var best = 1 << 62;
      var cost = -1;
      for (var repeat = 0; repeat < 5; repeat++) {
        final watch = Stopwatch()..start();
        final parser =
            AstFirstParser(rules: rules, topRuleName: 'JSON', input: input);
        parser.recover();
        cost = parser.lastCost;
        watch.stop();
        best = math.min(best, watch.elapsedMicroseconds);
      }
      totalUs += best;
      if (args.contains('--progress')) {
        print('latency[$index] len=${input.length} cost=$cost '
            'bestMs=${(best / 1000).toStringAsFixed(1)}');
      }
    }
    print('final_table latency: cases=${cases.length}, min5sumMs='
        '${(totalUs / 1000).toStringAsFixed(1)}');
  }

  if (!args.contains('--full')) return;
  final base = valid[0];
  final pure = Parser(rules: rules, topRuleName: 'JSON', input: base).parse();
  final wantedShape = _treeShape(pure.root);
  final battery = _battery(rules);
  var limit = battery.length;
  for (final arg in args) {
    if (arg.startsWith('--limit=')) {
      limit = math.min(limit, int.parse(arg.substring(8)));
    }
  }
  var covered = 0, shaped = 0, recovered = 0;
  final watch = Stopwatch()..start();
  for (final (index, input) in battery.take(limit).indexed) {
    if (args.contains('--progress')) print('battery[$index] $input');
    final parser =
        AstFirstParser(rules: rules, topRuleName: 'JSON', input: input);
    final result = parser.recover();
    if (args.contains('--progress')) {
      print('  -> cost=${parser.lastCost} budget=${parser.lastBudget} '
          'cells=${parser.lastCells}');
    }
    if (parser.lastCost >= 0) recovered++;
    if (_covers(result.root, input.length)) covered++;
    if (_treeShape(result.root) == wantedShape) shaped++;
  }
  watch.stop();
  print(
      'final_table battery: n=$limit/${battery.length}, recovered=$recovered, '
      'cover=$covered, originalShape=$shaped, ms=${watch.elapsedMilliseconds}');
}
