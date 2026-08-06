// _render75.dart -- generates RECOVERY_TESTCASES.md.
//
// For every JSON test case m75 is measured on, print two sequences:
//
//   the MUTATED INPUT, unchanged, with two marker lines under it -- where the
//   corruption was injected (known by construction, not by search), and where
//   m75 placed syntax-error spans;
//
//   the JSON RE-RENDERED FROM THE REPAIRED AST. Punctuation comes from the
//   GRAMMAR, not from the input -- that is the whole point, because the
//   difference between the two lines is exactly the reshaping recovery did.
//   Terminal text comes from the input span the node actually covers, so the
//   render cannot invent content even by accident.
//
// Two markers appear inline in the re-render:
//   <?>       grammar the input could not fill. m75 deliberately does NOT say
//             which symbol was demanded, so neither does this.
//   <!text!>  input the grammar could not use, shown verbatim.
//
// Three checks run over every case, because a renderer that quietly drops
// content would produce a prettier document and a false one:
//   REPLACED  every input character not emitted verbatim and not shown inside
//             an error span must be structural punctuation or whitespace.
//   MARKS     the markers in the re-render must equal the SyntaxError nodes in
//             the tree, one for one.
//   ROUNDTRIP for input that already parses, the re-render must itself parse
//             and must carry no markers at all.
import 'dart:io';

import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' show buildSetup, treeShape;
import 'm75.dart' as e75;

const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';
const valueRules = {'Object', 'Array', 'String', 'Number', 'Boolean', 'Null'};
const punctSet = '{}[],: \t\n\r';

// ---------------------------------------------------------------- mutations

class Mut {
  Mut(this.kind, this.pos, this.width, this.note);
  final String kind;
  final int pos, width;
  final String note;
}

/// The battery rebuilt exactly as `buildSetup` builds it, but carrying what
/// each edit WAS. Alignment is asserted, not assumed: if the rebuild ever
/// drifts, every mutation label in the document would silently attach to the
/// wrong string.
List<Mut> batteryMutations(Map<String, Clause> rules, List<String> battery) {
  bool parses(String s) => !Parser(
        rules: rules,
        topRuleName: 'JSON',
        input: s,
      ).parse().hasSyntaxErrors;

  final mutants = <String>[], infos = <Mut>[];
  void add(String m, Mut k) {
    mutants.add(m);
    infos.add(k);
  }

  for (var j = 0; j < base.length; j++) {
    add(base.substring(0, j) + base.substring(j + 1),
        Mut('delete', j, 0, 'deleted `${base[j]}` at $j'));
    if (j + 1 < base.length && base[j] != base[j + 1]) {
      add(
          base.substring(0, j) + base[j + 1] + base[j] + base.substring(j + 2),
          Mut('transpose', j, 2,
              'transposed `${base[j]}${base[j + 1]}` to `${base[j + 1]}${base[j]}` at $j'));
    }
  }
  for (var j = 0; j <= base.length; j++) {
    for (final c in ['Q', 'z', '}', '"', ',', '5']) {
      add(base.substring(0, j) + c + base.substring(j),
          Mut('insert', j, 1, 'inserted `$c` at $j'));
      if (j < base.length && base[j] != c) {
        add(base.substring(0, j) + c + base.substring(j + 1),
            Mut('substitute', j, 1, 'replaced `${base[j]}` with `$c` at $j'));
      }
    }
  }

  final keptM = <String>[], keptI = <Mut>[];
  for (var i = 0; i < mutants.length; i++) {
    if (!parses(mutants[i])) {
      keptM.add(mutants[i]);
      keptI.add(infos[i]);
    }
  }
  if (keptM.length != battery.length) {
    throw StateError('rebuild ${keptM.length} != battery ${battery.length}');
  }
  for (var i = 0; i < keptM.length; i++) {
    if (keptM[i] != battery[i]) throw StateError('battery drifted at $i');
  }
  return keptI;
}

// ------------------------------------------------------------------ marking

