// _bcheck.dart -- battery composition only; no engine is run.
import 'astdiff.dart';

void main() {
  final all = buildBattery();
  final w = weighted(all);
  for (final (label, list) in [('raw', all), ('weighted', w)]) {
    final byCat = <String, int>{}, byCorp = <String, int>{};
    for (final c in list) {
      byCat[c.category] = (byCat[c.category] ?? 0) + 1;
      byCorp[c.grammar] = (byCorp[c.grammar] ?? 0) + 1;
    }
    final cats = byCat.keys.toList()
      ..sort((a, b) => categoryWeight[b]!.compareTo(categoryWeight[a]!));
    print('=== $label: ${list.length} cases ===');
    for (final k in cats) {
      print('  ${k.padRight(16)}${byCat[k].toString().padLeft(5)}'
          '   weight ${categoryWeight[k]}');
    }
    print('  by corpus: $byCorp');
  }
}
