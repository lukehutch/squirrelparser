# Error Recovery Fix Plan

## Executive Summary

The current error recovery implementation has three critical flaws that cause syntax errors to span large portions of input instead of being localized:

1. **Repetition recovery is too greedy** - scans entire input looking for next match
2. **First clause switches alternatives based on error count** - destroys parse structure
3. **Bounds are not respected during recovery** - errors cross structural boundaries

## Problem Analysis

### Current Behavior

When parsing `{"a": 1, "b": 2}` with a small error (e.g., missing quote), the parser:
1. `WS` (whitespace) tries to match at position 0
2. `[ \t\n\r]` fails (first char is `{`)
3. Repetition recovery scans for next whitespace at position 5 (space after `:`)
4. Everything from 0-5 becomes a syntax error
5. `Value` tries `Object`, which fails with errors
6. `First` tries `String`, which succeeds by finding `"b"` at position 8
7. Result: `WS + String + WS` instead of `Object`!

### Why This Violates the Paper's Constraints

From the paper:
- **Constraint 8 (Boundary Preservation)**: "Recovery at grammar level L must not consume input belonging to level L+1"
- **Constraint 9 (Non-Cascading Errors)**: "Each error has a bounded affected region"

The current implementation violates both constraints.

## Proposed Solution

### Fix 1: Constrain Repetition Recovery

**Current Code (combinators.dart line ~269):**
```dart
(int, MatchResult?)? _recover(Parser parser, int curr, bool hasRecovered) {
  for (int skip = 1; skip < parser.input.length - curr + 1; skip++) {
    final probe = parser.probe(subClause, curr + skip);
    if (!probe.isMismatch) {
      return (skip, probe);
    }
  }
  ...
}
```

**Proposed Change:**
```dart
(int, MatchResult?)? _recover(Parser parser, int curr, Clause? bound, bool hasRecovered) {
  // Only skip 1 character for recovery in repetitions
  // This prevents whitespace patterns from eating entire structures
  const maxRepetitionSkip = 1;

  for (int skip = 1; skip <= maxRepetitionSkip && curr + skip <= parser.input.length; skip++) {
    // Check bound before probing
    if (bound != null && parser.canMatchNonzeroAt(bound, curr + skip)) {
      return null; // Hit boundary, don't recover
    }

    final probe = parser.probe(subClause, curr + skip);
    if (!probe.isMismatch) {
      return (skip, probe);
    }
  }
  return null;  // Don't do aggressive skip-to-end recovery
}
```

**Rationale**: Repetitions like `WS*` should only skip 1 character to try to resync. They shouldn't scan the entire input. Higher-level clauses (like `Seq`) can handle larger-scale recovery.

### Fix 2: Don't Switch Alternatives Based on Error Count

**Current Code (combinators.dart line ~167):**
```dart
if (parser.inRecoveryPhase && i == 0 && result.totDescendantErrors > 0) {
  var bestResult = result;
  // ... tries other alternatives ...
}
```

**Proposed Change:**
```dart
// REMOVE THIS ENTIRE BLOCK
// PEG semantics require using the first matching alternative
// Switching alternatives based on errors destroys parse structure
```

**Rationale**: PEG ordered choice semantics require using the first matching alternative. If `Object` matches (even with errors), it should be used. Switching to `String` because it has fewer errors violates PEG semantics and causes structural corruption.

### Fix 3: Pass Bounds Through Repetition Recovery

**Current Repetition.match:**
```dart
final result = parser.match(subClause, curr);
// ... later ...
final recovery = _recover(parser, curr, hasRecovered);
```

**Proposed Change:**
```dart
final result = parser.match(subClause, curr, bound: bound);
// ... later ...
final recovery = _recover(parser, curr, bound, hasRecovered);
```

### Fix 4: Consider Removing Repetition Recovery Entirely

A more aggressive fix would be to remove recovery from `Repetition` entirely:

```dart
@override
MatchResult match(Parser parser, int pos, {Clause? bound}) {
  final children = <MatchResult>[];
  int curr = pos;

  while (curr <= parser.input.length) {
    // Check bound before continuing
    if (parser.inRecoveryPhase && bound != null) {
      if (parser.canMatchNonzeroAt(bound, curr)) {
        break;
      }
    }

    final result = parser.match(subClause, curr, bound: bound);
    if (result.isMismatch) {
      // NO RECOVERY IN REPETITIONS
      // Let the parent Seq handle recovery
      if (!parser.inRecoveryPhase && curr < parser.input.length) {
        incomplete = true;
      }
      break;
    }
    if (result.len == 0) break;
    children.add(result);
    curr += result.len;
  }
  ...
}
```

**Rationale**: Repetition recovery is the source of most error cascading. If repetitions just stop when they can't match, the containing `Seq` will handle recovery at a higher level, which has more context about what structure is expected.

## Alternative Approach: Structural Recovery

Instead of character-level recovery, consider structural recovery:

1. When `Object` fails to parse, don't just skip characters
2. Look for structural delimiters: `{`, `}`, `,`, `:`
3. Use these to identify where members should be
4. Only mark the content between delimiters as errors

This would require significant changes to how recovery works:
- Add a concept of "sync tokens" to the grammar
- Recovery would seek to these tokens instead of arbitrary positions
- This is similar to how traditional error-recovering parsers work

## Testing Plan

Create tests for each scenario:

1. **Simple object with error in key**: `{a": 1, "b": 2}` - should parse as Object with syntax error for `a`
2. **Simple object with error in value**: `{"a": @@@, "b": 2}` - should parse as Object with syntax error for `@@@`
3. **Missing comma**: `{"a": 1 "b": 2}` - should parse as Object with syntax error for missing comma
4. **Nested object with inner error**: `{"outer": {"inner": @@@}}` - should preserve outer structure

## Implementation Order

1. First, fix the First clause (Fix 2) - this is causing structural corruption
2. Then, constrain repetition recovery (Fix 1 or Fix 4)
3. Finally, improve bound propagation (Fix 3)
4. Verify all existing tests still pass
5. Add new tests for error localization

## Constraints From the Paper

Any fix must maintain:
- **Axiom 1 (Packrat Invariant)**: Linear time complexity
- **Axiom 2 (PEG Ordered Choice)**: First matching alternative wins
- **Axiom 3 (Monotonic Consumption)**: No backtracking past consumed input
- **Constraint 3 (Bounded Recovery)**: Each recovery consumes at least one character
- **Constraint 8 (Boundary Preservation)**: Don't cross structural boundaries
- **Constraint 9 (Non-Cascading Errors)**: Errors are localized

## Risk Assessment

- **Low Risk**: Removing the First alternative comparison (Fix 2) - this is clearly wrong
- **Medium Risk**: Constraining repetition recovery (Fix 1) - may cause some tests to fail
- **Higher Risk**: Removing repetition recovery entirely (Fix 4) - major behavior change

## Conclusion

The fundamental issue is that error recovery is too aggressive at low levels of the grammar (repetitions, terminals), when it should be more conservative there and let higher-level clauses (sequences, rules) handle recovery with more structural context.

The fix should prioritize structural preservation over maximizing the amount of input consumed with fewer errors.
