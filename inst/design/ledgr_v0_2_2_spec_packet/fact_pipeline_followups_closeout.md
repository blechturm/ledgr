# Cut 16 Workstream 45 closeout: causal facts follow-ups

Role: record; Workstream 45 implementation evidence (LDG-3073).
Authority: non-binding. `tickets.yml` owns status, `contracts.md` owns
behaviour, Cut 16 decisions (11), (12), (23), (27) and (28) and
`cut16_antipattern_review.md` (findings 11 to 15) are the work list.
Status: LDG-3073 is complete; Workstream 45 is `review_pending` for its
independent Type 1 close review.

BASE for every identity claim is `4b33f377` (`integrate/cut15-v0.2.2`). The
implementation and its tests are `4c92fd92` on `ws45/fact-pipeline`; the
commit after it computes constructor civil labels once (no behaviour change)
and adds the documentation, census tables, evidence and this record.

## What changed for a ledgr user

- Building facts is faster at scale and gives the same rows, IDs and hashes.
  At 120,000 rows a trading-status family with correction chains validates in
  0.15 s instead of 83 s, and its correction lineage builds in 0.009 s
  instead of 24 s (392 s at 480,000 rows, now 0.04 s); resolving 100,000
  Date facts against the session calendar takes 1.5 s instead of 3.1 s.
- A fact family edited after it was built is refused whatever else is in the
  bundle. Before, putting it next to a family with Date fields silently
  re-signed the edit.
- Date and POSIXct clocks on the same row are compared on the instants the
  Date resolves to (a session open or close), not on UTC midnight. A
  dividend whose Date entitlement closes after its POSIXct effective time is
  now refused; one whose POSIXct entitlement falls before a same-day Date
  effective close is now accepted; the same holds for interval ends.
- A corporate action without a knowledge time is known when its event
  becomes effective, by one rule: a Date event at its session's open
  (decision 27), a POSIXct event at its instant. A supplied knowledge time is
  always kept; before, a POSIXct knowledge time beside a Date event was
  replaced by the event's session open.
- A cash, stock or mixed acquisition or spin-off with an effective date but no
  entitlement date no longer passes silently: the run, the carried
  walk-forward chain and a dense run refuse with
  `ledgr_corporate_action_entitlement_missing` at the pulse it would act on
  (decision 28). Supply the entitlement time.

## Item 1: correction lineage once per family

`ledgr_status_lineage()` holds children in CSR form (`child`, `child_start`,
`child_count`) built by one radix order, walks breadth-first levels from the
roots (one vectorised step per level of the deepest correction chain),
detects cycles as rows no level reaches, and computes subtree sizes bottom-up
and preorder entry numbers top-down by sibling runs. Its numbering equals
BASE's depth-first numbering exactly (5,000 randomized forests including
cycles: 0 lineage mismatches, `diff_lineage.R`). A family without
supersession returns the trivial numbering without a walk.

`ledgr_fact_validate_status_rows()` is the one trading-status validator
(intervals, supersession, tied-source conflicts). It builds the lineage once
and passes it to the conflict check; the seal-time check in
`ledgr_snapshot_validate_availability_for_seal()` calls the same function.
LTB-0351 counts one lineage build for a corrected family (at construction,
or at civil resolution when its clocks are Dates) and none without
supersession.

The conflict check with corrections no longer pairs every correction row
with every row of its scope. `ledgr_fact_status_unrelated_overlap()` counts
ordered pairs with different statuses that overlap by binary search over
rank-encoded interval bounds per (instrument, source, precedence, status)
group, counts the ancestor-related pairs among them by moving every row one
link up its chain per step, and refuses when the first count exceeds the
second. Rows outside every chain keep the grouped opposing-state sweep first,
so BASE's refusal precedence is unchanged (5,000 randomized forests: 0
outcome mismatches against BASE). LTB-0352 checks it against a literal
pairwise oracle with walked ancestry on 400 forests.

The `supersedes_fact_id` rewrite from supplied to canonical IDs in
`ledgr_facts_trading_status()` is one keyed match
(`ledgr_fact_status_link_ids()`) instead of a scan of every row per link.

## Item 2: civil time formatted and encoded once per session

