// Print the tree for one case, marking every short Seq as a hole or a prefix.
import 'package:squirrel_parser/squirrel_parser.dart';

import '_missing.dart' show shortSeqs;
import '_score1.dart' show resolve;
import 'astdiff.dart';

void main(List<String> argv) {
  final engine = argv.isEmpty ? 'm143' : argv[0];
  final gram = argv.length > 1 ? argv[1] : 'expr';
  final input = argv.length > 2 ? argv[2] : 'a+b*2-(';
  final c = corpora.firstWhere((c) => c.name == gram);
  final rules = MetaGrammar.parseGrammar(c.grammar);
  final t = resolve(engine)!(rules, c.top)(input);
  if (t == null) {
    print('null');
    return;
  }
  final (h, p) = shortSeqs(t);
  print('$engine  $gram  ${jsonEsc(input)}   holes=$h prefixes=$p');
  print('');
  show(t, rules, 0);
}

String jsonEsc(String s) => s.replaceAll('\n', '\\n');

void show(MatchResult m, Map<String, Clause> rules, int d) {
  final cl = m.clause;
  final kids = m.subClauseMatches;
  final real = kids.where((x) => x is! SyntaxError).toList();
  var tag = '';
  if (cl is Seq && real.isNotEmpty && real.length < cl.subClauses.length) {
    var aligned = true;
    for (var i = 0; i < real.length; i++) {
      final kc = real[i].clause;
      if (kc != null && !identical(kc, cl.subClauses[i])) aligned = false;
    }
    tag = aligned ? '   <<< PREFIX ${real.length}/${cl.subClauses.length}'
        : '   <<< HOLE ${real.length}/${cl.subClauses.length}'
            ' want=[${cl.subClauses.join(' , ')}]'
            ' got=[${real.map((k) => k.clause).join(' , ')}]';
  }
  final name = cl == null ? '${m.runtimeType}(null)' : '$cl';
  print('${'  ' * d}${m.pos}+${m.len} ${m.runtimeType} $name$tag');
  for (final k in kids) {
    show(k, rules, d + 1);
  }
}
