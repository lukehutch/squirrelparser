#!/usr/bin/env python3
r"""m129/m130/m131 = I77: an unexplained character costs what a deleted one costs.

WHAT I76 EXPOSED. m127 (I76) asks I43's evidence question at each ENDING instead
of once per alternative, and on a JSON document with its opening `{` deleted that
turns a cost-11 answer -- the whole document read as one String held together by
ten filled `\` escapes -- into the right one, `FILL@0 "{"`, cost 1. Six of ten
categories improved and the battery got 2.15x faster.

But `truncate` fell, and the worst case says why. On `[1,[2,[3,[4`:

    m126  cost=4  FILL@11 "]" x4                    <- right
    m127  cost=2  FILL@0 "\""  FILL@11 "\""         <- reads it as "[1,[2,[3,[4"

That is the SAME swallow, entering from the other side. I76 let the repair-opened
way compete at the ending, and here the repair-opened way is the swallow: two
invented quotes buy eleven structured characters, beating four honest brackets.
Cost cannot separate the good case from the bad one, because the repair-opened
way is cheaper in BOTH. What separates them is the swallow itself, and I43's
"opens with a repair" was only ever a proxy for it -- a bad proxy in both
directions, which is why it refused the right answer in one case and admits the
wrong one in the other.

I77. The engine already carries the swallow measure. `net` (I44) counts
characters matched by a terminal THAT CONSTRAINS WHAT IT ACCEPTS, so the eleven
characters a String swallows through `[^"\\]` contribute nothing to it. It is
merely outranked: `net` is the second key and its own comment concedes it only
works "at equal cost", and here the costs are 2 and 4.

So stop treating them as two keys. I33 said it outright and the m79+ line lost
it when cost became a plain character count: absorbing a character into a JSON
string costs what deleting it costs. A reading's claim on the input is the
characters it REPAIRED plus the characters it consumed WITHOUT EXPLAINING:

    key = cost + (got - net)

`got - net` is exactly "matched, but by a terminal that accepts nearly anything",
which is unexplained input wearing a parse node. Both cases fall out:

    [1,[2,[3,[4   honest  4 + 0  = 4     swallow  2 + 11 = 13   honest wins
    "a":1,...}    brace   1 + ~7 = ~8    swallow 11 + 45 = 56   brace  wins

WHY THIS IS SAFE WHERE FOLDING IT INTO `cost` IS NOT. Cost must stay a count of
DAMAGE: `cost == 0` is what "pure PEG matched this" means, it is what the budget
prunes on and what `_pure`/`_free` test, and a perfectly good JSON string has
unexplained contents. So the sum is used only where two readings are COMPARED --
in `_better` -- and never as cost. `_put`'s budget test, the deepening ladder and
round 0 are untouched, so round 0 remains exactly the frozen parser.

Prefix-optimal, so pruning stays exact: `_extend` adds `cost`, `got` and `net`
componentwise, so their signed sum is additive too, and a smaller sum stays
smaller under any common extension.

VARIANTS, because the arithmetic has two defensible forms and one attribution
control:

  m129  m127 + key = cost + got - net   (repairs plus unexplained: the honest form)
  m130  m127 + key = cost - net         (drops `got`; a skipped character then
                                         counts once as cost rather than also
                                         being absent from `got`)
  m131  m126 + key = cost + got - net   (I77 WITHOUT I76 -- the control. It should
                                         NOT fix the deleted-brace case, because
                                         there I43's early return discards the
                                         brace reading before any comparison
                                         happens: I76 makes the comparison occur,
                                         I77 makes it come out right.)
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



OLD = '''bool _better(int cost, int net, int got, int blind, int site, int doubt,
        int echo, _Way? b) =>
    b == null ||
    cost < b.cost ||
    (cost == b.cost &&
        (net > b.net ||'''

NEW = r'''/// I77: AN UNEXPLAINED CHARACTER COSTS WHAT A DELETED ONE COSTS.
///
/// The first key is not [_Way.cost] but `cost + (got - net)` -- the characters a
/// reading REPAIRED plus the characters it consumed WITHOUT EXPLAINING. `net`
/// counts what a constraining terminal matched, so `got - net` is exactly the
/// input a wide class such as `[^"\\]` swallowed while wearing a parse node.
///
/// I44 already knew this was the swallow measure, but ranked it BELOW cost,
/// where it can only break ties -- and a swallow does not tie, it wins. Two
/// invented quotes read `[1,[2,[3,[4` as one String for cost 2, beating the four
/// honest brackets at cost 4; ten invented backslashes read a whole object as
/// one String. Both lose here, 13 to 4 and 56 to 8.
///
/// This is I33 restored: absorbing a character into a JSON string costs what
/// deleting it costs. It is a COMPARISON key only, never a cost -- `cost == 0`
/// still means "pure PEG matched this", which is what the budget prunes on and
/// what makes round 0 the frozen parser, and a perfectly good string has
/// unexplained contents. Additive in all three components, so prefix-optimal,
/// so pruning stays exact.
bool _better(int cost, int net, int got, int blind, int site, int doubt,
        int echo, _Way? b) =>
    b == null ||
    KEY < BKEY ||
    (KEY == BKEY &&
        (net > b.net ||'''

VARIANTS = {
    'm129': ('m127', 'cost + got - net', 'b.cost + b.got - b.net',
             '// m129.dart -- I77: the first key is repairs PLUS unexplained characters, so a\n'
             '// String that swallows structure loses to the reading that explains it.\n'
             '// Generated by mk129.py from m127.dart.\n'),
    'm130': ('m127', 'cost - net', 'b.cost - b.net',
             '// m130.dart -- I77 without `got`: key = cost - net.\n'
             '// Generated by mk129.py from m127.dart.\n'),
    'm131': ('m126', 'cost + got - net', 'b.cost + b.got - b.net',
             '// m131.dart -- I77 WITHOUT I76, the attribution control.\n'
             '// Generated by mk129.py from m126.dart.\n'),
}

for name in (sys.argv[1:] or ['m129', 'm130', 'm131']):
    base, key, bkey, head = VARIANTS[name]
    src = open(D + base + '.dart', encoding='utf-8').read()
    assert src.startswith('// ' + base + '.dart --')
    src = head + src[_body(src):]
    assert src.count(OLD) == 1, name
    src = src.replace(OLD, NEW.replace('BKEY', bkey).replace('KEY', key))
    open(D + name + '.dart', 'w', encoding='utf-8').write(src)
    print('wrote', D + name + '.dart')