`ledgr_fact_civil_sessions()` prepares every declared open session of a
bundle once: civil date, open and close instants, how many open sessions
share the date, and the resolved evidence object for each edge (calendar,
civil date, instant, zone, venue) written once per session with two NDJSON
writes. `ledgr_fact_resolve_civil_frame()` parses each field's civil label,
matches it to its session by index and reads the instant and the encoded
evidence by that index; `ledgr_fact_civil_assemble()` joins the fields per
row. Unresolved labels in constructors are encoded once per distinct date.
The stored per-row `civil_time_json` is unchanged byte for byte (the
contract stores civil date, instant, zone and calendar with each Date-backed
fact, and snapshot hash rule 4 hashes that column), so "stored once" means
held and encoded once per session during resolution, not a new stored
format. LTB-0353 bounds every timestamp-format call and evidence frame by the
five sessions of a 1,200-row bundle and pins one evidence string literally.

## Item 3: integrity independent of bundle composition

`ledgr_fact_resolve_civil_families()` now resolves, validates and rehashes
only a family that still holds civil labels, and first checks that family's
recorded hash with `ledgr_fact_family_intact()`, the same rule
`ledgr_facts_assert()` uses. Every other family keeps its own hash. An
edited exact family is therefore refused by bundle validation with the same
message with or without a civil family beside it (BASE rehashed it whenever
the bundle held civil evidence), and an edited family awaiting resolution is
refused when bundled. LTB-0354 pins both.

## Item 4: validation and order on resolved instants

`ledgr_fact_family_settle()` is the one place a family's time comparisons
run and its row order is fixed. A constructor calls it when the family holds
no civil label (POSIXct input is already exact); `ledgr_facts()` calls it once
the bundle's sessions have resolved the labels. Interval bounds that carry no
civil label are still checked in the constructor where LTB-0044 expects the
first refusal (`ledgr_fact_check_exact_intervals()`); a Date bound is checked
only after resolution. Corporate-action clock order moved from the
constructor to `ledgr_validate_equity_corporate_action_clocks()` inside
settlement; the sealed-state validator still checks it on stored rows.

The registered witnesses (LTB-0355, New York sessions, 14:30 and 21:00 UTC):

- former false accept: entitlement `2021-01-05` (close 21:00) with effective
  `2021-01-05 15:00 UTC` refuses `ledgr_fact_invalid_clock_order`; BASE
  compared UTC midnight and accepted it;
- former false refusal: entitlement `2021-01-05 15:00 UTC` with effective
  `2021-01-05` (close 21:00) is accepted with those instants; BASE refused;
- a Date interval end `2021-01-05` resolves to 14:30 before it is compared:
  accepted after a 10:00 start (BASE refused), refused after a 15:00 start.

Ordering on resolved instants equals BASE's placeholder order whenever each
sort column holds one type, because a civil date maps to its session instant
monotonically within one venue; the identity comparison below confirms it on
every fixture.

## Item 5 and decision (27): one known-when-effective rule

`ledgr_corporate_action_assumed_knowledge()` is the only implementation. For
a row without a knowledge time and with an event clock (effective, else
entitlement, decision 11) it sets the knowledge time to the event and the
knowledge civil label to the event's civil label. A POSIXct event is known at
its instant; a Date event's knowledge label resolves, with every knowledge
label, to its session's declared open (decision 27), while the event itself
resolves to the close (decision 12). BASE had two copies, an instant copy and
a civil-label copy, and the civil copy won after resolution. They agreed on
all-Date and all-POSIXct rows, so decision (27) changes no all-Date row. They
disagreed on two mixed shapes, which now follow decisions (11) and (27):

- a supplied POSIXct knowledge time beside a Date event was replaced by the
  event's session open; it is now kept (decision 27 applies only "without a
  knowledge time");
- a POSIXct effective time beside a Date entitlement without knowledge was
  known at the entitlement's session open, before the effective event; it is
  now known at the effective instant (decision 11).

The rule is applied in the constructor because fact IDs hash the row with its
assumed knowledge, and moving it changes every such ID; the instants it
names exist only after resolution, through the single civil resolver. LTB-0356
pins the instants, the evidence, the pulse index (known within the effective
session, not at the previous close), the sealed row and a run's cash posting
without a late arrival.

