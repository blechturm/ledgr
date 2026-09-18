# Availability Hot-Path Representation - Response

**Status:** Response v1; adversarial review of Seed v1. Non-binding.
**Author:** Claude (response stage; Seed v1 author was Codex).
**Reviewed artifact:** `rfc_availability_hot_path_representation_v0_2_0_x_seed.md`.

## Reviewed source state

| Item | Value |
| --- | --- |
| Branch | `v0.2.0.1` |
| HEAD | `cb3047b8b45c64e34589b58ef2e8bfb33f5b2cc2` (matches the probe findings) |
| Worktree | Modified: `AGENTS.md`, `inst/design/README.md`, `horizon.md`, `ledgr_roadmap.md`, `rfc/README.md`, `test-documentation-contracts.R`. Untracked: the Seed, `dev/spikes/availability-hot-path-representation/`, `dev/spikes/asset_availability_pit/`. Nothing cleaned, staged, or committed. |
| Runtime | Windows, `x86_64-w64-mingw32`, R 4.5.2 for the probe rerun |
| ledgr loading | `pkgload::load_all(export_all = TRUE)` from the working tree (probe.R:12) |
| collapse | 2.1.8 from `C:/tmp/ledgr-collapse-218-src-lib`; the normal R 4.5.2 library holds 2.1.7; R 4.6.1 holds 2.1.8 from a CRAN Windows binary |
| Probe rerun | Yes, exit 0. Parity `TRUE` on all three checks. |

The prompt's history-document paths (`performance_arc_v0_1_8_7_to_v0_1_8_10.md`,
`collapse_optimization_map_v0_1_8_7_to_v0_1_8_10.md`,
`fold_path_hotpath_audit_v0_1_8_8.md`) do not exist. The Seed's own citations
(`manual/performance_arc_v0_1_8_x.qmd`, `collapse_optimization_map.md`,
`audits/fold_path_hotpath_audit.md`) resolve and were used instead.

## Recommendation

**Revise Seed v1 before Response Review**, after one further probe. The
diagnostic-representation mechanism is real and reproduced, but the Seed
presents it as the diagnosis of the external resource blocker, and the cited
external evidence points the other way on wall time. The Seed also names the
wrong cheaper prerequisite. Both are foundation defects a v2 should absorb; the
remaining findings are citation and wording corrections. No decision needs
maintainer escalation yet, and the proposal should be narrowed, not withdrawn.

## Findings

### Blocking

**F1 - High. Provider deferral misreads the cited evidence; on that evidence
provider resolution, not diagnostics, is the dominant wall lane.**

- Seed 6, lines 174-176: external measurements "put decision-view resolution in
  the minutes rather than the thirty-minute class, so those paths are not the
  first spike question."
- The measurement (batch2-integration-verification.md, "Full-Population Control")
  is 7.876 s for **one pulse's** 505 resolutions. The fold calls
  `decision_view()` once per pulse (`R/fold-engine.R:379`) over 757 pulses:
  757 x 7.876 s is about 5,960 s at first-cutoff cost, 3.3x the 1,800 s
  ceiling, before any other lane.
- The external review (batch2-review.md, resolution-cost table and its
  consequence paragraph) measured per-resolution cost rising roughly 12x from
  first to last cutoff and concluded the provider term "alone approaches the
  derived ceiling before any fold, sizing, or accounting work". Its
  attribution item explicitly declines to exclude per-pulse provider resolution
  as a large term because "that fold still performs one `decision_view()` per
  pulse across 757 pulses".
- The probe's construct arm is linear (rerun: 4.06, 7.97, 15.50 s for 5k, 10k,
  20k rows, about 0.78 ms per row). At roughly 380k rows for the observed shape
  that is about 300 s across the whole run, near 17% of the 1,804 s lower bound.
  The super-linear `do.call(rbind, ...)` at `R/fold-engine.R:1093` runs after the
  pulse loop and had not executed when the run was stopped `RUNNING`.
- Why it matters: Seed 5's kill/recharter clause ("the unchanged run still
  breaches its envelope") is not a corner case; on current evidence it is the
  expected outcome, so the spike as framed most likely ends by chartering the
  question it deferred. Memory is different: 108.34 MiB per 20k rows
  extrapolates to about 2 GiB of the 4,245.6 MB working set, so the memory
  diagnosis is supported.
