// _shape.dart -- WHICH DIRECTION IS THE SHAPE ERROR?
//
// An aggregate score says an engine is worse; it does not say whether the tree
// is too BIG or too SMALL. The two have opposite fixes, so the number has to be
// split before anything is changed.
//
//   over   -- sum of max(0, |got| - |expected|), structure the engine invented
//             that the document's own parse does not have. For an engine that
//             prefers FILL, this is where the loss lands: filling a NAMED rule
//             emits `Name ( )` into the skeleton where the original has nothing.
//   under  -- sum of max(0, |expected| - |got|), structure the engine failed to
//             recover.
//
// Also breaks an engine's zero-width fills down by whether the filled clause is
// a Ref to a NAMED rule -- only those reach the skeleton, so only those can cost
// shape points. A fill of a bare `'}'` is invisible to this metric and is
// exactly the structural repair the brief asks for.
//
// Usage: dart run _shape.dart <engineName> [...]
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

/// Count zero-width leaves, split by whether they reach the skeleton.
(int, int) fills(MatchResult root, Set<String> named) {
  var namedFill = 0, plainFill = 0;
  void walk(MatchResult m) {
    if (m.subClauseMatches.isEmpty && m.len == 0 && m is! SyntaxError) {
      final c = m.clause;
      if (c is Ref && named.contains(c.ruleName)) {
        namedFill++;
      } else {
        plainFill++;
      }
    }
    m.subClauseMatches.forEach(walk);
  }

  walk(root);
  return (namedFill, plainFill);
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

  print('engine   score     over    under  namedFill  plainFill'
      '   empty  giveup  worstUnder');
  for (final name in argv) {
    final build = resolve(name);
    if (build == null) {
      print('$name UNKNOWN');
      continue;
    }
    final made = <String, MatchResult? Function(String)>{
      for (final c in corpora) c.name: build(rulesOf[c.name]!, c.top)
    };
    var over = 0, under = 0, nf = 0, pf = 0;
    // `empty`  -- the engine returned a tree with NO named rule in it at all.
    // `giveup` -- the root is a bare SyntaxError spanning the whole input, which
    //             is m82's total-failure return. Neither shows up in the
    //             `crashed`/`uncovered` columns, because such a tree is a valid,
    //             fully-covering tree; it just says nothing.
    var empty = 0, giveup = 0, worst = 0;
    double total = 0;
    for (final k in cases) {
      final c = byCorpus[k.grammar]!;
      MatchResult? produced;
      try {
        produced = made[k.grammar]!(k.mutant);
      } catch (_) {
        produced = null;
      }
      final exp = expected['${k.grammar} ${k.original}']!;
      total += scoreCase(
        produced: produced,
        expected: exp,
        inputLen: k.mutant.length,
        named: c.named,
      ).score;
      if (produced == null) {
        under += exp.length;
        continue;
      }
      final got = skeleton(produced, c.named);
      if (got.length > exp.length) over += got.length - exp.length;
      if (exp.length > got.length) {
        under += exp.length - got.length;
        if (exp.length - got.length > worst) worst = exp.length - got.length;
      }
      if (got.isEmpty) empty++;
      if (produced is SyntaxError && produced.len == k.mutant.length) giveup++;
      final (a, b) = fills(produced, c.named);
      nf += a;
      pf += b;
    }
    print('${name.padRight(8)}'
        '${(total / cases.length).toStringAsFixed(4).padLeft(7)}'
        '${over.toString().padLeft(9)}'
        '${under.toString().padLeft(9)}'
        '${nf.toString().padLeft(11)}'
        '${pf.toString().padLeft(11)}'
        '${empty.toString().padLeft(8)}'
        '${giveup.toString().padLeft(8)}'
        '${worst.toString().padLeft(12)}');
  }
}
