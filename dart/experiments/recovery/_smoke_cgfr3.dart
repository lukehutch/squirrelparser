import 'package:squirrel_parser/squirrel_parser.dart';
import 'cgfr3.dart';

void main() {
  final rules = <String, Clause>{
    'Top': Seq([Ref('A'), Ref('B')]),
    'A': Str('a'),
    'B': Str('b'),
  };
  
  final parser = Cgfr3Parser(rules: rules, topRuleName: 'Top', input: 'axb');
  final result = parser.recover();
  
  print('Result cost: ${result.recoveryEvents}');
  print('Result missing: ${result.missing.map((o) => "${o.clause} at ${o.pos}").toList()}');
  print('Result spans: ${result.errorSpans.map((s) => "pos ${s.pos} len ${s.len}").toList()}');
}
