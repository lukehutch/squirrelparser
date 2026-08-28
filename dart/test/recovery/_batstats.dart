// _batstats.dart -- what the battery generator produces vs what the scored
// battery holds, so the paper can state the sampling honestly.
import 'astdiff.dart';

void main() {
  final raw = buildBattery();
  final kept = weighted(raw);
  void tally(String label, List<Case> cs) {
    final byCat = <String, int>{}, byGram = <String, int>{};
    for (final c in cs) {
      byCat[c.category] = (byCat[c.category] ?? 0) + 1;
      byGram[c.grammar] = (byGram[c.grammar] ?? 0) + 1;
    }
    final cats = byCat.keys.toList()
      ..sort((a, b) => categoryWeight[b]!.compareTo(categoryWeight[a]!));
    print('$label total=${cs.length}');
    for (final k in cats) {
      final per = (byCat[k]! / categoryWeight[k]!);
      print('  $k weight=${categoryWeight[k]} n=${byCat[k]} '
          'per-unit=${per.toStringAsFixed(1)}');
    }
    print('  by grammar: $byGram');
  }

  tally('generated', raw);
  tally('scored   ', kept);
}
