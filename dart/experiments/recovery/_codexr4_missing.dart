// _missing.dart -- does a repair assert a Seq production WITHOUT its required
// parts?
//
// The other controls ask what a repair does to the input: `_freespan` catches
// deleting characters that already matched, `_zerowidth` catches naming a node
// that covers none. Neither can see this one. A subclause that is simply ABSENT
// from a Seq match is not a zero-width node -- there is no node -- and it costs
// nothing, so the battery scores the tree as though the parser had found it.
// That makes it strictly cheaper than the honest reading and it wins on shape,
// because the expected skeleton has that node in it.
//
// It is inventing structure by deleting, and it is never legitimate: for a Seq
// to skip subclause i, i must have MISMATCHED at that position, and a clause
// that can derive the empty string never mismatches. So every skipped subclause
// is one the grammar requires and the input does not supply.
//
// Found in r1: `a*b+@*c` on the expr grammar came back as
// `Term <- Term WS MulOp WS Factor` holding only `[SyntaxError, MulOp, WS,
// Factor]` -- a multiplication with no left operand, reported at cost 1, where
// the honest deletion-only repair (drop `@*`) costs 2.
//
// Usage: dart run _missing.dart [engine ...]
import 'package:squirrel_parser/squirrel_parser.dart';

import '_codexr4_resolve.dart' show resolve;
import 'astdiff.dart';

/// Seq matches in [m] holding fewer children than the grammar asks for, split by
/// which kind they are: (holes, prefixes).
///
/// A PREFIX stopped early -- children 0..k are present and the rest of the
/// production was never reached. That is the pruning the brief asks for, but it
/// is only honest if something says so: an unmarked prefix reports a production
/// the input never finished and charges nothing for it, which is the same free
/// pass a hole gets. `Pair <- Key ':' Value` on `x:` came back from r1 as
/// `Seq [Key, Char]` at cost 0 -- no third child, and no mark where it should
/// have been. The count below is of SHAPE, so it cannot tell the two apart; read
/// it against `_zerowidth` and `_conf1`, which see whether the gap was named.
///
/// A HOLE skipped a middle element -- child i is a match of some LATER subclause
/// than i. The production claims to be complete while a required part of it was
/// never found in the input, and nothing in the tree says so.
///
/// `SyntaxError` children are skipped spans, not subclause matches, so they do
/// not count towards the requirement. A `Repaired` child carries no clause of
/// its own; it stands for whatever index it occupies, so it always aligns.
(int, int) shortSeqs(MatchResult m) {
  var holes = 0, prefixes = 0;
  void walk(MatchResult k) {
    final c = k.clause;
    final kids = k.subClauseMatches.where((x) => x is! SyntaxError).toList();
    if (c is Seq && kids.isNotEmpty && kids.length < c.subClauses.length) {
      var aligned = true;
      for (var i = 0; i < kids.length; i++) {
        final kc = kids[i].clause;
        if (kc != null && !identical(kc, c.subClauses[i])) aligned = false;
      }
      if (aligned) {
        prefixes++;
      } else {
        holes++;
      }
    }
    k.subClauseMatches.forEach(walk);
  }

  walk(m);
  return (holes, prefixes);
}

void main(List<String> argv) {
  final names = argv.isEmpty ? const ['r1', 'm143'] : argv;
  final rulesOf = {
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };

  final seen = <String>{};
  final cases = <Case>[];
  for (final k in weighted(buildBattery())) {
    if (seen.add('${k.grammar}\x00${k.category}\x00${k.mutant}')) cases.add(k);
  }

  print('${'engine'.padRight(8)}${'holes'.padLeft(10)}${'nodes'.padLeft(7)}'
      '${'prefixes'.padLeft(11)}${'nodes'.padLeft(7)}   worst hole');
  for (final e in names) {
    final b = resolve(e);
    if (b == null) {
      print('$e UNKNOWN');
      continue;
    }
    final made = {
      for (final c in corpora) c.name: b(rulesOf[c.name]!, c.top)
    };
    var holeCases = 0, holeNodes = 0, preCases = 0, preNodes = 0, worst = 0;
    var worstCase = '';
    for (final k in cases) {
      int h, p;
      try {
        final t = made[k.grammar]!(k.mutant);
        if (t == null) continue;
        (h, p) = shortSeqs(t);
      } catch (_) {
        continue;
      }
      if (h > 0) {
        holeCases++;
        holeNodes += h;
      }
      if (p > 0) {
        preCases++;
        preNodes += p;
      }
      if (h > worst) {
        worst = h;
        worstCase = '${k.grammar} ${k.mutant}';
      }
    }
    print('${e.padRight(8)}${'$holeCases/${cases.length}'.padLeft(10)}'
        '${'$holeNodes'.padLeft(7)}${'$preCases/${cases.length}'.padLeft(11)}'
        '${'$preNodes'.padLeft(7)}   ${worst == 0 ? '-' : '$worst in $worstCase'}');
  }
}
