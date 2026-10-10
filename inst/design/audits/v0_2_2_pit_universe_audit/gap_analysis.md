# Point-in-time universe audit, Stage 3: gap analysis

**Status:** Stage 3 output, 2026-10-10, for Gate 3. Written by a clean-context
Type 2 reviewer who wrote neither the yardstick nor any earlier audit output.
Binds nothing; findings route through Gate 3 (charter, "Routing of results").
**Frozen commit:** 289d57c (worktree `C:/tmp/ws22-b`). Code is cited as
`R/file.R:function` at that commit; rules as `PIT-xx-xxx` (`inventory.csv`),
findings as `S2-xxx`, `M1`, `M2` (`stage2/`), Stage 1 probes as `P1`..`P13`,
`W1`..`W4` (`map.md`).
**Inputs:** charter; `map.md`; `inventory.csv`; `path_matrix.csv`;
`stage2/findings.md` and `stage2/challenge.md`; Cut 12 draft (LDG-2993 to
LDG-3009, `tickets.yml`); the frozen `yardstick.md`; the accepted availability
(2026-09-08), equity-settlement (2026-09-24), terminal-outcomes (2026-10-05)
and v11 historical-projection (2026-09-28) syntheses; the history-wave register
(working; "binds nothing until stage 3", so every row, decided or pending, is a
plan); `decisions.md`; `contracts.md`; the macro plan; `horizon.md`; ledgr-research
`Universe-Construction-Boundaries.md` and `ledgr-feedback.md` (read only,
ownership context and LFB matches).
**Probes:** none new. Every behavioral claim rests on a Stage 1 or Stage 2
probe or on an exact code or document citation. Claims about planned behavior
cite the plan, not the code.
**Classes:** defect (ticketed in Cut 12, or new), design debt (shipped choice
weaker than it should be), planned capability (an accepted plan owns it), true
external gap (no plan covers it and it matters). Severity is for the release
goal (macro plan: long-window point-in-time portfolio research plus one public
long-only estimator strategy).

## 1. Design conformance (question a)

Status headers checked: the four syntheses are Accepted; the register is a
working record; `decisions.md` is an index whose linked sections bind. Rows 12
and 13 are binding changes of the availability synthesis that later accepted
decisions superseded, and `contracts.md` records both.

