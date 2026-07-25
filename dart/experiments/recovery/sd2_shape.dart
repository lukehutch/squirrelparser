// The full gate: cost histogram, tree SHAPE accuracy with per-kind splits, full
// coverage of the input, and time -- superdot against dot on the same battery.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/parser/combinators.dart';
import 'package:squirrel_parser/src/parser/match_result.dart';
import 'package:squirrel_parser/src/recovery/dot_recovery.dart';
import 'package:squirrel_parser/src/recovery/skip_recovery.dart' show SkipResult;
import 'sd3.dart';

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

/// Does the tree tile the whole input, left to right, with no gap or overlap?
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

void main() {
  const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  bool parses(String s) =>
      !Parser(rules: rules, topRuleName: 'JSON', input: s).parse().hasSyntaxErrors;

  final mutants = <(String, String, String)>[];
  for (var j = 0; j < base.length; j++) {
    mutants.add(('del', 'del@$j', base.substring(0, j) + base.substring(j + 1)));
    if (j + 1 < base.length && base[j] != base[j + 1]) {
      mutants.add(('swap', 'swap@$j',
          base.substring(0, j) + base[j + 1] + base[j] + base.substring(j + 2)));
    }
  }
  for (var j = 0; j <= base.length; j++) {
    for (final c in ['Q', 'z', '}', '"', ',', '5']) {
      mutants.add(('ins', 'ins@$j($c)', base.substring(0, j) + c + base.substring(j)));
      if (j < base.length && base[j] != c) {
        mutants.add(('sub', 'sub@$j->$c',
            base.substring(0, j) + c + base.substring(j + 1)));
      }
    }
  }
  final battery = mutants.where((m) => !parses(m.$3)).toList();
  final origShape =
      treeShape(Parser(rules: rules, topRuleName: 'JSON', input: base).parse().root);
  print('battery=${battery.length}  origShape len=${origShape.length}');

  void run(String name, SkipResult Function(String) f, int Function() cost) {
    var ok = 0, cov = 0, crash = 0;
    final byKind = <String, int>{'ins': 0, 'sub': 0, 'del': 0, 'swap': 0};
    final tot = <String, int>{'ins': 0, 'sub': 0, 'del': 0, 'swap': 0};
    final hist = <int, int>{};
    final bad = <String>[];
    final sw = Stopwatch()..start();
    for (final (kind, desc, m) in battery) {
      tot[kind] = tot[kind]! + 1;
      SkipResult r;
      try {
        r = f(m);
      } catch (e) {
        crash++;
        if (bad.length < 5) bad.add('$desc CRASH $e');
        continue;
      }
      hist[cost()] = (hist[cost()] ?? 0) + 1;
      if (covers(r.root, m.length)) cov++;
      if (treeShape(r.root) == origShape) {
        ok++;
        byKind[kind] = byKind[kind]! + 1;
      } else if (bad.length < 5) {
        bad.add('$desc  "$m"');
      }
    }
    sw.stop();
    final h = Map.fromEntries(hist.entries.toList()..sort((a, b) => a.key - b.key));
    print('${name.padRight(9)} shape ${ok.toString().padLeft(3)}/${battery.length}  '
        'ins ${byKind['ins']}/${tot['ins']} sub ${byKind['sub']}/${tot['sub']} '
        'del ${byKind['del']}/${tot['del']} swap ${byKind['swap']}/${tot['swap']}  '
        'cover $cov/${battery.length}  crash $crash  cost $h  '
        '${sw.elapsedMilliseconds}ms');
    for (final b in bad) {
      print('    miss: $b');
    }
  }

  final dot = DotRecovery(rules: rules, topRuleName: 'JSON');
  run('dot', dot.recover, () => dot.lastTotalCost);
  final sd = SuperDot3(rules: rules, topRuleName: 'JSON');
  run('superdot', (m) => sd.recover(m), () => sd.lastCost);
}
