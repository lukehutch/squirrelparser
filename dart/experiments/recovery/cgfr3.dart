// cgfr3.dart -- IN-TABLE COMMUNICATION ERROR RECOVERY (CGFR-3)
//
// Standalone, self-contained single-file error recovery engine using the
// "In-Table Communication Principle". It extends the pure Packrat memo table
// to search for the minimum-cost edit path directly on the AST, taking
// full advantage of O(1) memoized pure parse results.

import 'dart:math' as math;
import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/recovery/skip_recovery.dart'
    show SkipResult, MissingObligation;

abstract class Edit {
  int get cost;
  MatchResult? apply(Cgfr3Parser parser, Clause clause, int pos);
}

class InsertEdit extends Edit {
  @override
  int get cost => 1;
  @override
  MatchResult? apply(Cgfr3Parser parser, Clause clause, int pos) {
    return Match(clause, pos, 0);
  }
}

class SubstituteEdit extends Edit {
  @override
  int get cost => 1;
  @override
  MatchResult? apply(Cgfr3Parser parser, Clause clause, int pos) {
    if (pos >= parser.input.length) return null;
    return Match(clause, pos, 1);
  }
}

class DeleteEdit extends Edit {
  @override
  int get cost => 1;
  @override
  MatchResult? apply(Cgfr3Parser parser, Clause clause, int pos) {
    if (pos >= parser.input.length) return null;
    final m = parser.match(clause, pos + 1);
    if (m.isMismatch) return null;
    return Match(
        clause,
        pos,
        1 + m.len,
        subClauseMatches: [SyntaxError(pos: pos, len: 1), m]);
  }
}

class _Eof extends Terminal {
  const _Eof();
  @override
  MatchResult match(Parser parser, int pos) {
    if (parser is Cgfr3Parser && parser.isRecovery) {
      if (false) {}
    }
    if (pos == parser.input.length) return Match(this, pos, 0);
    return mismatch;
  }
}

class _Failure {
  final Clause clause;
  final int pos;
  _Failure(this.clause, this.pos);
  @override
  int get hashCode => clause.hashCode ^ pos.hashCode;
  @override
  bool operator ==(Object other) => other is _Failure && clause == other.clause && pos == other.pos;
}

class _Track extends Clause {
  final Clause sub;
  const _Track(this.sub);
  @override
  MatchResult match(Parser parser, int pos) {
    if ((parser as Cgfr3Parser).isRecovery) {
      if (false) {}
    }
    final res = parser.match(sub, pos);
    if (parser.isRecovery) {
      if (false) {}
    }
    return res;
  }
  @override
  void checkRuleRefs(Map<String, Clause> grammarMap) {}
}

Clause _wrapClause(Clause c) {
  if (c is Terminal) return _Track(c);
  if (c is Seq) return Seq(c.subClauses.map(_wrapClause).toList());
  if (c is First) return First(c.subClauses.map(_wrapClause).toList());
  if (c is Repetition) {
    if (c is OneOrMore) return OneOrMore(_wrapClause(c.subClause));
    if (c is ZeroOrMore) return ZeroOrMore(_wrapClause(c.subClause));
  }
  if (c is Optional) return Optional(_wrapClause(c.subClause));
  if (c is NotFollowedBy) return NotFollowedBy(_wrapClause(c.subClause));
  if (c is FollowedBy) return FollowedBy(_wrapClause(c.subClause));
  return c;
}

class RecoveryState implements Comparable<RecoveryState> {
  final Map<Clause, Map<int, Edit>> edits;
  final int cost;
  final int maxPosReached;

  RecoveryState(this.edits, this.cost, this.maxPosReached);

  RecoveryState addEdit(Clause clause, int pos, Edit edit) {
    final newEdits = <Clause, Map<int, Edit>>{};
    for (final e in edits.entries) {
      newEdits[e.key] = Map.of(e.value);
    }
    newEdits.putIfAbsent(clause, () => {})[pos] = edit;
    return RecoveryState(newEdits, cost + edit.cost, maxPosReached);
  }

