// _twoparsers.dart -- the last unexplained step.
//
// In ONE isolate, `_sidebyside` measured the LIBRARY parser reaching len 8192
// on the RR ladder while m70's `recoverCost` overflowed at len 4096, with the
// trace landing inside `Parser.match` under `_verify`. Those are not the same
// parser. Every engine in this line CARRIES a copy of `lib/src/parser` so it is
// standalone (`_coregate` claim C holds the copy byte-identical), and that copy
// is a separate class, compiled separately from the library's.
//
// So the control was wrong: it warmed and measured `package:squirrel_parser`'s
// `Parser` while the engine was running its own. This measures both, in the
// same isolate, on the same input, so the two ceilings are finally comparable.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'm70.dart' as e70;

String oneErr(int k) {
  final c = List.generate(k, (i) => '${i % 10}').join('+');
  return '${c.substring(0, c.length ~/ 2)}+${c.substring(c.length ~/ 2)}';
}

const gRRsrc = "E <- T '+' E / T;\nT <- F '*' T / F;\nF <- [0-9] / '(' E ')';\n";

String ladder(String label, bool Function(String) once) {
  var last = 'none';
  for (final k in [512, 1024, 2048, 4096]) {
    final s = oneErr(k);
    try {
      if (!once(s)) return '$label  FAILED to parse at len ${s.length}';
      last = '>=${s.length}';
    } on StackOverflowError {
      break;
    }
  }
  return '$label  tops out at $last';
}

void main() {
  final g = MetaGrammar.parseGrammar(gRRsrc);
  final back = <e70.Clause, Clause>{};
  final core = e70.rulesToCore(g, back);

  print(ladder('library Parser (cold)', (s) {
    Parser(rules: g, topRuleName: 'E', input: s).parse();
    return true;
  }));
  print(ladder('carried Parser (cold)', (s) {
    e70.Parser(rules: core, topRuleName: 'E', input: s).parse();
    return true;
  }));
  print(ladder('library Parser (warm)', (s) {
    Parser(rules: g, topRuleName: 'E', input: s).parse();
    return true;
  }));
  print(ladder('carried Parser (warm)', (s) {
    e70.Parser(rules: core, topRuleName: 'E', input: s).parse();
    return true;
  }));
}
