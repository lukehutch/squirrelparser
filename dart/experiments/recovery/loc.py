#!/usr/bin/env python3
"""Normalised LOC for every engine, so the column compares engines and not
formatter eras.

THE DEFECT THIS FIXES. The project's LOC measure is "non-blank lines that do not
start with //", counted on the file as committed. But the files were committed
across two `dart format` eras: Dart 3.7 introduced the "tall" style, and which
style applies is chosen by the LANGUAGE VERSION resolved for the file, not by
the formatter binary. `dart/pubspec.yaml` declares `sdk: '>=3.0.0 <4.0.0'`, so
in-package formatting selects the SHORT style. Measured drift, committed vs
reformatted in-package: m62 +2, m75 0, m78 +30, m105 +27, m112 +25, m113 +24,
m117 0. So a 555 and a 575 from different eras were never comparable, and the
20-line "penalty" I read off them was an artifact.

Formatting a copy under a mere COPY of pubspec.yaml does NOT reproduce it --
that gives m113 = 682, because the language version is resolved through
.dart_tool/package_config.json, which the copy has no way to reach, so the file
falls back to the newest version and gets the tall style. `--language-version=3.0`
reproduces the in-package figure exactly (m113 = 579, verified against the
in-package reformat), and leaves the repository untouched.
"""
import json
import os
import shutil
import subprocess

D = '/home/luke/Work/squirrelparser/dart/experiments/recovery/'
LIB = '/home/luke/Work/squirrelparser/dart/experiments/recovery/attic/libsrc_recovery/'
S = ('/tmp/claude-1001/-home-luke-Work-squirrelparser/'
     '1a737cdf-c369-45bf-956c-1b5bf00d5723/scratchpad/')
TMP = S + 'fmtn/'

ALIAS = {'dot': LIB + 'dot_recovery.dart', 'v6': D + 'attic/sd6.dart'}


def src_for(name):
    if name in ALIAS:
        return ALIAS[name]
    p = D + name + '.dart'
    return p if os.path.exists(p) else None


def count(path):
    n = 0
    for line in open(path, encoding='utf-8', errors='replace'):
        t = line.strip()
        if t and not t.startswith('//'):
            n += 1
    return n


def normalised(names):
    """{name: (raw, normalised)} -- normalised is LOC after `dart format
    --language-version=3.0`, the style the package itself selects."""
    shutil.rmtree(TMP, ignore_errors=True)
    os.makedirs(TMP)
    out, paths = {}, {}
    for n in names:
        p = src_for(n)
        if not p:
            continue
        dst = TMP + n + '.dart'
        shutil.copy(p, dst)
        paths[n] = (p, dst)
    r = subprocess.run(['dart', 'format', '--language-version=3.0', TMP],
                       capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit('dart format failed: ' + r.stderr[:400])
    for n, (p, dst) in paths.items():
        out[n] = (count(p), count(dst))
    return out


if __name__ == '__main__':
    names = sorted(f[:-5] for f in os.listdir(D) if f.endswith('.dart')
                   and not f.startswith('_'))
    names.append('dot')
    res = normalised(names)
    json.dump(res, open(S + 'loc.json', 'w'), indent=0)
    drift = {k: v[1] - v[0] for k, v in res.items() if v[1] != v[0]}
    print('%d files; %d differ from their committed count' % (len(res), len(drift)))
    for k in sorted(drift, key=lambda k: -abs(drift[k]))[:14]:
        print('  %-10s committed %4d  normalised %4d  %+d'
              % (k, res[k][0], res[k][1], drift[k]))
    print()
    for k in ('m62', 'm75', 'm78', 'm105', 'm112', 'm113', 'm114', 'm115',
              'm117', 'm120', 'm121', 'm122', 'm123', 'dot'):
        if k in res:
            print('  %-10s raw %4d  norm %4d' % (k, res[k][0], res[k][1]))
