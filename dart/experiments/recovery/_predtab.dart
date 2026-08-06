// Scratch: WHICH corner cases does each engine get wrong, and in which
// direction? `final_table.dart`'s new `pred`/`unsnd` columns are counts, and a
// count is not traceable -- this prints the per-case verdict grid behind them, so
// a row that regresses can be pinned to a grammar and an input.
//
// It reuses final_table.dart's own `predCases`, `predMaxK`, `truth` and
// `verdictOf`, so there is no second copy of the battery to drift.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'final_table.dart' show predCases, predMaxK, truth, verdictOf;
import 'm41.dart' as g41;
import 'm44.dart' as g44;
import 'm45.dart' as g45;
import 'm46.dart' as g46;
import 'm47.dart' as g47;
import 'm48.dart' as g48;
import 'm49.dart' as g49;

typedef Cost = int Function(String);

final makers = <String, Cost Function(Map<String, Clause>, String)>{
  'm41': (r, t) => g41.SuperDot3(rules: r, topRuleName: t).recoverCost,
  'm44': (r, t) => g44.SuperDot3(rules: r, topRuleName: t).recoverCost,
  'm45': (r, t) => g45.SuperDot3(rules: r, topRuleName: t).recoverCost,
  'm46': (r, t) => g46.SuperDot3(rules: r, topRuleName: t).recoverCost,
  'm47': (r, t) => g47.SuperDot3(rules: r, topRuleName: t).recoverCost,
  'm48': (r, t) => g48.SuperDot3(rules: r, topRuleName: t).recoverCost,
  'm49': (r, t) => g49.SuperDot3(rules: r, topRuleName: t).recoverCost,
};

void main() {
  final names = makers.keys.toList();
  final ok = {for (final n in names) n: 0};
  final under = {for (final n in names) n: 0};
  final over = {for (final n in names) n: 0};
  var tot = 0;
  final unsound = <String>[];

  for (final (g, top, alpha, inputs) in predCases) {
    final rules = MetaGrammar.parseGrammar(g);
    print('\n${g.replaceAll('\n', ' ')}');
    print('  ${'input'.padRight(8)}${'true'.padLeft(5)}'
        '${names.map((n) => n.padLeft(6)).join()}');
    for (final s in inputs) {
      final want = truth(rules, top, g, s, alpha, predMaxK);
      final cells = <String>[];
      var counted = false;
      for (final n in names) {
        int got;
        try {
          got = makers[n]!(rules, top)(s);
        } catch (_) {
          got = -1;
        }
        final v = verdictOf(want, got, predMaxK);
        if (v != 'unk') counted = true;
        if (v == 'ok') ok[n] = ok[n]! + 1;
        if (v == 'over') over[n] = over[n]! + 1;
        if (v == 'under') {
          under[n] = under[n]! + 1;
          unsound.add('$n  ${g.replaceAll('\n', ' ')}  "$s": '
              'said $got, truth ${want ?? '>$predMaxK'}');
        }
        cells.add('$got${v == 'ok' ? ' ' : v == 'under' ? '!' : v == 'over' ? '+' : '?'}'
            .padLeft(6));
      }
      if (counted) tot++;
      print('  ${(s.isEmpty ? '<empty>' : s).padRight(8)}'
          '${(want?.toString() ?? '>$predMaxK').padLeft(5)}${cells.join()}');
    }
  }

  print('\n(blank = exact, + = too high/safe, ! = UNDER-REPORT/unsound, '
      '? = truth beyond K=$predMaxK)');
  print('\n${'engine'.padRight(7)}${'exact'.padLeft(7)}${'over'.padLeft(6)}'
      '${'UNDER'.padLeft(7)}   of $tot settled cases');
  for (final n in names) {
    print('${n.padRight(7)}${ok[n]!.toString().padLeft(7)}'
        '${over[n]!.toString().padLeft(6)}${under[n]!.toString().padLeft(7)}');
  }
  print('\nEvery under-report, in full -- each names a repair that does not '
      'exist:');
  for (final u in unsound) {
    print('  $u');
  }
}