| # | Divergence (as-is against design) | Design source | Planned or drift | Route |
| --- | --- | --- | --- | --- |
| 1 | Calendar coverage over the requested range is not checked; `ledgr_sessions_incomplete` does not exist; a short calendar ends a run DONE and complete (S2-005, PIT-04-008) | availability s3 | drift | LDG-2998 |
| 2 | `ledgr_backtest()` runs dense on a point-in-time snapshot (S2-004, PIT-03-002) | availability s3 ("declared, never inferred"); Execution Contract | drift | LDG-3001 |
| 3 | Unknown-subtype rows and dense cash acquisitions never act and report fidelity `none`; a strict cash or quantity refusal aborts FAILED instead of stopping (S2-003 D1, M1, S2-009) | equity-settlement s3.3, s3.4 ("Strict mode stops"), s3.5 | drift | LDG-2996, LDG-2997 |
| 4 | Resume and the summary bind dividend entitlement after the ex-date open fill (S2-001, PIT-10-008, PIT-10-021) | equity-settlement s3.4 rule 2 | drift | LDG-2993 |
| 5 | A run that values no pulse finalizes by dense replay and loses its prefix (S2-002, PIT-11-003) | availability s7.4; Persistence Contract | drift | LDG-2994 |
| 6 | `config_hash` binds store-local `snapshot_id`, not content (S2-016, PIT-14-006) | availability s9.1 | drift | LDG-3004 |
| 7 | `summary()` and `print()` never label assumption-backed knowledge; only `ledgr_experiment_plan()` does (PIT-02-006, probe P6; `assumption_backed` appears only in `R/availability-policy.R:ledgr_experiment_plan`) | availability s4.2: "`summary()`, `ledgr_experiment_plan()`, and the survivorship article label such results as assumption-backed" | drift: the Availability Contract narrowed the rule to the plan without a recorded decision | new, G-007 |
| 8 | Valid off-session bars seal, are excluded at runtime, and appear in no retrospective view; the ingest report is discarded on success (PIT-01-005, PIT-02-003, PIT-04-010, probe P11) | availability s4.4: such rows "stay stored, are excluded from that cutoff's runtime input, and are visible in retrospective views" | drift (exclusion conforms, visibility does not) | new, G-008 |
| 9 | Mark history starts at the window's first pulse, so a carried or opening holding without a first-pulse bar has no mark (PIT-09-005, S2-007 iii) | availability s7.3 (stale mark "from its last accepted close"), s5.4 | drift, now planned (register PIT-S2-007) | history wave, G-015 |
| 10 | Feature, hydration and execution start at the scoring start (PIT-04-014) | availability s8; v11 s3 | planned (Cut 9 temporary rule; register A and B accepted) | history wave, G-015 |
| 11 | Expected sessions are not narrowed by `known_inactive` lifetime (PIT-06-002) | availability s4.1 | planned (v11 s4: LDG-2866/2867 pinned the fixed axis; narrowing scheduled in WS3) | history wave |
| 12 | The rebalance helper skips an unpriced member (`sizing_unavailable`) instead of failing typed (PIT-07-011) | availability s6.5 | superseded by Cut 10 LDG-2973 (Availability Contract, "Unpriced members") | none |
| 13 | Exhausted marks freeze by default instead of stopping (PIT-09-009) | availability s7.4 | superseded by terminal-outcomes s3.3 | none |
| 14 | A scheduled acquisition disposes at the mark, not at its sealed cash terms (PIT-10-012) | terminal-outcomes s3.2 amendment; equity-settlement s3.4 table | conforms; design debt against the yardstick | G-010 |
| 15 | An interval membership end applies at its effective time even when learned later | register D5-F1 (decided: document intervals as single-clock) | planned; no contract sentence yet | history wave, G-017 |
| 16 | Corporate-action rows without a knowledge time never act (S2-003 D2, PIT-10-006) | register C, D1-F7 (assume known-when-effective, disclosed); LFB-013 | planned | history wave, G-016 |
| 17 | A superseded status row revives after its superseder ends (PIT-03-014) | register D2-F3 (pending) | planned | history wave, Session F |
| 18 | Promotion checks only the snapshot hash (S2-006, PIT-13-007) | availability s7.4; Sweep Promotion Contract | drift; decided warn and record | LDG-3005 |
| 19 | Pulse inspection ignores status and lifetime planes (S2-012 after challenge) | availability s5.5; Strategy Contract, Decision Axis And Eligibility | drift | Gate 2: LFB-006, LFB-022 |
| 20 | Context field lists omit `risk_mark` and `mark_source`; partial status coverage is unstated in contracts (S2-017, S2-018 residual) | availability s3 table; Context Contract | contract drift | LDG-3009 |
| 21 | Fact Dates and date-only windows are UTC days, not venue days (S2-011) | none binding (the Snapshot Contract maps daily bar labels only) | open, planned | history wave, G-018 |

Answer to (a): no divergence is unexplained. Every code divergence from an
accepted synthesis is either ticketed in Cut 12 or routed by Gate 2, except
two disclosure drifts (rows 7 and 8), which are new. Row 7 matters more than
its size: the reference Sharadar adapter emits membership with
effective = knowledge = an assumed availability instant (adapter survey s1),
so a public result can read as evidenced point-in-time research while the
summary says nothing about the assumption.

## 2. Yardstick coverage (question b)

Owner is the yardstick's. For Data-owned rows the verdict answers "does ledgr
let an adapter meet it, and does it surface a violation". Verdicts describe
289d57c; "Cut 12" marks rows whose gap is already ticketed.

