# Decision Register: WS3/WS4 History Wave

**Status:** Working register, opened 2026-10-08. Records the maintainer's
decision on every finding of the
[Type 2 review](rfc_history_wave_v0_2_2_review.md) of the
[proposal](rfc_history_wave_v0_2_2_proposal.md). Binds nothing until stage 3
writes the accepted decisions into an amendment.
**Owner:** maintainer decides; executor verifies and drafts.

## Stages

| Stage | What | Exit | State |
| --- | --- | --- | --- |
| 1 | Verify | Every finding's premise rerun or read at `8afd098`; result in the Verified column | open |
| 2 | Decide | Every row has a decision or a recorded deferral, in the order of the sessions below | open |
| 3 | Amend | One amendment to v11 (sections 3, 6, 7) carrying the accepted decisions under the amendment discipline in `../rfc_cycle.md`; `decisions.md` and `README.md` updated | open |
| 4 | Final review | Type 1 review of the amendment against this register | open |
| 5 | Ticket cut | WS3/WS4 cut in `tickets.yml`; cut review; pipeline rows leave `README.md` | open |

Values: Verified is `pending`, `confirmed`, `corrected` (premise partly wrong;
note says how) or `refuted`. Decision is `pending`, `accept`, `accept with
change` (note), `reject` (durable reason), `defer` (trigger) or `route`
(owner).

## Session A: what history a strategy sees

Decides everything after it. Amends v11 section 3.

| ID | Sev | Finding | Verified | Recommendation | Decision |
| --- | --- | --- | --- | --- | --- |
| X-F1 / D4-F2 | blocking | Public history axis undecided: a 252-day read at the first scoring pulse returns 251 NA; WS7 sees mostly NA in short test windows | pending | Option (a): history axis = prepared pulses from the hydration start; decision axis = scoring pulses; causal, s <= t | pending |
| D1-F6 | consider | The representation can answer s > t (facts known before effect) | pending | History API refuses s > t; columns are s <= t | pending |

## Session B: one hydration rule

| ID | Sev | Finding | Verified | Recommendation | Decision |
| --- | --- | --- | --- | --- | --- |
| D4-F1 | blocking | Two hydration rules create a per-feature clock identity and inspection cannot carry | pending | One rule: feature state starts at the snapshot start for every entry point and class; bounded shortcut only as a proven exact optimization | pending |
| D4-F3 | should-fix | Cut 9 oracle must flip to the carried arms; dense bounded parity is about 1e-12 under two rules | pending | Flip LTB-0196 expectations under the single rule | pending |
| X-F4 | consider | Pulse inspection reproduces hydration only under one rule | pending | Follows from D4-F1 | pending |
| X-F5 | consider | Sweep feature-matrix helper may take the dense path in availability mode (untraced) | pending | Trace before D4 binds | pending |
| D4-F4 | should-fix | History-dependent indicators are refused in availability mode, so WS7 on a PIT universe has no EMA/RSI/ATR/MACD | pending | Decide: v0.2.2 scope statement, or WS4 decides the gap rule | pending |
| D4-F5 | consider | `ledgr_check_no_lookahead` is never called; full-history hydration spreads a lookahead | pending | Sampled build-time causality check beside D3's refutation | pending |
| D4-F6 | consider | Stance on convergence for readiness and structural completeness | pending | `stable_after` stays first-valid; convergence undisclosed in v0.2.2 | pending |

## Session C: knowledge clocks the history must carry

