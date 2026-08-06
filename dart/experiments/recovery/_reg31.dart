// Scratch: which cases did the per-slot give-up move from EXACT to inexact?
//   dart run _reg31.dart
import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import 'r6.dart' as a;
import '_v31.dart' as b;

void main() {
  final cases = weighted(buildBattery());
  final byCorpus = {for (final c in corpora) c.name: c};
  final rulesOf = {
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final original = <String, MatchResult>{};
  for (final c in corpora) {
    for (final doc in c.documents) {
      original['${c.name} $doc'] = Parser(
              rules: rulesOf[c.name]!, topRuleName: c.top, input: doc)
          .parse()
          .root;
    }
  }
  final ea = {
    for (final c in corpora)
      c.name: a.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top).recover
  };
  final eb = {
    for (final c in corpora)
      c.name: b.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top).recover
  };
  MatchResult? run(MatchResult? Function(String) f, String s) {
    try {
      return f(s);
    } catch (_) {
      return null;
    }
  }

  var lost = 0, won = 0;
  final lostBy = <String, int>{}, wonBy = <String, int>{};
  final shown = <String, int>{};
  for (final k in cases) {
    final c = byCorpus[k.grammar]!;
    final exp = expectedFor(k, original['${k.grammar} ${k.original}']!, c.named);
    CaseScore sc(MatchResult? m) => scoreCase(
        produced: m,
        expected: exp,
        inputLen: k.mutant.length,
        named: c.named);
    final ra = sc(run(ea[k.grammar]!, k.mutant));
    final rb = sc(run(eb[k.grammar]!, k.mutant));
    if (ra.errors == 0 && rb.errors != 0) {
      lost++;
      lostBy[k.category] = (lostBy[k.category] ?? 0) + 1;
      if ((shown[k.category] ?? 0) < 2) {
        shown[k.category] = (shown[k.category] ?? 0) + 1;
        print('LOST ${k.category}  ${k.grammar}');
        print('  input    ${k.mutant}');
        print('  want     ${exp.join(" ")}');
        final g = run(eb[k.grammar]!, k.mutant);
        print('  v31 got  ${g == null ? "<crash>" : skeleton(g, c.named).join(" ")}');
      }
    } else if (ra.errors != 0 && rb.errors == 0) {
      won++;
      wonBy[k.category] = (wonBy[k.category] ?? 0) + 1;
    }
  }
  print('\nEXACT lost $lost  $lostBy');
  print('EXACT won  $won  $wonBy');
}
