import 'package:squirrel_parser/squirrel_parser.dart';
import 'm26.dart' as a26;
import 'm35.dart' as a35;
import 'm36.dart' as a36;
bool inLang(Map<String,Clause> r,String t,String s){final p=Parser(rules:r,topRuleName:t,input:s).parse();return !p.hasSyntaxErrors&&p.root!=null&&p.root!.len==s.length;}
void main(){
  final cases=<(String,String,String,String)>[
    ('possessive star',"S <- 'a'* \"ab\";\n",'S','aab'),
    ('possessive star+',"S <- 'a'* \"ab\";\n",'S','aaaab'),
    ('committed choice',"S <- ('a' / \"ab\") 'b';\n",'S','abb'),
    ('committed nested',"S <- A 'c';\nA <- 'a' / \"ab\";\n",'S','abc'),
    ('greedy optional',"S <- 'a'? \"ab\";\n",'S','aab'),
  ];
  print('${'case'.padRight(20)}${'in'.padRight(8)}${'true'.padLeft(5)}${'m26'.padLeft(5)}${'m35'.padLeft(5)}${'m36'.padLeft(5)}');
  for(final (name,g,top,s) in cases){
    final r=MetaGrammar.parseGrammar(g);
    var fr={s};final seen={s};int? truth;
    for(var k=0;k<=3&&truth==null;k++){
      for(final c in fr){if(inLang(r,top,c)){truth=k;break;}}
      if(truth!=null)break;
      final nx=<String>{};
      for(final c in fr){
        for(var i=0;i<c.length;i++){final d=c.substring(0,i)+c.substring(i+1);if(seen.add(d))nx.add(d);}
        for(var i=0;i<=c.length;i++){for(final ch in ['a','b','c']){
          final ins=c.substring(0,i)+ch+c.substring(i);if(seen.add(ins))nx.add(ins);
          if(i<c.length){final su=c.substring(0,i)+ch+c.substring(i+1);if(seen.add(su))nx.add(su);}}}
      }
      fr=nx;
    }
    String go(int Function(String) f){try{return f(s).toString();}catch(e){return 'X';}}
    final w=truth?.toString()??'>3';
    print('${name.padRight(20)}${s.padRight(8)}${w.padLeft(5)}'
      '${go(a26.SuperDot3(rules:r,topRuleName:top).recoverCost).padLeft(5)}'
      '${go(a35.SuperDot3(rules:r,topRuleName:top).recoverCost).padLeft(5)}'
      '${go(a36.SuperDot3(rules:r,topRuleName:top).recoverCost).padLeft(5)}');
  }
}
