# RFC Seed: Terminal Outcomes for Untradable Holdings

**Status:** Seed v1, non-binding. Stage 2 of the RFC cycle; a response by a
different author is next.
**Author:** Claude, for the maintainer, 2026-10-04.
**Pipeline row:** [`terminal-outcome-policy`](README.md#terminal-outcome-policy)
(Due). Macro plan:
[v0.2.2 WS2](../ledgr_v0_2_2_spec_packet/macro_plan.md#ws2-terminal-gap-and-execution-usability).

**Inputs:**
- probe: `dev/spikes/terminal-outcomes/probe_findings.md`, executed at
  `a5443f3`;
- prior art: [`research/Terminal-outcome_prior_art.md`](../research/Terminal-outcome_prior_art.md),
  read through its 2026-10-04 amendments;
- the accepted
  [equity-settlement synthesis](rfc_equity_settlement_post_v0_2_0_2_synthesis.md),
  Sections 3.3-3.5;
- [`contracts.md`](../contracts.md), Availability, Persistence and Result
  Contracts.

## 1. Problem

A held instrument can become untradable: it is delisted with no settlement
evidence, halted past the valuation horizon, or its bars simply stop. Today
ledgr then **stops the whole run** and finalizes `INCOMPLETE` with only the
accepted prefix. The probe executed every case on the current tree:

| Probe case | Today's outcome |
| --- | --- |
| R1: delisting, no evidence | `INCOMPLETE`, `terminal_settlement_unsupported`; 3 of 10 sessions kept |
| R2: acquisition fact, research preset | `DONE`; `DISPOSITION` at last close (`last_permissible`) |
| R2: acquisition fact, strict preset | `INCOMPLETE`, `terminal_settlement_unsupported` |
| R3: known halt beyond `ledgr_valuation_stale(2)` | `INCOMPLETE`, `valuation_horizon_exhausted` |
| R4: exit attempted during the halt | `no_fill:trading_halted`, not queued; then exhausted |
| R5: bars stop, no fact | `INCOMPLETE`, `valuation_horizon_exhausted`, identical to R3 |

The unaffected instrument's path is lost in every stopping case. Downstream,
the stopped variant disappears silently:
- `ledgr_run_compare()` drops it by default and refuses it when named;
- the sweep footer counts it nowhere ("2 combinations: 1 done, 0 failed");
- review lists it without a stop reason;
- filtering, effective-trial counts and DSR never see it, because retention
  keeps completed candidates only;
- walk-forward selects the survivor and says nothing.

This is survivorship bias at strategy level, the bias point-in-time machinery
exists to prevent. The governing principle stays: **never fabricate
settlement**. What is missing is a declared, disclosed way to represent the
outcome instead of stopping.

## 2. Maintainer decisions (2026-10-04)

1. Scope is one concept, the **untradable holding** (Section 3).
2. Evidence always outranks assumption.
3. A closed menu of declared outcomes, with **opinionated defaults**; peer
   parity is acceptable.
4. Defaults must keep ledgr usable. Every default used must be recorded and
   shown, and changeable with one argument. Experiment templates may later
   carry such defaults; this RFC must not block that, but does not design it.
5. Per-reason overrides are in scope.
6. Assumed exits book as ledger events, enter identity and are visibly flagged.
7. Scenario comparison is by separate runs. Sweeping experiment assumptions is
   parked as a broader design question.
8. Incomplete candidates stay visible and counted on every selection surface.
9. The exclusions in Section 9 stand.

## 3. The untradable holding

A position is **untradable** at the first pulse where ledgr would stop today
because of it:

- **Terminal trigger:** a sealed lifetime terminal (`known_inactive` with a
  `terminal_event`) takes effect while the position is held, and no supported
  settlement evidence covers it.
- **Horizon trigger:** the position's mark becomes impermissible under the
  declared `ledgr_valuation_stale(max_sessions)`, whatever the reason: a known
  halt (R3), unexplained missing bars (R5) or an exit with no execution bar
  (R4).

A halt or gap that resolves inside the horizon is not untradable and behaves
exactly as today. `risk_mark_unavailable` and reconciliation stops are not
untradable holdings and are unchanged.

## 4. Precedence: evidence, then policy

1. **Evidence.** Supported corporate-action facts settle through the existing
   path in equity-settlement Section 3.4. A supplied post-event price series is
   simply bars. Evidence never consults the untradable policy.
2. **Declared or defaulted policy.** Applies only where no evidence path
   settles the holding.

Exact-quantity settlement (recipient shares, basis transfer) keeps its own
pipeline row and is not changed here.

## 5. The policy menu

One experiment-level policy, `untradable_policy`, built by a constructor
(working name `ledgr_untradable()`) from closed sets like the six existing
policy constructors. Arbitrary callbacks are not accepted.

| Value | Outcome at the untradable pulse |
| --- | --- |
| `refuse` | Today's behavior: stop the run, preserve the prefix, finalize `INCOMPLETE`. |
| `last_permissible` | Dispose at the last mark that was permissible under the horizon. Refuse if no permissible mark ever existed. |
| `last_mark` | Dispose at the last known mark, whatever its age. Explicit opt-in. |
| `haircut(fraction)` | Dispose at `(1 - fraction)` times the last permissible mark. |
| `write_off` | Dispose for zero proceeds. |

**Per-reason overrides** map the sealed `terminal_event` (and any finer reason
a future fact family carries) to a value, for example
`acquired = "last_permissible", delisted = "write_off"`. The horizon trigger
has one value of its own, because it has no terminal reason. Named
literature-based presets, such as Shumway-style losses for
performance-related delistings, are a later convenience and never a default.

## 6. Defaults

**Proposed default: `last_permissible` for both triggers**, extending the
accepted equity-settlement default rather than replacing it.

That synthesis (Section 3.3) chose `last_permissible` for held terminal
positions. It rejected unbounded `last_mark` as a default because it
"suspends the staleness horizon for the one case where an instrument is least
likely to be worth its last price". The maintainer's peer-parity decision and
that accepted rule meet here:

- **Delistings.** QuantConnect LEAN liquidates at the last known price on the
  delisting date (prior-art amendment 2). A delisting usually follows the last
  bar closely, so `last_permissible` produces the same outcome as the peers in
  the common case. It reproduces probe R2, extended to R1.
- **Horizon exhaustion.** Disposal happens at the exhaustion pulse, valued at
  the last mark that was still permissible. Staleness of the disposal price
  is bounded by the declared `max_sessions`, so the horizon is ended, not
  suspended.
- **Zipline-style unbounded stale liquidation** remains the explicit
  `last_mark` opt-in, as the accepted synthesis requires.

The literature shows `last_permissible` is optimistic for performance-related
delistings: Shumway found -30% for NYSE/AMEX and Shumway & Warther -55% for
Nasdaq. That is why disclosure (Section 7) is mandatory rather than optional.

**Open for maintainer decision (D1):** if "peer parity" was meant to include
unbounded `last_mark`, the default must explicitly supersede equity-settlement
Section 3.3. The seed does not assume that.

**The strict preset** sets `refuse`, consistent with
`ledgr_corporate_actions_strict()`.

## 7. Results, identity and disclosure

- **Booking.** An assumed exit is one `DISPOSITION` event, reusing the
  asset-neutral event from equity-settlement Section 3.4, with proceeds per the
  policy and a source naming the policy value and trigger. It is not a fill
  and needs no execution bar. FIFO, cash, P&L and replay use the existing
  disposition path.
- **Completion.** The run continues past the disposal and finishes `DONE` with
  complete performance. The stop reason, prefix and `INCOMPLETE` semantics
  remain only for `refuse`.
- **Identity.** The resolved policy, including defaulted values and every
  override, enters experiment and run identity, as equity-settlement Section
  3.3 requires for its policy. A run never acquires a default implicitly.
- **Disclosure.** Following the `corporate_action_fidelity` pattern
  (Section 3.5), ordinary results carry a headline untradable-outcome field:
  - the count of assumed exits;
  - modeled proceeds as a figure;
  - the policy used, marked **default** or **declared**.

  It appears in `print()`, `summary()`, run comparison, the run list, sweep
  tables and `ledgr_experiment_plan()`, in the same way "Corporate actions:
  NOT SUPPLIED" already prints. No separate provenance system is added.

## 8. Selection visibility

With a non-refusing policy, affected candidates complete, carry their loss and
take part in selection like any other `DONE` candidate, flagged by Section 7.
Under `refuse`, every surface must show what it excluded:

| Surface | Required behavior |
| --- | --- |
| Sweep print | Counts `INCOMPLETE` separately: "2 combinations: 1 done, 1 incomplete, 0 failed". |
| `ledgr_sweep_review()` | Issue rows show the stop reason and affected IDs from `completion_json`. |
| `ledgr_run_compare()` | The default reports excluded incomplete runs instead of dropping them silently. Explicitly named runs keep the typed refusal. |
| Walk-forward | Each fold reports training candidates excluded as incomplete, in its scores and print. |
| Effective trials and DSR | Incomplete candidates count as attempted trials; the trial count never shrinks silently. |

Ranking, candidate extraction and promotion still exclude incomplete
candidates (Persistence Contract), because prefix metrics are not comparable.

## 9. Out of scope

- **Queueing exits during halts:** stays with the execution-intent session
  (D9). R4's "not queued" is unchanged here.
- **Instruments that keep trading OTC at prices the snapshot lacks:** named
  and parked. Supplied OTC bars are evidence under Section 4.
- **Shorts and leverage:** ledgr is long-only in v0.2.2.
- **Non-spot accounting events:** stay with the cross-asset accounting row.
- **A default stale horizon:** Availability Contract "no default stale
  horizon" is untouched. That is the separate defaults question in the
  2026-09-29 horizon entry.
- **Sweeping experiment assumptions and experiment templates:** parked.
- **Probe side finding:** a declared status family treats instruments with no
  status row as restricted. This is not a terminal-outcome question; route it
  separately if unintended.

## 10. Contract changes this would need

- **Availability Contract, stop-token table:**
  - `terminal_settlement_unsupported` and `valuation_horizon_exhausted` become
    stops only under `refuse`;
  - new tokens are needed for an assumed disposal at each trigger (working
    names `terminal_assumed_disposal`, `horizon_assumed_disposal`).
- **Persistence Contract:** completion semantics for assumption-backed `DONE`
  runs; resume and repeat verification of a run whose prefix includes an
  assumed disposal.
- **Result Contract:** the headline untradable-outcome field; the selection
  visibility in Section 8.
- **Equity-settlement Section 3.3:** its "held terminal position" row moves
  into, or is aliased by, `untradable_policy`. Pre-release, a move is
  acceptable; the response should check that no recorded policy string
  changes meaning, per Section 3.3's scope-versioning rule.

## 11. Questions for the response

- **D1, default.** Does the bounded `last_permissible` default satisfy
  "peer parity", or should unbounded `last_mark` explicitly supersede
  equity-settlement Section 3.3?
- **D2, policy home.** One new `untradable_policy` argument, or an extension
  of `corporate_action_policy` plus a horizon value in the valuation policy?
  The seed leans to one argument, because the probe shows one problem with two
  triggers.
- **D3, timing.** Terminal disposals at the terminal's effective pulse;
  horizon disposals at the exhaustion pulse. Should the cash post at that
  close or the next open, matching equity-settlement's posting choices?
- **D4, no mark ever.** For an opening position whose instrument never had a
  bar before its terminal, `last_permissible` and `haircut` have no base.
  Fall back to `write_off` (disclosed), or refuse?
- **D5, trial counting.** Effective trials cluster retained return panels,
  and incomplete candidates have none. Does "count as attempted trials" mean
  a floor on the reported trial count, a separate attempted-trial figure, or
  retaining prefix returns for incomplete candidates?
- **D6, staleness interaction.** Under a non-refusing default, the horizon
  trigger fires for genuinely bad data (R5) as well as real halts (R3). Should
  the disclosure distinguish "explained by a fact" from "unexplained gap"?

## 12. Evidence the cycle still owes

Every literature figure and peer behavior cited here must be checked against
its primary source before synthesis (prior-art amendments, "Unverified"). The
implementation packet needs:
- a gate fixture per trigger and per policy value;
- a resume witness across an assumed disposal;
- selection-surface witnesses reproducing probe S1, S2 and W1;
- exact accounting parity between an assumed disposal and an equivalent
  evidenced `DISPOSITION`.