  @override
  int compareTo(RecoveryState other) {
    if (cost != other.cost) return cost.compareTo(other.cost);
    return other.maxPosReached.compareTo(maxPosReached);
  }
}

class Cgfr3MemoEntry {
  MatchResult? pureResult;
  int pureMemoVersion = 0;
  bool pureInRecPath = false;
  bool pureFoundLeftRec = false;
  int pureMaxPosTouched = -1;

  MatchResult? recResult;
  int recVersion = -1;
  int recMemoVersion = 0;
  bool recInRecPath = false;
  bool recFoundLeftRec = false;
}

class Cgfr3Parser extends Parser {
  late final Map<String, Clause> wrappedRules;
  final Map<Clause, Map<int, Cgfr3MemoEntry>> _cgfr3MemoTable = {};
  late final List<int> recMemoVersion;

  Cgfr3Parser({required super.rules, required super.topRuleName, required super.input}) {
    recMemoVersion = List.filled(input.length + 1, 0);
    wrappedRules = {};
    for (final entry in rules.entries) {
      wrappedRules[entry.key] = _wrapClause(entry.value);
    }
    for (final entry in wrappedRules.entries) {
      this.rules[entry.key] = entry.value;
    }
  }

  @override
  MatchResult matchRule(String ruleName, int pos) {
    final clause = wrappedRules[ruleName]!;
    if (false) {}
    return match(clause, pos);
  }


  
  // Recovery State
  bool isRecovery = false;
  int recVersion = 0;
  Map<Clause, Map<int, Edit>> currentEdits = {};

  // Frontier Tracking
  int maxFailPos = -1;
  Set<_Failure> frontiers = {};
  
  // Cache Invalidation Tracking
  int maxPosTouched = -1;

