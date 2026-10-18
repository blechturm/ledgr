# WS42 / LDG-3062..3064 close review (Type 1), `a915ba66..558811f2`

## Verdict: CHANGES_REQUIRED

The public history result, the matrix adapter, sufficiency, experiment-derived
inspection, availability precompute, the single data start, the store-122
retirement of the hydration seam and the anchor-derived month folds are in
place and well detected. One product defect blocks acceptance: the carried
walk-forward chain is not equal to one run when a corporate-action event
becomes effective in one test window and becomes known in the next (F1). The
other findings concern undisclosed scale cost of the default read, a per-read
instrument loop, a context exposure and the written record. None asks to
redesign v12 or Cut 16 decisions (8), (10) or (16), so this is not
NEEDS_TYPE_2.

Method:
- Read the diff, the closeout, claims LCL-0196/0197/0292..0300, the four
  WS42 test files and the changed pre-existing tests.
- Full suite once after `load_all()`: 1,124 blocks, 0 failures, 0 errors,
  one optional skip (Yahoo missing-package path). No `_problems` artifacts.
- `tools/check-fold-phase-contract.R`: `LEDGR_FOLD_PHASE_CONTRACT_OK`.
  Census `--mode=check` regenerated: every CSV equal to the committed one
  (`--strip-trailing-cr`) except `metadata.csv`.
- `tickets.yml` and `tests/claims.yml` parse.
- 19 mutations on a source copy (table below) and four probes: a carried
  chain with a late-known corporate action, a lookahead probe, full-lookback
  read allocation, and late-known overlay counts.
- Host note: after the coordinator's notice the host carried audio load.
  Timings below are single runs and load-limited; the conclusions rest on
  allocation sizes, growth with cutoff and loop counts.

## Findings

### F1 (high): a late-known corporate action breaks the carried chain

`R/walk-forward.R:1264-1297` (`ledgr_walk_forward_pending_entitlements()`)
carries only `ordinary_cash_dividend` rows. `R/corporate-action-settlement.R:278-280`
makes dispositions and quantity effects due at `max(effective_idx,
knowledge_idx)`. In the next window's plan, an effective clock before that
window's first pulse matches no pulse, so `effective_idx` is `NA` and the
row is never due.

Scenario: a held instrument has a `cash_acquisition` effective at session 4
(last-but-one pulse of test window 1, sessions 3-5) and known at session 7
(inside test window 2, sessions 6-8). One run disposes of it at session 7.
The carried chain never disposes of it: window 1 cannot see the knowledge,
and window 2 ignores the row.

Evidence (`probe_chain_ca.R`, the WS42 fixture shape with a BBB action,
opening AAA 2 and BBB 1, hold strategy, folds as in LTB-0303):

| | ledger | final equity |
| --- | --- | --- |
| one run (`ledgr_run_window`, sessions 3-8) | `DISPOSITION BBB 1 @ 27` at 2021-01-12 21:00 | 1063 |
| carried chain, two test runs | no disposition; BBB held and valued to the end | 1064 |

The same action known at session 2 (before its effective time) disposes at
session 4 in both, so the gap is specific to knowledge arriving after the
window holding the event clock. A `spin_off` (quantity effect) follows the
same code path. Under `unsupported_quantity = "refuse"` the run would stop
while the chain completes; that refusal case is inferred from the same
indices and was not run.

