// ONE harness for the full trade-off table: EVERY engine ever built -- sd3/sd5/v6,
// the shipped `dot`, and m12 through m40 -- measured on every metric in a single
// process so no number is recalled from a previous session's notes.
//
// CAVEAT, and it is why the isolated numbers exist: a single process warms as it
// goes, so an engine registered LATE looks faster than the same engine registered
// FIRST (measured: 377 vs 314 battms for m26). This table is for the correctness
// and shape columns, which are order-independent. For a timing A/B, run one engine
// per process by passing its name.
//
// Adding an engine: register it here AND add its row to LESSONS_LEARNED.md 5j.
//
// Five metric groups, each of which can independently disqualify an engine:
//   battery  -- shape / cover / cost histogram / crashes on the 519 mutants
//   valid    -- the 7 well-formed documents must come back untouched
//   latency  -- 12 synthetic cases, min-of-5, all engines alternating per case
//   truth    -- agreement with brute-force minimum edit distance (5 grammars)
//   depth    -- the input length at which native recursion overflows the stack
import 'dart:math';
import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/parser/combinators.dart';
import 'package:squirrel_parser/src/parser/match_result.dart';
import 'package:squirrel_parser/src/recovery/dot_recovery.dart';
import 'package:squirrel_parser/src/recovery/skip_recovery.dart' show SkipResult;
import 'sd3.dart' as g3;
import 'sd5.dart' as g5;
import 'sd6.dart' as g6;
import 'm12.dart' as g12;
import 'm33.dart' as g33;
import 'm34.dart' as g34;
import 'm15.dart' as g15;
import 'm16.dart' as g16;
import 'm17.dart' as g17;
import 'm18.dart' as g18;
import 'm19.dart' as g19;
import 'm20.dart' as g20;
import 'm21.dart' as g21;
import 'm22.dart' as g22;
import 'm23.dart' as g23;
import 'm24.dart' as g24;
import 'm25.dart' as g25;
import 'm26.dart' as g26;
import 'm29.dart' as g29;
import 'm30.dart' as g30;
import 'm31.dart' as g31;
import 'm32.dart' as g32;
import 'm35.dart' as g35;
import 'm36.dart' as g36;
import 'm37.dart' as g37;
import 'm38.dart' as g38;
import 'm39.dart' as g39;
import 'm40.dart' as g40;
import 'm27.dart' as g27;
import 'm28.dart' as g28;

const String jsonGrammar = '''
JSON <- WS Value WS;
Value <- Object / Array / String / Number / Boolean / Null;
Object <- '{' WS (Member (WS ',' WS Member)*)? WS '}';
Member <- String WS ':' WS Value;
Array <- '[' WS (Value (WS ',' WS Value)*)? WS ']';
String <- '"' Character* '"';
Character <- [^"\\\\] / ('\\\\' Escape);
Escape <- '"' / '\\\\' / '/' / 'b' / 'f' / 'n' / 'r' / 't' / ('u' [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F]);
Number <- Integer Fraction? Exponent?;
Integer <- '-'? (([1-9] [0-9]+) / [0-9]);
Fraction <- '.' [0-9]+;
Exponent <- ("e" / "E") ("+" / "-")? [0-9]+;
Boolean <- "true" / "false";
Null <- "null";
~WS <- [ \\t\\n\\r]*;
''';

const structural = <String>{
  'Object', 'Array', 'Member', 'String', 'Number', 'Boolean', 'Null', 'Value',
};

String treeShape(MatchResult r) {
  final sb = StringBuffer();
  void walk(MatchResult m) {
    final c = m.clause;
    if (c is Ref && structural.contains(c.ruleName)) {
      sb.write('${c.ruleName}(');
      m.subClauseMatches.forEach(walk);
      sb.write(')');
    } else {
      m.subClauseMatches.forEach(walk);
    }
  }

  walk(r);
  return sb.toString();
}

