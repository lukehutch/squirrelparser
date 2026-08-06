// _ambloss75.dart -- the inputs where m74's tie-break gets the shape and the
// (invention, loss) tie-break does not, EXCLUDING the string-swallow, which
// `_swallow75` measured at 38 inputs / 4 shape losses and therefore is not the
// explanation.
//
// Prints the two documents side by side so the pattern has to declare itself.
import 'dart:io';

import 'final_table.dart' show buildSetup, treeShape;
import '_m74w.dart' as e74;
import '_m74ambw.dart' as eamb;

const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';

int count(String s, String ch) => s.split('').where((c) => c == ch).length;

int dropped(String input, String y) {
  final n = input.length, m = y.length;
  var prev = List.filled(m + 1, 0), cur = List.filled(m + 1, 0);
  for (var i = 1; i <= n; i++) {
    for (var j = 1; j <= m; j++) {
      cur[j] = input.codeUnitAt(i - 1) == y.codeUnitAt(j - 1)
          ? prev[j - 1] + 1
          : (prev[j] > cur[j - 1] ? prev[j] : cur[j - 1]);
    }
    final t = prev;
    prev = cur;
    cur = t;
  }
  return n - prev[m];
}

void main() {
  final (rules, battery, origShape, _, __, ___, ____, _____) = buildSetup();
  final a74 = e74.SuperDot3(rules: rules, topRuleName: 'JSON');
  final aamb = eamb.SuperDot3(rules: rules, topRuleName: 'JSON');

  final only74 = <String>[], onlyAmb = <String>[];
  for (final s in battery) {
    final r74 = a74.recover(s);
    final ramb = aamb.recover(s);
    final y74 = a74.lastRepairedDoc, yamb = aamb.lastRepairedDoc;
    if (count(yamb, '\\') > count(s, '\\')) continue; // swallow: already counted
    final ok74 = treeShape(r74.root) == origShape;
    final okamb = treeShape(ramb.root) == origShape;
    if (ok74 == okamb) continue;
    final row = '  input $s\n'
        '    m74 $y74  lost ${dropped(s, y74)}'
        '${y74 == base ? "  == ORIGINAL" : ""}${ok74 ? "   [shape ok]" : ""}\n'
        '    amb $yamb  lost ${dropped(s, yamb)}'
        '${yamb == base ? "  == ORIGINAL" : ""}${okamb ? "   [shape ok]" : ""}';
    (ok74 ? only74 : onlyAmb).add(row);
  }

  stdout.writeln('non-swallow inputs where the shape verdicts differ:');
  stdout.writeln('  only m74 gets the shape: ${only74.length}');
  stdout.writeln('  only amb gets the shape: ${onlyAmb.length}\n');
  stdout.writeln('---- only m74 ----');
  for (final r in only74) {
    stdout.writeln(r);
  }
  stdout.writeln('\n---- only amb ----');
  for (final r in onlyAmb) {
    stdout.writeln(r);
  }
}
