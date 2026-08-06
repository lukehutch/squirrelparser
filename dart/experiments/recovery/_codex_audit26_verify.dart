import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_v13cx.dart' as cx;
import 'r5.dart' as r5;
import '_codex_audit26_compact.dart' as compact;
import '_codex_audit26_compactpeg.dart' as compactpeg;

String ser(MatchResult m) {
  final b = StringBuffer();
  void walk(MatchResult n) {
    b.write('${n.runtimeType}:${n.clause}:${n.pos}:${n.len}(');
    for (final child in n.subClauseMatches) walk(child);
    b.write(')');
  }

  walk(m);
  return b.toString();
}

void main() {
  var probes = 0,
      probeDiffs = 0,
      fixedProbeDiffs = 0,
      accepted = 0,
      pegDiffs = 0,
      r5PegDiffs = 0,
      fixedPegDiffs = 0;
  final samples = <String>[];
  for (final (_, grammar, top, inputs) in cx.probes) {
    final rules = MetaGrammar.parseGrammar(grammar);
    final a = r5.Squirrel(rules: rules, topRuleName: top);
    final b = compact.Squirrel(rules: rules, topRuleName: top);
    final fixed = compactpeg.Squirrel(rules: rules, topRuleName: top);
    for (final input in inputs) {
      probes++;
      final ta = a.recover(input), tb = b.recover(input);
      final tf = fixed.recover(input);
      if ('${a.lastCost}|${ser(ta)}' != '${b.lastCost}|${ser(tb)}')
        probeDiffs++;
      if ('${a.lastCost}|${ser(ta)}' != '${fixed.lastCost}|${ser(tf)}')
        fixedProbeDiffs++;
      final frozen =
          Parser(rules: rules, topRuleName: top, input: input).parse();
      if (!frozen.hasSyntaxErrors) {
        accepted++;
        if (b.lastCost != 0 || ser(tb) != ser(frozen.root)) pegDiffs++;
        if (a.lastCost != 0 || ser(ta) != ser(frozen.root)) r5PegDiffs++;
        if (fixed.lastCost != 0 || ser(tf) != ser(frozen.root)) fixedPegDiffs++;
        if (ser(tb) != ser(frozen.root) && samples.length < 2) {
          samples.add('hand grammar=$grammar input="$input"\n'
              'frozen=${ser(frozen.root)}\nr5=${ser(ta)}\ncompact=${ser(tb)}');
        }
      }
    }
  }
  var documents = 0, documentDiffs = 0, fixedDocumentDiffs = 0;
  for (final corpus in corpora) {
    final rules = MetaGrammar.parseGrammar(corpus.grammar);
    final engine = compact.Squirrel(rules: rules, topRuleName: corpus.top);
    final fixed = compactpeg.Squirrel(rules: rules, topRuleName: corpus.top);
    for (final input in corpus.documents) {
      documents++;
      final frozen =
          Parser(rules: rules, topRuleName: corpus.top, input: input).parse();
      final recovered = engine.recover(input);
      final fixedTree = fixed.recover(input);
      if (frozen.hasSyntaxErrors ||
          fixed.lastCost != 0 ||
          ser(fixedTree) != ser(frozen.root)) fixedDocumentDiffs++;
      if (frozen.hasSyntaxErrors ||
          engine.lastCost != 0 ||
          ser(recovered) != ser(frozen.root)) {
        documentDiffs++;
        if (samples.length < 4) {
          final base = r5.Squirrel(rules: rules, topRuleName: corpus.top);
          final r5tree = base.recover(input);
          samples.add('corpus=${corpus.name} input="$input"\n'
              'frozen=${ser(frozen.root)}\nr5=${ser(r5tree)}\ncompact=${ser(recovered)}');
        }
      }
    }
  }
  print('hand_probes=$probes compact_vs_r5_diffs=$probeDiffs '
      'fixed_vs_r5_diffs=$fixedProbeDiffs');
  print('accepted_hand_inputs=$accepted r5_peg_diffs=$r5PegDiffs '
      'compact_peg_diffs=$pegDiffs fixed_peg_diffs=$fixedPegDiffs');
  print('original_documents=$documents compact_peg_diffs=$documentDiffs '
      'fixed_peg_diffs=$fixedDocumentDiffs');
  for (final sample in samples) print(sample);
}
