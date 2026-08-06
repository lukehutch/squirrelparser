// _hist70.dart -- the battery's cost histogram was never checked against truth.
//
// Every row in the table prints a `costhist` for the 519-mutant battery, and
// every row said {1: 503, 2: 16} -- until cgfr1 said {1: 510, 2: 9}. The column
// is DISPLAYED, never SCORED, and `unsnd` cannot cover for it because `unsnd` is
// computed on the pred corpus. So an engine that underprices the battery shows
// up with a better-looking histogram and nothing flags it.
//
// The battery's true minimum is not a search problem, it is a construction
// property. `buildSetup` makes each mutant from `base` by exactly one of:
//
//   delete c      -- inserting c back is 1 edit  -> true min = 1
//   insert c      -- deleting it is 1 edit       -> true min = 1
//   substitute c  -- substituting back is 1 edit -> true min = 1
//   transpose x,y -- undoing costs 2 under delete/insert/substitute, so the
//                    true min is 2 UNLESS some unrelated single edit repairs
//                    it, which has to be searched.
//
// So only the transposes need searching, and the search is exhaustive over all
// 95 printable ASCII characters -- a negative result means "no single-byte edit
// exists at all", not "none over the alphabet I picked".
import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart';

const String base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';

bool ok(Map<String, Clause> rules, String s) {
  final p = Parser(rules: rules, topRuleName: 'JSON', input: s).parse();
  return !p.hasSyntaxErrors && p.root != null && p.root!.len == s.length;
}

/// Exhaustive single-character edit neighbourhood over printable ASCII.
String? oneEditRepair(Map<String, Clause> rules, String s) {
  for (var i = 0; i < s.length; i++) {
    if (ok(rules, s.substring(0, i) + s.substring(i + 1))) {
      return 'delete @$i';
    }
  }
  for (var i = 0; i <= s.length; i++) {
    for (var c = 32; c < 127; c++) {
      final ch = String.fromCharCode(c);
      if (ok(rules, s.substring(0, i) + ch + s.substring(i))) {
        return 'insert "$ch" @$i';
      }
      if (i < s.length &&
          s[i] != ch &&
          ok(rules, s.substring(0, i) + ch + s.substring(i + 1))) {
        return 'subst "$ch" @$i';
      }
    }
  }
  return null;
}

/// The battery, rebuilt WITH the edit kind that produced each mutant, in exactly
/// the order and under exactly the filter `buildSetup` uses.
(List<String>, List<String>) batteryWithKinds(Map<String, Clause> rules) {
  final mutants = <String>[], kinds = <String>[];
  void add(String m, String k) {
    mutants.add(m);
    kinds.add(k);
  }

  for (var j = 0; j < base.length; j++) {
    add(base.substring(0, j) + base.substring(j + 1), 'del');
    if (j + 1 < base.length && base[j] != base[j + 1]) {
      add(base.substring(0, j) + base[j + 1] + base[j] + base.substring(j + 2),
          'transpose');
    }
  }
  for (var j = 0; j <= base.length; j++) {
    for (final c in ['Q', 'z', '}', '"', ',', '5']) {
      add(base.substring(0, j) + c + base.substring(j), 'ins');
      if (j < base.length && base[j] != c) {
        add(base.substring(0, j) + c + base.substring(j + 1), 'sub');
      }
    }
  }

  final bm = <String>[], bk = <String>[];
  for (var i = 0; i < mutants.length; i++) {
    if (!ok(rules, mutants[i])) {
      bm.add(mutants[i]);
      bk.add(kinds[i]);
    }
  }
  return (bm, bk);
}

void main(List<String> args) {
  final (rules, battery, _, _, _, _, _, _) = buildSetup();
  final (bm, bk) = batteryWithKinds(rules);

  // The rebuild must reproduce buildSetup's battery exactly, or the kinds are
  // being attached to the wrong strings.
  if (bm.length != battery.length) {
    print('MISMATCH: rebuilt ${bm.length} vs buildSetup ${battery.length}');
    return;
  }
  for (var i = 0; i < bm.length; i++) {
    if (bm[i] != battery[i]) {
      print('MISMATCH at $i: "${bm[i]}" vs "${battery[i]}"');
      return;
    }
  }

  final sw = Stopwatch()..start();
  final trueMin = <int>[];
  var searched = 0;
  for (var i = 0; i < bm.length; i++) {
    if (bk[i] != 'transpose') {
      trueMin.add(1); // undoing the single edit is one edit
    } else {
      searched++;
      trueMin.add(oneEditRepair(rules, bm[i]) == null ? 2 : 1);
    }
  }
  sw.stop();

  final hist = <int, int>{};
  for (final t in trueMin) {
    hist[t] = (hist[t] ?? 0) + 1;
  }
  print('battery=${bm.length}  transposes=$searched  '
      'search=${sw.elapsedMilliseconds}ms');
  print('TRUE battery histogram: ${Map.fromEntries(hist.entries.toList()..sort((a, b) => a.key - b.key))}');
  print('');

  final names = args.isEmpty
      ? <String>['m62', 'm69', 'cgfr5', 'cgfr1', 'dot']
      : args[0].split(',');
  print('engine   exact  under   over  worst');
  for (final n in names) {
    final e = engines.firstWhere((x) => x.name == n);
    final (rec, cost, _) = e.make(rules, 'JSON');
    var exact = 0, under = 0, over = 0;
    var worst = '';
    for (var i = 0; i < bm.length; i++) {
      int? c;
      try {
        rec(bm[i]);
        c = cost();
      } catch (_) {}
      if (c == trueMin[i]) {
        exact++;
      } else if (c != null && c < trueMin[i]) {
        under++;
        if (worst.isEmpty) worst = 'under "${bm[i]}" said $c want ${trueMin[i]}';
      } else {
        over++;
        if (worst.isEmpty) worst = 'over "${bm[i]}" said $c want ${trueMin[i]}';
      }
    }
    print('${n.padRight(7)} ${exact.toString().padLeft(6)} '
        '${under.toString().padLeft(6)} ${over.toString().padLeft(6)}  $worst');
  }
}
