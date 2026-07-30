// m66 -- TRUST, BUT VERIFY: the relaxation answers; the tape is the appeal
// court. True-PEG exactness at the relaxed engine's speed on every input
// where the relaxation can prove itself -- which is every input on which it
// did not, in fact, lie.
//
//   I22 A VERIFIED WITNESS IS A CERTIFICATE OF EQUALITY. The CFG-union
//       reading accepts a superset of the true PEG language, so the relaxed
//       cost c62 is a FLOOR on the true cost for every input. When the
//       relaxed witness string survives I5 verification -- a clean pure
//       parse of the repaired text, a check the relaxed engine already
//       performs -- the true cost is squeezed: trueCost <= d(s, witness) =
//       c62 <= trueCost. Equality, and the witness in hand is a legitimate
//       minimum-cost true repair. The relaxation's one failure mode
//       (repairing toward a parse the committed grammar would never take)
//       is precisely the case its own verification detects, so the router
//       is total: return the relaxed result verbatim when verified, and
//       fall back to the tape (m65) exactly where the relaxation lied --
//       the conformance cases, where slowness is the price of truth.
//
// Routing, in order: a direct pure parse (clean is true membership, cost 0);
// relaxed -1 is exact (CFG-empty implies PEG-empty); relaxed 0 with a
// failing pure parse is a lie at cost zero, straight to the tape (the
// relaxed engine's recover() cannot even be called there); otherwise the
// relaxed recover runs, its verification bit routes. PARAMETERS: NONE.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/recovery/skip_recovery.dart'
    show SkipResult;
import 'm62.dart' as relaxed;
import 'm65.dart' as tape;

class SuperDot3 {
  final Map<String, Clause> rules;
  final String topRuleName;
  SuperDot3({required this.rules, required this.topRuleName});

  late final relaxed.SuperDot3 _fast =
      relaxed.SuperDot3(rules: rules, topRuleName: topRuleName);
  late final tape.SuperDot3 _exact =
      tape.SuperDot3(rules: rules, topRuleName: topRuleName);

  int lastCost = -1, lastSteps = -1;
  bool lastVerified = false;
  bool lastFellBack = false;
  int get lastCells => lastFellBack ? _exact.lastCells : 0;

  SkipResult _route(String input) {
    lastFellBack = false;
    final pure =
        Parser(rules: rules, topRuleName: topRuleName, input: input).parse();
    if (!pure.hasSyntaxErrors) {
      lastCost = 0;
      lastSteps = 0;
      lastVerified = true;
      return SkipResult(pure.root, const [], const [], 0, false);
    }
    final r = _fast.recover(input);
    if (_fast.lastCost == -1) {
      lastCost = -1; // CFG-empty implies PEG-empty: exact
      lastSteps = 0;
      lastVerified = false;
      return r;
    }
    if (_fast.lastVerified) {
      lastCost = _fast.lastCost;
      lastSteps = _fast.lastSteps;
      lastVerified = true;
      return r;
    }
    // An unverified witness -- including a relaxed 0 on an input the pure
    // parse rejects: the relaxation lied; the tape answers.
    lastFellBack = true;
    final t = _exact.recover(input);
    lastCost = _exact.lastCost;
    lastSteps = _exact.lastSteps;
    lastVerified = _exact.lastVerified;
    return t;
  }

  SkipResult recover(String input) => _route(input);

  int recoverCost(String input) {
    _route(input);
    return lastCost;
  }
}