bool covers(MatchResult root, int len) {
  var pos = 0;
  var ok = true;
  void walk(MatchResult m) {
    if (!ok) return;
    if (m is SyntaxError || m.subClauseMatches.isEmpty) {
      if (m.len == 0) return;
      if (m.pos != pos) ok = false;
      pos = m.pos + m.len;
      return;
    }
    m.subClauseMatches.forEach(walk);
  }

  walk(root);
  return ok && pos == len;
}

/// One engine, behind the uniform surface every variant happens to share.
class Eng {
  Eng(this.name, this.loc, this.make, {this.bugs = '-'});
  final String name;
  final int loc;

  /// Known defects SPECIFIC to this engine, as comma-separated tags expanded in
  /// the legend below. Four defects are shared by EVERY engine in the table and
  /// are deliberately not repeated per row -- see `sharedBugs`.
  final String bugs;

  /// Builds a fresh engine over `rules`/`top`, returning (recover, cost, costOnly).
  final (SkipResult Function(String), int Function(), int Function(String))
      Function(Map<String, Clause>, String) make;
}

/// Defects every engine in this table has, from `dot` onward. Listing them in the
/// per-engine column would fill it with the same four tags on every row.
const sharedBugs = <String>[
  'PEG   repairs toward the CFG reading of the grammar, not the PEG one:  a '
      'possessive `*` and a committed `/` are both treated as if any\n'
      '      alternative/stop were available. 4 of 5 conformance cases wrong, '
      'identically, in every engine back to `dot` (LESSONS 5b). The\n'
      '      `cost` column cannot see it -- its grammars are prefix-disjoint, '
      'so the CFG and PEG readings coincide there.',
  'RR    right-recursive grammars overflow the native stack (the RRmax column). '
      'Inherited from the pure parser, which shows the same\n'
      '      asymmetry; recovery worsens the threshold ~4x because its descent '
      'adds frames per position. Fix is an explicit worklist.',
  'd13   `del@13` and `swap@13` of the battery document are never recovered to '
      'the original shape, which is the 517/519 ceiling.',
  'K40   `maxCost` is a hard search ceiling (default 40). A repair costing more '
      'is not found at all: cost -1, and the whole input is\n'
      '      reported as one error span. It is the only tuning parameter left '
      'in the m-line.',
];

/// Tags used in the per-engine `bugs` column. Every tag here is either visible
/// in a column of the table below or cites the measurement that found it.
const bugLegend = <String, String>{
  'LR': 'NON-MINIMAL REPAIRS ON LEFT-RECURSIVE GRAMMARS. The memo cached its own '
      'in-progress placeholder as a final answer, so the\n'
      '        left-recursive alternative contributed nothing: cost 2-3 where the '
      'truth is 1, and from n>=512 no repair at all (-1).\n'
      '        Visible in the `cost` column -- 32-38/44 against 44/44. Fixed by '
      'A5 in m23.',
  'null': 'RECONSTRUCTION DIVERGES ON NULLABLE LEFT RECURSION. `E <- E N` with N '
      'nullable re-derives E over the same extent at zero\n'
      '        extra Delta, so the Delta-exact descent takes that cycle forever '
      '(StackOverflowError). Visible in `tree` (42/44 while\n'
      '        `cost` is 44/44 -- the cost is right and the witness cannot be '
      'built). Fixed by the Ref re-entry guard in m24.',
  'empty': 'RangeError on empty input: the leading-span loop ran to the budget '
      'without bounding by input length. Found only because a\n'
      '        degenerate-input gate was written separately from the mutation '
      'battery, which can never produce the empty string.',
  'shape': 'loses shape points against the 517/519 line -- see the `shape` '
      'column. Not a crash; a worse tree on inputs the better\n'
      '        engines get right.',
  'slow': 'far off the pace on `battms` and/or `latms`; kept as a recorded '
      'negative, not as a candidate.',
  'batt': '20-35% slower on the battery than m26 (which is all K=1), because a '
      'complete CFG level 0 replaces m26\'s O(1) oracle call.\n'
      '        Buys latency and large-K time back; the trade is real in both '
      'directions.',
  'stack': 'stack ceiling collapses -- see `LRmax`/`RRmax`. m30/m31 fail below '
      '512 on BOTH recursion directions.',
  'latent': 'A WRONG-COST DEFECT SITS BEHIND A FLAG. m31 splits reach-cost from '
      'complete-cost; with `debugShortcut(true)` it reports\n'
      '        cost 4 on JSON repairs whose truth is 1, because the split removes '
      'the recomputation that was silently repairing m26\'s\n'
      '        greedy level 0. Committed with the shortcut OFF, which is why the '
      'row scores 44/44 and is 15x slower than m26.',
  'pegfix': 'ATTEMPTS THE PEG FIX AND PAYS FOR IT. The guard consults the '
      'ORIGINAL input, but PEG semantics quantify over the REPAIRED\n'
      '        string, so it rejects legitimate repairs: m27 494/519 with hist '
      '{1:478, 2:41}, m29 492/519 with {1:474, 2:45} and cost\n'
      '        42/44. Not fixable by a better local predicate (LESSONS 5e).',
  'over': 'the doubling deepening schedule overshoots whenever K is not a power '
      'of two, running budget 2K instead of K and paying ~5x\n'
      '        for it -- the `latms` column, 1071 against m26\'s 249.',
  'noop': 'DOES NOT DO WHAT IT WAS BUILT FOR. m36 guards PEG semantics at budget '
      '0 only; round 0 rejects the illegal parse but it costs\n'
      '        ZERO edits and resurfaces at round 1 where the guard is off, so '
      'conformance is unchanged (LESSONS 5i).',
  'LOC': 'not a defect: a regression on the LOC column against m26\'s 382.',
  'dup': 'not an engine: m26 registered a SECOND time, at the end, to measure '
      'how much the warming heap flatters a late row.',
};

