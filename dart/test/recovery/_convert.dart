// _convert.dart -- adapters that map the library's grammar AST onto each
// engine's own clause classes: one conversion function per engine. The
// engines are self-contained (they carry their own parsing and recovery
// logic), so this file is the only place that inspects the library's
// clause types on their behalf.
import 'package:squirrel_parser/squirrel_parser.dart' as lib;

import '../../experiments/recovery/attic/c8.dart' as c8;
import '../../experiments/recovery/c9.dart' as c9;

/// Build a c8 engine (retired to the attic, superseded by c9; kept
/// importable as the paired-timing and dump baseline) from a library
/// grammar (as produced by `MetaGrammar.parseGrammar`) and a top rule
/// name. Strips the library's `~` (transparent-rule) markers, sets up a
/// rule shell per name, then converts every rule body; references
/// resolve against the shells, so rule order and cycles need no special
/// handling. Every converted clause keeps a pointer to its source
/// clause, so the trees the engine returns are labeled with the caller's
/// own grammar objects.
c8.Squirrel convertC8(Map<String, lib.Clause> rules, String topRuleName) {
  final defs = <String, lib.Clause>{
    for (final e in rules.entries)
      e.key.startsWith('~') ? e.key.substring(1) : e.key: e.value
  };
  final built = <String, c8.Rule>{
    for (final name in defs.keys) name: c8.Rule(name)
  };

  c8.Clause node(lib.Clause c) {
    if (c is lib.Ref) {
      final rule = built[c.ruleName];
      if (rule == null) throw ArgumentError('rule "${c.ruleName}" not found');
      return c8.RuleRef(c, rule);
    }
    if (c is lib.Seq) {
      return c8.Seq(c, [for (final s in c.subClauses) node(s)]);
    }
    if (c is lib.First) {
      return c8.First(c, [for (final s in c.subClauses) node(s)]);
    }
    if (c is lib.Repetition) {
      return c8.Repetition(c, node(c.subClause), c.requireOne);
    }
    if (c is lib.Optional) return c8.Optional(c, node(c.subClause));
    if (c is lib.FollowedBy) return c8.FollowedBy(c, node(c.subClause));
    if (c is lib.NotFollowedBy) return c8.NotFollowedBy(c, node(c.subClause));
    if (c is lib.Str) return c8.Str(c, c.text);
    if (c is lib.Char) return c8.Char(c, c.char.codeUnitAt(0));
    if (c is lib.CharSet) return c8.CharSet(c, c.ranges, c.inverted);
    if (c is lib.AnyChar) return c8.AnyChar(c);
    if (c is lib.Nothing) return c8.Nothing(c);
    throw UnsupportedError('clause kind ${c.runtimeType}');
  }

  for (final e in defs.entries) {
    built[e.key]!.body = node(e.value);
  }
  return c8.Squirrel(rules: built, topRuleName: topRuleName);
}

/// Build a c9 engine; the same conversion as [convertC8] (c9 keeps c8's
/// clause classes and names -- see c9.dart's header for what differs).
c9.Squirrel convertC9(Map<String, lib.Clause> rules, String topRuleName) {
  final defs = <String, lib.Clause>{
    for (final e in rules.entries)
      e.key.startsWith('~') ? e.key.substring(1) : e.key: e.value
  };
  final built = <String, c9.Rule>{
    for (final name in defs.keys) name: c9.Rule(name)
  };

  c9.Clause node(lib.Clause c) {
    if (c is lib.Ref) {
      final rule = built[c.ruleName];
      if (rule == null) throw ArgumentError('rule "${c.ruleName}" not found');
      return c9.RuleRef(c, rule);
    }
    if (c is lib.Seq) {
      return c9.Seq(c, [for (final s in c.subClauses) node(s)]);
    }
    if (c is lib.First) {
      return c9.First(c, [for (final s in c.subClauses) node(s)]);
    }
    if (c is lib.Repetition) {
      return c9.Repetition(c, node(c.subClause), c.requireOne);
    }
    if (c is lib.Optional) return c9.Optional(c, node(c.subClause));
    if (c is lib.FollowedBy) return c9.FollowedBy(c, node(c.subClause));
    if (c is lib.NotFollowedBy) return c9.NotFollowedBy(c, node(c.subClause));
    if (c is lib.Str) return c9.Str(c, c.text);
    if (c is lib.Char) return c9.Char(c, c.char.codeUnitAt(0));
    if (c is lib.CharSet) return c9.CharSet(c, c.ranges, c.inverted);
    if (c is lib.AnyChar) return c9.AnyChar(c);
    if (c is lib.Nothing) return c9.Nothing(c);
    throw UnsupportedError('clause kind ${c.runtimeType}');
  }

  for (final e in defs.entries) {
    built[e.key]!.body = node(e.value);
  }
  return c9.Squirrel(rules: built, topRuleName: topRuleName);
}
