// Re-checks every deterministic measured number quoted in squirrel_parser.tex.
// Run from the dart/ package directory:
//   dart --packages=.dart_tool/package_config.json ../paper/verification/verify_paper_numbers.dart
// Timing figures in the paper (ms/s) are environment-dependent and are not asserted here.

import 'dart:math' show Random;

import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/recovery/recovery.dart';

int _failures = 0;

void check(String what, Object actual, Object expected) {
  final ok = '$actual' == '$expected';
  if (!ok) _failures++;
  print('${ok ? "PASS" : "FAIL"}  $what: actual=$actual expected=$expected');
}

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

const structuralRules = {'JSON', 'Value', 'Object', 'Array', 'Member', 'String', 'Number', 'Boolean', 'Null'};

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

int workFor(Map<String, Clause> rules, String top, String input) {
  parserStats = ParserStats();
  final r = Parser(rules: rules, topRuleName: top, input: input).parse();
  final w = parserStats!.totalWork;
  parserStats = null;
  if (r.hasSyntaxErrors) throw StateError('input unexpectedly invalid');
  return w;
}

/// Same deterministic JSON generator as the paper's linearity benchmark.
String makeJson(int size) {
  final rng = Random(12345);
  final sb = StringBuffer('{');
  var first = true;
  var k = 0;
  while (sb.length < size - 16) {
    if (!first) sb.write(',');
    first = false;
    sb.write('"k$k":');
    switch (rng.nextInt(4)) {
      case 0:
        sb.write(rng.nextInt(100000));
      case 1:
        sb.write('"v${rng.nextInt(1000)}str"');
      case 2:
        sb.write('[${rng.nextInt(10)},${rng.nextInt(10)},true,null]');
      case 3:
        sb.write('{"n":${rng.nextInt(100)},"m":"x"}');
    }
    k++;
  }
  sb.write('}');
  return sb.toString();
}

