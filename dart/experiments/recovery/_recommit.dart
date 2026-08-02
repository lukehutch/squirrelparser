// _recommit.dart -- does the engine keep the structure the healthy prefix
// already committed to?
//
// The companion control to _freespan.dart. That one catches engines that DELETE
// input which already matched. This one catches a different way to throw away
// evidence: RE-READING an established prefix under a different rule because
// some other rule happens to be cheaper to repair.
//
// It exists because the chart engines repair `[1,[2,` by inventing two quote
// characters and calling the whole document a damaged JSON string -- cost 2,
// beating the cost-3 repair that closes both brackets. That is globally
// cost-minimal and structurally catastrophic (err 19 vs err 0), and NO existing
// gate caught it: m145 passes acceptance, conformance and free-span. The battery
// caught it only in aggregate.
//
// The test: the input's first character determines an unambiguous top-level
// construct under the cost-0 parser. Whatever the repair does further right, the
// tree it returns must still be headed by that construct. `arms` names the
// grammar's own top-level choice, so the question asked is one the grammar poses.
//
// WHAT IT FOUND, beyond the case it was built for:
//
//   m125 pre-I76           PASS  array,  cost 3
//   m126 pre-I76           PASS  array,  cost 3
//   m127 I76               FAIL  STRING, cost 2   <- I76 opens the reading
//   m128 I76 strict        FAIL  STRING
//   m129 I76 + I77         FAIL  STRING           <- I77 was built for this
//   m130 I77 without `got` FAIL  STRING
//   m131 I77 without I76   PASS  (I76 absent, so this says nothing about I77)
//   m132 I76 + I78         PASS  array,  cost 3   <- I78 closes it
//   m143 I76 + I78 + I81   PASS  array,  cost 3, err 0
//   m141 I78 + chart       FAIL  STRING, cost 2
//   m145 I78 + I81 + chart FAIL  STRING, cost 2
//
// Two results. First, I77 -- whose stated purpose was "a String that swallows
// structure loses to the reading that explains it" -- does NOT achieve that;
// m129 carries it and still fails. I78 does. I77 was withdrawn for scoring, and
// this is the harder reason it was right to withdraw.
//
// Second, and this is the structural one: m141 and m145 CARRY I78 and fail
// anyway. I78 admits a repair-opened alternative only where the input witnesses
// it -- a condition on the DESCENT, on which alternative may be opened. A chart
// materializes cells with no descent to test, so the guard has nothing to bind
// to. m132 reports cost 3 on `[1,[2,` and cost is the first key, so the cost-2
// reading is not outranked in the top-down search, it is UNREACHABLE; the chart
// puts it back. Every PEG-fidelity guard phrased over the derivation path is
// unenforceable in a bottom-up half. That, not latency, is why the two modes
// cannot share a guard set.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_score1.dart' show resolve;

/// Which alternative of the grammar's top-level choice the tree took.
///
/// [alts] is that choice's arms verbatim from the grammar, so this asks a
/// question the grammar itself poses. Labels outside [alts] are descended
/// through: `JSON` and `Value` wrap every reading alike, and it is the choice
/// under them that is at stake.
String? arm(MatchResult m, Set<String> alts) {
  final c = m.clause;
  final n = c is Ref ? c.ruleName : null;
  if (n != null && alts.contains(n)) return n;
  for (final k in m.subClauseMatches) {
    final r = arm(k, alts);
    if (r != null) return r;
  }
  return null;
}

class Probe {
  final String grammar, input, want;
  const Probe(this.grammar, this.input, this.want);
}

/// The arms of each grammar's top-level choice, verbatim from the grammar.
const arms = <String, Set<String>>{
  'json': {'Object', 'Array', 'String', 'Number', 'Boolean', 'Null'},
};

/// Each input opens with a character only one construct can begin, so the
/// committed reading is not a matter of taste.
const probes = <Probe>[
  Probe('json', '[1,[2,', 'Array'),
  Probe('json', '[1,[2,[3,', 'Array'),
  Probe('json', '[1,[2,[3,[4', 'Array'),
  Probe('json', '{"a":', 'Object'),
  Probe('json', '{"a":{"b":', 'Object'),
  Probe('json', '{"p":[1,2,3],"q":[4,5,6],"', 'Object'),
  Probe('json', '[{"x":[1,', 'Array'),
];

void main(List<String> argv) {
  final engines = argv.isNotEmpty
      ? argv
      : const ['m121', 'm126', 'm127', 'm132', 'm136', 'm141', 'm143', 'm145'];
  final rulesOf = {
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  print('${'engine'.padRight(8)}${'result'.padRight(8)}detail');
  var failed = 0;
  for (final e in engines) {
    final build = resolve(e);
    if (build == null) {
      print('${e.padRight(8)}UNKNOWN');
      continue;
    }
    final bad = <String>[];
    for (final k in probes) {
      final corpus = corpora.firstWhere((c) => c.name == k.grammar);
      final rec = build(rulesOf[k.grammar]!, corpus.top);
      String? got;
      try {
        final m = rec(k.input);
        got = m == null ? 'null' : arm(m, arms[k.grammar]!);
      } catch (_) {
        got = 'THREW';
      }
      if (got != k.want) {
        bad.add('${k.input} -> ${got ?? "none"} (want ${k.want})');
      }
    }
    if (bad.isNotEmpty) failed++;
    print('${e.padRight(8)}${(bad.isEmpty ? "PASS" : "FAIL").padRight(8)}'
        '${bad.isEmpty ? "${probes.length}/${probes.length} kept the committed construct" : bad.join("; ")}');
  }
  print('');
  print('$failed of ${engines.length} engines discard structure the healthy '
      'prefix established');
}
