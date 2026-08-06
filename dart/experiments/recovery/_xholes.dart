// Scratch: HOLES -- productions asserted where no part of them appeared.
//
// Codex's soundness counterexample against r8: `giveUp()` has no evidence gate,
// so repeated first-slot give-ups can cap a clause having matched nothing at
// all. On `S <- A B; A <- 'a' / 'b'; B <- 'c' / 'd'` with input "", r8 answers
// `Seq @0+0 (ERR @0+0, ERR @0+0)` -- an S with two missing parts and no input.
//
// A HOLE, defined so legitimately-empty matches are not counted: a node that is
// not itself a SyntaxError, spans zero characters, and has at least one
// SyntaxError in its subtree. `WS @0+0`, `ZeroOrMore @0+0` and `Optional @1+0`
// all span zero characters and hold no error, so none of them count.
//
//   dart run _holes.dart <engine> [<engine> ...]

import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import '_xscore.dart' show resolve;

bool _hasErr(MatchResult m) {
  if (m is SyntaxError) return true;
  for (final s in m.subClauseMatches) {
    if (_hasErr(s)) return true;
  }
  return false;
}

int _holes(MatchResult m) {
  var n = 0;
  if (m is! SyntaxError && m.len == 0 && _hasErr(m)) n++;
  for (final s in m.subClauseMatches) {
    n += _holes(s);
  }
  return n;
}

void main(List<String> argv) {
  // The counterexample grammar, verbatim.
  const g = "S <- A B; A <- 'a' / 'b'; B <- 'c' / 'd';";
  final cxRules = MetaGrammar.parseGrammar(g);

  final cases = weighted(buildBattery());
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final topOf = {for (final c in corpora) c.name: c.top};

  for (final name in argv) {
    final build = resolve(name);
    if (build == null) {
      print('$name UNKNOWN');
      continue;
    }
    // 1. The counterexample itself.
    final cx = build(cxRules, 'S');
    final parts = <String>[];
    for (final inp in ['', 'x', 'a', 'ac']) {
      try {
        final t = cx(inp);
        parts.add('"$inp"=${t == null ? 'null' : '${_holes(t)}h'}');
      } catch (e) {
        parts.add('"$inp"=threw');
      }
    }
    // 2. The battery.
    final made = <String, MatchResult? Function(String)>{
      for (final c in corpora) c.name: build(rulesOf[c.name]!, topOf[c.name]!)
    };
    var badCases = 0, badNodes = 0;
    for (final k in cases) {
      try {
        final t = made[k.grammar]!(k.mutant);
        if (t == null) continue;
        final h = _holes(t);
        if (h > 0) {
          badCases++;
          badNodes += h;
        }
      } catch (_) {}
    }
    print('${name.padRight(5)} battery ${badCases.toString().padLeft(4)}'
        '/${cases.length} cases with holes, '
        '${badNodes.toString().padLeft(4)} hole nodes   '
        'cx: ${parts.join("  ")}');
  }
}
