// _id70.dart -- m70 against m69, answer for answer AND tree for tree.
//
// I26 changes only WHERE the witness descent keeps its frames. It does not
// change which witness is chosen, what it costs, or what it spans -- the
// alternatives are still tried in `alts` order, the head candidates still in
// the same `..sort` order, and failure still backtracks to the next candidate.
// So the gate is IDENTITY, not agreement: any difference in a cost, a span, a
// missing obligation or a tree shape is a defect in the rewrite.
//
// Identity is a strictly stronger gate than the m69 suite re-run against m70,
// because it compares the witness itself rather than the number the witness
// justifies. Two engines can agree on every cost and still build different
// trees; `shape` catches that.
//
// (`_smoke69.dart` cannot do this job: it is a stale copy that still imports
// m53 and m60, so despite its name it never tested m69 at all.)
import 'package:squirrel_parser/squirrel_parser.dart';

import 'm69.dart' as old;
import 'm70.dart' as new_;

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

const doc = '{"a":1,"b":[2,3],"c":{"d":"x"},"e":true,"f":null}';

/// A canonical string for a witness tree, so two trees compare as text.
String shape(MatchResult m) {
  final b = StringBuffer();
  void go(MatchResult x) {
    final c = x.clause;
    b.write('(${c.runtimeType}:${x.pos},${x.len}');
    for (final s in x.subClauseMatches) {
      go(s);
    }
    b.write(')');
  }

  go(m);
  return b.toString();
}

/// Every single-character mutation of `doc`: delete, substitute, insert. This
/// is the 519-mutant battery the table's `cost` column is scored on.
List<String> battery() {
  final out = <String>[];
  const alphabet = '{}[]",:0123456789abcdefghijklmnopqrstuvwxyz tn';
  for (var i = 0; i < doc.length; i++) {
    out.add(doc.substring(0, i) + doc.substring(i + 1));
  }
  for (var i = 0; i < doc.length; i++) {
    for (final ch in const ['x', '1', '"', ',']) {
      if (doc[i] != ch) out.add(doc.substring(0, i) + ch + doc.substring(i + 1));
    }
  }
  for (var i = 0; i <= doc.length; i++) {
    for (final ch in const ['x', '}', ']', ',']) {
      out.add(doc.substring(0, i) + ch + doc.substring(i));
    }
  }
  // Keep the alphabet referenced so the intent of the corpus stays readable.
  assert(alphabet.isNotEmpty);
  return out;
}

/// Small grammars that exercise the parts of the descent the JSON grammar
/// never reaches: left recursion, self-looping spines, lookahead (so the
/// router falls through to the tape), and empty true languages.
const probes = <(String, String, List<String>)>[
  (
    "E <- E '+' T / T;\nT <- T '*' F / F;\nF <- [0-9] / '(' E ')';\n",
    'E',
    ['1++2', '1+*2', '((1+2', '1+2)', '', '+', '1+2*3+4', '(((1)))']
  ),
  (
    "E <- T '+' E / T;\nT <- F '*' T / F;\nF <- [0-9] / '(' E ')';\n",
    'E',
    ['1++2', '1+*2', '((1+2', '1+2)', '', '+', '1+2*3+4']
  ),
  ("S <- 'a'* \"ab\";\n", 'S', ['aab', 'aaaab', 'ab', '', 'b']),
  ("S <- ('a' / \"ab\") 'b';\n", 'S', ['abb', 'ab', 'b', 'a']),
  ("S <- A 'c';\nA <- 'a' / \"ab\";\n", 'S', ['abc', 'ac', 'c', 'bc']),
  ("S <- 'a'? \"ab\";\n", 'S', ['aab', 'ab', 'b', '']),
  ("S <- &[a-z] [0-9m-q];\n", 'S', ['', 'z', 'm', '0']),
  ("S <- ![a-l] [a-z];\n", 'S', ['', 'a', 'm']),
  ("S <- &[a-z] [a-z];\n", 'S', ['', 'Q', 'a']),
  ("S <- (\"ab\" / 'a')* 'c';\n", 'S', ['ababc', 'abax', 'c', 'ab']),
];

void main() {
  var n = 0, costBad = 0, treeBad = 0, spanBad = 0;
  final examples = <String>[];

  void one(Map<String, Clause> rules, String top, String s, String tag) {
    n++;
    final a = old.SuperDot3(rules: rules, topRuleName: top);
    final b = new_.SuperDot3(rules: rules, topRuleName: top);
    final ca = a.recoverCost(s);
    final cb = b.recoverCost(s);
    if (ca != cb) {
      costBad++;
      if (examples.length < 8) examples.add('cost  $tag ${_q(s)}: $ca vs $cb');
      return;
    }
    // Same cost -- now the witness itself, via the full `recover` path so the
    // spans and the missing obligations are compared too.
    final ra = a.recover(s);
    final rb = b.recover(s);
    final sa = shape(ra.root), sb = shape(rb.root);
    if (sa != sb) {
      treeBad++;
      if (examples.length < 8) examples.add('tree  $tag ${_q(s)}');
      return;
    }
    final spa = ra.errorSpans.map((e) => '${e.pos}+${e.len}').join(',');
    final spb = rb.errorSpans.map((e) => '${e.pos}+${e.len}').join(',');
    final ma = ra.missing.map((e) => '${e.pos}').join(',');
    final mb = rb.missing.map((e) => '${e.pos}').join(',');
    if (spa != spb || ma != mb) {
      spanBad++;
      if (examples.length < 8) {
        examples.add('span  $tag ${_q(s)}: [$spa|$ma] vs [$spb|$mb]');
      }
    }
  }

  final json = MetaGrammar.parseGrammar(jsonGrammar);
  one(json, 'JSON', doc, 'json/clean');
  for (final m in battery()) {
    one(json, 'JSON', m, 'json/battery');
  }
  for (final (g, top, inputs) in probes) {
    final rules = MetaGrammar.parseGrammar(g);
    for (final s in inputs) {
      one(rules, top, s, 'probe');
    }
  }

  print('m70 vs m69, identity gate');
  print('  compared        $n inputs');
  print('  cost mismatches $costBad');
  print('  tree mismatches $treeBad');
  print('  span mismatches $spanBad');
  for (final e in examples) {
    print('    $e');
  }
  final bad = costBad + treeBad + spanBad;
  print(bad == 0 ? '  IDENTICAL' : '  DIFFERS in $bad of $n');
}

String _q(String s) => s.length <= 24 ? '"$s"' : '"${s.substring(0, 24)}..."';
