# Availability Hot-Path Representation - Spike Evidence Re-Review

**Status:** Second and final post-execution review under `spike_protocol.md`
Section 7. **Reviewer:** Codex; not the spike executor or Charter author.

## Reviewed source state

- Branch `v0.2.0.1`; HEAD
  `cb3047b8b45c64e34589b58ef2e8bfb33f5b2cc2`.
- The runner, two-file seam, and all six evidence CSVs are byte-identical to
  the first evidence review's inputs. Only the checker and inventory changed.
- Corrected harness size is 893 R lines; the 117-line checker expansion is
  below the 500-line correction stop.

## Verdict

**PASS_WITH_LOW_OBSERVATIONS.** All three first-review findings are closed.
The diagnostic-writer spike formally closes **GREEN** under Charter v2. No
third evidence-review round is required.

## Findings closed

| Finding | Result | Deciding evidence |
| --- | --- | --- |
| M1: tolerant, incomplete deterministic diff | CLOSED | `spike_checker.R:78-108` requires all three deterministic CSVs and compares their raw bytes. An altered `fixture.csv` failed at its first changed line while the other two exact comparisons passed. |
| M2: incomplete package-scope guard | CLOSED | `spike_checker.R:227-250` uses `git diff --name-status --no-renames HEAD` plus `git ls-files --others --exclude-standard`, accepts only `M` for the named tracked allow-list, treats rename as delete plus add, and terminates on Git failure. The incident run detected staged add/delete/rename, working-tree deletion, and untracked additions. |
| M3: measurement checks did not enforce GREEN | CLOSED | `spike_checker.R:159-225` checks repetition shape, values and row counts, both median/spread rules, envelope completion and stop states, lane-share arithmetic, one largest lane, mechanism removal, the kill clause, and GREEN. A copied evidence set with slower/larger columnar measurements failed both comparison rules and GREEN. |

## Independent verification

- The corrected checker passed all 33 non-rerun checks with exit zero against
  the recorded evidence. Its reported clean full run adds the semantic-runner
  check and three exact diffs for 37 checks; the first review already supplied
  an independent byte-identical semantic rerun, so it was not repeated.
- `fixture.csv`, `cases.csv`, and `diagnostics_40_rows.csv` retain their
  first-review bytes. The writer and fold seam are unchanged, with no gut
  marker or reviewer scratch artifact remaining.
- A deterministic-rerun mutation failed exactly at `fixture.csv` line 2.
  A measurement mutation moving the columnar medians above the rows medians
  failed wall, working-set, and GREEN assertions. Both returned nonzero.
- The evidence still decides GREEN: exact semantic parity; 22.14 s versus
  51.59 s median wall and 369.6 versus 786.5 MiB median peak working set at 40
  pulses; both columnar 757-pulse runs DONE inside the envelope; final bind at
  zero samples.

## Incident adjudication

The scope-gut test accidentally operated on the real repository after its
scratch checkout failed. The executor then used prohibited index/checkout
commands to reverse only those accidental changes. I independently verified:
the index is empty; `R/backtest-runner.R`, `man/LEDGR_LAST_BAR_NO_FILL.Rd`, and
`tests/testthat/fixtures/test_bars.R` have no difference from HEAD; the staged
probe, renamed source path, and two untracked probes are absent; and repository
status matches the pre-incident shape.

The recovery was exact and did not compromise the spike. The process failure
remains recorded in the inventory. Future destructive scope tests must resolve
and verify the scratch repository first and invoke Git with `git -C <scratch>`;
they must never rely on a preceding directory change having succeeded.

## Low observation

`first_diff_line()` assumes byte inequality also produces a differing
`readLines()` element. A line-ending-only or final-newline-only difference
would instead stop inside its diagnostic formatter. It still exits nonzero and
cannot accept changed evidence, so this is message robustness rather than an
evidence-integrity defect. Carry it into future harness cleanup; Section 7 does
not open a third review round for it.

## RFC routing

GREEN answers only the Charter's diagnostic-writer question. It is not a
general availability-performance acceptance: the corrected dense/static
757-pulse run still takes about 523 seconds, versus about 87 seconds for the
older durable peer-benchmark engine despite that benchmark's larger bar load.
The corrected profile assigns 82.7% of in-loop samples to provider resolution.

Seed v2 Sections 6 and 10 therefore have their trigger: open the separate
provider-resolution question before treating this RFC as performance-complete.
That work should compile point-in-time facts into prepared integer-indexed
vectors or matrices and monotone change cursors before the fold; filtering,
sorting, and per-instrument data-frame subset loops do not belong in the pulse
path. The writer result remains valid input to a later synthesis. No production
implementation packet or release placement is authorized by this review.

SPIKE_EVIDENCE_REVIEW_DISPOSITION: PASS_WITH_LOW_OBSERVATIONS