| ID | Owner | Verdict | ledgr evidence | Gap |
| --- | --- | --- | --- | --- |
| U1.1 | Data | partly met | half-open `[effective_from, effective_to)` plus `knowledge_time` on every fact (PIT-01-001, PIT-03-007); a Date clock means UTC midnight, not the venue session (PIT-01-019, S2-011) | G-018 |
| U1.2 | Engine | partly met | a fact applies only when `max(effective_from, knowledge_time) <= t` (PIT-03-007; BBB a nonmember at s9); an interval end is single-clock, so a removal learned late applies early (register D5-F1) | G-017 |
| U1.3 | Data | met | `assume_effective` fills knowledge from `effective_from`, recorded in hashed family metadata (PIT-01-002, PIT-14-005); facts with neither clock are audit-only and never apply (PIT-01-003) | G-007 (disclosure) |
| U1.4 | Data | partly met | complete sets carry former members (PIT-01-015); a member without a bar is an NA row and is skipped (PIT-04-010, PIT-07-011); nothing counts member-sessions with neither bar nor status | G-024 |
| U1.5 | Research | partly met | a character universe is a fixed basket by contract (Availability Contract; PIT-03-005); only the plan names the universe kind | G-007 |
| U1.6 | Data | met | open intervals are `NA` ends (PIT-01-001); ledgr invents no event from a date | - |
| U1.7 | Data | partly met | identity is the exact `instrument_id` (PIT-14-001), so an adapter can link series; a remove/add pair on a held ID becomes a disposition at mark (OOO, map s10), not a no-op | G-019 |
| U1.8 | Engine | met | removal never liquidates; the held nonmember stays on the axis, valued and reducible (PIT-03-012, PIT-07-003; NNN in P1, P6) | - |
| U2.1 | Data | partly met | terminal = `known_inactive` row with an exact `terminal_event` label (PIT-01-014, PIT-10-014); terms in corporate-action rows (PIT-01-017); a held ID whose bars stop without a lifetime fact freezes with a warning (PIT-09-009, PIT-12-009); an unheld one is silent; no public lifetime reader (PIT-03-019) | G-023 |
| U2.2 | Data | met | ledgr consumes no delisting returns; terms carry validated flags, `complete` and one closed refusal reason (equity-settlement s3.2); non-positive prices refused after LDG-2999 | - |
| U2.3 | Engine | not met | dispositions use the mark, never contractual cash (PIT-10-012: CCC at 49.80 against 50.00 terms); stock legs and recipients never booked (PIT-10-011); reported as `unsupported` with omitted value (PIT-10-020) | G-010, G-019 |
| U2.4 | Engine | partly met | equity = cash + marked positions at every pulse (PIT-09-006); a terminal posts one DISPOSITION (PIT-10-016); without a terminal fact a dead holding is frozen at its last close indefinitely, disclosed with `total_return_if_frozen_worthless` (terminal-outcomes s3.3, s4) | accepted design; G-023 |
| U2.5 | Engine/Research | partly met | exact-label `held_terminal_position` map in versioned identity (terminal-outcomes s3.2); assumed outcomes counted and warned (PIT-10-022, PIT-12-009); no P&L under an alternative policy | G-021 |
| U2.6 | Data | met | `quotation_only` status and `known_inactive` lifetime are distinct facts (PIT-01-013, PIT-01-014); an OTC-only bar never fills (PIT-08-002) | G-022 (exits) |
| U2.7 | Engine | met | no standing order exists (availability s6.7); `known_inactive` blocks fills; a missing bar is `execution_bar_missing` (PIT-08-002, PIT-08-004) | - |
| U3.1 | Data | partly met | the supported basis is `split_adjusted` (PIT-02-005; Sharadar adapter); no split event exists for as-traded bars; an undeclared basis runs (PIT-02-004) | G-009, G-019 |
| U3.2 | Engine | partly met | fills and marks use sealed bars in their basis (PIT-08-008); under `split_adjusted`, level rules and integer sizing read back-adjusted levels | G-009 |
| U3.3 | Engine | partly met | no split subtype acts (only five subtypes act, PIT-10-001); NAV continuity holds only because bars are pre-adjusted | G-009, G-019 |
| U3.4 | Engine | partly met | entitlement bound before the ex-date open fills, cash at the ex-date close (PIT-10-005, PIT-10-007), which is the yardstick's rule; resume binds differently (S2-001), Cut 12 | G-001 |
| U3.5 | Engine | not met | spin-off children never credited (PIT-10-011: III keeps 10, no JJJ); reported `unsupported` | G-019 |
| U3.6 | Data | met | all state keyed by `instrument_id` (PIT-14-001); ledgr does no ticker join | - |
| U4.1 | Data | partly met | trading status is distinct from a missing bar (PIT-03-013, PIT-05-004); no bar-type field (carried, zero-volume) exists (LFB-027) | G-020 |
| U4.2 | Engine | partly met | status, lifetime and bar gates (PIT-08-002, PIT-08-004); no volume check, so a zero-volume printed bar fills (v11 s2; LFB-027) | G-020 |
| U4.3 | Engine | partly met | last observed close with `mark_age` on the session clock (PIT-09-001, PIT-09-002); stale diagnostics (PIT-09-012) and valuation headline (PIT-12-008); mark history restarts at each window (PIT-09-005) | G-015 |
| U4.4 | Engine | partly met | strict features never bridge a gap: NA, no zero return (PIT-06-003); portfolio returns over a stale mark are zero by construction; accepted v11 price-input carry, on by default, would put zero returns into return features | G-013 |
| U5.1 | Data | partly met | sealed calendar required, one row per civil date, qlcal provenance (PIT-04-001, PIT-03-003); off-session bars seal and vanish (PIT-01-005); short calendars and off-date instants are Cut 12 (S2-005, M2) | G-005, G-008 |
| U5.2 | Data/Engine | met | Date bar labels map to the session close (PIT-02-001); decisions at session closes, early closes included (PIT-04-006) | - |
| U5.3 | Engine | met | fills at the next open session across closures (PIT-04-007), windows and stale age count sessions (PIT-06-002, PIT-09-002); folds use calendar periods by design (register C11-F1 fixes the 31st) | - |
| U6.1 | Engine | met | decision at the close, fill at the next session open, stamped at the open (PIT-08-001); the terminal decision never executes | - |
| U6.2 | Engine | met | sizing from the decision close (PIT-07-012); declared whole-fill `insufficient_cash` rule (PIT-08-005) | - |
| U6.3 | Engine | partly met | accessors bounded to pulse and axis (PIT-05-005; Context Contract); facts only once knowable; exceptions: interval ends (D5-F1), a window-dependent clock refusal (PIT-10-003), the sampled causality check never runs (register D4-F5) | G-012, G-017 |
| U6.4 | Engine | met | equity at closes, fills at opens: close-to-open P&L accrues to the pre-fill book by construction (PIT-08-001, PIT-09-006) | - |
| U6.5 | Engine/Research | partly met | restricted IDs held, flagged, never filled at a stale price (PIT-07-002, PIT-08-008); one fixed policy, no carry and no redistribution (PIT-07-011, availability s6.7); exits blocked under `quotation_only` (PIT-08-002) | G-022 |
| U6.6 | Research | met | `ctx$members` and the admissible plane are the as-of set (PIT-05-002, PIT-07-009, PIT-07-015) | - |
| U6.7 | Data | not applicable | no non-price fact channel; binding only when one is added | - |
| U7.1 | Engine | met | per-instrument strict windows: NA until `stable_after` complete sessions (PIT-06-003) | - |
| U7.2 | Engine/Research | met | one explicit rule (`strict_window`, invalidate) inside feature identity (PIT-06-001, PIT-06-007); must be rebound when v11 carry lands | G-013 |
| U7.3 | Research | partly met | features ignore membership and use pre-entry bars (PIT-06-005); history is cut at the scoring start (PIT-04-014); dense mode refuses incomplete coverage (PIT-04-009) | G-015, G-011 |
| U8.1 | Engine | met | train end must precede test start (`R/walk-forward-folds.R:ledgr_walk_forward_validate_fold_boundaries`); selection metrics have no label horizon, so purge and embargo do not arise | - |
| U8.2 | Engine | met | training sweeps use the same knowable-at-t rule on their window; selection only from DONE training rows (PIT-13-009) | - |
| U8.3 | Research | met | objective and selection rule enter walk-forward `session_id` (availability s9.1) | - |
| U8.4 | Engine | partly met | `opening_state_policy` is explicit and in identity (PIT-13-011, PIT-13-012); `carry_test_state` is not one run: last decision dropped, a `next_open` dividend lost, mark history lost (S2-007) | G-014 |
| U8.5 | Engine/Research | partly met | every candidate row persists with identity and status (PIT-13-003, PIT-13-006); return series only under `ledgr_sweep_retention(returns = "completed")` (default `"none"`) | no action: opt-in, memory |
| U9.1 | Data | met | hash rule 2 covers every fact row, header and recorded assumption (PIT-14-005; Snapshot Contract) | - |
| U9.2 | Data/Engine | partly met | valuation, cash-posting, terminal and corporate-action policies enter identity (PIT-14-007, PIT-10-017); a declared price basis enters `config_hash` (PIT-14-008); an undeclared basis and assumed knowledge never reach results | G-007, G-009 |
| U9.3 | Engine | partly met | config, strategy and parameter hashes, seed, ledgr and R versions recorded (`R/run-registration.R`, `R/strategy-provenance.R`); binds `snapshot_id`, not content (S2-016), Cut 12 | G-006 |
| U9.4 | Engine | partly met | FILL, FEE, CASHFLOW, DISPOSITION events plus reason-coded diagnostics; universe planes are rebuilt from sealed facts by design (availability s9.3); reconstruction fails after a post-prefix fill (S2-008), Cut 12 | G-003 |
| U9.5 | Engine | partly met | resume refuses a config, snapshot or timing mismatch (PIT-11-010); interrupts at s15, s19, s23 reproduce exactly (P4); dividend and first-pulse-stop cases diverge (S2-001, S2-002), Cut 12 | G-001, G-002 |

