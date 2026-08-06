// _swallow75.dart -- is `amb`'s shape loss the STRING-SWALLOW, or something else?
//
// `_amb75` showed the (invention, loss) tie-break winning both named cases and
// cutting input loss 471 -> 334, while shape fell 517 -> 474. The suspected
// cause is a single degenerate repair: JSON's string body accepts almost
// anything, and its escape prefix `\` is a SINGLETON class, so inserting a
// backslash asserts nothing the grammar did not already force and destroys no
// input character. (invention, loss) therefore scores it perfectly -- while it
// silently drags neighbouring structure INSIDE the string, re-interpreting
// characters it never touched.
//
// If that is the whole story, then (invention, loss) is not wrong, it is
// INCOMPLETE: there is a third kind of damage it cannot see. A character can be
// kept, un-invented, and still be ruined, by being given a different role.
//
// This counts, over the battery: how often each arm emits a backslash the input
// did not contain, and what the shape verdict is on exactly those inputs.
import 'dart:io';

import 'final_table.dart' show buildSetup, treeShape;
import '_m74w.dart' as e74;
import '_m74ambw.dart' as eamb;

const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';

int count(String s, String ch) =>
    s.split('').where((c) => c == ch).length;

void main() {
  final (rules, battery, origShape, _, __, ___, ____, _____) = buildSetup();
  final a74 = e74.SuperDot3(rules: rules, topRuleName: 'JSON');
  final aamb = eamb.SuperDot3(rules: rules, topRuleName: 'JSON');

  var swallowAmb = 0, swallow74 = 0;
  var ambShapeOnSwallow = 0, m74ShapeOnSwallow = 0;
  var ambShapeOffSwallow = 0, m74ShapeOffSwallow = 0, offCount = 0;
  final examples = <String>[];

  for (final s in battery) {
    final r74 = a74.recover(s);
    final ramb = aamb.recover(s);
    final y74 = a74.lastRepairedDoc, yamb = aamb.lastRepairedDoc;
    final ok74 = treeShape(r74.root) == origShape;
    final okamb = treeShape(ramb.root) == origShape;
    final sw74 = count(y74, '\\') > count(s, '\\');
    final swamb = count(yamb, '\\') > count(s, '\\');
    if (sw74) swallow74++;
    if (swamb) {
      swallowAmb++;
      if (okamb) ambShapeOnSwallow++;
      if (ok74) m74ShapeOnSwallow++;
      if (examples.length < 6) {
        examples.add('  input $s\n    m74 $y74${ok74 ? "   [shape ok]" : ""}\n'
            '    amb $yamb${okamb ? "   [shape ok]" : ""}');
      }
    } else {
      offCount++;
      if (okamb) ambShapeOffSwallow++;
      if (ok74) m74ShapeOffSwallow++;
    }
  }

  stdout.writeln('battery ${battery.length} inputs\n');
  stdout.writeln('repairs that emit a backslash the input did not have:');
  stdout.writeln('  m74 $swallow74');
  stdout.writeln('  amb $swallowAmb');
  stdout.writeln('\nshape, split by whether amb swallowed:');
  stdout.writeln('                       inputs    m74 shape   amb shape');
  stdout.writeln('  amb swallowed    ${swallowAmb.toString().padLeft(10)}  '
      '${m74ShapeOnSwallow.toString().padLeft(11)} '
      '${ambShapeOnSwallow.toString().padLeft(11)}');
  stdout.writeln('  amb did not      ${offCount.toString().padLeft(10)}  '
      '${m74ShapeOffSwallow.toString().padLeft(11)} '
      '${ambShapeOffSwallow.toString().padLeft(11)}');
  stdout.writeln('  ------------------------------------------------------');
  stdout.writeln('  total            ${battery.length.toString().padLeft(10)}  '
      '${(m74ShapeOnSwallow + m74ShapeOffSwallow).toString().padLeft(11)} '
      '${(ambShapeOnSwallow + ambShapeOffSwallow).toString().padLeft(11)}');
  stdout.writeln('\nexamples of the swallow:');
  for (final e in examples) {
    stdout.writeln(e);
  }
}
