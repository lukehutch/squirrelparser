// _amb75.dart -- three tie-breaks over the SAME minimum-edit search.
//
// The search is identical in all three arms; only the secondary key differs,
// and the secondary key is lexicographically below cost, so it can never change
// the number of edits -- only which of the equally-cheap repairs survives.
//
//   m74  regret, deviation form: kept characters charged (w - h), discarded
//        charged 2h, a fabrication charged the FLAT WHOLE-UNICODE width no
//        matter what it writes.
//   fab  the same, with the one derivation error corrected: a fabrication
//        writes from class C, so it is charged `width(C)`, not `width(AnyChar)`.
//   amb  (invention, loss) lexicographic. Invention = bits the repair asserts
//        that the input did not justify = log2|C| per fabricated character, ZERO
//        when the grammar forced it. Loss = input characters not preserved.
//        Kept characters cost nothing in either component.
//
// Scored on the document each engine ACTUALLY CERTIFIES (its own `_repaired()`),
// not on a reconstruction from `SkipResult` -- `recover()` reports a
// substitution as a bare deletion span and drops the replacement text, so a
// SkipResult reconstruction reads a swap as pure destruction.
import 'dart:io';

import 'final_table.dart' show buildSetup, treeShape;
import '_m74w.dart' as e74;
import '_m74fabw.dart' as efab;
import '_m74ambw.dart' as eamb;

const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';

/// Input characters that do not survive into `y`, by longest common
/// subsequence: the edit list is the engine's business, this is the outcome.
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

/// Characters in `y` that were not in the input: what the repair invented.
int invented(String input, String y) => dropped(y, input);

class Arm {
  Arm(this.name, this.recover, this.cost, this.verified, this.doc);
  final String name;
  final dynamic Function(String) recover;
  final int Function() cost;
  final bool Function() verified;
  final String Function() doc;
  var shape = 0, certified = 0, exact = 0, loss = 0, inv = 0, costSum = 0;
}

void main() {
  final (rules, battery, origShape, _, __, ___, ____, _____) = buildSetup();
  final a74 = e74.SuperDot3(rules: rules, topRuleName: 'JSON');
  final afab = efab.SuperDot3(rules: rules, topRuleName: 'JSON');
  final aamb = eamb.SuperDot3(rules: rules, topRuleName: 'JSON');
  final arms = [
    Arm('m74', a74.recover, () => a74.lastCost, () => a74.lastVerified,
        () => a74.lastRepairedDoc),
    Arm('fab', afab.recover, () => afab.lastCost, () => afab.lastVerified,
        () => afab.lastRepairedDoc),
    Arm('amb', aamb.recover, () => aamb.lastCost, () => aamb.lastVerified,
        () => aamb.lastRepairedDoc),
  ];

  // The user's two cases, by construction rather than by hunting for them.
  final probes = <(String, String)>[
    (
      base.substring(0, 16) + base[17] + base[16] + base.substring(18),
      'transposed `33,` -> `3,3`: the list reads `[2,3,3true]`, '
          'and `3true` needs a comma'
    ),
    (
      base.substring(0, 13) + base.substring(14),
      'deleted the `2`: the list reads `[,33,true]`, '
          'and the leading comma is stray'
    ),
  ];

  for (final s in battery) {
    for (final arm in arms) {
      final r = arm.recover(s);
      final y = arm.doc();
      if (treeShape(r.root) == origShape) arm.shape++;
      if (arm.verified()) arm.certified++;
      if (y == base) arm.exact++;
      if (arm.cost() >= 0) arm.costSum += arm.cost();
      arm.loss += dropped(s, y);
      arm.inv += invented(s, y);
    }
  }

  stdout.writeln('battery ${battery.length} inputs, all corrupted from one '
      'document\n');
  stdout.writeln('arm   costsum  certified  shape  ==original  chars lost  '
      'chars invented');
  for (final a in arms) {
    stdout.writeln('${a.name.padRight(5)} '
        '${a.costSum.toString().padLeft(7)}  '
        '${a.certified.toString().padLeft(9)}  '
        '${a.shape.toString().padLeft(5)}  '
        '${a.exact.toString().padLeft(10)}  '
        '${a.loss.toString().padLeft(10)}  '
        '${a.inv.toString().padLeft(14)}');
  }

  stdout.writeln('\n---- the two cases named in the brief ----');
  for (final (s, why) in probes) {
    stdout.writeln('\n  $why');
    stdout.writeln('  input   $s');
    for (final a in arms) {
      a.recover(s);
      stdout.writeln('  ${a.name.padRight(4)} cost ${a.cost()}  ${a.doc()}');
    }
  }

  // Where do the three disagree, and does `amb` ever lose ground?
  var d = 0;
  final lines = <String>[];
  for (final s in battery) {
    final ys = arms.map((a) {
      a.recover(s);
      return a.doc();
    }).toList();
    if (ys.toSet().length == 1) continue;
    d++;
    if (lines.length < 24) {
      lines.add('  input $s\n'
          '${arms.indexed.map((e) => '    ${e.$2.name} ${ys[e.$1]}'
              '${ys[e.$1] == base ? "  == ORIGINAL" : ""}').join('\n')}');
    }
  }
  stdout.writeln('\n---- $d of ${battery.length} inputs where the arms '
      'disagree (first ${lines.length}) ----');
  for (final l in lines) {
    stdout.writeln(l);
  }
}
