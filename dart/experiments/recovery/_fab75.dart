// _fab75.dart -- is m74's FAB price a policy choice or a derivation error?
//
// m74 prices a SUB (discard one input character) at twice the width of the
// narrowest grammar class containing it, and a FAB (write one character,
// reading nothing) at the flat `_widestClass`. The second is not the same
// quantity as the first: SUB is priced by WHAT IT DESTROYS, FAB by the whole
// Unicode alphabet rather than by WHAT IT WRITES.
//
// LESSONS section 4 states the objective regret is derived from:
//     deviation form  Sum_kept (w - h)  +  Sum_discarded h
// where `w` is the width of the class that emitted the character and `h` the
// width of the narrowest class containing the input character there. A FAB
// keeps nothing and discards nothing: it writes a character from class `w`
// against no input at all, so its deviation price is `w - 0 = w`. It should
// cost `_widthOf(node.orig)`. `_widestClass` is that only when the leaf is
// AnyChar.
//
// Three arms on the identical 519-mutant battery: m74, the one-line fix, and
// the no-regret control. Reported per arm: shape against the original
// document, and separately how much of the input each arm DESTROYS and
// INVENTS -- because the user's stated priority is "the minimal set of changes
// so that something can still be recovered from the AST", which is not the
// same objective the shape column scores.
import 'dart:io';

import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/recovery/skip_recovery.dart' show SkipResult;

import 'final_table.dart' show buildSetup, treeShape;
import 'm74.dart' as e74;
import '_m74fab.dart' as efab;
import '_m74nr.dart' as enr;

const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';

String _spell(Clause c) => '[$c]';

(String, String, int, int) _report(SkipResult r, String input) {
  final ops = <(int, int, String)>[];
  for (final s in r.errorSpans) {
    ops.add((s.pos, s.len, ''));
  }
  for (final m in r.missing) {
    ops.add((m.pos, 0, _spell(m.clause)));
  }
  ops.sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
  final sb = StringBuffer();
  final desc = <String>[];
  var at = 0, destroyed = 0, invented = 0;
  for (final (pos, drop, ins) in ops) {
    if (pos < at) continue;
    sb.write(input.substring(at, pos));
    if (ins.isNotEmpty) {
      sb.write(ins);
      desc.add('ins "$ins" @$pos');
      invented++;
    }
    if (drop > 0) {
      desc.add('del "${input.substring(pos, pos + drop)}" @$pos');
      destroyed += drop;
    }
    at = pos + drop;
  }
  sb.write(input.substring(at));
  return (sb.toString(), desc.join(', '), destroyed, invented);
}

class Arm {
  Arm(this.name, this.recover, this.cost, this.verified);
  final String name;
  final SkipResult Function(String) recover;
  final int Function() cost;
  final bool Function() verified;
  var shape = 0, destroyed = 0, invented = 0, certified = 0;
  var costSum = 0;
}

void main() {
  final (rules, battery, origShape, _, __, ___, ____, _____) = buildSetup();
  final a74 = e74.SuperDot3(rules: rules, topRuleName: 'JSON');
  final afab = efab.SuperDot3(rules: rules, topRuleName: 'JSON');
  final anr = enr.SuperDot3(rules: rules, topRuleName: 'JSON');
  final arms = [
    Arm('m74', a74.recover, () => a74.lastCost, () => a74.lastVerified),
    Arm('fab', afab.recover, () => afab.lastCost, () => afab.lastVerified),
    Arm('nr', anr.recover, () => anr.lastCost, () => anr.lastVerified),
  ];

  // The user's two cases, by construction rather than by hunting for them.
  final probes = <String>[
    // TRANSPOSED base[16..17]: `33,` -> `3,3`, giving `,3true`.
    base.substring(0, 16) + base[17] + base[16] + base.substring(18),
    // DELETED base[13]="2", giving `[,33,`.
    base.substring(0, 13) + base.substring(14),
  ];

  for (final s in battery) {
    for (final arm in arms) {
      final r = arm.recover(s);
      final (_, __, d, i) = _report(r, s);
      if (treeShape(r.root) == origShape) arm.shape++;
      arm.destroyed += d;
      arm.invented += i;
      if (arm.cost() >= 0) arm.costSum += arm.cost();
      if (arm.verified()) arm.certified++;
    }
  }

  stdout.writeln('battery ${battery.length} inputs\n');
  stdout.writeln('arm    shape  costsum  certified  chars destroyed  '
      'chars invented');
  for (final arm in arms) {
    stdout.writeln('${arm.name.padRight(6)} '
        '${arm.shape.toString().padLeft(5)}  '
        '${arm.costSum.toString().padLeft(7)}  '
        '${arm.certified.toString().padLeft(9)}  '
        '${arm.destroyed.toString().padLeft(15)}  '
        '${arm.invented.toString().padLeft(14)}');
  }

  stdout.writeln('\n---- the two cases the user named ----');
  for (final s in probes) {
    stdout.writeln('\nmutant  $s');
    for (final arm in arms) {
      final r = arm.recover(s);
      final (y, desc, _, __) = _report(r, s);
      final ok = treeShape(r.root) == origShape;
      stdout.writeln('  ${arm.name.padRight(4)} cost ${arm.cost()}  $y');
      stdout.writeln('       $desc   ${ok ? "[shape matches original]" : ""}');
    }
  }
}
