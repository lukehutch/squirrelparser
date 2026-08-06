// _idist.dart -- where m81's time goes, counted rather than guessed.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' show jsonGrammar;
import '_i81.dart' as e;

const doc = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  bool parses(String s) => !Parser(rules: rules, topRuleName: 'JSON', input: s)
      .parse()
      .hasSyntaxErrors;
  final b = <String>[];
  for (var j = 0; j < doc.length; j++) {
    b.add(doc.substring(0, j) + doc.substring(j + 1));
    if (j + 1 < doc.length && doc[j] != doc[j + 1]) {
      b.add(doc.substring(0, j) + doc[j + 1] + doc[j] + doc.substring(j + 2));
    }
  }
  for (var j = 0; j <= doc.length; j++) {
    for (final c in ['Q', 'z', '}', '"', ',', '5']) {
      b.add(doc.substring(0, j) + c + doc.substring(j));
      if (j < doc.length && doc[j] != c) {
        b.add(doc.substring(0, j) + c + doc.substring(j + 1));
      }
    }
  }
  final battery = b.where((x) => !parses(x)).toList();
  final eng = e.SuperDot3(rules: rules, topRuleName: 'JSON');
  for (final m in battery) {
    eng.recover(m);
  }
  final n = battery.length;
  String per(int v) => (v / n).toStringAsFixed(0).padLeft(8);
  print('mutants $n   rounds ${e.cRounds}  (${(e.cRounds / n).toStringAsFixed(2)}/mutant)');
  print('_fix calls  ${e.cFix}  ${per(e.cFix)} per mutant');
  print('  memo hits ${e.cHit}  ${(100 * e.cHit / e.cFix).toStringAsFixed(1)}%');
  print('  body runs ${e.cBody}  ${per(e.cBody)} per mutant');
  print('ways returned ${e.cWays}   ${(e.cWays / e.cFix).toStringAsFixed(2)} per _fix');
  print('_wrap allocs  ${e.cWrap}  ${per(e.cWrap)}');
  print('_seq extends  ${e.cSeqX}  ${per(e.cSeqX)}');
  print('_rep extends  ${e.cRepX}  ${per(e.cRepX)}');
  print('SKIP ways     ${e.cSkip}  ${per(e.cSkip)}');
  print('FILL ways     ${e.cFill}  ${per(e.cFill)}');
  print('\nbody runs by clause type:');
  final keys = e.byType.keys.toList()
    ..sort((a, b) => e.byType[b]!.compareTo(e.byType[a]!));
  for (final k in keys) {
    print('  ${k.padRight(16)} ${e.byType[k]!.toString().padLeft(9)}  '
        '${(100 * e.byType[k]! / e.cBody).toStringAsFixed(1)}%');
  }
  print('\nbody runs at a (clause,pos) the FROZEN parse never asked about: '
      '${e.cOffPath}  ${(100 * e.cOffPath / e.cBody).toStringAsFixed(1)}%');
}
