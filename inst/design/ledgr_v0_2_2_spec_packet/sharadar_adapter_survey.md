# Sharadar Adapter and Long-Run Survey (2026-10-08)

**Status:** Read-only survey, input to the
[history-wave register](../rfc/rfc_history_wave_v0_2_2_decisions.md) and the
WS2 remainder. Not a decision record. Gathered by a clean-context agent on
2026-10-08 from `C:/Users/maxth/ledgr-research` (adapter packages, EXP-0003,
feedback log `docs/governance/ledgr-feedback.md`) and this branch at
`b331c78`. Points marked *verified* were re-checked by the executor; the rest
are the agent's findings with its cited evidence.

## 1. The adapter still works; its meaning changed

- No exported ledgr function used by `ledgr.sharadar` was removed or renamed on
  v0.2.2. The only exported signature change is `ledgr_valuation_stale()`
  gaining `exhausted = "freeze"`. `ledgr.universe` does not call ledgr.
- An adapter-shaped snapshot (qlcal sessions, membership snapshot sets,
  lifetime facts labelled `"delisting"`, `price_basis = "split_adjusted"`)
  seals to the identical hash on v0.2.1.0 and the branch.
- The adapter emits membership only as complete snapshot sets with
  effective = knowledge = the availability instant; intervals are prohibited
  (`sharadar_ledgr_membership_intervals()` aborts). *Verified.*
- Behavior changes that alter the adapter's meaning:
  - **Cut 6:** held terminals with a label are disposed at the last
    permissible mark (an empty label still stops); exhausted marks freeze
    instead of stopping; policy schema 2 means EXP-0003 run stores can be read
    but not resumed, rerun or promoted.
  - **Cut 9:** features re-warm at every scoring start. Superseded by the
    history-wave decision that every indicator starts at the beginning of the
    data.
  - **Cut 7:** alias-first feature reads; `ledgr_pulse_wide()` columns are
    named by alias. No adapter call site is affected.
- Identity drift: the adapter's `resolver_code_hash` covers bodies of internals
  that changed, so artifacts pinned to it will not re-verify.
- The branch DESCRIPTION still says 0.2.1.0, so `ledgr (>= 0.2.1.0)` cannot
  tell the branch from the release.

## 2. Adapter patch list (in `ledgr-research`, none in ledgr)

1. Pass the vendor delisting reason through as `terminal_event` instead of
   collapsing it to `delisting`/`terminal_resolution`; bump the adapter policy
   version (snapshot hash changes).
2. Drop carried zero-volume bars (LFB-027), decided 2026-10-08 (snapshot hash
   changes).
3. Make `exhausted` explicit wherever `ledgr_valuation_stale(2)` is used.
4. Retire or rewrite the 0.2.1.0 diagnostic replica of availability policy.
5. Teach the reconciliation helpers about `DISPOSITION` events and frozen marks
   (they also loop per pulse over instruments).
6. Regenerate or re-pin `resolver_code_hash`-bound artifacts.
7. Pin ledgr by commit SHA, not version.
8. Runner: close filter until LFB-017 is fixed; window sizes compatible with
   the warm-up rule; fresh run stores.

## 3. EXP-0003 and what still breaks a long run

EXP-0003 (ledgr 0.2.1.0): 1997-12-31 to 2026-09-04, 1,168 instruments,
5,485,271 bars, 7,214 sessions, 528 in-window delistings; returns 63/126/252,
top-N momentum and equal weight, a 3x3 sweep and walk-forward. Cold run about
25 minutes, warm 81-89 s, sweep 2,952 s, about 3.5 minutes per fold, fact
readers 64-77 s per call, peak worker memory 7.0 GB.

| Item | What | Status on the branch |
| --- | --- | --- |
| B0 | every run stopped at the first held terminal | fixed for labelled terminals (Cut 6) |
| LFB-017 | one member without a price aborts the canonical rebalance pipeline | open; WS2 remainder, decided skip-and-record |
| LFB-023 | one fold without a selectable candidate aborts walk-forward | open; WS2 remainder, decided per-fold policy |
| LFB-018 | an interrupted run stays `CREATED` | open; WS2 remainder, decided `FAILED` |
| LFB-019, 021, 022 | inspection and reconstruction gaps | open |
| LFB-020 | walk-forward refusal before the first bar | message improved |
| LFB-024 | availability-aware features recompute every window | fixed for built-in SMA and returns; EMA, RSI and TTR remain slow (history-wave blocker 4) |
| LFB-025 | every run re-hashes the snapshot (about 60-80 s at 5.5M bars) | open; WS5 |
| LFB-026 | features not reused across calls | open |
| LFB-027 | carried zero-volume bars valued and filled as trades (4.9% of bars) | adapter drops them (decided); release definition of done item 9 *verified open* |

Branch-only observation (unverified cause): with `carry_test_state` and
non-contiguous test windows, a delisting between two test windows can make the
next test run `INCOMPLETE/terminal_mark_unavailable`.

## 4. Building the long snapshot

- Entry point `sharadar_ledgr_snapshot(con, canonical_build_id, from, to,
  db_path)`. Longest window recorded (1994-08-11 to 2026-09-04): 1,176
  instruments, 5,503,853 bars, 326,591 membership rows, 836 lifetime rows;
  projection 209 s, seal 165.5 s, verify-reopen 61.8 s; process working set
  about 6.8 GB.
- S&P members have full daily split-adjusted coverage only from 1998-01-02.
  *Verified* (adoption check, EXP-0003 correction). Decided span: 1998-2026.

## 5. Other gaps found

- NEWS.md's development section covers only Cut 9; Cut 6 and Cut 7
  user-visible changes (freeze default, `last_permissible`, policy schema 2,
  `ledgr_valuation_summary`, alias-named columns) are missing.
- No checked-in record exists for the release-only `exp0003_scale` shape, so
  v0.2.2 runtime and memory at this scale are unmeasured.
