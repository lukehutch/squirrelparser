// _fabdiff.dart -- every battery input where the FAB price changes the answer,
// scored on the document each engine actually produces.
//
// The first version of this harness rebuilt the repaired document from
// `SkipResult`, and that was wrong: `recover()` reports a SUBSTITUTION as a bare
// deletion span (m74.dart:1033-1038 keeps `pos` and `drop` and throws the
// replacement text away), so a repair that swaps one character for another reads
// as pure destruction. These arms expose the engine's OWN `_repaired()` string
// instead, which is the string it certified by re-parsing.
//
// Three columns per input: the certified document, how many input characters it
// drops, and whether it is byte-for-byte the document the battery was corrupted
// from. That last column is the one the `shape` gate is a proxy for -- and the
// proxy is loose enough to score `te` and `true` the same.
import 'dart:io';

import 'final_table.dart' show buildSetup, treeShape;
import '_m74w.dart' as e74;
import '_m74fabw.dart' as efab;

const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';

/// Characters of `input` that do not survive into `y`, by longest common
/// subsequence: the edit list is the engine's business, this is the outcome.
int _dropped(String input, String y) {
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

void main() {
  final (rules, battery, origShape, _, __, ___, ____, _____) = buildSetup();
  final a74 = e74.SuperDot3(rules: rules, topRuleName: 'JSON');
  final afab = efab.SuperDot3(rules: rules, topRuleName: 'JSON');

  var differ = 0, only74 = 0, onlyFab = 0, same = 0;
  var exact74 = 0, exactFab = 0, drop74 = 0, dropFab = 0;
  final lines = <String>[];
  for (final s in battery) {
    final r74 = a74.recover(s);
    final rfab = afab.recover(s);
    final y74 = a74.lastRepairedDoc, yfab = afab.lastRepairedDoc;
    final d74 = _dropped(s, y74), dfab = _dropped(s, yfab);
    drop74 += d74;
    dropFab += dfab;
    if (y74 == base) exact74++;
    if (yfab == base) exactFab++;
    if (y74 == yfab) continue;
    differ++;
    final ok74 = treeShape(r74.root) == origShape;
    final okfab = treeShape(rfab.root) == origShape;
    if (ok74 && !okfab) {
      only74++;
    } else if (okfab && !ok74) {
      onlyFab++;
    } else {
      same++;
    }
    final tag = ok74 == okfab
        ? (ok74 ? 'shape: both ok' : 'shape: neither')
        : (ok74 ? 'shape: ONLY m74' : 'shape: ONLY fab');
    lines.add('mutant $s\n'
        '  m74 $y74  drop $d74${y74 == base ? "  == ORIGINAL" : ""}\n'
        '  fab $yfab  drop $dfab${yfab == base ? "  == ORIGINAL" : ""}'
        '   $tag');
  }

  stdout.writeln('battery ${battery.length} inputs\n');
  stdout.writeln('                        m74     fab');
  stdout.writeln('certified == original  ${exact74.toString().padLeft(4)}    '
      '${exactFab.toString().padLeft(4)}');
  stdout.writeln('input chars dropped    ${drop74.toString().padLeft(4)}    '
      '${dropFab.toString().padLeft(4)}');
  stdout.writeln('\ncertified document differs on $differ inputs:');
  stdout.writeln('  only m74 matches the original tree shape: $only74');
  stdout.writeln('  only fab matches the original tree shape: $onlyFab');
  stdout.writeln('  shape verdict identical:                  $same\n');
  for (final l in lines) {
    stdout.writeln(l);
  }
}
