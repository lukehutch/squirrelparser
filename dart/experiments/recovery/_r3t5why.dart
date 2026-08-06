// _r3t5why.dart -- does the repetition skip let `Chr*` delete its own terminator?
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_r3score.dart' show builds;

void marks(MatchResult m, String s, List<String> out) {
  if (m is SyntaxError) {
    out.add(m.len == 0
        ? 'fill@${m.pos}'
        : 'del@${m.pos}:${s.substring(m.pos, m.pos + m.len)}');
  }
  for (final k in m.subClauseMatches) {
    marks(k, s, out);
  }
}

void main() {
  final rulesOf = {
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final byName = {for (final c in corpora) c.name: c};
  final origOf = <String, MatchResult>{};
  for (final c in corpora) {
    for (final doc in c.documents) {
      origOf['${c.name} $doc'] = Parser(
              rules: rulesOf[c.name]!, topRuleName: c.top, input: doc)
          .parse()
          .root;
    }
  }
  final mk = {
    for (final n in ['r3', 't5'])
      n: {for (final c in corpora) c.name: builds[n]!(rulesOf[c.name]!, c.top)}
  };
  final seen = <String>{};
  var shown = 0;
  for (final k in weighted(buildBattery())) {
    if (k.category != 'literal-damage') continue;
    if (!seen.add('${k.grammar}\x00${k.mutant}')) continue;
    final c = byName[k.grammar]!;
    final exp = expectedFor(k, origOf['${k.grammar} ${k.original}']!, c.named);
    final got = <String, MatchResult?>{};
    final sc = <String, double>{};
    for (final n in ['r3', 't5']) {
      MatchResult? m;
      try {
        m = mk[n]![k.grammar]!(k.mutant);
      } catch (_) {}
      got[n] = m;
      sc[n] = scoreCase(
              produced: m,
              expected: exp,
              inputLen: k.mutant.length,
              named: c.named)
          .score;
    }
    if (sc['r3']! - sc['t5']! < 0.05) continue;
    if (++shown > 4) break;
    print('\n${k.grammar} `${k.mutant}`   r3 ${sc['r3']!.toStringAsFixed(3)} '
        '-> t5 ${sc['t5']!.toStringAsFixed(3)}');
    for (final n in ['r3', 't5']) {
      final o = <String>[];
      if (got[n] != null) marks(got[n]!, k.mutant, o);
      print('  $n  ${o.join(' ')}');
    }
  }
}
