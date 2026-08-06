// Does the recorded PEG-priority defect still reproduce on m143?
//
// Recorded against m132: `Top <- A / B; A <- . 'a' 'b'; B <- 'x' 'a' 'b'` on
// `ab` selects B, whose witness `xab` re-parses to A -- so B is unreachable in
// the repaired string, and PEG ordered choice says A wins anyway. Same family as
// I82 (a reading the descent should not have opened), different guard.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'm126.dart' as e126;
import 'm127.dart' as e127;
import 'm132.dart' as e132;
import 'm143.dart' as e143;

const g = '''
Top <- A / B;
A <- . 'a' 'b';
B <- 'x' 'a' 'b';
''';

String label(MatchResult m) {
  final c = m.clause;
  if (c is Ref && (c.ruleName == 'A' || c.ruleName == 'B')) return c.ruleName;
  for (final k in m.subClauseMatches) {
    final r = label(k);
    if (r.isNotEmpty) return r;
  }
  return '';
}

void main() {
  final rules = MetaGrammar.parseGrammar(g);
  const input = 'ab';
  final probes = <String, MatchResult Function()>{
    'm126': () => e126.SuperDot3(rules: rules, topRuleName: 'Top').recover(input),
    'm127': () => e127.SuperDot3(rules: rules, topRuleName: 'Top').recover(input),
    'm132': () => e132.SuperDot3(rules: rules, topRuleName: 'Top').recover(input),
    'm143': () => e143.SuperDot3(rules: rules, topRuleName: 'Top').recover(input),
  };
  print('Top <- A / B;  A <- . \'a\' \'b\';  B <- \'x\' \'a\' \'b\';   input "ab"');
  print('PEG ordered choice says A. B\'s witness "xab" re-parses to A.');
  print('');
  for (final e in probes.entries) {
    try {
      final got = label(e.value());
      print('  ${e.key}  -> ${got.isEmpty ? "neither" : got}'
          '${got == 'A' ? "  ok" : "  DEFECT"}');
    } catch (x) {
      print('  ${e.key}  -> threw: $x');
    }
  }
}
