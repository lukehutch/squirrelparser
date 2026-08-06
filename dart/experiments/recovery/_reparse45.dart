// Scratch: DOES THE REPORTED REPAIR EXIST? Every gate so far has compared a
// NUMBER to another number. This one takes the witness tree, applies it to the
// input to produce s' -- discarding what the tree discards, emitting what a lying
// leaf says stands there -- and hands s' to the PURE parser.
//
// Three things are checked, and each is a different kind of lie:
//
//   * PARSES: s' is in L(G), read to the end. If it is not, the engine returned a
//     repair that does not repair anything.
//   * EDITS: the number of edits the tree EXHIBITS (characters discarded, plus
//     one per fabrication, plus one per substitution) equals the cost reported.
//   * COVERS: s' is reachable from the input by exactly those edits, which the
//     walk enforces by construction -- every character of the input is either
//     kept, discarded, or replaced, in order.
//
// The predicate grammars are included precisely because `_bfpred45.dart` says
// three of their rows are under-reports. This gate does not know that. If it
// independently flags the same three, two unrelated methods agree on the residual.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm45.dart' as g45;

const String jsonGrammar = '''
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

/// What a lying leaf emits: the text the terminal stands for. A class emits its
/// first member, which is a member, and membership is all the parser asks.
String witness(Clause clause) => switch (clause) {
      Str(:final text) => text,
      Char(:final char) => char,
      AnyChar() => 'a',
      CharSet(:final ranges, :final inverted) =>
        inverted ? _outside(ranges) : String.fromCharCode(ranges.first.$1),
      _ => '',
    };

String _outside(List<(int, int)> ranges) {
  for (var c = 32; c <= 0xFFFF; c++) {
    if (!ranges.any((r) => c >= r.$1 && c <= r.$2)) return String.fromCharCode(c);
  }
  return '';
}

class Counts {
  int skipped = 0, fabricated = 0, substituted = 0, gaps = 0;
  int get edits => skipped + fabricated + substituted;
}

/// Walk the witness, emitting s'. Children are walked in order and anything they
/// leave uncovered is input text passing through unedited -- a hidden rule (`~WS`)
/// drops out of the tree without dropping out of the string.
void walk(MatchResult m, Parser parser, String input, StringBuffer out, Counts c) {
  if (m is SyntaxError) {
    c.skipped += m.len; // SKIP: consumed, emits nothing
    return;
  }
  final clause = m.clause;
  final children = m.subClauseMatches;
  if (children.isEmpty) {
    if (clause is Terminal && clause is! Nothing) {
      if (m.len == 0) {
        c.fabricated++; // FAB
        out.write(witness(clause));
        return;
      }
      if (clause.match(parser, m.pos).isMismatch) {
        c.substituted++; // SUB
        out.write(witness(clause));
        return;
      }
    }
    out.write(input.substring(m.pos, m.pos + m.len));
    return;
  }
  var cursor = m.pos;
  for (final child in children) {
    if (child.pos > cursor) {
      c.gaps++;
      out.write(input.substring(cursor, child.pos));
    }
    walk(child, parser, input, out, c);
    cursor = child.pos + child.len;
  }
  if (cursor < m.pos + m.len) {
    c.gaps++;
    out.write(input.substring(cursor, m.pos + m.len));
  }
}

bool inLanguage(Map<String, Clause> rules, String top, String s) {
  final p = Parser(rules: rules, topRuleName: top, input: s).parse();
  return !p.hasSyntaxErrors && p.root.len == s.length;
}

/// One input: repair it, apply the repair, re-parse. Returns a verdict string, or
/// null when everything agrees.
String? check(Map<String, Clause> rules, String top, String input) {
  final engine = g45.SuperDot3(rules: rules, topRuleName: top);
  final result = engine.recover(input);
  final claimed = engine.lastCost;
  if (claimed < 0) return null; // "no repair" is not a repair that must parse
  if (result.forced) return null; // presentation fallback, not a witness
  final out = StringBuffer();
  final counts = Counts();
  final parser = Parser(rules: rules, topRuleName: top, input: input)..parse();
  walk(result.root, parser, input, out, counts);
  final repaired = out.toString();
  if (!inLanguage(rules, top, repaired)) {
    return 'DOES NOT PARSE: "$input" -> "$repaired" (claimed $claimed)';
  }
  if (counts.edits != claimed) {
    return 'EDIT COUNT: "$input" -> "$repaired" exhibits ${counts.edits} '
        '(skip ${counts.skipped}, fab ${counts.fabricated}, '
        'sub ${counts.substituted}), claimed $claimed';
  }
  return null;
}

void main() {
  // ---- JSON: a real grammar, 519 mutants of one document
  final json = MetaGrammar.parseGrammar(jsonGrammar);
  const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';
  bool parses(String s) =>
      !Parser(rules: json, topRuleName: 'JSON', input: s).parse().hasSyntaxErrors;
  final mutants = <String>[];
  for (var j = 0; j < base.length; j++) {
    mutants.add(base.substring(0, j) + base.substring(j + 1));
    if (j + 1 < base.length && base[j] != base[j + 1]) {
      mutants.add(
          base.substring(0, j) + base[j + 1] + base[j] + base.substring(j + 2));
    }
  }
  for (var j = 0; j <= base.length; j++) {
    for (final ch in ['Q', 'z', '}', '"', ',', '5']) {
      mutants.add(base.substring(0, j) + ch + base.substring(j));
      if (j < base.length && base[j] != ch) {
        mutants.add(base.substring(0, j) + ch + base.substring(j + 1));
      }
    }
  }
  final battery = mutants.where((m) => !parses(m)).toList();
  var bad = 0;
  for (final input in battery) {
    final verdict = check(json, 'JSON', input);
    if (verdict != null) {
      bad++;
      if (bad <= 6) print('  $verdict');
    }
  }
  print('JSON battery: ${battery.length - bad}/${battery.length} repairs parse '
      'and cost what they claim');

  // ---- the predicate grammars, where the residual under-reports live
  final cases = <(String, String, String, List<String>)>[
    ("S <- &'x' 'x' &'y' 'y';\n", 'S', 'xyz', ['xy', 'zz', 'z', '', 'xz', 'zy']),
    (
      "S <- !'x' A;\nA <- 'x' / \"yy\";\n",
      'S',
      'xyq',
      ['q', 'x', 'yy', 'y', '', 'xy']
    ),
    ("S <- !'x' 'b';\n", 'S', 'xb', ['x', 'b', '', 'xb', 'bb']),
    ("S <- 'a' !'x' 'b';\n", 'S', 'abx', ['ax', 'ab', 'a', 'axb', '']),
    (
      "S <- Kw !Alpha;\nKw <- \"if\";\nAlpha <- [a-z];\n",
      'S',
      'ifq',
      ['if', 'ifq', 'iff', 'i']
    ),
    ("S <- &'x' 'y';\n", 'S', 'xy', ['x', 'y', '', 'xy']),
    ("S <- (&'x' 'y') / 'a' 'a';\n", 'S', 'xya', ['aa', 'x', '', 'ay']),
    ("S <- &'x' &[a-y] 'x';\n", 'S', 'xz', ['x', 'z', '', 'xx']),
    ("S <- '(' C C ')';\nC <- !')' .;\n", 'S', '()x', ['()', '(x)', '(', '(x']),
  ];
  print('');
  var pbad = 0, ptotal = 0;
  for (final (grammar, top, _, inputs) in cases) {
    final rules = MetaGrammar.parseGrammar(grammar);
    for (final input in inputs) {
      ptotal++;
      final verdict = check(rules, top, input);
      if (verdict != null) {
        pbad++;
        print('  ${grammar.replaceAll('\n', ' ')}  $verdict');
      }
    }
  }
  print('predicate grammars: ${ptotal - pbad}/$ptotal repairs parse and cost '
      'what they claim');
}
