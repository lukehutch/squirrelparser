#!/usr/bin/env python3
"""Instrument m121 to size TWO within-round savings the round profiler missed.

Occasion 54 measured CROSS-round redundancy (rounds whose result is discarded)
at 28.9% and refuted the semi-naive plan on that ceiling. That measurement says
nothing about waste WITHIN the round that wins, which is where the other 71%
lives. Two candidates are visible in the source, and both are cheap to size.

  A. RESIDUAL BUDGET. `_seq` (m121.dart:868-870) asks `_element` for a search at
     the FULL budget and only then discards every way whose cost does not fit in
     what the prefix left: `if (cost > _budget) continue`. When the prefix has
     already spent the whole budget, the residual is 0, so only the cost-0 ways
     could ever survive -- the entire repair search under that call was waste,
     and a pure-table lookup would have answered it. `_rep` has the same shape.

  B. ORDERED-CHOICE FAN-OUT. `_first` (m121.dart:981-991) skips an alternative
     with no pure reading for one `continue` at budget 0, but at budget >= 1
     runs a COMPLETE repair search on it. That is the visible reason budget 0
     costs 0.027 ms/case and budget 1 costs 0.94 -- a 35x step that every case
     pays. This counts how much of the clock those searches are.

Both are sized the same honest way: COUNTS, plus the wall time of the subtree
rooted at each OUTERMOST such call. Outermost-only means the intervals never
overlap, so the times are summable and are a true ceiling -- a nested residual-0
call inside a residual-0 subtree is already inside the time being attributed.

The ceiling is an over-estimate for one nameable reason: the real call is made
at the full budget and MEMOISED there, so a later caller that genuinely needs
the full-budget answer reads it free. Under a per-budget memo that work would be
done once per budget instead of once. So treat these as upper bounds.

Behaviour is untouched -- every insertion is a counter or a stopwatch.
"""
import re

D = '/home/luke/Work/squirrelparser/dart/experiments/recovery/'
src = open(D + 'm121.dart', encoding='utf-8').read()

# ---------------------------------------------------------------- 1. globals
anchor = 'int _budget = 0;'
assert src.count(anchor) == 1
src = src.replace(anchor, anchor + '''

// -- instrumentation (not part of the engine) --------------------------------
/// `_element` calls from a sequence/repetition fold, bucketed by the budget the
/// prefix actually LEFT (`_budget - w.cost`). Index 0 = the prefix already spent
/// everything, so only cost-0 ways can survive the filter below the call.
final List<int> kResidCalls = List.filled(64, 0);
/// Of those, the ones made while `_budget > 0` and the residual is 0.
int kZeroCalls = 0, kZeroUs = 0;
/// Ways returned by such calls, and how many the cost filter then discarded.
int kZeroWays = 0, kZeroCut = 0;
/// `_first` alternatives given a full repair search because they had no pure
/// reading (the budget >= 1 branch), and the wall time of those searches.
int kAltCalls = 0, kAltUs = 0;
/// Ways those searches produced, and how many survived to be offered upward.
int kAltWays = 0;

/// Outermost-only nesting guards: an interval already being timed swallows the
/// ones inside it, so the recorded times never overlap and are summable.
bool _kInZero = false, _kInAlt = false;
final Stopwatch _kZeroSw = Stopwatch(), _kAltSw = Stopwatch();

void kResetProbe() {
  for (var i = 0; i < kResidCalls.length; i++) {
    kResidCalls[i] = 0;
  }
  kZeroCalls = kZeroUs = kZeroWays = kZeroCut = 0;
  kAltCalls = kAltUs = kAltWays = 0;
  _kInZero = _kInAlt = false;
}
// -- end instrumentation -----------------------------------------------------''')

# ------------------------------------------------- 2. the sequence fold (A)
old_seq = '''      for (var w = ways; w != null; w = w.next) {
        for (var x = _element(sub, w.end); x != null; x = x.next) {
          final cost = w.cost + x.cost;
          if (cost > _budget) continue;'''
assert src.count(old_seq) == 1
new_seq = '''      for (var w = ways; w != null; w = w.next) {
        final _resid = _budget - w.cost;
        kResidCalls[_resid < 0 ? 0 : (_resid > 63 ? 63 : _resid)]++;
        final _zero = _budget > 0 && _resid == 0;
        final _outer = _zero && !_kInZero;
        if (_outer) {
          _kInZero = true;
          _kZeroSw
            ..reset()
            ..start();
        }
        final _x0 = _element(sub, w.end);
        if (_outer) {
          _kZeroSw.stop();
          kZeroUs += _kZeroSw.elapsedMicroseconds;
          _kInZero = false;
        }
        if (_zero) {
          kZeroCalls++;
          for (var y = _x0; y != null; y = y.next) {
            kZeroWays++;
            if (w.cost + y.cost > _budget) kZeroCut++;
          }
        }
        for (var x = _x0; x != null; x = x.next) {
          final cost = w.cost + x.cost;
          if (cost > _budget) continue;'''
src = src.replace(old_seq, new_seq)

# ---------------------------------------------- 3. the repetition fold (A)
old_rep = '''      final w = _at(reach, at)!;
      for (var x = _element(r.subClause, at); x != null; x = x.next) {'''
assert src.count(old_rep) == 1
new_rep = '''      final w = _at(reach, at)!;
      final _resid = _budget - w.cost;
      kResidCalls[_resid < 0 ? 0 : (_resid > 63 ? 63 : _resid)]++;
      final _zero = _budget > 0 && _resid == 0;
      final _outer = _zero && !_kInZero;
      if (_outer) {
        _kInZero = true;
        _kZeroSw
          ..reset()
          ..start();
      }
      final _x0 = _element(r.subClause, at);
      if (_outer) {
        _kZeroSw.stop();
        kZeroUs += _kZeroSw.elapsedMicroseconds;
        _kInZero = false;
      }
      if (_zero) {
        kZeroCalls++;
        for (var y = _x0; y != null; y = y.next) {
          kZeroWays++;
          if (w.cost + y.cost > _budget) kZeroCut++;
        }
      }
      for (var x = _x0; x != null; x = x.next) {'''
src = src.replace(old_rep, new_rep)

# ------------------------------------------- 4. the ordered-choice branch (B)
old_alt = '''      for (var e = _clause(a, pos); e != null; e = e.next) {
        if (!e.synth) {'''
assert src.count(old_alt) == 1
new_alt = '''      final _aOuter = !_kInAlt;
      if (_aOuter) {
        _kInAlt = true;
        _kAltSw
          ..reset()
          ..start();
      }
      final _a0 = _clause(a, pos);
      if (_aOuter) {
        _kAltSw.stop();
        kAltUs += _kAltSw.elapsedMicroseconds;
        _kInAlt = false;
      }
      kAltCalls++;
      for (var e = _a0; e != null; e = e.next) {
        kAltWays++;
        if (!e.synth) {'''
src = src.replace(old_alt, new_alt)

out = D + '_r121b.dart'
open(out, 'w', encoding='utf-8').write(src)
print('wrote', out)
