// Scores Parser.parse(recover: true) (gap recovery at repetition stops) on the battery, beside plain parsing.
// Run from dart/: dart run experiments/recovery/_gap1.dart [raw] [show]
import 'package:squirrel_parser/squirrel_parser.dart';
import '../../test/recovery/astdiff.dart';

MatchResult tree(ParseResult r) => r.unmatchedInput == null
    ? r.root
    : Match(null, 0, 0, subClauseMatches: [r.root, r.unmatchedInput!]);

List<SyntaxError> errors(MatchResult m) => m is SyntaxError
    ? [m]
    : [for (final c in m.subClauseMatches) ...errors(c)];

void main(List<String> args) {
  final cases = args.contains('raw') ? buildBattery() : weighted(buildBattery());
  final show = args.contains('show');
  final rules = {for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)};
  final corpus = {for (final c in corpora) c.name: c};
  for (final recover in [false, true]) {
    final byCat = <String, List<double>>{};
    var sum = 0.0, whole = 0, skipped = 0, early = 0, late = 0, nerr = 0;
    final sw = Stopwatch()..start();
    for (final k in cases) {
      final c = corpus[k.grammar]!;
      final original = Parser(rules: rules[k.grammar]!, topRuleName: c.top, input: k.original).parse().root;
      final r = Parser(rules: rules[k.grammar]!, topRuleName: c.top, input: k.mutant).parse(recover: recover);
      final t = tree(r);
      final s = scoreCase(
          produced: t, expected: expectedFor(k, original, c.named), inputLen: k.mutant.length, named: c.named);
      sum += s.score;
      byCat.putIfAbsent(k.category, () => []).add(s.score);
      final es = errors(t);
      if (r.root is! SyntaxError) whole++;
      nerr += es.length;
      for (final e in es) skipped += e.len;
      var p = 0;
      while (p < k.mutant.length && p < k.original.length && k.mutant[p] == k.original[p]) p++;
      if (es.isNotEmpty && es.first.pos < p) early++;
      if (es.isNotEmpty) late += es.first.pos - p;
      if (show && recover) {
        print('${k.grammar} ${k.category} ${s.score.toStringAsFixed(2)} ${k.mutant}  ->  '
            '${es.map((e) => '[${e.pos}:${k.mutant.substring(e.pos, e.pos + e.len)}]').join(' ')}');
      }
    }
    final n = cases.length;
    print('recover=$recover cases=$n score=${(sum / n).toStringAsFixed(4)} '
        'tree(not whole-input error)=$whole errors=$nerr skipped=$skipped '
        'firstErrorBeforeDamage=$early meanFirstErrorOffset=${(late / n).toStringAsFixed(2)} ms=${sw.elapsedMilliseconds}');
    for (final e in byCat.entries) {
      print('  ${e.key}: ${(e.value.reduce((a, b) => a + b) / e.value.length).toStringAsFixed(4)} (${e.value.length})');
    }
  }
}
