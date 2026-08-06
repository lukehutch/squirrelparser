// _why72.dart -- the four lost shape points are all `[2X33` : a junk character
// between two numbers. Two repairs cost 1 -- substitute the junk with a comma
// (three array values, the pristine shape) or delete it (the digits fuse into
// one number, two values). If the costs really are equal this is a TIE, and the
// engines differ only in how a tie is broken. Print what each caller receives.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' show jsonGrammar;
import 'm71.dart' as e71;
import 'm72.dart' as e72;

String _leaves(MatchResult m) {
  final b = StringBuffer();
  void walk(MatchResult m) {
    if (m is SyntaxError) {
      b.write('ERR@${m.pos}+${m.len} ');
      return;
    }
    if (m.subClauseMatches.isEmpty) {
      if (m.len > 0) b.write('${m.clause}@${m.pos}+${m.len} ');
      return;
    }
    m.subClauseMatches.forEach(walk);
  }

  walk(m);
  return b.toString();
}

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  final a = e71.SuperDot3(rules: rules, topRuleName: 'JSON');
  final b = e72.SuperDot3(rules: rules, topRuleName: 'JSON');
  for (final s in [
    '{"a":1,"bc":[2Q33,true],"d":{"e":null},"f":"gh"}',
    '[2Q33,true]',
    '[2Q33]',
  ]) {
    print('=== "$s"');
    for (final (name, e) in <(String, dynamic)>[('m71', a), ('m72', b)]) {
      final c = e.recoverCost(s);
      final r = e.recover(s);
      final spans = r.errorSpans.map((x) => '${x.pos}+${x.len}').join(',');
      print('  $name cost=$c reg=${e.lastRegret} verified=${e.lastVerified} '
          'spans=[$spans] missing=${r.missing.length} skipped=${r.charsSkipped}');
      print('       ${_leaves(r.root)}');
    }
  }
}
