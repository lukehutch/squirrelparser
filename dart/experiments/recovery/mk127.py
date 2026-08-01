#!/usr/bin/env python3
r"""m127/m128 = m126 + I76: I43's evidence test belongs at the ENDING, not at the
alternative.

THE DEFECT, found by following the latency and arriving at a quality bug. On
`"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}` -- a JSON document whose
opening `{` was deleted -- m126 answers at cost 11 by reading the WHOLE document
as one String, filling ten `\` escapes so each real `"` becomes string content,
then discarding the final `}`:

    FILL@2 "\"  FILL@6 "\"  FILL@9 "\" ... FILL@42 "\"  SKIP@46+1 "}"

The correct reading -- fill one `{` and recover the object -- costs 1. It is
never offered. At position 0 the `Value` choice tries `Object` (no pure reading;
its ways OPEN with a filled `{`, so they go to `opened`), then `Array` (likewise),
then `String`, which HAS a pure reading because `"a"` is a perfectly good String.
I51's early return then answers the choice from `String` alone and `opened` is
dropped on the floor. So a cost-1 answer is discarded in favour of a cost-11 one,
and the deepening then has to climb to budget 16 to find the expensive answer,
which is why these six documents cost ~1,182 ms of the battery's 2,103.

This is the very swallow I43's comment says it exists to stop -- "one invented
character buys the reclassification of a real delimiter into string content" --
arriving by a route I43 does not cover: the way opens on a REAL `"` and does its
inventing INSIDE the body, where I53 admits it because `[^"\\]` cannot match a
`"` and so nothing else can be entered there.

I76. I39 already established that a PEG choice commits to a SHAPE but not to an
ENDING. I43's question -- "did the evidence choose this, or did the repair?" --
therefore has to be asked at each ending separately, because an ending is the
only place two readings actually compete. At an ending the evidence reaches for
FREE, evidence decides and the repair-opened way is refused, exactly as I43 says.
At an ending the evidence reaches only BY REPAIRING, evidence decided nothing:
both readings are guesses, and cost settles it. An alternative that is free at
its first character and then needs ten fills to arrive was not "committed to by
the evidence" in any sense I43 can appeal to -- I43 was reading a one-character
test as though it described the whole way.

It is also what the brief asks for in as many words -- a brace may be inserted to
fix the structure "after satisfying yourself that that is in fact the optimal
fix". Satisfying yourself requires making the comparison, which a blanket discard
prevents.

TWO VARIANTS, because the strength of the weakening is exactly what has to be
measured, and the record says this is where the battery's largest failure bucket
lives (the `\` fill alone was 172 of 519 mutants before I43):

  m127  admit the repair-opened way at an ending the evidence reaches only by
        repairing, OR does not reach at all.
  m128  admit it ONLY at an ending the evidence reaches BY REPAIRING. The
        strictly smaller step: an ending no evidence-opened way reaches at all
        stays refused, as under I43.
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


src0 = open(D + 'm126.dart', encoding='utf-8').read()
assert src0.startswith('// m126.dart --')

# ------------------------------------------------------------ 1. the helper
ANCHOR = '''/// Concatenate two ways. Synthesis stays "at the head" only while no evidence
/// has been read yet, which is what makes [_Way.synth] mean what I43 needs.'''
assert src0.count(ANCHOR) == 1

HELPER = r'''/// I76: ASK I43'S QUESTION AT THE ENDING, NOT AT THE ALTERNATIVE.
///
/// I43 refuses a way that OPENS with a repair whenever some alternative opens on
/// evidence, so that a repair cannot pick the SHAPE. But I39 says a choice
/// commits to a shape and not to an ending, and an ending is the only place two
/// readings meet. So the test belongs here, per ending:
///
///   * the evidence reaches this ending for FREE -- it decided, and the
///     repair-opened way is refused, exactly as I43 says;
///   * the evidence reaches it only BY REPAIRING (or not at all) -- it decided
///     nothing, both readings are guesses, and [_put] lets cost settle it.
///
/// An alternative that is free at its first character and then needs ten fills
/// to reach the ending was never "committed to by the evidence"; I43 was reading
/// a one-character test as if it described the whole way. Measured on a JSON
/// document with its opening `{` deleted, this is the difference between filling
/// one brace (cost 1) and reading the whole document as a String held together
/// by ten filled `\` escapes (cost 11).
_Way? _admit(_Way? evidence, _Way? opened) {
  if (evidence == null || opened == null) return evidence ?? opened;
  _Way? out = evidence;
  for (_Way? e = opened; e != null; e = e.next) {
    final rival = _at(out, e.end);
    if (RIVAL) out = _put(out, _cons(e, null));
  }
  return out;
}

'''

# ------------------------------------------------ 2. I51's early return (the
# discard that matters here: a pure alternative answers the choice and `opened`
# never gets to compete)
OLD_EARLY = '''        final w = _clause(a, pos);
        if (w != null) {
          if (out == null) return _wrap(f, pos, w);
          for (_Way? e = w; e != null; e = e.next) {
            out = _put(out, _cons(e, null));
          }
          return _wrap(f, pos, out);
        }'''
assert src0.count(OLD_EARLY) == 1

NEW_EARLY = '''        final w = _clause(a, pos);
        if (w != null) {
          // I76: the fast path survives only while there is nothing to weigh
          // this against -- with repair-opened ways in hand, the endings they
          // reach have to be compared before the choice is answered.
          if (out == null && opened == null) return _wrap(f, pos, w);
          for (_Way? e = w; e != null; e = e.next) {
            out = _put(out, _cons(e, null));
          }
          return _wrap(f, pos, _admit(out, opened));
        }'''

# --------------------------------------------------------- 3. the tail return
OLD_TAIL = '    return _wrap(f, pos, out ?? opened);'
assert src0.count(OLD_TAIL) == 1
NEW_TAIL = '    return _wrap(f, pos, _admit(out, opened));'

VARIANTS = {
    'm127': ('rival == null || rival.cost > 0',
             "// m127.dart -- I76: I43's evidence test is asked at each ending, not once per\n"
             "// alternative, so an ending the evidence reaches only by repairing is open to\n"
             "// a repair-opened reading. Generated by mk127.py from m126.dart.\n"),
    'm128': ('rival != null && rival.cost > 0',
             '// m128.dart -- I76, the strict form: only an ending the evidence reaches BY\n'
             '// REPAIRING is opened to a repair-opened way; an ending it does not reach at\n'
             '// all stays refused, as under I43. Generated by mk127.py from m126.dart.\n'),
}

for name in (sys.argv[1:] or ['m127', 'm128']):
    rival, head = VARIANTS[name]
    src = head + src0[_body(src0):]
    src = src.replace(ANCHOR, HELPER.replace('RIVAL', rival) + ANCHOR)
    src = src.replace(OLD_EARLY, NEW_EARLY)
    src = src.replace(OLD_TAIL, NEW_TAIL)
    open(D + name + '.dart', 'w', encoding='utf-8').write(src)
    print('wrote', D + name + '.dart')
