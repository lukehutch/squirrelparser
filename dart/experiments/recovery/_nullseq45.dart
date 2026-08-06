// Scratch: is I4's boundary a limit of the IMPLEMENTATION or of the METHOD?
//
// I4 fuses `!C T` where T is the terminal that consumes the character C looks at.
// The obvious generalisation is to PUSH the constraint down the grammar until it
// reaches a terminal -- a static rewrite, no new state. This asks whether that
// rewrite can be correct, and answers it with the PURE PARSER, no engine involved:
// two languages compared by membership.
//
//   G0:  S <- !'x' A B;   A <- 'a'?;   B <- 'b' / 'x';
//
// The constraint is on the first character of the whole sequence. A may emit
// nothing, so WHICH clause owns that character is not decided until run time:
//
//   G1: constraint pushed into A only     -- `S <- (!'x' 'a')? B;`
//   G2: constraint pushed into A and B    -- `S <- (!'x' 'a')? (!'x' B);`
//
// If G1 accepts a string G0 rejects, that placement under-reports. If G2 rejects
// a string G0 accepts, that placement loses repairs. Both, and the static rewrite
// is dead: the engine must know AT RUN TIME whether anything was emitted yet,
// which is one bit travelling back up -- and one bit is what the value does not
// carry.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm45.dart' as g45;

bool inLanguage(Map<String, Clause> rules, String top, String s) {
  final p = Parser(rules: rules, topRuleName: top, input: s).parse();
  return !p.hasSyntaxErrors && p.root.len == s.length;
}

int? trueDistance(
    Map<String, Clause> rules, String top, String s, String alphabet, int maxK) {
  var frontier = {s};
  final seen = {s};
  for (var k = 0; k <= maxK; k++) {
    for (final c in frontier) {
      if (inLanguage(rules, top, c)) return k;
    }
    final next = <String>{};
    for (final c in frontier) {
      for (var i = 0; i < c.length; i++) {
        final del = c.substring(0, i) + c.substring(i + 1);
        if (seen.add(del)) next.add(del);
      }
      for (var i = 0; i <= c.length; i++) {
        for (final ch in alphabet.split('')) {
          final ins = c.substring(0, i) + ch + c.substring(i);
          if (seen.add(ins)) next.add(ins);
          if (i < c.length) {
            final sub = c.substring(0, i) + ch + c.substring(i + 1);
            if (seen.add(sub)) next.add(sub);
          }
        }
      }
    }
    frontier = next;
  }
  return null;
}

void main() {
  const g0 = "S <- !'x' A B;\nA <- 'a'?;\nB <- 'b' / 'x';\n";
  const g1 = "S <- (!'x' 'a')? B;\nB <- 'b' / 'x';\n";
  const g2 = "S <- (!'x' 'a')? (!'x' B);\nB <- 'b' / 'x';\n";
  final r0 = MetaGrammar.parseGrammar(g0);
  final r1 = MetaGrammar.parseGrammar(g1);
  final r2 = MetaGrammar.parseGrammar(g2);

  print('MEMBERSHIP -- the pure parser alone, no recovery anywhere');
  print('${'string'.padRight(8)}${'G0'.padLeft(7)}${'G1'.padLeft(7)}'
      '${'G2'.padLeft(7)}   verdict');
  var g1Differs = false, g2Differs = false;
  for (final s in ['b', 'x', 'ab', 'ax', 'a', '', 'bx', 'aa']) {
    final a = inLanguage(r0, 'S', s);
    final b = inLanguage(r1, 'S', s);
    final c = inLanguage(r2, 'S', s);
    if (b && !a) g1Differs = true;
    if (a && !c) g2Differs = true;
    final note = (b && !a)
        ? 'G1 ACCEPTS WHAT G0 REJECTS -- under-reports'
        : (a && !c)
            ? 'G2 REJECTS WHAT G0 ACCEPTS -- loses a repair'
            : '';
    print('${(s.isEmpty ? '<empty>' : s).padRight(8)}${a.toString().padLeft(7)}'
        '${b.toString().padLeft(7)}${c.toString().padLeft(7)}   $note');
  }
  print(g1Differs && g2Differs
      ? '\nBOTH static placements are wrong languages. No pushdown of the '
          'constraint\ncan be exact, so the emission is a RUN-TIME fact.'
      : '\ninconclusive');

  // What the engine actually does on the same grammar, for the record.
  print('\nRECOVERY on G0   alphabet="abx"');
  print('${'input'.padRight(8)}${'true'.padLeft(6)}${'m45'.padLeft(6)}');
  for (final s in ['x', 'ax', 'b', 'ab', '', 'xx', 'xb']) {
    final t = trueDistance(r0, 'S', s, 'abx', 3);
    final got = g45.SuperDot3(rules: r0, topRuleName: 'S').recoverCost(s);
    print('${(s.isEmpty ? '<empty>' : s).padRight(8)}'
        '${(t?.toString() ?? '>3').padLeft(6)}${got.toString().padLeft(6)}'
        '${t != null && got != t ? '   MISMATCH' : ''}');
  }
}
