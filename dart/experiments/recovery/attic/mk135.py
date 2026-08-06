#!/usr/bin/env python3
r"""m135/m136 = I78 standing alone: delete I43, I53, `_admit` and the two-list
split, because a correctly aimed rule does not need the proxy it replaces.

THE CLAIM. I43 refuses a way that OPENS with a repair while any alternative can
be entered on evidence. I53 puts back the case where nothing can. I76 puts back
the case where the evidence reaches an ending only by repairing. Each is a patch
on the same proxy: "opens with a repair" was never the thing being guarded
against. I78 names the thing itself -- a repair may not conjure a shape the input
does not witness -- and once it is stated, the three patches and the machinery
they need have nothing left to do:

    _Way? out, opened;                     ->  _Way? out;
    if (!e.synth) { out = ... }            ->  if (e.synth && e.net == 0) continue;
    else { opened = ... }                      out = _put(out, _cons(e, null));
    return _wrap(f, pos, _admit(out, opened)); -> return _wrap(f, pos, out);
    _Way? _admit(...) { ... }              ->  deleted

One list, one condition. Every repair-opened way that the input witnesses now
competes with the evidence-opened ways directly, at every ending, under the key
vector -- which is where a comparison belongs. The brief this serves says a
RELAXATION of criteria must reduce code, not add it; I76 and I78 added ~20 lines
to `_first`, and this gives them back with interest.

WHAT THIS CHANGES BEYOND m134. m134 still keeps I76's guard -- a repair-opened
way competes only at an ending the evidence reaches by repairing or not at all.
Dropping it lets a witnessed repair-opened way compete even where the evidence
arrives FREE. That is a real widening and the reason both variants are measured:
under `cost - net` a free way at that ending scores `-net_e` and the repaired one
`c - net_r`, so the repair wins only by explaining more than it costs, which is
the trade the key exists to price.

  m135  m134 (I76 + I77 as cost - net + I78) with the split deleted
  m136  m132 (I76 + I78, cost as the first key) with the split deleted -- the
        control that says whether I77 is carrying the collapse or I78 is
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



# ------------------------------------------------------- 1. drop `_admit`
ADMIT_HEAD = "/// I76: ASK I43'S QUESTION AT THE ENDING, NOT AT THE ALTERNATIVE."
ADMIT_TAIL = '''  return out;
}

'''

# ------------------------------------------------ 2. one list, one condition
OLD_DECL = '    _Way? out, opened;'
NEW_DECL = '    _Way? out;'

OLD_FAST = '''          // I76: the fast path survives only while there is nothing to weigh
          // this against -- with repair-opened ways in hand, the endings they
          // reach have to be compared before the choice is answered.
          if (out == null && opened == null) return _wrap(f, pos, w);
          for (_Way? e = w; e != null; e = e.next) {
            out = _put(out, _cons(e, null));
          }
          return _wrap(f, pos, _admit(out, opened));'''
NEW_FAST = '''          if (out == null) return _wrap(f, pos, w);
          for (_Way? e = w; e != null; e = e.next) {
            out = _put(out, _cons(e, null));
          }
          return _wrap(f, pos, out);'''

OLD_SPLIT = '''      for (var e = _clause(a, pos); e != null; e = e.next) {
        if (!e.synth) {
          out = _put(out, _cons(e, null));
        } else {
          opened = _put(opened, _cons(e, null));
        }
      }'''
NEW_SPLIT = r'''      for (var e = _clause(a, pos); e != null; e = e.next) {
        // I78: INVENTION MAY COMPLETE A SHAPE THE INPUT WITNESSES; IT MAY NOT
        // CONJURE ONE THE INPUT DOES NOT WITNESS AT ALL.
        //
        // `net` counts real input characters matched by a terminal that
        // constrains what it accepts, and a fill contributes none, so
        // `synth && net == 0` is exactly "this reading opens with invention and
        // explains nothing". Filling a `{` whose `}` is real, in front of real
        // keys and values, is completing a witnessed shape. Filling BOTH quotes
        // of a String and reading eleven structured characters through `[^"\\]`
        // conjures one nothing witnesses -- strip the invented quotes and no
        // evidence of a String remains.
        //
        // This is what I43 meant by "a repair may not make the choice". I43
        // tested where a way OPENS, a one-character proxy that was wrong in both
        // directions: it refused the brace, whose partner is real, and admitted
        // the swallow, whose delimiters are both invented. Aim the rule at the
        // evidence instead and I43, I53 and the two-list split all go with it --
        // every witnessed reading simply competes under the key vector, which is
        // where a comparison belongs.
        if (e.synth && e.net == 0) continue;
        out = _put(out, _cons(e, null));
      }'''

OLD_TAIL = '    return _wrap(f, pos, _admit(out, opened));'
NEW_TAIL = '    return _wrap(f, pos, out);'

# ------------------------------- 3. the doc comments that describe the deleted
# machinery. I43's prohibition and I53's two-list weakening are both gone, so
# leaving their text in place would describe an engine that no longer exists.
OLD_DOC = r'''  /// I43: A REPAIR MAY NOT MAKE THE CHOICE. I36 says synthesis must not choose
  /// the TEXT; this says it must not choose the SHAPE either. A way that OPENS
  /// with a FILL was selected by text that is not there, so here -- and only here,
  /// because this is the only construct in PEG that decides between shapes -- it
  /// is refused. Synthesis may still COMPLETE an alternative the evidence has
  /// already committed to, which is every case that matters:
  ///     `[2,33true]`   fill the `,`; the list was already a list      ALLOWED
  ///     `{"a":1`       fill the `}`; the object was already an object ALLOWED
  ///     `{"e":ull}`    fill a `"` to make `ull` a String              REFUSED
  ///     `{"a"1:...}`   fill a `\` to make the `"` escape content      REFUSED
  ///
  /// Measured, the last two were the battery's largest failure buckets: the `\`
  /// alone is 172 of 519 mutants, because one invented character costs 1 and buys
  /// the reclassification of a real delimiter into string content. No cost model
  /// prices that correctly -- I tried, and the character it captures is matched by
  /// a PRECISE terminal, so there is nothing to charge for. It is not a pricing
  /// error, it is a category error, and the fix is a prohibition.'''

NEW_DOC = r'''  /// I78: INVENTION MAY COMPLETE A SHAPE THE INPUT WITNESSES; IT MAY NOT CONJURE
  /// ONE THE INPUT DOES NOT WITNESS AT ALL. I36 says synthesis must not choose
  /// the TEXT; this says it must not choose the SHAPE either, and says it about
  /// the whole reading rather than its first character:
  ///     `[2,33true]`   fill the `,`; the list was already a list      ALLOWED
  ///     `{"a":1`       fill the `}`; the object was already an object ALLOWED
  ///     `"a":1,...}`   fill the `{`; the `}` and every key are real   ALLOWED
  ///     `{"e":ull}`    fill a `"` to make `ull` a String              REFUSED
  ///     `[1,[2,[3,[4`  fill BOTH quotes and call it one String        REFUSED
  ///
  /// This replaces I43, which asked whether a way OPENED with a repair. That was
  /// a one-character proxy for the question, and it was wrong in both directions.
  /// It refused the filled `{` -- whose partner `}` is real and whose contents
  /// are real keys and values -- and so answered a deleted brace by reading the
  /// whole document as one String held together by ten filled `\` escapes, cost
  /// 11 where the brace costs 1. And it ADMITTED the swallow wherever the
  /// swallow happened to open on a real character, which is how `[1,[2,[3,[4`
  /// became the String "[1,[2,[3,[4" for two invented quotes, beating four
  /// honest brackets.
  ///
  /// The measure was already here. [_Way.net] counts real input characters
  /// matched by a terminal THAT CONSTRAINS WHAT IT ACCEPTS, and a fill
  /// contributes `got: 0, net: 0`, so `synth && net == 0` is exactly "opens with
  /// invention and explains nothing". Strip the invented quotes from the swallow
  /// and no evidence of a String remains; strip the invented `{` and an object
  /// plainly remains. Aimed at the evidence instead of at the opening, the rule
  /// also absorbs I53 -- a reading whose alternatives all fail on the evidence
  /// is admitted iff something real still witnesses it -- so the prohibition,
  /// its exception and the two-list split it needed all go together.'''

# I53's whole block goes: its case -- every alternative failing on the evidence
# -- is now decided by the same test as every other, and correctly, because the
# way for `Assign <- Name '=' Expr` with a FILLED Name still carries the real `=`
# and the real expression, so it is witnessed and admitted.
OLD_I53 = '    // I53: A REPAIR MAY MAKE THE CHOICE ONLY WHEN NOTHING ELSE CAN.'
OLD_I53_END = '''    // I43: wherever I43 admitted anything at all, its answer is unchanged.
'''

BASE = {'m135': 'm134', 'm136': 'm132'}
HEAD = {
    'm135': '// m135.dart -- I78 standing alone: one list, one condition. I43, I53, `_admit`\n'
            '// and the two-list split are deleted. Generated by mk135.py from m134.dart.\n',
    'm136': '// m136.dart -- I78 standing alone WITHOUT I77, the attribution control.\n'
            '// Generated by mk135.py from m132.dart.\n',
}

for name in (sys.argv[1:] or ['m135', 'm136']):
    base = BASE[name]
    src = open(D + base + '.dart', encoding='utf-8').read()
    assert src.startswith('// ' + base + '.dart --')
    src = HEAD[name] + src[_body(src):]

    i = src.index(ADMIT_HEAD)
    j = src.index(ADMIT_TAIL, i) + len(ADMIT_TAIL)
    src = src[:i] + src[j:]

    i = src.index(OLD_I53)
    j = src.index(OLD_I53_END, i) + len(OLD_I53_END)
    src = src[:i] + src[j:]

    for old, new in [(OLD_DOC, NEW_DOC), (OLD_DECL, NEW_DECL),
                     (OLD_FAST, NEW_FAST), (OLD_SPLIT, NEW_SPLIT),
                     (OLD_TAIL, NEW_TAIL)]:
        assert src.count(old) == 1, (name, old[:40])
        src = src.replace(old, new)

    # The header names what was deleted, so check the CODE only.
    body = src[_body(src):]
    assert '_admit' not in body and 'opened' not in body, name
    open(D + name + '.dart', 'w', encoding='utf-8').write(src)
    print('wrote', D + name + '.dart')