/// `ms` is a list of (column, width, char); width 0 marks a boundary, which
/// needs one column past the end of the line to be representable.
String markLine(int len, List<(int, int, String)> ms) {
  final buf = List.filled(len + 1, ' ');
  for (final (p, w, ch) in ms) {
    if (w == 0) {
      if (p >= 0 && p <= len) buf[p] = ch;
    } else {
      for (var i = p; i < p + w && i <= len; i++) {
        buf[i] = ch;
      }
    }
  }
  return buf.join().trimRight();
}

/// Columns where a boundary mark sits inside a span mark, so the `~` run is
/// drawn one character short. Counted rather than assumed away.
var markCollisions = 0;

/// The m75 line, which `markLine` cannot draw: two zero-width errors can land
/// on the SAME column -- L00 needs both a quote and a comma at offset 29 --
/// and a plain overwrite would show one `v` under a header saying `2 missing`.
String errLine(int len, List<(int, int, String)> ms) {
  final zero = List.filled(len + 1, 0);
  final wide = List.filled(len + 1, false);
  for (final (p, w, _) in ms) {
    if (w == 0) {
      if (p >= 0 && p <= len) zero[p]++;
    } else {
      for (var i = p; i < p + w && i <= len; i++) {
        wide[i] = true;
      }
    }
  }
  final buf = List.filled(len + 1, ' ');
  for (var i = 0; i <= len; i++) {
    if (zero[i] > 0) {
      buf[i] = zero[i] == 1 ? 'v' : (zero[i] < 10 ? '${zero[i]}' : '+');
      if (wide[i]) markCollisions++;
    } else if (wide[i]) {
      buf[i] = '~';
    }
  }
  return buf.join().trimRight();
}

List<(int, int, String)> errorMarks(MatchResult root) {
  final out = <(int, int, String)>[];
  void walk(MatchResult m) {
    if (m is SyntaxError) {
      out.add(m.len == 0 ? (m.pos, 0, 'v') : (m.pos, m.len, '~'));
    }
    m.subClauseMatches.forEach(walk);
  }

  walk(root);
  return out;
}

// ----------------------------------------------------------------- the render

class Render {
  Render(this.input) : fate = List.filled(input.length, 0);
  final String input;
  final List<int> fate; // 0 replaced by grammar, 1 emitted verbatim, 2 in error
  final _root = StringBuffer();
  var missing = 0, unusable = 0;

  /// Where writes currently go. A terminal is rendered into a scratch buffer
  /// first, because whether it needs its rule name is only known once its own
  /// markers have been counted.
  late StringBuffer _out = _root;

  String get text => _root.toString();

  void punct(String s) => _out.write(s);

  void verbatim(int pos, int len) {
    for (var i = pos; i < pos + len; i++) {
      fate[i] = 1;
    }
    _out.write(input.substring(pos, pos + len));
  }

  void marker(SyntaxError e) {
    if (e.len == 0) {
      missing++;
      _out.write('<?>');
    } else {
      unusable++;
      for (var i = e.pos; i < e.pos + e.len; i++) {
        fate[i] = 2;
      }
      _out.write('<!${input.substring(e.pos, e.pos + e.len)}!>');
    }
  }

  /// The ordered descendants of `m` that are Refs to a wanted rule, plus every
  /// SyntaxError that is not nested inside one of them. Descent stops at a
  /// wanted node, so this returns the members of a list rather than every
  /// String anywhere beneath it.
  List<MatchResult> pick(MatchResult m, Set<String> wanted) {
    final out = <MatchResult>[];
    void go(MatchResult n) {
      if (n is SyntaxError) {
        out.add(n);
        return;
      }
      final c = n.clause;
      if (c is Ref && wanted.contains(c.ruleName)) {
        out.add(n);
        return;
      }
      n.subClauseMatches.forEach(go);
    }

    m.subClauseMatches.forEach(go);
    return out;
  }

