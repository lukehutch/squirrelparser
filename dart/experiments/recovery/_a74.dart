// _a74.dart -- does m74 answer as m73 does, and is its witness real?
//
// m74 replaces `_build`+`_emit`+`_verify` with I31's chase-splice-reparse, so
// the two things to check are (a) the COST is unchanged on every gate input,
// and (b) the SkipResult it hands back still tiles the input and re-parses.
// (b) is the part `_build` used to guarantee by construction; here it is a
// property of the map `_xOf`, so it wants a test rather than an argument.
import 'dart:io';

import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' show buildSetup;
import 'm73.dart' as e73;
import 'm74.dart' as e74;

int _leaves(MatchResult m, int want, List<String> bad) {
  var cursor = 0;
  void walk(MatchResult n) {
    if (n.subClauseMatches.isEmpty) {
      if (n.len == 0) return;
      if (n.pos != cursor) bad.add('gap ${n.pos} != $cursor');
      cursor = n.pos + n.len;
      return;
    }
    n.subClauseMatches.forEach(walk);
  }
  walk(m);
  if (cursor != want) bad.add('end $cursor != $want');
  return cursor;
}

void main() {
  final (rules, battery, _, _, latCases, _, _, _) = buildSetup();
  final all = <String>[...battery, ...latCases];
  final a = e73.SuperDot3(rules: rules, topRuleName: 'JSON');
  final b = e74.SuperDot3(rules: rules, topRuleName: 'JSON');
  var diff = 0, cert = 0, badTree = 0, spans = 0, miss = 0;
  final examples = <String>[];
  for (final s in all) {
    final ca = a.recoverCost(s), cb = b.recoverCost(s);
    if (ca != cb) {
      diff++;
      if (examples.length < 5) examples.add('cost $ca vs $cb on ${s.length}ch');
    }
    if (b.lastVerified) cert++;
    if (cb > 0 && b.lastVerified) {
      final r = b.recover(s);
      final bad = <String>[];
      _leaves(r.root, s.length, bad);
      if (r.root.len != s.length) bad.add('root ${r.root.len} != ${s.length}');
      if (bad.isNotEmpty) {
        badTree++;
        if (examples.length < 8) examples.add('tree ${bad.first}');
      }
      spans += r.errorSpans.length;
      miss += r.missing.length;
    }
  }
  stdout.writeln('inputs ${all.length}  cost-diffs $diff  certified $cert'
      '  bad-trees $badTree  spans $spans  missing $miss');
  for (final e in examples) {
    stdout.writeln('  $e');
  }
}
