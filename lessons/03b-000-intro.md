<!-- Part of LESSONS_LEARNED.md, section: e-series: repair as a search over repaired strings (2026-10-24) -->
[Back to the index](../LESSONS_LEARNED.md)

## e-series: repair as a search over repaired strings (2026-10-24)

**Status: research line, not promoted.** The e engines break D1 by
design: every candidate is a full PEG parse of a repaired string, and
the final tree comes from one more parse of the chosen string with the
library parser. They also keep a fixed cap of 400,000 parses per input
(D2), and they fail gate b2 (`[,2,33,true]` should delete the comma;
the second D8 reading). They are recorded because they answer one
question the other lines could not: how good can repairs be when every
answer is a real parse? Engines and the harness are in the kit
(`squirrel-kit/dart/experiments/recovery/e1.dart` ... `e14.dart`);
`_e7s.dart` and `_e14.dart` are copied into this repository.
