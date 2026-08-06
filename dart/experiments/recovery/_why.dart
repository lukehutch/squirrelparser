// _why.dart -- show the ACTUAL expected vs produced skeleton for cases in a
// chosen category. A category's mean score is a claim; this is the evidence.
// Usage: dart run _why.dart <category> [howMany]
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'm81.dart' as eng;

void main(List<String> argv) {
  final want = argv.isEmpty ? 'content-damage' : argv[0];
  final howMany = argv.length > 1 ? int.parse(argv[1]) : 4;

  final cases = weighted(buildBattery()).where((c) => c.category == want).toList();
  print('${cases.length} weighted cases in "$want"\n');

  final byCorpus = <String, Corpus>{for (final c in corpora) c.name: c};
  final engines = <String, eng.SuperDot3>{};
  final ruleset = <String, Map<String, Clause>>{};

  var shown = 0;
  var worstScore = 2.0;
  Case? worst;
  List<String>? worstExp, worstGot;

  for (final c in cases) {
    final co = byCorpus[c.grammar]!;
    final rules = ruleset.putIfAbsent(
        c.grammar, () => MetaGrammar.parseGrammar(co.grammar));
    final e = engines.putIfAbsent(
        c.grammar, () => eng.SuperDot3(rules: rules, topRuleName: co.top));
    final expected = expectedFor(
        c,
        Parser(rules: rules, topRuleName: co.top, input: c.original)
            .parse()
            .root,
        co.named);
    MatchResult? produced;
    try {
      produced = e.recover(c.mutant);
    } catch (_) {
      produced = null;
    }
    final s = scoreCase(
        produced: produced,
        expected: expected,
        inputLen: c.mutant.length,
        named: co.named);
    final got = produced == null ? <String>[] : skeleton(produced, co.named);

    if (s.score < worstScore) {
      worstScore = s.score;
      worst = c;
      worstExp = expected;
      worstGot = got;
    }
    if (shown < howMany) {
      shown++;
      print('[${c.grammar}] score ${s.score.toStringAsFixed(3)}  '
          'errors ${s.errors}  covered ${s.covered}');
      print('  orig    ${c.original}');
      print('  mutant  ${c.mutant}');
      print('  expect  ${expected.join(' ')}');
      print('  got     ${got.join(' ')}');
      print('');
    }
  }

  if (worst != null && worstScore < 1.0) {
    print('--- WORST case in "$want" (score ${worstScore.toStringAsFixed(3)}) ---');
    print('  [${worst.grammar}]');
    print('  orig    ${worst.original}');
    print('  mutant  ${worst.mutant}');
    print('  expect  ${worstExp!.join(' ')}');
    print('  got     ${worstGot!.join(' ')}');
  } else {
    print('--- no case in "$want" scores below 1.000 ---');
  }
}
