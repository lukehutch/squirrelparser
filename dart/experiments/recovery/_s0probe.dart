// _s0probe.dart -- print r9's and _s0's trees for chosen inputs.
import 'package:squirrel_parser/squirrel_parser.dart';

import 's2.dart' as s0;
import 'astdiff.dart';
import 'r9.dart' as r9;

void main(List<String> argv) {
  final specs = argv.isEmpty
      ? [
          ('expr', '1*'),
          ('json', '{"n":[0,-7,1.5,2e3],"t":[true,false,nu}l]}'),
        ]
      : [
          for (var i = 0; i + 1 < argv.length; i += 2) (argv[i], argv[i + 1])
        ];
  for (final (g, input) in specs) {
    final c = corpora.firstWhere((x) => x.name == g);
    final rules = MetaGrammar.parseGrammar(c.grammar);
    print('=== $g "$input"');
    final a = r9.Squirrel(rules: rules, topRuleName: c.top).recover(input);
    final b = s0.Squirrel(rules: rules, topRuleName: c.top).recover(input);
    print('--- r9  skeleton: ${skeleton(a, c.named).join(' ')}');
    print(a.toPrettyString(input));
    print('--- s0  skeleton: ${skeleton(b, c.named).join(' ')}');
    print(b.toPrettyString(input));
  }
}
