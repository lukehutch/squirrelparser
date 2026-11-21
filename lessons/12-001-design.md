<!-- Part of LESSONS_LEARNED.md, section: 12. Rounds 62-63: z10, z9's search checked by f25's interpreter (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 12.1 Design

`_z10.dart` runs z9's search (`_recover`, round 60), turns its tree into an edit list, and
has `_f25k.dart` parse the edited string and build the tree from that parse. A deletion is a
`SyntaxError` with `len > 0`; a substitution is a deletion recorded in `_subOf`, the map from
the substitution's way to the literal it substitutes; an insertion is
`Match(c, pos, 0, [SyntaxError len 0])`, with a negative placeholder for a character of a
`CharSet` or `AnyChar` (D7). If the edited string does not parse, z10 runs f25's own search.
If f25's recursive interpreter overflows the stack, z10 returns z9's tree unchecked.

`_f25k.dart` is `_f25.dart` (f25) with `recover`'s setup moved to `begin`, a new
`check(input, edits)`, and one fix (12.3).

D1 holds on the checked path in the sense of the memo ruling: `check` is the only parse of the
repaired string, and its tree is the answer; z9's tree is used only for its edit list. The
fallback path is f25, which already searches over repaired strings and breaks D1 the same way
f25 does.
