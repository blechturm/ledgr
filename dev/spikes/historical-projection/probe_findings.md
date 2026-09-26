# Historical projection: existing-code reproduction

**2026-09-26 / ChatGPT, seed author.** Not an independent review.
**Question:** Do F1/F2 reproduce at `ae040e762e082dd9f347ae7bc1c1aa13be9fc6ce`?

`probe.R` sources unchanged production functions and runs `ledgr_execute_fold()`
with its memory output handler. Synthetic three-instrument, twelve-pulse flat
fixtures use `sma_3`: ordinary computation/fast context for dense; strict
computation/production portable provider/non-fast context for availability.
Both complete twelve callbacks with `DONE`. This is a source-level fold test over
normalized inputs, not sealed ingestion, public `ledgr_run()`, changing-membership
semantics, or a memory benchmark. Values are computed from bars, not narrated rows.

| First callback observation | Dense | Availability |
| --- | --- | --- |
| `feature_values$sma_3` shape / pulse-index length | 3 x 12 / 12 | same |
| Public current plane | NA, NA, NA | same |
| Direct column 12 via `ctx$.feature_projection` | 111, 211, 311 | same |
| Projection removed before fold entry | `ledgr_invalid_execution_spec` | same |

At callback 12 the public plane matches the earlier future read. Null-projection
rejection occurs in spec validation, before the fold's additional guard; its
condition also inherits `ledgr_invalid_fold_execution`. A pure target-returning
strategy containing that future read passes preflight as Tier 1, allowed TRUE.
The mutable observer wrapper is instrumentation, not an admitted public strategy.

**Outcome: both findings reproduce.** Direct future access violates decision-time-
only contexts (`contracts.md:113-116,736-742`). It spans the prepared horizon,
not arbitrary future dates. This does not establish history-API feasibility.

From the design repository root, with R, rlang, digest and yyjsonr:

```sh
Rscript dev/spikes/historical-projection/probe.R IMPLEMENTATION_REPO OUT
python dev/spikes/historical-projection/check.py IMPLEMENTATION_REPO --rscript Rscript
```

Executed: R 4.5.2, rlang 1.1.3, digest 0.6.39, yyjsonr 0.1.22. The checker
reproduces the CSV and guards package/design scope. Removing the raw attachment
in both helper paths in a local source copy changes shape/future-access evidence;
current planes, completion and null-projection rejection are unchanged. This gut
is a detector demonstration, not a repair: accessor closures retain projection state.

**Inventory:** No production paths deleted. Demoted: the unresolved numerical-
backing question and any inference of ragged-history or memory suitability.
Learned: both modes share full prepared backing; direct future access escapes
preflight. Open: original-cutoff semantic evidence, callback authority, inspection
compatibility and allocation cost. Seed v2 proposes one semantic checkpoint before
synthesis. No comparative spike is chartered.
