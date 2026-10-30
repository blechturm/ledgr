# LDG-3163 focused independent re-review, correction round 1

- Reviewer: Codex; clean-context independent reviewer, author of neither the tools nor round 1.
- Date: 2026-10-30.
- Mode: Type 1 against LDG-3163, cut 5 / macro WS4a and F1-F10; Type 2 limited to correction-introduced problems. Maintainer-owned brief, drafted by Claude.
- Reviewed commit: `a04f566301d685efa730c58f888d618773ec332b`, verified on `release/v0.2.3`; corrections compared with `b47068b5`, ignoring only line endings when appropriate.
- Verdict: **PASS_AFTER_PATCHES**. Apply N1's exact six-line patch; it suffices without another review. F6 remains incomplete in the reviewed commit; F1-F5 and F7-F10 are resolved. No correction-introduced design problem requires Type 2.

The 23 base cases reproduce exactly; all 11 selected guts fail with their expected evidence; all 30 detector rows reproduce exactly and all their required controls pass. The real memory records are sound, but the new integrity checks still accept five forms of missing evidence. N1 fixes that demonstrated gap without changing the metric or records. The 2,000-line limit, peak-R-heap decision and recorded timing deviations are not reopened.

Paths below: `R` = `C:/Users/maxth/Documents/GitHub/ledgr`; `W` = `R/dev/bench/v0_2_3_ws4a`; `P` = `R/dev/bench/timing/protocols/ws4a-timing-1`; `S` = `C:/Users/maxth/AppData/Local/Temp/ldg3163-rereview1`; `L` = `E:/ledgr-data/r-lib/ledgr-v0.2.3-base-953338df`. These are readability abbreviations, not shell variables; actual calls used absolute paths, plain Rscript and one simple shell command per call.

`G` below is the executed command:
```text
Rscript W/guts.R --out=S/guts --guts=M2_reorder_pulse_fills,M3_drop_lot_fee,M5_positions_plus_delta,M7_drop_partial_remainder,M11_uncompensated_totals,C14c_reuse_staging,C14c_reuse_leg_staging,C3_tolerance_x10,C6_leave_one_live_lot,C18_drop_split_tail,C5b_kahan_on_openings
```
It exited 0: eleven economic/preservation failures were caught, plus the invalid-ref child was REFUSED with status 2. The subset option avoided rewriting tracked gut records. Other registered guts were inspected through their unchanged definitions and recorded outcomes, not claimed as independently rerun here.

| Finding | Resolved? | Evidence and executed command |
| --- | --- | --- |
| F1: fail-closed product guard and selections | Yes | `W/check.R:18-35` validates names and resolves a commit before checking both Git statuses. `Rscript W/check.R --out=S/check` passed all 23 cases. Separate `Rscript W/check.R` calls with `--out=S/invalid-ref --cases=C5b --base=LDG3163_NONEXISTENT_REF`, `--out=S/unknown-gut --gut=LDG3163_UNKNOWN_GUT`, and `--out=S/empty-selection --cases=` all returned REFUSED/nonzero. `G` independently distinguished invalid-ref status 2 from gut status 1. |
| F2: detector controls and M1-M12 register | Yes | `Rscript W/detectors.R --lib=L --out=S/detectors` exited 0; 30 rows exactly match the frozen baseline, every own control TRUE. D12a runs store/config tests plus C1 hash; D20 compares named route boundaries and executes output witnesses; D10 counts writers on both producers' run/sweep. D2/D16/D18/D22/W1 remain explicitly NOT_EVALUABLE at production attachments, with tested predicates and named later owners. `G` executes all five newly missing mutations; `W/guts.R:193-199` and `records/mutations.csv` map all M1-M12 distinctly, including M3 versus M10. |
| F3: D6 routed JSON allowlist | Yes | `W/detectors.R:68-85` keys parsed shapes by owning stage and counts excess occurrences. The detector command above passes unchanged P5; rejects the new P3 call carrying `intent_reason` and a duplicate P5 state encode. D6 now records PASS. |
| F4: D7 reads counter after operation | Yes | `W/detectors.R:185-196` evaluates `op` first, then counter and compensation. The detector command catches both M6 and a discarded-result Kahan call; `G` also catches C5b's runtime-counter gut. |
| F5: deterministic D12c and executable verdict | Yes | Detector run passes; `Rscript S/detector-controls.R` runs the actual `exports` expression under C, English US UTF-8 and German Austria UTF-8: same frozen value, added export rejected. The old and new frozen token multisets match exactly. Extracted final verdict code returns 0 unchanged and 1 for unexpected outcome, FALSE control, NA control or missing detector. `W/detectors.R:158,305-308`. |
| F6: memory integrity and exit status | **Not fully; N1** | `Rscript W/memory.R --mode=summarize --lib=L --records=S/memory --scratch=S/empty-memory` passed the unmodified real records copied to scratch, reproducing validation exactly with no prepared directory. `Rscript S/memory-controls.R` rejects rep-1-only, nonlive, size-mismatch, duplicate, nonfinite, wrong-GC, wrong-replay-count and budget-miss variants (all status 1). Missing-column variants still pass; `Rscript S/patch-memory.R` demonstrates five false passes and verifies N1 rejects them. |
| F7: C14c leg-retention witness | Yes, fee deviation justified | `W/cases.R:449-472` captures the used leg prefix before copying, requires later flushes and checks two retained objects. The base check reproduces both hashes. `G`'s leg-only gut fails with exactly `changed: leg_block`, so the event witness remains equal; the event gut fails separately. Writing the leg's independent fee is a valid isolated aliasing witness because base OPEN qty aliases event qty (`R/output-handler.R:197-219`). The equivalent typed handouts remain assigned to LDG-3167. |
| F8: deferred C13b missing observations | Yes | `W/cases.R:375-383` requires list inputs and all five named fields. Equal, changed-cash and missing-field controls execute on source in `Rscript W/check.R --out=S/check` and pass. Actual typed second-row fault attachment remains future LDG-3167 work. |
| F9: retain evidence when preconditions fail | Yes | `W/lib.R:108,175` retains failure tables; normal preconditions remain. `G` catches C3 with book/equity differences and C18 with diagnostic differences alongside their precondition errors. C6 now retains FAILED status, conditions and diagnostics naming `ledgr_lot_state_invariant` and `Disposition left live lots after reaching zero position.` Its gut explicitly requires that evidence. |
| F10: timing status prose | Yes | `git -C R diff --ignore-space-at-eol b47068b5 a04f5663 -- dev/bench/v0_2_3_ws4a/cases.R dev/bench/v0_2_3_ws4a/lib.R dev/bench/timing/protocols/ws4a-timing-1/protocol.md` shows protocol status/reps reconciled to the existing smoke, explicitly not an A/A window. `Rscript W/timing_absolute.R --self-test` passes all 12 controls, including rejecting 45 us and accepting 30 us. No timing window ran. |

