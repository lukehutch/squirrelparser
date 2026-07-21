/// Computation of the shortest "witness" string for each rule of a grammar:
/// the shortest string that the rule can match. Used by the repair search as
/// a macro edit ("virtually insert an entire missing rule"), with cost equal
/// to the witness length, so macro edits never under-count the true
/// character-level edit cost.
///
/// Lookahead clauses are treated as matching the empty string, which can make
/// a witness unsound in context; this is safe because every candidate repair
/// is validated by actually parsing the repaired input.
library;

import '../parser/clause.dart';
import '../parser/combinators.dart';
import '../parser/terminals.dart';
import 'observed_grammar.dart' show expectedCharOf;

/// Maximum witness length considered useful as a macro insertion.
const int maxWitnessLen = 64;

/// Collect the grammar's character alphabet: one representative of every
/// character-equivalence class, where two characters are equivalent when
/// every character test in the grammar (equality with a Char/Str literal,
/// membership in a CharSet, AnyChar) treats them identically. Signatures are
/// constant on the intervals between the breakpoints {d, d+1} of literal
/// characters d and {lo, hi+1} of set ranges, so one representative per
/// accepted interval makes insertions/substitutions drawn from this set
/// sufficient for minimum-cost repair (the paper's alphabet-sufficiency
/// lemma). Characters the grammar mentions directly are listed first, so
/// they are proposed first by the candidate tiers.
Set<String> grammarAlphabet(Map<String, Clause> rules) {
  final alphabet = <String>{};
  final seen = <Clause>{};
  final literals = <int>{};
  final charSets = <CharSet>[];
  var hasAnyChar = false;
  void walk(Clause c) {
    if (!seen.add(c)) return;
    if (c is Char) alphabet.add(c.char);
    if (c is Str) alphabet.addAll(c.text.split(''));
    if (c is AnyChar) hasAnyChar = true;
    if (c is CharSet) {
      charSets.add(c);
      final rep = expectedCharOf(c, '', 0);
      if (rep != null) alphabet.add(rep.char);
      if (!c.inverted) {
        for (final (lo, hi) in c.ranges) {
          alphabet.add(String.fromCharCode(lo));
          alphabet.add(String.fromCharCode(hi));
        }
      }
    }
    if (c is HasOneSubClause) walk(c.subClause);
    if (c is HasMultipleSubClauses) c.subClauses.forEach(walk);
  }

  rules.values.forEach(walk);
  for (final ch in alphabet) {
    literals.add(ch.codeUnitAt(0));
  }

  bool accepted(int c) {
    if (hasAnyChar || literals.contains(c)) return true;
    for (final cs in charSets) {
      var inSet = false;
      for (final (lo, hi) in cs.ranges) {
        if (c >= lo && c <= hi) {
          inSet = true;
          break;
        }
      }
      if (inSet != cs.inverted) return true;
    }
    return false;
  }

  final breakpoints = <int>{0};
  void addBreak(int b) {
    if (b >= 0 && b <= 0xffff) breakpoints.add(b);
  }

  for (final d in literals) {
    addBreak(d);
    addBreak(d + 1);
  }
  for (final cs in charSets) {
    for (final (lo, hi) in cs.ranges) {
      addBreak(lo);
      addBreak(hi + 1);
    }
  }
  final bps = breakpoints.toList()..sort();
  for (var i = 0; i < bps.length; i++) {
    final lo = bps[i];
    final hi = (i + 1 < bps.length ? bps[i + 1] : 0x10000) - 1;
    if (!accepted(lo)) continue;
    // Prefer a printable representative; the signature is constant across
    // the interval, so any member represents the class. Prefer a
    // non-surrogate representative when the interval offers one, but keep
    // surrogate-only intervals: the parser operates on UTF-16 code units, so
    // a grammar can accept exactly the surrogate range, and dropping the
    // class would make its language unreachable by repair.
    var rep = hi >= 0x20 && lo <= 0x7e ? (lo < 0x20 ? 0x20 : lo) : lo;
    if (rep >= 0xd800 && rep <= 0xdfff && hi >= 0xe000) {
      rep = 0xe000;
    }
    alphabet.add(String.fromCharCode(rep));
  }
  return alphabet;
}

/// Compute shortest witness strings for all rules in the grammar (with the
/// '~' transparent-rule prefix stripped from keys). Rules with no finite
/// witness (or witness longer than [maxWitnessLen]) are omitted.
Map<String, String> computeRuleWitnesses(Map<String, Clause> rules) {
  // Strip transparent prefixes for lookup by Ref name.
  final byName = <String, Clause>{};
  for (final e in rules.entries) {
    byName[e.key.startsWith('~') ? e.key.substring(1) : e.key] = e.value;
  }

  // witnesses[name] == null means "not yet known / infinite".
  final witnesses = <String, String?>{for (final name in byName.keys) name: null};

  String? witnessOf(Clause c) {
    if (c is Terminal) {
      if (c is Char) return c.char;
      if (c is Str) return c.text;
      if (c is Nothing) return '';
      if (c is AnyChar) return 'a';
      if (c is CharSet) return expectedCharOf(c, '', 0)?.char;
      return null;
    }
    if (c is Ref) return witnesses[c.ruleName];
    if (c is Seq) {
      final parts = <String>[];
      for (final sub in c.subClauses) {
        final w = witnessOf(sub);
        if (w == null) return null;
        parts.add(w);
      }
      return parts.join();
    }
    if (c is First) {
      String? best;
      for (final sub in c.subClauses) {
        final w = witnessOf(sub);
        if (w != null && (best == null || w.length < best.length)) best = w;
      }
      return best;
    }
    if (c is OneOrMore) return witnessOf(c.subClause);
    if (c is ZeroOrMore || c is Optional || c is NotFollowedBy || c is FollowedBy) return '';
    return null;
  }

  // Fixpoint iteration: keep improving witnesses until stable.
  var changed = true;
  while (changed) {
    changed = false;
    for (final name in byName.keys) {
      final w = witnessOf(byName[name]!);
      if (w != null && (witnesses[name] == null || w.length < witnesses[name]!.length)) {
        witnesses[name] = w;
        changed = true;
      }
    }
  }

  return {
    for (final e in witnesses.entries)
      if (e.value != null && e.value!.length <= maxWitnessLen) e.key: e.value!
  };
}
