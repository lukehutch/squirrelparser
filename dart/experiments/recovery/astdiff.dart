// astdiff.dart -- THE AST-DIFF EVALUATOR.
//
// WHY THE OLD METRIC HAD TO GO. `treeShape(produced) == treeShape(original)` is
// a PASS/FAIL, and it answers the wrong question twice over:
//
//   * It cannot tell a recovery that misplaced one node from one that re-read
//     half the document as the contents of a single string. Both score zero, so
//     the metric is blind to the difference between a near-miss and a disaster,
//     and an engine tuned against it is tuned against noise.
//   * It rewards reproducing the original CHARACTERS. But the input is only
//     evidence; the deliverable is the TREE. An engine that recovers the whole
//     object except for the one damaged member has done nearly all of the job.
//
// WHAT REPLACES IT. The expectation is stated exactly: the damage was applied to
// a document whose tree we know, so THE CORRECT REPAIRED AST IS THE UNDAMAGED
// DOCUMENT'S AST. Recovery's job is to recover as much of that shape as the
// evidence still supports. So the score is a DIFF: walk both trees into a
// sequence of structural labels and take the edit distance between them. That
// counts structural errors -- nodes lost, nodes invented, nodes relabelled --
// instead of asking whether there were none.
//
// WHY LABELS AND NOT TEXT. The metric has to be comparable across every engine
// in the table, and the engines disagree about what they are parsing: the
// string-repair engines build a tree over a REPAIRED string they synthesised,
// while the AST-centric ones build it over the original input with zero-width
// marks. Any text-keyed comparison would measure that difference rather than
// the recovery. Structural labels are the common ground, and they are what the
// owner's framing calls primal.
//
// THE REPAIR MARKS DROP OUT FOR FREE. A `SyntaxError` span and a zero-width
// FILL both carry no rule label, so neither appears in the sequence: a recovery
// is judged on the tree it claims, not on how it annotated the damage. That is
// what makes "flag the mutation in the tree" cost nothing in the score.

import 'package:squirrel_parser/squirrel_parser.dart';

// ---------------------------------------------------------------------------
// The metric.

/// Pre-order sequence of the named-rule labels in a tree.
///
/// `(` and `)` are emitted as their own tokens so that NESTING is part of what
/// the diff can get wrong: moving a member out of an object costs the two
/// brackets even when every label survives. Anonymous nodes -- sequences,
/// repetitions, terminals, and both repair marks -- contribute nothing, because
/// they are grammar bookkeeping rather than structure a reader would name.
List<String> skeleton(MatchResult r, Set<String> named) {
  final out = <String>[];
  void walk(MatchResult m) {
    final c = m.clause;
    if (c is Ref && named.contains(c.ruleName)) {
      out.add(c.ruleName);
      out.add('(');
      m.subClauseMatches.forEach(walk);
      out.add(')');
    } else {
      m.subClauseMatches.forEach(walk);
    }
  }

  walk(r);
  return out;
}

/// The skeleton a correct recovery is EXPECTED to produce for one damaged
/// document, given the parse of the undamaged one.
///
/// For nine of the ten categories the damage leaves every character position
/// occupied -- a delimiter is gone, a quote is doubled, two characters are
/// swapped -- so the undamaged skeleton is exactly what a reader still expects
/// to see, and this returns it unchanged.
///
/// TRUNCATION IS THE EXCEPTION, AND IT WAS SILENTLY WRONG. A truncate case is
/// `doc.substring(0, k)`: the tail of the document is not damaged, it is ABSENT.
/// Every named node lying entirely past `k` covers no character the engine can
/// read, so producing it would mean inventing content -- which the brief
/// forbids -- and demanding it charged every engine for obeying the rule. The
/// nodes that begin before `k` are kept, including the one straddling the cut,
/// because a node whose text runs off the end is precisely the unterminated
/// construct a reader does still expect to see reported.
///
/// Measured: this raises the truncate ceiling from 0.566 to 1.0, which is what
/// it should always have been. No named node in any corpus is zero-width
/// (0 of 667), so `pos < k` is exactly "covers at least one retained character".
List<String> expectedFor(Case k, MatchResult original, Set<String> named) {
  if (k.category != 'truncate') return skeleton(original, named);
  final cut = k.mutant.length;
  final out = <String>[];
  void walk(MatchResult m) {
    final c = m.clause;
    if (c is Ref && named.contains(c.ruleName)) {
      if (m.pos >= cut) return;
      out.add(c.ruleName);
      out.add('(');
      m.subClauseMatches.forEach(walk);
      out.add(')');
    } else {
      m.subClauseMatches.forEach(walk);
    }
  }

  walk(original);
  return out;
}