This contradicts v12 Section 8 ("concatenated carried test runs must equal
one public `ledgr_run()` ... on events, equity and diagnostics"), the new
Walk-Forward Fold Lifecycle text at `contracts.md:230`, and the closeout's
statement that share-delivering actions "post at their pulse inside the
window that owns them". LCL-0297's scope narrows the claim to "unsettled cash
entitlements", so no registered block can see this.

Smallest fix: carry every corporate-action row the deciding window bound or
made effective but whose due pulse falls after it, not only cash rows. That
means disposition-eligible and quantity-eligible rows with an effective
index inside the window and `due > last`. The next window's
`ledgr_corporate_action_plan(carried = )` then makes them due at
`max(1, knowledge_idx)`. Add the late-known acquisition case to LTB-0303 (or
a sibling block) against the one-run oracle. A better fix derives the carried
set from the predecessor plan's own due indices. The current code re-derives
cash posting and knowledge timing in the walk-forward driver, which is a
second implementation of settlement timing.

### F2 (medium, record and route): the default read is quadratic and 8.6x its values

The default `lookback = Inf` (Cut 16 decision (3)) materializes the value
plane plus twelve aligned evidence planes on every read. At the H1 shape
(1,166 x 7,213, `frame_probe.R` fixture), these sizes are load-independent:

| cutoff | result object | value columns |
| --- | --- | --- |
| 1,803 | 139 MB | 16 MB |
| 3,606 | 278 MB | 32 MB |
| 7,213 | 554 MB | 64 MB |

Growth is linear in the cutoff, so a strategy that reads the default every
pulse allocates about 554 MB x 7,213 / 2, roughly 2 TB, over one run. In a
single load-limited run, one read near the end raised R's heap high-water
mark by about 1.6 GB. It took 2.1 s, against 0.07 s to slice and transpose
the values alone. Profile shares: `ledgr_history_carry_evidence` 38 percent,
`t()` of the evidence planes 29 percent. A ten-cutoff fit estimates about
8,200 s added to a 131 s run.

Per-read cost is bounded by output size, so this is not a hidden re-treatment
or a second reader. The quadratic total follows from the accepted default.
The 8.6x constant comes from eager, transposed, partly character evidence
planes. Laziness would touch v12 Section 3 ("retains aligned missingness and
carry evidence"), so it is not a WS42 product change. The closeout's
seven-shape walk reports only "1.96 s" and does not state the per-run
consequence.

Fix: state the per-read allocation and the default-every-pulse consequence
in the closeout. Route the teaching ("pass a finite `lookback` inside
strategies") to LDG-3071. Route the evidence representation (lazy or on-request
evidence planes, logical rather than character reason planes, avoiding the
per-plane transpose) to the LDG-3069 memory owner, or to the maintainer if it
needs a v12 Section 3 reading.

### F3 (low): the overlay loop runs per read over late-known instruments

`R/history-frame.R:183`. Each read iterates in R over every requested
instrument whose last late-known lifetime or terminal fact lies after the
cutoff. Each iteration does memo key construction, an environment lookup and
strided row writes into four planes. Iterations per read at cutoff n/2
(load-independent): 58 with 5 percent late instruments and 583 with 50
percent. In one load-limited run, a 21-session read cost 21 ms versus 8 ms
after the epochs at 5 percent, and 69 ms versus 10 ms at 50 percent. Memo
size was 101 MB and 145 MB. The count stays high for most of the history
whenever late facts are spread over it. The closeout states the loop and its
reason, but its scale evidence uses only 40 late intervals. The real-data
share of late-known lifetime facts is unmeasured.

Fix: record the iteration count as a function of late instruments in the
closeout and ask LDG-3070 (H6 real-data) to report the late-known instrument
count. If that count is material, group overlays by epoch and write them by
index.

### F4 (low): `ctx$.history` exposes the whole substrate to strategies

`R/fold-engine.R` places `ledgr_history_view` on the context as `.history`.
The view holds the read service, which holds the substrate with every bar to
the snapshot end. A strategy that reads
`ctx$.history$service$substrate$bars$close[1, ncol(...)]` passes
`ledgr_strategy_preflight()` as `tier_1`. In the WS42 fixture it traded on
the last session's close at session 1 (`probe_peek.R`: fill AAA 5 at
2021-01-05 14:30). The same preflight also passes
`environment(ctx$feature)$projection`. Whether that pre-existing path
reaches future values was not verified, so the exposure may not be new in
kind, but the new one is a plain list path.

The contract says "History reads add no context field" (`contracts.md:1736`)
and the ticket says "the helper adds no ctx view". Both are literally false.

Fix: reword the contract to "no public context field; a private `.history`
carrier". Route a preflight rule for dot-prefixed context internals (or a
closure-held view) to the preflight owner.

### F5 (record-only): evidence and contract text

- `tickets.yml` LDG-3062 evidence and closeout line 62-63 name the refusals
  `ledgr_invalid_history_request` (unknown ID) and `ledgr_history_unavailable`
  (cutoff outside axis). The code, contract and LTB-0297 use
  `ledgr_history_unknown_instrument` and `ledgr_history_outside_axis`.
- Closeout line 389 says `git diff --check` is clean. `git diff --check
  a915ba66..558811f2` reports trailing whitespace on seven lines of
  `dev/bench/v0_2_2_public_history/evidence/frame_probe_h1.txt`.
- "Test changes and their reasons" omits three registered blocks: LTB-0281
  (observe packet gains `history_view`), LTB-0200 (fold insert without the
  hydration column) and LTB-0206 (window has no hydration field). Line 198
  calls the continuity tests "unregistered". Each change is mechanical and
  valid, but each needs its stated reason.
- `contracts.md:790-791` (Units, Price Basis And Universe) still says the
  public selectors and target-intent boundary "remain pending under LDG-3062
  and LDG-3063". Both are now delivered.
