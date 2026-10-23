# WS48 / LDG-3082, LDG-3083, LDG-3090 focused re-review 1 (Type 1), `86621d5c..1d6bde52` (context `c79793e6..1d6bde52`)

## Verdict: PASS_AFTER_PATCHES (F1-F6 fixed; decisions (19) and (20) implemented correctly; two minor and three nit corrections, none to the proof's correctness)

What holds:

- F1-F6 are fixed as the close review asked, and each claimed detector
  fails on its mutation (re-run here: R3, V6, V7, N1).
  - F1 (widen): the stop query selects `reason_code IN
    ('valuation_horizon_exhausted', 'terminal_mark_unavailable')`, and
    `valuation_stop_reason` is the first stop row's reason. LTB-0438 adds the
    LTB-0164 no-mark fixture and expects the literal STOPPED line with
    `(terminal_mark_unavailable)` in print() and summary(). The contracts.md
    bullet, roxygen, the regenerated Rd, the LDG-3090 scope and LCL-0428 name
    both reasons.
  - F2: LTB-0432 adds the 1 March decision at `threshold = 0.3` (share
    exactly 3/10) and expects solved, CCC above zero and the four-instrument
    oracle. R3 now fails LTB-0432 (and LTB-0437).
  - F3: LTB-0436's INCOMPLETE run uses a call-counting strategy and asserts
    `calls$n == 0L` (`test-minimum-variance-proof.R:308-324`). I read the
    engine mutations E1 and E2; I did not re-run them.
  - F4: "five sessions for six instruments".
  - F5: one sentence after the run explains the STALE line.
  - F6: `solution <- solution / sum(solution)` after clipping. LTB-0436 mocks
    `0.5 + 0.9e-8` twice and `-0.9e-8`. N1 fails it with an error
    (`ledgr_levered_weights`).