/// Levenshtein distance over label sequences: the number of structural errors.
///
/// Two rows rather than a full matrix, because this runs once per engine per
/// case and the sequences are hundreds of tokens long.
int editDistance(List<String> a, List<String> b) {
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  final cur = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    cur[0] = i;
    final ai = a[i - 1];
    for (var j = 1; j <= b.length; j++) {
      final sub = prev[j - 1] + (ai == b[j - 1] ? 0 : 1);
      final del = prev[j] + 1;
      final ins = cur[j - 1] + 1;
      cur[j] = sub < del ? (sub < ins ? sub : ins) : (del < ins ? del : ins);
    }
    prev = List<int>.of(cur);
  }
  return prev[b.length];
}

/// One case's result. [errors] is the raw structural error count; [score] is it
/// normalised so that cases with big trees do not silently outweigh small ones.
///
/// Normalising by the larger of the two lengths is what makes INVENTION cost as
/// much as LOSS: an engine that answers with a huge wrong tree scores near zero
/// rather than being rewarded for the labels it happened to include.
class CaseScore {
  const CaseScore(this.errors, this.score, this.covered, this.crashed);
  final int errors;
  final double score;
  final bool covered;
  final bool crashed;
}

CaseScore scoreCase({
  required MatchResult? produced,
  required List<String> expected,
  required int inputLen,
  required Set<String> named,
}) {
  if (produced == null) {
    return CaseScore(expected.length, 0, false, true);
  }
  final got = skeleton(produced, named);
  final d = editDistance(expected, got);
  final n = expected.length > got.length ? expected.length : got.length;
  return CaseScore(d, n == 0 ? 1 : 1 - d / n, covers(produced, inputLen), false);
}

/// Every leaf of the tree, in order, accounts for exactly the input -- no gap,
/// no overlap, nothing past the end. An engine that fails this has not produced
/// a tree OVER THE INPUT at all, whatever its labels say, so it is reported
/// separately rather than folded into the score.
bool covers(MatchResult root, int len) {
  var pos = 0;
  var ok = true;
  void walk(MatchResult m) {
    if (!ok) return;
    if (m is SyntaxError || m.subClauseMatches.isEmpty) {
      if (m.len == 0) return;
      if (m.pos != pos) ok = false;
      pos = m.pos + m.len;
      return;
    }
    m.subClauseMatches.forEach(walk);
  }

  walk(root);
  return ok && pos == len;
}

// ---------------------------------------------------------------------------
// The battery.

/// One damaged document, and the undamaged one it came from.
class Case {
  const Case(this.grammar, this.original, this.mutant, this.category);

  /// Index into [grammars].
  final String grammar;
  final String original;
  final String mutant;
  final String category;
}

/// A named grammar plus its top rule and the rule labels that count as
/// structure. Recovery is only interesting where the grammar has decisions in
/// it, so the set is every rule a reader would name in describing the parse.
class Corpus {
  const Corpus(this.name, this.grammar, this.top, this.named, this.documents);
  final String name;
  final String grammar;
  final String top;
  final Set<String> named;
  final List<String> documents;
}

const jsonGrammar = '''
JSON <- WS Value WS;
Value <- Object / Array / String / Number / Boolean / Null;
Object <- '{' WS (Member (WS ',' WS Member)*)? WS '}';
Member <- String WS ':' WS Value;
Array <- '[' WS (Value (WS ',' WS Value)*)? WS ']';
String <- '"' Character* '"';
Character <- [^"\\\\] / ('\\\\' Escape);
Escape <- '"' / '\\\\' / '/' / 'b' / 'f' / 'n' / 'r' / 't' / ('u' [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F]);
Number <- Integer Fraction? Exponent?;
Integer <- '-'? (([1-9] [0-9]+) / [0-9]);
Fraction <- '.' [0-9]+;
Exponent <- ("e" / "E") ("+" / "-")? [0-9]+;
Boolean <- "true" / "false";
Null <- "null";
~WS <- [ \\t\\n\\r]*;
''';

/// LEFT RECURSION, which recovery has to survive without the memo table
/// blocking itself. `Expr` grows leftward, so a repair inside the left operand
/// has to be visible to the frame that ENTERED the recursion.
const exprGrammar = '''
Expr <- Expr WS AddOp WS Term / Term;
Term <- Term WS MulOp WS Factor / Factor;
Factor <- Num / '(' WS Expr WS ')' / Name;
AddOp <- '+' / '-';
MulOp <- '*' / '/';
Num <- [0-9]+;
Name <- [a-z]+;
~WS <- [ \\t\\n]*;
''';

