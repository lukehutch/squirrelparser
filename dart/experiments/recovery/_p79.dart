// _p79.dart -- does the AST-centric engine do what the reframing demands?
//
// Three questions, in the order that matters:
//   1. On UNDAMAGED input, is the tree identical to the pure parser's? (If not,
//      recovery has changed the language, which is fatal.)
//   2. Do the owner's two acceptance cases come out right, with no tie-break
//      model in the engine at all?
//   3. What does the unique-minimal-witness gate actually admit and refuse?
import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' show jsonGrammar, treeShape, covers;
import 'm79.dart' as e79;

const doc = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';

String render(MatchResult m, String input) {
  final sb = StringBuffer();
  void walk(MatchResult n) {
    if (n is e79.Filled) {
      sb.write('‹${n.text}›'); // <<text>> = synthesized, zero width
      return;
    }
    if (n is SyntaxError) {
      sb.write('«${input.substring(n.pos, n.pos + n.len)}»'); // deleted
      return;
    }
    if (n.subClauseMatches.isEmpty) {
      if (n.len > 0) sb.write(input.substring(n.pos, n.pos + n.len));
      return;
    }
    n.subClauseMatches.forEach(walk);
  }

  walk(m);
  return sb.toString();
}

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);

  // ---- 1. identity on undamaged input ------------------------------------
  final pure = Parser(rules: rules, topRuleName: 'JSON', input: doc).parse();
  final eng = e79.SuperDot3(rules: rules, topRuleName: 'JSON');
  final got = eng.recover(doc);
  print('=== clean input ===');
  print('  cost          ${eng.lastCost}   (must be 0)');
  print('  shape equal   ${treeShape(got) == treeShape(pure.root)}');
  print('  covers input  ${covers(got, doc.length)}');

  // ---- 2. the two acceptance cases ---------------------------------------
  print('\n=== the owner\'s two acceptance cases ===');
  for (final s in ['[2,33,true]', '[2,33true]', '[,2,]', '[,2,3]', '[2,,3]']) {
    final e = e79.SuperDot3(rules: rules, topRuleName: 'JSON');
    final r = e.recover(s);
    print('  ${'"$s"'.padRight(14)} cost ${e.lastCost.toString().padLeft(2)}  '
        '${render(r, s)}');
  }

  // ---- 3. what the witness gate admits -----------------------------------
  print('\n=== a sample of the battery ===');
  var ok = 0, tot = 0, shape = 0;
  final pureShape = treeShape(pure.root);
  for (var i = 0; i < doc.length; i++) {
    final del = doc.substring(0, i) + doc.substring(i + 1);
    final e = e79.SuperDot3(rules: rules, topRuleName: 'JSON');
    final r = e.recover(del);
    tot++;
    if (e.lastCost >= 0 && covers(r, del.length)) ok++;
    if (treeShape(r) == pureShape) shape++;
  }
  print('  single-char deletions: $tot   covered $ok   shape-identical $shape');
}
