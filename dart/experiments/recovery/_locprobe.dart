// _locprobe.dart -- print the LOC column alone, through the table's own code
// path, without running the 120s-per-part sweep.
//
// The rule changed from "the lines between the ERROR RECOVERY markers" to "every
// non-blank, non-comment line of the file", and the markers are gone. This is
// what says the new `_locOf` resolves for all 65 registered engines rather than
// throwing on one of them two hours into a sweep.
import 'dart:io';

import 'final_table.dart' show engines;

void main() {
  final rows = [for (final e in engines) (e.name, e.loc)]
    ..sort((a, b) => a.$2 - b.$2);
  for (final (name, loc) in rows) {
    stdout.writeln('${name.padRight(8)} $loc');
  }
  stdout.writeln('${rows.length} engines, min ${rows.first.$2}, '
      'max ${rows.last.$2}');
}