Counts: met 19, partly met 26, not met 2 (U2.3, U3.5), not applicable 1
(U6.7). Once Cut 12 lands as drafted, U3.4, U9.3, U9.4 and U9.5 become met
(23 met, 22 partly). Both "not met" rows are exact-quantity settlement, a
declared v0.2.2 non-goal (macro plan s5) that ledgr reports as `unsupported`
rather than hides.

Optional capabilities (present, partial, absent; does it matter for the
release goal):

| ID | ledgr | Matters |
| --- | --- | --- |
| C1.1 announcement table | partial: every fact has a knowledge clock; announced-not-effective membership is not visible (register D1-F6 refuses s > t) | no: effective membership is the conservative default |
| C1.2 bitemporal corrections | absent: one vintage per snapshot; lifetime corrections deferred (D5-F2) | no |
| C1.3 staged knowledge | partial: complete sets dated by knowledge time | no |
| C2.1 OTC exit | absent: `quotation_only` blocks fills | no |
| C2.2 elections | absent | no |
| C2.3 settlement receivable | absent: disposition cash is immediate | no |
| C2.4 delisting notices as signals | absent | no |
| C3.1 spin-off tax lots | absent (FIFO only) | no |
| C3.2 dividend receivable | absent: `effective_close` posts at the ex-date close, disclosed (equity-settlement s3.4) | no |
| C3.3 declaration-date knowledge | partial: corporate-action rows carry `knowledge_time` | no |
| C3.4 forward-adjusted series | absent | no |
| C3.5 reconciliation harness | absent | yes, as release evidence (G-025) |
| C4.1 intraday halts | absent | no (daily) |
| C4.2 stale-mark escalation | partial: freeze after `max_sessions`, frozen terminal `write_off`, worthless bound | no |
| C4.3 limit-locked | absent | no (US) |
| C5.1 announced closures only | absent: the sealed calendar is fully known | no |
| C5.2 early-close cut-offs | not applicable: early closes are pulses | no |
| C6.1 same-close fills | absent by design | no |
| C6.2 costs and turnover | partial: fixed, notional-bps and spread steps; no turnover reader found | low |
| C7.1 auto warm-up | planned: register B, every indicator starts at the data start | yes (WS7) |
| C8.1 purged k-fold, CPCV | partial: `ledgr_pbo()` | no |
| C8.2 rolling and anchored | present: `ledgr_folds_rolling()`, `ledgr_folds_anchored()` | present |
| C8.3 DSR, PBO, SPA | present: `ledgr_dsr()`, `ledgr_pbo()`, `ledgr_effective_trials()`; SPA absent | no |
| C9.1 cross-platform tolerance | absent: byte identity is claimed on a fixed platform only | no |

