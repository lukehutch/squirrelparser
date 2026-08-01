#!/usr/bin/env python3
r"""m137/m138/m139 = I79: INVENTION MUST PAY FOR ITSELF IN EXPLANATION.

WHAT m135 EXPOSED. m135 deleted I43, I53, `_admit` and the two-list split, on the
claim that I78 alone ("a repair may not conjure a shape the input does not
witness", tested as `net == 0`) is the whole rule. It is not. Deleting the I76
guard cost 0.0031 aggregate and 318 ms, concentrated in `literal-damage`
0.970 -> 0.946, and the per-case diff names the mechanism exactly. On
`{"a":1,"bc":[2,33,rue],...}`:

    m134  cost=2  FILL@18 '"'  FILL@21 '"'      <- quote `rue`, a local repair
    m135  cost=2  FILL@10 '\'  FILL@23 '\'      <- the `\`-escape swallow, back

I78 cannot see that swallow, and the reason is precise. A JSON escape is
`'\\' ["\\/bfnrt]` -- a CONSTRAINING CharSet. So an invented `\` PROMOTES the
real `"` after it out of the wide body class `[^"\\]` and into a precise one,
and that real character then counts toward `net`. The invented character buys
itself a witness. `net == 0` is therefore not a test a fill cannot game; it is
one this particular fill games by construction.

I79. Look at what the swallow actually achieves and the tell is in the numbers
already computed. Each invented `\` explains exactly one real character -- the
`"` it escapes -- and nothing else, because the rest of the swallowed span goes
through `[^"\\]` at `net` 0. So the reading explains precisely as much as it
invents. The honest repairs are not like that at all:

    deleted `{`      cost 1   net ~7    fills one brace, explains a whole object
    `,` before true  cost 1   net  4    fills one comma, explains `true`
    `\`-swallow      cost 2   net  2    two fills, two escaped quotes, nothing more
    `"rue"`          cost 2   net  0    two fills, eleven chars through `[^"\\]`
    `[1,[2,[3,[4`    cost 2   net  0    two fills, the whole span unexplained

So the test is not "does the input witness this at all" but "does the input
witness MORE than the repair invented":

    admit a repair-opened reading iff  net > cost

Same units on both sides -- characters -- so this is not a tuned ratio and adds
no constant. It says invention must pay for itself: a fill earns its place by
explaining constrained input it did not itself create, and a fill whose only
yield is the character it reclassified has earned nothing. I78 is the `cost >= 1`
case of it, which is why I78 caught the two swallows whose fills yield nothing
and missed the one whose fills yield exactly themselves.

If this holds, the I76 guard has nothing left to defend and the m135 collapse --
one list, one condition, 599 LOC -- comes back with the score intact.

VARIANTS:

  m137  m135 (single list, no I76 guard) with `net <= cost` refused. The whole
        claim: I79 alone replaces I43, I53, I76 and I78 together.
  m138  m134 (guard kept) with I78 sharpened to I79 inside `_admit`. Separates
        "I79 is a better witness test" from "I79 makes the guard redundant".
  m139  m135 with the milder `net < cost` refused, so a reading that breaks even
        is admitted. The `\`-swallow breaks even exactly, so this SHOULD fail to
        fix `literal-damage` -- the control that says the boundary is the claim.
"""
import sys

D = '/home/luke/Work/squirrelparser/dart/experiments/recovery/'


def _body(src):
    """Index just past the whole leading `//` header block, so a regenerated
    engine does not inherit the headers of every engine it was derived from."""
    i = 0
    for line in src.split('\n'):
        if not line.startswith('//'):
            break
        i += len(line) + 1
    return i


DOC = r'''        // I79: INVENTION MUST PAY FOR ITSELF IN EXPLANATION.
        //
        // `net` counts real input characters matched by a terminal that
        // CONSTRAINS what it accepts, and a fill contributes none, so
        // `net > cost` asks whether this reading explains more real, constrained
        // input than it invented. Filling one `{` and recovering an object of
        // real keys and values pays many times over; filling both quotes of a
        // String and reading eleven characters through `[^"\\]` pays nothing.
        //
        // The boundary matters, and a weaker `net > 0` does not hold it. A JSON
        // escape is `'\\' ["\\/bfnrt]`, a CONSTRAINING set, so an invented `\`
        // promotes the real `"` after it out of the wide body class into a
        // precise one and that character then counts as explained: the fill buys
        // itself a witness. Such a reading explains exactly one character per
        // fill and no more, so it breaks even and is refused here, while every
        // honest completion clears the line by a wide margin.
        //
        // This is what I43 was reaching for with "a repair may not make the
        // choice". I43 tested where a way OPENS -- a one-character proxy, wrong
        // in both directions: it refused the filled `{`, whose partner `}` and
        // whose contents are all real, and it admitted the swallow wherever the
        // swallow happened to open on a real character. Aimed at the evidence
        // instead, it needs no exception for the case where nothing else can be
        // entered (I53) and no separate list to defer the comparison (I76).'''

TEST = 'if (e.synth && e.net <= e.cost) continue;'

# ---- m137/m139: single-list form (base m135). Replace I78's block wholesale.
OLD_135_HEAD = '        // I78: INVENTION MAY COMPLETE A SHAPE THE INPUT WITNESSES; IT MAY NOT'
OLD_135_TEST = '        if (e.synth && e.net == 0) continue;'

