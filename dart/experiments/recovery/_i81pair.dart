// Codex's I81 counter-example, checked directly: does m143 DELETE a required
// non-nullable child when it lands at EOF?
//
// `Pair <- Key ':' Value` on `x:`. The colon was consumed, so the grammar says a
// `Value` slot belongs here; the input does not supply one. Keeping a zero-width
// `Value` holding a zero-width SyntaxError is the honest reading -- it names the
// slot without inventing a digit. Deleting the node instead reports a `Pair`
// that never had a `Value`, and nothing in the tree says so.
import 'package:squirrel_parser/squirrel_parser.dart';

import '_score1.dart' show resolve;

const g = '''
Pair  <- Key ':' Value;
Key   <- [a-z]+;
Value <- [0-9]+;
''';

void main(List<String> argv) {
  final rules = MetaGrammar.parseGrammar(g);
  for (final e in argv.isEmpty ? const ['m132', 'm143', 'r1'] : argv) {
    final b = resolve(e);
    if (b == null) {
      print('$e UNKNOWN\n');
      continue;
    }
    final t = b(rules, 'Pair')('x:');
    print('=== $e ===');
    print(t == null ? '  null' : t.toPrettyString('x:'));
    print('  has a Value node: ${t != null && names(t).contains('Value')}');
    print('');
  }
}

Set<String> names(MatchResult m) {
  final out = <String>{};
  void walk(MatchResult k) {
    final c = k.clause;
    if (c is Ref) out.add(c.ruleName);
    k.subClauseMatches.forEach(walk);
  }

  walk(m);
  return out;
}

// Appended probe: what COST does each engine report, and does the tree carry any
// mark at all saying the required `Value` was not found? A tree that covers the
// whole input at cost 0 with no SyntaxError in it is a free pass -- the engine
// has silently accepted a string the PEG rejects.