- Smallest correction: replace the "minutes" sentence with the external
  review's actual finding; reframe Seed 2 and 5 so the diagnostic writer is
  proposed as the verified memory mechanism, not the wall diagnosis; make the
  lane profile in F2 the prerequisite.

**F2 - High. The named cheaper prerequisite is the wrong one.**

- `spike_protocol.md` 2 requires the charter to name "the cheaper prerequisite
  question it depends on". Seed 5, lines 144-145, names the collapse 2.1.8
  character/list probe. That is a prerequisite for the Seed 4.3 mechanism
  choice (`setv` versus base), not for the spike question.
- Two smaller questions precede the spike:
  1. Which lane dominates wall and memory on a shortened production-shaped
     flat fold? The fold loop records only `t_loop`
     (`R/fold-engine.R:13,1141`), so this is an `Rprof()` run of, say, 40
     pulses over a 505-ID axis, recorded as probe findings, not tooling work.
  2. Is the persistence seam chunk-safe? `write_run_diagnostics`
     (`R/backtest-runner.R:426-439`) is called once per invocation after the
     loop (`R/fold-engine.R:1105-1108`), inside one `dbWithTransaction`
     (`R/backtest-runner.R:260-262`, `R/fold-engine.R:1116`), and renumbers
     `diagnostic_seq` from `MAX + 1`. A chunked writer calls it many times per
     invocation. I executed the DuckDB primitive: inside one transaction chunk
     two renumbered from 4 after chunk one wrote 1-3; a rolled-back chunk left
     `next_seq` at 6 (duckdb 1.4.3). The ledgr-level obligations remain
     untested: clean-versus-resumed equality
     (`test-availability-parity.R:40`), exception-diagnostic sequence after
     rollback (`R/fold-engine.R:1120-1140`), and no double write through
     `write_run_evidence` (`R/backtest-runner.R:441-446`). Those are the
     fork's first failing cases.
- Smallest correction: name question 1 as the prerequisite, question 2 as the
  first seam case, and move collapse 2.1.8 into Seed 4.3 as a mechanism option.

### Non-blocking

**F3 - Medium. The probe's alternative arm does not measure the proposed
mechanism.** `build_columns_once()` (probe.R:68-94) is one vectorized
`data.frame()` from fully known vectors. Seed 4.2 proposes per-row scalar
`setv()` writes into preallocated columns with chunk flushes. The "below the
timer's resolution" figure (Seed 2, lines 49-50) is the ceiling of a different
design. Excluded from both arms: 22-column scalar writes (the 70k test covers
two columns), the per-row `[[id]]` named-vector lookups that feed each row
(`R/fold-engine.R:622-645`, linear in a 505-name axis), and `dbAppendTable`.
Correction: state that the probe bounds the attainable gain; the fork measures
the writer, including persistence.

**F4 - Medium. Seed 5 pre-authors charter content.** `spike_protocol.md` 3
forbids witness lists or checkers before a fork exists, and `rfc_cycle.md`
("Spikes inside a cycle") says the seed author does not write the charter.
Lines 157-163 read "Required parity surfaces should be limited to five
reviewable claims" and fix a fixture shape and case cap. Correction: relabel
as candidate surfaces for the charter author; the Seed proposes only the
question and the kill rule.

**F5 - Low. Rule-3 attribution.** Seed 2, lines 30-35, attributes three rules
to the v0.1.8.9 packet. Rules 1-2 are `v0_1_8_9_spec.md:133-138`. Rule 3
("frames at a boundary, not once per row") is bound by
`rfc_collapse_primitive_internals_v0_1_9_synthesis.md:204-210` and
`audits/fold_path_hotpath_audit.md:59`, which flagged this exact
`data.frame()` plus `do.call(rbind, rows)` shape in May 2026 (read-back lane,
MED); `765b34e` reintroduced it in the fold hot path in September. Fix the
citation; the "already-proven anti-pattern" claim is otherwise well supported.

**F6 - Low. Seed 4.3 overstates what 2.1.8 is needed for.** The recorded
2.1.7 failure (`v0_1_8_9_spec_packet/per_lane_attribution.md:125-129`) was a
long, scale-growing character buffer failing at growth boundaries with
`SET_STRING_ELT() must be a 'CHARSXP'`, a loud error rather than silent
corruption. Production already runs `setv()` on character columns in bounded
chunk buffers under 2.1.7 (`R/fold-reconstruction.R:221-227`) with tests
green; the handler keeps its `is.character` guard (`R/backtest-runner.R:381`).
A bounded chunked writer, the shape Seed 4.2 proposes, may not need 2.1.8.
Open question 3 should ask whether a bounded writer is safe on the minimum
supported collapse. `DESCRIPTION` line 23 carries no collapse floor. No
upstream issue is warranted; the rerun reproduced no defect.