/// LOOKAHEAD, kept inside the scope the owner relaxed the requirement to: the
/// predicate bodies are Seq, ZeroOrMore/OneOrMore and terminals, with one
/// `First`, and NO repetition nested inside a repetition. A statement is
/// terminated by `;` unless the next token starts a block, and a bare word may
/// not be a keyword -- both of which a recovery has to honour while repairing.
const stmtGrammar = '''
Program <- WS Stmt+ WS;
Stmt <- Block / If / Assign;
Block <- '{' WS Stmt* WS '}' WS;
If <- "if" WS '(' WS Cond WS ')' WS Stmt;
Assign <- Name WS '=' WS Cond WS ';' WS;
Cond <- Name / Num / Str;
Name <- !Keyword [a-z]+;
Keyword <- ("if" / "else") !([a-z]);
Num <- [0-9]+;
Str <- '"' Chr* '"';
Chr <- [^"\\\\] / ('\\\\' Esc);
Esc <- '"' / '\\\\' / 'n' / 't';
~WS <- [ \\t\\n]*;
''';

const corpora = <Corpus>[
  Corpus('json', jsonGrammar, 'JSON', {
    'Object', 'Array', 'Member', 'String', 'Number', 'Boolean', 'Null', 'Value',
  }, [
    '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}',
    '[1,[2,[3,[4]]],5]',
    '{"k":[{"a":1},{"b":2}]}',
    '{"n":[0,-7,1.5,2e3],"t":[true,false,null]}',
    '{"alpha":"beta gamma","delta":["epsilon","zeta"]}',
    // Delimiter-dense, to feed `delim-delete` -- see `weighted`.
    '{"a":{"b":{"c":[1,2,{"d":[3,4]}]}},"e":[[1],[2,3]]}',
    '[{"x":[1,2],"y":{"z":3}},{"x":[],"y":{}}]',
    '{"p":[1,2,3],"q":[4,5,6],"r":[7,8,9],"s":[0,-1]}',
  ]),
  Corpus('expr', exprGrammar, 'Expr', {
    'Expr', 'Term', 'Factor', 'Num', 'Name', 'AddOp', 'MulOp',
  }, [
    'a+b*2-(3+c)*4',
    '1*(2+3*(4-5))',
    '(a*b)+(c*d)-(e+f)',
    '((a+b)*(c-d))/((e+f)*(g-h))',
    '1+2*3-4/5+(6*7)-(8+9)',
    'a*(b+(c*(d+(e*f))))',
  ]),
  Corpus('stmt', stmtGrammar, 'Program', {
    'Stmt', 'Block', 'If', 'Assign', 'Cond', 'Name', 'Num', 'Str',
  }, [
    'x=1; if (x) { y=2; z=3; } w=4;',
    'if (a) { if (b) { c=1; } }',
    '{ a=1; { b=2; } if (c) d=3; }',
    '{ a=1; b=2; { c=3; if (d) { e=4; } f=5; } g=6; }',
    'if (a) { b=1; } if (c) { d=2; } e=3;',
    'x=1; y=2; z=3; { p=4; q=5; } r=6;',
    // String literals in a NON-JSON grammar, so `quote-delete` and
    // `content-damage` are not measured against one grammar's string shape.
    'x="ab"; y="c"; { z="de"; }',
    'if (a) { b="hi"; } c="jk"; d=1;',
    '{ p="q"; { r="st"; } if (u) v="w"; }',
  ]),
];

// ---------------------------------------------------------------------------
// Categories and their weights.
//
// WEIGHTS ARE COVERAGE, NOT MULTIPLIERS. The owner asked for the score to be
// weighted by importance; the honest way to do that is to TEST the important
// patterns more, so a category's weight is how many cases it contributes, and
// the aggregate is a plain mean over cases. A multiplier applied to a thin
// category would let one lucky case swing the total.
//
// The ordering is what a person actually does to a document. Truncation leads
// because it is what an editor sees on every keystroke; missing delimiters and
// unterminated strings follow because they are what a person actually mistypes.
// Damage inside string CONTENT is last: it usually still parses, so it tests
// little.
const categoryWeight = <String, double>{
  'truncate': 3.0,
  'delim-delete': 3.0,
  'quote-delete': 2.5,
  'delim-insert': 2.0,
  'junk-insert': 2.0,
  'literal-damage': 1.5,
  'quote-insert': 1.5,
  'multi-damage': 1.5,
  'transpose': 1.0,
  'content-damage': 1.0,
};

