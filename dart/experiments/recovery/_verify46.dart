// Scratch: does m46's SELF-report agree with an outside check?
//
// `_reparse45.dart` applies the witness tree from outside the engine and re-parses
// the result. m46 does the same thing inside itself and reports `lastVerified`.
// Two implementations of the same claim, and the gate is that they never differ:
// an inside `true` with an outside failure is the worst possible outcome, because
// it is a lie about honesty.
//
// The external walk here is deliberately NOT the engine's: it picks a different
// member of a character class (the first printable one rather than the first code
// unit), so agreement is not agreement-by-shared-code.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm46.dart' as g46;

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

String witness(Clause clause) => switch (clause) {
      Str(:final text) => text,
      Char(:final char) => char,
      AnyChar() => 'a',
      CharSet(:final ranges, :final inverted) => inverted
          ? _outside(ranges)
          : String.fromCharCode(ranges.first.$1),
      _ => '',
    };

String _outside(List<(int, int)> ranges) {
  for (var c = 32; c <= 0xFFFF; c++) {
    if (!ranges.any((r) => c >= r.$1 && c <= r.$2)) return String.fromCharCode(c);
  }
  return '';
}

void walk(MatchResult m, Parser parser, String input, StringBuffer out) {
  if (m is SyntaxError) return;
  final clause = m.clause;
  final children = m.subClauseMatches;
  if (children.isEmpty) {
    out.write(clause is Terminal &&
            clause is! Nothing &&
            (m.len == 0 || clause.match(parser, m.pos).isMismatch)
        ? witness(clause)
        : input.substring(m.pos, m.pos + m.len));
    return;
  }
  var cursor = m.pos;
  for (final child in children) {
    if (child.pos > cursor) out.write(input.substring(cursor, child.pos));
    walk(child, parser, input, out);
    cursor = child.pos + child.len;
  }
  if (cursor < m.pos + m.len) {
    out.write(input.substring(cursor, m.pos + m.len));
  }
}

bool inLanguage(Map<String, Clause> rules, String top, String s) {
  final p = Parser(rules: rules, topRuleName: top, input: s).parse();
  return !p.hasSyntaxErrors && p.root.len == s.length;
}

/// (engine's own verdict, outside verdict, the repaired string)
(bool, bool, String) both(Map<String, Clause> rules, String top, String input) {
  final engine = g46.SuperDot3(rules: rules, topRuleName: top);
  final result = engine.recover(input);
  if (result.forced) return (engine.lastVerified, false, '<forced>');
  final out = StringBuffer();
  final parser = Parser(rules: rules, topRuleName: top, input: input)..parse();
  walk(result.root, parser, input, out);
  final repaired = out.toString();
  return (engine.lastVerified, inLanguage(rules, top, repaired), repaired);
}

void main() {
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
  var verified = 0, disagree = 0;
  for (final input in battery) {
    final (inside, outside, repaired) = both(json, 'JSON', input);
    if (inside) verified++;
    if (inside != outside) {
      disagree++;
      if (disagree <= 5) {
        print('  DISAGREE "$input" -> "$repaired": engine $inside, outside '
            '$outside');
      }
    }
  }
  print('JSON battery: $verified/${battery.length} verified by the engine, '
      '$disagree disagreements with the outside check');

  final cases = <(String, String, List<String>)>[
    ("S <- &'x' 'x' &'y' 'y';\n", 'S', ['xy', 'zz', 'z', '', 'xz', 'zy']),
    ("S <- !'x' A;\nA <- 'x' / \"yy\";\n", 'S', ['q', 'x', 'yy', 'y', '', 'xy']),
    ("S <- !'x' 'b';\n", 'S', ['x', 'b', '', 'xb', 'bb']),
    ("S <- 'a' !'x' 'b';\n", 'S', ['ax', 'ab', 'a', 'axb', '']),
    ("S <- Kw !Alpha;\nKw <- \"if\";\nAlpha <- [a-z];\n", 'S',
        ['if', 'ifq', 'iff', 'i']),
    ("S <- &'x' 'y';\n", 'S', ['x', 'y', '', 'xy']),
    ("S <- (&'x' 'y') / 'a' 'a';\n", 'S', ['aa', 'x', '', 'ay']),
    ("S <- &'x' &[a-y] 'x';\n", 'S', ['x', 'z', '', 'xx']),
    ("S <- '(' C C ')';\nC <- !')' .;\n", 'S', ['()', '(x)', '(', '(x']),
    ("S <- !'x' A B;\nA <- 'a'?;\nB <- 'b' / 'x';\n", 'S', ['x', 'ax', 'xx']),
  ];
  print('\nunverified repairs the engine ADMITS to (predicate grammars):');
  var ptotal = 0, punverified = 0, pdisagree = 0;
  for (final (grammar, top, inputs) in cases) {
    final rules = MetaGrammar.parseGrammar(grammar);
    for (final input in inputs) {
      ptotal++;
      final (inside, outside, repaired) = both(rules, top, input);
      if (inside != outside) pdisagree++;
      if (!inside) {
        punverified++;
        print('  ${grammar.replaceAll('\n', ' ').padRight(38)}'
            '"$input" -> "$repaired"'
            '${inside != outside ? "   DISAGREE (outside says $outside)" : ""}');
      }
    }
  }
  print('predicate grammars: ${ptotal - punverified}/$ptotal verified, '
      '$pdisagree disagreements');
}
