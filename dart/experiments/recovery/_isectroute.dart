// _isectroute.dart -- WHICH ROUTE answers the intersection cases?
//
// `_isectall` shows m62, m64, m66, m67, m69, cgfr5 and m70 all answer the four
// intersection cases correctly and only m65 and m68 do not. That is a different
// story from the one the m69 note tells. Two mechanisms can produce a right
// answer here: the I4 fusion `&C T == C intersect T`, which computes the
// intersection exactly and needs no alphabet at all, and the tape, which
// enumerates candidate strings from a proposal alphabet. Only the tape route can
// be defeated by a one-representative-per-terminal alphabet.
//
// So the question is not "who is right" but "who is right BY FUSION and who is
// right BY THE TAPE": `lastFellBack` says which.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'cgfr5.dart' as e_cgfr5;
import 'm66.dart' as e66;
import 'm67.dart' as e67;
import 'm68.dart' as e68;
import 'm69.dart' as e69;
import 'm70.dart' as e70;

const gSrc = "S <- &[a-z] [0-9m-q];\n";

void main() {
  final r = MetaGrammar.parseGrammar(gSrc);
  print('grammar $gSrc  input ""   truth = 1 (witness "m")');
  print('engine    cost  fellBack(tape?)');
  void one(String name, int Function() cost, bool Function() fb) {
    final c = cost();
    print('${name.padRight(8)} ${c.toString().padLeft(5)}  ${fb()}');
  }

  // m65 is the pure-tape engine (I21) and has no route to report.
  final a66 = e66.SuperDot3(rules: r, topRuleName: 'S');
  one('m66', () => a66.recoverCost(''), () => a66.lastFellBack);
  final a67 = e67.SuperDot3(rules: r, topRuleName: 'S');
  one('m67', () => a67.recoverCost(''), () => a67.lastFellBack);
  final a68 = e68.SuperDot3(rules: r, topRuleName: 'S');
  one('m68', () => a68.recoverCost(''), () => a68.lastFellBack);
  final a69 = e69.SuperDot3(rules: r, topRuleName: 'S');
  one('m69', () => a69.recoverCost(''), () => a69.lastFellBack);
  final ac5 = e_cgfr5.SuperDot3(rules: r, topRuleName: 'S');
  one('cgfr5', () => ac5.recoverCost(''), () => ac5.lastFellBack);
  final a70 = e70.SuperDot3(rules: r, topRuleName: 'S');
  one('m70', () => a70.recoverCost(''), () => a70.lastFellBack);
}
