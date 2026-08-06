// Pricing a supplied literal by its own length changes r9's answer on 9 of the
// battery's 1824 cases, and moves no digit of the reported score. This scores
// exactly those 9 under both pricings, which is the only way to tell an
// improvement from a wash.
//
// `_r9len.dart` is r9 with the change; `r9.dart` is r9 as committed. The
// comparison is over the WHOLE tree: `skeleton` is the scoring projection and
// drops SyntaxError marks, so it cannot see a change in what the engine admits.
import 'package:squirrel_parser/squirrel_parser.dart';

import '_r9len.dart' as len;
import 'astdiff.dart';
import 'r9.dart' as flat;

void main() {
  final cases = weighted(buildBattery());
  final byCorpus = <String, Corpus>{for (final c in corpora) c.name: c};
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final original = <String, MatchResult>{};
  for (final c in corpora) {
    for (final doc in c.documents) {
      original['${c.name} $doc'] =
          Parser(rules: rulesOf[c.name]!, topRuleName: c.top, input: doc)
              .parse()
              .root;
    }
  }
  final a = <String, MatchResult? Function(String)>{};
  final b = <String, MatchResult? Function(String)>{};
  for (final c in corpora) {
    a[c.name] = flat.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top).recover;
    b[c.name] = len.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top).recover;
  }

  var differ = 0;
  var sumA = 0.0, sumB = 0.0, betterB = 0, betterA = 0;
  for (final k in cases) {
    final c = byCorpus[k.grammar]!;
    MatchResult? run(MatchResult? Function(String) f) {
      try {
        return f(k.mutant);
      } catch (_) {
        return null;
      }
    }

    final x = run(a[k.grammar]!), y = run(b[k.grammar]!);
    final xs = x == null ? 'NULL' : x.toPrettyString(k.mutant);
    final ys = y == null ? 'NULL' : y.toPrettyString(k.mutant);
    if (xs == ys) continue;
    differ++;
    final exp = expectedFor(k, original['${k.grammar} ${k.original}']!, c.named);
    double sc(MatchResult? t) => t == null
        ? 0
        : scoreCase(
            produced: t,
            expected: exp,
            inputLen: k.mutant.length,
            named: c.named,
          ).score;
    final p = sc(x), q = sc(y);
    sumA += p;
    sumB += q;
    if (q > p) betterB++;
    if (p > q) betterA++;
    print('${k.grammar} "${k.mutant}"');
    print('  as committed ${p.toStringAsFixed(4)}   '
        'priced by length ${q.toStringAsFixed(4)}');
  }
  print('---');
  print('differing: $differ   committed total ${sumA.toStringAsFixed(4)}   '
      'by-length total ${sumB.toStringAsFixed(4)}');
  print('by-length better on $betterB, worse on $betterA');
}
