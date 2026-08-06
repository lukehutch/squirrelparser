// m64's gate: a 300-step random single-edit walk over the battery document.
// At every step the incremental answer must equal a fresh m62 batch run
// (costs, and witness shapes on every 10th step); timing compares the
// incremental path against batch-from-scratch on the same sequence.
import 'dart:math';
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm62.dart' as ref;
import 'm64.dart' as inc;

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

String shape(MatchResult m) {
  final kids = m.subClauseMatches;
  final label = m is SyntaxError ? 'ERR' : '${m.clause}';
  return kids.isEmpty
      ? '$label@${m.pos}+${m.len}'
      : '$label@${m.pos}+${m.len}(${kids.map(shape).join(',')})';
}

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';
  const alphabet = '{}[],:"aebcdf1233trunlgh Qz5';
  final rnd = Random(1234);

  final e = inc.SuperDot3(rules: rules, topRuleName: 'JSON');
  e.recoverCost(base); // seed the session (base parses: cost 0)
  final r = ref.SuperDot3(rules: rules, topRuleName: 'JSON');

  var s = base;
  var costDiffs = 0, shapeDiffs = 0, zeroCost = 0;
  var incUs = 0, batUs = 0, keptSum = 0, rungMax = 0, checked = 0;
  final sw = Stopwatch();
  for (var step = 0; step < 300; step++) {
    // one random single-character edit
    final op = s.length <= 1 ? 0 : rnd.nextInt(3);
    if (op == 0) {
      final p = rnd.nextInt(s.length + 1);
      s = s.substring(0, p) + alphabet[rnd.nextInt(alphabet.length)] + s.substring(p);
    } else if (op == 1) {
      final p = rnd.nextInt(s.length);
      s = s.substring(0, p) + s.substring(p + 1);
    } else {
      final p = rnd.nextInt(s.length);
      var c = alphabet[rnd.nextInt(alphabet.length)];
      while (c == s[p]) {
        c = alphabet[rnd.nextInt(alphabet.length)];
      }
      s = s.substring(0, p) + c + s.substring(p + 1);
    }

    sw..reset()..start();
    final ci = e.recoverCostEdit(s);
    sw.stop();
    incUs += sw.elapsedMicroseconds;
    keptSum += e.lastKept;
    if (e.lastRungs > rungMax) rungMax = e.lastRungs;

    sw..reset()..start();
    final cb = r.recoverCost(s);
    sw.stop();
    batUs += sw.elapsedMicroseconds;

    if (ci != cb) {
      costDiffs++;
      print('step $step COST DIFF inc=$ci batch=$cb  s=$s');
    }
    if (cb == 0) zeroCost++;
    if (step % 10 == 9 && ci > 0 && ci == cb) {
      checked++;
      final si = shape(e.recoverEdit(s).root);
      final sb = shape(r.recover(s).root);
      if (si != sb) {
        shapeDiffs++;
        print('step $step SHAPE DIFF');
      }
    }
  }
  print('steps=300  costDiffs=$costDiffs  shapeDiffs=$shapeDiffs (of $checked checked)  '
      'cleanSteps=$zeroCost');
  print('incremental total=${(incUs / 1000).toStringAsFixed(1)}ms  '
      'batch total=${(batUs / 1000).toStringAsFixed(1)}ms  '
      'speedup=${(batUs / incUs).toStringAsFixed(2)}x');
  print('mean kept cells=${(keptSum / 300).toStringAsFixed(0)}  maxRungs=$rungMax');

  // Scenario 2, the IDE cycle: valid document, one corrupting keystroke,
  // query, revert, query -- 100 cycles at random positions, warm throughout.
  final e2 = inc.SuperDot3(rules: rules, topRuleName: 'JSON');
  e2.recoverCost(base);
  final r2 = ref.SuperDot3(rules: rules, topRuleName: 'JSON');
  var incUs2 = 0, batUs2 = 0, diffs2 = 0;
  for (var i = 0; i < 100; i++) {
    final p = rnd.nextInt(base.length);
    var c = alphabet[rnd.nextInt(alphabet.length)];
    while (c == base[p]) {
      c = alphabet[rnd.nextInt(alphabet.length)];
    }
    final broken = base.substring(0, p) + c + base.substring(p + 1);
    sw..reset()..start();
    final ci = e2.recoverCostEdit(broken);
    sw.stop();
    incUs2 += sw.elapsedMicroseconds;
    sw..reset()..start();
    final cb = r2.recoverCost(broken);
    sw.stop();
    batUs2 += sw.elapsedMicroseconds;
    if (ci != cb) diffs2++;
    sw..reset()..start();
    final fi = e2.recoverCostEdit(base);
    sw.stop();
    incUs2 += sw.elapsedMicroseconds;
    sw..reset()..start();
    final fb = r2.recoverCost(base);
    sw.stop();
    batUs2 += sw.elapsedMicroseconds;
    if (fi != 0 || fb != 0) diffs2++;
  }
  print('IDE cycle (100 break/fix pairs): diffs=$diffs2  '
      'inc=${(incUs2 / 1000).toStringAsFixed(1)}ms  '
      'batch=${(batUs2 / 1000).toStringAsFixed(1)}ms  '
      'speedup=${(batUs2 / incUs2).toStringAsFixed(2)}x');

  // Scenario 3, scale: the same IDE cycle on a ~4.9KB document (100x the
  // members), 20 break/fix pairs -- does any regime reward the cell carry?
  final bigMembers = [for (var i = 0; i < 100; i++) '"k$i":{"a":$i,"b":[1,2,"x$i"],"ok":true}'].join(',');
  final big = '{$bigMembers}';
  final e3 = inc.SuperDot3(rules: rules, topRuleName: 'JSON');
  e3.recoverCost(big);
  final r3 = ref.SuperDot3(rules: rules, topRuleName: 'JSON');
  var incUs3 = 0, batUs3 = 0, diffs3 = 0;
  for (var i = 0; i < 20; i++) {
    final p = rnd.nextInt(big.length);
    var c = alphabet[rnd.nextInt(alphabet.length)];
    while (c == big[p]) {
      c = alphabet[rnd.nextInt(alphabet.length)];
    }
    final broken = big.substring(0, p) + c + big.substring(p + 1);
    sw..reset()..start();
    final ci = e3.recoverCostEdit(broken);
    sw.stop();
    incUs3 += sw.elapsedMicroseconds;
    sw..reset()..start();
    final cb = r3.recoverCost(broken);
    sw.stop();
    batUs3 += sw.elapsedMicroseconds;
    if (ci != cb) diffs3++;
    e3.recoverCostEdit(big);
    r3.recoverCost(big);
  }
  print('scale n=${big.length} (20 break/fix): diffs=$diffs3  '
      'inc=${(incUs3 / 20 / 1000).toStringAsFixed(2)}ms/keystroke  '
      'batch=${(batUs3 / 20 / 1000).toStringAsFixed(2)}ms/keystroke  '
      'speedup=${(batUs3 / incUs3).toStringAsFixed(2)}x');
}
