# Workstream 15 Type 1 close review

Reviewer: independent clean-context Claude Opus, 2026-11-01.
Range: `cb332627..29188f87` on `codex/cut7-ws5`.
Tickets: LDG-3179, LDG-3180, LDG-3181.
Authority: `tickets.yml` Cut 7 decisions (4), (7), (8) and section 3/4
ownership; synthesis D1/D2 and Section 4 items 1-2; contracts.md;
`optimization_coding_style.qmd`.

## Verdict

**CHANGES_REQUIRED.**

The flat lazy context and the fill-transition anchors are sound in the common
path: live facts are right for entry, addition, partial and full exit,
re-entry and supplied openings; a durable resume reproduces live facts at all
eight tested boundaries; walk-forward carry, including a boundary execution,
yields the correct shared-axis anchors. One resume path is wrong, though, and
the pulse-inspection path fabricates a basis. Several acceptance items have no
detecting test, and the record misstates identity and preparation behaviour.
None of this needs a design change; every fix stays inside the accepted D1/D2.

## Findings

### F1 (High): resuming a carried walk-forward window drops its carried facts

- Where: `R/backtest-runner.R:654` replaces the carried anchors
  (`R/backtest-runner.R:634`) with `ledgr_position_facts_from_replay()`, which
  starts from all-unknown anchors (`R/position-facts.R:27`) and replays only
  the window's own ledger. That ledger opens carried holdings with
  `opening_position` CASHFLOW events, which the classifier counts as non-fill
  openings and so leaves unknown.