  @override
  MatchResult match(Clause clause, int pos) {
    if (isRecovery) {
      if (false) {}
    }
    if (pos > input.length) return mismatch;

    var entry = _cgfr3MemoTable.putIfAbsent(clause, () => {}).putIfAbsent(pos, Cgfr3MemoEntry.new);

    if (isRecovery) {
      // 1. Check for injected edits FIRST
      final edit = currentEdits[clause]?[pos];
      if (edit != null) {
        final res = edit.apply(this, clause, pos);
        if (res != null) return res;
      }

      // 2. Check pure cache
      if (entry.pureResult != null && !entry.pureResult!.isMismatch) {
        bool canReuse = true;
        for (final clauseEdits in currentEdits.values) {
          for (final editPos in clauseEdits.keys) {
            if (entry.pureMaxPosTouched >= editPos) {
              canReuse = false;
              break;
            }
          }
          if (!canReuse) break;
        }
        if (canReuse) {
          if (currentEdits.length == 1 && currentEdits.keys.first is CharSet && currentEdits.values.first.keys.first == 2 && currentEdits.values.first.values.first is InsertEdit) print("PURE CACHE HIT for $clause at $pos");
          return entry.pureResult!;
        } else {
          if (currentEdits.length == 1 && currentEdits.keys.first is CharSet && currentEdits.values.first.keys.first == 2 && currentEdits.values.first.values.first is InsertEdit) print("PURE CACHE SKIPPED for $clause at $pos (touched ${entry.pureMaxPosTouched})");
        }
      }

      // ...
      
      // 3. Check recovery cache
      if (entry.recVersion == recVersion && entry.recMemoVersion == recMemoVersion[pos] && !entry.recInRecPath) {
        return entry.recResult!;
      } else if (entry.recResult != null && entry.recInRecPath) {
        return entry.recResult!;
      } else if (entry.recInRecPath) {
        entry.recFoundLeftRec = true;
        entry.recResult = mismatch;
        return mismatch;
      }

      // Evaluate in recovery mode
      entry.recVersion = recVersion;
      entry.recMemoVersion = recMemoVersion[pos];
      entry.recInRecPath = true;
      entry.recFoundLeftRec = false;
      entry.recResult = null; // MUST CLEAR FROM PREVIOUS CANDIDATES
      do {
        final newResult = clause.match(this, pos);
        if (entry.recResult != null && newResult.len <= entry.recResult!.len) {
          break;
        }
        entry.recResult = newResult;
        if (!entry.recFoundLeftRec) break;
        // Invalidate cache for lower levels of left recursion at pos
        recMemoVersion[pos]++;
        entry.recMemoVersion = recMemoVersion[pos];
      } while (true);
      entry.recInRecPath = false;
      entry.recVersion = recVersion;
      entry.recMemoVersion = recMemoVersion[pos];
      
      if (currentEdits.length == 2 && 
          currentEdits.keys.any((k) => k is Char && k.char == '+') &&
          currentEdits.keys.any((k) => k is CharSet) &&
          currentEdits.values.any((v) => v.containsKey(1) && v[1] is DeleteEdit) &&
          currentEdits.values.any((v) => v.containsKey(3) && v[3] is DeleteEdit)) {
        if (pos == 0 && clause.toString() == "((T _Track F) / F)") {
           print("DEBUG WEIRD T at 0: len=${entry.recResult!.len}. Children = ${entry.recResult!.subClauseMatches.map((c) => '${c.clause.runtimeType}(${c.clause}) (pos=${c.pos}, len=${c.len}, mismatch=${c.isMismatch}) [${c.subClauseMatches.map((gc) => '${gc.clause.runtimeType}(${gc.clause}) (pos=${gc.pos}, len=${gc.len}, mismatch=${gc.isMismatch})').toList()}]').toList()}");
        }
      }
      
      // Track frontier
      if (entry.recResult!.isMismatch && clause is Terminal && clause is! Nothing) {
        if (pos > maxFailPos) {
          maxFailPos = pos;
          frontiers = {_Failure(clause, pos)};
          print("UPDATED maxFailPos to $pos with clause $clause");
        } else if (pos == maxFailPos) {
          frontiers.add(_Failure(clause, pos));
        }
      }
      
      if (false) {}
      return entry.recResult!;
    } else {
      // Pure parse logic
      if (entry.pureResult != null && (entry.pureInRecPath || entry.pureMemoVersion == memoVersion[pos])) {
        if (entry.pureMaxPosTouched > maxPosTouched) {
          maxPosTouched = entry.pureMaxPosTouched;
        }
        return entry.pureResult!;
      } else if (entry.pureInRecPath) {
        entry.pureFoundLeftRec = true;
        entry.pureResult = mismatch;
        return mismatch;
      }

      entry.pureInRecPath = true;
      int prevMax = maxPosTouched;
      maxPosTouched = pos;
      
      do {
        final newResult = clause.match(this, pos);
        if (entry.pureResult != null && newResult.len <= entry.pureResult!.len) {
          break;
        }
        entry.pureResult = newResult;
        if (!entry.pureFoundLeftRec) break;
        entry.pureMemoVersion = ++memoVersion[pos];
      } while (true);
      
      if (entry.pureResult!.isMismatch && clause is Terminal && clause is! Nothing) {
        if (pos > maxFailPos) {
          maxFailPos = pos;
          frontiers = {_Failure(clause, pos)};
        } else if (pos == maxFailPos) {
          frontiers.add(_Failure(clause, pos));
        }
      }
      
      entry.pureMaxPosTouched = maxPosTouched;
      if (clause.toString().contains("T") && pos == 0) {
        print("SETTING pureMaxPosTouched for $clause at 0 to ${maxPosTouched}");
      }
      if (prevMax > maxPosTouched) {
        maxPosTouched = prevMax;
      }
      
      entry.pureInRecPath = false;
      entry.pureMemoVersion = memoVersion[pos];
      return entry.pureResult!;
    }
  }

