// Scratch: hand _accept.dart's own logic a u9 engine, so the gate runs
// unmodified against the candidate without a tracked file importing scratch.
import 'package:squirrel_parser/squirrel_parser.dart';

import '_u10.dart' as u9;

typedef Build = MatchResult Function(String) Function(
    Map<String, Clause>, String);

Build? resolve(String name) =>
    (r, t) => u9.Squirrel(rules: r, topRuleName: t).recover;
