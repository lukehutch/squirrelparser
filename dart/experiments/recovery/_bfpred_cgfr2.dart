// Predicate invariance gate for cgfr2.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm62.dart' as reference;
import 'cgfr2.dart' as candidate;

void main() {
  final rules = MetaGrammar.parseGrammar('''
    S <- &'a' 'a' / 'b';
  ''');
  final ref = reference.SuperDot3(rules: rules, topRuleName: 'S');
  final cand = candidate.SuperDot3(rules: rules, topRuleName: 'S');

  final cRef = ref.recoverCost('a');
  final cCand = cand.recoverCost('a');
  print('ref cost: $cRef, cand cost: $cCand');
  assert(cRef == cCand && cCand == 0);
  print('Predicate invariance gate passed!');
}