## Decision (28): effective-only dispositions and quantity effects refuse

`ledgr_corporate_action_plan()` marks a complete `cash_acquisition`,
`stock_acquisition`, `mixed_acquisition` or `spin_off` row with an effective
clock and no entitlement clock (`ledgr_corporate_action_entitled_subtypes()`),
in every execution mode. `check_clocks()` refuses it at
`max(effective pulse, knowledge pulse)` with
`ledgr_corporate_action_entitlement_missing` (also
`ledgr_invalid_corporate_action_event`, `ledgr_invalid_state`), carrying
`fact_id`, `parent_instrument_id`, `subtype`, `effective_time` and
`knowledge_time`. A missing knowledge clock still takes precedence on the
same pulse. `carry_out()` carries such a row, with no entitled quantity, when
its effective clock fell in the window and its knowledge clock falls after
it, so the successor window refuses on the pulse one run uses. LTB-0357 pins
the single run, the completing first window, the chain refusal for a row
effective in window 1 and known in window 2, a spin-off effective inside
window 2, and a dense run. Rows of other subtypes are unchanged (see Routed).

## Item 8: settlement state as data

Settlement code changed here (decision 28), so the question was considered.
One predicate in `carry_out()` sufficed. Carrying the plan state as an object
would have the fold return its plan at a window's end and change the carried
opening, which is config identity; that is a fold-output change outside this
ticket. It stays with execution-core consolidation; the macro plan entry
records the outcome.

## Identity comparison

`dev/bench/v0_2_2_fact_pipeline_followups/compare_runner.R` builds one corpus
in a tree (every family, both membership shapes, assumed knowledge, correction
chains, Date, POSIXct and mixed clocks, qlcal sessions, a rebundle) and three
snapshots with a run and a two-fold carried walk-forward each, and writes
every fact row, fact ID, family hash, bundle hash, snapshot hash, stored fact
table, ledger, equity curve, fills and terminal outcome table.
`compare_check.R` diffs BASE and candidate and requires every case identical
except the declared intended differences, each of which must differ.
Result (`evidence/compare_result.txt`): `WS45_IDENTITY_OK`.

- Identical: 21 cases, including the three snapshot hashes
  (`1d710543...`, `1643c9c3...`, `2c9a6089...`), their stored fact tables,
  runs (fills, three corporate-action events each) and walk-forward chains.
- Intended differences (all mixed Date/POSIXct rows BASE handled wrongly, and
  decision 28):

| Case | BASE | Candidate | Reason |
|---|---|---|---|
| supplied POSIXct knowledge, Date events | knowledge = event session open | supplied knowledge kept | item 5, decision (27) |
| same, five-row family | as above per row | supplied knowledge kept | item 5, decision (27) |
| POSIXct effective, Date entitlement, no knowledge | entitlement session open | effective instant | item 5, decision (11) |
| Date entitlement closing after POSIXct effective | accepted | `ledgr_fact_invalid_clock_order` | item 4 (former false accept) |
| POSIXct entitlement before same-day Date effective close | refused | accepted | item 4 (former false refusal) |
| POSIXct start before a Date end's session open | refused | accepted | item 4 |
| effective-only cash acquisition, run and chain | completes, no disposition | `ledgr_corporate_action_entitlement_missing` | decision (28); snapshot hash identical |

No other hash changed. Decision (27) changes no all-Date row: BASE already
resolved such knowledge to the session open through its civil copy.

## Scale

`run_scale.ps1` runs `scale_stage.R` in a fresh process per observation
under the recorded timing method: High performance plan, affinity `0xFFFF`
inherited by every `Rscript` (`evidence/scale_conditions.txt`), BASE and
candidate alternating with the starting arm swapped each repetition, three
repetitions, medians. Each process times only its stage; a call faster than
one second is repeated until the calls total a second and the mean is
reported (the Windows clock ticks in about 10 ms). Fixtures come from
`scale_fixtures.R`: 100 Date membership intervals per instrument, and
trading status with every tenth row corrected twice (chain depth 2, 1.2
fact rows per input row). Raw rows: `evidence/scale_record.csv`.

