// _wit.dart -- render the repaired witness for named engines on given inputs, so
// a category score can be read as a concrete tree rather than a number.
//
// Usage: dart run _wit.dart <corpus> <engineA> <engineB> -- <input> [<input> ...]
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'm121.dart' as m121;
import 'm126.dart' as m126;
import 'm127.dart' as m127;
import 'm132.dart' as m132;
import 'm136.dart' as m136;
import 'm141.dart' as m141;
import 'm143.dart' as m143;
import 'm145.dart' as m145;

String? filled(MatchResult m) => switch (m) {
      m121.Filled f => f.text,
      m126.Filled f => f.text,
      m127.Filled f => f.text,
      m132.Filled f => f.text,
      m136.Filled f => f.text,
      m141.Filled f => f.text,
      m143.Filled f => f.text,
      m145.Filled f => f.text,
      _ => null,
    };

/// The string the repair claims parses: real characters as they are, invented
/// ones in `<>`, skipped ones dropped.
void wit(MatchResult m, String src, StringBuffer b) {
  final f = filled(m);
  if (f != null) return b.write('<$f>');
  if (m is SyntaxError) return b.write('[-${src.substring(m.pos, (m.pos + m.len).clamp(0, src.length))}-]');
  if (m is Match && m.subClauseMatches.isEmpty) {
    return b.write(src.substring(m.pos, (m.pos + m.len).clamp(0, src.length)));
  }
  if (m is Match) {
    for (final k in m.subClauseMatches) {
      wit(k, src, b);
    }
  }
}

(MatchResult?, int) run(String e, Map<String, Clause> rules, String top, String s) {
  switch (e) {
    case 'm121':
      final p = m121.SuperDot3(rules: rules, topRuleName: top);
      return (p.recover(s), p.lastCost);
    case 'm126':
      final p = m126.SuperDot3(rules: rules, topRuleName: top);
      return (p.recover(s), p.lastCost);
    case 'm127':
      final p = m127.SuperDot3(rules: rules, topRuleName: top);
      return (p.recover(s), p.lastCost);
    case 'm132':
      final p = m132.SuperDot3(rules: rules, topRuleName: top);
      return (p.recover(s), p.lastCost);
    case 'm136':
      final p = m136.SuperDot3(rules: rules, topRuleName: top);
      return (p.recover(s), p.lastCost);
    case 'm141':
      final p = m141.SuperDot3(rules: rules, topRuleName: top);
      return (p.recover(s), p.lastCost);
    case 'm143':
      final p = m143.SuperDot3(rules: rules, topRuleName: top);
      return (p.recover(s), p.lastCost);
    case 'm145':
      final p = m145.SuperDot3(rules: rules, topRuleName: top);
      return (p.recover(s), p.lastCost);
  }
  return (null, -1);
}

void main(List<String> argv) {
  final i = argv.indexOf('--');
  final engines = argv.sublist(1, i);
  final inputs = argv.sublist(i + 1);
  final c = corpora.firstWhere((e) => e.name == argv[0]);
  final rules = MetaGrammar.parseGrammar(c.grammar);

  // The battery's expectation for a truncate case is the undamaged tree with
  // every node lying wholly past the cut dropped, so it needs the original.
  final doc = c.documents.firstWhere((d) => d.startsWith(inputs.first),
      orElse: () => inputs.first);
  final orig = Parser(rules: rules, topRuleName: c.top, input: doc).parse().root;

  for (final s in inputs) {
    final d = c.documents.firstWhere((d) => d.startsWith(s), orElse: () => doc);
    final o = d == doc
        ? orig
        : Parser(rules: rules, topRuleName: c.top, input: d).parse().root;
    final exp = expectedFor(
        Case(c.name, d, s, 'truncate'), o, c.named);
    print('input     $s');
    print('  expect  ${exp.join(' ').replaceAll('( ', '(').replaceAll(' )', ')')}');
    for (final e in engines) {
      final (r, k) = run(e, rules, c.top, s);
      final b = StringBuffer();
      if (r != null) wit(r, s, b);
      final got = r == null ? <String>[] : skeleton(r, c.named);
      print('  ${e.padRight(6)} cost=${k.toString().padLeft(3)} '
          'err=${editDistance(exp, got).toString().padLeft(2)}  $b');
      print('          ${got.join(' ').replaceAll('( ', '(').replaceAll(' )', ')')}');
    }
    print('');
  }
}