# m135 also carries I78 as the `///` doc block on `_first` (it replaced I43's
# there). Leaving it would describe a rule the engine no longer applies.
OLD_135_DOC_HEAD = '  /// I78: INVENTION MAY COMPLETE A SHAPE THE INPUT WITNESSES; IT MAY NOT CONJURE'
OLD_135_DOC_END = '  /// its exception and the two-list split it needed all go together.\n'
NEW_135_DOC = r'''  /// I79: INVENTION MUST PAY FOR ITSELF IN EXPLANATION. I36 says synthesis must
  /// not choose the TEXT; this says it must not choose the SHAPE either, and
  /// says it of the whole reading rather than of its first character. A repair
  /// earns its place only by explaining more real, constrained input than it
  /// invented -- [_Way.net] > [_Way.cost]:
  ///     `[2,33true]`   fill the `,`;  cost 1, net 4   the list was a list
  ///     `{"a":1`       fill the `}`;  cost 1, net >0  the object was an object
  ///     `"a":1,...}`   fill the `{`;  cost 1, net ~7  the `}` and keys are real
  ///     `{"e":ull}`    quote `ull`;   cost 2, net 0   REFUSED
  ///     `[1,[2,[3,[4`  quote it all;  cost 2, net 0   REFUSED
  ///     `,rue],"d":`   escape 2 `"`;  cost 2, net 2   REFUSED -- breaks even
  ///
  /// The last line is why the test is `net > cost` and not `net > 0`. A JSON
  /// escape is `'\\' ["\\/bfnrt]`, a CONSTRAINING set, so an invented `\`
  /// promotes the real `"` after it out of the wide body class `[^"\\]` into a
  /// precise one, and that character then counts as explained. The fill buys
  /// itself a witness -- one character per fill, exactly, and nothing else,
  /// because the rest of the swallowed span stays at `net` 0. Requiring the
  /// repair to come out AHEAD refuses it while every honest completion clears
  /// the line by a wide margin.
  ///
  /// This replaces I43, which asked whether a way OPENED with a repair. That was
  /// a one-character proxy for the question, and it was wrong in both
  /// directions. It refused the filled `{` -- whose partner `}` is real and
  /// whose contents are real keys and values -- and so answered a deleted brace
  /// by reading the whole document as one String held together by ten filled
  /// `\` escapes, cost 11 where the brace costs 1. And it ADMITTED the swallow
  /// wherever the swallow happened to open on a real character.
  ///
  /// Aimed at the evidence instead of at the opening, it also absorbs I53 -- a
  /// reading whose alternatives all fail is admitted iff something real still
  /// pays for it -- and I76, which deferred the comparison to the ending because
  /// the opening test could not be trusted to make it. Prohibition, exception,
  /// deferral and the two lists they needed all go together.
'''

# ---- m138: `_admit` form (base m134).
OLD_134_HEAD = '    // I78: THE INPUT MUST WITNESS THE SHAPE THE REPAIR IS COMPLETING.'
OLD_134_TEST = '    if (e.net == 0) continue;'

VARIANTS = {
    'm137': ('m135', OLD_135_HEAD, OLD_135_TEST, TEST,
             '// m137.dart -- I79: a repair-opened reading is admitted iff it explains more\n'
             '// constrained input than it invents (net > cost). One list, one condition:\n'
             '// I43, I53, I76 and I78 all fold into it. Generated by mk137.py from m135.dart.\n'),
    'm139': ('m135', OLD_135_HEAD, OLD_135_TEST,
             'if (e.synth && e.net < e.cost) continue;',
             '// m139.dart -- I79 with the boundary moved: a reading that BREAKS EVEN is\n'
             '// admitted. The `\\`-escape swallow breaks even exactly, so this is the control.\n'
             '// Generated by mk137.py from m135.dart.\n'),
    'm138': ('m134', OLD_134_HEAD, OLD_134_TEST, 'if (e.net <= e.cost) continue;',
             '// m138.dart -- m134 with I78 sharpened to I79, the I76 guard KEPT. Separates\n'
             '// "better witness test" from "guard now redundant".\n'
             '// Generated by mk137.py from m134.dart.\n'),
}

for name in (sys.argv[1:] or ['m137', 'm138', 'm139']):
    base, head, old_test, new_test, banner = VARIANTS[name]
    src = open(D + base + '.dart', encoding='utf-8').read()
    assert src.startswith('// ' + base + '.dart --')
    src = banner + src[_body(src):]

    # Excise I78's comment block (head .. the line before its test) and swap the
    # test, so the engine does not carry prose describing a rule it no longer has.
    i = src.index(head)
    j = src.index(old_test, i)
    assert src.count(old_test) == 1, name
    indent = ' ' * (len(old_test) - len(old_test.lstrip()))
    doc = '\n'.join(indent + ln.lstrip() if ln.strip() else ln
                    for ln in DOC.split('\n'))
    src = src[:i] + doc + '\n' + indent + new_test + src[j + len(old_test):]

    if base == 'm135':
        i = src.index(OLD_135_DOC_HEAD)
        j = src.index(OLD_135_DOC_END, i) + len(OLD_135_DOC_END)
        src = src[:i] + NEW_135_DOC + src[j:]

    body = src[_body(src):]
    assert 'I78' not in body, name
    open(D + name + '.dart', 'w', encoding='utf-8').write(src)
    print('wrote', D + name + '.dart')
