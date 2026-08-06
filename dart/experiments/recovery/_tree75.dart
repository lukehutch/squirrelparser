// _tree75.dart -- does m75's tree obey the contract the brief states?
//
//   "the repaired string should not insert nodes into the AST that aren't
//    actually supported by the input -- instead, syntax error spans should be
//    inserted into the actual AST nodes in the memo table ... FIX THE SHAPE OF
//    RECURSIVE DESCENT only ... without changing the input"
//
// Four things have to hold, and each is checkable rather than arguable:
//
//   TILES     every node's span lies inside [0, input.length), children are in
//             order, disjoint, and inside the parent. A node that covered a
//             fabricated character could not satisfy this, because there is no
//             coordinate in the input for it to sit at.
//   TOTAL     every input character lies under some node. Nothing is silently
//             dropped on the floor: a character the grammar could not use is
//             still in the tree, inside a SyntaxError span.
//   FLAGGED   every repair leaves a mark in the tree -- a wide span where input
//             went unused, a zero-width one where the grammar went unfilled.
//   SHAPE     the structural Ref nesting still matches the pre-corruption
//             document's. `treeShape` walks through clause-less nodes, so error
//             spans neither help nor hurt it; this measures the recursion shape
//             alone, which is what the brief asks recovery to fix.
//
// m74 is scored on TILES/TOTAL too, over the SAME input, to show what the old
// contract did: its tree is indexed by the repaired string, so its spans are in
// the wrong coordinate system as soon as a repair changes any length.
import 'dart:io';

import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' show buildSetup, treeShape;
import 'm74.dart' as e74;
import 'm75.dart' as e75;

const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';

class Audit {
  var tiles = true, total = true;
  var unsupported = 0;
  var errNodes = 0, errChars = 0, maxEnd = 0;
  final gaps = <(int, int)>[];
}

/// Walk the tree once, checking containment and ordering, and collecting the
/// intervals the leaves cover so gaps can be found.
Parser? oracle;

Audit audit(MatchResult root, int len) {
  final a = Audit();
  final leaves = <(int, int)>[];
  void walk(MatchResult m, int lo, int hi) {
    if (m.pos < 0 || m.len < 0 || m.pos < lo || m.pos + m.len > hi) {
      a.tiles = false;
    }
    if (m.pos + m.len > a.maxEnd) a.maxEnd = m.pos + m.len;
    if (m is SyntaxError) {
      a.errNodes++;
      a.errChars += m.len;
    }
    final kids = m.subClauseMatches;
    if (kids.isEmpty) {
      if (m.len > 0) leaves.add((m.pos, m.pos + m.len));
      // The brief's rule, made checkable: a node may only claim text the
      // ORIGINAL input actually supplies. Put the leaf's own clause back to the
      // pure parser at the leaf's own position, over the untouched input. If it
      // does not read exactly that span, the node is asserting something the
      // document never said.
      final c = m.clause;
      if (c != null && m is! SyntaxError) {
        final probe = c.match(oracle!, m.pos);
        if (probe.isMismatch || probe.len != m.len) a.unsupported++;
      }
      return;
    }
    var cursor = m.pos;
    for (final k in kids) {
      if (k.pos < cursor) a.tiles = false; // out of order, or overlapping
      walk(k, m.pos, m.pos + m.len);
      cursor = k.pos + k.len;
    }
  }

  walk(root, 0, len);
  leaves.sort((x, y) => x.$1 - y.$1);
  var cursor = 0;
  for (final (s, e) in leaves) {
    if (s > cursor) {
      a.gaps.add((cursor, s));
      a.total = false;
    }
    if (e > cursor) cursor = e;
  }
  if (cursor < len) {
    a.gaps.add((cursor, len));
    a.total = false;
  }
  return a;
}

String render(MatchResult m, String input, [int d = 0]) {
  final pad = '  ' * d;
  final sb = StringBuffer();
  final c = m.clause;
  if (m is SyntaxError) {
    sb.writeln(m.len == 0
        ? '$pad<missing> at ${m.pos}'
        : '$pad<error "${input.substring(m.pos, m.pos + m.len)}">');
  } else {
    final name = c is Ref ? c.ruleName : (c?.runtimeType.toString() ?? '.');
    sb.write('$pad$name');
    sb.writeln(m.subClauseMatches.isEmpty
        ? ' "${input.substring(m.pos, m.pos + m.len)}"'
        : '');
  }
  for (final k in m.subClauseMatches) {
    sb.write(render(k, input, d + 1));
  }
  return sb.toString();
}

