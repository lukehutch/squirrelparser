import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import 'c4.dart' as c4;
import 's1.dart' as s1;

const idx = [42, 122, 128, 129, 130, 133, 139, 167, 171, 298, 304, 339, 340,
  343, 346, 347, 350, 351, 352, 621, 638, 691, 692, 848, 857, 861, 864, 871,
  1027, 1037, 1042, 1179, 1180, 1192, 1197, 1202, 1529, 1530, 1536, 1537,
  1542, 1543, 1544, 1577, 1581, 1595, 1674, 1701, 1745, 1747, 1749, 1757,
  1766, 1792];

void main() {
  final cases = weighted(buildBattery());
  final byCorpus = <String, Corpus>{for (final c in corpora) c.name: c};
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final original = <String, MatchResult>{};
  for (final c in corpora) {
    for (final doc in c.documents) {
      original['${c.name} $doc'] =
          Parser(rules: rulesOf[c.name]!, topRuleName: c.top, input: doc)
              .parse()
              .root;
    }
  }
  for (final i in idx) {
    final k = cases[i];
    final c = byCorpus[k.grammar]!;
    final exp =
        expectedFor(k, original['${k.grammar} ${k.original}']!, c.named);
    final e4 = c4.Squirrel(rules: rulesOf[k.grammar]!, topRuleName: c.top);
    final t4 = e4.recover(k.mutant);
    final e1 = s1.Squirrel(rules: rulesOf[k.grammar]!, topRuleName: c.top);
    final t1 = e1.recover(k.mutant);
    print('=== i=$i ${k.grammar} ${k.category}');
    print('doc: ${k.mutant.replaceAll('\n', ' ')}');
    print('org: ${k.original.replaceAll('\n', ' ')}');
    print('exp: ${exp.join(' ')}');
    print('c4:  ${skeleton(t4, c.named).join(' ')}');
    print('s1:  ${skeleton(t1, c.named).join(' ')}');
  }
}
