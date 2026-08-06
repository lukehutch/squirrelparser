// _exprbug.dart -- an empty skeleton on the LEFT-RECURSIVE grammar is either a
// crash, a bare SyntaxError over the whole input, or a real tree the labeller
// cannot see. Find out which.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'm82.dart' as eng;

const probes = [
  'a', 'a+', 'a*', 'a+b', 'a*b', 'a+b*', 'a*b+', 'a*b*', 'a+b+',
  '1*', '1+2*', '(a', '(a+', 'a+(b*', 'a+b*2-(+c)*4',
];

void dump(MatchResult n, String input, String indent) {
  final c = n.clause;
  final label = n is SyntaxError
      ? 'SyntaxError'
      : n is eng.Filled
          ? 'Filled("${n.text}")'
          : c is Ref
              ? 'Ref(${c.ruleName})'
              : c == null
                  ? '<null clause>'
                  : c.runtimeType.toString();
  final txt = n.len > 0 && n.pos + n.len <= input.length
      ? input.substring(n.pos, n.pos + n.len)
      : '';
  print('$indent$label  [${n.pos},${n.pos + n.len})  "$txt"');
  for (final s in n.subClauseMatches) {
    dump(s, input, '$indent  ');
  }
}

void main() {
  final co = corpora.firstWhere((c) => c.name == 'expr');
  final rules = MetaGrammar.parseGrammar(co.grammar);
  final e = eng.SuperDot3(rules: rules, topRuleName: co.top);

  for (final s in probes) {
    print('=== "$s" ===');
    MatchResult? r;
    Object? err;
    try {
      r = e.recover(s);
    } catch (x) {
      err = x;
    }
    if (err != null) {
      print('  THREW: $err\n');
      continue;
    }
    print('  cost ${e.lastCost}  covered ${covers(r!, s.length)}');
    print('  skeleton: ${skeleton(r, co.named).join(' ')}');
    dump(r, s, '    ');
    print('');
  }
}