void main() {
  final (rules, battery, origShape, _, __, ___, ____, _____) = buildSetup();
  final a75 = e75.SuperDot3(rules: rules, topRuleName: 'JSON');
  final a74 = e74.SuperDot3(rules: rules, topRuleName: 'JSON');

  var tiles75 = 0, total75 = 0, shape75 = 0, flagged75 = 0, cert75 = 0;
  var tiles74 = 0, total74 = 0, shape74 = 0, cert74 = 0;
  var errNodes = 0;
  final breaches = <String>[];

  var unsup75 = 0, unsup74 = 0, errChars75 = 0;
  for (final s in battery) {
    oracle = Parser(rules: rules, topRuleName: 'JSON', input: s)..parse();
    final r75 = a75.recover(s);
    final u = audit(r75.root, s.length);
    unsup75 += u.unsupported;
    errChars75 += u.errChars;
    if (u.tiles) tiles75++;
    if (u.total) total75++;
    if (u.errNodes > 0 || a75.lastCost == 0) flagged75++;
    if (a75.lastVerified) cert75++;
    errNodes += u.errNodes;
    if (treeShape(r75.root) == origShape) shape75++;
    if ((!u.tiles || !u.total) && breaches.length < 6) {
      breaches.add('  $s  tiles=${u.tiles} total=${u.total} '
          'maxEnd=${u.maxEnd}/${s.length} gaps=${u.gaps}');
    }

    final r74 = a74.recover(s);
    final v = audit(r74.root, s.length);
    unsup74 += v.unsupported;
    if (v.tiles) tiles74++;
    if (v.total) total74++;
    if (a74.lastVerified) cert74++;
    if (treeShape(r74.root) == origShape) shape74++;
  }

  final n = battery.length;
  stdout.writeln('battery $n inputs, all corrupted from one document\n');
  stdout.writeln('engine  certified   TILES   TOTAL   SHAPE   FLAGGED'
      '   UNSUPPORTED nodes');
  stdout.writeln('m74   ${cert74.toString().padLeft(10)}'
      '${tiles74.toString().padLeft(8)}${total74.toString().padLeft(8)}'
      '${shape74.toString().padLeft(8)}${"-".padLeft(10)}'
      '${unsup74.toString().padLeft(19)}');
  stdout.writeln('m75   ${cert75.toString().padLeft(10)}'
      '${tiles75.toString().padLeft(8)}${total75.toString().padLeft(8)}'
      '${shape75.toString().padLeft(8)}${flagged75.toString().padLeft(10)}'
      '${unsup75.toString().padLeft(19)}');
  stdout.writeln('\nerror nodes placed in m75 trees: $errNodes, '
      'covering $errChars75 input characters of '
      '${battery.fold<int>(0, (a, s) => a + s.length)} '
      '(the rest were given a role by the grammar)');
  if (breaches.isNotEmpty) {
    stdout.writeln('\nm75 contract breaches (first ${breaches.length}):');
    for (final b in breaches) {
      stdout.writeln(b);
    }
  }

  // Where m74 wins SHAPE and m75 does not: is m74's win bought with nodes the
  // input never supported? If it is, then SHAPE is scoring the very thing the
  // brief forbids, and 474 is the price of the rule rather than a regression.
  var only74 = 0, only74Invented = 0, only75 = 0;
  final samples = <String>[];
  for (final s in battery) {
    oracle = Parser(rules: rules, topRuleName: 'JSON', input: s)..parse();
    final ok75 = treeShape(a75.recover(s).root) == origShape;
    final r74 = a74.recover(s);
    final v = audit(r74.root, s.length);
    final ok74 = treeShape(r74.root) == origShape;
    if (ok74 == ok75) continue;
    if (ok75) {
      only75++;
      continue;
    }
    only74++;
    if (v.unsupported > 0) only74Invented++;
    if (samples.length < 5) {
      samples.add('  $s\n    m74 gets the shape with ${v.unsupported} '
          'node(s) the input does not support');
    }
  }
  stdout.writeln('\n---- the SHAPE gap, examined ----');
  stdout.writeln('inputs where only m74 matches the original shape: $only74');
  stdout.writeln('  ...of those, m74 invented at least one node: '
      '$only74Invented');
  stdout.writeln('inputs where only m75 matches: $only75');
  for (final x in samples) {
    stdout.writeln(x);
  }

  // The three repairs the brief singled out.
  final probes = <String>[
    base.replaceFirst('true', 'ture'),
    base.replaceFirst('"a":1', '"a":"1'),
    base.replaceFirst('"a":1', '"a":'),
  ];
  stdout.writeln('\n---- the three repairs named in the brief ----');
  for (final s in probes) {
    final r = a75.recover(s);
    final u = audit(r.root, s.length);
    stdout.writeln('\ninput  $s');
    stdout.writeln('m75 cost ${a75.lastCost} verified ${a75.lastVerified}  '
        'tiles=${u.tiles} total=${u.total} errNodes=${u.errNodes}');
    oracle = Parser(rules: rules, topRuleName: 'JSON', input: s)..parse();
    final tree = render(r.root, s);
    final keep = tree
        .split('\n')
        .where((l) => l.contains('error') || l.contains('missing'))
        .toList();
    stdout.writeln('  error spans in the tree: '
        '${keep.isEmpty ? "(none)" : ""}');
    for (final k in keep) {
      stdout.writeln('  ${k.trim()}');
    }
    stdout.writeln('  shape matches original: '
        '${treeShape(r.root) == origShape}');
  }
}