- Decision (19), leavers:
  - Step 7 targets `ctx$universe[ctx$vec$position != 0 & !ctx$vec$member]`
    to zero after the rebalance, on solved decisions only.
    `ledgr_target_rebalance()` preserves and reserves held non-eligible
    holdings (`R/strategy-helpers.R:394-418`), so the article's "neither
    weights nor sells it" and "the cash ... stays idle until the next
    decision" are accurate.
  - LTB-0440 is failure-sensitive: L1 (no exit) fails it.
  - A zero target for a halted leaver is legal. In a probe with DDD as a
    leaver halted over 1-3 March, the run is DONE. The 2 March exit is
    discarded, and DDD is sold on 2 April, at the next solved decision, as
    contracts.md (literal targets, halted holdings) says.
  - G4 is routed. The portfolio-construction row of `rfc/README.md` in the
    integration copy carries the input (26be3c0b: "Input added 2026-10-23
    (Cut 17 decision 19) ..."), and the LDG-3082 evidence lists it.
- Decision (20), eigenvalue floor:
  - The repair is correct. It floors at `eig_floor * largest`, after
    shrinkage, and reconstructs `V diag(f) V'` and then symmetrises. That is
    the Frobenius projection onto `{X : X >= floor * I}`, so "nearest
    positive definite repair" is accurate.
  - My own floor on LTB-0439's window gives:
    - floored eigenvalues with min/max exactly 1e-6;
    - an unchanged largest eigenvalue.
  - LTB-0439's oracle is independently confirmed. I used my own returns from
    the closes, a pairwise covariance by loop, my own floor and a
    projected-gradient simplex solver (not active-set, not quadprog).
    - Weights: 0.5127021 and 0.4872979 on AAA and BBB, zero on the three
      entrants.
    - pg against quadprog on the floored matrix: 4e-14.
    - KKT residual on the support: 1.1e-19. The off-support margin is
      +1.5e-4.
    - Targets 952/774/0/0/0 are identical across the strategy, my oracle and
      the test's oracle.
  - The precondition holds. The shrunk eigenvalues include -2.0e-4.
  - The missing-entry hold is reachable and pinned. `anyNA(sigma)` is the
    only remaining hold apart from "no positive variance". LTB-0436 reaches
    it in a run (`price_carry = NULL`, the CCC/DDD windows disjoint) and
    expects DONE and no 2 March fill. F1s (the check dropped) fails LTB-0436
    with an error.
  - The LTB-0436 and LTB-0437 changes are not oracle bending. The old
    zero-variance case now solves (probe: `solved`, DDD 1187 shares), which
    is the intended effect of decision (20)'s "holds only on genuine
    failures". The article's singular example now solves by design. Both
    moves, and the weaker "no 2 March fill" run assertion (the February and
    April decisions now solve), have stated reasons in the LDG-3083 evidence,
    as AGENTS.md requires.
  - The demo is untouched by the floor:
    - the smallest min/max eigenvalue ratio over the 24 solved decisions is
      0.571 (2019-04-01);
    - the reconstruction moves sigma by at most 2.8e-15 relative;
    - the rendered outputs are unchanged apart from the sweep ID.
- No regressions:
  - all ten blocks pass;
  - `render-vignettes-gfm.R --check vignettes/minimum-variance.qmd` passes;
  - census check OK (158 branch and 55 flow sites; every regenerated table
    byte-identical to the committed CSV);
  - mode-branch self-test OK;
  - fold-phase checker OK;
  - tickets.yml, claims.yml and _pkgdown.yml parse;
  - `git diff --check c79793e6 1d6bde52` is clean;
  - committed blobs are LF (`git ls-files --eol`: i/lf) and UTF-8;
  - claims LCL-0421..0430 and blocks LTB-0431..0440 sit inside the
    reservation, with no duplicate claim IDs;
  - the Workstream 48 tickets read complete, and WS48 reads review_pending.

What does not hold:

- N1 (minor, detector; decision (20), LCL-0429): the floor's rule and size
  are unpinned. An absolute floor (P3) and a hard-coded 1e-3 floor (P5)
  survive every block.
- N2 (minor, seven-shape 5 and article accuracy): the strategy always
  computes eigenvectors and reconstructs sigma, even when nothing is floored.
  - This costs about 0.08 s per decision at N = 500 (about 27 s over 333
    decisions).
  - The article's "left unchanged" is true only to rounding.
- N3 (nit, detector): the "no positive variance" hold is unpinned. P6
  survives; the decision still holds, but as `solver_failure`.
- N4 (nit, teaching): the leaver paragraph points the reader at "registered
  blocks". It does not say leavers are sold only on solved decisions.
- N5 (nit, claim text): LCL-0427 still says the rendered output "shows each
  hold outcome". `covariance_not_positive_definite` no longer appears in the
  rendered output.

Review ratio: 5 findings over 3 tickets = 1.667 per completed ticket.
Recorded, not gated.

## Method

- I read:
  - AGENTS.md and the brief;
  - the Cut 17 decisions (16)-(20) in the integration tickets.yml;
  - `close_review_48.md`;
  - the whole `86621d5c..1d6bde52` diff (R, contracts, Rd, claims, test file,
    qmd, md, tickets.yml evidence);
  - `R/strategy-helpers.R` (`ledgr_target_rebalance`);
  - `R/strategy-types.R` (`ledgr_strategy_eligible`);
  - contracts.md, the literal-target and `ctx$vec` bullets;
  - the integration `rfc/README.md` portfolio-construction row and 26be3c0b;
  - the exploratory Sharadar aggregates (`explore_minvar/results/summary`);
  - the seven shapes in `optimization_coding_style.qmd`.
- I ran these scripts, all in `ws48_rereview/`, one R process at a time:
  - `run_blocks.R`: the ten blocks;
  - `indep_rereview.R`: the LTB-0439 oracle, floor sensitivity, demo floor
    margin, the zero-variance, halted-leaver and default-carry probes;
  - `mutate_rereview.R`: mutations on copies in `ws48_rereview/mut/`, with
    the results in `mutations_rereview.csv`;
  - `fix_probe.R`: whether the proposed N1 and N3 fixes detect P3, P5 and
    P6;
  - `rules_rereview.R`: YAML, IDs, encoding, render check, census check with
    `--output` to `ws48_rereview/census/`, mode-branch self-test;
  - the fold-phase checker, run directly with the worktree root;
  - `eigen_cost.R`.
- Not run: the full suite, R CMD check and timing gates. The brief excludes
  them, and the implementer's evidence covers them.

## Findings

### N1 (minor, detector; decision (20), LCL-0429 "floored at 1e-6 times the largest")

Verified facts:

- On LTB-0439's window the long-only solution puts no weight on the floored
  direction, so its targets do not depend on the floor's size or form.
  Against the 1e-6 relative targets, each variant differs by at most:
  - relative 1e-8: 1 share;
  - relative 1e-5: 1 share;
  - relative 1e-4: 1 share;
  - relative 1e-3: 0 shares;
  - absolute 1e-6: 1 share;
  - absolute 1e-10: 0 shares.

  Only floor-before-shrink differs (174 shares; P4 is detected).
- Mutation P3 (`floored[floored < eig_floor] <- eig_floor`, an absolute
  floor) and P5 (1e-3 hard-coded) pass all nine strategy blocks.

Smallest fix:

- In LTB-0439, add a second decision on the same fixture with
  `eig_floor = 0.2`. Expect `solved` and targets within one share of
  `floor(ws48_long_only(ws48_floor(sigma, 0.2)) * 0.95 * 100000 / price)`,
  which is 653/546/109/119/129.
- Executed (`fix_probe.R`): the unmutated strategy differs by 0 shares, P3
  by 282 and P5 by 299. At 0.01 and 0.05 the targets equal the 1e-6 ones,
  so use 0.2 (or at least 0.1).
- Add P3 and P5 to LCL-0429's `smallest_failing_change`, and record the
  reason (strengthening a detector, no fixture change) in the LDG-3083
  evidence.

### N2 (minor; seven-shape 5 "work computed when its result is not needed", and the article's eig_floor bullet)

Verified facts:

- The repair runs `eigen(sigma, symmetric = TRUE)` with vectors and the
  `V diag(f) V'` product on every solved decision, whether or not any
  eigenvalue is below the floor.
- On the demo, nothing is floored on any of the 24 solved decisions
  (smallest ratio 0.571). The reconstruction still moves sigma by up to
  2.8e-15 relative, so "an estimate whose eigenvalues are all above the
  floor is left unchanged" holds only to rounding.
- At N = 500 (synthetic 252 x 500 window, this machine, mean of 5 runs):
  - values-only eigen: 0.022 s;
  - eigen with vectors: 0.068 s;
  - reconstruction: 0.034 s;
  - solve.QP: 0.140 s.

  So the repair adds about 0.08 s per decision, or about 27 s over the 333
  decisions of the exploratory Sharadar run, which took 173 s before
  decision (20). That run traded 296 of 333 months; the 37 untraded months
  are the indefinite ones, so the floor would bind on about 11% of
  decisions.
- This is article code, not a package hot path. The brief asks for the walk
  over the strategy's per-decision work, and this is the one instance.

Smallest fix:

```r
values <- eigen(sigma, symmetric = TRUE, only.values = TRUE)$values
largest <- max(values)
if (!(largest > 0)) {
  return(hold("covariance_not_positive_definite"))
}
if (min(values) < eig_floor * largest) {
  decomposition <- eigen(sigma, symmetric = TRUE)
  floored <- decomposition$values
  floored[floored < eig_floor * largest] <- eig_floor * largest
  sigma <- decomposition$vectors %*% (floored * t(decomposition$vectors))
  sigma <- (sigma + t(sigma)) / 2
}
```

The snippet keeps the indexed assignment because LTB-0437 forbids `pmax(`
in the strategy source. The fix:

- makes "left unchanged" literally true;
- keeps the demo outputs and LTB-0439 (which takes the repair branch);
- restores the pre-(20) cost on decisions that need no repair.

Re-render, then run `render-vignettes-gfm.R --check` and the blocks.

### N3 (nit, detector): the "no positive variance" hold is unpinned

Verified facts:

- Mutation P6 (drop the `!(largest > 0)` hold) passes every block.
- On an all-constant window (`fix_probe.R`):
  - the unmutated strategy returns `covariance_not_positive_definite`
    (target equal to `ctx$hold()`);
  - P6 returns `solver_failure` (target equal to `ctx$hold()`).
- So the defect is only the wrong outcome name. The article names this case
  under `covariance_not_positive_definite`.

Smallest fix: in LTB-0436, add a pulse on a fixture whose four closes are
constant (for example `rep(c(50, 60, 70, 80), each = nrow(closes))`) with
`lookback = 10L, min_obs = 5L`. Expect `covariance_not_positive_definite`
and `target == hold`. Record P6 in LCL-0426.

### N4 (nit, teaching): the leaver paragraph

Verified facts:

- `minimum-variance.qmd` (leaver paragraph) says "The demo's universe never
  changes, so the registered blocks show the sale". An article reader has no
  access to registered blocks.
- The paragraph does not say when the sale happens. In the code it happens
  only on a solved decision, so a decision that holds keeps leavers until
  the next solved one. A halted leaver's exit is discarded and retried at
  the next decision, as the probe shows (sold 2 April, not 2 March).

Smallest fix: replace that sentence with "The demo's universe never changes,
so this run has no leaver. The sale happens on decisions that solve: on a
decision that holds, a leaver stays until the next one, and so does one
halted at the decision." Re-render and verify.

### N5 (nit, claim text): LCL-0427 "the rendered output shows each hold outcome"

Verified facts:

- After b376cab8 the rendered article shows only these outcomes:
  `not_a_decision_date`, `insufficient_history`, `too_few_instruments` and
  `solved`.
- `covariance_not_positive_definite`, `solver_failure` and
  `no_permissible_mark` are described in prose only. LTB-0437's expected
  map agrees.

Smallest fix: in LCL-0427, replace "shows each hold outcome" with "shows the
not_a_decision_date, insufficient_history and too_few_instruments holds".

## Observations (no change required)

- O1 (decision (20) consequence). The old LTB-0436 zero-variance fixture now
  solves, with 99.96% of the 95% sleeve in the constant-price DDD. That is
  the exact minimum-variance answer for the estimate, and the decision text
  asks the strategy to hold only on genuine failures. The maintainer should
  still know it. Before (20), an exactly singular estimate held; now a
  near-riskless instrument takes the book.
  - With default carry, an exactly constant 60-return window is not
    expected on real data, because carried closes are screened by
    `threshold`.
  - A variance screen belongs with the estimation-exclusion policy in the
    portfolio-construction RFC, if it is wanted.
- O2. Mutation L3 (exit every inadmissible holding instead of every
  non-member) survives. It differs from step 7 only for a target-restricted
  member. Under contracts.md, a zero target for a halted holding is
  discarded, and the halted member is admissible again at the next decision
  after the halt. So the mutation is equivalent on every block, like the
  close review's R7. No block change is required.
- O3. With default carry, the LTB-0436 missing-entry fixture solves: CCC's
  carried share screens it out. So the missing-entry hold is reached only
  under a policy without input carry, or in genuinely disjoint histories.

## Mutations

All mutations were made on copies under `ws48_rereview/mut/`.

- Strategy mutations reach the blocks through `LEDGR_TEST_SOURCE_ROOT`. Each
  ran against LTB-0431..0437, 0439 and 0440.
- The R/ mutations were installed into the loaded namespace for LTB-0438,
  then restored, and the block passed again after restore.

| ID | Change | Result |
| --- | --- | --- |
| baseline | unmutated copy | all ten pass |
| R3 | `carried_input_share < threshold` (close review F2) | LTB-0432 and LTB-0437 fail |
| V6 | stop filter without `terminal_mark_unavailable` (F1) | LTB-0438 fails |
| V7 | reason hard-coded, not read from the stop row (F1) | LTB-0438 fails |
| N1 | no renormalisation after clipping (F6) | LTB-0436 errors |
| F1s | missing-entry hold dropped | LTB-0436 errors |
| P1 | no floor applied | LTB-0439 fails |
| P2 | `eig_floor` default 0 | LTB-0439 fails |
| P3 | absolute floor (reviewer) | survives (N1) |
| P4 | floor before shrinkage (reviewer) | LTB-0439 fails |
| P5 | floor hard-coded 1e-3 (reviewer) | survives (N1) |
| P6 | no-positive-variance hold dropped (reviewer) | survives; holds as solver_failure (N3) |
| L1 | no leaver exit | LTB-0440 fails |
| L3 | exit inadmissible holdings, not non-members (reviewer) | survives; equivalent (O2) |

The implementer's L2, E1, E2 and the original 25 strategy mutations were not
re-run.

## Provisional defaults

1. The article sits in Going Deeper after strategy-authoring-tools: sound
   (close review default 1, unchanged).
2. `keep_excluded`: sound (close review default 2).
3. `shrink` 0.5 and `min_obs` 60, uncalibrated: sound for this cut (close
   review default 3). With the floor in place, shrink is purely a
   regulariser, and WS50's G-013 report is where calibration belongs.
4. `equity_fraction` 0.95 fixed inside the strategy: sound (close review
   default 3).
5. "Excluded by the history" read as not admissible: sound (close review
   default 4; R7 and now L3 are equivalent).
6. STOPPED wording naming at most three holdings, with the block in the
   review profile: sound (close review defaults 5 and 6).
7. Decision (17)'s "missing mark" covers both no-mark stops (widen rather
   than route): sound. `terminal_mark_unavailable` is the same situation for
   a known-inactive holding; `terminal_settlement_unsupported` correctly
   keeps its headline.
