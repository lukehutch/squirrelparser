// Scratch: does the ONE output-affecting heuristic still earn its keep?
//
// `_row` sorts Delta-tied head ends ASCENDING -- "prefer the shortest head" --
// and the comment on it says it is kept because it measures better, not because
// anything derives it. That was measured on m26-era engines, before A4 (the gap
// attaches in front of the next reader) and before I4. If A4 already puts
// discarded text outside the subtree, the sort may now be dead weight, and
// deleting it would leave the engine with NO heuristic that changes output.
//
// Three variants, same battery, same process: ascending (m46 as shipped),
// descending (worst case for the claim), and unsorted (whatever the value map
// iterates).
import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/parser/match_result.dart';
import 'package:squirrel_parser/src/recovery/skip_recovery.dart' show SkipResult;
import 'm46.dart' as asc;
import '_m46desc.dart' as desc;
import '_m46nosort.dart' as nosort;

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

typedef Run = (SkipResult, int);

void main(List<String> argv) {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';
  bool parses(String s) =>
      !Parser(rules: rules, topRuleName: 'JSON', input: s).parse().hasSyntaxErrors;

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

  final variants = <String, Run Function(String)>{
    'asc (m46)': (s) {
      final e = asc.SuperDot3(rules: rules, topRuleName: 'JSON');
      final r = e.recover(s);
      return (r, e.lastCost);
    },
    'desc': (s) {
      final e = desc.SuperDot3(rules: rules, topRuleName: 'JSON');
      final r = e.recover(s);
      return (r, e.lastCost);
    },
    'nosort': (s) {
      final e = nosort.SuperDot3(rules: rules, topRuleName: 'JSON');
      final r = e.recover(s);
      return (r, e.lastCost);
    },
  };

  final shapesOf = <String, List<String>>{};
  print('${'variant'.padRight(11)}${'shape'.padLeft(9)}${'cover'.padLeft(9)}'
      '${'costhist'.padLeft(16)}${'verified'.padLeft(10)}');
  for (final entry in variants.entries) {
    var shape = 0, cov = 0, verified = 0;
    final hist = <int, int>{};
    final shapes = <String>[];
    for (final m in battery) {
      final (r, cost) = entry.value(m);
      shapes.add(treeShape(r.root));
      if (treeShape(r.root) == origShape) shape++;
      if (covers(r.root, m.length)) cov++;
      hist[cost] = (hist[cost] ?? 0) + 1;
      if (!r.forced) verified++;
    }
    shapesOf[entry.key] = shapes;
    final keys = hist.keys.toList()..sort();
    print('${entry.key.padRight(11)}${'$shape/${battery.length}'.padLeft(9)}'
        '${'$cov/${battery.length}'.padLeft(9)}'
        '${'{${keys.map((k) => '$k:${hist[k]}').join(', ')}}'.padLeft(16)}'
        '${'$verified/${battery.length}'.padLeft(10)}');
  }

  // Where do the variants actually differ from ascending?
  for (final name in ['desc', 'nosort']) {
    var diff = 0;
    final examples = <String>[];
    for (var i = 0; i < battery.length; i++) {
      if (shapesOf[name]![i] != shapesOf['asc (m46)']![i]) {
        diff++;
        if (examples.length < 3) examples.add(battery[i]);
      }
    }
    print('$name differs from asc on $diff/${battery.length} trees'
        '${examples.isEmpty ? '' : '   e.g. ${examples.join("  |  ")}'}');
  }
}
