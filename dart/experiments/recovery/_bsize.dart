import 'astdiff.dart';
void main() {
  final b = buildBattery();
  final w = weighted(b);
  print('battery ${b.length}  weighted ${w.length}');
  final byCat = <String, int>{};
  for (final c in b) { byCat[c.category] = (byCat[c.category] ?? 0) + 1; }
  final ks = byCat.keys.toList()..sort();
  for (final k in ks) { print('  $k ${byCat[k]}'); }
}