8. Leavers are sold on solved decisions only: sound, and I recommend keeping
   it.
   - LDG-3082's scope binds "returns ctx$hold() ... when the estimate is
     unavailable". LTB-0436 asserts `target == hold` for every hold, and
     LDG-3088 counts outcomes on that basis. A held decision that also exits
     leavers would need a new outcome and a scope amendment.
   - The practical gap is small. The exploratory run's 37 untraded months
     were exactly the indefinite-covariance months that (20) now repairs.
     The remaining holds are the data-start `insufficient_history` (no book
     yet) and rare `too_few_instruments` or missing entries.
   - A halted leaver waits for the next fillable decision either way.
   - Whether exits should be decoupled from the estimate belongs with G4 in
     the portfolio-construction RFC.
9. `eig_floor = 1e-6` relative to the largest eigenvalue: sound as a
   numerical repair. It caps the condition number at 1e6, and quadprog's
   factorisation is stable there. It is not a regulariser: near-null
   directions keep near-zero variance (O1), and on LTB-0439 any floor from
   1e-8 to 1e-3 gives the same targets. That is fine for a proof whose
   regulariser is `shrink`; pin the rule per N1.
10. Missing covariance entries are not imputed and hold as
    `covariance_not_positive_definite`: sound.
    - Any imputed value (0 or an average) is an invented estimate.
    - With default carry the case is practically unreachable (O3).
    - The finer alternative is to drop one instrument of the pair as an
      estimation exclusion. That belongs to the estimation-exclusion policy
      in the portfolio-construction RFC.
    - Reusing the outcome name is acceptable, because the article defines it
      as "cannot be repaired".