| ID | Sev | Finding | Verified | Recommendation | Decision |
| --- | --- | --- | --- | --- | --- |
| D5-F1 | blocking | Interval membership end applies on its effective date though known a day later; honest encoding refused | pending (also verify the Sharadar adapter's interval shape) | Optional `end_knowledge_time` on interval facts, in WS3 | pending |
| D5-F2 | should-fix | Lifetime deferral needs v11 section 9's reopen trigger and precise wording (only opposing overlaps refused) | pending | Defer with trigger: acquisitions merged into bitemporal lifetime facts | pending |
| D5-F3 | consider | "Treats a correction as a later-known fact" is true of storage, not rules | pending | Reword | pending |
| D1-F7 | should-fix | Sessions and corporate actions as known at t uncovered; 82 CA backfilled in 16 hours | pending | Decide: extend segments to CA and sessions, or ship barriers at the diagonal with a stated reason | pending |
| X-F3 | should-fix | Carry barriers depend on lifetime and CA at t | pending | Name the dependency in the amendment | pending |
| X-F2 | should-fix | Feature-value revision (v11 7(d)) has no owner | pending | WS3 stance: one prepared series per feature and policy; revision unexercised in this release; keep v11 section 8 fixtures as an obligation | pending |

## Session D: indicator history class

| ID | Sev | Finding | Verified | Recommendation | Decision |
| --- | --- | --- | --- | --- | --- |
| D3-F1 | should-fix | `strict_window` already means bounded; the TTR default contradicts it | pending | strict_window implies bounded; refuse the contradictory pair | pending |
| D3-F2 | should-fix | TTR class belongs in the warmup rules table, per function | pending | Bounded SMA, WMA, ROC, CCI, BBands, ...; history-dependent EMA, RSI, ATR, MACD; verify each against TTR source | pending |
| D3-F3 | should-fix | Refutation belongs in the strict path, against the full series once | pending | Compare `fn(window_i)` with `series_fn(full)[i]` | pending |
| D3-F4 | consider | Refusal must name instrument, position and gap, with a product tolerance | pending | Accept | pending |
| D3-F5 | consider | Does `history_class` enter identity? | pending | Feature fingerprint beside `gap_contract` | pending |
| D3-F6 | consider | Define bounded testably | pending | A function of the last `stable_after` bars only | pending |
| I-F3 | consider | Spike B's 1e-9 is a 120-bar fixture tolerance | pending | State a basis for any product tolerance | pending |

## Session E: storage details and budget

| ID | Sev | Finding | Verified | Recommendation | Decision |
| --- | --- | --- | --- | --- | --- |
| D1-F9 | should-fix | Memory budget must be set before the representation is accepted | pending | Maintainer sets the WS3 budget in this session | pending |
| D1-F1 | should-fix | Size guard must be named, overridable, with recorded counts | pending | Accept | pending |
| D1-F2 | should-fix | Production build and read shape (spike shape is an antipattern) | pending | Per-instrument epochs, flat vectors, cursor re-seek, vectorised reads | pending |
| D1-F3 | should-fix | Merging equal states loses deciding-fact evidence | pending | Merge on (state, winning fact, reason) | pending |
| D1-F4 | should-fix | Membership has four states; parity oracle is the resolver plus `members_at` | pending | Accept | pending |
| D1-F5 | should-fix | Family declaration travels apart from rows | pending | Accept | pending |
| D1-F8 | consider | Diagonal parity needs a carve-out if the end clock lands | pending | Follows from D5-F1 | pending |
| I-F1 | should-fix | Evidence wording overclaims "no restatement" | pending | Guard exists because the shape is unmeasured | pending |
| I-F4 | consider | State what spike A discharged | pending | Accept | pending |

## Session F: correction chains

| ID | Sev | Finding | Verified | Recommendation | Decision |
| --- | --- | --- | --- | --- | --- |
| D2-F4 | consider | Route chains out of the WS3 wave | pending | Small facts ticket under the Cut 3 exact-byte oracles | pending |
| D2-F1 | blocking | Chain learned out of order: resolver says `conflicting` | pending | Constructor rule: superseder knowledge >= predecessor knowledge | pending |
| D2-F2 | should-fix | Exempt ancestor pairs, not whole components | pending | Accept | pending |
| D2-F3 | should-fix | Resolver revives a predecessor; ingest helper truncates it | pending | Superseder must cover its predecessor's interval; align the ingest helper | pending |
| I-F2 | consider | "Matches the resolver" was read, not executed | pending | Covered by D2-F1..F3 probes | pending |