Where the yardstick over-reaches or conflicts with itself (one line each):

- U4.3 and U4.4 conflict at portfolio level: a stale mark (U4.3) makes the
  holding's return zero for each stale session, which U4.4 forbids. U4.4
  should be scoped to per-instrument statistics and estimator inputs; that is
  how this review applies it.
- U8.1 makes purging and embargo universal. They protect label-based
  cross-validation; backtest-metric walk-forward with ordered, non-overlapping
  windows has no label interval to purge. Over-reach for a backtest engine.
- U1.5 asks validation to fail on any universe whose membership never varies.
  Fixed baskets (ETFs, a declared list, crypto) are legitimate; disclosure, not
  refusal, is the right engine duty.
- U3.1 forbids a back-adjusted file as the only price source. A split-adjusted
  share-unit model is internally consistent for value accounting; what breaks
  is level rules, per-share costs and integer lots (U3.2), and vintage pinning
  (U9.1) already covers reproducibility. The guarantee should be "as-traded or a
  declared, enforced adjusted-unit model".
- U5.3 requires fold lengths in sessions. Calendar-month folds are a normal
  research choice; what matters is that each boundary resolves to sessions
  deterministically.
- U2.5 requires P&L under an alternative policy in every run. That is a
  sensitivity capability; count and weight at exit are the correctness core.
