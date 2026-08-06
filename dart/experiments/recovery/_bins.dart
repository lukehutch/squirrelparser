// _bins.dart -- _bseq's question for the in-place ordered insert.
//
// Under I30 the enumeration order IS the tie-break rule, so ANY change to the
// entry list is a change to the LANGUAGE, not an optimisation to be waved
// through on a cost gate. `_m72ins` claims to build the identical list with no
// temp-list allocation, so it must produce the identical WITNESS -- cost,
// certificate, spans, missing set and tree shape -- on every input, and cost
// identity alone would not show it (that lesson is already paid for).
import 'final_table.dart' show buildSetup, treeShape;
import 'm72.dart' as a;
import '_m72ins.dart' as b;

String sig(dynamic eng, String s) {
  try {
    final r = eng.recover(s);
    final spans = [for (final e in r.errors) '${e.pos}+${e.len}'].join(',');
    final miss = [for (final m in r.missing) '$m'].join(',');
    return '${eng.lastCost}|${eng.lastVerified}|$spans|$miss|'
        '${treeShape(r.tree)}|${r.recoveryEvents}|${r.failed}';
  } catch (e) {
    return 'THREW:$e';
  }
}

void main() {
  final (rules, battery, _, validDocs, latCases, _, _, _) = buildSetup();
  final inputs = <String>[...battery, ...validDocs, ...latCases];
  final ea = a.SuperDot3(rules: rules, topRuleName: 'JSON');
  final eb = b.SuperDot3(rules: rules, topRuleName: 'JSON');
  var costDiff = 0, fullDiff = 0;
  for (final s in inputs) {
    if (ea.recoverCost(s) != eb.recoverCost(s)) costDiff++;
    if (sig(ea, s) != sig(eb, s)) {
      fullDiff++;
      if (fullDiff <= 3) print('  DIFF on "$s"\n    m72 ${sig(ea, s)}\n    ins ${sig(eb, s)}');
    }
  }
  print('${inputs.length} checked, $costDiff cost differences, '
      '$fullDiff full-result differences');
}