final engines = <Eng>[
  Eng('dot', 797, (r, t) {
    final e = DotRecovery(rules: r, topRuleName: t);
    return (e.recover, () => e.lastTotalCost, (s) => (e.recover(s), e.lastTotalCost).$2);
  }, bugs: 'slow,shape'),
  Eng('sd3', 499, (r, t) {
    final e = g3.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'LR,empty'),
  Eng('sd5', 513, (r, t) {
    final e = g5.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'LR,empty'),
  Eng('v6', 526, (r, t) {
    final e = g6.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'LR'),
  Eng('m12', 396, (r, t) {
    final e = g12.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'LR,shape'),
  Eng('m15', 406, (r, t) {
    final e = g15.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'LR'),
  Eng('m16', 352, (r, t) {
    final e = g16.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'LR'),
  Eng('m17', 357, (r, t) {
    final e = g17.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'LR'),
  Eng('m18', 373, (r, t) {
    final e = g18.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'LR'),
  Eng('m19', 362, (r, t) {
    final e = g19.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'LR'),
  Eng('m20', 350, (r, t) {
    final e = g20.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'LR,slow'),
  Eng('m21', 361, (r, t) {
    final e = g21.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'LR,slow'),
  Eng('m22', 337, (r, t) {
    final e = g22.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'LR'),
  Eng('m23', 371, (r, t) {
    final e = g23.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'null'),
  Eng('m24', 393, (r, t) {
    final e = g24.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),
  Eng('m25', 394, (r, t) {
    final e = g25.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),
  Eng('m26', 382, (r, t) {
    final e = g26.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),
  Eng('m27', 387, (r, t) {
    final e = g27.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'pegfix'),
  Eng('m28', 384, (r, t) {
    final e = g28.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'over'),
  Eng('m29', 390, (r, t) {
    final e = g29.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'pegfix,slow,stack'),

  Eng('m30', 382, (r, t) {
    final e = g30.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'slow,stack,shape'),

  Eng('m31', 388, (r, t) {
    final e = g31.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'slow,stack,latent'),

  Eng('m32', 378, (r, t) {
    final e = g32.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'batt'),

  Eng('m33', 389, (r, t) {
    final e = g33.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'slow'),

  Eng('m34', 381, (r, t) {
    final e = g34.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'slow,shape'),

  Eng('m35', 381, (r, t) {
    final e = g35.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'batt'),

  Eng('m36', 390, (r, t) {
    final e = g36.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'noop'),

  Eng('m37', 385, (r, t) {
    final e = g37.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),

  Eng('m38', 407, (r, t) {
    final e = g38.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'LOC'),

  Eng('m39', 396, (r, t) {
    final e = g39.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }),

  Eng('m40', 429, (r, t) {
    final e = g40.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'LOC'),

  Eng('m26b', 382, (r, t) {
    final e = g26.SuperDot3(rules: r, topRuleName: t);
    return (e.recover, () => e.lastCost, e.recoverCost);
  }, bugs: 'dup'),
];

// ---------------------------------------------------------------- ground truth
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
          if (seen.add(c.substring(0, i) + ch + c.substring(i))) {
            next.add(c.substring(0, i) + ch + c.substring(i));
          }
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

final truthCases = <(String, String, String, List<String>)>[
  (
    "E <- E '+' T / T;\nT <- T '*' F / F;\nF <- [0-9];\n",
    'E',
    '0+*',
    ['1+2', '1++2', '1+', '+1', '1*', '1+2++3', '1 + 2', '', '++', '1+2*'],
  ),
  (
    "E <- T '+' E / T;\nT <- F '*' T / F;\nF <- [0-9];\n",
    'E',
    '0+*',
    ['1+2', '1++2', '1+', '+1', '1*', '1+2++3', '1 + 2', '', '++', '1+2*'],
  ),
  (
    "E <- A / F;\nA <- B '+' F;\nB <- E;\nF <- [0-9];\n",
    'E',
    '0+',
    ['1+2', '1++2', '1+', '+1', '1+2+3', '', '++', '1+2+'],
  ),
  (
    "E <- E N / F;\nN <- '-'?;\nF <- [0-9];\n",
    'E',
    '0-',
    ['1', '1-', 'x', '1--', '', '11'],
  ),
  (
    "V <- O / A / N;\nO <- '{' (M (',' M)*)? '}';\nM <- N ':' V;\n"
        "A <- '[' (V (',' V)*)? ']';\nN <- [0-9];\n",
    'V',
    '0{}[],:',
    ['0', '{0:0}', '{0:0', '{0:}', '[0,]', '[0 0]', '{}}', '', '[[0]', '{0:0,}'],
  ),
];

// ------------------------------------------------------------------------ main
void main(List<String> args) {
  // Comma-separated engine names keep an iteration under a minute; with no
  // argument every engine runs, which is the table that gets reported.
  if (args.isNotEmpty) {
    final keep = args.first.split(',').toSet();
    engines.retainWhere((e) => keep.contains(e.name));
  }
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';
  bool parses(String s) =>
      !Parser(rules: rules, topRuleName: 'JSON', input: s).parse().hasSyntaxErrors;

  // ---- the 519-mutant battery
  final mutants = <String>[];
  for (var j = 0; j < base.length; j++) {
    mutants.add(base.substring(0, j) + base.substring(j + 1));
    if (j + 1 < base.length && base[j] != base[j + 1]) {
      mutants.add(
          base.substring(0, j) + base[j + 1] + base[j] + base.substring(j + 2));
    }
  }
  for (var j = 0; j <= base.length; j++) {
    for (final c in ['Q', 'z', '}', '"', ',', '5']) {
      mutants.add(base.substring(0, j) + c + base.substring(j));
      if (j < base.length && base[j] != c) {
        mutants.add(base.substring(0, j) + c + base.substring(j + 1));
      }
    }
  }
  final battery = mutants.where((m) => !parses(m)).toList();
  final origShape = treeShape(
      Parser(rules: rules, topRuleName: 'JSON', input: base).parse().root);

  const validDocs = [
    '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}',
    '[]',
    '{}',
    '  [1, 2, [3, {"x": -4.5e+6}], false, null]  ',
    '{"s":"a\\\\u00ffb\\\\n\\\\t","n":-0.5,"deep":{"a":{"b":{"c":[[[1]]]}}}}',
    '"just a string"',
    '0',
  ];

  // ---- latency cases (identical to gen_cmp.dart so numbers stay comparable)
  final big = '{"users":[{"id":1,"name":"ann","tags":["x","y"]},'
      '{"id":2,"name":"bob","tags":["z"]},{"id":3,"name":"cyd","tags":[]}],'
      '"total":3,"ok":true}';
  final latCases = <String>[];
  for (final k in [4, 16, 64]) {
    latCases.add(big.substring(0, 30) + big.substring(30 + k));
    latCases.add(big.substring(0, 30) + ('@' * k) + big.substring(30));
    final ch = big.substring(30, 30 + k).split('')..shuffle(Random(12345 + k));
    latCases.add(big.substring(0, 30) + ch.join() + big.substring(30 + k));
  }
  for (final k in [4, 16, 64]) {
    final it = [for (var i = 0; i < k; i++) '{"id":$i,"name":"n$i","ok":true}'];
    final d = '{"items":[${it.join(',')}],"total":$k}';
    final mid = d.length ~/ 2;
    latCases.add('${d.substring(0, mid)}Q${d.substring(mid + 1)}');
  }

  // ---- stack-depth probe grammars
  final depthLR = MetaGrammar.parseGrammar(
      "E <- E '+' T / T;\nT <- T '*' F / F;\nF <- [0-9] / '(' E ')';\n");
  final depthRR = MetaGrammar.parseGrammar(
      "E <- T '+' E / T;\nT <- F '*' T / F;\nF <- [0-9] / '(' E ')';\n");
  String oneErr(int k) {
    final c = List.generate(k, (i) => '${i % 10}').join('+');
    return '${c.substring(0, c.length ~/ 2)}+${c.substring(c.length ~/ 2)}';
  }

  /// Largest n from `sizes` that completes without overflowing, as ">=hi" or "<lo".
  String depthLimit(Eng e, Map<String, Clause> g, List<int> sizes) {
    var last = 'none';
    for (final k in sizes) {
      final s = oneErr(k);
      try {
        final (_, _, cost) = e.make(g, 'E');
        cost(s);
        last = '${s.length}';
      } on StackOverflowError {
        return last == 'none' ? '<${s.length}' : last;
      } catch (_) {
        return last == 'none' ? 'err' : last;
      }
    }
    return '>=$last';
  }

  // ---- run everything, one engine at a time for battery/valid/truth/depth,
  //      but latency interleaved per case across all engines.
  print('battery=${battery.length}  valid=${validDocs.length}  '
      'latency cases=${latCases.length}');

  final lat = <String, List<double>>{for (final e in engines) e.name: []};
  final built = <String, (SkipResult Function(String), int Function(), int Function(String))>{
    for (final e in engines) e.name: e.make(rules, 'JSON')
  };
  for (final m in latCases) {
    for (final e in engines) {
      final (_, _, cost) = built[e.name]!;
      var t = double.infinity;
      for (var i = 0; i < 5; i++) {
        final sw = Stopwatch()..start();
        try {
          cost(m);
        } catch (_) {
          t = -1;
          break;
        }
        t = min(t, sw.elapsedMicroseconds / 1000);
      }
      lat[e.name]!.add(t);
    }
  }

  final rows = <List<String>>[];
  for (final e in engines) {
    // battery
    final (rec, cost, _) = e.make(rules, 'JSON');
    var shape = 0, cov = 0, crash = 0;
    final hist = <int, int>{};
    final sw = Stopwatch()..start();
    for (final m in battery) {
      SkipResult r;
      try {
        r = rec(m);
      } catch (_) {
        crash++;
        continue;
      }
      hist[cost()] = (hist[cost()] ?? 0) + 1;
      if (covers(r.root, m.length)) cov++;
      if (treeShape(r.root) == origShape) shape++;
    }
    sw.stop();
    final h = Map.fromEntries(hist.entries.toList()..sort((a, b) => a.key - b.key));

    // valid
    final (rec2, cost2, _) = e.make(rules, 'JSON');
    var clean = 0;
    for (final d in validDocs) {
      try {
        final r = rec2(d);
        if (cost2() == 0 && r.errorSpans.isEmpty && r.missing.isEmpty) clean++;
      } catch (_) {}
    }

    // ground truth. Two separate claims, and conflating them hides a real
    // difference: `tOk` is only that the COST is minimal, `rOk` is that the
    // witness tree can actually be rebuilt and covers the input. m23 passes the
    // first and diverges on the second.
    var tOk = 0, tTot = 0, rOk = 0;
    for (final (g, top, alpha, inputs) in truthCases) {
      final gr = MetaGrammar.parseGrammar(g);
      final (r3, _, c3) = e.make(gr, top);
      for (final s in inputs) {
        tTot++;
        final want = trueDistance(gr, top, s, alpha, 3);
        try {
          if (want != null && c3(s) == want) tOk++;
        } catch (_) {}
        try {
          if (covers(r3(s).root, s.length)) rOk++;
        } catch (_) {}
      }
    }

    final total = lat[e.name]!.fold(0.0, (a, b) => a + max(b, 0));
    rows.add([
      e.name,
      '${e.loc}',
      '$shape/${battery.length}',
      '$cov/${battery.length}',
      '$crash',
      h.toString(),
      '$clean/${validDocs.length}',
      '$tOk/$tTot',
      '$rOk/$tTot',
      e.bugs,
      '${sw.elapsedMilliseconds}',
      total.toStringAsFixed(1),
      '', // /v6, filled once v6's total is known
      depthLimit(e, depthLR, [256, 512, 1024, 2048]),
      depthLimit(e, depthRR, [256, 512, 1024, 2048]),
    ]);
    print('  ...${e.name} done');
  }

  // The /v6 column is a ratio to the baseline, so it only exists when the
  // baseline was one of the engines run.
  final v6 = lat['v6']?.fold(0.0, (a, b) => a + max(b, 0));
  for (var i = 0; i < engines.length; i++) {
    final t = lat[engines[i].name]!.fold(0.0, (a, b) => a + max(b, 0));
    rows[i][12] = v6 == null ? '-' : '${(t / v6).toStringAsFixed(2)}x';
  }

  const head = ['engine', 'LOC', 'shape', 'cover', 'crsh', 'cost hist', 'valid',
    'cost', 'tree', 'bugs', 'battms', 'latms', '/v6', 'LRmax', 'RRmax'];
  final w = [
    for (var c = 0; c < head.length; c++)
      [head[c].length, for (final r in rows) r[c].length].reduce(max)
  ];
  String fmt(List<String> r) =>
      [for (var c = 0; c < r.length; c++) r[c].padLeft(w[c])].join(' ');
  print('\n${fmt(head)}');
  for (final r in rows) {
    print(fmt(r));
  }
  print('\nshape/cover/costhist/battms: 519-mutant battery.  cost: agreement '
      'with\nbrute-force minimum edit distance over 5 grammars (44 cases).  '
      'tree: the witness\nrebuilds and covers the input on those same 44.  latms: '
      'sum of 12 latency\ncases, min-of-5, interleaved.  LRmax/RRmax: largest '
      '1-error input length that\ncompletes without StackOverflowError '
      '(">=4096" means it never overflowed).');

  // The bugs column, expanded. Tags name defects specific to one engine; the
  // shared list names the four every engine in the table has, which would
  // otherwise repeat on every row.
  final used = <String>{for (final e in engines) ...e.bugs.split(',')}
    ..remove('-');
  if (used.isNotEmpty) {
    print('\nbugs -- per-engine:');
    for (final tag in bugLegend.keys.where(used.contains)) {
      print('  ${tag.padRight(5)} ${bugLegend[tag]}');
    }
  }
  print('\nbugs -- shared by EVERY engine below, so not repeated per row:');
  for (final b in sharedBugs) {
    print('  $b');
  }
  print('\nUNPROVEN, not a measured bug: the left-recursion fixed point in every\n'
      'A5 engine (m23 onward) re-runs until no Delta improves, and that iteration\n'
      'count has no tight polynomial bound in the derivation -- only the '
      'measurement\nthat it behaves like a small constant.');
}