- U2.1's `settlement_status` enumeration is a vendor-shaped taxonomy; ledgr's
  exact-label map plus corporate-action completeness carries the same
  information without ledgr interpreting vendor reasons, which the
  terminal-outcomes synthesis (s8) rightly rejects.
- U9.5 notes that no finance source requires bit-identity; ledgr's claim
  exceeds the yardstick, which is fine.

## 3. Gap register

| ID | Class | Sev | Description | Evidence | Route |
| --- | --- | --- | --- | --- | --- |
| G-001 | defect, ticketed | high | Resume binds dividend entitlement after the ex-date open fill; interruption changes cash | S2-001; U3.4, U9.5 | Cut 12 LDG-2993 as drafted |
| G-002 | defect, ticketed | high | A run that values no pulse finalizes by dense replay; prefix lost, run unopenable, walk-forward session unrerunnable | S2-002, W4; U9.5 | Cut 12 LDG-2994 |
| G-003 | defect, ticketed | medium | Reconstruction fails after a post-prefix fill | S2-008; U9.4 | Cut 12 LDG-2995 |
| G-004 | defect, ticketed | high | Unmodeled held corporate actions never act and read `none`; strict refusals abort FAILED | S2-003 D1, M1, S2-009; U2.1, U3.x surfacing | Cut 12 LDG-2996, LDG-2997 |
| G-005 | defect, ticketed | medium | Ingest guarantees the runtime assumes: calendar range, positive prices, session instants | S2-005, S2-010, M2; U5.1 | Cut 12 LDG-2998, LDG-2999, LDG-3000 |
| G-006 | defect, ticketed | medium | Entry-point and identity consistency: `ledgr_backtest()`, `snapshot_id` in identity, promotion identity, locale ties, metrics on INCOMPLETE | S2-004, S2-016, S2-015, S2-006, S2-013, S2-014; U9.3 | Cut 12 LDG-3001 to LDG-3005 |
| G-007 | defect, new | medium | Results never disclose that knowledge clocks were assumed, or that a fixed basket ran on a snapshot with membership facts; availability s4.2 binds `summary()` to label assumption-backed runs | PIT-02-006 (P6); `R/availability-policy.R:ledgr_experiment_plan` is the only labeller; U1.3, U1.5, U9.2 | Cut 12 amendment (WS25): one result line and structured field naming assumption-backed families and the universe kind; history-wave D1-F7 then extends the same field to corporate actions |
| G-008 | defect, new | low | Valid off-session bars seal and vanish; no retrospective view or count, against availability s4.4 | PIT-01-005, PIT-02-003, PIT-04-010 (P11); U5.1 | Cut 12 amendment (WS24, whose claim is "refused or reported, never silently ignored"): persist the count, or refuse such bars when sessions are declared |
| G-009 | design debt | medium | ledgr's accounting assumes split-adjusted share units (no split event acts), but an undeclared basis runs and no contract states the model; as-traded bars across a split book a phantom loss with no signal unless a split fact is supplied; under `split_adjusted`, level rules and integer sizing read back-adjusted levels | PIT-02-004 (contract: none), PIT-10-001; U3.1 to U3.3, U9.2 | Cut 12 amendment: contract sentence plus plan and summary disclosure; Gate 3 decides whether an availability-aware experiment must declare a basis |
| G-010 | design debt | low | A complete, validated cash-acquisition row disposes at the mark, not at its contractual cash; only the difference is reported | PIT-10-012; equity-settlement s3.4 table; U2.3 | exact-quantity RFC (pipeline row `exact-equity-quantity-settlement`); no v0.2.2 action (the Sharadar adapter emits no scheduled rows) |
| G-011 | design debt | low | Dense mode refuses any basket with incomplete bars, which steers users to survivor-only baskets; the error does not name the point-in-time path | `R/backtest-runner.R:ledgr_run_fold_impl` (`ledgr_missing_bars`), PIT-04-009; U7.3, U1.4 | Cut 12 amendment (message hint) or no action |
| G-012 | design debt | low | Corporate-action clocks must land on a pulse inside the run's range or the run refuses at start, so validity depends on the window and on a fact the decision cannot yet know; a later-knowable row can refuse an earlier window | PIT-10-003; Availability Contract ("must not rewrite earlier ... errors"); U6.3 | history wave, with the window rules of PIT-S2-007; or move the check to sealing |
| G-013 | planned capability | medium | v11 price-input carry (on by default, five sessions) will fill gaps with repeated prices, so return and volatility features see zero returns on carried sessions; WS7's minimum-variance estimator reads `daily_return` and keeps such instruments (`na_action = "drop_instruments"` drops only NA), understating their variance and covariance; it also reintroduces, for features, the carried prices the adapter drops for LFB-027 | v11 s5; research UX brief "Weights return to the current context"; register B2; U4.4, U7.2 | history wave scope change (stage 3 amendment): return-family inputs bridge last valid to next valid or are not carry-eligible by default, and the carried-share evidence travels with the history result; WS7 acceptance checks it |
| G-014 | planned capability | medium | `carry_test_state` is not one run with parameter switches: the last decision of each test window is dropped, a `next_open` dividend is lost, mark history is lost | S2-007 (i) to (iii), W1, W4; U8.4, S36 | history wave scope change: the register routes (ii) and (iii) only; include (i) and adopt "continuous carry equals one run" as the acceptance test, or state the non-equivalence in the Execution Contract |
| G-015 | planned capability | medium | Features, hydration and marks start at the window start; carried holdings and new entrants lose pre-window history | PIT-04-014, PIT-09-005; register A, B, PIT-S2-007; U4.3, U7.3 | history wave (decided); the amendment must name mark history beside feature history |
| G-016 | planned capability | high | Corporate-action rows without a knowledge clock never post, and the reference adapter supplies no corporate-action facts; public Sharadar results therefore omit dividends (disclosed "NOT SUPPLIED"), a bias that plausibly falls hardest on low-volatility, high-yield names, the ones a minimum-variance proof selects (inference) | S2-003 D2, PIT-10-006; register D1-F7; LFB-013; macro plan s6 item 2; U3.4 (Data side) | history wave (D1-F7 implementation) plus a research-side adapter task; WS7's public proof runs with dividend facts or states the exclusion in its headline |
| G-017 | planned capability | low | Interval membership is single-clock; a removal learned after its effective date leaks at the effective date | register D5-F1; LFB-012; U1.2, U6.3 | history wave: write the contract sentence; the reference adapter uses snapshot sets |
| G-018 | planned capability | low | Fact Dates and date-only windows are UTC days; harmless for New York closes, wrong for venues closing after UTC midnight | S2-011; PIT-01-019, PIT-04-012; U1.1 | history wave (register PIT-S2-011) |
| G-019 | planned capability | medium | No exact-quantity settlement: stock and mixed acquisition legs, spin-off children, splits as events and redomicile links are not booked; reported `unsupported` with omitted value | PIT-10-011, PIT-10-001; equity-settlement s2; LFB-011; U1.7, U2.3, U3.3, U3.5 | RFC (pipeline row); v0.2.2 non-goal; keep the release claim that recipient value is omitted |
| G-020 | planned capability | low | No bar-type flag and no volume gate; zero-volume printed bars fill | LFB-027; v11 s2; U4.1, U4.2 | research adapter drops carried bars (decided); residual to the execution-policy pipeline row; release DoD item 9 stays |
| G-021 | planned capability | low | No terminal-policy sensitivity in results | U2.5 | horizon 2026-10-04 "Sweeping experiment assumptions" |
| G-022 | planned capability | low | One fixed untradable-target policy; exits from `quotation_only` holdings are blocked | PIT-08-002; U6.5 | horizon 2026-09-29 "Design homework"; OMS RFC |
| G-023 | planned capability | low | No public status or lifetime reader, so an adapter cannot audit terminal coverage before running | PIT-03-019; LFB-021; U2.1, U4.1 | horizon 2026-09-25 "Availability evidence has no convenient reader" |
| G-024 | true external gap | low | No report of member-sessions with neither a bar nor a status row, the cheapest signal that an adapter broke U1.4 | PIT-04-010, PIT-07-011; U1.4 | horizon; candidate for the WS3 structural-completeness query |
| G-025 | true external gap | low | No reconciliation of buy-and-hold equity against a vendor total-return series, the only external check on corporate-action accounting | C3.5 | WS8 integrated evidence: one buy-and-hold reconciliation on the Sharadar build against `closeadj` |