  SkipResult recover() {
    final eof = _Eof();
    final goal = Seq([Ref(topRuleName), _wrapClause(eof)]);
    final wrappedGoal = goal; // already wrapped by Ref and _wrapClause

    // 1. Run pure parse
    isRecovery = false;
    final pureRes = match(wrappedGoal, 0);
    if (!pureRes.isMismatch && pureRes.len == input.length) {
      return SkipResult(pureRes.subClauseMatches[0], const [], const [], 0, false);
    }

    // Initialize recovery
    isRecovery = true;
    final queue = <RecoveryState>[RecoveryState({}, 0, 0)];
    final seen = <String>{};

    int iterations = 0;
    while (queue.isNotEmpty && iterations < 1000) {
      iterations++;
      queue.sort();
      final state = queue.removeAt(0);

      // Apply state
      currentEdits = state.edits;
      MatchResult res;
      if (currentEdits.isEmpty) {
        res = pureRes;
      } else {
        recVersion++;
        maxFailPos = -1;
        frontiers.clear();
        res = match(wrappedGoal, 0);
        if (state.edits.length == 2 && 
            state.edits.keys.any((k) => k is Char && k.char == '+') &&
            state.edits.keys.any((k) => k is CharSet) &&
            state.edits.values.any((v) => v.containsKey(1) && v[1] is DeleteEdit) &&
            state.edits.values.any((v) => v.containsKey(3) && v[3] is DeleteEdit)) {
          print("DEBUG RESULT: res.len=${res.len}, res.isMismatch=${res.isMismatch}");
        }
      }
      
      if (state.edits.length == 2 && 
          state.edits.keys.any((k) => k is Char) &&
          state.edits.keys.any((k) => k is CharSet) &&
          state.edits.values.any((v) => v.containsKey(1) && v[1] is DeleteEdit) &&
          state.edits.values.any((v) => v.containsKey(3) && v[3] is DeleteEdit)) {
        print("DEBUG CANDIDATE: DeleteEdit('+', 1) + DeleteEdit([0-9], 3) returned len=${res.len}");
      }

      if (!res.isMismatch && res.len == input.length) {
        // Success! Extract errors
        final spans = <SyntaxError>[];
        final missing = <MissingObligation>[];
        void walk(MatchResult m) {
          if (m is SyntaxError) {
            spans.add(m);
            return;
          }
          if (m.subClauseMatches.isEmpty && m.len == 0 && m.clause is Terminal && m.clause is! Nothing && m.clause is! _Eof) {
            missing.add(MissingObligation(m.clause!, m.pos));
          }
          if (m.subClauseMatches != null) {
            for (var sub in m.subClauseMatches!) walk(sub);
          }
        }
        walk(res);
        print("FOUND SUCCESS! events: ${spans.length + missing.length} spans=$spans missing=$missing");
        print("state.edits = ${state.edits.map((c, m) => MapEntry(c.runtimeType, m))}");
        return SkipResult(res.subClauseMatches[0], spans, missing, state.cost, false);
      }

      // Expand frontier
      print("Frontier size: ${frontiers.length} at pos $maxFailPos, cost: ${state.cost} -> ${frontiers.map((f) => f.clause).toList()}");
      for (final f in frontiers) {
        // Prevent explosive loops
        final stateKey = "${f.clause.hashCode}:${f.pos}:${state.cost}";
        if (seen.contains(stateKey)) continue;
        seen.add(stateKey);

        queue.add(state.addEdit(f.clause, f.pos, InsertEdit()));
        queue.add(state.addEdit(f.clause, f.pos, SubstituteEdit()));
        queue.add(state.addEdit(f.clause, f.pos, DeleteEdit()));
      }
    }

    final err = SyntaxError(pos: 0, len: input.length);
    return SkipResult(err, [err], const [], 1, true);
  }
}
