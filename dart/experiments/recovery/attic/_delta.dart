// _delta.dart -- score TWO engines per case and report where the score moved.
//
// `_div` compares skeletons, so it says THAT two engines disagree, not whether
// the disagreement was an improvement. When an aggregate goes up while the
// perfect count goes down, those are two different sets of cases moving in
// opposite directions, and the summary line cannot separate them. This does.
//
// Usage: dart run _delta.dart <engineA> <engineB> [maxToPrint]
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'm92.dart' as g92;
import 'm97.dart' as g97;
import 'm98.dart' as g98;
import 'm99.dart' as g99;
import 'm100.dart' as g100;
import 'm101.dart' as g101;
import 'm102.dart' as g102;
import 'm103.dart' as g103;
import 'm105.dart' as g105;
import 'm106.dart' as g106;
import 'm108.dart' as g108;
import 'm109.dart' as g109;

typedef Build = MatchResult? Function(String) Function(
    Map<String, Clause>, String);

final Map<String, Build> made = {
  'm92': (r, t) => g92.SuperDot3(rules: r, topRuleName: t).recover,
  'm97': (r, t) => g97.SuperDot3(rules: r, topRuleName: t).recover,
  'm98': (r, t) => g98.SuperDot3(rules: r, topRuleName: t).recover,
  'm99': (r, t) => g99.SuperDot3(rules: r, topRuleName: t).recover,
  'm100': (r, t) => g100.SuperDot3(rules: r, topRuleName: t).recover,
  'm101': (r, t) => g101.SuperDot3(rules: r, topRuleName: t).recover,
  'm102': (r, t) => g102.SuperDot3(rules: r, topRuleName: t).recover,
  'm103': (r, t) => g103.SuperDot3(rules: r, topRuleName: t).recover,
  'm105': (r, t) => g105.SuperDot3(rules: r, topRuleName: t).recover,
  'm106': (r, t) => g106.SuperDot3(rules: r, topRuleName: t).recover,
  'm108': (r, t) => g108.SuperDot3(rules: r, topRuleName: t).recover,
  'm109': (r, t) => g109.SuperDot3(rules: r, topRuleName: t).recover,
};

void main(List<String> argv) {
  final a = argv[0], b = argv[1];
  final cap = argv.length > 2 ? int.parse(argv[2]) : 40;

  final cases = weighted(buildBattery());
  final byCorpus = <String, Corpus>{for (final c in corpora) c.name: c};
  final rules = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final original = <String, MatchResult>{};
  for (final c in corpora) {
    for (final doc in c.documents) {
      original['${c.name} $doc'] =
          Parser(rules: rules[c.name]!, topRuleName: c.top, input: doc)
              .parse()
              .root;
    }
  }
  final ra = <String, MatchResult? Function(String)>{
    for (final c in corpora) c.name: made[a]!(rules[c.name]!, c.top)
  };
  final rb = <String, MatchResult? Function(String)>{
    for (final c in corpora) c.name: made[b]!(rules[c.name]!, c.top)
  };

  var up = 0, down = 0, lostPerfect = 0, wonPerfect = 0;
  double sumUp = 0, sumDown = 0;
  final upCat = <String, int>{}, downCat = <String, int>{};
  var n = 0;
  for (final k in cases) {
    final c = byCorpus[k.grammar]!;
    MatchResult? x, y;
    try {
      x = ra[k.grammar]!(k.mutant);
    } catch (_) {}
    try {
      y = rb[k.grammar]!(k.mutant);
    } catch (_) {}
    final exp = expectedFor(k, original['${k.grammar} ${k.original}']!, c.named);
    final sx = scoreCase(
        produced: x, expected: exp, inputLen: k.mutant.length, named: c.named);
    final sy = scoreCase(
        produced: y, expected: exp, inputLen: k.mutant.length, named: c.named);
    if (sx.score == sy.score) continue;
    if (sy.score > sx.score) {
      up++;
      sumUp += sy.score - sx.score;
      upCat[k.category] = (upCat[k.category] ?? 0) + 1;
    } else {
      down++;
      sumDown += sx.score - sy.score;
      downCat[k.category] = (downCat[k.category] ?? 0) + 1;
    }
    if (sx.score == 1.0 && sy.score < 1.0) lostPerfect++;
    if (sx.score < 1.0 && sy.score == 1.0) wonPerfect++;
    n++;
    final only = argv.length > 3 ? argv[3] : '';
    if (n <= cap &&
        (only.isEmpty ||
            (only == 'worse' && sy.score < sx.score) ||
            (only == 'better' && sy.score > sx.score))) {
      print('--- ${k.grammar} / ${k.category}   '
          '$a ${sx.score.toStringAsFixed(3)} -> $b ${sy.score.toStringAsFixed(3)}');
      print('    orig   ${k.original}');
      print('    mutant ${k.mutant}');
      print('    $a  ${x == null ? "<null>" : skeleton(x, c.named).join(" ")}');
      print('    $b  ${y == null ? "<null>" : skeleton(y, c.named).join(" ")}');
    }
  }
  print('');
  print('cases whose score moved: $n of ${cases.length}');
  print('  $b better on $up (total +${sumUp.toStringAsFixed(3)})  $upCat');
  print('  $b worse  on $down (total -${sumDown.toStringAsFixed(3)})  $downCat');
  print('  perfect lost $lostPerfect, perfect won $wonPerfect');
  print('  net aggregate change '
      '${((sumUp - sumDown) / cases.length).toStringAsFixed(6)}');
}
