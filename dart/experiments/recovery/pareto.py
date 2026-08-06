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
    'dot': (0.9549, 67.3, 15705), 'm23': (0.9551, 67.2, 2142),
    'm24': (0.9551, 67.2, 2129), 'm25': (0.9551, 67.2, 1576),
    'm26': (0.9551, 67.2, 1479), 'm27': (0.9475, 62.3, 1721),
    'm28': (0.9551, 67.2, 1634), 'm29': (0.9484, 62.2, 9964),
    'm30': (0.9551, 67.2, 10690), 'm31': (0.9550, 67.2, 12006),
    'm32': (0.9550, 67.2, 1721), 'm33': (0.9550, 67.2, 1694),
    'm34': (0.9551, 67.1, 2911), 'm35': (0.8948, 64.9, 1776),
    'm36': (0.8948, 64.9, 1628), 'm37': (0.9551, 67.2, 1426),
    'm38': (0.9551, 67.2, 1296), 'm39': (0.9551, 67.2, 1332),
    'm40': (0.9551, 67.2, 1390), 'm41': (0.9550, 67.2, 1144),
    'm42': (0.9550, 67.2, 1264), 'm43': (0.9550, 67.2, 1290),
    'm44': (0.9550, 67.2, 1271), 'm45': (0.9550, 67.2, 1317),
    'm46': (0.9550, 67.2, 1312), 'm47': (0.9550, 67.2, 1440),
    'm48': (0.9550, 67.2, 1394), 'm49': (0.9550, 67.2, 1362),
    'm50': (0.9550, 67.2, 3061), 'm51': (0.9550, 67.2, 1837),
    'm52': (0.9550, 67.2, 1760), 'm53': (0.9550, 67.2, 1664),
    'm57': (0.9548, 67.1, 3370), 'm58': (0.9549, 67.2, 3602),
    'm59': (0.9550, 67.2, 13602), 'm60': (0.9550, 67.2, 1338),
    'm61': (0.9550, 67.2, 1729), 'm62': (0.9550, 67.2, 1354),
    'm64': (0.9550, 67.2, 1359), 'm71': (0.9550, 67.2, 1472),
    'm72': (0.9548, 67.1, 1518), 'm73': (0.9550, 67.2, 1293),
    'm74': (0.9548, 67.1, 1356), 'm76': (0.8262, 66.8, 2137),
    'm78': (0.9444, 68.4, 2135), 'm112': (0.9575, 67.2, 4395),
    'm113': (0.9573, 67.0, 4439), 'm121': (0.9573, 67.0, 4743),
    'm132': (0.9648, 69.2, 1098), 'm143': (0.9693, 72.1, 1131),
    'r9': (0.9748, 74.0, 2038), 'r13': (0.9008, 51.9, 6692),
    's1': (0.9841, 77.0, 1686), 't1': (0.9326, 57.7, 1035),
    's2': (0.9841, 77.0, 1715), 's3': (0.9819, 78.8, 1812),
    's4': (0.9823, 79.1, 1849), 'b2': (0.8826, 48.2, 7691),
    'c1': (0.9823, 79.1, 1576), 'c2': (0.9818, 78.7, 1949),
    'c3': (0.9826, 81.7, 1463),
}
DQ = {'m75': (0.9528, 70.8, 1275), 'm77': (0.9609, 71.5, 1389)}


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
