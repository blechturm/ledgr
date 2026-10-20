# WS46 focused re-review 1 (Type 1), `5043afc0..967794af`

## Verdict: CHANGES_REQUIRED

Correction 1 implements decisions (23) and (24) as written and closes F2,
F4, F5, F6, F7 and F8 as claimed.

- Decision (23): every path refuses a membership, trading-status or
  lifetime fact with no knowledge time with `ledgr_fact_knowledge_missing`,
  before any table is written. That covers the durable run, two-worker
  sweep, precompute, both walk-forward policies, inspection, `run_window`,
  `sweep_window` and `ledgr_promote()`.
- Decision (24): on 1,387 adversarial families the candidate's membership
  counts and refusals equal the canonical two-clock count at every limit.
  Every difference from BASE is in a family BASE counted wrongly.
- The identity runner gives 86 of 89. The three differences are the
  `G/limit_1..3` refusals that decision (24) allows. The first reviewer's
  e2e probe gives 63 of 63.
- The full suite, the census and the fold-phase checker pass.

One finding blocks acceptance:

- R1: decision (23) made the user-facing documentation false. `?ledgr_facts`,
  `?ledgr_sim_pit_inputs` and four passages of the `point-in-time-inputs`
  vignette say that a fact without a knowledge time stays audit-only and
  leaves the run unchanged. Every run, sweep and inspection on such a
  snapshot now refuses.

Two lower findings: a fact-counter mutation that no block detects (R2), and
record precision (R3). Neither reopens a Cut 16 decision, so the verdict is
not NEEDS_TYPE_2.

Method:

- Read the inputs:
  - AGENTS.md, `close_review_46.md`, and Correction 1 in
    `history_simplification_closeout.md`;
  - the Cut 16 decisions (22)-(24) and LDG-3074..3077 with their evidence;
  - contracts.md Provider, Knowledge And Timing, and the condition
    reference;
  - `git diff 5043afc0..967794af` in full: `R/`, tests, `tests/claims.yml`,
    `tools/`, the census, the map, the closeout, the contract and
    `tickets.yml`.
