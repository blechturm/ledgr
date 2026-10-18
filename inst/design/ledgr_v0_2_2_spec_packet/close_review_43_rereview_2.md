# WS43 focused re-review 2 (Type 1), `c59a9b0f..ddecb5f4`

## Verdict: CHANGES_REQUIRED

Correction 2 closes R1 and R4 and implements decision (21) as described.
Decision (20) now restarts bounded and history-dependent windows at every
relisting in preparation and in the internal reader, the carry barrier stays
sticky, and the terminal plane is not read ahead of its knowledge time. The
changed `used_before_window` rule reports the reviewer's output-carry,
leading-input-carry and inactive-span cases, and no run or sweep result
depends on which experiments ran earlier in a session.

Three low findings remain. The agent also changed the bounded width that
`used_before_window` uses, from `stable_after` to `requires_bars`. That
change was not requested, nothing detects it, and it drops a case the
contract covers (S1). The new config registration resolves R3 for package
defaults, but it silently overwrites a user's explicit registration. It also
leaves the general built-in versus custom collision order-dependent, against
the unconditional decision (19) wording (S2). One claim record is stale
(S3). No finding asks to reopen a Cut 16 decision, so this is not
NEEDS_TYPE_2. This is correction round 2; under the governance rule a
further round goes to the maintainer.

Method:
- Read AGENTS.md, `close_review_43.md`, `close_review_43_rereview_1.md`, the
  Correction 2 section of `indicator_history_closeout.md`, Cut 16 decisions
  (1)-(21), LDG-3065..3067, v12 Sections 3, 5 and 6, the seven shapes, and
  `git diff c59a9b0f..ddecb5f4` in full for `R/`, `tests/`, `tests/claims.yml`,
  the contract, NEWS, both Rd files and the `indicators` vignette.
- Probes on a source copy (`ws43_rereview2/probes`): `r1.R` (three relisting
  cycles, a relisting followed at once by another delisting, a late-known
  terminal fact against early-known and no-fact substrates, terminal planes
  at cutoffs before and after knowledge), `r2.R` and `m9.R`
  (`used_before_window` on SMA, TTR SMA, BBands `up`, MACD `signal`, EMA,
  returns, aroon widths, lookback edges, a restart inside the window,
  carried runs and a `stable_after > requires_bars` definition), `r3.R` in
  both orders (custom and built-in `sma_50`/`return_1` runs, sequential and
  two-worker sweeps, user-user collisions, a non-default `sma_3`, an
  explicit user registration), `reasons.R` (decision (21) coverage under
  plain and output-carry policies, two calculation starts), and the previous
  reviewer's `agree.R`.
- 18 own source-copy mutations, each restored (table below); the agent's CSV
  was not used.
- Full suite, `tools/check-codebase-contracts.R --mode=check` and
  `tools/check-fold-phase-contract.R` on the source copy (results below).
  `git diff --check` is clean and every changed file is ASCII.

## Findings

### S1 (low): the bounded width change drops a contracted case and is undetected

`R/history-frame.R:390-403` (`ledgr_history_feature_width()`), used by
`R/history-frame.R:730-760`. R2 asked for carried values and inactive spans.
The correction also replaced the width source, `stable_after` for
`strict_window`, with `requires_bars` for every bounded definition. The
closeout records the change, but R2 did not ask for it.

Verified facts:
- `history_class = "bounded"` stores `gap_contract = "strict_window"` on the
  definition (`m9.R`: the LTB-0322 `level` definition prints
  `strict_window`), so the "strict_window only" part of the old rule changed
  nothing. The only effective change is `stable_after` to `requires_bars`.
  These differ only for a custom definition with
  `stable_after > requires_bars`.
- For such a definition the returned value is valid only because its segment
  began at least `stable_after` expected sessions earlier (decision (15),
  readiness per segment). In `m9.R` (`requires_bars = 2`, `stable_after = 4`,
  data from session 9), a read of sessions 10-14 returns valid values at
  12-14 only because session 9, before the window, was available. The new
  rule reports `used_before_window = FALSE`; with the previous width it is
  `TRUE`. The contract (`contracts.md:1737-1744`) and v12 Section 3 define
  the flag as use of "an observation or calculation state before the
  returned window". The segment's readiness is that state.
- Mutation M9 restores the old width source and fails no block in the
  indicator files. In the WS42 fixture the public reads are identical
  under both rules.

Inference: with the seen-sessions rule, a reach of `stable_after` expected
sessions is exact for the readiness dependence, because a valid value whose
in-window expected count is below `stable_after` must belong to a segment
that started before the window. `requires_bars` is exact only for the value's
inputs.

Fix: use `stable_after` (validated `>= requires_bars`) as the reach in the
seen-sessions rule, or derive it from the retained segment start. Add a
`stable_after > requires_bars` case to LTB-0322 and correct the closeout
sentence.

