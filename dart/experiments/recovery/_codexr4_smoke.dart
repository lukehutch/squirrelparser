// _r3smoke.dart -- does r3 terminate, cover, and agree with PEG when clean?
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_codexr4_candidate.dart' as candidate;

void main() {
  for (final c in corpora) {
    final rules = MetaGrammar.parseGrammar(c.grammar);
    for (final doc in c.documents) {
      final pure = Parser(rules: rules, topRuleName: c.top, input: doc).parse();
      final e = candidate.Squirrel(rules: rules, topRuleName: c.top);
      final sw = Stopwatch()..start();
      MatchResult got;
      try {
        got = e.recover(doc);
      } catch (err) {
        print('${c.name} CRASH on clean: $err');
        continue;
      }
      sw.stop();
      final a = skeleton(pure.root, c.named).join(' ');
      final b = skeleton(got, c.named).join(' ');
      print('${c.name.padRight(6)} clean cost=${e.lastCost} '
          'len=${got.len}/${doc.length} same=${a == b} ${sw.elapsedMilliseconds}ms');
      if (a != b) {
        print('   PEG $a');
        print('   r3  $b');
      }
    }
  }

  const probes = [
    ('json', '{"a:1,"bc":[2,33,true]}'),
    ('json', '"a":1,"bc":[2]}'),
    ('json', '[1,[2,'),
    ('json', 'Q[1,[2,[3,[4]]],5]'),
    ('json', '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}'),
  ];
  for (final (g, s) in probes) {
    final c = corpora.firstWhere((x) => x.name == g);
    final rules = MetaGrammar.parseGrammar(c.grammar);
      final e = candidate.Squirrel(rules: rules, topRuleName: c.top);
    final sw = Stopwatch()..start();
    try {
      final got = e.recover(s);
      sw.stop();
      print('`$s` cost=${e.lastCost} cover=${got.len}/${s.length} '
          '${sw.elapsedMilliseconds}ms  '
          '${skeleton(got, c.named).where((t) => t != '(' && t != ')').join(' ')}');
    } catch (err) {
      sw.stop();
      print('`$s` CRASH after ${sw.elapsedMilliseconds}ms: $err');
    }
  }
}
