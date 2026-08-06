// Scratch: does m48 close m47's `_end` leak WITHOUT giving up what I6 bought?
//
// m47 discharged a pending constraint at the end of a cons chain, so a chain all
// of whose elements are silent satisfied a NONEMPTY constraint vacuously and the
// engine reported repairs that do not exist (`_leak47`: 0 where the truth is 1).
// m48 does two things instead: the chain terminator ENFORCES the constraint like
// any other silent move, and `_cons` posts a constraint only in front of a rest
// that must read a character. The first alone would over-report where the second
// alone would under-report, so both columns have to be checked at once:
//
//   block A -- the leak grammars. m47 under-reports; m48 must be exact.
//   block B -- a lookahead whose reader is BEHIND a rule reference. This is what
//              I6 exists for; m48 must still be exact, not merely safe.
//   block C -- a lookahead with no reader after it at all, in its own rule and in
//              the goal. m48 must fall back to m46 and stay safe.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm46.dart' as g46;
import 'm47.dart' as g47;
import 'm48.dart' as g48;

bool inLanguage(Map<String, Clause> rules, String top, String s) {
  final p = Parser(rules: rules, topRuleName: top, input: s).parse();
  return !p.hasSyntaxErrors && p.root != null && p.root!.len == s.length;
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

const int maxEdits = 3;

String cell(int Function(String) f, String s) {
  try {
    return f(s).toString();
  } catch (e) {
    return 'X(${e.runtimeType})';
  }
}

/// Exact, or safely above, or agreeing that nothing is within reach.
String verdict(int? truth, String got) {
  final n = int.tryParse(got);
  if (truth != null) {
    return got == '$truth'
        ? 'ok'
        : (n == null || n < 0 || n > truth)
            ? 'high'
            : 'UNDER';
  }
  return (n == null || n < 0 || n > maxEdits) ? 'ok' : 'UNDER';
}

const blockA = <(String, String, String, List<String>)>[
  (
    'nullable run ENDING a rule body',
    "S <- !'x' A D;\nA <- 'a'? 'c'?;\nD <- 'd' / 'x';\n",
    'acdx',
    ['x', 'ax', 'acx', 'd', 'ad', ''],
  ),
  (
    'the same nullables INLINE (control)',
    "S <- !'x' 'a'? 'c'? D;\nD <- 'd' / 'x';\n",
    'acdx',
    ['x', 'ax', 'acx', 'd', 'ad', ''],
  ),
  (
    'one nullable ending a rule body',
    "S <- !'x' A D;\nA <- 'a'?;\nD <- 'd' / 'x';\n",
    'adx',
    ['x', 'ax', 'd', 'ad', ''],
  ),
  (
    'nullable refs ending a rule body',
    "S <- !'x' A D;\nA <- B C;\nB <- 'b'?;\nC <- 'c'?;\nD <- 'd' / 'x';\n",
    'bcdx',
    ['x', 'bx', 'd', 'bd', ''],
  ),
];

const blockB = <(String, String, String, List<String>)>[
  (
    'G0: nullable prefix, reader behind a name',
    "S <- !'x' A B;\nA <- 'a'?;\nB <- 'b' / 'x';\n",
    'abx',
    ['x', 'xx', 'ax', 'b', '', 'xb'],
  ),
  (
    'reader is a whole choice behind a name',
    "S <- !'x' A;\nA <- 'x' / \"yy\";\n",
    'xyq',
    ['q', 'x', 'yy', 'y', '', 'xy'],
  ),
  (
    'repetition under a lookahead',
    "S <- !'x' 'a'* B;\nB <- 'b' / 'x';\n",
    'abx',
    ['x', 'aax', 'b', ''],
  ),
];

const blockC = <(String, String, String, List<String>)>[
  // The rest of S's chain is a SINGLE nullable rule: nothing after `!'x'` has to
  // emit, so there is no reader for the constraint to bind and m48 keeps the
  // node. Truth on "" is 0 -- a strict constraint with nowhere to go would say 1.
  (
    'lookahead over a rest that need not read',
    "S <- !'x' A;\nA <- 'a'?;\n",
    'ax',
    ['', 'a', 'x', 'ax', 'aa'],
  ),
  // The lookahead is LAST in its own rule and its reader is in the parent chain,
  // which no value carried between frames can reach.
  (
    'trailing lookahead, reader in the parent',
    "S <- A 'b';\nA <- 'a' &'b';\n",
    'abx',
    ['ab', 'a', 'ax', 'b', ''],
  ),
  (
    'trailing negative lookahead (keyword boundary)',
    "S <- Kw !Alpha;\nKw <- \"if\";\nAlpha <- [a-z];\n",
    'ifq',
    ['if', 'ifq', 'iff', 'i', 'if '],
  ),
  // `!.` succeeds only at end of input, so the whole rest must be empty.
  (
    'negative lookahead at everything',
    "S <- 'a' !. ;\n",
    'ab',
    ['a', 'ab', '', 'aa'],
  ),
];

/// How much does block C's residual cost on grammars people actually write? The
/// idiom is the keyword boundary, `Kw <- "if" !Alpha`, where the lookahead is the
/// last thing in its own rule and everything that could satisfy it is at the call
/// site. If m48 is exact here anyway the residual is a curiosity; if it is not,
/// it is worth a channel that runs the other way.
const blockD = <(String, String, String, List<String>)>[
  (
    'keyword boundary INSIDE the keyword rule',
    "S <- Kw Rest;\nKw <- \"if\" !Alpha;\nRest <- ' ' Alpha;\nAlpha <- [a-z];\n",
    'ifa ',
    ['if a', 'ifa', 'if ', 'iff a', 'i a'],
  ),
  (
    'the same boundary, reader nullable at the call site',
    "S <- Kw Rest;\nKw <- \"if\" !Alpha;\nRest <- ' '*;\nAlpha <- [a-z];\n",
    'ifa ',
    ['if', 'ifa', 'if ', 'iff'],
  ),
  (
    'trailing lookahead behind an ordered choice',
    "S <- A 'b';\nA <- 'a' &'b' / 'c';\n",
    'abc',
    ['ab', 'cb', 'a', 'c', 'ax'],
  ),
];

(int, int, int, int) run(
    String name, List<(String, String, String, List<String>)> block) {
  var bad46 = 0, bad47 = 0, bad48 = 0, total = 0;
  print('\n===== $name =====');
  for (final (title, grammar, alphabet, inputs) in block) {
    final rules = MetaGrammar.parseGrammar(grammar);
    print('\n$title\n  ${grammar.replaceAll('\n', ' ')}');
    print('  ${'input'.padRight(9)}${'true'.padLeft(6)}${'m46'.padLeft(6)}'
        '${'m47'.padLeft(6)}${'m48'.padLeft(6)}   46/47/48');
    for (final s in inputs) {
      total++;
      final t = trueDistance(rules, 'S', s, alphabet, maxEdits);
      final want = t?.toString() ?? '>$maxEdits';
      final c46 =
          cell(g46.SuperDot3(rules: rules, topRuleName: 'S').recoverCost, s);
      final c47 =
          cell(g47.SuperDot3(rules: rules, topRuleName: 'S').recoverCost, s);
      final c48 =
          cell(g48.SuperDot3(rules: rules, topRuleName: 'S').recoverCost, s);
      final v46 = verdict(t, c46), v47 = verdict(t, c47), v48 = verdict(t, c48);
      if (v46 != 'ok') bad46++;
      if (v47 != 'ok') bad47++;
      if (v48 != 'ok') bad48++;
      print('  ${(s.isEmpty ? '<empty>' : s).padRight(9)}${want.padLeft(6)}'
          '${c46.padLeft(6)}${c47.padLeft(6)}${c48.padLeft(6)}'
          '   $v46/$v47/$v48${v48 == 'UNDER' ? '   <== m48 UNSOUND' : ''}');
    }
  }
  print('\n  $name exact: m46 ${total - bad46}/$total, '
      'm47 ${total - bad47}/$total, m48 ${total - bad48}/$total');
  return (total, bad46, bad47, bad48);
}

void main() {
  final r = [
    run('block A: the leak grammars', blockA),
    run('block B: what I6 exists for', blockB),
    run('block C: no reader for the constraint', blockC),
    run('block D: the residual on grammars people write', blockD),
  ];
  var total = 0, b46 = 0, b47 = 0, b48 = 0;
  for (final (t, x, y, z) in r) {
    total += t;
    b46 += x;
    b47 += y;
    b48 += z;
  }
  print('\nOVERALL exact: m46 ${total - b46}/$total, m47 ${total - b47}/$total, '
      'm48 ${total - b48}/$total');
}