### S2 (low): experiment registration is order-dependent and silently overwrites a user registration

`R/indicator.R:336-353` (`ledgr_indicator_register_config()`), called from
`R/backtest-config.R:222` on every `ledgr_run()`.

Verified facts (`r3.R`, both orders, default session):
- Results do not depend on order. Custom `sma_50`/`return_1` runs return
  42 and -7, built-in runs return the built-in values, and sequential and
  two-worker sweeps match, in either order. Sweeps do not touch the registry.
  A stored fingerprint that matches neither the built-in nor a registered
  indicator refuses with `ledgr_run_hash_mismatch`. `ledgr_indicator_register()`
  is unchanged.
- New in Correction 2: after `ledgr_indicator_register(mine, "sma_200",
  overwrite = TRUE)`, any run with `ledgr_ind_sma(200)` replaces the entry
  without a message. The exported `ledgr_indicator_get("sma_200")` then
  returns the built-in, not the user's indicator, so a later experiment built
  from the registry silently computes something else. Before the correction
  this run refused with "already registered with different logic. Existing
  registration is unchanged".
- Not new, but the R3 class it answers. For a built-in pattern id with no
  package default (`sma_3`), a custom `sma_3` run after a built-in
  `ledgr_ind_sma(3)` run in the same session refuses with `ledgr_invalid_args`,
  and a built-in `ledgr_ind_sma(3)` run after a custom one refuses too.
  Decision (19), the Strict Features contract (`contracts.md:2006-2009`),
  `?ledgr_indicator` and LCL-0313 say, without that condition, that the
  custom definition runs its own function and the built-ins still compute
  their values.
- The user-user refusal holds (custom 43 after custom 42 refuses). Running a
  built-in experiment in between lifts it, because the built-in overwrite
  resets the entry.

Fix: `ledgr_feature_defs_from_config()` dispatches a built-in fingerprint for
`sma_<n>` and `return_1` without the registry. So `register_config()` can
skip registration when the indicator's logic equals the built-in of its id
pattern, and replace an existing entry only when that entry is the package
default. This removes the silent overwrite and the order dependence. Add the
explicit-registration and `sma_3` cases to LTB-0321. The alternative is to
state the session condition in the four documents.

### S3 (low, record): LCL-0313 describes the old fixture

`tests/claims.yml:3576` and `:3583`. The `oracle_class` still reads "literal
SMA(3) means" from four public runs. The `cheapest_adequate_lane` still reads
"two six-session snapshots". LTB-0321 now uses `sma_50` on 55-session
snapshots, with an oracle function, a user-user refusal and an
unregistered-fingerprint refusal. Fix: update both fields.

## Item results

| Item | Result |
| --- | --- |
| R1 decision (20) every relisting | PASS. `r1.R`: three cycles restart SMA(3), SMA(2) and EMA(3) after each relisting (SMA(3) 12 at 13 and 17 at 18, never a mixed window). A relisting followed at once by another delisting leaves 7 and 10 not ready and 11 = 10.5. The carry barrier stays sticky (a missing session right after a relisting is not carried). Frame and internal reader agree at every cutoff. The late-known terminal fact is invisible before its knowledge pulse (asserted and sticky planes all zero at cutoffs 9 and 11), values before knowledge equal the no-fact substrate, and values after equal the early-known substrate. `terminal_at()` returns the same sticky expression for its two other callers. B5 now agrees and K differs only as LCL-0311 now scopes |
| R2 `used_before_window` | PASS for the three requested cases (LTB-0322; M6, M7 and M8, the original broad column-rule revert, are detected). Lookback edges are correct (window at the data start FALSE, short bounded window TRUE, `Inf` FALSE). BBands `up` and aroon take their catalogue widths (3, `n + 1`), and MACD `signal` and EMA use the history-dependent rule. Cost is one cumulative sum over the read cells, with nothing recomputed from the calculation. Width-source change: S1 |
| R3 decision (19) paths | `sma_n` branch removed; unregistered fingerprint refuses (M10 detected); defaults no longer block (M11, M12, M13 detected); residual S2 |
| R4 detectors and record | PASS: LTB-0316's middle-instrument panel fails probe-last and probe-first (M14, M15); LTB-0320 asserts the internal reader's counts (M4, M5); LCL-0311 and the closeout F2 sentence are scoped to facts known at their column |
| Decision (21) | PASS. `reasons.R`: no cell that is not `calculation_valid` lacks a reason, under plain and output-carry policies and two calculation starts, for bounded, history-dependent, SMA and return definitions. Both readers agree. The reason is derived from the value (frame `ready & !is.finite(value)`; internal reader `ready & !calculated`). Registered in LTB-0319 (M16 and M17 detected) |
| Earlier PASS items | No regression: F1 sentence, F2 states and agreement (`agree.R` 23 cases), F4 carry barrier, F6 required-field carry, F7 record, slice refusal |

