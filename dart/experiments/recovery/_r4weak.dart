// _r4weak.dart -- where r4 still loses, and to whom.
//
//   dart run _r4weak.dart deficit          per-category: how much score is
//                                          missing, and how few cases hold it
//   dart run _r4weak.dart worst [n]        the n worst-scoring cases
//   dart run _r4weak.dart vs <other> [n]   cases where <other> beats r4
//   dart run _r4weak.dart slow [n]         the n slowest cases for r4
import 'dart:convert';

import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_score1.dart' show resolve;

void main(List<String> argv) {
  final mode = argv.isEmpty ? 'deficit' : argv[0];
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final byName = {for (final c in corpora) c.name: c};
  final original = <String, MatchResult>{};
  for (final c in corpora) {
    for (final doc in c.documents) {
      original['${c.name} $doc'] =
          Parser(rules: rulesOf[c.name]!, topRuleName: c.top, input: doc)
              .parse()
              .root;
    }
  }

  Map<String, MatchResult? Function(String)> engine(String n) => {
        for (final c in corpora) c.name: resolve(n)!(rulesOf[c.name]!, c.top)
      };

  final r4 = engine('r4');
  final cases = weighted(buildBattery());
  // One row per DISTINCT case, but keep the battery's weight so the numbers
  // reconcile with `_score1`.
  final weight = <String, int>{};
  final uniq = <String, Case>{};
  for (final k in cases) {
    final id = '${k.grammar}\x00${k.mutant}';
    weight[id] = (weight[id] ?? 0) + 1;
    uniq[id] = k;
  }

  double score(MatchResult? Function(String) f, Case k, {Stopwatch? sw}) {
    MatchResult? r;
    sw?.start();
    try {
      r = f(k.mutant);
    } catch (_) {}
    sw?.stop();
    final c = byName[k.grammar]!;
    return scoreCase(
            produced: r,
            expected:
                expectedFor(k, original['${k.grammar} ${k.original}']!, c.named),
            inputLen: k.mutant.length,
            named: c.named)
        .score;
  }

  if (mode == 'deficit') {
    // For each category: total weighted score missing, and how it concentrates.
    final lost = <String, double>{};
    final n = <String, int>{};
    final imperfect = <String, int>{};
    final worstOf = <String, List<(double, String)>>{};
    for (final e in uniq.entries) {
      final k = e.value, w = weight[e.key]!;
      final s = score(r4[k.grammar]!, k);
      lost[k.category] = (lost[k.category] ?? 0) + (1 - s) * w;
      n[k.category] = (n[k.category] ?? 0) + w;
      if (s < 1.0) {
        imperfect[k.category] = (imperfect[k.category] ?? 0) + w;
        (worstOf[k.category] ??= []).add((s, k.mutant));
      }
    }
    final order = lost.keys.toList()
      ..sort((a, b) => lost[b]!.compareTo(lost[a]!));
    final grand = lost.values.fold(0.0, (a, b) => a + b);
    print('category         score  cases  imperf   lost  %of-deficit');
    for (final c in order) {
      print('${c.padRight(16)}'
          '${(1 - lost[c]! / n[c]!).toStringAsFixed(3).padLeft(5)}'
          '${n[c]!.toString().padLeft(7)}'
          '${(imperfect[c] ?? 0).toString().padLeft(8)}'
          '${lost[c]!.toStringAsFixed(1).padLeft(7)}'
          '${(lost[c]! / grand * 100).toStringAsFixed(1).padLeft(9)}%');
    }
    print('\ntotal deficit ${grand.toStringAsFixed(1)} '
        'over ${n.values.fold(0, (a, b) => a + b)} weighted cases');
    for (final c in order) {
      final l = worstOf[c] ?? [];
      l.sort((a, b) => a.$1.compareTo(b.$1));
      print('\n-- $c, worst 6 of ${l.length} imperfect --');
      for (final r in l.take(6)) {
        print('  ${r.$1.toStringAsFixed(3)}  `${r.$2}`');
      }
    }
    return;
  }

  if (mode == 'literal') {
    // The TRUE ceiling for "allow a deletion inside a terminal": r4's whole
    // weighted deficit over cases whose damage lands inside a multi-character
    // literal -- including cases m143 also loses, which `bought` cannot see.
    List<(int, int)> literalSpans(MatchResult m) {
      final out = <(int, int)>[];
      void walk(MatchResult k) {
        final cl = k.clause;
        if (cl is Str && cl.text.length > 1 && k.len > 0) {
          out.add((k.pos, k.pos + k.len));
        }
        for (final j in k.subClauseMatches) {
          walk(j);
        }
      }
      walk(m);
      return out;
    }

    var n = 0;
    double lost = 0, lostAll = 0;
    final rows = <(double, String, String)>[];
    for (final e in uniq.entries) {
      final k = e.value, w = weight[e.key]!;
      final s = score(r4[k.grammar]!, k);
      lostAll += (1 - s) * w;
      if (s >= 1.0) continue;
      final o = k.original, mu = k.mutant;
      var p = 0;
      while (p < o.length && p < mu.length && o[p] == mu[p]) {
        p++;
      }
      var sf = 0;
      while (sf < o.length - p &&
          sf < mu.length - p &&
          o[o.length - 1 - sf] == mu[mu.length - 1 - sf]) {
        sf++;
      }
      final lo = p, hi = o.length - sf;
      final spans = literalSpans(original['${k.grammar} $o']!);
      final hit = spans.any((sp) =>
          (lo < hi && lo >= sp.$1 && hi <= sp.$2) ||
          (lo >= hi && lo > sp.$1 && lo < sp.$2));
      if (!hit) continue;
      n += w;
      lost += (1 - s) * w;
      rows.add((s, k.category, k.mutant));
    }
    print('r4 is imperfect on $n weighted cases whose damage falls INSIDE a '
        'multi-character literal');
    print('they hold ${lost.toStringAsFixed(1)} of r4\'s '
        '${lostAll.toStringAsFixed(1)} total deficit '
        '(${(lost / lostAll * 100).toStringAsFixed(1)}%)');
    rows.sort((a, b) => a.$1.compareTo(b.$1));
    print('\nworst 15:');
    for (final r in rows.take(15)) {
      print('  ${r.$1.toStringAsFixed(3)}  ${r.$2.padRight(15)}'
          '${jsonEncode(r.$3)}');
    }
    return;
  }

  if (mode == 'worst') {
    final n = argv.length > 1 ? int.parse(argv[1]) : 25;
    final rows = <(double, String, String)>[];
    for (final e in uniq.entries) {
      final k = e.value;
      rows.add((score(r4[k.grammar]!, k), k.category, k.mutant));
    }
    rows.sort((a, b) => a.$1.compareTo(b.$1));
    for (final r in rows.take(n)) {
      print('${r.$1.toStringAsFixed(3)}  ${r.$2.padRight(15)} `${r.$3}`');
    }
    return;
  }

  if (mode == 'vs') {
    final other = engine(argv[1]);
    final n = argv.length > 2 ? int.parse(argv[2]) : 25;
    final rows = <(double, String, double, double, String)>[];
    var up = 0, down = 0;
    double sumUp = 0, sumDown = 0;
    for (final e in uniq.entries) {
      final k = e.value, w = weight[e.key]!;
      final a = score(r4[k.grammar]!, k), b = score(other[k.grammar]!, k);
      if ((a - b).abs() < 1e-9) continue;
      b > a ? up++ : down++;
      b > a ? sumUp += (b - a) * w : sumDown += (a - b) * w;
      rows.add((b - a, k.category, a, b, k.mutant));
    }
    rows.sort((x, y) => y.$1.compareTo(x.$1));
    print('${argv[1]} beats r4 on $up cases (weighted gain '
        '${sumUp.toStringAsFixed(1)}); r4 beats ${argv[1]} on $down '
        '(weighted gain ${sumDown.toStringAsFixed(1)})\n');
    print('  delta      r4  ${argv[1].padLeft(6)}  category         input');
    for (final r in rows.take(n)) {
      print('${r.$1.toStringAsFixed(3).padLeft(7)} '
          '${r.$3.toStringAsFixed(3).padLeft(7)} ${r.$4.toStringAsFixed(3).padLeft(7)}  '
          '${r.$2.padRight(15)} `${r.$5}`');
    }
    return;
  }

  if (mode == 'bought') {
    // Over the cases the other engine WINS: how many of its trees carry a
    // zero-width NAMED node (a `Ref`, i.e. a content construct) that r4's tree
    // does not? That is score bought by asserting a construct the document
    // never wrote, which is exactly what r4's `_lift` rule refuses.
    final other = engine(argv.length > 1 ? argv[1] : 'm143');
    // A zero-width `WS` or `Char` is not invention -- those rules derive the
    // empty string, so matching nothing is what the grammar says they do. Only
    // a rule that CANNOT be empty is fabricated when it appears with len 0.
    // Ask the frozen parser which is which rather than guessing from the name.
    final nullable = <String, Set<String>>{};
    for (final c in corpora) {
      final s = <String>{};
      for (final key in rulesOf[c.name]!.keys) {
        final name = key.startsWith('~') ? key.substring(1) : key;
        try {
          final root =
              Parser(rules: rulesOf[c.name]!, topRuleName: name, input: '')
                  .parse()
                  .root;
          if (root.len == 0 && root is! SyntaxError && !root.isMismatch) {
            s.add(name);
          }
        } catch (_) {}
      }
      nullable[c.name] = s;
    }
    for (final c in corpora) {
      print('${c.name}: nullable rules ${nullable[c.name]!.toList()..sort()}');
    }

    Map<String, int> namedZeroWidth(MatchResult? m, String g) {
      final h = <String, int>{};
      if (m == null) return h;
      void walk(MatchResult k) {
        final cl = k.clause;
        if (k is! SyntaxError &&
            k.len == 0 &&
            cl is Ref &&
            !nullable[g]!.contains(cl.ruleName)) {
          h[cl.ruleName] = (h[cl.ruleName] ?? 0) + 1;
        }
        for (final j in k.subClauseMatches) {
          walk(j);
        }
      }
      walk(m);
      return h;
    }

    MatchResult? run(MatchResult? Function(String) f, String s) {
      try {
        return f(s);
      } catch (_) {
        return null;
      }
    }

    var wins = 0, withInvention = 0;
    double gain = 0, gainWithInvention = 0;
    final byCat = <String, (int, int)>{};
    final fabricated = <String, int>{}; // which construct, and how often
    final rest = <(double, Case)>[]; // wins invention does NOT explain
    for (final e in uniq.entries) {
      final k = e.value, w = weight[e.key]!;
      final a = score(r4[k.grammar]!, k), b = score(other[k.grammar]!, k);
      if (b - a < 1e-9) continue;
      wins++;
      gain += (b - a) * w;
      final mineN = namedZeroWidth(run(r4[k.grammar]!, k.mutant), k.grammar);
      final theirsN =
          namedZeroWidth(run(other[k.grammar]!, k.mutant), k.grammar);
      final extra = <String, int>{};
      for (final r in theirsN.keys) {
        final d = theirsN[r]! - (mineN[r] ?? 0);
        if (d > 0) extra[r] = d;
      }
      final invented = extra.isNotEmpty;
      if (invented) {
        withInvention++;
        gainWithInvention += (b - a) * w;
        for (final r in extra.keys) {
          fabricated['${k.grammar}.$r'] =
              (fabricated['${k.grammar}.$r'] ?? 0) + extra[r]!;
        }
      }
      final p = byCat[k.category] ?? (0, 0);
      byCat[k.category] = (p.$1 + 1, p.$2 + (invented ? 1 : 0));
      if (!invented) rest.add((((b - a) * w), k));
    }
    rest.sort((x, y) => y.$1.compareTo(x.$1));
    print('${argv.length > 1 ? argv[1] : "m143"} wins $wins cases, weighted '
        'gain ${gain.toStringAsFixed(1)}');
    print('of those, $withInvention carry a zero-width NAMED node r4 does not, '
        'worth ${gainWithInvention.toStringAsFixed(1)} '
        '(${(gainWithInvention / gain * 100).toStringAsFixed(0)}% of the gain)');
    print('\ncategory          wins  bought-with-invention');
    final order = byCat.keys.toList()
      ..sort((a, b) => byCat[b]!.$2.compareTo(byCat[a]!.$2));
    for (final c in order) {
      print('${c.padRight(17)}${byCat[c]!.$1.toString().padLeft(5)}'
          '${byCat[c]!.$2.toString().padLeft(23)}');
    }
    print('\nwhich constructs it fabricates (rule, times):');
    final fk = fabricated.keys.toList()
      ..sort((a, b) => fabricated[b]!.compareTo(fabricated[a]!));
    for (final r in fk) {
      print('  ${r.padRight(20)}${fabricated[r]}');
    }
    // Of the wins invention does not explain: does the damage land INSIDE a
    // multi-character literal of the clean parse? `_align` consumes the input
    // characters at `pos` contiguously and entirely (it requires `j == k`), so
    // it can SUPPLY a character the literal wanted but can never SKIP a junk
    // character inside the literal's span. That is a deletion inside a
    // terminal -- the one mechanism r4 lacks that its own rules do not forbid.
    List<(int, int)> literalSpans(MatchResult m) {
      final out = <(int, int)>[];
      void walk(MatchResult k) {
        final cl = k.clause;
        if (cl is Str && cl.text.length > 1 && k.len > 0) {
          out.add((k.pos, k.pos + k.len));
        }
        for (final j in k.subClauseMatches) {
          walk(j);
        }
      }
      walk(m);
      return out;
    }

    var inLiteral = 0;
    double inLiteralGain = 0;
    for (final e in rest) {
      final k = e.$2;
      final o = k.original, mu = k.mutant;
      var p = 0;
      while (p < o.length && p < mu.length && o[p] == mu[p]) {
        p++;
      }
      var s = 0;
      while (s < o.length - p && s < mu.length - p && o[o.length - 1 - s] == mu[mu.length - 1 - s]) {
        s++;
      }
      final lo = p, hi = o.length - s; // the damaged range IN THE ORIGINAL
      final spans = literalSpans(original['${k.grammar} $o']!);
      // Damage strictly inside a literal, or an insertion at an interior point.
      final hit = spans.any((sp) =>
          (lo < hi && lo >= sp.$1 && hi <= sp.$2) ||
          (lo >= hi && lo > sp.$1 && lo < sp.$2));
      if (hit) {
        inLiteral++;
        inLiteralGain += e.$1;
      }
    }
    print('\nthe ${rest.length} wins invention does NOT explain, worth '
        '${(gain - gainWithInvention).toStringAsFixed(1)}');
    print('of those, $inLiteral have the damage INSIDE a multi-character '
        'literal, worth ${inLiteralGain.toStringAsFixed(1)} '
        '(${(inLiteralGain / (gain - gainWithInvention) * 100).toStringAsFixed(0)}% '
        'of the unexplained gain) -- these need a deletion inside a terminal');
    print('\nworst 20 unexplained:');
    for (final e in rest.take(20)) {
      final k = e.$2;
      print('  ${e.$1.toStringAsFixed(3)}  ${k.category.padRight(15)}'
          '${k.grammar.padRight(6)}${jsonEncode(k.mutant)}');
    }
    return;
  }

  if (mode == 'gap') {
    // Per category: how much of r4's deficit m143 ALSO carries (a floor neither
    // design reaches past) and how much is r4's alone (an addressable gap).
    final other = engine(argv.length > 1 ? argv[1] : 'm143');
    final mine = <String, double>{}, theirs = <String, double>{};
    final both = <String, double>{}, n = <String, int>{};
    for (final e in uniq.entries) {
      final k = e.value, w = weight[e.key]!;
      final a = score(r4[k.grammar]!, k), b = score(other[k.grammar]!, k);
      mine[k.category] = (mine[k.category] ?? 0) + (1 - a) * w;
      theirs[k.category] = (theirs[k.category] ?? 0) + (1 - b) * w;
      // The part of r4's loss that the other engine does not recover either.
      both[k.category] = (both[k.category] ?? 0) + (1 - (a > b ? a : b)) * w;
      n[k.category] = (n[k.category] ?? 0) + w;
    }
    final order = mine.keys.toList()
      ..sort((a, b) =>
          (mine[b]! - both[b]!).compareTo(mine[a]! - both[a]!));
    print('category         r4lost  otherlost  shared-floor  r4-only');
    for (final c in order) {
      print('${c.padRight(16)}'
          '${mine[c]!.toStringAsFixed(1).padLeft(6)}'
          '${theirs[c]!.toStringAsFixed(1).padLeft(11)}'
          '${both[c]!.toStringAsFixed(1).padLeft(14)}'
          '${(mine[c]! - both[c]!).toStringAsFixed(1).padLeft(9)}');
    }
    final tm = mine.values.fold(0.0, (a, b) => a + b);
    final tb = both.values.fold(0.0, (a, b) => a + b);
    print('\nr4 total deficit ${tm.toStringAsFixed(1)}; '
        '${tb.toStringAsFixed(1)} of it (${(tb / tm * 100).toStringAsFixed(0)}%) '
        'is a floor ${argv.length > 1 ? argv[1] : "m143"} does not reach past '
        'either; ${(tm - tb).toStringAsFixed(1)} is addressable.');
    return;
  }

  if (mode == 'show') {
    // show <g> <input> <engine,...>  -- skeleton, marks, and any node that
    // claims characters (len > 0) while carrying a zero-width repair inside it.
    final g = argv[1], s = argv[2], c = byName[g]!;
    for (final v in argv[3].split(',')) {
      final r = resolve(v)!(rulesOf[g]!, c.top)(s);
      final marks = <String>[];
      final fabricated = <String>[];
      void walk(MatchResult m) {
        if (m is SyntaxError) {
          marks.add(m.len == 0
              ? 'fill@${m.pos}'
              : 'del@${m.pos}:${s.substring(m.pos, m.pos + m.len)}');
        } else if (m.len == 0 && m.clause != null) {
          final cl = m.clause!;
          fabricated.add(cl is Ref ? cl.ruleName : cl.runtimeType.toString());
        }
        for (final k in m.subClauseMatches) {
          walk(k);
        }
      }
      if (r != null) walk(r);
      print('${v.padRight(6)} ${r == null ? "(null)" : skeleton(r, c.named).join(' ')}');
      print('       marks: ${marks.join(' ')}');
      print('       zero-width nodes: '
          '${fabricated.isEmpty ? "none" : fabricated.join(' ')}');
    }
    return;
  }

  if (mode == 'slow') {
    final n = argv.length > 1 ? int.parse(argv[1]) : 20;
    for (final e in uniq.entries) {
      score(r4[e.value.grammar]!, e.value); // warm the JIT
    }
    final rows = <(int, String, String, double)>[];
    for (final e in uniq.entries) {
      final k = e.value;
      final sw = Stopwatch();
      final s = score(r4[k.grammar]!, k, sw: sw);
      rows.add((sw.elapsedMicroseconds, k.category, k.mutant, s));
    }
    rows.sort((a, b) => b.$1.compareTo(a.$1));
    final tot = rows.fold(0, (a, b) => a + b.$1);
    final top = rows.take(n).fold(0, (a, b) => a + b.$1);
    print('total ${(tot / 1000).toStringAsFixed(0)} ms over ${rows.length} '
        'distinct cases; slowest $n are ${(top / tot * 100).toStringAsFixed(1)}%'
        ' of it\n');
    for (final r in rows.take(n)) {
      print('${(r.$1 / 1000).toStringAsFixed(2).padLeft(8)} ms  '
          'score ${r.$4.toStringAsFixed(3)}  ${r.$2.padRight(15)} `${r.$3}`');
    }
    return;
  }
  print('unknown mode $mode');
}
