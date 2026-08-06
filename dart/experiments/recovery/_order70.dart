// _order70.dart -- the tape's work is a WALK over a prefix trie. How much does
// the order it walks in cost?
//
// `_incr70.dart` measured that re-parsing y given its parent's parse is 7-10x
// cheaper than parsing y from nothing at realistic length, but that jumping
// between unrelated prefixes is only ~2x cheaper. Dijkstra pops in cost order,
// which is not trie order, so it jumps.
//
// This replays the tape's ACTUAL classification sequence on the real latency
// cases and prices three orders by the characters that must be re-parsed:
//
//   FRESH      sum |y|                         -- parse every candidate whole
//   AS-IS      sum |y| - lcp(y_i, y_{i-1})     -- reuse, in the order it asks
//   TRIE       sum |y| - lcp(y_i, prev in sorted order)  -- the best any order
//                                                 can do, since the trie's edge
//                                                 count is a lower bound
//
// AS-IS/FRESH is what an LCP cache buys today. TRIE/FRESH is what it buys if
// the drain order is changed -- and by I21 (m65's own result: the layer is the
// answer, the tie is only a ranking) reordering WITHIN a cost layer is free.
import 'dart:math';

import 'package:squirrel_parser/squirrel_parser.dart';
import '_tapeprobe.dart' as tape;

const String jsonGrammar = '''
JSON <- WS Value WS;
Value <- Object / Array / String / Number / Boolean / Null;
Object <- '{' WS (Member (WS ',' WS Member)*)? WS '}';
Member <- String WS ':' WS Value;
Array <- '[' WS (Value (WS ',' WS Value)*)? WS ']';
String <- '"' Character* '"';
Character <- [^"\\\\] / ('\\\\' Escape);
Escape <- '"' / '\\\\' / '/' / 'b' / 'f' / 'n' / 'r' / 't' / ('u' [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F]);
Number <- Integer Fraction? Exponent?;
Integer <- '-'? (([1-9] [0-9]+) / [0-9]);
Fraction <- '.' [0-9]+;
Exponent <- ("e" / "E") ("+" / "-")? [0-9]+;
Boolean <- "true" / "false";
Null <- "null";
~WS <- [ \\t\\n\\r]*;
''';

int lcp(String a, String b) {
  final n = min(a.length, b.length);
  var i = 0;
  while (i < n && a.codeUnitAt(i) == b.codeUnitAt(i)) {
    i++;
  }
  return i;
}

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);

  // The latency cases, verbatim from final_table.dart's buildSetup.
  final big = '{"users":[{"id":1,"name":"ann","tags":["x","y"]},'
      '{"id":2,"name":"bob","tags":["z"]},{"id":3,"name":"cyd","tags":[]}],'
      '"total":3,"ok":true}';
  final latCases = <String>[];
  for (final k in [4, 16, 64]) {
    latCases.add(big.substring(0, 30) + big.substring(30 + k));
    latCases.add(big.substring(0, 30) + ('@' * k) + big.substring(30));
    final ch = big.substring(30, 30 + k).split('')..shuffle(Random(12345 + k));
    latCases.add(big.substring(0, 30) + ch.join() + big.substring(30 + k));
  }
  for (final k in [4, 16, 64]) {
    final it = [for (var i = 0; i < k; i++) '{"id":$i,"name":"n$i","ok":true}'];
    final d = '{"items":[${it.join(',')}],"total":$k}';
    final mid = d.length ~/ 2;
    latCases.add('${d.substring(0, mid)}Q${d.substring(mid + 1)}');
  }

  // The tape has no fast path, so the k=16 and k=64 latency cases take minutes
  // each -- which is exactly why m63/m65 are `TO` in the table. The k=4 family
  // is the same shape at a size that finishes; pass indices on the command line
  // to price a bigger one.
  final pick = <int>[0, 1, 2, 9];

  print('case  inLen  classif   fresh_ch    asis_ch    trie_ch  '
      'asis/fresh  trie/fresh  trie/asis');
  var tf = 0, ta = 0, tt = 0, tc = 0;

  for (final c in pick) {
    final s = latCases[c];
    tape.SuperDot3.seq.clear();
    final e = tape.SuperDot3(rules: rules, topRuleName: 'JSON');
    final sw = Stopwatch()..start();
    e.recoverCost(s);
    sw.stop();

    final seq = List<String>.of(tape.SuperDot3.seq);
    if (seq.isEmpty) {
      print('${c.toString().padLeft(4)} ${s.length.toString().padLeft(6)} '
          '${'0'.padLeft(8)}   (tape never reached)');
      continue;
    }

    var fresh = 0, asis = 0;
    var prev = '';
    for (final y in seq) {
      fresh += y.length;
      asis += y.length - lcp(y, prev);
      prev = y;
    }

    // Trie order: sort, then each string costs only what it adds to its
    // predecessor. This is exactly the trie's edge count over the visited set,
    // and no visiting order can beat it.
    final sorted = List<String>.of(seq)..sort();
    var trie = 0;
    prev = '';
    for (final y in sorted) {
      trie += y.length - lcp(y, prev);
      prev = y;
    }

    tf += fresh;
    ta += asis;
    tt += trie;
    tc += seq.length;
    print('${c.toString().padLeft(4)} ${s.length.toString().padLeft(6)} '
        '${seq.length.toString().padLeft(8)} ${fresh.toString().padLeft(10)} '
        '${asis.toString().padLeft(10)} ${trie.toString().padLeft(10)} '
        '${(asis / fresh).toStringAsFixed(3).padLeft(11)} '
        '${(trie / fresh).toStringAsFixed(3).padLeft(11)} '
        '${(trie / asis).toStringAsFixed(3).padLeft(10)}');
  }

  if (tc > 0) {
    print('');
    print('TOTAL classifications=$tc  fresh=$tf  asis=$ta  trie=$tt');
    print('  an LCP cache in the order Dijkstra asks : '
        '${(tf / ta).toStringAsFixed(1)}x fewer characters');
    print('  the same cache walked in trie order     : '
        '${(tf / tt).toStringAsFixed(1)}x fewer characters');
    print('  what reordering is worth                : '
        '${(ta / tt).toStringAsFixed(1)}x');
  }
}
