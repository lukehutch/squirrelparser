// Scratch: does a nonproductive rule hang the deepening loop? (Codex claim 3.)
import 'package:squirrel_parser/squirrel_parser.dart';
import "_u10.dart" as r4;

void main() {
  final rules = MetaGrammar.parseGrammar('S <- S;');
  final p = Parser(rules: rules, topRuleName: 'S', input: '').parse();
  print('frozen parser returned: hasSyntaxErrors=${p.hasSyntaxErrors}');
  print('starting r4.recover("") -- if this is the last line, it hangs');
  final t = r4.Squirrel(rules: rules, topRuleName: 'S').recover('');
  print('r4 returned: ${t.runtimeType} len=${t.len}');
}
