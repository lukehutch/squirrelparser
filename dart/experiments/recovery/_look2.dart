import 'dart:io';
import 'package:squirrel_parser/squirrel_parser.dart';
import 'cgfr2.dart' as c2;
import 'cgfr4.dart' as c4;
void main(List<String> args) {
  final r = MetaGrammar.parseGrammar('S <- &[a-z] [a-z];\n');
  final which = args[0];
  stderr.writeln('engine=$which on "Q"');
  final c = which == 'c2'
      ? c2.SuperDot3(rules: r, topRuleName: 'S').recoverCost('Q')
      : c4.SuperDot3(rules: r, topRuleName: 'S').recoverCost('Q');
  stderr.writeln('  cost=$c');
}
