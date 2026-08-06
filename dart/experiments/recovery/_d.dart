import 'package:squirrel_parser/squirrel_parser.dart';
void main(){
  for (final (g,top,s) in [
    ("S <- ('a' / \"ab\") 'b';\n",'S','abb'),
    ("S <- A 'c';\nA <- 'a' / \"ab\";\n",'S','abc'),
    ("S <- 'a'* \"ab\";\n",'S','aab'),
  ]) {
    final r=MetaGrammar.parseGrammar(g);
    final p=Parser(rules:r,topRuleName:top,input:s).parse();
    print('$s  hasSyntaxErrors=${p.hasSyntaxErrors}  root=${p.root==null?"null":"len ${p.root!.len}"}  n=${s.length}');
  }
}