  /// Error markers carry no separator of their own: a missing comma shows up
  /// against the element it belongs to, not as a phantom extra element.
  void joinItems(List<MatchResult> items, String sep) {
    var first = true;
    for (final it in items) {
      if (it is SyntaxError) {
        marker(it);
        continue;
      }
      if (!first) punct(sep);
      first = false;
      emit(it);
    }
  }

  /// A terminal value: its own text, with any error markers spliced in at the
  /// position they hold in the tree.
  void leaf(MatchResult n) {
    void go(MatchResult m) {
      if (m is SyntaxError) {
        marker(m);
        return;
      }
      if (m.subClauseMatches.isEmpty) {
        if (m.len > 0) verbatim(m.pos, m.len);
        return;
      }
      m.subClauseMatches.forEach(go);
    }

    go(n);
  }

  void emit(MatchResult n) {
    if (n is SyntaxError) {
      marker(n);
      return;
    }
    final c = n.clause;
    final name = c is Ref ? c.ruleName : null;
    switch (name) {
      case 'Value':
        final items = pick(n, valueRules);
        if (items.isEmpty) {
          _out.write('<?>');
          missing++;
        } else {
          for (final k in items) {
            emit(k);
          }
        }
      case 'Object':
        punct('{');
        joinItems(pick(n, {'Member'}), ', ');
        punct('}');
      case 'Array':
        punct('[');
        joinItems(pick(n, {'Value'}), ', ');
        punct(']');
      case 'Member':
        final items = pick(n, {'String', 'Value'});
        var i = 0, before = _out.length;
        for (; i < items.length; i++) {
          emit(items[i]);
          if (items[i] is! SyntaxError) {
            i++;
            break;
          }
        }
        if (_out.length == before) {
          _out.write('<?>');
          missing++;
        }
        punct(': ');
        before = _out.length;
        for (; i < items.length; i++) {
          emit(items[i]);
        }
        if (_out.length == before) {
          _out.write('<?>');
          missing++;
        }
      case 'String' || 'Number' || 'Boolean' || 'Null':
        // A terminal whose own delimiters are among the missing symbols is
        // unreadable from its text alone -- `<?>2[,33,true]<?>` could be
        // anything, and the one thing the reader needs is what the AST decided
        // it was. So a terminal carrying a marker is named; one that reads
        // cleanly speaks for itself and is not.
        final outer = _out, scratch = StringBuffer();
        final before = missing + unusable;
        _out = scratch;
        leaf(n);
        _out = outer;
        _out.write(missing + unusable > before ? '$name($scratch)' : '$scratch');
      default:
        n.subClauseMatches.forEach(emit);
    }
  }

  /// Input characters neither emitted nor shown as an error must be structural
  /// punctuation or whitespace -- anything else means content was dropped.
  String? breach() {
    final bad = <String>[];
    for (var i = 0; i < input.length; i++) {
      if (fate[i] == 0 && !punctSet.contains(input[i])) {
        bad.add('`${input[i]}`@$i');
      }
    }
    return bad.isEmpty ? null : bad.join(' ');
  }
}

// -------------------------------------------------------------------- driver

class Case {
  Case(this.group, this.id, this.input, this.note, this.mut);
  final String group, id, input, note;

  /// Carried, not looked up: the battery contains duplicate strings (deleting
  /// either of two identical adjacent characters gives the same mutant), so
  /// `indexOf` would label the second one with the first one's edit.
  final Mut? mut;
}

int countErrNodes(MatchResult root) {
  var n = 0;
  void walk(MatchResult m) {
    if (m is SyntaxError) n++;
    m.subClauseMatches.forEach(walk);
  }

  walk(root);
  return n;
}