| Stage | Rows | BASE (s) | Candidate (s) | BASE x4 rows | Candidate x4 rows |
|---|---:|---:|---:|---:|---:|
| Correction lineage | 120,000 | 23.87 | 0.0090 | | |
| Correction lineage | 480,000 | 392.2 | 0.0412 | 16.4 | 4.6 |
| Status validation (intervals, supersession, conflicts) | 120,000 | 83.41 | 0.147 | | |
| Status validation | 480,000 | not run (quadratic) | 0.695 | | 4.7 |
| Civil resolution (`ledgr_facts()` on a Date family) | 100,000 | 3.14 | 1.52 | | |
| Civil resolution | 400,000 | 11.58 | 5.21 | 3.7 | 3.4 |
| Family hash | 100,000 | 0.565 | 0.565 | | |
| Family hash | 400,000 | 2.23 | 2.23 | 3.9 | 3.9 |

Candidate lineage, validation, resolution and hashing grow linearly with fact
rows (ratios 3.4 to 4.7 for four times the rows; the sorts add the log
factor). BASE lineage grew quadratically (16.4 times) because each child
list was found by name; BASE validation was not run at 480,000 rows because
its pair formation is quadratic (projected over 20 minutes per repetition).
Of the candidate's 1.52 s of civil resolution at 100,000 rows, two family
hashes (the integrity check of item 3 and the rehash after resolution) are
about 1.1 s; hashing itself is unchanged and linear. Fact construction is not
in this table: its per-row identity and provenance hashing is unchanged
(Routed).

## Seven-shape walk

Every new or changed function, against the seven shapes of
`optimization_coding_style.qmd` (1 one-row frames, 2 full-table subset per
id, 3 per-element formatting, 4 per-row JSON, 5 recomputed or discarded work,
6 quadratic validators, 7 scalar writes into environment-held vectors). A
remaining loop and its reason is named; the reason is also a comment in the
code.

| Function | Change | Walk |
|---|---|---|
| `ledgr_status_lineage()` | rewritten | CSR children from one radix order (2); level loop runs once per depth level of the deepest correction chain, each level vectorised; no name lookup; no-supersession families return without a walk (5); local vectors only (7). |
| `ledgr_fact_validate_status_rows()` | new | One lineage per family shared by both graph checks (5). |
| `ledgr_fact_validate_status_supersession()` | rewritten | Per-link `for` loop replaced by vectorised checks over all links (3); returns the lineage it builds (5). |
| `ledgr_fact_validate_source_conflicts()` | changed | Pair formation over correction rows times scope rows removed (6); grouped sweep for rows outside chains, counting check otherwise. |
| `ledgr_fact_status_unrelated_overlap()` | new | Binary search over rank-encoded bounds per group (6); loop over the fixed three-status vocabulary; chain-walk loop runs once per depth level and visits each ancestor pair once. |
| `ledgr_fact_status_link_ids()` | new | One keyed `match()` instead of a scan per link (2, 6). |
| `ledgr_fact_civil_labels()` | new | `lapply` over the fixed clock-field vocabulary; each distinct date formatted once (3). |
| `ledgr_fact_civil_json()`, `ledgr_fact_civil_encode()` | changed | One NDJSON write per field over distinct dates, indexed back (4). |
| `ledgr_fact_civil_ndjson()`, `ledgr_fact_civil_assemble()` | new | One write per call; `for` over the fixed field vocabulary, vectorised over rows. |
| `ledgr_fact_civil_sessions()` | new | One table per bundle; two NDJSON writes and two timestamp formats over sessions, never rows (3, 4); `lapply` over the bundle's session families. |
| `ledgr_fact_resolve_civil_frame()` | changed | Per-row session data-frame subset and per-row formatting removed: rows read instants and evidence by session index (1, 2, 3, 4); `for` over the fixed field vocabulary. |
| `ledgr_fact_resolve_civil_families()` | changed | Resolves, validates and rehashes only pending families (5); `vapply`/`for` over the bundle's families. |
| `ledgr_fact_frame_pending_civil()` | new | Vectorised. |
| `ledgr_fact_family_settle()`, `ledgr_fact_family_build()` | new | One validation and one radix order per family; called once per family (5). |
| `ledgr_fact_check_exact_intervals()` | new | Vectorised; constructor passes the labels it already computed (5). |
| `ledgr_validate_equity_corporate_action_rows()`, `ledgr_validate_equity_corporate_action_clocks()` | split | Vectorised; clock order runs once, on resolved instants. |
| `ledgr_corporate_action_assumed_knowledge()` | new | Vectorised; the only copy of the rule (5). |
| `ledgr_fact_family_intact()`, `ledgr_facts_assert()` | extracted | One family hash per call; `vapply` over families. `ledgr_facts_assert()` still rehashes every family on each call (shape 5, pre-existing, routed). |
| Constructors (`ledgr_facts_membership_intervals()`, `_snapshots()`, `ledgr_facts_trading_status()`, `ledgr_facts_lifetime()`, `ledgr_facts_equity_corporate_actions()`) | changed | Placeholder validation and ordering removed; the per-row helpers they call (`ledgr_fact_ids()`, `ledgr_fact_provenance()`, the snapshot set-id `vapply`) are unchanged and dominate construction time (shapes 3/4, routed). |
| `ledgr_snapshot_validate_availability_for_seal()` | one call | Uses the shared validator (one lineage). |
| `ledgr_corporate_action_plan()` (`check_clocks`, `carry_out`) | changed | Vectorised masks and one `split()` by pulse; per-pulse reads by index; no new loop. |
| `ledgr_corporate_action_entitled_subtypes()` | new | Constant. |

