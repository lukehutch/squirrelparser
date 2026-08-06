// Head-to-head: every repair engine on the SAME battery.
//
// Usage: dart d_allengines.dart <engine>
// One engine per process, so a hang or blow-up in one does not cost the others.
//
// Battery = the 519 unparseable single-edit mutants of the JSON doc (del, ins,
// sub, swap at every position). Generator and treeShape/covers are copied
// verbatim from d_skip_sweep.dart so the numbers are comparable to every
// earlier measurement in this work.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/recovery/skip_recovery.dart';
import 'package:squirrel_parser/src/recovery/semiring_recovery.dart';
import 'package:squirrel_parser/src/recovery/agenda_recovery.dart';
import 'package:squirrel_parser/src/recovery/frontier_recovery.dart';
import 'package:squirrel_parser/src/recovery/dot_recovery.dart';
import 'package:squirrel_parser/src/recovery/repair_search.dart';

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

const structuralRules = {
  'JSON', 'Value', 'Object', 'Array', 'Member',
  'String', 'Number', 'Boolean', 'Null'
};

String treeShape(MatchResult r) {
  final sb = StringBuffer();
  void walk(MatchResult m) {
    final clause = m.clause;
    if (clause is Ref && structuralRules.contains(clause.ruleName)) {
      sb.write('${clause.ruleName}(');
      m.subClauseMatches.forEach(walk);
      sb.write(')');
    } else {
      m.subClauseMatches.forEach(walk);
    }
  }

  walk(r);
  return sb.toString();
}

// Leaf-coverage check: terminals + spans must tile [0, len) in order.
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

/// What one engine produced for one mutant.
/// [root] is null when the engine declined to produce a repair at all.
/// [coverable] is false for engines whose tree spans a rewritten string rather
/// than the mutant itself, so the tiling invariant does not apply.
class Out {
  final MatchResult? root;
  final bool coverable;
  Out(this.root, {this.coverable = true});
}

