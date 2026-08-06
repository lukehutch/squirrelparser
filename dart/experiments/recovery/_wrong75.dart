// _wrong75.dart -- scratch: WHICH answers is m75 getting wrong, and how?
// The subset gate counts 98 of 2387; a count cannot be designed against.
import 'package:squirrel_parser/squirrel_parser.dart';

import '_subset75.dart' show grammars, trueDist;
import 'm75.dart' as chase;

void main() {
  var checked = 0, wrong = 0;
  final byG = <String, List<String>>{};
  var tooLow = 0, tooHigh = 0, falseImpossible = 0, falsePossible = 0;
  for (final (g, top, alpha) in grammars) {
    final r = MetaGrammar.parseGrammar(g);
    final e = chase.SuperDot3(rules: r, topRuleName: top);
    final key = g.replaceAll('\n', ' ').trim();
    byG[key] = [];
    final strings = <String>[''];
    for (var len = 1; len <= 5; len++) {
      for (final p in strings.where((s) => s.length == len - 1).toList()) {
        for (final ch in alpha.split('')) {
          strings.add(p + ch);
        }
      }
    }
    for (final s in strings) {
      final truth = trueDist(r, top, s, alpha, 3);
      final c = e.recoverCost(s);
      final ok = truth == null ? (c > 3 || c == -1) : c == truth;
      checked++;
      if (ok) continue;
      wrong++;
      // Which DIRECTION is the error? Under-restriction lets the DP accept a
      // repair the real parser rejects, so the answer comes out TOO LOW;
      // over-restriction rejects a real repair, so it comes out TOO HIGH.
      final t = truth;
      if (t == null) {
        if (c >= 0 && c <= 3) {
          tooLow++;
        } else {
          tooHigh++;
        }
      } else if (c == -1) {
        falseImpossible++;
      } else if (c < t) {
        tooLow++;
      } else {
        tooHigh++;
      }
      if (c >= 0 && t == null) falsePossible++;
      byG[key]!.add('"$s" true=${truth ?? ">3"} m75=$c '
          'verified=${e.lastVerified}');
    }
  }
  print('checked=$checked  wrong=$wrong');
  print('  answer too LOW  (accepted a repair that does not exist) = $tooLow');
  print('     of those, claimed possible where truth is ">3"       '
      '= $falsePossible');
  print('  answer too HIGH (missed a repair that does exist)       = $tooHigh');
  print('  answered -1 where a repair exists                       '
      '= $falseImpossible');
  print('');
  byG.forEach((k, v) {
    if (v.isEmpty) return;
    print('${v.length.toString().padLeft(4)}  $k');
    for (final x in v.take(6)) {
      print('        $x');
    }
    if (v.length > 6) print('        ... and ${v.length - 6} more');
  });
}