## Mutation table

`mutations.py` copies the tracked files at their working-tree state (the
file list of `git ls-files -z`, explicit root), adds the compiled library,
applies one exact replacement, runs `test-fact-pipeline-followups.R` with
`load_all(compile = FALSE)` and records the failing blocks
(`evidence/mutations.csv`). 20 of 20 detected.

| ID | Mutation | Failing blocks |
|---|---|---|
| L1 | siblings numbered out of preorder | LTB-0351 |
| L2 | acyclicity check dropped | LTB-0351 |
| L3 | conflict validator rebuilds the lineage | LTB-0351 |
| L4 | lineage built without supersession | LTB-0351 |
| C1 | a related pair counted once | LTB-0351, LTB-0352 |
| C2 | ancestor pairs counted across scopes | LTB-0352 |
| C3 | touching half-open intervals overlap | LTB-0352 |
| R1 | resolved instants formatted per row | LTB-0353 |
| R2 | evidence key order changed | LTB-0353, LTB-0356 |
| I1 | every bundle family rehashed | LTB-0354 |
| I2 | pending family rehashed without its check | LTB-0354 |
| V1 | clock order checked before resolution | LTB-0355 |
| V2 | intervals not checked after resolution | LTB-0355 |
| K1 | supplied knowledge replaced (BASE label mask) | LTB-0356, LTB-0357 |
| K2 | entitlement preferred over effective | LTB-0356 |
| K3 | Date knowledge resolved to the close | LTB-0353, LTB-0356 |
| K4 | known-when-effective dropped | LTB-0356, LTB-0357 |
| D1 | effective-only row passes silently | LTB-0357 |
| D2 | refusal only in availability runs | LTB-0357 |
| D3 | unentitled row not carried to the next window | LTB-0357 |

D3 shows the chain refusal comes from the carry: without it the second
window completes while the single run refuses.

## Test changes and reasons

No registered test's setup, fixture or oracle changed. New blocks LTB-0351
to LTB-0357 (claims LCL-0341 to LCL-0347) in
`tests/testthat/test-fact-pipeline-followups.R`. Run against BASE, every new
block except LTB-0352 fails (LTB-0352 is the semantic oracle for a rewrite
whose BASE was correct but quadratic; its mutations C1 to C3 detect).

## Routed, not changed here