**F7 - Low. Window label assumes a destination.** "v0.2.0.x" presumes a
patch-series home for a fold-core representation change while
`ledgr_roadmap.md:8,117` reserve `v0.2.0.1` for the crypto probe and
`AGENTS.md:305-307` states no representation optimization is authorized.
Acceptable in a non-binding Seed; list it under open decisions instead.

**F8 - Low, observation.** Ordering has authority: `v0_2_0_0_spec.md:426-427`
binds "Sequence rows deterministically by decision pulse, stage, and axis" and
`contracts.md:463-464` binds ordered stage evidence. The persisted sequence is
assigned at write time (`R/backtest-runner.R:433-436`), so order equals arrival
order at the handler; a chunked writer preserves it iff flushes are in arrival
order. The Seed is right to bind ordering.

## Claims independently verified

| Claim | Basis |
| --- | --- |
| Probe results: parity `TRUE` x3, 70k `setv` 0.91 s, list 27.08 / 54.17 / 108.34 MiB, column frame 0.81 / 1.60 / 3.16 MiB, bind super-linear (2.14, 7.97, 25.11 s) | Directly executed |
| DuckDB read-your-own-writes and rollback for chunked `MAX + 1` renumbering | Directly executed |
| collapse versions: 2.1.7 in the R 4.5.2 library, 2.1.8 isolated, 2.1.8 in R 4.6.1 from CRAN binary | Directly executed |
| All four Seed source citations; `765b34e` exists (2026-09-11); handler renumbering; one transaction over the loop; `decision_view()` once per pulse; only `t_loop` telemetry; bounded character `setv` in production; spec ordering clause; contract append/rollback clauses; synthesis non-scope (lines 847-848); audit line 59; roadmap and AGENTS window statements | Verified from source |
| ~380k rows, ~300 s construct, ~2 GiB retained list, ~5,960 s provider floor at the observed shape | Inferred from executed and documented numbers |
| 1,804 s / 4,245.6 MB / 7.876 s / 12x growth; collapse issue 876 changelog; "compiled from CRAN source" | Documented, not independently verified (aggregate records read; private run not rerun; changelog not fetched) |

## Adversarial analysis

The strongest case against the Seed is that it proves a mechanism and then
diagnoses a symptom the mechanism does not explain. The retained
list-of-frames is a verified memory anti-pattern and plausibly half the
observed working set. It is not a verified wall problem at the point the
external run was stopped: construction is linear and small, and the expensive
bind had not run. The one external per-lane number available, read correctly,
says provider resolution alone exceeds the envelope, and the external reviewer
said so. A writer that satisfies every parity surface in Seed 5 and halves
memory would still leave the flat fold at several thousand seconds, and the
cycle would have spent its spike on the second bottleneck.

Diagnostic representation is therefore the first separable **memory**
bottleneck and a credible later wall bottleneck, but not the first separable
wall bottleneck on current evidence. The honest framing is a memory correction
whose wall effect is measured, not assumed. Seed 4.2's cheapest form,
vectorized construction over a complete pulse axis, is available only to the
extent `decision_view()` already returns axis-aligned vectors; the `[[id]]`
usage at `R/fold-engine.R:622-645` suggests it does, but the probe did not
exercise that path and the Seed defers the provider representation it would
lean on.

Hidden allocations the probe excludes and the fork must not: the per-row
`[[id]]` scans; DuckDB's own transaction buffer, which a mid-fold flush moves
bytes into rather than eliminating; and `feature_identity_json` and
`detail_json` strings, which the probe fixes as `NA` and `"{}"`.

## Proposed-spike assessment

- Single question: yes, though it bundles five equivalence properties; keep it.
- Comparison arms: exactly two; correct.
- Witnesses and cases: at most ten, derived from failures; correct. The five
  parity surfaces are sound but belong to the charter (F4).
- Resource measurement: the envelope must be stated as a ratio to the current
  path on the same host, never an absolute, and peak memory must be process
  working set, not R `gc()`, because chunked flushing relocates bytes into
  DuckDB.
