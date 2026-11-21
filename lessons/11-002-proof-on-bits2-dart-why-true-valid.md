<!-- Part of LESSONS_LEARNED.md, section: 11. Round 60: z9 — Zero Bit-Packing Anywhere, Exact z6/z7 Battery Trees, Fastest Battery & Rungs, and Best D1 Fuzzer Validity/Costs (2026-10-25) -->
[Back to the index](../LESSONS_LEARNED.md)

### 11.2 Proof on `_bits2.dart` (Why True Valid PEG Costs Are 7 and 8)

The `z8` audit noted that on `_bits2.dart`, `c14` returned costs `1` and `2`, `z6` returned `4` and `8`, `z8` returned `6` and `2`, and `z7` returned `7` and `8`. Running `e8` and `f25` (which parse every repaired string with the library parser) on `_bits2.dart` returns **costs `7` and `8`**, identical to `z7` and `z9`:
- In `_bits2.dart` Grammar 1 (`S <- E ';'; E <- "k0" / ... / "k1" / ... / E '+' "k1";` on `"k1+k1+k1+;"`), `E` is an ordered choice (`First`) where `"k1"` appears *before* the left-recursive arm `E '+' "k1"`.
- In `squirrel_parser`, when `E` is matched at `pos = 0` on `"k1+k1+k1;"`, the non-recursive arm `"k1"` succeeds at `0..2`, so `First.match` returns `0..2` immediately without ever attempting the later arm `E '+' "k1"`. Because `foundLeftRec` is never set, the grow loop does not run, `E@0` stops at `0..2`, and `';'` fails at `pos = 2`.
- Thus `"k1+k1+k1;"` is **not** in the PEG language of Grammar 1 (nor Grammar 2); `c14`, `z6`, and `z8`'s lower costs on `_bits2.dart` are invalid trees that assume the shadowed left-recursive arm ran. The minimum valid repairs are `"k1;"` (cost 7) and `"k0;"` (cost 8), which `z9`, `z7`, `e8`, and `f25` all return.
