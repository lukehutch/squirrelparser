// _lad70.dart -- the LR/RR ladder for selected engines, printing the rung that
// fails AND the frames it failed in. Same grammars, same `oneErr`, same rungs
// as `final_table.dart`'s `depthLimit`, so answers are comparable to the
// LRmax/RRmax columns; the stack trace is the new part.
//
//   dart ... _lad70.dart m62,m67,m68,cgfr5
import 'package:squirrel_parser/squirrel_parser.dart';

import 'm62.dart' as e62;
import 'm64.dart' as e64;
import 'm66.dart' as e66;
import 'm67.dart' as e67;
import 'm68.dart' as e68;
import 'm69.dart' as e69;
import 'cgfr5.dart' as ecg5;
import 'm70.dart' as e70;
import '_cr70.dart' as ecr;

String oneErr(int k) {
  final c = List.generate(k, (i) => '${i % 10}').join('+');
  return '${c.substring(0, c.length ~/ 2)}+${c.substring(c.length ~/ 2)}';
}

final gLR = MetaGrammar.parseGrammar(
    "E <- E '+' T / T;\nT <- T '*' F / F;\nF <- [0-9] / '(' E ')';\n");
final gRR = MetaGrammar.parseGrammar(
    "E <- T '+' E / T;\nT <- F '*' T / F;\nF <- [0-9] / '(' E ')';\n");

final es = <String, int Function(Map<String, Clause>, String)>{
  'm62': (g, s) => e62.SuperDot3(rules: g, topRuleName: 'E').recoverCost(s),
  'm64': (g, s) => e64.SuperDot3(rules: g, topRuleName: 'E').recoverCost(s),
  'm66': (g, s) => e66.SuperDot3(rules: g, topRuleName: 'E').recoverCost(s),
  'm67': (g, s) => e67.SuperDot3(rules: g, topRuleName: 'E').recoverCost(s),
  'm68': (g, s) => e68.SuperDot3(rules: g, topRuleName: 'E').recoverCost(s),
  'm69': (g, s) => e69.SuperDot3(rules: g, topRuleName: 'E').recoverCost(s),
  'cgfr5': (g, s) => ecg5.SuperDot3(rules: g, topRuleName: 'E').recoverCost(s),
  'm70': (g, s) => e70.SuperDot3(rules: g, topRuleName: 'E').recoverCost(s),
  '_cr70': (g, s) => ecr.SuperDot3(rules: g, topRuleName: 'E').recoverCost(s),
};

String ladder(int Function(Map<String, Clause>, String) cost,
    Map<String, Clause> g, void Function(String) note) {
  var last = 'none';
  for (final k in const [256, 512, 1024, 2048]) {
    final s = oneErr(k);
    try {
      cost(g, s);
      last = '${s.length}';
    } on StackOverflowError catch (_, st) {
      final seen = <String>{};
      final top = <String>[];
      for (final f in st.toString().split('\n')) {
        final m = RegExp(r'#\d+\s+(\S+)').firstMatch(f);
        if (m == null) continue;
        if (seen.add(m.group(1)!)) top.add(m.group(1)!);
        if (top.length >= 4) break;
      }
      note('    overflow at len=${s.length} in ${top.join(" <- ")}');
      return last == 'none' ? '<${s.length}' : last;
    } catch (e) {
      note('    error at len=${s.length}: '
          '${e.toString().split("\n").first}');
      return last == 'none' ? 'err' : last;
    }
  }
  return '>=$last';
}

void main(List<String> args) {
  final names = args.isEmpty ? es.keys.toList() : args[0].split(',');
  print('engine   LRmax   RRmax');
  for (final n in names) {
    final notes = <String>[];
    final lr = ladder(es[n]!, gLR, notes.add);
    final rr = ladder(es[n]!, gRR, notes.add);
    print('${n.padRight(7)} ${lr.padLeft(7)} ${rr.padLeft(7)}');
    for (final x in notes) {
      print(x);
    }
  }
}
