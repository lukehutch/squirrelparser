// _score1.dart -- score ONE engine on the AST-diff battery and print one result
// line. One engine per process, so an engine that hangs on damaged
// left-recursive input is killed by the caller's `timeout` instead of blocking
// every other engine's measurement.
//
// THE ADAPTER RUNS ONE WAY ONLY, AND THAT IS WHY THIS FILE EXISTS RATHER THAN A
// NEW COLUMN IN final_table.dart. Engines up to m78 return `SkipResult`, whose
// `.root` IS the full-coverage tree this evaluator wants, so adapting them here
// is lossless. Adapting the other way -- forcing m79-m82's `MatchResult` into
// `SkipResult` for the old table -- is NOT lossless: `recoveryEvents` would have
// to carry `lastCost`, and under I44 that is a count of unexplained CHARACTERS
// where every earlier engine counts edit EVENTS. Putting two different
// objectives in one column is the error this project has already made three
// times, so the new engines are scored on the shape metric, which is
// objective-neutral, and are not back-fitted into the cost column.
//
// Usage: dart run _score1.dart <engineName>
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'final_table.dart' show engines;
import 'm79.dart' as g79;
import 'm80.dart' as g80;
import 'm81.dart' as g81;
import 'm82.dart' as g82;
import 'm83.dart' as g83;
import 'm84.dart' as g84;
import 'm85.dart' as g85;
import 'm86.dart' as g86;
import 'm87.dart' as g87;
import 'm88.dart' as g88;
import 'm89.dart' as g89;
import 'm90.dart' as g90;
import 'm91.dart' as g91;
import 'm92.dart' as g92;
import 'm93.dart' as g93;
import 'm94.dart' as g94;
import 'm95.dart' as g95;
import 'm96.dart' as g96;
import 'm97.dart' as g97;
import 'm98.dart' as g98;
import 'm99.dart' as g99;
import 'm100.dart' as g100;
import 'm101.dart' as g101;
import 'm102.dart' as g102;
import 'm103.dart' as g103;
import 'm105.dart' as g105;
import 'm106.dart' as g106;
import 'm108.dart' as g108;
import 'm109.dart' as g109;
import 'm110.dart' as g110;
import 'm111.dart' as g111;
import 'm112.dart' as g112;
import 'm113.dart' as g113;
import 'm114.dart' as g114;
import 'm115.dart' as g115;
import 'm116.dart' as g116;
import 'm118.dart' as g118;
import 'm117.dart' as g117;
import 'm119.dart' as g119;
import 'm120.dart' as g120;
import 'm121step.dart' as gm121step;
import 'm116step.dart' as gm116step;
import 'm113step.dart' as gm113step;
import 'm121.dart' as g121;
import 'm122.dart' as g122;
import 'm123.dart' as g123;
import 'm124.dart' as g124;
import 'm125.dart' as g125;
import 'm126.dart' as g126;
import 'm127.dart' as g127;
import 'm128.dart' as g128;
import 'm129.dart' as g129;
import 'm130.dart' as g130;
import 'm131.dart' as g131;
import 'm132.dart' as g132;
import 'm133.dart' as g133;
import 'm134.dart' as g134;
import 'm135.dart' as g135;
import 'm136.dart' as g136;
import 'm137.dart' as g137;
import 'm138.dart' as g138;
import 'm139.dart' as g139;
import 'm140.dart' as g140;
import 'm141.dart' as g141;
import 'm142.dart' as g142;
import 'm143.dart' as g143;
import 'm145.dart' as g145;
import 'r1.dart' as r1;
import 'r2.dart' as r2;
import 'r3.dart' as r3;

/// A uniform surface over both engine generations: give it a grammar and a top
/// rule, get back something that turns a damaged string into a tree or throws.
typedef Build = MatchResult? Function(String) Function(
    Map<String, Clause>, String);