Counts: defect 8 (6 ticketed: 3 high, 3 medium; 2 new: 1 medium, 1 low);
design debt 4 (1 medium, 3 low); planned capability 11 (1 high, 4 medium, 6
low); true external gap 2 (2 low). By severity: high 4, medium 9, low 12.

LFB register checked: G-016 matches LFB-013; G-019 LFB-011; G-020 LFB-027;
G-023 LFB-021; G-017 LFB-012; G-007 extends no existing entry. No new LFB
is proposed; G-007, G-008, G-009, G-011 are ledgr-side.

## 4. Recommendations for Gate 3

**What the audit says overall.** The point-in-time core is sound against the
yardstick's highest-ranked failure modes: membership as of the session with
knowledge bounding (rank 1, 7), fills strictly after the information (rank 2),
no leakage through the strategy context, declared terminal policy instead of
last-price exits (rank 5), pinned content-addressed inputs (rank 8), and
stable-ID keying (rank 9). The weak ground is economic completeness of supplied
events (exact-quantity settlement, cash terms, dividends that never arrive),
recovery edges (all in Cut 12), and disclosure. Nothing found requires a new
design wave beyond the history wave.

**Order.**

1. Cut 12 as drafted (G-001 to G-006), recovery first, as its sequencing says.
   Add three small amendments, all inside the cut's existing claims: G-007
   (assumption and universe disclosure in results, WS25), G-008 (off-session
   bars reported or refused, WS24), G-009 (price-basis contract sentence and
   disclosure, WS25). G-011 is an optional message hint. None changes a
   ticket's acceptance shape; each needs its own probe flip.
