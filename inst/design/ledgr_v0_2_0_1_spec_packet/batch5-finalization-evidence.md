# v0.2.0.1 Batch 5 Resumed-Run Finalization Evidence

Status: Complete after independent review and maintainer acceptance.

Ticket: LDG-2727.
Implementation base: `3329cdab6ea8d6db0fb4b93271a9cf7447f485ab`.

## Repair boundary

Availability-aware interrupted invocations now commit their fold-supplied
equity rows as a validated calendar prefix while leaving the run `RUNNING`.
Terminal availability finalization uses the same production commit function.
When the final invocation does not itself cover the exact achieved prefix, it
reads the committed prior rows and merges on `(run_id, ts_utc)`.

The merge requires each input to be monotone and on the intended pulse
calendar. Identical duplicate rows collapse to one. Conflicting duplicates,
missing pulses, extra pulses, out-of-calendar pulses, and non-monotone input
raise `ledgr_run_terminal_evidence_invalid`. Prefix validation happens before
deletion. Deletion, merged append, and terminal status update then share one
DuckDB transaction, so an error preserves the committed prefix and cannot
write `DONE` or `INCOMPLETE`.

The existing full achieved-prefix validator is unchanged. Dense runs keep
their full event-replay reconstruction and do not call the prefix commit.
There is no schema, completion row, stop reason, run identity, equity formula,
or event replay change.

The interrupted-invocation write is required by the accepted merge rule: at
the Batch 5 base, an interrupted availability invocation committed state,
events, and diagnostics but no equity rows. Its terminal resume therefore had
no prior equity evidence to merge. Persisting the already computed fold facts
at the same committed invocation boundary supplies that prior prefix without
reconstructing economics or weakening terminal validation.

## Finalization matrix

- Uninterrupted availability `DONE` behavior remains green in the existing
  economics and workflow regressions.
- An availability run interrupted after its first pulse retains one equity
  row, resumes to `DONE` with all three rows, reopens, and extracts the complete
  curve through the ordinary result reader.
- The reviewed interrupted-and-resumed controlled `INCOMPLETE` scenario now
  retains all nine achieved rows. `ledgr_run_open()`, the availability result
  view, explanation, and equity extraction all succeed and agree with the
  active handle.
- The interrupted-and-resumed early-exit `DONE` scenario now retains all 12
  achieved rows.
- The dense interrupted-and-resumed case retains its existing behavior: zero
  prefix-commit calls, full five-row recomputation at terminal finalization,
  successful reopen, and successful result extraction.
- A resume-then-unexpected-error case retains its five committed prefix rows
  exactly and remains `FAILED`; the failed invocation does not replace them.
- Identical overlap, including an identical duplicate within the current
  invocation, collapses to one row and yields the exact prefix.
- Conflicting overlap, missing, extra, non-monotone, and out-of-calendar rows
  all fail with the terminal-evidence condition.
- An atomic conflict test proves the prior equity rows and `RUNNING` status are
  unchanged and the terminal-status callback is not reached.

## Batch 4 review carry-forwards

All three non-blocking Batch 4 observations are closed in this batch's
preflight:

- the unused `pulses_posix` writer parameter and call-site argument are gone;
- the installed-package retirement guard deparses the namespace and rejects
  retired spike tokens even when raw `R/` sources are unavailable; and
- the production diagnostic row and typed-column constructors have their name
  vectors pinned directly to one another.

The retired provider and writer spike runners remain historical evidence and
were not rerun.

## Verification

- focused finalization matrix, economics, fold-witness, and provider-consumer
  files: passed in 100.6 seconds;
- dense runner, v0.1.0 acceptance, derived-state, run-store, and public-API
  files: passed in 67.7 seconds; and
- all 18 `test-availability*.R` files: passed in 237.8 seconds with zero
  failures, errors, warnings, or skips;
- the complete source-tree suite: passed in 961.4 seconds with one expected
  skip for an unavailable-package path whose package was installed;
- the source package and all vignettes built in 405.9 seconds with only the
  existing long-path portability warnings; and
- `R CMD check --no-manual --no-build-vignettes`: passed under R 4.6.1 in
  1,218.7 seconds with zero errors, zero warnings, and the existing long-path
  NOTE.

Independent review and maintainer acceptance remain outstanding.