- "Routed, not fixed here" names owners "pending maintainer confirmation".
  Until confirmed, those items (unread substrate planes, feature-cell
  placeholders, cash-only carry, the whole-prefix helper) have no accepting
  ticket. The cash-only route is superseded by F1.
- Mode branches: the runner's `final_execution_posix = if
  (availability_active) ... else NULL` is redundant, because the dense
  calendar has no such field and the spec ignores it without a provider.
  Every other added branch is either a public-entry gate or a representation
  switch bound by decisions (1) and (16). The walk-forward
  `is.null(history_substrate)` split is the only semantic one. Decision (16)
  binds it; list it for removal at execution-core consolidation.

## Acceptance table

LDG-3062

| Acceptance item | Result |
| --- | --- |
| frame, matrix and scalar agree with literal fixture arithmetic | pass (LTB-0297; M5 detected) |
| selector shapes, unknown refuse, inadmissible explicit kept, cutoff outside axis refuses | pass (class names misrecorded, F5) |
| finite lookback is the exact suffix including pre-window carry; used_before_window | pass (LTB-0298 vs whole-prefix oracle at every cutoff; M3 detected) |
| empty shapes | pass (LTB-0297) |
| no future rows; late-known only later; immutability | pass (M1, M4 detected) |
| sufficiency independent of readiness | pass (LTB-0299) |
| matrix with no manual reconstruction | pass |
| no ctx view, artifact or snapshot row; exclusion changes no target or fill | pass on execution and durable state (M2 detected); "no ctx view" is literally false, F4 |

LDG-3063

| Acceptance item | Result |
| --- | --- |
| run/sweep/inspection/window/precompute plane parity | pass (LTB-0300; M6 detected) |
| experiment is the configuration authority | pass |
| no strategy-side inspection | pass (LTB-0302) |
| P1/P2 only, no durable state, structural detector | pass (LTB-0302, LTB-0293) |
| stale precompute refuses before candidates; exact reuse deterministic | pass (M7, M9 detected) |
| mutation isolation | pass (LTB-0298, LTB-0301) |
| explicit availability gating; dense unchanged | pass (M8 detected; LTB-0306 literals unchanged) |

LDG-3064

| Acceptance item | Result |
| --- | --- |
| hand-authored boundary chain equals one run | pass for the fixture; fails for a late-known corporate action (F1) |
| flat and standalone keep the terminal rule | pass |
| one scoring start, data-start history, one substrate per session | pass (M11, M14, M15, M16 detected) |
| month folds without drift | pass (M17 detected) |
| hydration seam absent; schema 120/121 refuse under 122 | pass (scan clean; LTB-0260) |
| LTB-0196 changed only for the data-start rule; restart fails it | pass under decision (16) (M6b, M14, M15 detected) |

## Mutations (source copy, each restored)

| ID | Mutation | Result |
| --- | --- | --- |
| M1 | skip late overlay | LTB-0298 fails |
| M2 | drop_instruments ignores admission | LTB-0299 fails |
| M3 | used_before_window never set for bars | LTB-0298 fails |
| M4 | one future column returned | LTB-0297, LTB-0298 fail |
| M5 | admissible selects the whole axis | LTB-0297 fails |
| M6 | inspection calculates from the cutoff | LTB-0300 fails (LTB-0302 passes, as expected) |
| M6b | same | LTB-0196, LTB-0197 fail |
| M7 | axis validation ignores cutoff, sessions and hash | LTB-0301 fails |
| M8 | dense experiment allowed in inspection | LTB-0302 fails |
| M9 | payload mode cross allowed | LTB-0301 fails |
| M10 | pending entitlements never carried | LTB-0303 fails |
| M11 | marks from the first scoring pulse | LTB-0303, LTB-0304 fail |
| M12 | no window continuation | LTB-0303 fails |
| M13 | carried lots dropped | LTB-0303 fails |
| M14 | runner features from scoring start | LTB-0196 fails (LTB-0306 passes) |
| M15 | sweep features from scoring start | LTB-0196 fails |
| M16 | reconstruction marks window-local | LTB-0303, LTB-0304 fail |
| M17 | rolling train start from the previous boundary | LTB-0305 fails |

LCL-0300 (dense restart witness) was not mutated here. Its literals are the
unchanged Cut 9 values.

## Clean

- One reader: frame, matrix and scalar reads come from the substrate through
  the read service. The matrix adapter reads nothing. Selection consumes
  `ctx$vec$admissible`, and `drop_instruments` consumes WS41's
  `ledgr_history_estimator_admission()`.
- Overlay epoch logic is correct for segments whose knowledge precedes their
  first column. LTB-0298 checks it against the independent whole-prefix
  primitive at every cutoff in both orders.
- Feature values are computed per instrument over raw causal rows. No future
  facts enter them.
- WS41 routed items: `ctx$feature_table` is schema-only on availability, with
  `.feature_table_current` still lazy for inspection (fixed).
  `ledgr_history_substrate_treated_field()` has no product caller (verified).
  Unread planes are routed (F5 on confirmation).
- Registered oracle changes: LTB-0196 (decision 16), LTB-0197 (replacement),
  LTB-0218 (zero-horizon setup, stated reason valid), LTB-0258/0260 and the
  fold witness (schema 122) and LTB-0296 (data-start literals with old values
  in a comment) all have valid stated reasons. LTB-0306 equals the old
  LTB-0196 apart from the stated field renames. Its stale-payload case now
  mutates `scoring_range$start`. With only one dense start left, that is the
  only reachable form.
- Contract receivers for LDG-3062, LDG-3063 and LDG-3064 are present tense
  with their v12 pending links removed. The remaining links (Strategy
  Context Teaching, Release Gates, Store And Codebase Gates, WS43 groups)
  belong to other owners.

## Confirmation (correction commit `1ac64ecf`)

Verdict: PASS.

F1 is fixed. `ledgr_walk_forward_pending_entitlements()` now rebuilds the
previous window's own `ledgr_corporate_action_plan()` from its ledger. The
rebuild covers the window's pulses plus the next window's first pulse and
runs as a resume past the last pulse. The rows to carry come from the plan's
own state (bound, posted and due indices) through `carry_out()`. The driver
no longer re-derives posting or knowledge timing, so this is not a second
settlement path.

The rebuild and `carry_out()` run once per fold boundary. `carry_out()` is
vectorized over corporate-action rows. The binding reuses the existing
resume helper (`ledgr_corporate_action_past_quantities()`, paired position
lookup). Nothing runs per pulse, and nothing grows quadratically across
folds.

Re-run against `1ac64ecf`:
- Chain probes, one run against the concatenated carried chain (non-opening
  ledger, equity and non-routine diagnostics):

  | Probe | Result |
  | --- | --- |
  | `cash_acquisition` effective 4, known 7 | disposition at 27 on 2021-01-12 in both; final 1063 |
  | `ordinary_cash_dividend` effective 4, known 7 | identical; final 1064.5 |
  | `ordinary_cash_dividend` effective 5, known 6 | identical; final 1064.5 |
  | `spin_off` 4/7 under `unsupported_quantity = "refuse"` | both stop at 2021-01-12 with `corporate_action_quantity_refused`; final 1058; chain `PARTIAL` |
  | `spin_off` 6/8 under the same policy | both stop at 2021-01-13; final 1061 |
  | entitlement-free acquisition and spin-off variants | identical (see the observation below) |
- Mutations on a fresh source copy; LTB-0303 fails under each:
  - carry only cash rows;
  - carry nothing;
  - rebuild without the next window's first pulse;
  - leave a passed effective clock unreached;
  - do not recompute the late flag;
  - ignore a later knowledge clock.
- The removed runner branch is behavior-identical. The dense calendar
  (`ledgr_run_snapshot_calendar()`) has no `final_execution_posix` element,
  and `ledgr_execution_spec()` reads the argument only when an availability
  provider is present.
- Record text for F2-F5 is present:
  - full-lookback allocation and its quadratic consequence;
  - overlay-loop counts;
  - routes to LDG-3071, LDG-3069 and LDG-3070, plus a proposed preflight
    follow-up;
  - the private `ctx$.history` carrier in the contract;
  - corrected refusal classes;
  - stated reasons for LTB-0281, LTB-0200 and LTB-0206;
  - selectors no longer pending in `contracts.md`;
  - the walk-forward split listed for consolidation.

  The routed owners remain proposals pending maintainer confirmation, as
  disclosed.
- Full suite once after `load_all()`: 1,124 blocks, 0 failures, 0 errors and
  one optional skip. No `_problems` artifacts were left.
- `tools/check-fold-phase-contract.R`: `LEDGR_FOLD_PHASE_CONTRACT_OK`.
- Census `--mode=check`: equal to the committed CSVs except `metadata.csv`.
- `tickets.yml` and `tests/claims.yml` parse.
- `git diff --check a915ba66..HEAD` is clean.

Observation, not a WS42 finding: a `cash_acquisition` or `spin_off` row with
an effective clock but no entitlement clock is neither disposed of nor
refused in a single run, even when known early. The chain matches the run,
so continuity holds. Whether such rows should act belongs to the
corporate-action settlement owner.

No timing conclusion is drawn: the host carried audio load.