void main() {
  final json = MetaGrammar.parseGrammar(jsonGrammar);

  // ---- Table "jsonlinearity": work per char for valid JSON (Sec. Measured linearity).
  const expectedJson = {987: 1933, 1997: 3792, 3993: 7269, 8000: 14485, 15994: 28793, 31987: 56563};
  for (final size in [1000, 2000, 4000, 8000, 16000, 32000]) {
    final doc = makeJson(size);
    final w = workFor(json, 'JSON', doc);
    check('JSON linearity n=${doc.length} work', w, expectedJson[doc.length]!);
  }

  // ---- Table "adversarial", left half: expression grammar work.
  final expr = MetaGrammar.parseGrammar("E <- E '+' N / N ; N <- [0-9]+ ;");
  const expectedExpr = {999: 1002, 1999: 2002, 3999: 4002, 7999: 8002, 15999: 16002};
  for (final n in [500, 1000, 2000, 4000, 8000]) {
    final input = List.filled(n, '1').join('+');
    check('Expr grammar n=${input.length} work', workFor(expr, 'E', input), expectedExpr[input.length]!);
  }

  // ---- Table "adversarial", right half: quadratic lookahead-over-LR grammar.
  final adv = MetaGrammar.parseGrammar("S <- (&E 'x' S) / 'x' ; E <- E 'x' / 'x' ;");
  const expectedAdv = {250: 31877, 500: 126252, 1000: 502502, 2000: 2005002};
  for (final n in [250, 500, 1000, 2000]) {
    check('Adversarial grammar n=$n work', workFor(adv, 'S', 'x' * n), expectedAdv[n]!);
  }

  // ---- Expansion-semantics examples (Sec. Expansion semantics / Granularity).
  final ex1 = MetaGrammar.parseGrammar("A <- B / 'x' ; B <- (A 'y') / (A 'x') ;");
  final r1 = Parser(rules: ex1, topRuleName: 'A', input: 'xxyx').parse();
  check('Granularity example xxyx full match', '${!r1.hasSyntaxErrors}/${r1.root.len}', 'true/4');

  final ex2 = MetaGrammar.parseGrammar("A <- (B !'y') / 'x' ; B <- A 'x' ;");
  final r2 = Parser(rules: ex2, topRuleName: 'A', input: 'xxxy').parse();
  check('Semantics example xxxy matches len 2', '${r2.hasSyntaxErrors}/${r2.root.len}', 'true/2');

  // ---- Figure LeftRecTypes: all nine examples parse fully.
  final figs = <(String, String, String, String, int)>[
    ('(a)', "A <- (A 'x') / 'x';", 'A', 'xxx', 3),
    ('(b)', "A <- B / 'x'; B <- (A 'y') / (A 'x');", 'A', 'xxyx', 4),
    ('(c)', "A <- B / 'z'; B <- ('x' A) / (A 'y');", 'A', 'xxzyyy', 6),
    ('(d)', "A <- 'x'? (A 'y' / A / 'y');", 'A', 'xxyyy', 5),
    ('(e)', "S <- E; E <- F 'n' / 'n'; F <- E '+' I* / G '-'; G <- H 'm' / E; H <- G 'l'; I <- '(' A+ ')'; A <- 'a';", 'S', 'nlm-n+(aaa)n', 12),
    ('(f)', 'M <- L; L <- P ".x" / \'x\'; P <- P "(n)" / L;', 'M', 'x.x(n)(n).x.x', 13),
    ('(g)', "E <- E '+' N / N; N <- [0-9]+;", 'E', '0+1+2+3', 7),
    ('(h)', "E <- N '+' E / N; N <- [0-9]+;", 'E', '0+1+2+3', 7),
    ('(i)', "E <- E '+' E / N; N <- [0-9]+;", 'E', '0+1+2+3', 7),
  ];
  for (final (label, g, top, input, len) in figs) {
    final r = Parser(rules: MetaGrammar.parseGrammar(g), topRuleName: top, input: input).parse();
    check('Fig LeftRecTypes $label', '${!r.hasSyntaxErrors}/${r.root.len}', 'true/$len');
  }

  // ---- Table "mutation": the 519-mutant sweep (Sec. Mutation results).
  const doc = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';
  final search = RepairSearch(rules: json, topRuleName: 'JSON');
  bool parses(String s) => !Parser(rules: json, topRuleName: 'JSON', input: s).parse().hasSyntaxErrors;
  final origShape = treeShape(Parser(rules: json, topRuleName: 'JSON', input: doc).parse().root);

  final mutants = <(String, String)>[];
  for (var j = 0; j < doc.length; j++) {
    mutants.add(('del', doc.substring(0, j) + doc.substring(j + 1)));
    if (j + 1 < doc.length && doc[j] != doc[j + 1]) {
      mutants.add(('swap', doc.substring(0, j) + doc[j + 1] + doc[j] + doc.substring(j + 2)));
    }
  }
  for (var j = 0; j <= doc.length; j++) {
    for (final c in ['Q', 'z', '}', '"', ',', '5']) {
      mutants.add(('ins', doc.substring(0, j) + c + doc.substring(j)));
      if (j < doc.length && doc[j] != c) {
        mutants.add(('sub', doc.substring(0, j) + c + doc.substring(j + 1)));
      }
    }
  }
  check('Mutants generated', mutants.length, 656);

  var tested = 0, stillValid = 0, cost1 = 0, shapeMatch = 0, identical = 0, failed = 0, panic = 0;
  var totalParses = 0;
  final byKind = <String, List<int>>{};
  for (final (kind, m) in mutants) {
    if (parses(m)) {
      stillValid++;
      continue;
    }
    tested++;
    final k = byKind.putIfAbsent(kind, () => [0, 0, 0]);
    k[0]++;
    final r = search.repair(m);
    if (r == null) {
      failed++;
      continue;
    }
    totalParses += r.stats.parsesRun;
    if (r.stats.usedPanicFallback) panic++;
    if (r.cost == 1) {
      cost1++;
      k[1]++;
    }
    if (r.repaired == doc) identical++;
    if (treeShape(r.parseResult.root) == origShape) {
      shapeMatch++;
      k[2]++;
    }
  }
  check('Still-valid mutants excluded', stillValid, 137);
  check('Mutants tested', tested, 519);
  check('Repairs failed', failed, 0);
  check('Panic fallback uses', panic, 0);
  check('Cost-1 repairs', cost1, 519);
  check('Char-identical restorations', identical, 338);
  check('Structural restorations', shapeMatch, 490);
  check('Total parses in sweep', totalParses, 14592);
  check('Deletion class (tested/cost1/shape)', byKind['del']!.join('/'), '37/37/34');
  check('Transposition class', byKind['swap']!.join('/'), '42/42/41');
  check('Insertion class', byKind['ins']!.join('/'), '216/216/211');
  check('Substitution class', byKind['sub']!.join('/'), '224/224/204');

  // ---- Sec. Oracle-verified: LR expression grammar 56/56 cost-1 mutants.
  final exprG = MetaGrammar.parseGrammar('''
    E <- E "+" T / E "-" T / T ;
    T <- T "*" F / T "/" F / F ;
    F <- "(" E ")" / N ;
    N <- [0-9]+ ;
  ''');
  const exprInput = '(12+3)*45-6/(7+89)+1*2';
  final searchE = RepairSearch(rules: exprG, topRuleName: 'E');
  bool parsesE(String s) => !Parser(rules: exprG, topRuleName: 'E', input: s).parse().hasSyntaxErrors;
  var eTested = 0, eCost1 = 0;
  for (var j = 0; j < exprInput.length; j++) {
    for (final m in [
      exprInput.substring(0, j) + exprInput.substring(j + 1),
      '${exprInput.substring(0, j)}Q${exprInput.substring(j)}',
      '${exprInput.substring(0, j)}#${exprInput.substring(j + 1)}',
    ]) {
      if (parsesE(m)) continue;
      eTested++;
      final r = searchE.repair(m);
      if (r != null && r.cost == 1) eCost1++;
    }
  }
  check('LR expression mutants (tested/cost1)', '$eTested/$eCost1', '56/56');

  // ---- Sec. Recovery performance: parse counts for single-error scaling; garbage cost.
  const expectedParses = {496: 3, 987: 3, 1997: 6, 3993: 6, 8000: 3};
  for (final size in [500, 1000, 2000, 4000, 8000]) {
    final d = makeJson(size);
    final commaPos = d.indexOf(',', d.length ~/ 2);
    final broken = d.substring(0, commaPos) + d.substring(commaPos + 1);
    final r = RepairSearch(rules: json, topRuleName: 'JSON').repair(broken)!;
    check('Single-error n=${d.length} (cost/parses)', '${r.cost}/${r.stats.parsesRun}',
        '1/${expectedParses[d.length]!}');
  }
  final garbage = List.generate(400, (i) => 'qwxyz#@!'[i % 8]).join();
  final rg = RepairSearch(rules: json, topRuleName: 'JSON').repair(garbage)!;
  check('Garbage input n=400 repair cost', rg.cost, 2);

  // ---- Sec. Observers: alphabet-sufficiency example S <- !'a' !'z' [a-z].
  // Every member of L(G) lies strictly between the grammar's literal/boundary
  // characters; the class representative required by the lemma makes the
  // minimal repair reachable.
  final lookG = MetaGrammar.parseGrammar("S <- !'a' !'z' [a-z] ;");
  bool parsesLook(String s) =>
      !Parser(rules: lookG, topRuleName: 'S', input: s).parse().hasSyntaxErrors;
  check('Alphabet example: b/y parse, a/z/1 do not',
      [parsesLook('b'), parsesLook('y'), parsesLook('a'), parsesLook('z'), parsesLook('1')].join('/'),
      'true/true/false/false/false');
  final rLook = RepairSearch(rules: lookG, topRuleName: 'S').repair('1');
  check('Alphabet example: repair of "1" is cost 1',
      rLook == null ? 'null' : '${rLook.cost}', '1');

  print(_failures == 0 ? '\nALL CHECKS PASSED' : '\n$_failures CHECK(S) FAILED');
  if (_failures > 0) throw StateError('$_failures verification failures');
}
