// Scratch: is the `committed >= 0` guard in m49's I3 veto load bearing, in BOTH
// directions? The line under test, in `_compute`'s `_Alt` case:
//
//   if (e.value < _costUnit &&
//       _endOf(e.key) > committed &&
//       (committed >= 0 || _oweOf(e.key) == _free)) continue;
//
// Two ablations, each dropping half of the third conjunct:
//
//   va  `_endOf(e.key) > committed` alone -- veto a debt-free-priced candidate
//       whatever it owes. This is the pre-I7 reading of I3.
//   vb  `... && _oweOf(e.key) == _free` -- never veto an owing candidate, even
//       when the oracle MATCHED here.
//
// Claim to check: va is SAFE but LOSES exactness (costs go up), vb is UNSOUND or
// changes an answer it must not (costs go down / a witness stops verifying).
// If either ablation changed nothing, the guard would be dead weight.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm49.dart' as g49;
import '_m49va.dart' as va;
import '_m49vb.dart' as vb;

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

/// _leak49's four blocks, concatenated: soundness (A), what I6 exists for (B),
/// what I7 exists for (C, D). Plus the PEG-commitment grammars the debt-free half
/// of the veto is the only protection for.
const grammars = <(String, String, String, List<String>)>[
  // -- block A: the m47 leak. m49 must not under-report here.
  (
    'A: nullable run ENDING a rule body',
    "S <- !'x' A D;\nA <- 'a'? 'c'?;\nD <- 'd' / 'x';\n",
    'acdx',
    ['x', 'ax', 'acx', 'd', 'ad', ''],
  ),
  (
    'A: nullable refs ending a rule body',
    "S <- !'x' A D;\nA <- B C;\nB <- 'b'?;\nC <- 'c'?;\nD <- 'd' / 'x';\n",
    'bcdx',
    ['x', 'bx', 'd', 'bd', ''],
  ),
  // -- block B: reader behind a name.
  (
    'B: G0, nullable prefix, reader behind a name',
    "S <- !'x' A B;\nA <- 'a'?;\nB <- 'b' / 'x';\n",
    'abx',
    ['x', 'xx', 'ax', 'b', '', 'xb'],
  ),
  (
    'B: reader is a whole choice behind a name',
    "S <- !'x' A;\nA <- 'x' / \"yy\";\n",
    'xyq',
    ['q', 'x', 'yy', 'y', '', 'xy'],
  ),
  // -- block C/D: the trailing lookahead, which is what the guard is for. Every
  // one of these has an ALTERNATION over a clause that owes at its end.
  (
    'C: trailing lookahead, reader in the parent',
    "S <- A 'b';\nA <- 'a' &'b';\n",
    'abx',
    ['ab', 'a', 'ax', 'b', ''],
  ),
  (
    'C: trailing negative lookahead (keyword boundary)',
    "S <- Kw !Alpha;\nKw <- \"if\";\nAlpha <- [a-z];\n",
    'ifq',
    ['if', 'ifq', 'iff', 'i', 'if '],
  ),
  (
    'D: keyword boundary INSIDE the keyword rule',
    "S <- Kw Rest;\nKw <- \"if\" !Alpha;\nRest <- ' ' Alpha;\nAlpha <- [a-z];\n",
    'ifa ',
    ['if a', 'ifa', 'if ', 'iff a', 'i a'],
  ),
  (
    'D: the same boundary, reader nullable at the call site',
    "S <- Kw Rest;\nKw <- \"if\" !Alpha;\nRest <- ' '*;\nAlpha <- [a-z];\n",
    'ifa ',
    ['if', 'ifa', 'if ', 'iff'],
  ),
  (
    'D: trailing lookahead behind an ordered choice',
    "S <- A 'b';\nA <- 'a' &'b' / 'c';\n",
    'abc',
    ['ab', 'cb', 'a', 'c', 'ax'],
  ),
  // -- the debt-free half of the veto is the ONLY thing keeping the search off a
  // non-greedy repetition and a free-riding alternative (LESSONS 5m). If dropping
  // `committed >= 0` were free, these would not move either.
  (
    'PEG: a star that may not stop early',
    "S <- 'a'* 'b' 'a';\n",
    'ab',
    ['aa', 'aba', 'ba', 'a', ''],
  ),
  (
    'PEG: ordered choice, longer alternative second',
    "S <- 'a' / 'a' 'a' 'a' &'b';\n",
    'ab',
    ['a', 'aaa', 'aa', 'aaab', ''],
  ),
  (
    'PEG: the same choice as a whole-input goal',
    "S <- A 'b';\nA <- 'a' / 'a' 'a' 'a' &'b';\n",
    'ab',
    ['ab', 'aaab', 'aab', 'b', 'a'],
  ),
];

void main() {
  var d49 = 0, dva = 0, dvb = 0, total = 0, moveVa = 0, moveVb = 0;
  final notes = <String>[];
  for (final (title, grammar, alphabet, inputs) in grammars) {
    final rules = MetaGrammar.parseGrammar(grammar);
    print('\n$title\n  ${grammar.replaceAll('\n', ' ')}');
    print('  ${'input'.padRight(9)}${'true'.padLeft(6)}${'m49'.padLeft(6)}'
        '${'va'.padLeft(6)}${'vb'.padLeft(6)}   49/va/vb');
    for (final s in inputs) {
      total++;
      final t = trueDistance(rules, 'S', s, alphabet, maxEdits);
      final want = t?.toString() ?? '>$maxEdits';
      final c49 =
          cell(g49.SuperDot3(rules: rules, topRuleName: 'S').recoverCost, s);
      final cva =
          cell(va.SuperDot3(rules: rules, topRuleName: 'S').recoverCost, s);
      final cvb =
          cell(vb.SuperDot3(rules: rules, topRuleName: 'S').recoverCost, s);
      final v49 = verdict(t, c49), vva = verdict(t, cva), vvb = verdict(t, cvb);
      if (v49 != 'ok') d49++;
      if (vva != 'ok') dva++;
      if (vvb != 'ok') dvb++;
      if (cva != c49) {
        moveVa++;
        notes.add('va  $title / "$s": m49 $c49 -> $cva (true $want) [$vva]');
      }
      if (cvb != c49) {
        moveVb++;
        notes.add('vb  $title / "$s": m49 $c49 -> $cvb (true $want) [$vvb]');
      }
      print('  ${(s.isEmpty ? '<empty>' : s).padRight(9)}${want.padLeft(6)}'
          '${c49.padLeft(6)}${cva.padLeft(6)}${cvb.padLeft(6)}'
          '   $v49/$vva/$vvb');
    }
  }
  print('\nexact: m49 ${total - d49}/$total, '
      'va ${total - dva}/$total, vb ${total - dvb}/$total');
  print('rows where the ablation CHANGES the answer: va $moveVa, vb $moveVb');
  for (final n in notes) {
    print('  $n');
  }
}
