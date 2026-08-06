import 'package:squirrel_parser/squirrel_parser.dart';
import 'cgfr3.dart';

void main() {
  final rules = MetaGrammar.parseGrammar("E <- E '+' T / T;\nT <- T '*' F / F;\nF <- [0-9];\n");
  final parser = Cgfr3Parser(rules: rules, topRuleName: 'E', input: '1*');
  
  // monkey patch match to print
  final origMatch = parser.match;
  
  final res = parser.recover();
  print("Final cost: \${res.cost}");
}