2. Gate 3 decides G-009's open question: should an availability-aware
   experiment refuse an undeclared price basis? Recommendation: yes, since
   v11 already treats "undeclared" as a distinct barrier state and the cost is
   one argument for adapters.
3. Resume the history wave with a widened scope (below).
4. WS7 acceptance adds two checks: the estimator sample on carried inputs
   (G-013) and the dividend status of the run (G-016).
5. WS8 adds the reconciliation record (G-025).
6. Leave G-010, G-019 (exact-quantity RFC), G-020 (execution policy), G-021,
   G-022, G-023, G-024 on their routes; none blocks the release goal, and each
   is disclosed in results today or after Cut 12.

**History-wave scope: changes recommended.**

- Add (G-013): the stage 3 amendment binds how v11 input carry meets return
  and volatility features. Either return-family features bridge a gap from the
  last valid to the next valid observation (the yardstick's U4.4 and S17), or
  input carry is off by default for them; in both cases the carried share
  travels with the history result and WS7 consumes it. As accepted, v11 carry
  silently converts a halt the adapter exposed (LFB-027) back into flat prices
  for every estimator. This is the one place where an accepted plan, not the
  code, is what the yardstick would fail.
- Widen PIT-S2-007 (G-014): include part (i), the dropped final decision, and
  choose between "continuous carry equals one run with scheduled parameter
  switches" (handing the last decision to the next window's first open) and
  an explicit Execution Contract statement that carry chains are not
  equivalent. The challenger kept (i) as "context" because each rule is
  stated; under the yardstick (U8.4, S36) the combination is the defect.
  Add G-012 to the same session, since both are window-boundary rules.
- Bind G-015 explicitly: the history-start decision covers mark history and
  dividend entitlement, not only features (register A says "strategy reads").
- Keep (no change): D5-F1 as documentation (G-017), D1-F7 (G-016, now known
  to gate the release's dividends), S2-011 (G-018), Sessions D, E, F.
- Session E caution: C11-F2 proposes trimming the per-member decision trace.
  U9.4 needs every decision recoverable; trimming is safe only if omitted rows
  are exactly reconstructible (for example "held, no target change") and
  `ledgr_run_explain()` still answers for them.
- Do not add bitemporal membership (C1.2), announcement tables (C1.1) or
  exact-quantity settlement to the wave; the yardstick itself classes the
  first two as optional, and the third is a declared non-goal with honest
  reporting.

**Not ledgr's to fix, but release-relevant.** The reference adapter supplies
no corporate-action facts and constructs its membership knowledge clocks equal
to the effective instant. ledgr surfaces the first ("NOT SUPPLIED") and, after
G-007, will surface the second. The public estimator proof should not be
published as evidenced point-in-time research until both are either supplied
or named in its headline.
