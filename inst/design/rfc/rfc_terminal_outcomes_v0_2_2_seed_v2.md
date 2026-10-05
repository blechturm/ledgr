# RFC Seed v2: Terminal Outcomes and Frozen Holdings

**Status:** Seed v2, non-binding. Stage 5 of the RFC cycle. It supersedes
[seed v1](rfc_terminal_outcomes_v0_2_2_seed.md), which stays as the historical
artifact. The synthesis is next, by an author other than this one.
**Author:** Claude (also the v1 author), for the maintainer, 2026-10-04.
**Responds to:**
[Type 2 response](rfc_terminal_outcomes_v0_2_2_response.md), `00b6887`,
verdict `REVISE_SEED`.
**Pipeline row:** [`terminal-outcome-policy`](README.md#terminal-outcome-policy).

**Evidence (executed, in `dev/spikes/terminal-outcomes/`):** `probe_findings.md`
(R1-R5, selection surfaces); `freeze_probe.R` (gap inside the stale budget);
`carried_price_probe.R` (zero-volume carried bars); `gap_census_findings.md`
(Sharadar lake, 45.4 million bars). Plus the
[prior art](../research/Terminal-outcome_prior_art.md) through its amendments.

## 0. What changed from v1

v1 applied one disposition policy to terminals and to horizon exhaustion. The
response showed that turns ignorance into a sale (F1). In v2, terminals keep a
modeled disposition through the existing `held_terminal_position` field, and
horizon exhaustion **freezes and carries** the holding: no sale, no stop. New
in v2: a loud warning rule, a metrics section, and the untraded-bar question,
named but not absorbed. Section 13 adjudicates each response item.

## 1. Problem

Today a held position that meets a sealed terminal without settlement evidence
(R1), or whose mark exceeds `ledgr_valuation_stale(max_sessions)` (a halt, R3;
or bars that stop, R5), stops the whole run as `INCOMPLETE`. The candidate then
disappears from comparison, ranking and walk-forward. The census shows the
stakes:

- Runs of more than five untraded sessions: 3 in about 28 S&P 500 years, all
  bank failures; 57,643 market-wide, in 4,448 of 20,961 instruments.
- Carried prices against the price on resumption: SVB 106.04 to 0.40;
  Signature Bank 70.00 to 0.13.

Fail-closed makes broad-market research unusable; selling at the last price
fabricates cash. v2 avoids both.

## 2. Maintainer decisions (v1 Section 2, revised 2026-10-04)

1. **Revised.** Untradable holdings have two triggers with two outcomes.
   - A **sealed terminal event** gets a modeled disposition (Section 4).
   - **Horizon exhaustion** freezes and carries the holding (Section 5).

   *Reason:* fail-closed would stop most broad-market runs, and selling at the
   last price fabricates cash. Freezing matches what a real holder experiences.
   This partly rejects the response, which kept horizon exhaustion fail-closed.
2. Evidence always outranks assumption. Unchanged.
3. Closed menus with opinionated defaults; peer parity is acceptable.
   Unchanged.
4. Defaults keep ledgr usable. Every default used is recorded, shown, and
   changeable with one argument. Unchanged.
5. Per-reason overrides are in scope. **Refined:** they are keyed on exact
   sealed labels.
6. Assumed exits book as ledger events and enter identity. Unchanged.
7. Scenarios are compared by separate runs; sweeping assumptions is parked.
   Unchanged.
8. Incomplete candidates stay visible and counted. **Refined:** counted
   separately, never inside DSR mathematics.
9. **New.** The summary states assumptions and frozen holdings explicitly and
   warns obviously (Section 6).

## 3. What ledgr does today (executed)

| Fact | Evidence |
| --- | --- |
| Terminal and expiry are separate sets; terminal wins and stops with `terminal_settlement_unsupported`, otherwise `valuation_horizon_exhausted` | `R/fold-engine.R:492-523` |
| Valuation tracks `reference` (last close), `age`, and source `current_close` / `stale_close` / `expired_close`; beyond the budget `mark` becomes `NA` | `R/availability-economics.R:62-106` |
| Inside the budget a held gap is already *frozen and carried*: valued at `stale_close` with age 1-3, sells record `no_fill` / `execution_bar_missing`, and the run ends `DONE` | `freeze_probe.R` |
| A persistent sell fills at the first open after resumption (60, against 102 before the gap), so the loss is realized honestly | `freeze_probe.R` |
| A one-shot sell is dropped, not queued | `freeze_probe.R` (execution-intent session D9) |
| `held_terminal_position` (`last_permissible`, `last_mark`, `refuse`) already exists with versioned identities, but fires only for scheduled corporate-action rows | `R/corporate-action-policy.R:18-46`; `R/corporate-action-settlement.R:391-410` |
| A disposition without a qualifying mark **aborts** with `ledgr_corporate_action_disposition_mark_unavailable` instead of stopping | `R/corporate-action-settlement.R:455-470` |
| `terminal_event` is optional free text | `R/availability-facts.R:327` |
| The corporate-action summary counts held-terminal choices and sets `corporate_action_fidelity`; print shows one headline line | `R/corporate-action-results.R:275-416` |
| DSR requires `effective_trials` no larger than the completed candidates | `R/validation-dsr.R:420-436` |
| Zero-volume carried bars are valued and **filled** as trades | `carried_price_probe.R`; ledgr-research LFB-027 |

Freeze-and-carry is therefore not a new mechanism. It is today's in-budget
behavior continued past the budget, plus disclosure.

## 4. Terminal events

- **Trigger.** A held position meets a sealed lifetime `known_inactive` row
  with a nonempty `terminal_event`, and no supported settlement evidence
  settles it. Evidence paths (equity-settlement synthesis Section 3.4) run
  first and never consult this policy.
- **Home.** Extend `ledgr_corporate_actions(held_terminal_position = )` and
  widen its trigger from scheduled corporate-action rows to lifetime terminals.
  The menu:

  | Value | Outcome |
  | --- | --- |
  | `last_permissible` | **Default.** Dispose at the mark permissible at the terminal pulse. |
  | `last_mark` | Explicit opt-in: dispose at `reference`, the last close of any age. |
  | `haircut` | Dispose at `(1 - fraction)` × the permissible mark; the fraction is declared. |
  | `write_off` | Dispose for zero proceeds. |
  | `refuse` | Today's stop. **Strict preset.** |

  A widened trigger and new values change meaning, so every value gets a `v002`
  identity; `v001` keeps its scope (equity-settlement Section 3.3 versioning
  rule).
- **Overrides** map exact sealed labels to values:
  `held_terminal_position = c(default = "last_permissible", bankruptcy =
  "write_off")`.
  - Unmatched labels use `default`.
  - The ordered mapping enters identity, and results show the matched label.
  - ledgr interprets no synonyms. Today the Sharadar adapter seals every
    terminal as `"delisting"`, so overrides only become useful once the adapter
    passes the vendor reason through. That is research-side and not designed
    here.
- **Posting.** One `DISPOSITION` at the terminal's effective pulse, before that
  pulse's strategy call, as the existing disposition does (D3). It is not a
  fill.
- **No qualifying mark** (for example, never priced): refuse (D4). This is a
  change from today. Refusal must be a typed `INCOMPLETE` stop with its own
  token and a preserved prefix, not the current abort. No silent `write_off`.
- **Terminal while frozen (new, maintainer decision D-T1).** If the holding is
  already frozen (Section 5), no mark is permissible. `last_permissible` would
  refuse and stop the run. In the census, 118 delisted instruments end with
  more than five untraded sessions, none of them S&P 500 members.
  **Recommendation:** a separate setting for this sub-case, default
  `write_off`, disclosed as "assumed worthless". A name frozen past the budget
  and then delisted is overwhelmingly distressed: the prior art's
  performance-delisting losses are -30% (NYSE/AMEX, Shumway) to -55% (Nasdaq,
  Shumway-Warther), to verify. Alternatives are `last_mark`, `haircut` or
  `refuse`.

## 5. Frozen holdings (horizon exhaustion)

- **Home.** The valuation policy:
  `ledgr_valuation_stale(max_sessions, exhausted = c("freeze", "refuse"))`,
  default `"freeze"`. The resolved value enters run identity. "The package
  supplies no default stale horizon" (Availability Contract) stays true:
  `max_sessions` must still be declared.
- **State machine,** per held instrument:
  1. **Current.** A traded bar exists: today's behavior.
  2. **Stale,** age at most `max_sessions`: today's behavior. Valued at
     `stale_close`; targets record `no_fill` / `execution_bar_missing`.
  3. **Frozen,** age above `max_sessions`:
     - the position is kept;
     - it is valued at `reference` with new source `frozen_close`, and its age
       keeps growing;
     - targets record `no_fill` with a frozen reason;
     - no cash event is created;
     - the rest of the portfolio runs normally.
  4. **Resumption.** The next traded bar makes the mark current. A pending
     persistent target fills at that bar's open, so the gain or loss is
     realized (probe: 102 to 60).
  5. **Terminal while frozen.** Section 4, D-T1.
  6. **Frozen at the end of the run.** The run finishes `DONE`, with the
     disclosure and bound from Sections 6 and 7.
- **Stops.** `valuation_horizon_exhausted` becomes a stop only under
  `exhausted = "refuse"`. A new non-stop diagnostic, working name
  `frozen_mark_carried`, records entry into and exit from a freeze.
- **Sizing.** Equity includes frozen value, as it includes stale value today.
  The disclosure makes that visible. Weight-based helpers may exclude frozen
  instruments from rebalancing, as they already skip unpriced names; the
  synthesis should confirm the helper behavior.
- **Resume and replay** stay deterministic: freezing depends only on bars,
  facts and the declared policy.

## 6. Disclosure and warnings

- **Terminal outcomes** extend the corporate-action summary and the
  `corporate_action_fidelity` line (F5) with:
  - assumed exits by value and matched label;
  - modeled proceeds;
  - each default marked **default** or **declared**.
- **Valuation headline** (new, beside the corporate-action line):
  `Valuation: CURRENT`, `STALE - k holdings carried within the budget`, or
  `FROZEN - k holdings frozen, max x% of equity, longest n sessions, m still frozen at end`.
- **Warning banner:** an unmissable block at the top of `print()` and
  `summary()`, shown whenever any holding was frozen or any terminal exit was
  assumed, and escalated when anything is frozen at the end or the frozen or
  assumed weight ever exceeds 5% of equity. It names the assumption, the
  default used and the argument that changes it. Thresholds are for the
  synthesis.
- **Other surfaces.** The same flags appear as columns in run comparison, the
  run list, sweep tables, `ledgr_sweep_review()`, walk-forward prints and
  `ledgr_experiment_plan()`. No parallel provenance system.

## 7. Metrics on stale and frozen prices

Accounting stays exact: equity at `reference` is the honest last-traded value.
The metrics are biased in known ways:

| Measure | Effect | Treatment |
| --- | --- | --- |
| Total return, full path | Correct once the freeze resolves; the jump books the real move on the right day | Report as is |
| Volatility, Sharpe | Overstated: flat days look calm and the loss lands in one jump. This is non-synchronous trading (Scholes-Williams 1977, Dimson 1979; to verify) | Disclose stale exposure beside them |
| Max drawdown | Correct once resolved; understates risk during the freeze | Disclose |
| Frozen at the end | Final equity rests on an untradable price | Add the bound below |
| Selection | Smooth illiquid strategies win more often | Exposure columns in sweeps |

Required fields, derivable from per-pulse valuation diagnostics (`mark_source`,
`mark_age`, `quantity`, `price`): stale and frozen equity-day shares, maximum
frozen weight, longest freeze, frozen-at-end count, value and weight, and
**`total_return_if_frozen_worthless`** (the return with frozen-at-end holdings
set to zero).

Stale-robust variants, such as an autocorrelation-adjusted Sharpe (Lo 2002, to
verify) or lower-frequency metrics, are a parked analysis-helper option, never
a default.

## 8. Selection visibility

| Surface | Required |
| --- | --- |
| Sweep print | "n combinations: d done, i incomplete, f failed" plus frozen and assumed-exit counts |
| `ledgr_sweep_review()` | Issue rows show the stop reason and the affected IDs |
| `ledgr_run_compare()` | The default lists excluded incomplete runs; a named incomplete run keeps the typed refusal |
| Walk-forward | Excluded incomplete training candidates per fold, in scores and print |
| Effective trials, DSR | Unchanged mathematics on completed panels; report attempted and excluded counts and IDs (F4) |

With freeze-and-carry, far fewer candidates end `INCOMPLETE` at all. The
remaining stops are `refuse` choices and the D4 no-mark case.

## 9. Untraded bars: named, not absorbed

Sharadar is dense: 4.9% of bars are zero-volume carried prices. ledgr values
**and fills** at them, so a strategy can exit SVB at 106 during the halt
(LFB-027).

The fix has two parts:

- an **adapter policy**: whether carried rows are presented as missing or
  flagged;
- a **ledgr semantics** for untraded bars: no fills, and stale valuation age.
  This must be coordinated with the planned liquidity and capacity policy.

It is a separate decision, outside this RFC. It interacts with this RFC in one
way. Presenting carried rows honestly makes horizon exhaustion frequent, and
freeze-and-carry is what keeps that usable. The two should land in the same
release.

## 10. Out of scope

Queueing one-shot exits during halts (execution-intent D9); OTC trading after
delisting (supplied OTC bars are evidence); shorts and leverage; exact-quantity
settlement (own pipeline row); a default stale horizon; stale-robust metrics,
sweeping assumptions and experiment templates (parked); the adapter's reason
pass-through and untraded-bar policy (ledgr-research horizon, 2026-10-04).

## 11. Contract changes

- **Availability Contract, stop-token table:** `terminal_settlement_unsupported`
  and `valuation_horizon_exhausted` become stops only under their `refuse`
  values; add a no-mark refusal token and the non-stop `frozen_mark_carried`
  and assumed-disposal diagnostics.
- **Valuation policy:** the `exhausted` argument and the `frozen_close` source.
- **Persistence Contract:** `DONE` runs that contain freezes and assumed exits;
  resume across both.
- **Result Contract:** the valuation headline, the warning banner, stale-exposure
  fields, the worthless bound and the selection counts.
- **Equity-settlement Section 3.3:** the `v002` identities and the widened
  trigger.

## 12. Evidence the cycle still owes

Gate fixtures per trigger and policy value; a freeze-and-resume fixture
reproducing the SVB pattern (carried 106, resumes 0.40); a freeze-to-end
fixture with the worthless bound; a terminal-while-frozen fixture (D-T1);
resume witnesses across a freeze and an assumed disposal; selection-surface
witnesses (probe S1, S2, W1); exact accounting parity between an assumed and an
evidenced `DISPOSITION`; primary-source checks of every cited literature
figure.

## 13. Response adjudication

| Item | Verdict | Evidence |
| --- | --- | --- |
| F1, terminal versus horizon conflation | Accept the diagnosis; **superseded** in remedy: freeze, not fail-closed | `fold-engine.R:492-523`; census; `freeze_probe.R` |
| F2, extend the existing policy | Accept | `corporate-action-policy.R:18-46` |
| F3, exact sealed labels | Accept | `availability-facts.R:327`; adapter seals `"delisting"` |
| F4, no prefixes in DSR | Accept | `validation-dsr.R:420-436` |
| F5, reuse the corporate-action summary | Accept for terminals; add a valuation headline for freezes | `corporate-action-results.R:275-416` |
| D1, default `last_permissible` | Accept | Equity-settlement Section 3.3 |
| D2, policy home | Accept for terminals; freezing goes in the valuation policy | Section 5 |
| D3, post at the effective pulse | Accept | `post_disposition` boundary |
| D4, refuse when no mark exists | Accept, as a typed stop rather than an abort | `corporate-action-settlement.R:455-470` |
| D5, separate counts | Accept | Section 8 |
| D6, reporting only | Accept; freezing makes it a disclosure field | Sections 6 and 7 |

## 14. Open questions for the synthesis

1. **D-T1:** the default for a terminal while frozen (recommended `write_off`).
2. **Banner thresholds:** the 5% weight rule and frozen-at-end escalation.
3. **Rebalancing:** do weight helpers exclude frozen names, or carry their
   weight as fixed?
4. **Sizing:** should `equity_fraction` sizing use equity including frozen
   value, or offer an excluding option?
5. **Disclosure in the `refuse` world:** does `refuse` under the valuation
   policy still show the frozen fields for the pre-stop prefix?
6. **Release order:** confirm the untraded-bar decision is scheduled for the
   same release as freezing.