void main(List<String> argv) {
  const doc = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  final name = argv.isEmpty ? 'dot' : argv[0];

  Out Function(String) run;
  switch (name) {
    case 'skip':
      final e = SkipRecovery(rules: rules, topRuleName: 'JSON');
      run = (s) => Out(e.recover(s).root);
    case 'semiring':
      final e = SemiringRecovery(rules: rules, topRuleName: 'JSON');
      run = (s) => Out(e.recover(s).root);
    case 'agenda':
      final e = AgendaRecovery(rules: rules, topRuleName: 'JSON');
      run = (s) => Out(e.recover(s).root);
    case 'frontier':
      final e = FrontierRecovery(rules: rules, topRuleName: 'JSON');
      run = (s) => Out(e.recover(s).root);
    // One DotRecovery, six objectives. Each runs in its own process so the
    // timings are not polluted by another configuration's JIT warm-up.
    case 'dot':
    case 'dot-r2': // SHIPPED DEFAULT: (cost, regret), fab priced as a claim
      final e = DotRecovery(rules: rules, topRuleName: 'JSON');
      run = (s) => Out(e.recover(s).root);
    case 'dot-scalar': // the same objective as ONE INTEGER: cost*M + regret
      scalarMode = 1;
      final e = DotRecovery(rules: rules, topRuleName: 'JSON');
      run = (s) => Out(e.recover(s).root);
    case 'dot-r3b': // (cost, fabSize, regret)
      tieMode = 53;
      fabRegretMode = 0;
      final e = DotRecovery(rules: rules, topRuleName: 'JSON');
      run = (s) => Out(e.recover(s).root);
    case 'dot-r3': // (cost, regret, fabSize)
      tieMode = 47;
      fabRegretMode = 0;
      final e = DotRecovery(rules: rules, topRuleName: 'JSON');
      run = (s) => Out(e.recover(s).root);
    case 'dot-4tier': // retired: (cost, dataBits, classBits, fabSize)
      tieMode = 43;
      fabRegretMode = 0;
      final e = DotRecovery(rules: rules, topRuleName: 'JSON');
      run = (s) => Out(e.recover(s).root);
    case 'dot-old': // retired: (cost, diameter, fabSize, classBits)
      tieMode = 13;
      fabRegretMode = 0;
      final e = DotRecovery(rules: rules, topRuleName: 'JSON');
      run = (s) => Out(e.recover(s).root);
    case 'search':
      final e = RepairSearch(rules: rules, topRuleName: 'JSON');
      run = (s) {
        final r = e.repair(s);
        return Out(r?.parseResult.root, coverable: false);
      };
    default:
      print('unknown engine: $name');
      return;
  }

  bool parses(String s) =>
      !Parser(rules: rules, topRuleName: 'JSON', input: s).parse().hasSyntaxErrors;
  final origShape =
      treeShape(Parser(rules: rules, topRuleName: 'JSON', input: doc).parse().root);

  final mutants = <(String, String, String)>[]; // (kind, desc, mutant)
  for (var j = 0; j < doc.length; j++) {
    mutants.add(('del', 'del@$j(${doc[j]})', doc.substring(0, j) + doc.substring(j + 1)));
    if (j + 1 < doc.length && doc[j] != doc[j + 1]) {
      mutants.add(
          ('swap', 'swap@$j', doc.substring(0, j) + doc[j + 1] + doc[j] + doc.substring(j + 2)));
    }
  }
  for (var j = 0; j <= doc.length; j++) {
    for (final c in ['Q', 'z', '}', '"', ',', '5']) {
      mutants.add(('ins', 'ins@$j($c)', doc.substring(0, j) + c + doc.substring(j)));
      if (j < doc.length && doc[j] != c) {
        mutants.add(
            ('sub', 'sub@$j(${doc[j]}->$c)', doc.substring(0, j) + c + doc.substring(j + 1)));
      }
    }
  }

  // Sanity: the valid doc must round-trip to the original shape.
  try {
    final c = run(doc);
    final sane = c.root != null && treeShape(c.root!) == origShape;
    print('$name: valid-doc sanity ${sane ? "OK" : "FAIL"}');
  } catch (e) {
    print('$name: valid-doc sanity THREW $e');
  }

  var tested = 0, ok = 0, noRepair = 0, threw = 0, coverFail = 0;
  final byKindTested = <String, int>{};
  final byKindOk = <String, int>{};
  final sw = Stopwatch()..start();
  var timeMs = 0;
  for (final (kind, desc, m) in mutants) {
    if (parses(m)) continue;
    tested++;
    byKindTested[kind] = (byKindTested[kind] ?? 0) + 1;
    final t0 = sw.elapsedMicroseconds;
    Out? r;
    try {
      r = run(m);
    } catch (e) {
      threw++;
      print('  THREW $desc: $e');
    }
    timeMs += ((sw.elapsedMicroseconds - t0) / 1000).round();
    if (r == null) continue;
    if (r.root == null) {
      noRepair++;
      continue;
    }
    if (r.coverable && !covers(r.root!, m.length)) coverFail++;
    if (treeShape(r.root!) == origShape) {
      ok++;
      byKindOk[kind] = (byKindOk[kind] ?? 0) + 1;
    }
  }

  final pct = (100 * ok / tested).toStringAsFixed(1);
  print('RESULT $name  shape=$ok/$tested ($pct%)  '
      'total=${timeMs}ms  avg=${(timeMs / tested).toStringAsFixed(2)}ms  '
      'noRepair=$noRepair  threw=$threw  coverFail=$coverFail');
  final parts = <String>[];
  for (final k in ['ins', 'sub', 'del', 'swap']) {
    parts.add('$k ${byKindOk[k] ?? 0}/${byKindTested[k] ?? 0}');
  }
  print('  by kind: ${parts.join('  ')}');
}