## Seven-shape walk

- `R/valuation-summary.R` (81cc0123): the same single parameterised query.
  The filter is widened to two reason codes, and the reason is read from row
  one. There is no loop, no per-row formatting and no new caller on
  selection surfaces. No shape instance.
- Strategy per decision (b376cab8):
  - The eigen decomposition with vectors and the `V diag(f) V'` product are
    O(N^3), bounded by the estimated count and independent of run length.
  - The leaver mask is one vectorised comparison over `ctx$universe`.
  - Off-decision pulses are unchanged: one empty two-session read.
  - The single instance is shape 5: the reconstruction is computed when no
    eigenvalue is floored (N2, measured above).

## Verified by execution versus by reading

- By execution:
  - the ten blocks;
  - the LTB-0439 oracle with my own floor and solver;
  - KKT;
  - floor sensitivity;
  - the demo floor margin and reconstruction rounding;
  - the zero-variance, halted-leaver, default-carry and all-constant probes;
  - 14 mutations, including R3, V6 and V7 (F1), N1 (F6) and the proposed N1
    and N3 fixes against P3, P5 and P6;
  - the render check;
  - the census check (counts and table byte equality);
  - the mode-branch self-test;
  - the fold-phase checker;
  - YAML;
  - `git diff --check`;
  - line endings;
  - IDs;
  - the N = 500 eigen cost.
- By reading:
  - F3's counting assertion, and the implementer's E1 and E2 records;
  - the F4 and F5 text;
  - the contracts.md and Rd wording;
  - `ledgr_target_rebalance()` reservation of held non-eligible holdings;
  - contracts.md on zero targets for halted and restricted holdings;
  - the G4 routing in the integration `rfc/README.md`;
  - the stated reasons for the LTB-0436 and LTB-0437 changes;
  - the decision (16)-(20) texts.
- Not run: the full suite, R CMD check, timing gates, and the implementer's
  L2, E1, E2 and original 25 mutations.
