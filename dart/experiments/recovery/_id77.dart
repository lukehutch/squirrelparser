// _id77.dart -- I33 is a SECONDARY key, so it must not move a single cost.
// Cost identity against m75 over the battery, the valid controls and the
// latency cases; plus the tree contract (TILES/TOTAL/UNSUPPORTED), because a
// tie-break that changed which repair wins can still break the tree.
import 'dart:io';

import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' show buildSetup, treeShape;
import '_lat72.dart' show latCases;
import 'm75.dart' as a75;
import 'm77.dart' as a77;

class Audit {
  var tiles = true, total = true;
  var unsupported = 0, errNodes = 0, errChars = 0;
}

Parser? oracle;

Audit audit(MatchResult root, int len) {
  final a = Audit();
  final leaves = <(int, int)>[];
  void walk(MatchResult m, int lo, int hi) {
    if (m.pos < 0 || m.len < 0 || m.pos < lo || m.pos + m.len > hi) {
      a.tiles = false;
    }
    if (m is SyntaxError) {
      a.errNodes++;
      a.errChars += m.len;
    }
    final kids = m.subClauseMatches;
    if (kids.isEmpty) {
      if (m.len > 0) leaves.add((m.pos, m.pos + m.len));
      final c = m.clause;
      if (c != null && m is! SyntaxError) {
        final probe = c.match(oracle!, m.pos);
        if (probe.isMismatch || probe.len != m.len) a.unsupported++;
      }
      return;
    }
    var cursor = m.pos;
    for (final k in kids) {
      if (k.pos < cursor) a.tiles = false;
      walk(k, m.pos, m.pos + m.len);
      cursor = k.pos + k.len;
    }
  }

  walk(root, 0, len);
  leaves.sort((x, y) => x.$1 - y.$1);
  var cursor = 0;
  for (final (s, e) in leaves) {
    if (s > cursor) a.total = false;
    if (e > cursor) cursor = e;
  }
  if (cursor < len) a.total = false;
  return a;
}

void main() {
  final (rules, battery, origShape, validDocs, _, __, ___, ____) = buildSetup();
  final e75 = a75.SuperDot3(rules: rules, topRuleName: 'JSON');
  final e76 = a77.SuperDot3(rules: rules, topRuleName: 'JSON');

  final corpora = <String, List<String>>{
    'battery': battery,
    'valid': validDocs,
    'latency': latCases(),
  };

  for (final entry in corpora.entries) {
    var costDiff = 0, treeDiff = 0, certDiff = 0;
    var t75 = 0, t76 = 0, o75 = 0, o76 = 0, sh75 = 0, sh76 = 0;
    var u75 = 0, u76 = 0, ec75 = 0, ec76 = 0, c75 = 0, c76 = 0;
    final samples = <String>[];
    for (final s in entry.value) {
      oracle = Parser(rules: rules, topRuleName: 'JSON', input: s)..parse();
      final k75 = e75.recoverCost(s), k76 = e76.recoverCost(s);
      if (k75 != k76) {
        costDiff++;
        if (samples.length < 8) samples.add('  COST  m75=$k75 m77=$k76  $s');
      }
      final r75 = e75.recover(s), r76 = e76.recover(s);
      if (e75.lastVerified) c75++;
      if (e76.lastVerified) c76++;
      if (e75.lastVerified != e76.lastVerified) certDiff++;
      final a = audit(r75.root, s.length), b = audit(r76.root, s.length);
      if (a.tiles) t75++;
      if (b.tiles) t76++;
      if (a.total) o75++;
      if (b.total) o76++;
      u75 += a.unsupported;
      u76 += b.unsupported;
      ec75 += a.errChars;
      ec76 += b.errChars;
      if (treeShape(r75.root) == origShape) sh75++;
      if (treeShape(r76.root) == origShape) sh76++;
      if (a.errNodes != b.errNodes || a.errChars != b.errChars) treeDiff++;
    }
    final n = entry.value.length;
    stdout.writeln('---- ${entry.key} ($n inputs) ----');
    stdout.writeln('  COST DIFFERENCES m75 vs m77 : $costDiff   '
        '(I33 is a tie-break; this MUST be 0)');
    stdout.writeln('  certified                   : $c75 -> $c76  '
        '(differing: $certDiff)');
    stdout.writeln('  TILES                       : $t75 -> $t76');
    stdout.writeln('  TOTAL                       : $o75 -> $o76');
    stdout.writeln('  UNSUPPORTED nodes           : $u75 -> $u76');
    stdout.writeln('  input chars left with no role: $ec75 -> $ec76');
    stdout.writeln('  trees that differ at all     : $treeDiff');
    if (entry.key == 'battery') {
      stdout.writeln('  SHAPE (see the caveat)      : $sh75 -> $sh76');
    }
    for (final x in samples) {
      stdout.writeln(x);
    }
  }
}
