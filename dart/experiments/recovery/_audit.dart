// _audit.dart -- what is actually IN each category of the AST-diff battery.
// A category that scores 1.000 is either a solved problem or a vacuous one, and
// the only way to tell is to look at the cases.
import 'astdiff.dart';

void main() {
  final all = buildBattery();
  final byCat = <String, List<Case>>{};
  for (final c in all) {
    byCat.putIfAbsent(c.category, () => []).add(c);
  }
  final keys = byCat.keys.toList()
    ..sort((a, b) => byCat[b]!.length.compareTo(byCat[a]!.length));
  print('raw battery: ${all.length} cases in ${keys.length} categories\n');
  for (final k in keys) {
    final cs = byCat[k]!;
    // How many DISTINCT documents and corpora does the category cover, and how
    // many distinct characters does the damage involve? A category built from
    // one character is measuring one thing.
    final corp = cs.map((c) => c.grammar).toSet();
    final docs = cs.map((c) => c.original).toSet();
    final chars = <String>{};
    for (final c in cs) {
      // The characters present in the mutant but not the original, and vice
      // versa -- a cheap signature of what the damage touched.
      final a = c.original.split('')..sort();
      final b = c.mutant.split('')..sort();
      final ma = <String, int>{}, mb = <String, int>{};
      for (final x in a) {
        ma[x] = (ma[x] ?? 0) + 1;
      }
      for (final x in b) {
        mb[x] = (mb[x] ?? 0) + 1;
      }
      for (final e in mb.entries) {
        if ((ma[e.key] ?? 0) < e.value) chars.add('+${e.key}');
      }
      for (final e in ma.entries) {
        if ((mb[e.key] ?? 0) < e.value) chars.add('-${e.key}');
      }
    }
    final sig = chars.toList()..sort();
    print('${k.padRight(16)} ${cs.length.toString().padLeft(5)}  '
        'weight ${categoryWeight[k]}  corpora ${corp.length}  docs ${docs.length}');
    print('    damage alphabet (${sig.length}): ${sig.join(' ')}');
    for (final c in cs.take(3)) {
      print('    ${c.grammar}: ${c.original}');
      print('        ->   ${c.mutant}');
    }
    print('');
  }
}
