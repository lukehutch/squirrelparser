import 'package:squirrel_parser/squirrel_parser.dart';
void main() {
  for (final g in [
    "S <- ('ab' / 'a')+;",
    "S <- ('ab' / 'a')*;",
    "S <- (\"ab\" / \"a\")+;",
    "S <- A+; A <- 'ab' / 'a';",
    "S <- ('a' 'b')+;",
  ]) {
    try {
      MetaGrammar.parseGrammar(g);
      print('OK   $g');
    } catch (e) {
      print('FAIL $g   -> ${e.toString().split('\n').first}');
    }
  }
}
