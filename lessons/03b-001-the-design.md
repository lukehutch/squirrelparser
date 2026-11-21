<!-- Part of LESSONS_LEARNED.md, section: e-series: repair as a search over repaired strings (2026-10-24) -->
[Back to the index](../LESSONS_LEARNED.md)

### The design

A search state is a list of edits (delete, insert or substitute one
character) applied to the input. Each state is parsed. If the parse
fails, its children each add one edit, placed at or after the state's
last edit and no later than the last position its parse examined: an
edit further right cannot change what the parse saw. The characters
worth inserting or substituting at a position are found by one parse
with an unknown character there; only characters the parse compared
against can change the result. States are expanded cost level by cost
level. Characters appended at the end of the input count once in total,
so a level is split by how many characters it appends at the end and
stops at the first count that succeeds. Equal-cost results are ranked
by matched literal text, then by how much real input the named
constructs around the edits keep (the enclosure tie-break), then by
later edits, then insert before substitute before delete.

Because each answer is the parse of a string, its tree is a valid PEG
parse of the repaired input. This is the property the pd and u lines
got from PEG derivatives.
