// _j76.dart -- m76 and m77 on the REAL JSON grammar, correctness columns only.
//
// The 12 false -1 found by _cmp76 are on a synthetic grammar.  Whether they
// reach the grammar the project actually cares about is a separate question, and
// answering it does not need the whole 47-engine table.  `measureOne` is the
// table's own per-engine measurement, so this is the table's instrument rather
// than a second one written to agree with it.
//
// TIMING IS NOT QUOTED FROM HERE: the table gives each engine a cold isolate,
// and this runs two engines warm in one process.  Correctness columns only.
import 'final_table.dart' show measureOne;

void main(List<String> args) {
  for (final name in args.isEmpty ? ['m76', 'm77'] : args) {
    final out = measureOne(name, 'main');
    if (out.isEmpty || out.first != 'OK') {
      print('$name: FAILED -> $out');
      continue;
    }
    print('$name -> ${out.skip(1).join(' | ')}');
  }
}