**N1 — blocking, residual F6: missing evidence passes the new integrity checks.**

At `W/memory.R:210-213`, `$` returns NULL for an absent column; comparisons become zero-length and `all()` returns TRUE. Removing any one of `children.csv`'s `block_live`, `gc_env`, or `replay_rows`, `control_size.csv`'s `block_bytes`, or `workloads.csv`'s `fills` makes summarize return 0 and write successful validation. This falsely certifies liveness, policy, control sizing or replay completeness without the evidence F6 requires. It is an implementation gap in the correction, not a new memory-method decision.

Reproduction: `Rscript S/memory-controls.R` creates and runs the three missing-child-column copies; `Rscript S/patch-memory.R` creates the two missing-reference-column copies and runs both reviewed and patched scripts. Scripts and value-free CSV copies remain in scratch. Each child is invoked as `Rscript <memory script> --mode=summarize --lib=L --records=<copy> --scratch=S/empty-memory`; no workload or preparation is invoked.

Exact patch: insert these six lines at `W/memory.R:203`, immediately after reading `wl` and before `grid <- merge(...)`:

```r
required <- function(x, fields) if (!all(fields %in% names(x)))
  stop("memory records REFUSED: missing columns: ", paste(setdiff(fields, names(x)), collapse = ", "))
required(all, c("shape", "op", "phase", "rep", "peak_pagefile", "gc_max_used_bytes",
  "block_bytes", "block_live", "replay_rows", "concurrent_r", "gc_env"))
required(size, c("shape", "op", "block_bytes"))
required(wl, c("shape", "fills"))
```

The exact insertion was executed in `S/memory-patched.R`: unchanged real records exit 0; all 13 corrupted variants exit 1, including all five missing-column cases. `S/memory-patch-results.csv` records the results. Existing thresholds, medians and records are unchanged. Apply only this insertion; no rerecording or further review is needed. No additional optional finding.

The reviewed inputs remain appropriate: ticket acceptance and design-note Sections 4/6/7 are checked against actual base execution, not correction prose alone. Relevant stable contract anchors are `inst/design/contracts.md#contract-execution-fold-core`, `#contract-execution-event-staging`, and `#contract-execution-walk-forward-folds`. Adding C5a's three window-equity tables makes the existing M5 numeric drift observable: all base outputs reproduce and the mutation differs; existing opening/book tables were not relaxed. C14c's fee write tests the required independent retained leg without conflating it with the shared event quantity. Neither adjustment changes execution semantics or needs Type 2.

Maintained R count (comments and blanks included): cases 557; check 62; detectors 308; guts 231; lib 192; memory 245; record 22; timing_absolute 104; protocol workloads 236. **1,957 / 2,000**, measured using `Rscript -e` with `list.files(..., '[.]R$', full.names=TRUE)` for W and P and `length(readLines(f))` per file. N1 brings it to **1,963 / 2,000**. Shared reused harness code was not copied or counted again.

Environment: Windows, R 4.6.1 (2026-06-24 ucrt), effective locale C; startup warns that inherited C.UTF-8 locale settings are unavailable. The detector locale controls explicitly set three valid collations. No timing windows, memory workloads, real-data workloads or full package suite were run. Detector store/config tests and the small registered cases did run.

After pkgload-bearing commands, `git -C R checkout -- R/cpp11.R src/cpp11.cpp` restored generated wrappers; the initial sandbox denial was resolved by the authorized escalation. No tracked records required restoration. Final `git -C R diff --exit-code 953338df -- R src tests NAMESPACE DESCRIPTION man` passes; HEAD is unchanged. Only this requested review is added to the repository; no commit and no ticket edit. Review accounting: one focused re-review invocation, one blocking Type 1 finding, zero Type 2 findings; the exact patch was verified in scratch only.
