// _regretwhy.dart -- WHAT does deleting regret change, case by case?
//
// `_nr74` already showed the aggregate: cost and certification bit-identical,
// shape 517 -> 488. Aggregates do not say what a caller would see. This walks
// the same 519-mutant battery, keeps every input whose recovered TREE SHAPE
// differs between m74 and the regret-deleted control, and prints the edit list
// each engine chose next to the mutation that was actually applied.
//
// Each battery input is `base` with exactly one character deleted, transposed,
// inserted or substituted, so the repair the author would want is the one that
// undoes that mutation -- and `origShape` is that document's tree shape.
import 'dart:io';

import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/recovery/skip_recovery.dart'
    show SkipResult;

import 'final_table.dart' show buildSetup, treeShape;
import 'm74.dart' as e74;
import '_m74nr.dart' as enr;

const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';

/// The engine picks the spelling itself; naming the CLAUSE avoids inventing a
/// character it would not have chosen. `[]` marks the insertion point.
String _spell(Clause c) => '[$c]';

/// The edit list a caller receives, rendered as the repaired string.
(String, String) _report(SkipResult r, String input) {
  final ops = <(int, int, String)>[]; // (pos, drop, insert)
  for (final s in r.errorSpans) {
    ops.add((s.pos, s.len, ''));
  }
  for (final m in r.missing) {
    ops.add((m.pos, 0, _spell(m.clause)));
  }
  ops.sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
  final sb = StringBuffer();
  final desc = <String>[];
  var at = 0;
  for (final (pos, drop, ins) in ops) {
    if (pos < at) continue; // overlapping report; render what we can
    sb.write(input.substring(at, pos));
    if (ins.isNotEmpty) {
      sb.write(ins);
      desc.add('ins "$ins" @$pos');
    }
    if (drop > 0) {
      desc.add('del "${input.substring(pos, pos + drop)}" @$pos');
    }
    at = pos + drop;
  }
  sb.write(input.substring(at));
  return (sb.toString(), desc.join(', '));
}

/// How this battery input differs from `base`, in the mutation's own terms.
String _mutation(String m) {
  if (m.length == base.length - 1) {
    for (var i = 0; i < m.length; i++) {
      if (m[i] != base[i]) return 'DELETED base[$i]="${base[i]}"';
    }
    return 'DELETED base[${m.length}]="${base[m.length]}"';
  }
  if (m.length == base.length + 1) {
    for (var i = 0; i < base.length; i++) {
      if (m[i] != base[i]) return 'INSERTED "${m[i]}" at $i';
    }
    return 'INSERTED "${m[base.length]}" at ${base.length}';
  }
  for (var i = 0; i < base.length; i++) {
    if (m[i] != base[i]) {
      if (i + 1 < base.length && m[i] == base[i + 1] && m[i + 1] == base[i]) {
        return 'TRANSPOSED base[$i..${i + 1}]="${base.substring(i, i + 2)}"';
      }
      return 'SUBSTITUTED base[$i]="${base[i]}" -> "${m[i]}"';
    }
  }
  return 'unchanged?';
}

void main() {
  final (rules, battery, origShape, _, __, ___, ____, _____) = buildSetup();
  final a = e74.SuperDot3(rules: rules, topRuleName: 'JSON');
  final b = enr.SuperDot3(rules: rules, topRuleName: 'JSON');

  var diffs = 0, aRight = 0, bRight = 0, costDiff = 0;
  final byKind = <String, int>{};
  final shown = <String>[];

  for (final s in battery) {
    final ra = a.recover(s), ca = a.lastCost;
    final rb = b.recover(s), cb = b.lastCost;
    if (ca != cb) costDiff++;
    final sa = treeShape(ra.root) == origShape;
    final sb2 = treeShape(rb.root) == origShape;
    if (sa) aRight++;
    if (sb2) bRight++;
    if (sa == sb2) continue;
    diffs++;
    final kind = _mutation(s).split(' ').first;
    byKind['$kind ${sa ? "m74-only" : "nr-only"}'] =
        (byKind['$kind ${sa ? "m74-only" : "nr-only"}'] ?? 0) + 1;
    if (shown.length < 12) {
      final (ya, da) = _report(ra, s);
      final (yb, db) = _report(rb, s);
      shown.add('''
mutant   $s
         ${_mutation(s)}   (cost $ca both)
m74  ->  $ya
         $da   ${sa ? "*** restores the original ***" : "(different document)"}
nr   ->  $yb
         $db   ${sb2 ? "*** restores the original ***" : "(different document)"}
''');
    }
  }

  stdout.writeln('base     $base');
  stdout.writeln('battery  ${battery.length} inputs, cost differences $costDiff');
  stdout.writeln('shape    m74 $aRight   no-regret $bRight   differing $diffs');
  stdout.writeln('\nby mutation kind:');
  final keys = byKind.keys.toList()..sort();
  for (final k in keys) {
    stdout.writeln('  ${k.padRight(24)} ${byKind[k]}');
  }
  stdout.writeln('\n---- first ${shown.length} differing cases ----\n');
  for (final s in shown) {
    stdout.writeln(s);
  }
}