## Mutations (source copy, each restored)

Filter `indicator-evidence|indicator-causality|indicator-dispatch` unless
noted.

| ID | Mutation | Result |
| --- | --- | --- |
| M1 | runs break where the sticky plane changes | LTB-0320 fails |
| M2 | no terminal breaks | LTB-0320 fails |
| M3 | breaks where the asserted plane changes between rows | LTB-0320 fails |
| M4 | internal reader windows use the sticky plane | LTB-0320 fails |
| M5 | internal reader window rule removed (RR12) | LTB-0320 fails |
| M6 | `used_before_window` ignores output-carried sources | LTB-0322 fails |
| M7 | ignores the leading carried-input run | LTB-0322 fails |
| M8 | whole bounded branch back to the pre-correction column rule (the broad form of the agent's narrowed "columns" mutation) | LTB-0322 fails |
| M9 | width back to `stable_after` for `strict_window` | no block fails (S1) |
| M10 | unregistered fingerprint falls back to the built-in | LTB-0321 fails |
| M11 | package defaults block the experiment's definition | LTB-0321 fails |
| M12 | built-in shadows the custom function | LTB-0321 fails |
| M13 | config registration always overwrites | LTB-0321 fails |
| M14 | probe the last instrument | LTB-0316 fails |
| M15 | probe the first instrument | LTB-0316 fails |
| M16 | frame drops `calculation_non_finite` | LTB-0319 fails |
| M17 | internal reader drops `calculation_non_finite` | LTB-0319 fails |
| M18 | engine digest omits `terminal_breaks` (filter `strict-feature-acceleration|strict-ttr-cleanup`) | LTB-0144 and LTB-0276 fail |

All 12 detectors the agent claims are reproduced (M1, M2, M5-M7, M10-M12,
M14, M16, M17; M8 in the broad form). The single survivor, M9, is the
unrequested change in S1.

## Changed oracles

- LTB-0144 and LTB-0276: only the availability engine literal changes
  (`4b2bb8e6...`), and the helper list gains `terminal_breaks`. The dense
  literals are unchanged. Valid: hashed helpers changed (M18 shows that the
  digest binds the new helper).
- LTB-0316, LTB-0319, LTB-0320: extended only; every earlier assertion is
  unchanged.
- LTB-0321: `sma_3` becomes `sma_50`, the registry is no longer cleared, and
  the built-in SMA oracle becomes a mean function of the fixture closes
  instead of literals. The stated reason (exercise a package default) is
  valid and nothing is weakened. A built-in pattern id without a default is
  no longer exercised; S2 asks for it back.
- No WS42 registered oracle changed.

## Cost and shape

No new loop over bars, pulses, cells or events. The decision (20) breaks are
one `cumsum` per instrument, range and definition (recomputed per definition
on the same inputs; cheap, not a finding). The terminal assertion comes
from the fact plane already resolved for the sticky barrier.
`used_before_window` is vectorized over the read cells (transpose, `fcumsum`,
`max.col`). Config registration computes at most three fingerprints per
indicator at config time. The internal reader repeats the break rule inline
instead of calling `ledgr_history_feature_terminal_breaks()`. Both copies are
detected (M1-M5).

## Suite and checkers

- Full suite on the source copy after `load_all()`: 1,140 blocks, 0
  failures, 0 errors, one optional skip (Yahoo missing-package path), 12.1
  min. No `_problems` artifacts.
- `tools/check-codebase-contracts.R --mode=check`:
  `LEDGR_CODEBASE_CENSUS_OK` (helpers 1,808, matching the committed census).
  The diff of `R/` adds no `availability_active` or other execution-mode
  branch, and the dense engine literal is unchanged.
- `tools/check-fold-phase-contract.R`: `LEDGR_FOLD_PHASE_CONTRACT_OK`.

## Maintainer notes (not findings)

- History-dependent values report `used_before_window = TRUE` whenever the
  window does not start at the data start, even when the segment restarted
  inside the window (`r2.R`: EMA(3) after a seven-session gap). This
  over-reports. It is conservative and the contract now states it. The
  retained segment start would make it exact.
- An instrument excluded by `na_action = "drop_instruments"` because a cell
  is `calculation_non_finite` (or `not_ready`) gets the selection-table reason
  `missing_required_input`. Decision (21) covers `missing_reason` only.

## Review ratio

Three findings (S1-S3) over five re-reviewed items (R1-R4 and decision
(21)): 3/5 = 0.600. This is correction round 2. All three findings are low.
Under the governance rule, a third correction round goes to the maintainer.