- Scenario: two-fold `carry_test_state` walk-forward. Fold 1 buys BBB (entry
  2020-01-06) and closes AAA by a fill (exit 2020-01-07). Run fold 2's test
  config live, then the same config as `ledgr_run_fold(max_pulses = 2)`
  followed by `ledgr_run_config()`:

  | pulse | live BBB `entry_at` / `bars_since_entry` | resumed | live AAA `exit_at` / `bars_since_exit` | resumed |
  | --- | --- | --- | --- | --- |
  | 2020-01-10 | 2020-01-06 / 4 | NA / NA | 2020-01-07 / 3 | NA / Inf |

  A strategy that reads these columns therefore makes different decisions
  after a resume. This breaks D2 ("Resume restores the same facts. A
  contiguous `carry_test_state` chain carries their known economic
  provenance") and LDG-3181 acceptance 2.
- Why tests miss it: `test-position-facts-context.R` covers resume only for a
  fresh opening. It covers carry only as a `carried()`/`from_carried()` unit
  round trip.
- Minimal fix: let `ledgr_position_facts_from_replay()` take the initial
  anchor state, and seed it in `ledgr_state_asof()` from the run's carried
  opening. Do not classify `.ledgr_lot_opening` rows as transitions: the
  opening is the initial book, not an event, so a plain supplied opening still
  stays unknown. Add a real carried-window resume to the registered block,
  comparing it to the live run.

### F2 (Medium): pulse inspection fabricates `entry_price = 0`

- Where: `R/pulse-snapshot.R:206-219` supplies a zero cost basis for
  inspection positions. `R/position-facts.R:80` turns that into
  `entry_price = 0`.
- Scenario: `ledgr_pulse_snapshot(snap, c("AAA","BBB"), "2020-01-05T00:00:00Z",
  positions = c(AAA = 2))` returns `entry_price = c(AAA = 0, BBB = NA)`. A real
  run refuses an opening without a finite basis, so this value exists only in
  inspection, and it is fabricated.
- Contradicts: LDG-3181 scope ("positions supplied to `ledgr_pulse_snapshot()`
  carry unknown entry/exit facts, never fabricated ones"), acceptance 5, and
  the new contract bullet ("pulse inspection never fabricate[s] anchors").
  Ownership row `D2_pulse_unknown` names `test-position-facts-context.R`, but
  that file has no pulse-inspection test.
- Minimal fix: report `entry_price = NA_real_` for inspection positions that
  have no supplied basis, and add the registered pulse-inspection detector.

### F3 (Medium): fact columns are built eagerly on every pulse

- Where: `R/fold-engine.R:803-810` computes all five fact columns on every
  decision pulse, including the POSIXct conversions and a `context_pos` subset
  over the run axis. It does this before the callback and outside the lazy
  cache.
- Scenario: a six-pulse run whose strategy returns `ctx$flat()` and never
  reads a fact calls `ledgr_position_facts_view()` six times (traced). The
  context's `build_counts` never records these builds, so the
  "one build per requested column / no unused build" counters cannot see
  them.
- Contradicts: D1 ("Build each requested column on first read") and LDG-3180
  acceptance 2; it is also the eager-materialisation shape the style manual
  forbids.
- Minimal fix: put the anchor list, `lot_state`, `context_pos` and
  `current_bar` into the pulse lookup. These are copy-on-modify values, so
  they stay frozen. Then build each fact column inside
  `ledgr_pulse_context_lazy_field()`.

### F4 (Medium): per-pulse full-axis indexing and retired-reader construction; the new contract claims otherwise

- New contract text (`inst/design/contracts.md:2202`) says "the service, axis
  indices and feature resolver are prepared once per run or candidate". The
  candidate does not do this on every pulse:
  - It rebuilds `bar_index`, with `setdiff`/`duplicated` validation
    (`R/pulse-context.R:607`, `:755-785`).
  - It rebuilds `id_to_idx` and runs `match(universe, private_universe)`
    (`R/pulse-context.R:565`).
  - It copies every availability plane (`:612-614`).
  - It still builds the retired `ctx$feature`/`ctx$features` scalar and bundle
    closures twice (`ledgr_attach_feature_helpers`, `:397-438`; the filter
    wrappers, `:528-560`). No consumer reaches them: `$` refuses those names.
  - Lazy reads index name-keyed planes by `[ids]` (`:115-127`, `:724`), even
    though the planes are already in context order.
- Fill anchors re-hash the whole history axis per fill batch:
  `ledgr_position_fact_bar_index()` (`R/position-facts.R:11-19`) runs from
  `R/fold-engine.R:1343` and `:1394`. That is O(pulses-with-fills x axis
  length), which grows quadratically with bars on the 7,213-session real-data
  axis. Its `findInterval` fallback also snaps an off-axis label silently to
  the next bar, or to bar 1 for a label before the axis. That fails open
  instead of refusing.
- LDG-3180 acceptance 2 asks for a counter proving one service/resolver
  preparation per candidate. None exists.
- Minimal fix:
  - Delete the retired accessor construction.
  - Index planes and bars positionally (`bars_current` is already
    context-ordered), or prepare the index once per candidate.
  - Derive the fill bar from the next prepared pulse index (or one envelope
    epoch map) and refuse off-axis labels with a classed error.
  - Add the preparation counter.
  - Or correct the contract sentence if per-pulse preparation is accepted.

### F5 (Medium): contracts still bind removed readers in LDG-3180-owned sections

- `contracts.md:1279-1288` (Context Planes: `ctx$vec$...` planes), `:2372-2386`
  (Feature Resolution: `ctx$feature()`, `ctx$features()`, `ctx$vec$feature()`),
  `:2415-2423` (Prepared Views: `ctx$tradable()`) and `:2452-2456` (Inspection:
  a scalar-loop warning that is now removed) all still describe behaviour that
  no longer exists. `:2216` says these readers are not public.
- Section 3 ownership gives feature resolution and the context/state flat
  columns to LDG-3180. LDG-3190 "does not first implement any contract
  amendment". The Decision Axis section (`:1814`, `:1826`, `:1840`, `:1888`,
  `:1906`, `:1919`) is LDG-3182's, but it now binds `ctx$vec$admissible`, which
  is absent.
- `README.Rmd:129` still says "`ctx$vec` holds today's values". Only
  `README.md` was corrected, so the next knit reverts it.
- Minimal fix:
  - Amend the LDG-3180-owned sections to the flat spellings.
  - In the sections later tickets own, replace removed spellings with their
    flat equivalents (`ctx$buyable`, flat feature columns), or mark them
    retired by LDG-3180.
  - Fix `README.Rmd`.

### F6 (Medium): undeclared configuration-identity change for carried windows

- Probe: one identical experiment hashed at `cb332627` and at the candidate.
  A plain run (`d3c1c01a...`) and an uncarried fold-1 test window
  (`eccd0b50...`) are unchanged. The carried fold-2 test window changes from
  `f8395256...` to `bb4379b1...`, because `opening.carried.position_facts`
  enters the hashed config.
- `ws15_implementation_matrix.md:26-29` opens with "snapshot and configuration
  identity do not change in this workstream". The Cut 7 identity statement
  does not list carried facts.
- The change is semantically justified, since carried facts change what a
  callback reads. But it must be recorded. A stored carried opening without
  `position_facts` is now read as "no known anchors" instead of refusing. Under
  the current-only policy that should rest on the cut's format-fingerprint
  bump, and the record should say so.
- Minimal fix: correct the matrix and the LDG-3181 evidence to state the
  carried-window identity impact and its store-format consequence.

### F7 (Medium): acceptance items lack detecting evidence

Product probes passed where I ran them. The listed acceptance detectors are
nevertheless absent or vacuous:

- **LDG-3179**
  - `check.R` checks one string. Deleting any `surface_inventory.csv` or
    ownership row, restoring an export, or dropping a claim still passes.
    "Literal enough to fail when one named reader/helper or owner is omitted"
    is not met.
  - The ownership table covers D1/D2 only, not every decision, Section 3 row,
    Section 4 detector and maintained consumer.
  - `mutation` is prose, not one command per family.
  - There are no expected-difference rows.
  - The call-count/semantic base record is a prose summary.
  - The consumer census omits `dev/bench/peer_benchmark/dense/recipes.R` (the
    retained peer driver) and `dev/bench/long_window/lw_run.R` /
    `lw_sweepwf.R`, which the state census itself lists. All three still call
    `ctx$vec$feature()` and now fail; each needs a migration or a routing row.
- **LDG-3180**
  - The frozen-view test mutates the caller's local `bars`/`positions` copies.
    R copy semantics make it pass under any implementation, so it cannot
    detect "retain a mutable fold buffer".
  - There is no candidate-leak or shared-buffer mutation and no preparation
    counter.
  - There are no changing-universe or holdings-only flat-column fixtures in the
    new block.
- **LDG-3181**
  - There are no detectors for partial sale, addition, supplied opening,
    zero-fill disposition, split/recipient change, a real same-bar double
    transition, a skipped decision bar, or live-versus-rebuild equality at
    every boundary.
  - There are no fills-only, held-mask or disposition-as-fill mutations.
  - There is no source check against a second replay engine or instrument
    loop.
  - Same-bar order is tested only by calling `ledgr_position_facts_apply()`
    directly.
  - My resume and carry probes (below) are ready-made fixtures for most of
    these.

### F8 (Low): mapped concrete feature IDs can silently shadow context fields

- The collision check in `R/runtime-projection.R:440-441` covers aliases and
  unmapped IDs only. Meanwhile `ledgr_pulse_context_feature_reads()` admits
  mapped IDs, and `$` resolves asset fields first (`R/pulse-context.R:166-171`).
- Scenario: `ledgr_feature_map(px = ledgr_indicator(id = "close", ...))` is
  accepted. Then `ctx[["close"]][["AAA"]]` returns the bar close (106), not the
  feature (42).
- D1: "no key may silently select a bar field instead of the promised
  feature."
- Minimal fix: check every feature ID, mapped or not, against the reserved
  fields.

### F9 (Low): the timing protocol cannot run against its preregistered candidate

- `ws5-timing-1/workloads.R` adapts `ctx$vec` to flat columns only. Both state
  cells and the inherited WS4a strategy read `ctx$state_prev` and return
  `state_update`. Decision (4) retires `state_prev` in LDG-3185, and the
  integrated candidate takes declared state at `ledgr_experiment()`.
- The registered workloads must therefore be edited after registration, which
  the protocol's own no-change rule forbids. The "post-WS4a attribution base"
  is also not named by commit.
- Minimal fix: name the base commit and add the declared-state branch to the
  adapter now, before any record.

### F10 (Low): two registered oracles narrowed without a stated reason

- LTB-0304 (`test-history-continuity.R:336-372`) no longer checks mark-age
  parity across the five entry points.
- LTB-0167 (`test-terminal-outcomes.R:372-393`) dropped its `mark_source`,
  `mark_age`, `target_restricted`, reason and `priced` assertions for the
  frozen holding.
- These facts still exist in the P2 view and in run diagnostics, so they can
  still be asserted. AGENTS requires a stated reason for a registered-test
  change; the ticket evidence gives one only for LCL-0066/0071/0102/0103.
- Minimal fix: keep the assertions through the private plane or diagnostics,
  or record the reason.

## Clean areas

- Live fact semantics: entry on the opening fill's bar; additions and partial
  exits keep the anchor; FIFO `entry_price` after a partial sale (102.33 to
  103.00); full exit; re-entry keeps the last exit; `Inf`/`NA` sentinels.
  Supplied openings have unknown entry facts and the supplied basis.
- A durable resume of a fresh-opening run equals the live facts at all eight
  resume points, across additions, partial sales, a supplied opening and
  re-entry.
- Walk-forward `carry_test_state` with no resume: a carried entry
  (`bars_since_entry` 2 at the next window start) and a boundary execution
  (entry on the first bar of the next window, age 0) are correct on the shared
  axis.
- Saved views are frozen in a real run. A ctx kept from pulse 1 and first read
  after the run still shows pulse-1 position, held, `entry_at`,
  `holding_value` and cash. The lookup environment is fresh on every pulse.
- Non-fill transitions are routed through `ledgr_carrier_settlement_install()`
  for every live position mutation site. `FILL` rows come only from real
  fills. No fills-only scanner, held-mask engine or instrument loop was added.
  Replay reuses the existing accounting replay.
- Strict reads: retired names and unknown fields raise
  `ledgr_unknown_context_field`. Alias collisions are refused at
  `ledgr_feature_map()`. `names()`/`str()` do not force columns.
  `holding_value` is `NA` for a held position without a mark, and target
  helpers refuse it.
- The risk-price fallback in `ledgr_risk_context_prices()` matches the old
  plane choice in practice, because unobserved substrate closes are `NA`.
- Plain runs and uncarried windows keep their configuration hash. No WS16+
  surface (selection verbs, `ctx$state`, declared state, investor inputs)
  landed. The four WS6 frame/bar surfaces remain. The exports added are only
  the four S3 methods.

## What I ran

- Targeted tests, all green: `test-flat-lazy-context`,
  `test-position-facts-context`, `test-active-alias-runtime`,
  `test-strategy-context-entrances`, `test-scalar-accessor-warning`,
  `test-strategy-context-surface`, `test-pulse-context-accessors`,
  `test-documentation-contracts`. `dev/bench/v0_2_3_ws5/check.R` printed
  `WS5_INVENTORY_OK`.
- Ordinary fast profile: see "Fast profile and timing" below.
- Probes (job-local scripts, no product edits):
  - walk-forward carry and boundary execution;
  - resume-versus-live at eight boundaries;
  - resume of a carried walk-forward window (F1);
  - pulse snapshot with supplied positions (F2);
  - trace of `ledgr_position_facts_view` with no fact reads (F3);
  - mapped-ID collision (F8);
  - frozen view kept across pulses;
  - configuration hashes at `cb332627` versus the candidate (F6).

## Fast profile and timing

- **Ordinary fast profile:** `tools/run-test-profile.R --profile=fast` passed
  620/620 blocks, 0 skipped, 0 failed, in 363.35 s (High performance power
  plan, affinity `0xFFFFFF`). The advisory 112-second hint was exceeded. That
  clock is contaminated: my probes ran in parallel. It cannot be compared with
  the WS14 record of 202.65 s and is reported only as a functional pass. The
  committed WS15 record contains no fast-profile record, although the WS5
  README calls the profile "the aggregate gate".
- **Descriptive timing (not a gate; not shared-harness evidence):** fixture of
  300 instruments x 250 bars, `pkgload::load_all` on both trees, one SMA
  feature, three alternating pairs, `cb332627` versus the candidate. Medians:
  - hold-only run: 5.50 s versus 5.67 s (+3%);
  - trading run: 4.72 s versus 4.82 s (+2%).

  The candidate is no faster than the eager `ctx$vec` base. That is consistent
  with F3 and F4: the per-pulse index rebuild, retired closure construction and
  eager fact view replace the eager `vec` cost instead of removing it. The
  Cut 7 milestone record should attribute this through `t_ctx`, as
  `ws5-timing-1` intends, after F9 is fixed.
- **Mutation checks** (namespace overrides in a job-local script, running
  `test-position-facts-context.R`):
  - treating every replayed non-fill transition as a fill (disposition-as-fill
    in rebuild): 0 failures, so it is **undetected** (F7);
  - treating live non-fill transitions as fills: 3 failures, detected;
  - dropping carried anchors at the runner: detected by the unit round trip
    only.

## Ratio

Findings-bearing Type 1 close review 1 of WS15: CHANGES_REQUIRED. One High,
six Medium and three Low findings. No NEEDS_TYPE_2 concern: every fix
implements the accepted D1/D2 text.
