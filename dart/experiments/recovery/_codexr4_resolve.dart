import 'package:squirrel_parser/squirrel_parser.dart';

import '_codexr4_candidate.dart' as candidate;
import '_codexr4_under397.dart' as under397;

typedef Build = MatchResult? Function(String) Function(
    Map<String, Clause>, String);

Build? resolve(String name) => switch (name) {
      'r4' => (rules, top) =>
          candidate.Squirrel(rules: rules, topRuleName: top).recover,
      'under397' => (rules, top) =>
          under397.Squirrel(rules: rules, topRuleName: top).recover,
      _ => null,
    };
