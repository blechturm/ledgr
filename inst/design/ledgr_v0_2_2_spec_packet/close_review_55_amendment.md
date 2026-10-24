# Workstream 55 amendment close review

Mode: independent Type 1 close review of LDG-3105 at `229a7cf3`.

Verdict: **CHANGES_REQUIRED**.

## Findings

1. **High: excluded ordinary bar reads rebuilt diagnostic evidence.** The
   compact path called `ledgr_history_bar_evidence()` for excluded instruments,
   which prepared a whole-history field-position plane such as `base_close`.
   That violated the accepted ordinary-versus-diagnostic boundary and made a
   first excluded read scale with source history rather than the request.
2. **Medium: the binding clock hid first-read preparation.** The benchmark
   called each public read before allocation and timing, so it did not measure
   the first supported read or prove where immutable owner preparation ended.
3. **Medium: the source-range detector observed only R arguments.** It proved
   that the wrapper passed bounded row and column vectors but could not detect
   a direct out-of-range source-value access added inside the compiled loop.

No Type 2 decision was required. The accepted repair direction was to keep
ordinary reads off diagnostic evidence, make any immutable preparation
explicit at the context-owner boundary, remove public-read warm-ups from the
record and observe every compiled source-value access in a test-only trace.

## Verified clean

- matrix, wide and explicit-long values, selection and dependency disclosures
  agreed on the exercised bar and feature cases;
- complete ordinary reads remained below the accepted absolute timing gate;
- ordinary results retained no cell evidence or transient value seal;
- the direct sibling shape, output allocation and mutation isolation held; and
- focused semantic suites and the registered record checker passed.
