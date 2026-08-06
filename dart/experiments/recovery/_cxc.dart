// Scratch: MY OWN check of Codex's four structural claims about r4 -- written
// from its grammars and inputs alone, not from its code. Each row asks the only
// question that matters: does the engine report a cost the FROZEN parser
// contradicts, and is there a cheaper repair it missed?
import 'package:squirrel_parser/squirrel_parser.dart';

import 'r4.dart' as r4;
import '_u9.dart' as u9;
import '_u11b.dart' as u10;

bool pureAccepts(Map<String, Clause> rules, String top, String s) =>
    !Parser(rules: rules, topRuleName: top, input: s).parse().hasSyntaxErrors;

/// The cheapest DELETION-ONLY repair the frozen parser accepts, up to [cap].
int? deleteDistance(Map<String, Clause> rules, String top, String s, int cap) {
  for (var k = 0; k <= cap; k++) {
    final idx = List<int>.filled(k, 0);
    bool rec(int at, int from) {
      if (at == k) {
        final b = StringBuffer();
        for (var i = 0; i < s.length; i++) {
          if (!idx.take(k).contains(i)) b.write(s[i]);
        }
        return pureAccepts(rules, top, b.toString());
      }
      for (var i = from; i < s.length; i++) {
        idx[at] = i;
        if (rec(at + 1, i + 1)) return true;
      }
      return false;
    }

    if (rec(0, 0)) return k;
  }
  return null;
}

String tree(MatchResult m, [String pad = '  ']) {
  final b = StringBuffer();
  void walk(MatchResult k, String p) {
    b.writeln('$p${k.runtimeType}${k is SyntaxError ? k.len == 0 ? ' FILL' : ' DELETE' : ''} '
        'pos=${k.pos} len=${k.len}');
    for (final s in k.subClauseMatches) {
      walk(s, '$p  ');
    }
  }

  walk(m, pad);
  return b.toString();
}

void main() {
  final probes = <(String, String, String, String)>[
    ('C1 possessive repetition', "S <- 'a'* \"ab\";", 'S', 'aab'),
    ('C1 committed choice', "S <- ('a' / \"ab\") 'b';", 'S', 'abb'),
    ('C1 nested committed', "S <- A 'c';\nA <- 'a' / \"ab\";", 'S', 'abc'),
    ('C4 choice as top', "S <- 'a' / 'b';", 'S', ''),
    ('C4 same, wrapped', "T <- S;\nS <- 'a' / 'b';", 'T', ''),
    ('C5 nearest clean move', "S <- 'a'+ 'z';", 'S', 'xazaaaaaz'),
    ('C2 EOI stop', "S <- 'a' 'b' 'c';", 'S', 'a'),
  ];

  print('probe                      pure     r4cost u10cost  del-dist  verdict');
  for (final (name, g, top, input) in probes) {
    final rules = MetaGrammar.parseGrammar(g);
    final ok = pureAccepts(rules, top, input);
    final a = r4.Squirrel(rules: rules, topRuleName: top);
    final b = u10.Squirrel(rules: rules, topRuleName: top);
    int ca = -1, cb = -1;
    MatchResult? ta, tb;
    try {
      ta = a.recover(input);
      ca = a.lastCost;
    } catch (e) {
      ca = -2;
    }
    try {
      tb = b.recover(input);
      cb = b.lastCost;
    } catch (e) {
      cb = -2;
    }
    final dd = deleteDistance(rules, top, input, 3);
    // A cost the frozen parser contradicts: 0 charged for a string it rejects.
    final free = !ok && ca == 0;
    final freeB = !ok && cb == 0;
    // A repair cheaper than the one charged, reachable by deletion alone.
    final over = dd != null && ca > 0 && dd < ca;
    print([
      name.padRight(26),
      (ok ? 'ACCEPT' : 'REJECT').padRight(8),
      ca.toString().padLeft(6),
      cb.toString().padLeft(7),
      (dd?.toString() ?? '>3').padLeft(9),
      '  r4:${free ? 'FREEPASS' : over ? 'OVER($dd<$ca)' : 'ok'}'
          '  u10:${freeB ? 'FREEPASS' : dd != null && cb > 0 && dd < cb ? 'OVER($dd<$cb)' : 'ok'}',
    ].join(' '));
    if (ta != null) print(tree(ta, '      r4 | '));
    if (tb != null) print(tree(tb, '      u10| '));
    print('');
  }
}
