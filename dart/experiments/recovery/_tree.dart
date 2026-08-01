// _tree.dart -- PRINT THE ACTUAL TREE, WITH SPANS AND NODE KINDS.
//
// A skeleton says WHICH named rules came out. It does not say whether a node
// covers real characters, and that is the whole question when one engine
// recovers a construct the other drops: did the winner match text, assert text
// that is not there, or mark an absence with a zero-width error node? Those are
// three different answers and the skeleton renders all three identically.
//
// Usage: dart run _tree.dart <engine> <grammar> <input>
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'final_table.dart' show engines;
import 'm81.dart' as g81;
import 'm82.dart' as g82;
import 'm83.dart' as g83;
import 'm84.dart' as g84;
import 'm85.dart' as g85;
import 'm86.dart' as g86;
import 'm87.dart' as g87;
import 'm88.dart' as g88;
import 'm89.dart' as g89;
import 'm90.dart' as g90;
import 'm92.dart' as g92;

typedef Build = MatchResult? Function(String) Function(
    Map<String, Clause>, String);

final Map<String, Build> extra = {
  'm81': (r, t) => g81.SuperDot3(rules: r, topRuleName: t).recover,
  'm82': (r, t) => g82.SuperDot3(rules: r, topRuleName: t).recover,
  'm83': (r, t) => g83.SuperDot3(rules: r, topRuleName: t).recover,
  'm84': (r, t) => g84.SuperDot3(rules: r, topRuleName: t).recover,
  'm85': (r, t) => g85.SuperDot3(rules: r, topRuleName: t).recover,
  'm86': (r, t) => g86.SuperDot3(rules: r, topRuleName: t).recover,
  'm87': (r, t) => g87.SuperDot3(rules: r, topRuleName: t).recover,
  'm88': (r, t) => g88.SuperDot3(rules: r, topRuleName: t).recover,
  'm89': (r, t) => g89.SuperDot3(rules: r, topRuleName: t).recover,
  'm90': (r, t) => g90.SuperDot3(rules: r, topRuleName: t).recover,
  'm92': (r, t) => g92.SuperDot3(rules: r, topRuleName: t).recover,
};

Build build(String name) {
  if (extra.containsKey(name)) return extra[name]!;
  for (final e in engines) {
    if (e.name == name) {
      return (r, t) {
        final made = e.make(r, t);
        return (String s) => made.$1(s).root;
      };
    }
  }
  throw StateError('no engine $name');
}

String label(Clause? c) {
  if (c == null) return '<no clause>';
  if (c is Ref) return c.ruleName;
  final s = c.toString();
  return s.length > 26 ? '${s.substring(0, 26)}...' : s;
}

void dump(MatchResult m, String input, String pad) {
  final kind = m is SyntaxError ? 'ERR ' : '    ';
  final text = m.pos + m.len <= input.length
      ? input.substring(m.pos, m.pos + m.len)
      : '<OUT OF RANGE>';
  final shown = text.replaceAll('\n', '\\n');
  print('$pad$kind${label(m.clause)}  @${m.pos}+${m.len}'
      '${m.len == 0 ? "  <ZERO-WIDTH>" : "  ${json(shown)}"}');
  for (final k in m.subClauseMatches) {
    dump(k, input, '$pad  ');
  }
}

String json(String s) => '"$s"';

void main(List<String> argv) {
  final engine = argv[0], gram = argv[1], input = argv[2];
  final c = corpora.firstWhere((x) => x.name == gram);
  final rules = MetaGrammar.parseGrammar(c.grammar);
  final run = build(engine)(rules, c.top);
  final root = run(input);
  print('$engine   [$gram]   ${json(input)}   (len ${input.length})');
  if (root == null) {
    print('  CRASH / null');
    return;
  }
  dump(root, input, '  ');
  print('skeleton: ${skeleton(root, c.named).join(' ')}');
}
