import 'package:squirrel_parser/squirrel_parser.dart';
import 'm26.dart' as a26;
import 'm35.dart' as a35;
import 'm36.dart' as a36;
import 'm38.dart' as a38;
void main(){
  final cases=<(String,String,String,String)>[
    ('possessive star',"S <- 'a'* \"ab\";\n",'S','aab'),
    ('committed choice',"S <- ('a' / \"ab\") 'b';\n",'S','abb'),
    ('committed nested',"S <- A 'c';\nA <- 'a' / \"ab\";\n",'S','abc'),
    ('greedy optional',"S <- 'a'? \"ab\";\n",'S','aab'),
  ];
  print('${'case'.padRight(20)}  maxCost=0: m26 m35 m36 m38   |  maxCost=40: m26 m35 m36 m38');
  for(final (name,g,top,s) in cases){
    final r=MetaGrammar.parseGrammar(g);
    String go(int Function(String,{int maxCost}) f,int mc){try{return f(s,maxCost:mc).toString().padLeft(4);}catch(e){return '   X';}}
    print('${name.padRight(20)}       '
      '${go(a26.SuperDot3(rules:r,topRuleName:top).recoverCost,0)}'
      '${go(a35.SuperDot3(rules:r,topRuleName:top).recoverCost,0)}'
      '${go(a36.SuperDot3(rules:r,topRuleName:top).recoverCost,0)}'
      '${go(a38.SuperDot3(rules:r,topRuleName:top).recoverCost,0)}   |            '
      '${go(a26.SuperDot3(rules:r,topRuleName:top).recoverCost,40)}'
      '${go(a35.SuperDot3(rules:r,topRuleName:top).recoverCost,40)}'
      '${go(a36.SuperDot3(rules:r,topRuleName:top).recoverCost,40)}'
      '${go(a38.SuperDot3(rules:r,topRuleName:top).recoverCost,40)}');
  }
}
