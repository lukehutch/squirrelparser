// Scratch: WHERE DOES THE WORK STOP SCALING WITH THE INPUT?
//
// The battery says nothing about asymptotics: every case in it is short. This
// runs one grammar over inputs that double in length and reports the empirical
// exponent between consecutive sizes, log2(t(2n)/t(n)). 1.0 is linear, 2.0
// quadratic, 3.0 cubic. A shape whose exponent climbs with n is worse than the
// last pair of measurements says.
//
//   dart run _scale.dart            all shapes, clean + one error
//   dart run _scale.dart <shape>    just one

import 'dart:math' as math;

import 'package:squirrel_parser/squirrel_parser.dart';

import '_v23.dart' as e;

typedef Shape = ({String name, String grammar, String top, String Function(int) gen});

final shapes = <Shape>[
  // A flat list -- the commonest real shape, and the one the chart's ways list
  // is widest on, because `Item*` can stop at every item boundary.
  (
    name: 'list',
    grammar: 'S <- Item (Comma Item)*; Item <- [a-z]+; Comma <- \',\';',
    top: 'S',
    gen: (n) => List.generate(n, (i) => String.fromCharCode(97 + i % 26)).join(','),
  ),
  // The same, with one character that cannot be read where it stands.
  (
    name: 'list-err',
    grammar: 'S <- Item (Comma Item)*; Item <- [a-z]+; Comma <- \',\';',
    top: 'S',
    gen: (n) {
      final s = List.generate(n, (i) => String.fromCharCode(97 + i % 26)).join(',');
      final k = s.length ~/ 2;
      return '${s.substring(0, k)}#${s.substring(k + 1)}';
    },
  ),
  // A repetition of a two-slot sequence: every iteration is a Seq whose second
  // slot is asked at every end the first slot reached.
  (
    name: 'rep-seq',
    grammar: 'S <- (A B)*; A <- \'a\'; B <- \'b\';',
    top: 'S',
    gen: (n) => 'ab' * (n ~/ 2),
  ),
  (
    name: 'rep-seq-err',
    grammar: 'S <- (A B)*; A <- \'a\'; B <- \'b\';',
    top: 'S',
    gen: (n) {
      final s = 'ab' * (n ~/ 2);
      final k = s.length ~/ 2;
      return '${s.substring(0, k)}#${s.substring(k + 1)}';
    },
  ),
  // A repetition of an ordered choice -- the widest cell in the chart, since
  // both arms offer an end at every position.
  (
    name: 'rep-first',
    grammar: 'S <- (A / B)*; A <- \'a\'; B <- \'b\';',
    top: 'S',
    gen: (n) => List.generate(n, (i) => i % 3 == 0 ? 'b' : 'a').join(),
  ),
  (
    name: 'rep-first-err',
    grammar: 'S <- (A / B)*; A <- \'a\'; B <- \'b\';',
    top: 'S',
    gen: (n) {
      final s = List.generate(n, (i) => i % 3 == 0 ? 'b' : 'a').join();
      final k = s.length ~/ 2;
      return '${s.substring(0, k)}#${s.substring(k + 1)}';
    },
  ),
  // Left recursion: the fixed-point loop runs once per iteration it discovers.
  (
    name: 'left-rec',
    grammar: 'E <- E Plus T / T; T <- [0-9]; Plus <- \'+\';',
    top: 'E',
    gen: (n) => List.generate(n ~/ 2, (i) => '${i % 10}').join('+'),
  ),
  (
    name: 'left-rec-err',
    grammar: 'E <- E Plus T / T; T <- [0-9]; Plus <- \'+\';',
    top: 'E',
    gen: (n) {
      final s = List.generate(n ~/ 2, (i) => '${i % 10}').join('+');
      final k = s.length ~/ 2;
      return '${s.substring(0, k)}#${s.substring(k + 1)}';
    },
  ),
  // Nesting: the same construct at every level, so a cell at the outside
  // depends on a cell one position in, all the way down.
  (
    name: 'nest',
    grammar: 'S <- Open S Close / Leaf; Leaf <- \'x\'; Open <- \'(\'; Close <- \')\';',
    top: 'S',
    gen: (n) => '(' * (n ~/ 2) + 'x' + ')' * (n ~/ 2 - 1),
  ),
  // A sequence of many slots -- does the slot count multiply the width?
  (
    name: 'seq-deep',
    grammar: 'S <- W W W W W W W W; W <- [a-z]*;',
    top: 'S',
    gen: (n) => List.generate(n, (i) => String.fromCharCode(97 + i % 26)).join(),
  ),
];

void main(List<String> argv) {
  final want = argv.isEmpty ? null : argv.first;
  final sizes = [16, 32, 64, 128, 256, 512, 1024, 2048];
  print('shape             n     ms   exponent   (log2 of the ratio to n/2)');
  for (final sh in shapes) {
    if (want != null && sh.name != want) continue;
    final rules = MetaGrammar.parseGrammar(sh.grammar);
    var prev = 0.0, prevN = 0;
    for (final n in sizes) {
      final input = sh.gen(n);
      final eng = e.Squirrel(rules: rules, topRuleName: sh.top);
      // Warm, then measure: the first run of a shape pays for JIT.
      try {
        eng.recover(input);
      } catch (_) {}
      final sw = Stopwatch()..start();
      var reps = 0;
      while (sw.elapsedMilliseconds < 120) {
        try {
          e.Squirrel(rules: rules, topRuleName: sh.top).recover(input);
        } catch (_) {}
        reps++;
        if (sw.elapsedMilliseconds > 4000) break;
      }
      sw.stop();
      final ms = sw.elapsedMicroseconds / 1000 / reps;
      final exp = prevN == 0
          ? ''
          : (_log2(ms / prev) / _log2(input.length / prevN.toDouble()))
              .toStringAsFixed(2);
      print('${sh.name.padRight(15)} ${input.length.toString().padLeft(5)} '
          '${ms.toStringAsFixed(2).padLeft(8)}   ${exp.padLeft(6)}');
      prev = ms;
      prevN = input.length;
      if (ms > 3000) {
        print('${' ' * 15} (stopping this shape: over 3 s)');
        break;
      }
    }
    print('');
  }
}

double _log2(double x) => x <= 0 ? 0.0 : math.log(x) / math.ln2;
