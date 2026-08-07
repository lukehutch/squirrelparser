#!/usr/bin/env python3
"""Which engines are still worth considering: the Pareto frontier over the four
axes the project actually scores on.

WHY THIS EXISTS. A hand-built "worth considering" list was wrong twice in one
occasion, both times the same way -- an engine kept because one column looked
good, without checking whether some other engine beat it on every column at
once. m78 was kept on its perfect% (m132 beats it on all four); m112 and m121
were put on the frontier (r9 beats both on all four, and nobody had compared 536
lines against 578). Domination is arithmetic wherever all the axes are recorded,
so it is computed here rather than read off a table.

AXES. score (up), perfect% (up), era-2 battery ms (down), normalised LOC (down).

TIE TOLERANCE. 0.0001 of AST-diff score over 1,824 weighted cases is 0.18 of one
case, so score is compared at 3 decimals; `--exact` uses 4 and admits three more
engines that survive on 0.18 of a case. The ms column carries ~7% within-session
spread (LESSONS 3.6), so a sub-7% latency gap is not a real difference -- no
domination reported here rests on one, but re-check that if the data changes.

DATA. Scores/perfect%/ms are the one-session era-2 sweep recorded in
LESSONS_LEARNED.md (Appendix). LOC comes from loc.py, the one authority, via its
cache when present. Excluded: sd3-m22 (the LR-broken run -- broken, not slower),
m63/m65-m70 (never finished the battery), and m75/m77, which D1 disqualifies for
re-parsing and which are reported separately so they can never dominate.
"""
import json
import os
import sys

import loc

# name: (score, perfect%, era-2 battery ms)
E = {
    # Era-3 battery (five operation categories; coin-flip operator mutations
    # and one/two-char truncation stubs curated out; truncation expectations
    # drop LR-wrapper levels the cut removed -- astdiff.dart, LESSONS I107).
    # Measured 2026-08-06, one machine, one sweep.
    # c6/c5 timed interleaved the same session (medians ~1490 vs ~1657); c5's
    # standing sweep number is kept for the rest of the table's scale. The
    # non-c engines are archived in attic/ with their last era-3 numbers in
    # attic/OLD_LESSONS_LEARNED.md.
    'c6': (0.9879, 84.0, 1490),
    'c5': (0.9878, 83.9, 1620),
    'c4': (0.9878, 83.9, 1687), 'c3': (0.9829, 81.2, 1713),
    'c1': (0.9818, 78.6, 1785), 'c2': (0.9812, 78.5, 2354),
}
DQ = {}


def loc_of(names):
    """Normalised LOC per engine, from loc.py's cache if it is present."""
    cache = loc.S + 'loc.json'
    if os.path.exists(cache):
        d = json.load(open(cache))
        if all(n in d for n in names):
            return {n: d[n][1] for n in names}
    return {n: v[1] for n, v in loc.normalised(names).items()}


def main():
    tol = 4 if '--exact' in sys.argv else 3
    L = loc_of(list(E) + list(DQ))

    def vec(n, t):  # every axis turned into "bigger is better"
        s, p, ms = t
        return (round(s, tol), p, -ms, -L[n])

    def beats(a, b):
        return all(x >= y for x, y in zip(a, b)) and any(x > y for x, y in zip(a, b))

    front = [n for n, t in E.items()
             if not any(beats(vec(m, u), vec(n, t)) for m, u in E.items() if m != n)]
    front.sort(key=lambda n: -E[n][0])
    print('score to %ddp: %d of %d engines on the frontier\n' % (tol, len(front), len(E)))
    print('  %-5s %6s %6s %7s %6s  dominates' % ('', 'score', 'perf%', 'ms', 'LOC'))
    for n in front:
        k = [m for m in E if m != n and beats(vec(n, E[n]), vec(m, E[m]))]
        print('  %-5s %.4f %6.1f %7d %6d  %d' % (n, *E[n], L[n], len(k)))
    print('\ndominated (%d): %s' % (len(E) - len(front),
          ' '.join(sorted(set(E) - set(front), key=lambda n: -E[n][0]))))

    print('\nD1-disqualified (re-parse), held out so they cannot dominate:')
    for n, t in DQ.items():
        d = [m for m in E if beats(vec(m, E[m]), vec(n, t))]
        print('  %-5s %.4f %6.1f %7d %6d  beaten on all four by: %s'
              % (n, *t, L[n], ' '.join(sorted(d)) or 'nothing'))

    print('\nbest score at each size ceiling:')
    for cap in (400, 450, 500, 550, 600, 650):
        ok = [(E[n][0], n) for n in E if L[n] <= cap]
        if ok:
            b = max(ok)
            print('  <=%4d lines: %.4f (%s), %d engines qualify' % (cap, b[0], b[1], len(ok)))


if __name__ == '__main__':
    main()
