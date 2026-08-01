// _invent.dart -- DOES THE AST-DIFF SCORE REWARD INVENTION?
//
// The m75 elegNote records that the OLD shape column was the metric being
// wrong, not the engine: "on all 43 inputs where m74 matches the pre-corruption
// shape and m75 does not, m74 buys the match with at least one node the input
// does not support -- 43 of 43". The new AST-diff evaluator compares against the
// skeleton of the parse of the ORIGINAL UNDAMAGED document, so it can inherit
// exactly that bias -- it pays for guessing the document back, and guessing is
// what the brief forbids.
//
// So the score has to be read next to the invention it may be buying. The test
// is `_id77.dart`'s, unchanged in substance: hand every leaf of the finished
// tree back to the PURE parser at its own position over the UNTOUCHED input and
// ask whether it reads its own span.
//
// TWO KINDS OF UNSUPPORTED NODE, COUNTED SEPARATELY, because collapsing them is
// how this measurement would lie in the other direction:
//   * WIDE  -- len > 0 and it does not read its own span. The node CLAIMS real
//              input characters that do not say what it says. This is invention
//              that corrupts, and it is what the brief forbids.
//   * FILL  -- len == 0. It asserts structure and destroys nothing; the symbol
//              is not written into the input. The brief explicitly ALLOWS this
//              for a uniquely-determined delimiter (I36).
// An engine that scores well on shape while carrying WIDE nodes is buying the
// score with invention. One that scores well carrying only FILLs is not.
//
// Usage: dart run _invent.dart <engineName> [...]
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'final_table.dart' show engines;
import 'm79.dart' as g79;
import 'm80.dart' as g80;
import 'm81.dart' as g81;
import 'm82.dart' as g82;
import 'm83.dart' as g83;
import 'm84.dart' as g84;
import 'm85.dart' as g85;
import 'm86.dart' as g86;
import 'm87.dart' as g87;

typedef Build = MatchResult? Function(String) Function(
    Map<String, Clause>, String);

final Map<String, Build> extra = {
  'm79': (r, t) => g79.SuperDot3(rules: r, topRuleName: t).recover,
  'm80': (r, t) => g80.SuperDot3(rules: r, topRuleName: t).recover,
  'm81': (r, t) => g81.SuperDot3(rules: r, topRuleName: t).recover,
  'm82': (r, t) => g82.SuperDot3(rules: r, topRuleName: t).recover,
  'm83': (r, t) => g83.SuperDot3(rules: r, topRuleName: t).recover,
  'm84': (r, t) => g84.SuperDot3(rules: r, topRuleName: t).recover,
  'm85': (r, t) => g85.SuperDot3(rules: r, topRuleName: t).recover,
  'm86': (r, t) => g86.SuperDot3(rules: r, topRuleName: t).recover,
  'm87': (r, t) => g87.SuperDot3(rules: r, topRuleName: t).recover,
};

Build? resolve(String name) {
  if (extra.containsKey(name)) return extra[name];
  for (final e in engines) {
    if (e.name == name) {
      return (r, t) {
        final made = e.make(r, t);
        return (String s) => made.$1(s).root;
      };
    }
  }
  return null;
}

class Audit {
  var wide = 0, fill = 0, errNodes = 0;
  var tiles = true, total = true;
}

Audit audit(MatchResult root, int len, Parser oracle) {
  final a = Audit();
  final leaves = <(int, int)>[];
  void walk(MatchResult m, int lo, int hi) {
    if (m.pos < 0 || m.len < 0 || m.pos < lo || m.pos + m.len > hi) {
      a.tiles = false;
    }
    if (m is SyntaxError) a.errNodes++;
    final kids = m.subClauseMatches;
    if (kids.isEmpty) {
      if (m.len > 0) leaves.add((m.pos, m.pos + m.len));
      final c = m.clause;
      if (c != null && m is! SyntaxError) {
        final probe = c.match(oracle, m.pos);
        if (probe.isMismatch || probe.len != m.len) {
          if (m.len > 0) {
            a.wide++;
          } else {
            a.fill++;
          }
        }
      }
      return;
    }
    var cursor = m.pos;
    for (final k in kids) {
      if (k.pos < cursor) a.tiles = false;
      walk(k, m.pos, m.pos + m.len);
      cursor = k.pos + k.len;
    }
  }

  walk(root, 0, len);
  leaves.sort((x, y) => x.$1 - y.$1);
  var cursor = 0;
  for (final (s, e) in leaves) {
    if (s > cursor) a.total = false;
    if (e > cursor) cursor = e;
  }
  return a;
}

void main(List<String> argv) {
  final cases = weighted(buildBattery());
  final byCorpus = <String, Corpus>{for (final c in corpora) c.name: c};
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final expected = <String, List<String>>{};
  for (final c in corpora) {
    for (final doc in c.documents) {
      final r =
          Parser(rules: rulesOf[c.name]!, topRuleName: c.top, input: doc).parse();
      expected['${c.name} $doc'] = skeleton(r.root, c.named);
    }
  }

  print('engine   score   wide   fill  errN  !tile  !cover  crash');
  for (final name in argv) {
    final build = resolve(name);
    if (build == null) {
      print('$name UNKNOWN');
      continue;
    }
    final made = <String, MatchResult? Function(String)>{
      for (final c in corpora) c.name: build(rulesOf[c.name]!, c.top)
    };
    var wide = 0, fill = 0, errN = 0, noTile = 0, noCover = 0, crash = 0;
    double total = 0;
    for (final k in cases) {
      final c = byCorpus[k.grammar]!;
      MatchResult? produced;
      try {
        produced = made[k.grammar]!(k.mutant);
      } catch (_) {
        produced = null;
      }
      total += scoreCase(
        produced: produced,
        expected: expected['${k.grammar} ${k.original}']!,
        inputLen: k.mutant.length,
        named: c.named,
      ).score;
      if (produced == null) {
        crash++;
        continue;
      }
      final oracle = Parser(
          rules: rulesOf[k.grammar]!, topRuleName: c.top, input: k.mutant)
        ..parse();
      final a = audit(produced, k.mutant.length, oracle);
      wide += a.wide;
      fill += a.fill;
      errN += a.errNodes;
      if (!a.tiles) noTile++;
      if (!a.total) noCover++;
    }
    print('${name.padRight(8)}'
        '${(total / cases.length).toStringAsFixed(4).padLeft(7)}'
        '${wide.toString().padLeft(7)}'
        '${fill.toString().padLeft(7)}'
        '${errN.toString().padLeft(6)}'
        '${noTile.toString().padLeft(7)}'
        '${noCover.toString().padLeft(8)}'
        '${crash.toString().padLeft(7)}');
  }
}
