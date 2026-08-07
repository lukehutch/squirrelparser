// Systematic mutation testing of JSON error recovery, replicating the
// methodology that showed the earlier (abandoned) recovery design cascading
// on 79% of single-character mutations.
//
// For every single-character mutation of a valid JSON document (deletion,
// insertion, substitution, transposition) that makes it unparseable, the
// repair search must find a cost-1 repair (matching the known ground truth:
// the mutation itself is reversible at cost 1), and the repaired parse tree
// should structurally match the original document's parse tree for most
// mutations ("non-cascading recovery").

import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/recovery/recovery.dart';
import 'package:test/test.dart';

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

/// Rules that define the *structure* of a JSON document. Token-internal
/// rules (Character, Escape, Integer, ...) are excluded: changing "ab" to
/// "b" inside a string does not change the document's structure.
const structuralRules = {'JSON', 'Value', 'Object', 'Array', 'Member', 'String', 'Number', 'Boolean', 'Null'};

/// Render the shape of a parse tree as a nested string of structural rule
/// names, ignoring positions (so shapes can be compared across inputs).
String treeShape(MatchResult r, {bool structuralOnly = true}) {
  final sb = StringBuffer();
  void walk(MatchResult m) {
    final clause = m.clause;
    if (clause is Ref && (!structuralOnly || structuralRules.contains(clause.ruleName))) {
      sb.write('${clause.ruleName}(');
      m.subClauseMatches.forEach(walk);
      sb.write(')');
    } else {
      m.subClauseMatches.forEach(walk);
    }
  }

  walk(r);
  return sb.toString();
}

void main() {
  const doc = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';

  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  final search = RepairSearch(rules: rules, topRuleName: 'JSON');

  bool parses(String s) =>
      !Parser(rules: rules, topRuleName: 'JSON', input: s).parse().hasSyntaxErrors;

  late final String origShape = () {
    final p = Parser(rules: rules, topRuleName: 'JSON', input: doc).parse();
    return treeShape(p.root);
  }();

  test('the unmutated document parses', () {
    expect(parses(doc), isTrue);
  });

  test('all single-character mutations recover with cost 1', () {
    final mutants = <(String, String)>[]; // (description, mutant)
    for (var j = 0; j < doc.length; j++) {
      mutants.add(('del@$j(${doc[j]})', doc.substring(0, j) + doc.substring(j + 1)));
      if (j + 1 < doc.length && doc[j] != doc[j + 1]) {
        mutants.add(
            ('swap@$j', doc.substring(0, j) + doc[j + 1] + doc[j] + doc.substring(j + 2)));
      }
    }
    for (var j = 0; j <= doc.length; j++) {
      for (final c in ['Q', 'z', '}', '"', ',', '5']) {
        mutants.add(('ins@$j($c)', doc.substring(0, j) + c + doc.substring(j)));
        if (j < doc.length && doc[j] != c) {
          mutants.add(('sub@$j(${doc[j]}->$c)', doc.substring(0, j) + c + doc.substring(j + 1)));
        }
      }
    }

    var tested = 0, stillValid = 0, cost1 = 0, costMore = 0, shapeMatch = 0, failed = 0;
    final costMoreCases = <String>[];
    final failures = <String>[];

    for (final (desc, m) in mutants) {
      if (parses(m)) {
        stillValid++;
        continue; // mutation produced valid JSON; nothing to recover
      }
      tested++;
      final r = search.repair(m);
      if (r == null) {
        failed++;
        failures.add(desc);
        continue;
      }
      if (r.cost == 1) {
        cost1++;
      } else {
        costMore++;
        costMoreCases.add('$desc -> cost ${r.cost} ("${r.repaired}")');
      }
      if (treeShape(r.parseResult.root) == origShape) shapeMatch++;
    }

    // Every mutation is reversible at cost 1, so minimality demands cost 1
    // for every recovered mutant.
    expect(failed, equals(0), reason: 'repairs not found: $failures');
    expect(costMore, equals(0),
        reason: 'non-minimal repairs (cost > 1): ${costMoreCases.take(10).join('; ')}');

    final shapePct = (100 * shapeMatch / tested).toStringAsFixed(1);
    // ignore: avoid_print
    print('JSON mutations: $tested tested, $stillValid still-valid skipped; '
        'cost-1: $cost1/$tested; original tree shape restored: $shapeMatch/$tested ($shapePct%)');

    // Structural restoration should be the norm (the old design managed 21%).
    expect(shapeMatch / tested, greaterThan(0.75),
        reason: 'tree shape restored for only $shapeMatch/$tested mutants');
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('multi-error document recovers with minimal total cost', () {
    // Three independent errors: missing comma, garbage char, missing quote.
    const broken = '{"a":1"bc":[2,3Q3],"d:null}';
    // Cost should be 3: insert ',', delete 'Q', insert '"'.
    final r = search.repair(broken);
    expect(r, isNotNull);
    expect(r!.cost, equals(3), reason: 'got "${r.repaired}"');
    expect(parses(r.repaired), isTrue);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