void main() {
  final (rules, battery, origShape, validDocs, latCases, _, __, ___) =
      buildSetup();
  final muts = batteryMutations(rules, battery);
  final eng = e75.SuperDot3(rules: rules, topRuleName: 'JSON');

  // The two repairs the brief singled out, located by construction.
  final brief = <String, String>{
    base.substring(0, 16) + base[17] + base[16] + base.substring(18):
        'NAMED IN THE BRIEF: the list reads `[2,3,3true]`, and `3true` needs a '
            'comma, so the repair must be `,3,true` and not `,true`',
    base.substring(0, 13) + base.substring(14):
        'NAMED IN THE BRIEF: the list reads `[,33,true]`; deleting the stray '
            'leading comma beats inventing a value to put in front of it',
  };

  final cases = <Case>[
    for (var i = 0; i < battery.length; i++)
      Case('battery', 'B${i.toString().padLeft(3, "0")}', battery[i],
          muts[i].note, muts[i]),
    for (var i = 0; i < validDocs.length; i++)
      Case('valid', 'V${i.toString().padLeft(2, "0")}', validDocs[i],
          'no corruption -- control case, recovery must change nothing', null),
    for (var i = 0; i < latCases.length; i++)
      Case('latency', 'L${i.toString().padLeft(2, "0")}', latCases[i],
          latNote(i), null),
  ];

  final out = StringBuffer();
  var replacedBreaches = 0, markBreaches = 0, roundTripFail = 0, cleanCount = 0;
  var totMissing = 0, totUnusable = 0, shapeOk = 0, certOk = 0;
  final bodies = <String, List<String>>{};
  final tally = <String, List<int>>{}; // group -> [cases, missing, unusable]

  for (final c in cases) {
    final r = eng.recover(c.input);
    final cost = eng.lastCost, verified = eng.lastVerified;
    final rend = Render(c.input);
    rend.emit(r.root);

    final marks = errorMarks(r.root);
    final nodes = countErrNodes(r.root);
    final breach = rend.breach();
    if (breach != null) replacedBreaches++;
    if (rend.missing + rend.unusable != nodes) markBreaches++;
    totMissing += rend.missing;
    totUnusable += rend.unusable;
    if (c.group == 'battery' && treeShape(r.root) == origShape) shapeOk++;
    if (verified) certOk++;

    final clean = !Parser(
      rules: rules,
      topRuleName: 'JSON',
      input: c.input,
    ).parse().hasSyntaxErrors;
    var rt = '';
    if (clean) {
      cleanCount++;
      final reParsed = Parser(
        rules: rules,
        topRuleName: 'JSON',
        input: rend.text,
      ).parse();
      final ok = !reParsed.hasSyntaxErrors &&
          reParsed.root.len == rend.text.length &&
          nodes == 0;
      if (!ok) roundTripFail++;
      rt = ok ? ' · round-trips' : ' · **ROUND-TRIP FAILED**';
    }

    final t = tally.putIfAbsent(c.group, () => [0, 0, 0]);
    t[0]++;
    t[1] += rend.missing;
    t[2] += rend.unusable;

    final b = StringBuffer();
    b.writeln('#### ${c.id} · ${c.note}');
    b.writeln();
    b.writeln('`cost $cost` · `${verified ? "certified" : "NOT certified"}`'
        ' · `${rend.missing} missing` · `${rend.unusable} unusable`$rt');
    b.writeln();
    b.writeln('```text');
    b.writeln('in   ${c.input}');
    final m = c.mut;
    if (m != null) {
      b.writeln('mut  ${markLine(c.input.length, [(m.pos, m.width, '^')])}');
    }
    final em = errLine(c.input.length, marks);
    b.writeln('m75  ${em.isEmpty ? "(no error spans)" : em}');
    b.writeln('ast  ${rend.text}');
    b.writeln('```');
    if (breach != null) {
      b.writeln();
      b.writeln('> **DROPPED CONTENT:** $breach');
    }
    if (brief.containsKey(c.input)) {
      b.writeln();
      b.writeln('> ${brief[c.input]}');
    }
    b.writeln();
    bodies.putIfAbsent(c.group, () => []).add(b.toString());
  }

  // ------------------------------------------------------------- the header
  out.writeln('# m75 recovery, case by case');
  out.writeln();
  out.writeln('Every JSON test case engine **m75** is measured on, showing the '
      'corrupted input it was given and the JSON re-rendered from the AST it '
      'produced. Generated by `dart/experiments/recovery/_render75.dart`; do '
      'not edit by hand.');
  out.writeln();
  out.writeln('## How to read a case');
  out.writeln();
  out.writeln('''
```text
in   the mutated input, character for character, unchanged
mut  ^ marks the character(s) the corruption touched, or, for a deletion, the
     boundary the deleted character was removed from (known by construction,
     not recovered by search)
m75  ~ marks input m75 found unusable; v marks a boundary where the grammar
     wanted a symbol the input never supplied, and a digit marks a boundary
     where it wanted that many
ast  the JSON re-rendered from the repaired AST
```
''');
  out.writeln('The `ast` line is **not** the input echoed back. Structural '
      'punctuation on that line -- `{` `}` `[` `]` `,` `:` -- is emitted by '
      'the *grammar*, from the shape of the recursion tree. Everything else is '
      'the literal input text of the span each node covers. So where `ast` '
      'differs from `in`, the difference is exactly the reshaping that '
      'recovery performed.');
  out.writeln();
  out.writeln('Three annotations can appear inline in `ast`:');
  out.writeln();
  out.writeln('| marker | meaning |');
  out.writeln('|---|---|');
  out.writeln('| `<?>` | The grammar demanded a symbol at this point and the '
      'input did not supply one. The tree holds a **zero-width** '
      '`SyntaxError` here. m75 does not write which symbol was wanted, '
      'because a wide character class cannot say which member it would '
      'have been -- picking one would be invention, not evidence. |');
  out.writeln('| `<!text!>` | Input the grammar could not give a role to, '
      'shown verbatim. The tree holds a `SyntaxError` span covering exactly '
      'these characters. |');
  out.writeln('| `String(…)` | A terminal that carries a marker is named, '
      'because a terminal missing its own delimiters cannot be identified '
      'from its text: `<?>2[,33,true]<?>` on its own could be anything, and '
      '`String(<?>2[,33,true]<?>)` says the AST read those eleven characters '
      'as a string with both quotes absent. Terminals that read cleanly are '
      'not named. |');
  out.writeln();
  out.writeln('Because the AST is built over the **original, unchanged** '
      'input (I32), no node on the `ast` line can claim text the document did '
      'not supply. That is machine-checked in `_tree75.dart`: putting every '
      'leaf back to the pure parser at its own position over the untouched '
      'input, m75 places **0** unsupported nodes across this battery, where '
      'm74 places 535.');
  out.writeln();

  out.writeln('## Totals');
  out.writeln();
  out.writeln('| group | cases | `<?>` missing | `<!…!>` unusable |');
  out.writeln('|---|---:|---:|---:|');
  for (final g in ['battery', 'valid', 'latency']) {
    final t = tally[g]!;
    out.writeln('| $g | ${t[0]} | ${t[1]} | ${t[2]} |');
  }
  out.writeln('| **all** | ${cases.length} | $totMissing | $totUnusable |');
  out.writeln();
  out.writeln('Certified by the pure parser: **$certOk / ${cases.length}**. '
      'Original recursion shape recovered on the battery: '
      '**$shapeOk / ${battery.length}** '
      '(see the note on that column below).');
  out.writeln();
  out.writeln('### Renderer self-checks');
  out.writeln();
  out.writeln('| check | what it rules out | result |');
  out.writeln('|---|---|---|');
  out.writeln('| REPLACED | an input character silently dropped by the '
      'renderer rather than by the grammar: every character not emitted '
      'verbatim and not shown inside `<!…!>` must be structural punctuation '
      'or whitespace | '
      '${replacedBreaches == 0 ? "**pass**, 0 cases" : "**FAIL**, $replacedBreaches cases"} |');
  out.writeln('| MARKS | a marker invented by the renderer, or a tree error '
      'node it failed to show: inline marker count must equal the '
      '`SyntaxError` node count in the tree | '
      '${markBreaches == 0 ? "**pass**, 0 cases" : "**FAIL**, $markBreaches cases"} |');
  out.writeln('| ROUND-TRIP | recovery disturbing input that was already '
      'valid: for every input that already parses -- the '
      '${validDocs.length} controls, and L11, whose `Q` happened to land '
      'inside a string, $cleanCount in all -- the re-render must itself parse '
      'and must carry no markers | '
      '${roundTripFail == 0 ? "**pass**, 0 cases" : "**FAIL**, $roundTripFail cases"} |');
  out.writeln('| OVERDRAW | a boundary mark sitting inside a span mark on the '
      '`m75` line, which would draw the `~` run one character short | '
      '${markCollisions == 0 ? "**pass**, 0 columns" : "$markCollisions columns, listed marks still exact"} |');
  out.writeln();
  out.writeln('> On the shape column: the battery is built by corrupting one '
      'known document, so "recovers the original shape" rewards *guessing '
      'the document back*, which is the invention the brief forbids. On all '
      '43 battery inputs where m74 matches the original shape and m75 does '
      'not, m74 buys the match with at least one node the input does not '
      'support; there are 0 inputs the other way. The number is reported '
      'here for continuity with the engine table, not as a target.');
  out.writeln();
  out.writeln('> Not included: the five non-JSON probe grammars '
      '(`\'a\'* "ab"`, `(\'a\' / "ab") \'b\'`, `A <- \'a\' / "ab"`, '
      '`\'a\'? "ab"`, `&(A \'b\') A \'b\' \'x\'`) used by `_m75diff.dart` and '
      '`_subset75.dart`, and the LR/RR expression-grammar depth ladders. '
      'Those are not JSON, so there is no JSON to re-render; they are scored '
      'on cost against exhaustive truth instead.');
  out.writeln();

  const titles = {
    'battery': 'The 519-mutant battery',
    'valid': 'Valid documents (controls)',
    'latency': 'Latency corpus',
  };
  const blurbs = {
    'battery': 'Every single-character deletion, adjacent transposition, '
        'insertion and substitution of `$base` that stops it parsing. '
        'Insertions and substitutions draw from `Q z } " , 5`.',
    'valid': 'Documents that already parse. Recovery must return cost 0, place '
        'no error spans, and re-render to the same document.',
    'latency': 'The larger documents the `latms` column is timed on: a '
        '119-character nested document with a run of characters deleted, a '
        'run of `@` inserted, or a run shuffled at offset 30; and three '
        'generated documents with one character replaced by `Q` at the '
        'midpoint.',
  };
  for (final g in ['battery', 'valid', 'latency']) {
    out.writeln('## ${titles[g]}');
    out.writeln();
    out.writeln(blurbs[g]);
    out.writeln();
    for (final b in bodies[g]!) {
      out.write(b);
    }
  }

  // Relative to the process CWD, which the run pattern fixes at `dart/`, not
  // to this script's directory -- Dart resolves relative paths against the
  // former, so `../../` would land outside the repository entirely.
  final path = '../RECOVERY_TESTCASES.md';
  File(path).writeAsStringSync(out.toString());
  stdout.writeln('wrote $path  ${out.length} bytes, ${cases.length} cases');
  stdout.writeln('REPLACED breaches $replacedBreaches   '
      'MARKS breaches $markBreaches   ROUND-TRIP failures $roundTripFail');
  stdout.writeln('missing markers $totMissing   unusable markers $totUnusable  '
      ' certified $certOk/${cases.length}   shape $shapeOk/${battery.length}');
}

String latNote(int i) {
  const k = [4, 16, 64];
  if (i < 9) {
    final n = k[i ~/ 3];
    return switch (i % 3) {
      0 => 'deleted $n characters at offset 30',
      1 => 'inserted $n `@` characters at offset 30',
      _ => 'shuffled the $n characters at offset 30',
    };
  }
  return 'replaced the midpoint character with `Q` in a generated '
      '${k[i - 9]}-item document';
}
