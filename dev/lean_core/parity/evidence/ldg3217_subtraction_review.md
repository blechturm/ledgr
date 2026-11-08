FINDINGS

LDG-3217 A4 subtraction review of `dev/lean_core/prepare.R`, lines 17-156,
at `b665b405239d56715388ce243ea98f0c25eed358`; executable oracle: installed
`d5b3a151`. Four internal subtractions follow. They preserve the external
entry checks and the pinned constructor's refusal sites and ordering.
No worktree files were edited.

1. **Remove repeated normalization and the second time-axis encoding.**
   Lines **58, 70, 79-80, 93**. Remove the `as.POSIXct(axis, ...)` assignment,
   `axis_num`, `as.character(rows$instrument_id)`, and
   `as.numeric(rows[[f]][keep])`. Match the timestamp vectors directly:
   `c <- collapse::fmatch(rows$ts_utc, axis[c0:c1])`.

   The pinned fetch already returns character instrument IDs and UTC
   POSIXct timestamps (`R/precompute-features.R:477-509`); both axis producers
   explicitly return UTC POSIXct (`prepare.R:48` and
   `R/availability-provider.R:389-423`). The current schema supplies all five
   OHLCV columns as DOUBLE (`R/db-schema-current.R:33-37`). Thus the field
   coercion does not establish a new type. Direct POSIXct matching compares
   the same epoch values while eliminating the separate full `axis_num`
   vector and the per-chunk timestamp conversions. Neither coercion nor
   the extra representation owns a contracted refusal on these trusted
   inputs. The combined subtraction passed the captured comparisons and
   the focused hydration cases below, including missing observations,
   off-session rows, duplicate rows, and chunk edges. This is subtraction
   of repeated work under style shape 5, rather than a per-row parsing loop.

2. **Merge the query universe and the matrix instrument axis.**
   Lines **56-59, 79, 110**. Remove the separate `instrument_ids` argument
   and its `as.character()` assignment; use `universe` for `n` and the
   row-position match. The sole preparation caller passes `universe` twice
   in the same call at line 110. Experiment construction already requires
   a nonempty character universe (`R/experiment.R:483-503`). This is one
   ordered axis with two parameter roles, not an actual supported remapping.
   No sorting, deduplication, new check, or refusal relocation is needed.
   The pinned substrate identity validation still runs unchanged.

3. **Remove the guaranteed instrument-membership half of the row filter.**
   Line **81**: replace `keep <- !is.na(r) & !is.na(c)` with
   `keep <- !is.na(c)`. This depends on the shared universe established
   above: the pinned SQL query uses `instrument_id IN (universe)` and the
   row match uses that same character vector. Every fetched instrument
   therefore has a position. Computing `!is.na(r)` and combining it with
   the session mask repeats an already established property over every
   fetched bar. Retain the column mask, line 82's empty-selection shortcut,
   and the indexing by `keep`: valid sealed off-session bars can have no
   declared-session position (`contracts.md#contract-snapshot-off-session-bars`).
   A synthetic whole-second off-session row, including a chunk containing
   only that row, produced identical planes and refusals against the pin.

4. **Move the internal carrier class assertion to debug.**
   Line **148**: prefix the existing condition with `.lean_debug &&`, or
   remove the assertion entirely. `lean_hydrate()` constructs the
   `lean_bars` carrier at lines 98-99 and passes it through
   `lean_prepare_bars()` and the pinned constructor to this adapter. There
   is no external carrier input on this path. The assertion consequently
   cannot fire without an internal construction defect; its custom
   `simpleError` is absent from the pin's refusal contract. Keeping it under
   `.lean_debug` follows interface Section 13's internal-handoff rule.
   Keep lines 149-152 in production: duplicate refusal is explicitly
   required by W2 and must remain at the pinned constructor's site, after
   its identity, fact-knowledge, policy and segment checks.

All four changes were applied only to in-memory function copies by
[subtractions.R](subtractions.R). Evidence:

- Original and subtracted preparation each passed all 13 fixture checks,
  1,926 comparisons per run, at chunk 8/debug off and chunk 12/debug on:
  [baseline8.csv](baseline8.csv), [baseline12.csv](baseline12.csv),
  [subtracted8.csv](subtracted8.csv), [subtracted12.csv](subtracted12.csv).
  These include full downstream reads and duplicate condition class/message.
- [focused_probe.csv](focused_probe.csv): 180/180 checks. This includes
  64 hydration comparisons against both the unmodified lean implementation
  and pinned matrix builder, and 112 entry comparisons against the pin,
  across both clock kinds, debug settings, and chunk widths 1, 8, 12, 1000.
  Entry cases include empty bars, inadequate calendars, duplicates, and
  simultaneous identity/duplicate and missing-knowledge/duplicate defects.
  Conditions compare the full class vector and message; successful substrates
  exclude only the newly allocated memo/projection fields, as in the runner.
  Synthetic changes are probe-local; the fixture and snapshot are unchanged.

Reproduce the focused probe with one PowerShell command:

```powershell
& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" C:/Users/maxth/ledgr-wt/ldg3217-subtraction-out/focused_probe.R
```

[variant_parity.R](variant_parity.R) runs the existing fixture runner with
the same in-memory subtractions; use its normal `--lib`, `--capture`,
`--chunk`, `--debug`, and `--out` arguments. Only the supplied small fixture
was loaded; no larger captures were run. These are correctness comparisons,
not timing evidence.

No additional per-bar R iteration was found. Line **71** iterates over
session chunks as W2 requires, using vectorized matches and indexed block
writes. Lines **66 and 90** iterate over exactly five fields, independently
of bar/session counts. There is no R loop over individual bar rows or a
session scan per row. The environment bindings are cleared before block
replacement, so the extract/write/replace pattern here is not by itself
evidence of style shape 7's repeated shared-buffer copying.

Retain the early empty-range query/refusal (lines 35-48, 108): moving it
after calendar preparation would change refusal precedence. Retain the
empty-chunk coverage handler (75-77), which permits sparse declared-session
chunks. Retain the duplicate flag/refusal and the external experiment and
snapshot checks. No further helper duplication or removable plane
representation was established within this review's scope.
