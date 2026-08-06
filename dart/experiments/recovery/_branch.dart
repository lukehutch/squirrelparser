// _branch.dart -- Codex's two remaining probes.
//
// (2) I76 ordered-choice: on `Top <- A / B` with `A <- . 'a' 'b'` and
//     `B <- 'x' 'a' 'b'`, input `ab`, does the engine pick B -- whose repair
//     spells `xab`, a string on which pure PEG picks A?
//
// (4) the predicted I77 regression: `x="a` in the statement corpus, where
//     `Name` precedes `Str` and skipping the real opening quote reclassifies
//     `a` as a Name.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'm126.dart' as m126;
import 'm127.dart' as m127;
import 'm132.dart' as m132;
import 'm134.dart' as m134;

const gAB = '''
Top <- A / B;
A <- . 'a' 'b';
B <- 'x' 'a' 'b';
''';

/// The name of the first named rule under the root -- which alternative of the
/// top-level choice the engine committed to.
String branch(MatchResult? m) {
  if (m is! Match) return '?';
  for (final k in m.subClauseMatches) {
    final c = k.clause;
    if (c is Ref && (c.ruleName == 'A' || c.ruleName == 'B')) return c.ruleName;
    final d = branch(k);
    if (d != '?') return d;
  }
  return '?';
}

void marks(MatchResult m, String src, List<String> out) {
  if (m is m126.Filled ||
      m is m127.Filled ||
      m is m132.Filled ||
      m is m134.Filled) {
    out.add('FILL@${m.pos}');
  } else if (m is SyntaxError) {
    out.add('SKIP@${m.pos}+${m.len}'
        '"${src.substring(m.pos, (m.pos + m.len).clamp(0, src.length))}"');
  }
  if (m is Match) {
    for (final k in m.subClauseMatches) {
      marks(k, src, out);
    }
  }
}

/// The repaired witness: real characters as they are, filled ones in `<>`,
/// skipped ones dropped. This is the string the repair claims parses.
void wit(MatchResult m, String src, StringBuffer b) {
  if (m is m126.Filled) return b.write('<${m.text}>');
  if (m is m127.Filled) return b.write('<${m.text}>');
  if (m is m132.Filled) return b.write('<${m.text}>');
  if (m is m134.Filled) return b.write('<${m.text}>');
  if (m is SyntaxError) return;
  if (m is Match && m.subClauseMatches.isEmpty) {
    b.write(src.substring(m.pos, (m.pos + m.len).clamp(0, src.length)));
    return;
  }
  if (m is Match) {
    for (final k in m.subClauseMatches) {
      wit(k, src, b);
    }
  }
}

String witness(MatchResult? m, String src) {
  if (m == null) return '?';
  final b = StringBuffer();
  wit(m, src, b);
  return b.toString();
}

void main() {
  final rAB = MetaGrammar.parseGrammar(gAB);

  print('--- (2) ordered choice: Top <- A / B  on "ab"');
  print('    pure PEG on the repaired witness "xab" picks: '
      '${Parser(rules: rAB, topRuleName: 'Top', input: 'xab').parse().hasSyntaxErrors ? 'REJECTED' : branch(Parser(rules: rAB, topRuleName: 'Top', input: 'xab').parse().root)}');
  for (final e in ['m126', 'm127', 'm132', 'm134']) {
    MatchResult? r;
    int? c;
    switch (e) {
      case 'm126':
        final p = m126.SuperDot3(rules: rAB, topRuleName: 'Top');
        r = p.recover('ab');
        c = p.lastCost;
      case 'm127':
        final p = m127.SuperDot3(rules: rAB, topRuleName: 'Top');
        r = p.recover('ab');
        c = p.lastCost;
      case 'm132':
        final p = m132.SuperDot3(rules: rAB, topRuleName: 'Top');
        r = p.recover('ab');
        c = p.lastCost;
      case 'm134':
        final p = m134.SuperDot3(rules: rAB, topRuleName: 'Top');
        r = p.recover('ab');
        c = p.lastCost;
    }
    print('    $e  branch=${branch(r)}  cost=$c  '
        'witness="${witness(r, 'ab')}"');
  }

  print('');
  print('--- (1b) does I77 buy a BETTER tree for the extra cost, or a worse one?');
  const g1 = '''
Top <- C 'q' 'r' 's';
C <- E / W;
E <- . 'a' 'b';
W <- . . . .;
''';
  final r1 = MetaGrammar.parseGrammar(g1);
  String cbranch(MatchResult? m) {
    if (m is! Match) return '?';
    for (final k in m.subClauseMatches) {
      final c = k.clause;
      if (c is Ref && (c.ruleName == 'E' || c.ruleName == 'W')) return c.ruleName;
      final d = cbranch(k);
      if (d != '?') return d;
    }
    return '?';
  }

  for (final s in ['xxab', 'xyab']) {
    print('    input $s  (four arbitrary chars IS W, matching for free)');
    for (final e in ['m127', 'm132', 'm134']) {
      MatchResult? r;
      int? k;
      switch (e) {
        case 'm127':
          final p = m127.SuperDot3(rules: r1, topRuleName: 'Top');
          r = p.recover(s);
          k = p.lastCost;
        case 'm132':
          final p = m132.SuperDot3(rules: r1, topRuleName: 'Top');
          r = p.recover(s);
          k = p.lastCost;
        case 'm134':
          final p = m134.SuperDot3(rules: r1, topRuleName: 'Top');
          r = p.recover(s);
          k = p.lastCost;
      }
      final out = <String>[];
      if (r != null) marks(r, s, out);
      print('      $e cost=$k  C->${cbranch(r)}  witness="${witness(r, s)}"'
          '  ${out.join(' ')}');
    }
  }

  print('');
  print('--- (4) predicted I77 regression: `x="a` in the stmt corpus');
  final c = corpora.firstWhere((e) => e.name == 'stmt');
  final rs = MetaGrammar.parseGrammar(c.grammar);
  for (final s in ['x="a', 'x="ab', 'p="q']) {
    print('    input $s');
    for (final e in ['m126', 'm127', 'm132', 'm134']) {
      MatchResult? r;
      int? k;
      switch (e) {
        case 'm126':
          final p = m126.SuperDot3(rules: rs, topRuleName: c.top);
          r = p.recover(s);
          k = p.lastCost;
        case 'm127':
          final p = m127.SuperDot3(rules: rs, topRuleName: c.top);
          r = p.recover(s);
          k = p.lastCost;
        case 'm132':
          final p = m132.SuperDot3(rules: rs, topRuleName: c.top);
          r = p.recover(s);
          k = p.lastCost;
        case 'm134':
          final p = m134.SuperDot3(rules: rs, topRuleName: c.top);
          r = p.recover(s);
          k = p.lastCost;
      }
      final out = <String>[];
      if (r != null) marks(r, s, out);
      print('      $e cost=$k  ${out.join('  ')}');
    }
  }
}
