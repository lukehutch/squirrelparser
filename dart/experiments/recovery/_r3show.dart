// _r3show.dart -- concrete cases: what r3 gets right, and what it still misses.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'm143.dart' as g143;
import 'r2.dart' as g2;
import 'r3.dart' as g3;

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

String flat(List<String> sk) => sk
    .fold(StringBuffer(), (StringBuffer b, t) {
      b.write(t == '(' || t == ')' ? t : ' $t');
      return b;
    })
    .toString()
    .replaceAll(' (', '(')
    .trim();

void main() {
  const probes = [
    // -- WINS -----------------------------------------------------------------
    ('json', '{"a:1,"bc":[2,33,true]}', 'quote-delete: r2 could not see this'),
    ('json', '{"a":[1,[2,', 'truncate: three constructs left open'),
    ('expr', 'a*', 'truncate: the operand the document never supplied'),
    ('expr', '1+2*3', 'undamaged: must be PEG to the node'),
    ('json', '{"a":1,"b":[2,3]}', 'undamaged'),
    ('stmt', 'x=1; if (x) { y=2; } z=3;', 'undamaged'),
    // -- LOSSES ---------------------------------------------------------------
    ('stmt', 'x=1; if (x) { y=\\; z=3; } w=4;', 'LOSS: backslash, no fillable Cond'),
    ('json', '{"a":[1,[2,', 'LOSS: one long String is CHEAPER than the Array'),
  ];
  for (final (g, s, why) in probes) {
    final c = corpora.firstWhere((x) => x.name == g);
    final rules = MetaGrammar.parseGrammar(c.grammar);
    print('\n`$s`   ($g -- $why)');
    for (final (name, mk) in <(String, MatchResult Function())>[
      ('r2', () => g2.Squirrel(rules: rules, topRuleName: c.top).recover(s)),
      ('r3', () => g3.Squirrel(rules: rules, topRuleName: c.top).recover(s)),
      ('m143', () => g143.SuperDot3(rules: rules, topRuleName: c.top).recover(s)),
    ]) {
      try {
        final t = mk();
        final o = <String>[];
        marks(t, s, o);
        print('  ${name.padRight(5)} ${flat(skeleton(t, c.named))}');
        if (o.isNotEmpty) print('        ${o.join(' ')}');
      } catch (e) {
        print('  ${name.padRight(5)} CRASH $e');
      }
    }
  }
}