- Built source copies of the candidate (`git ls-files`, working tree equal
  to `967794af` apart from CRLF churn in five uncommitted files) and of BASE
  `b9d098c8` (`git archive`). Each was compiled once, sequentially, before
  any two-worker run. A third copy, of `303ded9c` (the first reviewer's),
  served as the pre-correction timing arm.
- Probes (scratchpad `ws46_rereview/probes/`):
  - `d23.R`: five snapshots, each with one fact that has no knowledge time.
    The fact is a status fact, a lifetime fact, a set header, a set header
    in an unused universe, or a lifetime fact for an instrument the
    experiment does not trade. Each snapshot goes through 13 entry points,
    and every base table is counted before and after.
  - `d23_promote.R`: the promote path.
  - `vig.R` and `ex.R`: the three availability vignettes and the
    fact-related Rd examples, run against the candidate.
  - `d24_eval.R` / `d24_cmp.R`: three arms over two adversarial sets. The
    arms are BASE production; BASE with the same-clock branch disabled,
    which is the canonical, resolver-based M-6 compiler; and the candidate.
    The sets are the first reviewer's 828 families and 559 new public-shape
    header-only families (`d24_gen2.R`, same-clock and lagged, with ties
    and clocks between sessions).
  - `frozen.R`: checks that the two functions moved into the frozen helper
    are verbatim.
  - `empty_axis.R`: counts on an empty axis.
  - `sameclock_time.R`: same-clock counting time.
- 15 mutations on a mutation copy, each restored byte for byte (table
  below), plus D5 against both adversarial sets.
- Re-ran:
  - the implementer's runner (`ws46/runner`) and `check_identity.R`,
    including the self-test;
  - the first reviewer's `e2e.R`;
  - the full suite, census `--mode=check` and
    `--self-test-mode-branches`, and `tools/check-fold-phase-contract.R .`.
- `git diff --check` is clean, and every changed file is ASCII.

## Findings

### R1 (medium, blocking): the public documentation still says a fact without a knowledge time is audit-only

These passages contradict the refusal that decision (23) introduced:

- `R/availability-facts.R:8-9` (`man/ledgr_facts.Rd:66-67`): "Missing
  knowledge time remains audit-only unless `knowledge =
  "assume_effective"` is declared."
- `R/sim-pit-inputs.R:36-37` (`man/ledgr_sim_pit_inputs.Rd:67`): "Missing
  knowledge stays audit-only under `"evidenced"`."
- `vignettes/point-in-time-inputs.qmd`:
  - 156-157: "a missing knowledge time is kept for audit but cannot affect
    resolution";
  - 205-206: a status row with missing evidenced knowledge "stays
    audit-only rather than becoming an active restriction";
  - 250-251: a missing evidenced lifetime knowledge time "leaves the row
    audit-only rather than changing the run";
  - 380-382: "missing evidenced knowledge remains audit-only unless
    `assume_effective` is declared".

Evidence (`d23.R`): each of these fact shapes is accepted by its public
constructor under the default `knowledge = "evidenced"`, seals and passes
`ledgr_experiment()`. Then `ledgr_run()`, `ledgr_sweep()`,
`ledgr_precompute_features()`, `ledgr_walk_forward()`,
`ledgr_pulse_snapshot()`, `ledgr_run_window()`, `ledgr_sweep_window()` and
`ledgr_promote()` all refuse with `ledgr_fact_knowledge_missing`. They
refuse even when the fact belongs to a universe or instrument the
experiment never uses.

The texts predate WS46. Before Correction 1 they roughly held on this
branch: the close review's `na_status.R` run completed with the status fact
never applied. Correction 1 makes them false, and it updated only the
contract and the condition reference.

The vignettes and examples still execute (`vig.R`: three of three; `ex.R`:
every example present), because none of them builds such a fact. NEWS does
not mention the new refusal.

Smallest fix: in the two roxygen paragraphs and the four vignette
passages, say that such a fact is accepted and audited at seal, and that
availability preparation then refuses it with `ledgr_fact_knowledge_missing`
until a `knowledge_time` is supplied or `assume_effective` is declared
(Cut 16 decision 23; its meaning is decided with LDG-3073). Regenerate the
two Rd files. Optionally add a NEWS line.

### R2 (low, detector gap): a tie-handling mutation of the fact counter survives LTB-0335 and LTB-0337

The mutation is at `R/history-substrate.R:940`. It changes
`head_known[[y]] <= head_known[relevant]` to `<`, so an own incomplete
header no longer blocks a header ranked before it whose knowledge time is
the same (mutation D5). Result:

- LTB-0337: 104 expectations, 0 failed.
- LTB-0335: 441 expectations, 0 failed.

The mutant is wrong on publicly storable data:

- On the 559 header-only families it differs from the canonical count in
  284 limit evaluations across 37 families (27 same-clock, 10 lagged).
- On the first reviewer's 828 families it differs in 151 evaluations.

Smallest witness: a complete set `x` and an incomplete set `z` with
identical effective and knowledge times (2021-03-04 20:00 UTC, between two
21:00 sessions), where `z` lists five instruments. The canonical count is
2 for every instrument. The mutant counts 3 for the instruments that `z`
lists.

LCL-0327 claims that membership counts "equal the canonical two-clock
count for every shape". Its 48 random families rarely draw two headers on
one instant.

Smallest fix: add this literal tie family to LTB-0337. Alternatively, force
tied header clocks in a share of its generated families, as `count_gen.R`
does for 40 percent of its families.

### R3 (low, record): scope and stale lines

- Over-count scope. The closeout F3 row, LCL-0327 and decision (24)
  describe the removed same-clock counter as one that "undercounts on some,
  never overcounts". That holds for the shapes the public API can store
  (header-only or interval-only per universe). It does not hold in general.
  On the 828 families, the 36 that differ from BASE are all same-clock
  families mixing set headers and interval rows in one universe:
  - BASE overcounted 22 of them and undercounted 15 (one both);
  - at the limits 22 evaluations BASE refused now run, and 7 it ran now
    refuse.
  The candidate equals the canonical count on every one. `ledgr_facts()`
  refuses a second membership family per universe ("Fact family scopes
  must be unique"), so no public input reaches this shape, and decision
  (24)'s "only intended difference" holds for public data. Scope the
  sentence to storable shapes, or record the internal over-count.
- `history_simplification_closeout.md:101`: the M-2 row still lists "the
  same-clock membership counter" as a production caller.
- LCL-0325 `oracle_class` still says "five membership shapes"; LTB-0335 now
  draws four.
- Empty axis. Correction 1 also removed BASE's `length(axis) == 0L` branch
  in `ledgr_history_membership_segment_counts()`. On an empty axis the
  count for a non-complete, non-interval-only, non-same-clock family is now
  1 per instrument instead of 0 (`empty_axis.R`: 270 of 711 membership
  families differ). Inference, not exhaustively verified: no public entry
  reaches an empty axis, because `ledgr_history_substrate_for_experiment()`
  builds the axis from the snapshot start, and a counted family of 1 can
  never exceed a limit of at least 1. The closeout does not mention the
  removal.

## Item results

| Item | Result |
| --- | --- |
| F1 / decision (23) | PASS. See the path table below: every path, including a decoy universe, an untraded instrument and `ledgr_promote()`, refuses before any table is written. The durable run checks the stored facts on its own connection before registration (`R/backtest-runner.R:757`), so a resumed INCOMPLETE run is refused the same way. A resume could not be probed, because such a run cannot be created on the candidate. The other paths refuse at `R/history-substrate.R:1402`. Set headers and interval rows with no knowledge time are both refused. The default-mode set rows inherit the header's `NA`, so the membership count also sees them. No vignette, Rd example or demo dataset (`ledgr_demo_pit_inputs`: 0 missing knowledge times) builds such a fact. Documentation: R1 |
| F2 contract | PASS: `contracts.md:872-874` lists `facts`, `decision_view`, `execution_view` and `identity`, and says history is read only from the substrate |
| F3 / decision (24) | PASS. The same-clock counter, `is_diagonal` and `membership_state` are absent; R-M14 and R-M15 fail LTB-0332. The candidate equals the canonical M-6 arm in 0-mismatch comparisons: 4,100 evaluations on the 828 families and 3,872 on the 559 header-only families. Header-only: 118 families differ from BASE, all same-clock, all BASE undercounts. 193 limit evaluations are newly refused and none newly admitted, and no family that BASE counted correctly changed. Status: 117 of 117 identical. Scope note in R3 |
| F4 scaling claim | PASS. The closeout, map and ticket state the quadratic term. The scaling CSV discloses its session count; its 320-set rows run on a 2,610-session axis, not 500, because the axis is sized by the grid maximum. Same-clock timing below |
| F5 detector | PASS. X16a (shared floor 16 to 15) fails LTB-0335 (33) and LTB-0291 (1). X16b (one-fact compiler only, flat default 15) fails LTB-0335 (1). X18 (per-instrument compiler passes one extra fact) fails LTB-0335 (50). The guard is one function; LCL-0325 states the shared status code |
| F6 map | PASS. Sections 1-2 are marked as the BASE inventory, changed rows end with **Now:**, and R35 and M-8 carry status, differential and exit. Stale closeout line: R3 |
| F7 dead code | PASS: `header_method` is removed with radix order kept; `previous_keep` went with the counter |
| F8 test name and record | PASS: renamed; the mixed-shape inference is confirmed (and it scopes R3); the spike probes are recorded as historical |
| Identity | PASS. Runner: 86 of 89 against my BASE run, and the only differences are `G/limit_1` and `_2` (3 to 4 segments for G01) and `G/limit_3` (BASE runs, the candidate refuses at 4 segments for 5 facts, limit 3), in run, sweep and inspection. No retries; self-test 89 of 89. e2e: 63 of 63 apart from four strategy-error messages that differ only in the source-copy path (`base/R` against `cand/R`), which are identical after normalisation, as in the first review |
| Test changes | Valid. LTB-0291's three state mappings now call `history_reference_membership_state()`; `frozen.R` shows it and `history_reference_membership_is_diagonal()` are verbatim BASE, and every literal is unchanged. LTB-0335 drops `same_clock` for the stated decision (24) reason; LTB-0337 covers same-clock header-only and interval-only shapes against an independent brute-force resolver count. The mixed same-clock shape it drops is not publicly storable. The census seam `ledgr_availability_prepared_membership()` has no product caller (only the frozen helper, LTB-0291 and LTB-0334), and its contract text names both blocks |
| Docs and claims | LCL-0326/0327 and LTB-0336/0337 fall within the reserved ranges, one block each, with no duplicate or orphan. The condition reference and `man/ledgr_condition_classes.Rd` name the class. R1, R3 |

Decision (23) paths (`d23.R`; every cell: `ledgr_fact_knowledge_missing`,
no table changed):

| Entry | status | lifetime | set header | decoy universe | untraded instrument |
| --- | --- | --- | --- | --- | --- |
| `ledgr_run()` | refused | refused | refused | refused | refused |
| `ledgr_sweep()`, sequential and `workers = 2` | refused | refused | refused | refused | refused |
| `ledgr_precompute_features()` | refused | refused | refused | refused | refused |
| `ledgr_walk_forward()`, flat and `carry_test_state` | refused | refused | refused | refused | refused |
| `ledgr_pulse_snapshot(exp, ...)` | refused | refused | refused | refused | refused |
| `ledgr_run_window()`, `ledgr_sweep_window()` | refused | refused | refused | refused | refused |
| `ledgr_run()` with a character-vector universe | refused | refused | refused | refused | refused |
| `ledgr_promote()` with `require_same_snapshot = FALSE` (lifetime only) | n/a | refused, 0 runs | n/a | n/a | n/a |

The low-level `ledgr_pulse_snapshot(snapshot, universe, ...)` still runs.
It is the dense inspection branch, which decision (10) keeps without
availability history. `ledgr_backtest()` refuses every availability
snapshot with `ledgr_backtest_availability_unsupported`, as before.

## Mutations (source copy, each restored)

| ID | Mutation | Block | Result |
| --- | --- | --- | --- |
| M0 | none | LTB-0291, 0332, 0334, 0335, 0336, 0337 | 447, 43, 91, 441, 48, 104 expectations; none failed |
| X16a | shared guard default floor 16 to 15 (F5 re-run) | LTB-0335 / 0291 / 0334 | fails (33) / fails (1) / passes |
| X16b | one-fact compiler alone gets a flat default of 15 | LTB-0335 | fails (1) |
| X18 | per-instrument compiler hands the guard `fact_count + 1` | LTB-0335 | fails (50) |
| R-M14 | the same-clock counter returns | LTB-0332 | fails (1) |
| R-M15 | `ledgr_history_membership_is_diagonal()` returns | LTB-0332 | fails (1) |
| K1r | no check before run registration | LTB-0336 | fails (15) |
| K4 | no check in `ledgr_history_substrate()` | LTB-0336 | fails (30) |
| K5 | the in-memory check skips trading status | LTB-0336 | fails (10) |
| K6 | the stored-fact check skips trading status | LTB-0336 | fails (5) |
| K7 | the stored-fact check skips `snapshot_membership` | LTB-0336 | fails (5) |
| D4 | an own-header region counts when empty (`<=`) | LTB-0337 / 0335 | fails (4) / fails (24) |
| D5 | an own header with an equal knowledge time does not block (`<`) | LTB-0337 / 0335 | survives both (R2); wrong on 37 public-shape families |
| D6 | every complete header counts as winning | LTB-0337 / 0335 | fails (2) / fails (21) |

## Cost and shape

- The new checks scan four fact tables, either in one `UNION ALL` count
  query on the run connection or in one vectorized `is.na` sum per
  in-memory frame. Nothing iterates over bars, pulses or instruments.
  Removing the same-clock counter removes a per-break resolver loop.
- Same-clock incomplete sets, which is the shape
  `knowledge = "assume_effective"` produces, now go through the fact counter
  and inherit F4's quadratic term. `sameclock_time.R`: 300 instruments,
  1,400 sessions, each set listing half the instruments. High performance
  plan, affinity `0xFFFF`, `Rscript.exe` by full path, arms alternating,
  two runs (disclosure, not a finding):

  | Sets | BASE `b9d098c8` (M-4) | pre-correction `303ded9c` | candidate `967794af` |
  | ---: | --- | --- | --- |
  | 80 | 0.14, 0.14 s | 0.03, 0.03 s | 0.08, 0.09 s |
  | 320 | 0.47, 0.48 s | 0.16, 0.15 s | 0.34, 0.32 s |
  | 1,280 | 1.94, 2.03 s | 0.42, 0.41 s | 2.12, 2.13 s |

  Segment totals are identical in all three arms; these families have no
  between-session ties. The candidate is about BASE's cost at these sizes
  and gives up the pre-correction counter's speed. Beyond about 1,280 sets
  the quadratic term should make it slower than BASE. That is the same
  routed O(S log S) exit as F4, now also relevant to `assume_effective`
  users.

## Suite and checkers

- Full suite on the candidate copy (`load_all()`, then `test_local(...,
  stop_on_failure = FALSE, load_package = 'none')`): 1,147 blocks, 18,438
  expectations, 0 failures, 0 errors, one optional skip
  (`ledgr_snapshot_from_yahoo requires quantmod`), 683 s of block time. This
  matches the closeout.
- `tools/check-codebase-contracts.R --mode=check`: `LEDGR_CODEBASE_CENSUS_OK`
  (helpers 1,804, findings 72), and `LEDGR_MODE_BRANCH_CENSUS files=29
  functions=55 branch_sites=158 flow_sites=55`. `--self-test-mode-branches`:
  `LEDGR_MODE_BRANCH_SELF_TEST_OK`. The correction adds no execution-mode
  branch: the run-path check is unconditional, and dense snapshots hold no
  such rows.
- `tools/check-fold-phase-contract.R .`: `LEDGR_FOLD_PHASE_CONTRACT_OK`.
- Not run: the fixture ladder, the fast, review and heavy profiles, and
  `R CMD check`.

## Review ratio

Three findings (R1-R3) over ten re-reviewed items (F1-F8 and decisions
(23) and (24)): 3/10 = 0.300. This is correction round 1.