- Semantic parity: surfaces 1-4 are the right gates; add explicitly that
  `diagnostic_seq` continuity across chunks and across resume is asserted, and
  that no row's `detail_json` or `feature_identity_json` is coalesced.
- Transaction and resume: covered in principle; the seam cases in F2 must be
  the fork's first failing cases, not later witnesses.
- Kill/recharter rule: concrete and falsifiable as written. Given F1 it
  should sit before the fork as a prerequisite profile rather than after it.
- Engineering rule (Seed 8): appropriately scoped, correctly marked proposed,
  supported by the arc once F5's citations are fixed. Leave binding to
  synthesis.

## Open decisions

1. **What this cycle is for.** A memory correction for the diagnostic path is
   supported now; "make the Sharadar-shaped flat fold complete within its
   envelope" needs the lane profile first and may lead with provider
   resolution. Maintainer, after the profile probe.
2. **Release destination.** Patch series versus a minor for a fold-core
   representation change; `v0.2.0.1` is currently the crypto probe's.
   Maintainer, at synthesis.
3. **collapse floor.** Whether any correction may raise `DESCRIPTION` to
   `collapse (>= 2.1.8)` or must stay on the minimum supported version with a
   bounded design. Synthesis, informed by the seam and F6.

## Recommended next step

1. Run a lane-profile probe (`Rprof()` over a shortened production-shaped
   flat fold with a public synthetic fixture) and record it as a second
   `probe_findings` section under `dev/spikes/availability-hot-path-representation/`.
   This is `spike_protocol.md` 1 work, not a spike.
2. Write Seed v2 absorbing F1-F4 and the citation fixes, with the profile as
   the named prerequisite and the seam cases as the fork's first failures.
3. Then Response Review. Do not proceed to a charter or synthesis from Seed v1.

## Commands and evidence

```text
git branch --show-current            -> v0.2.0.1
git rev-parse HEAD                   -> cb3047b8b45c64e34589b58ef2e8bfb33f5b2cc2
git status --short                   -> 6 modified planning files; 3 untracked (Seed, two spike dirs)
git log -1 765b34e                   -> 2026-09-11 "Implement availability-aware fold economics"

LEDGR_COLLAPSE_LIBRARY=C:/tmp/ledgr-collapse-218-src-lib
"C:/Program Files/R/R-4.5.2/bin/x64/Rscript.exe" dev/spikes/.../probe.R .
  collapse_version=2.1.8  setv_character_parity=TRUE  setv_list_parity=TRUE
  setv_70k_elapsed_seconds=0.91
  rows  construct  bind   list_mib  col_build  col_mib  parity
  5000   4.06      2.14   27.08     0.01       0.81     TRUE
  10000  7.97      7.97   54.17     0.02       1.60     TRUE
  20000  15.50     25.11  108.34    0.00       3.16     TRUE
  exit 0

DuckDB seam probe (R 4.5.2, duckdb 1.4.3), one transaction:
  chunk1 from 1, chunk2 from 4; committed rows 5, max_seq 5
  rolled-back chunk3: rows 5, next_seq 6, error "fold_exception"

Source checks: R/availability-economics.R:386-432; R/fold-engine.R:318-327,
  379, 611-654, 1082-1108, 1116, 1120-1140; R/backtest-runner.R:260-262,
  381-394, 426-456; R/fold-reconstruction.R:219-227; R/availability-results.R:24-29;
  inst/design/contracts.md:462-471, 877-884; v0_2_0_0_spec.md:424-427;
  v0_1_8_9_spec.md:70-138; per_lane_attribution.md:100-135;
  audits/fold_path_hotpath_audit.md:59; rfc_collapse_primitive_internals:204-220;
  synthesis:847-848; ledgr_roadmap.md:8,117; AGENTS.md:305-307; DESCRIPTION:23.

External aggregate records read (no private rows, symbols, or paths):
  batch2-integration-verification.md "Full-Population Control And Resource Blocker";
  batch2-review.md resolution-cost table, consequence paragraph, attribution item.
```

## Revision history

- 2026-09-14 - Response v1 to Seed v1 at `cb3047b8b45c64e34589b58ef2e8bfb33f5b2cc2`.
  Probe rerun under R 4.5.2 with isolated collapse 2.1.8. No other file modified.

RECOMMENDED_NEXT_STAGE: Seed v2 after a lane-profile probe, then Response Review
