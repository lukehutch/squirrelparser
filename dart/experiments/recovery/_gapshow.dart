// Prints each gap recovery chose on generated JSON (see _gapscale.dart), with the deleted delimiters.
import 'dart:math';
import 'package:squirrel_parser/squirrel_parser.dart';
import '../../test/recovery/astdiff.dart';
import '_gapscale.dart' show makeDoc;

void main(List<String> args) {
  final [m, k] = args[0].split('/').map(int.parse).toList();
  final doc = makeDoc(m, k, Random(7)), clean = makeDoc(m, 0, Random(7));
  var i = 0;
  while (i < doc.length && doc[i] == clean[i]) i++;
  print('first damage at $i: ...${clean.substring(max(0, i - 20), min(clean.length, i + 20))}...');
  final p = Parser(rules: MetaGrammar.parseGrammar(jsonGrammar), topRuleName: 'JSON', input: doc);
  final sw = Stopwatch()..start();
  p.parse(recover: true);
  print('ms=${sw.elapsedMilliseconds} gaps=${p.gaps.length}');
  for (final e in p.gaps.entries.toList()..sort((a, b) => a.key.$2 - b.key.$2)) {
    final at = e.key.$2;
    print('$at+${e.value} [${doc.substring(at, at + e.value)}] ctx ...${doc.substring(max(0, at - 15), at)}|${doc.substring(at, min(doc.length, at + 25))} in ${e.key.$1}');
  }
}
