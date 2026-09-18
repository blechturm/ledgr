# Availability Hot-Path Representation - Spike Evidence Review

**Status:** First post-execution review under `spike_protocol.md` Section 7.
**Reviewer:** Codex; Seed v2 author and Charter reviewer, but not the spike
executor or Charter author.

## Reviewed source state

- Branch `v0.2.0.1`; HEAD
  `cb3047b8b45c64e34589b58ef2e8bfb33f5b2cc2`.
- Reviewed the uncommitted two-file seam, runner, checker, inventory, and six
  evidence CSVs. The RFC index remains at spike execution authorized.
- Harness size is 776 R lines: runner 473, checker 135, writer seam 168. The
  fold seam is +13/-24. Both remain inside the Charter budgets.

## Verdict

**CHANGES_REQUIRED.** The recorded evidence supports the Charter's **GREEN**
outcome, and neither the writer seam nor either measured fixture needs to be
rerun. Three bounded checker defects must be corrected before the evidence
review can pass.

## Section 7 actions

1. **Rerun and diff.** The semantic runner completed independently in 1,623.1
   seconds. `fixture.csv`, `cases.csv`, and `diagnostics_40_rows.csv` were
   byte-identical to the recorded files. All nine case/arm rows reproduced,
   including one-row rollback evidence and the 5,060-row committed resume
   prefix followed by one error row.
2. **Gut.** I inserted an unconditional abort at the start of the columnar
   writer's `flush()`. The 40-pulse child failed at its first chunk; the run
   store recorded `FAILED`, exactly one `fold_exception` diagnostic, and zero
   ledger events. I removed the abort and verified the writer was restored
   byte-for-byte with no gut marker remaining.
3. **Inspect the decision.** The 40-pulse medians and spreads recompute to
   51.59 s / 0.44 s and 786.5 MiB / 121.2 MiB for rows, versus 22.14 s and
   369.6 MiB for columnar. The columnar arm therefore clears both registered
   spread rules. At 757 pulses the rows arm was stopped at 1,800.3 s while
   `RUNNING`; both columnar runs finished near 520 s and below 935 MiB. The
   grouped in-loop profile is provider 82.7%, diagnostics 14.6%, valuation
   2.1%, residual 0.7%; final bind has zero samples.

## Findings

### M1 - The claimed exact diff is tolerant and omits the fixture

`spike_checker.R:52-60` parses only `cases.csv` and
`diagnostics_40_rows.csv`, then uses `all.equal()` with its default numeric
tolerance. A semantic change from `1` to `1 + 1e-9` passes that predicate.
`fixture.csv` is never compared, although it is the only durable evidence for
the exact 60-list formula and indices required by Charter Review L2.

Fix: compare all three deterministic CSVs exactly, preferably as bytes or
normalized lines. Timing CSVs remain structural because their values vary.

### M2 - The package-scope guard misses change classes

`spike_checker.R:117-122` recognizes only porcelain `M` rows and `??` rows.
Tracked deletion, staged addition, rename, copy, and conflict statuses are
ignored. A simulated porcelain stream confirmed that `D  R/x.R`, `A  R/x.R`,
and `R  R/x.R -> R/y.R` never enter either checked set. The Git subprocess is
also not required to succeed before its output is parsed.

Fix: derive all tracked paths changed from HEAD plus all untracked paths, fail
clearly if either Git command fails, then apply the existing package-scope
allow-list. Do not add a hash ledger or workspace-cleanliness gate.

### M3 - Structural measurement checks do not enforce the deciding clause

`spike_checker.R:94-109` verifies arm labels, row counts, statuses, and three
lane names, but never evaluates the Charter's median/spread rule, the 757-pulse
wall and memory limits, or the grouped lane shares. The current predicates can
pass a file where both 757-pulse arms were killed, and they still pass after
making the columnar 40-pulse timings slower and larger than rows.

Fix: validate the recorded measurement CSVs against the registered repetition
shape, median/spread comparisons, envelope bounds and completion states, and
finite nonnegative lane shares with one largest grouped lane. This validates
recorded evidence; it does not create a public performance claim.

## Correction boundary and next step

Change only `spike_checker.R` and, if its checker description changes, the
inventory. Preserve the seam and all recorded CSV values. Run the corrected
checker; the semantic rerun may reuse this review's byte-identical result if no
deterministic evidence or runner code changes. Return the correction for the
second and final evidence-review round. Do not advance the RFC index yet.

SPIKE_EVIDENCE_REVIEW_DISPOSITION: CHANGES_REQUIRED
