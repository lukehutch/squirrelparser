#!/usr/bin/env python3
"""Which engines re-parse a MODIFIED input string?

WHY THIS AUDIT EXISTS. The full table ranks m77 first (.9609 / 71.5% / 1,386 ms,
passing all three acceptance cases). Opening it: m77.dart:1141-1143 builds a
repaired string with `_repaired()` and runs a second, brand-new `Parser` over
it. That is the architecture the brief bans in four places --

  D1  "You should not need to create a new Parser engine, ever! ... Don't ever
       start a new parse."
      "you should not launch whole new parser instances; you should keep working
       with and updating the same memo table"
      "Why do you even need to produce a modified input string and invalidate
       cache entries to match the modified input string? Just keep parsing, and
       repairing/flagging in-place."
      "the input should not be modified or fixed in-place, ever"

-- so its score is not a score on the task as specified. Having found that by
opening ONE file, the same question has to be asked of all of them, or the
ranking silently mixes engines solving two different problems.

THE PREDICATE. Constructing a `Parser` is not itself the violation: an engine may
legitimately construct one over the ORIGINAL input and work with its memo table
(that is what the frozen library does). The violation is constructing one over a
string that is not the input. So the check extracts every `Parser(` construction
together with its `input:` argument, and reports the distinct argument
expressions per engine. The result is short enough to inspect by hand, which is
the point -- a regex is the search, not the verdict.
"""
import json
import os
import re

D = '/home/luke/Work/squirrelparser/dart/experiments/recovery/'
LIB = '/home/luke/Work/squirrelparser/dart/lib/src/recovery/'
S = ('/tmp/claude-1001/-home-luke-Work-squirrelparser/'
     '1a737cdf-c369-45bf-956c-1b5bf00d5723/scratchpad/')
ALIAS = {'dot': LIB + 'dot_recovery.dart', 'v6': D + 'sd6.dart'}

# `input:` argument expressions that ARE the original input.
ORIGINAL = {'input', 's', '_input', 'this.input', 'src', '_in'}

CALL = re.compile(r'\bParser\s*\(([^;]{0,300}?)\)\s*\.?', re.S)
ARG = re.compile(r'\binput\s*:\s*([A-Za-z_][\w.$]*(?:\(\))?)')


def src_for(name):
    if name in ALIAS:
        return ALIAS[name]
    p = D + name + '.dart'
    return p if os.path.exists(p) else None


def audit(name):
    p = src_for(name)
    if not p:
        return None
    src = open(p, encoding='utf-8', errors='replace').read()
    code = re.sub(r'^\s*//.*$', '', src, flags=re.M)   # prose does not count
    args = set()
    for m in CALL.finditer(code):
        a = ARG.search(m.group(1))
        args.add(a.group(1) if a else '<no input: arg>')
    if not args:
        return ('own', set())
    foreign = {a for a in args if a not in ORIGINAL}
    return ('reparse' if foreign else 'lib', foreign)


if __name__ == '__main__':
    names = sorted(f[:-5] for f in os.listdir(D)
                   if f.endswith('.dart') and not f.startswith('_'))
    names.append('dot')
    out, bykind = {}, {'own': [], 'lib': [], 'reparse': []}
    for n in names:
        r = audit(n)
        if r is None:
            continue
        kind, foreign = r
        out[n] = kind
        bykind[kind].append((n, sorted(foreign)))
    json.dump(out, open(S + 'reparse.json', 'w'), indent=0)
    for k in ('own', 'lib', 'reparse'):
        print('%-8s %d' % (k, len(bykind[k])))
    print()
    print('RE-PARSE A MODIFIED STRING (violates D1) -- the `input:` expressions:')
    for n, f in sorted(bykind['reparse']):
        print('  %-8s %s' % (n, ', '.join(f)))
    print()
    print('CONSTRUCT A PARSER OVER THE ORIGINAL INPUT ONLY (allowed):')
    print(' ', ' '.join(n for n, _ in sorted(bykind['lib'])))
