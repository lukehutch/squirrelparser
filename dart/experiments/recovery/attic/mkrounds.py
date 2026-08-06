#!/usr/bin/env python3
"""Instrument m121's deepening loop with a per-ROUND clock.

WHY. The latency plan (cost-stratified semi-naive chart) rests on one claim:
clearing the repair memo at the top of every round (m121.dart:570-571) makes
round b redo round b-1's work, so the redundancy is worth eliminating. That is
an assumption, and it is cheap to falsify. If the FINAL round dominates the
clock, then every earlier round together is a small share and the rewrite's
ceiling is small -- the plan would be wrong before a line of it is written.

So: time each round separately, bucketed by round ORDINAL (0,1,2,4,8,... -> 0th,
1st, 2nd, ...), and report where the time actually goes. Reads a global out of
the engine rather than changing any behaviour: the loop body is untouched.
"""
import re
import sys

D = '/home/luke/Work/squirrelparser/dart/experiments/recovery/'
# Which engine to instrument (default m121, the engine this was written for).
ENG = sys.argv[1] if len(sys.argv) > 1 else 'm121'
src = open(D + ENG + '.dart', encoding='utf-8').read()

# 1. globals to accumulate into, next to the existing `int _budget = 0;`
anchor = 'int _budget = 0;'
assert src.count(anchor) == 1
src = src.replace(anchor, anchor + '''

// -- instrumentation (not part of the engine) --------------------------------
/// Microseconds spent in each deepening ROUND, indexed by round ordinal.
final List<int> kRoundUs = List.filled(64, 0);
/// How many recover() calls reached each round ordinal.
final List<int> kRoundHits = List.filled(64, 0);
/// Round ordinal at which each recover() call SUCCEEDED (-1 = never).
final List<int> kWinRound = List.filled(64, 0);
final Stopwatch _kSw = Stopwatch();
int _kOrd = 0;
/// Exact microseconds spent in rounds that were DISCARDED (per call, summed).
int kWastedUs = 0;
/// Exact microseconds spent in the round that ANSWERED (per call, summed).
int kProdUs = 0;
/// Rounds completed so far in the current call, in microseconds.
int _kPreUs = 0;
''')

# 2. start the per-round clock right after the round's memo setup. m121/m124
# clear the single round tables here; m125 onward (I74) instead makes the
# per-budget families reach this budget, so accept either shape.
setups = ['''      _mc.clear();
      _me.clear();
      _rg = List.filled(s.length + 1, 0);''', '      _room(_budget);']
old = next((o for o in setups if src.count(o) == 1), None)
assert old is not None, 'no round-setup anchor matched'
src = src.replace(old, old + '''
      kRoundHits[_kOrd] += 1;
      _kSw.reset();
      _kSw.start();''')

# 3. stop it on BOTH exits from the round: the success return and the loop end
old = '''      if (best != null) {
        lastCost = best.cost;'''
assert src.count(old) == 1
src = src.replace(old, '''      _kSw.stop();
      final _kThis = _kSw.elapsedMicroseconds;
      kRoundUs[_kOrd] += _kThis;
      if (best != null) {
        kWinRound[_kOrd] += 1;
        kProdUs += _kThis;
        kWastedUs += _kPreUs;
        _kPreUs = 0;
        _kOrd = 0;
        lastCost = best.cost;''')

# the round ended without a winner -> advance the ordinal
old = '''        return Match(null, 0, s.length, subClauseMatches: kids);
      }
    }'''
assert src.count(old) == 1
src = src.replace(old, '''        return Match(null, 0, s.length, subClauseMatches: kids);
      }
      _kPreUs += _kThis;
      _kOrd += 1;
    }
    kWastedUs += _kPreUs;
    _kPreUs = 0;
    _kOrd = 0;''')

# 4. reset the ordinal at the START of each recover() so calls do not bleed
old = '''    final cap = 2 * s.length + (_witness(top)?.length ?? 0) + 1;'''
assert src.count(old) == 1
src = src.replace(old, '''    _kOrd = 0;
    _kPreUs = 0;
    final cap = 2 * s.length + (_witness(top)?.length ?? 0) + 1;''')

open(D + '_' + ENG + 'r.dart', 'w', encoding='utf-8').write(src)
print('wrote _' + ENG + 'r.dart')