- **Question for the maintainer (not changed, identity-preserving).** Under
  `knowledge = "assume_effective"`, a membership, trading-status or lifetime
  family with a Date `effective_from` and a POSIXct `knowledge_time` column
  has every supplied knowledge time replaced by the effective date's session
  open (the civil-label copy of the assume-effective rule overrides the
  instant copy, the same pattern item 5 removed for corporate actions). When
  the supplied knowledge is later than that open, the fact becomes visible
  before it was known. Fixing it changes fact rows and hashes for that input
  shape, which no recorded decision covers, so it is kept byte-identical
  (`ledgr_fact_civil_json()` says so in place) and routed for a decision.
- **Effective-only rows outside decision (28).** An `ordinary_cash_dividend`
  with an effective clock and no entitlement clock still never posts (its
  posting binds at entitlement), and an unmodeled subtype with only an
  effective clock is still not reported as unsupported. Decision (28) names
  dispositions and quantity effects; these keep BASE behaviour and are routed
  to the corporate-action settlement owner.
- **Per-row identity and provenance hashing in constructors.**
  `ledgr_fact_ids()` digests one canonical JSON per row and
  `ledgr_fact_provenance()` writes one per row; the membership-snapshot set-id
  `vapply` digests per missing row. They dominate construction (about 39 s
  for 100,000 Date membership rows) and are unchanged here because any change
  must stay byte-identical; routed to the fact-compiler work (LDG-3080/F05).
- **`ledgr_status_runtime_conflicts()`** (ingest report) still loops per
  instrument and boundary with a per-candidate `vapply`; it now benefits from
  the linear lineage but keeps its loop shape. Routed with the item above.
- **`ledgr_facts_assert()`** rehashes every family on each call (shape 5,
  pre-existing). Routed with the items above.
- **Settlement state as data**: execution-core consolidation (Item 8).

## Verification record

Host: i9-12900K, Windows 11, R 4.6.1, DuckDB 1.5.6 (CRAN), run sequentially.

- Focused suites (fact, civil time, seal and hash, corporate action,
  walk-forward, availability, history substrate; 35 files): pass.
- Full suite (`pkgload::load_all('.', compile = FALSE)` then
  `testthat::test_local('.', reporter = 'summary', stop_on_failure = FALSE,
  load_package = 'none')`) on the final working tree: 1,168 blocks, 20,459
  expectations, no failure or error, one optional skip
  (`ledgr_snapshot_from_yahoo requires quantmod`); 697 s wall.
- Identity runner on the final tree against BASE `4b33f377`:
  `WS45_IDENTITY_OK` (21 identical, 7 intended differences;
  `evidence/compare_result.txt`). Lineage and conflict differential against
  BASE (`diff_lineage.R`, 5,000 forests): 0 mismatches.
- `tools/check-codebase-contracts.R --mode=check`: OK, 158 branch and 55
  flow sites (unchanged from BASE: no new execution-mode branch), findings
  72; the regenerated census tables (line references, the new condition
  class and helpers) are in the commit; `--self-test-mode-branches`: OK.
- `tools/check-fold-phase-contract.R .`: `LEDGR_FOLD_PHASE_CONTRACT_OK`.
- `tickets.yml` and `tests/claims.yml` parse; `git diff --check 4b33f377` is
  clean.
- Rd: `man/ledgr_condition_classes.Rd` and `man/ledgr_facts.Rd` regenerated
  with roxygen2; unrelated roxygen drift in eight other Rd files was not
  kept.
- `R CMD build` (with `QUARTO_PATH` naming RStudio's bundled Quarto) and
  `R CMD check --no-manual --no-build-vignettes ledgr_0.2.1.0.tar.gz` on a
  `git archive` source copy of `1793d1f3`: Status OK, no warning or note;
  every vignette rebuilt and its code ran. The check's test step runs the
  fast-profile membership as `tests/testthat.R` defines it, not the timed
  gate.
- Not run here, by instruction: the fast, review and heavy gate profiles and
  the independent close review. `R/cpp11.R` and `src/cpp11.cpp` line-ending
  churn from compilation is not committed.

Scripts and records: `dev/bench/v0_2_2_fact_pipeline_followups/`
(`scale_fixtures.R`, `scale_stage.R`, `run_scale.ps1`, `compare_runner.R`,
`compare_check.R`, `diff_lineage.R`, `mutations.py`, `evidence/`).
