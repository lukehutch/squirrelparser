// _dc77.dart -- scratch: does I33 move the cases the brief names?
// Reads the TREE, not the repaired string: `_repaired` is library-private, and
// the tree is the deliverable anyway.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' show buildSetup;
import 'm75.dart' as a75;
import 'm77.dart' as a77;

const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';

/// The named rules covering each stretch of input, plus every error span.
String sketch(MatchResult m, String input) {
  final out = <String>[];
  void walk(MatchResult n) {
    final c = n.clause;
    if (n is SyntaxError) {
      out.add(n.len == 0
          ? '<?>@${n.pos}'
          : '<!${input.substring(n.pos, n.pos + n.len)}!>@${n.pos}');
    } else if (c is Ref &&
        const {'Object', 'Array', 'String', 'Number', 'Boolean', 'Null'}
            .contains(c.ruleName)) {
      out.add('${c.ruleName}[${n.pos},${n.pos + n.len})');
    }
    n.subClauseMatches.forEach(walk);
  }

  walk(m);
  return out.join(' ');
}

void main() {
  final rules = buildSetup().$1;
  final e75 = a75.SuperDot3(rules: rules, topRuleName: 'JSON');
  final e76 = a77.SuperDot3(rules: rules, topRuleName: 'JSON');
  final cases = <(String, String)>[
    ('B021 `[2`->`2[`', '{"a":1,"bc":2[,33,true],"d":{"e":null},"f":"gh"}'),
    (',3true', base.replaceFirst('[2,33,true]', '[2,3,3true]')),
    ('[,33,true]', base.replaceFirst('[2,33,true]', '[,33,true]')),
    ('ture', base.replaceFirst('true', 'ture')),
    ('"a":"1', base.replaceFirst('"a":1', '"a":"1')),
    ('"a": (empty)', base.replaceFirst('"a":1', '"a":')),
  ];
  for (final (name, s) in cases) {
    final c75 = e75.recoverCost(s), c76 = e76.recoverCost(s);
    final t75 = sketch(e75.recover(s).root, s);
    final t76 = sketch(e76.recover(s).root, s);
    print('$name   $s');
    print('  m75 cost $c75  $t75');
    print('  m77 cost $c76  $t76');
    print(c75 != c76
        ? '  *** COST MOVED -- I33 must never do this ***'
        : (t75 == t76 ? '  (identical tree)' : '  >>> TREE CHANGED <<<'));
  }
}