const _delims = '{}[],:()=;+-*/';

/// What role does the character at [j] play in [doc]? Used only to CATEGORISE a
/// mutation, never to guide one.
String _role(String doc, int j) {
  final ch = doc[j];
  if (ch == '"') return 'quote';
  if (_delims.contains(ch)) return 'delim';
  if (ch == ' ' || ch == '\t' || ch == '\n') return 'space';
  // Inside a pair of quotes?
  var q = 0;
  for (var i = 0; i < j; i++) {
    if (doc[i] == '"') q++;
  }
  return q.isOdd ? 'content' : 'literal';
}

/// Build the battery: every single-character damage to every document in every
/// corpus that actually breaks the parse, plus truncations and two-error cases.
List<Case> buildBattery() {
  final out = <Case>[];
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

    for (final doc in c.documents) {
      void add(String m, String cat) {
        if (m.isNotEmpty && !parses(m)) out.add(Case(c.name, doc, m, cat));
      }

      for (var j = 0; j < doc.length; j++) {
        final role = _role(doc, j);
        // DELETE
        add(doc.substring(0, j) + doc.substring(j + 1),
            role == 'quote' ? 'quote-delete'
                : role == 'delim' ? 'delim-delete'
                    : role == 'content' ? 'content-damage' : 'literal-damage');
        // TRANSPOSE with the next character
        if (j + 1 < doc.length && doc[j] != doc[j + 1]) {
          add(
              doc.substring(0, j) +
                  doc[j + 1] +
                  doc[j] +
                  doc.substring(j + 2),
              'transpose');
        }
      }
      // INSERT / SUBSTITUTE
      for (var j = 0; j <= doc.length; j++) {
        for (final ch in ['z', 'Q', '"', ',', '}', '5', ';', ')', '\\']) {
          final at = _role(doc, j < doc.length ? j : doc.length - 1);
          final role = at == 'content' && ch != '"'
              ? 'content-damage'
              : ch == '"'
                  ? 'quote-insert'
                  : _delims.contains(ch) ? 'delim-insert' : 'junk-insert';
          add(doc.substring(0, j) + ch + doc.substring(j), role);
          if (j < doc.length && doc[j] != ch) {
            add(doc.substring(0, j) + ch + doc.substring(j + 1),
                _role(doc, j) == 'quote' ? 'quote-delete' : role);
          }
        }
      }
      // TRUNCATE -- the incomplete document, at every prefix length.
      for (var k = 1; k < doc.length; k++) {
        add(doc.substring(0, k), 'truncate');
      }
      // MULTI -- two independent deletions, spread across the document so the
      // repairs cannot be merged into one span.
      for (var j = 1; j < doc.length - 3; j += 2) {
        for (final gap in [doc.length ~/ 2, doc.length ~/ 3, 3]) {
          final k = j + gap;
          if (k <= j + 1 || k >= doc.length) continue;
          add(
              doc.substring(0, j) +
                  doc.substring(j + 1, k) +
                  doc.substring(k + 1),
              'multi-damage');
        }
      }
    }
  }
  return out;
}

/// Trim each category down to its weight-proportional share, so the aggregate
/// mean IS the weighted score. Cases are taken by even stride rather than from
/// the front, so a trimmed category still spans the whole document.
/// The unit is DERIVED FROM SUPPLY, not chosen: it is the largest number of
/// cases per unit weight that every category can actually furnish. Fixing it by
/// hand is what inverted the weighting the first time -- `delim-delete` has
/// weight 3.0 but only 73 cases, so a unit of 60 silently gave it less coverage
/// than `delim-insert` at weight 2.0. If a category is short, the honest fix is
/// to GENERATE MORE OF IT, and this makes that visible instead of hiding it.
List<Case> weighted(List<Case> all, {int? unit}) {
  final byCat = <String, List<Case>>{};
  for (final c in all) {
    byCat.putIfAbsent(c.category, () => []).add(c);
  }
  var u = unit ?? 1 << 30;
  if (unit == null) {
    for (final e in byCat.entries) {
      final per = (e.value.length / categoryWeight[e.key]!).floor();
      if (per < u) u = per;
    }
  }
  final out = <Case>[];
  for (final e in byCat.entries) {
    final want = (categoryWeight[e.key]! * u).round();
    final have = e.value;
    if (have.length <= want) {
      out.addAll(have);
    } else {
      final stride = have.length / want;
      for (var i = 0; i < want; i++) {
        out.add(have[(i * stride).floor()]);
      }
    }
  }
  return out;
}