final Map<String, Build> extra = {
  'm79': (r, t) {
    final e = g79.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm80': (r, t) {
    final e = g80.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm81': (r, t) {
    final e = g81.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm82': (r, t) {
    final e = g82.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm83': (r, t) {
    final e = g83.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm84': (r, t) {
    final e = g84.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm85': (r, t) {
    final e = g85.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm86': (r, t) {
    final e = g86.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm87': (r, t) {
    final e = g87.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm88': (r, t) {
    final e = g88.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm89': (r, t) {
    final e = g89.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm90': (r, t) {
    final e = g90.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm91': (r, t) {
    final e = g91.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm92': (r, t) {
    final e = g92.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm93': (r, t) {
    final e = g93.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm94': (r, t) {
    final e = g94.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm95': (r, t) {
    final e = g95.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm96': (r, t) {
    final e = g96.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm97': (r, t) {
    final e = g97.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm98': (r, t) {
    final e = g98.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm99': (r, t) {
    final e = g99.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm100': (r, t) {
    final e = g100.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm101': (r, t) {
    final e = g101.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm102': (r, t) {
    final e = g102.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm103': (r, t) {
    final e = g103.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm105': (r, t) {
    final e = g105.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm106': (r, t) {
    final e = g106.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm108': (r, t) {
    final e = g108.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm109': (r, t) {
    final e = g109.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm110': (r, t) {
    final e = g110.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm111': (r, t) {
    final e = g111.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm112': (r, t) {
    final e = g112.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm113': (r, t) {
    final e = g113.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm114': (r, t) {
    final e = g114.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm115': (r, t) {
    final e = g115.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm116': (r, t) {
    final e = g116.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm118': (r, t) {
    final e = g118.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm117': (r, t) {
    final e = g117.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm119': (r, t) {
    final e = g119.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm120': (r, t) {
    final e = g120.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm121step': (r, t) {
    final e = gm121step.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm116step': (r, t) {
    final e = gm116step.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm113step': (r, t) {
    final e = gm113step.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm121': (r, t) {
    final e = g121.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm122': (r, t) {
    final e = g122.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm123': (r, t) {
    final e = g123.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm124': (r, t) {
    final e = g124.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm125': (r, t) {
    final e = g125.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm126': (r, t) {
    final e = g126.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm127': (r, t) {
    final e = g127.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm128': (r, t) {
    final e = g128.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm129': (r, t) {
    final e = g129.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm130': (r, t) {
    final e = g130.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm131': (r, t) {
    final e = g131.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm132': (r, t) {
    final e = g132.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm133': (r, t) {
    final e = g133.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm134': (r, t) {
    final e = g134.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm135': (r, t) {
    final e = g135.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm136': (r, t) {
    final e = g136.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm137': (r, t) {
    final e = g137.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm138': (r, t) {
    final e = g138.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm139': (r, t) {
    final e = g139.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm140': (r, t) {
    final e = g140.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm141': (r, t) {
    final e = g141.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm142': (r, t) {
    final e = g142.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm143': (r, t) {
    final e = g143.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'm145': (r, t) {
    final e = g145.SuperDot3(rules: r, topRuleName: t);
    return e.recover;
  },
  'r1': (r, t) => r1.Squirrel(rules: r, topRuleName: t).recover,
  'r2': (r, t) => r2.Squirrel(rules: r, topRuleName: t).recover,
  'r3': (r, t) => r3.Squirrel(rules: r, topRuleName: t).recover,
};

Build? resolve(String name) {
  if (extra.containsKey(name)) return extra[name];
  for (final e in engines) {
    if (e.name == name) {
      // `.root` is already the full-coverage tree over the ORIGINAL input.
      return (r, t) {
        final made = e.make(r, t);
        return (String s) => made.$1(s).root;
      };
    }
  }
  return null;
}

void main(List<String> argv) {
  if (argv.isEmpty) {
    print('usage: dart run _score1.dart <engineName>');
    return;
  }
  final name = argv[0];
  final build = resolve(name);
  if (build == null) {
    print('$name UNKNOWN');
    return;
  }

  final cases = weighted(buildBattery());
  final byCorpus = <String, Corpus>{for (final c in corpora) c.name: c};
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };

  // Expectations come from the FROZEN parser reading the UNDAMAGED document, so
  // no engine can be tuned toward them. [expectedFor] then adjusts them for the
  // one category where the damage removes text outright rather than corrupting
  // it -- see the note on that function.
  final original = <String, MatchResult>{};
  for (final c in corpora) {
    for (final doc in c.documents) {
      final r =
          Parser(rules: rulesOf[c.name]!, topRuleName: c.top, input: doc).parse();
      if (r.hasSyntaxErrors) {
        throw StateError('corpus ${c.name}: document does not parse: $doc');
      }
      original['${c.name} $doc'] = r.root;
    }
  }

  // One engine per grammar, reused across that grammar's cases -- the official
  // protocol. Constructing per case would price the grammar lowering 1824 times.
  final made = <String, MatchResult? Function(String)>{};
  for (final c in corpora) {
    made[c.name] = build(rulesOf[c.name]!, c.top);
  }

  final catScore = <String, double>{};
  final catN = <String, int>{};
  var crashed = 0, uncovered = 0, perfect = 0;
  double total = 0;

  // THE CLOCK COVERS THE ENGINE AND NOTHING ELSE. It used to span [scoreCase]
  // too, which prices the evaluator's tree walk as though the engine had spent
  // it -- the same class of error as measuring two arms on different clocks.
  final sw = Stopwatch();
  for (final k in cases) {
    final c = byCorpus[k.grammar]!;
    MatchResult? produced;
    sw.start();
    try {
      produced = made[k.grammar]!(k.mutant);
    } catch (_) {
      produced = null;
    }
    sw.stop();
    final s = scoreCase(
      produced: produced,
      expected: expectedFor(k, original['${k.grammar} ${k.original}']!, c.named),
      inputLen: k.mutant.length,
      named: c.named,
    );
    if (s.crashed) crashed++;
    if (!s.covered) uncovered++;
    if (s.score == 1.0) perfect++;
    total += s.score;
    catScore[k.category] = (catScore[k.category] ?? 0) + s.score;
    catN[k.category] = (catN[k.category] ?? 0) + 1;
  }
  // One machine-readable line: name, aggregate, perfect%, crashed, uncovered,
  // ms, then category=mean pairs.
  final cats = catN.keys.toList()
    ..sort((a, b) => categoryWeight[b]!.compareTo(categoryWeight[a]!));
  final parts = [
    name,
    (total / cases.length).toStringAsFixed(4),
    (perfect / cases.length * 100).toStringAsFixed(1),
    '$crashed',
    '$uncovered',
    '${sw.elapsedMilliseconds}',
    for (final k in cats) '$k=${(catScore[k]! / catN[k]!).toStringAsFixed(3)}',
  ];
  print(parts.join(' '));
}
