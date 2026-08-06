import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/recovery/skip_recovery.dart' show SkipResult;
import 'final_table.dart' show buildSetup, treeShape;
import 'm76.dart' as e;

const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';

String report(SkipResult r, String input) {
  final xs = <String>[
    for (final s in r.errorSpans)
      'delete "${input.substring(s.pos, s.pos + s.len)}" @${s.pos}',
    for (final m in r.missing) 'missing ${m.clause} @${m.pos}',
  ];
  return xs.join(', ');
}

void main() {
  final setup = buildSetup();
  final engine = e.SuperDot3(rules: setup.$1, topRuleName: 'JSON');
  final probes = <(String, String)>[
    ('transpose [2 -> 2[',
      '{"a":1,"bc":2[,33,true],"d":{"e":null},"f":"gh"}'),
    ('must insert comma',
      base.substring(0, 16) + base[17] + base[16] + base.substring(18)),
    ('must delete leading comma', base.substring(0, 13) + base.substring(14)),
    ('literal ,3true', ',3true'),
    ('literal [,2,', '[,2,'),
  ];
  print('fabricationBound=${engine.fabricationBound}');
  var hardPassed = 0;
  for (final (index, probe) in probes.indexed) {
    final (name, input) = probe;
    final r = engine.recover(input);
    print('$name cost=${engine.lastCost} verified=${engine.lastVerified} '
        'inv=${engine.lastInvention} desc=${engine.lastDescription} '
        'shape=${treeShape(r.root) == setup.$3}');
    print('  ${report(r, input)}');
    for (final m in r.missing) {
      final c = m.clause;
      if (c is CharSet) print('    class ${c.ranges} inverted=${c.inverted} '
          'emissions=${engine.emissionSizes(c)}');
    }
    if (index == 1 &&
        engine.lastCost == 1 &&
        r.errorSpans.isEmpty &&
        r.missing.any((m) => m.pos == 18 &&
            (m.clause is Char && (m.clause as Char).char == ',' ||
             m.clause is Str && (m.clause as Str).text == ','))) hardPassed++;
    if (index == 2 &&
        engine.lastCost == 1 &&
        r.errorSpans.any((s) => s.pos == 13 && s.len == 1)) hardPassed++;
    if (index == 1 || index == 2) {
      print('    hardCheck index=$index spans='
          '${r.errorSpans.map((s) => '${s.pos}:${s.len}').join('|')} '
          'missing=${r.missing.map((m) => '${m.pos}:${m.clause}').join('|')}');
    }
  }
  print('namedHardCases=$hardPassed/2');
}
