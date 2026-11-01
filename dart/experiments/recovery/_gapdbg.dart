import 'package:squirrel_parser/squirrel_parser.dart';
import '../../test/recovery/astdiff.dart';

void main(List<String> args) {
  final c = corpora.firstWhere((c) => c.name == args[0]);
  final p = Parser(rules: MetaGrammar.parseGrammar(c.grammar), topRuleName: c.top, input: args[1]);
  final r = p.parse(recover: true);
  print('root ${r.root.runtimeType} ${r.root.pos}+${r.root.len} unmatched=${r.unmatchedInput?.pos} gaps=${p.gaps.entries.map((e) => '${e.key.$2}+${e.value} ${e.key.$1}').toList()}');
}
