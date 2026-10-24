# Workstream 53 close review

**Mode:** Type 1 close review  
**Product baseline:** `0ffaaa0f`  
**Reviewed head:** `c8401ecc`  
**Verdict:** CHANGES_REQUIRED

The cost and memory observations are internally coherent, but the record does
not satisfy its own preregistration and native equality oracle. The defects
are in evidence acquisition and checking, not in product code.

## Blocking findings

1. **The measurement was not durably preregistered before execution.** Commit
   `bf1e6f12`, which first records the concrete plan, is timestamped
   `2026-10-24T02:24:30Z`. Fourteen of the 24 repeated one- and two-worker
   arms in `steps.csv` started earlier, from `02:09:13Z` through `02:23:35Z`.
   The acquisition code was not frozen either. `profile_h1_current.R` changes
   by 57 additions and 13 deletions between `bf1e6f12` and `c8401ecc`, and
   the committed evidence contains fields produced only by the later code.
   The worker acquisition scripts and checker are first added by
   `c8401ecc`, after the measurements they describe. There is no committed
   acquisition runner for the 24 `attrib_*` arms. Commit the final plan,
   acquisition programs and checker first, then rerun every affected arm.
   Otherwise label the current numbers descriptive and do not claim the
   LDG-3095/LDG-3096 preregistration acceptance items.

2. **The repeated-arm record does not retain the preregistered native
   equality oracle.** The plan requires status, pulse/fill/trade counts,
   final equity and stable fills/equity/trades hashes for runs, and candidate
   status, final equity and execution seed for sweeps. Each repeated run file
   retains only `fill_rows`, final equity and two phase clocks. Each repeated
   sweep file retains only candidate count and final equity. In particular,
   the two-worker records cannot establish seed equality with the retained
   four- and eight-worker rows. `check_ws53.R` consequently checks only 8,798
   fill rows or two completed candidates and grouped final-equity text. The
   rerun must retain and check the complete registered oracle from the native
   result APIs; a research-side reconstruction is not a substitute.

3. **The checker does not bind raw samples to the reported summaries.** It
   trusts `steps.csv`, `worker_scaling.csv`, `arm_summary.csv` and the phase
   summaries independently. In a temporary copy I changed one raw private
   byte value to `999999999999`, changed an arm elapsed median to `999999`,
   and changed a phase tree peak to `999999`; the checker still printed
   `WS53_CHECK_OK`. The unmodified raw rows are coherent: independently
   recomputed repeated-arm peaks differ from `steps.csv` by at most 0.048 MiB
   (rounding), and worker parent/tree peaks and daemon counts match exactly
   after applying the recorded R-process filter. Make the checker recompute
   or compare those rows and add a small corruption witness. Its declared
   canonical-JSON, scheduler and 12 GiB gates are failure-sensitive: focused
   mutations of each gate failed as expected.

## Results that hold

- `0ffaaa0f..c8401ecc` changes evidence, benchmark and governance material;
  it changes no file under `R/` or `src/`.
- `summarize_ws53.R` regenerates all four committed summaries byte-for-byte,
  and the unmodified checker prints `WS53_CHECK_OK`.
- The public-path profile is 60.39 seconds. Its 9.69 + 49.21 + 0.06 second
  phases total 58.96 seconds (97.63%), leaving 1.43 seconds (2.37%). The
  closeout correctly says that Windows `Rprof()` accumulated only 19.36
  sampleable R seconds and does not claim coverage of native or waiting time.
  Individually timed public reads are each below 3% of profile wall, and
  reopen is 0.03 seconds.
- The canonical-JSON total is 1.65 seconds, 2.73% of wall, below the 5% gate.
  The held-pulse context/strategy/target lower bound is 14.27 seconds,
  22.93% of the 62.22-second diagnostic wall, over 6,868 holds and 345
  decisions. Returning scheduler semantics to the RFC as Type 2 while
  preserving non-decision fill, settlement, valuation, state, diagnostic and
  commit work is the correct disposition. Macro-plan WS6, WS7 and WS8 and the
  RFC row do not authorize a scheduler or telemetry product change here.
- Keeping telemetry unchanged is supported by the source inventory: detailed
  session telemetry has diagnostic/benchmark consumers, while the compact
  durable row feeds the public run-information and continuity paths. A future
  semantic redesign remains a Type 2 matter.
- The one-worker medians are 61.97/56.66 seconds for v003 and 73.34/68.53
  seconds for v004 under `load_all()`/installed mode. The corresponding
  two-worker medians are 60.55/57.80 and 66.81/61.85 seconds. Recomputed
  engine-phase private-memory deltas are 40.164 and 457.477 MiB for one
  worker, and 397.512 and 240.117 MiB for two workers. These support the
  narrow attribution to engine-resident dividend data rather than setup, but
  remain descriptive until finding 1 is corrected.
- The singleton four- and eight-worker rows are 6,085.422 and 8,948.727 MiB
  parent-plus-daemon private memory, with effective intervals 0.20326 and
  0.20346 seconds and exactly four and eight R daemons. The eight-worker peak
  is 8.739 GiB, below the 12 GiB trigger. Both retained v004 rows have the
  same two final equities and execution seeds. Serialized staged payload is
  476,486,520 bytes for v003 and 494,658,440 bytes for v004, a difference of
  18,171,920 bytes; 18,171,576 bytes of that difference is the retained
  corporate-action row payload.
- The evidence directory currently contains 98 files, 376,837 bytes
  (0.359 MiB), not 94 files as the closeout says. The 27 compressed sample
  files expose only epoch/process/memory sampling columns. Text evidence has
  no local drive path, and no instrument, ticker, vendor or customer column
  is present. The historical statement that 12.49 GiB of disposable stores
  was deleted is not independently recoverable, but the committed boundary
  is appropriately small and no private workload was opened for this review.
- `tickets.yml` parses, `git diff --check 0ffaaa0f..c8401ecc` is clean, and
  the worktree was clean before this review artifact. The dangling sentence
  after the cleanup paragraph in `residual_cost_memory_closeout.md` should be
  removed while correcting the record.

A focused Type 1 re-review should verify the durable ordering, complete
native oracle, raw-to-summary checker witnesses and corrected file count. The
scheduler result itself appropriately remains routed to later Type 2 design.
