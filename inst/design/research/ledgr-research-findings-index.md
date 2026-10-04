# ledgr-research Findings Index

**Status:** living index, non-binding.
**Synced:** 2026-10-02, from the private ledgr-research repository at
`369c1d490c6bf20c9652c025622eb3cbdde3bce7` ([feedback register](https://github.com/blechturm/ledgr-research/blob/369c1d490c6bf20c9652c025622eb3cbdde3bce7/docs/governance/ledgr-feedback.md)).
**Authority:**

- **ledgr-research's register** is the source of truth for each finding's
  research impact, evidence and workaround.
- **The active packet's `tickets.yml`** is the sole authority for any fix.
- **This index only maps findings to ledgr homes.** It selects no API and
  authorizes no implementation.

This page lists every ledgr finding from the research repository that is not
yet closed, and the ledgr design entry that owns it. Read it before working
in an area a finding touches.

- **Detailed evidence** lives in the register and in the handoff notes in
  this folder.
- **Every row is vendor-neutral.** No licensed rows or private identifiers
  appear here.

**Keeping it current.**

1. When a ticket takes a finding, cite its `LFB-###` in `tickets.yml`.
   ledgr-research then records the ticket in the entry's `Upstream` field.
2. When the fix ships, the entry moves to `resolved_upstream`. It reaches
   `adopted` once ledgr-research has verified the fix.
3. Each new research handoff re-syncs this table and updates the commit
   above.

Rows marked "-" for the ledgr home are unrouted. The maintainer decides
whether they need a home.

## Blocks long-window or membership-wide research

| ID | Finding | Type, severity | Status | Research impact | ledgr home | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| LFB-011 | No held-security transformation or distribution settlement | capability_gap, high | open | Held delistings and acquisitions stop runs `INCOMPLETE` (B0). On 30 years of S&P 500 data no run passed 6.2% of the window, and every sweep candidate was `INCOMPLETE` | Roadmap: post-v0.2.1.0 exact equity quantity settlement; v0.2.x corporate actions. Horizon: 2026-09-29 untradable holdings; 2026-09-24 exact equity quantity settlement | `Sharadar-Corporate-Event-Evidence.md`; `Sharadar-Long-Window-Usability-Evidence.md` |
| LFB-014 | Held incomplete corporate-action facts are ignored and misreported | bug, high | open | Incomplete facts for held positions vanish from settlement and refusal; the summary under-reports them | Roadmap: v0.2.x corporate actions | Register |
| LFB-013 | Corporate-action facts cannot declare assumed knowledge | bug, high | open | Vendor action feeds without a first-known timestamp cannot enter as declared assumptions | Roadmap: v0.2.x corporate actions | Register |
| LFB-017 | One member without a current close aborts the canonical rebalance pipeline | api_friction, high | open | The documented `ledgr_selection()` -> `ledgr_weight_equal()` -> `ledgr_target_rebalance()` pattern fails the **whole run** on one ordinary gap. Workaround: a `where` close filter | Roadmap: v0.2.2 untradable holdings and selection session. Horizon: 2026-09-29 design homework (intent meets the universe and the market) | `Sharadar-Long-Window-Usability-Evidence.md` |
| LFB-023 | One walk-forward fold without a selectable candidate aborts the whole session | api_friction, medium | open | Under B0, 30-year walk-forward stopped at fold 5 of 110 in both schemes | Horizon: 2026-09-29 untradable holdings (selection surfaces) | `Sharadar-Long-Window-Usability-Evidence.md` |

## Performance

| ID | Finding | Type, severity | Status | Research impact | ledgr home | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| LFB-024 | Availability-aware features recompute every window from scratch | performance, high | filed | 88-91% of a cold run; about 25 min for three return features over 30 years; scales with bars, so intraday is impractical | Roadmap: v0.2.2 leakage boundary and indicator warmup session | `../../../dev/bench/notes/long_window_scaling_findings.md` (cause 1) |
| LFB-025 | Every run and every fact-reader call re-hashes the whole snapshot | performance, medium | filed | About 80 s of fixed setup per run and about 70 s per fact-reader call on a 30-year snapshot | Roadmap: v0.2.2 snapshot verification session; v0.2.2 long-window performance workstream | Same note (causes 2 and 6) |
| LFB-026 | Features are not reused across sweep calls, walk-forward folds or processes | performance, medium | filed | Each sweep and fold pays LFB-024 again (49-min sweep; about 3.5 min per fold) | Roadmap: v0.2.2 long-window performance workstream (after LFB-024) | Same note (cause 4) |
| LFB-016 | Session local times are resolved one civil date at a time | performance, medium | filed | About 43-55 s per multi-decade session calendar | Roadmap: v0.2.2 long-window performance workstream | Same note (cause 7) |
| LFB-015 | Membership snapshot provenance is copied onto every member row | performance, low | open | Snapshot size and seal hashing grow with set size times payload size | - | Register |
| LFB-009 | Long runs and result reads expose no progress stages | api_friction, medium | open | A 25-minute cold feature phase ran silently | Roadmap: v0.2.1.0 LFB-009 live-progress row. Horizon: 2026-09-20 real-data workflow costs | `Sharadar-Workflow-Improvement-Evidence.md` |

## Workflow and API friction

| ID | Finding | Type, severity | Status | Research impact | ledgr home | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| LFB-019 | State reconstruction fails on availability-aware stores with ordinary gaps | bug, medium | open | `ledgr_state_reconstruct()` is unusable on real point-in-time data; `ledgr_results()` still works | - | `Sharadar-Long-Window-Usability-Evidence.md` |
| LFB-018 | A run interrupted before its pulse loop stays in status `CREATED` | bug, low | open | Time-limited or interrupted runs leave rows that look pending forever | - | Same |
| LFB-020 | The walk-forward refusal for folds before the first bar does not name the cause | api_friction, low | open | Diagnosis cost only | - | Same |
| LFB-021 | Lifetime facts have no public reader | capability_gap, low | open | The terminal schedule that stops runs is invisible through the API | Horizon: 2026-09-25 availability evidence has no convenient reader | Same |
| LFB-022 | Pulse snapshots refuse a universe member without a bar on that date | api_friction, low | open | Real membership cannot be inspected as is | Roadmap: v0.2.1.0 LFB-006 row | Same |
| LFB-006 | No mutation-free pre-run decision-context preview | api_friction, low | open | First-cutoff inspection needs a throwaway run | Roadmap: v0.2.1.0 LFB-006 row. Horizon: 2026-09-20 point-in-time universe inspection | `Sharadar-Workflow-Improvement-Evidence.md` |

## Data, lineage and knowledge clocks

| ID | Finding | Type, severity | Status | Research impact | ledgr home | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| LFB-002 | No snapshot-level metadata channel for external data lineage | capability_gap, medium | open | Vendor build lineage must stay outside the snapshot | Roadmap: v0.2.x OMS semantics and snapshot lineage (not a v0.2.1.0 dependency) | Register |
| LFB-004 | Complete membership lists cannot retain distinct source clocks | capability_gap, medium | open | Per-member source clocks collapse into one set clock | Roadmap: v0.2.1.0 non-dependency note | Register |
| LFB-012 | An interval row cannot carry separately learned boundaries | capability_gap, medium | open | One knowledge time per interval mis-states late-learned ends | Horizon: 2026-09-27 interval facts cannot express per-endpoint knowledge | Register |

## Resolved upstream, adoption pending on the research side

LFB-001 (dividend cashflow), LFB-003 (lifetime-aware runtime), LFB-008
(availability result reads) and LFB-010 (zero-cash opening) shipped in ledgr.
ledgr-research has not yet verified them as `adopted`. They need no ledgr
action unless that verification fails.
