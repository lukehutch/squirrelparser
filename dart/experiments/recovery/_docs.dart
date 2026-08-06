// _docs.dart -- do the proposed new battery documents parse cleanly, and what
// does each one add to the SUPPLY of the scarce categories? A document that
// does not parse would give every case built from it a nonsense expected tree.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';

const cand = <String, List<String>>{
  'json': [
    '{"a":{"b":{"c":[1,2,{"d":[3,4]}]}},"e":[[1],[2,3]]}',
    '[{"x":[1,2],"y":{"z":3}},{"x":[],"y":{}}]',
    '{"p":[1,2,3],"q":[4,5,6],"r":[7,8,9],"s":[0,-1]}',
  ],
  'expr': [
    '((a+b)*(c-d))/((e+f)*(g-h))',
    '1+2*3-4/5+(6*7)-(8+9)',
    'a*(b+(c*(d+(e*f))))',
  ],
  'stmt': [
    'x="ab"; y="c"; { z="de"; }',
    'if (a) { b="hi"; } c="jk"; d=1;',
    '{ p="q"; { r="st"; } if (u) v="w"; }',
  ],
};

const delims = '{}[],:()=;+-*/';

void main() {
  for (final c in corpora) {
    final rules = MetaGrammar.parseGrammar(c.grammar);
    bool parses(String s) {
      try {
        return !Parser(rules: rules, topRuleName: c.top, input: s)
            .parse()
            .hasSyntaxErrors;
      } catch (_) {
        return false;
      }
    }

    print('=== ${c.name} ===');
    for (final doc in [...c.documents, ...cand[c.name]!]) {
      final isNew = !c.documents.contains(doc);
      // Supply a document furnishes in the two scarcest, weight-3.0 categories.
      var dd = 0;
      for (var j = 0; j < doc.length; j++) {
        if (delims.contains(doc[j]) &&
            !parses(doc.substring(0, j) + doc.substring(j + 1))) {
          dd++;
        }
      }
      var tr = 0;
      for (var k = 1; k < doc.length; k++) {
        if (!parses(doc.substring(0, k))) tr++;
      }
      print('  ${isNew ? "NEW " : "    "}parses=${parses(doc)}  '
          'len=${doc.length.toString().padLeft(2)}  '
          'delim-delete=${dd.toString().padLeft(2)}  '
          'truncate=${tr.toString().padLeft(2)}   $doc');
    }
    print('');
  }
}
