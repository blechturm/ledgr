# Slice-4 probe (slice-4 cut input, 2026-11-16)

A probe, not product code. The question: what does the lean loop need to
reproduce the pin for slice 4, and how big is it? Nothing in `dev/lean_core/`
was changed by it. The slice-4 cut rebuilds the work properly. The method
is slice 3's probe (`dev/spikes/slice3_probe/`).

Slice 4 (macro plan, order after Cut 20, point b):
- opening positions and imports;
- corporate actions: dividends, cash and stock acquisitions, spin-offs
  (prices are split-adjusted, so there are no splits);
- membership, trading status and lifetime facts, with their terminal
  dispositions;
- execution restrictions;
- a context axis that differs from the run axis.

`probe.patch` is the final diff against `5c70734b`:
- `dev/lean_core/loop.R`, +261/-88 lines, and `dev/lean_core/marks.R`,
  +21/-6. Every change is marked "slice-4 probe".
- 10 slice-4 workloads (`s4_`) in a new
  `parity/loop_workloads_slice4.R`.
- `parity/loop_parity.R` sources them, and `--dump` also saves the lean
  result.

Reproduce: create a worktree at `5c70734b`, `git apply probe.patch`, then
run `loop_parity.R --lib=<pin library d5b3a151> --debug=0|1
--workloads=... --out=...`. `reach.R <dump dir>` lists what each dumped
workload reaches (event types, diagnostic codes, status). `reach_pin.txt`
is its output for the pin.

## Steps and results

| Step | Files | Result |
| --- | --- | --- |
| 1. Baseline | `a_baseline` | 10 `s4_` workloads, 157 tables, all refused at their slice-4 family. |
| 2. Opening positions | `b_opening_debug1` | Identical with only the refusal narrowed. The lean loop already starts from the opening state. |
| 3. Corporate actions, refusal lifted only | `c_corporate_debug1` | 17 tables differ. The dividend is silently missed (cash 10005 vs 10000, one CASHFLOW row short), and debug on does not stop it. |
| 4. Corporate actions posted | `d_corporate_debug1` | Identical. The pin's corporate-action plan is the stand-in. Its rows are captured during the loop and published after it, in event order with the fills. |
| 5. Facts, refusal lifted | `e_facts_debug1` | Terminal, halt and cash-acquisition runs stop at "Lean execution view differs from the provider's at pulse 3". The v201 witnesses move on to the execution-restrictions refusal. |
| 6. Facts and dispositions | `f_terminal_debug1`, `g_exec_debug1` | Identical once each pulse takes its execution view from the provider, the plan and terminal dispositions are posted, and execution restrictions are lifted. |
| 7. Context axis and stops | `h_context_debug1`, `i_stop_debug1` | Identical once P2, the planner and the records run on the pulse's context, and a P1 stop takes the valuation-stop path. |
| Final patch, slice-4 set | `j_all_debug0`, `j_all_debug1` | 10 `s4_` workloads plus 6 affected ones: 362 tables identical in each mode. |
| 8. Full gate, against `loop_freeze.csv` | `k_gate_debug0`, `k_gate_debug1` | 121 workloads, 2,038 tables, 0 different in each mode. 104 PASS, 1 PASS* (`s3_sched_none`, as before), 16 PATH, all expected (below). |

The 16 PATH verdicts in step 8:
- 10 new `s4_` workloads, which have no freeze row.
- `dense_dividend_state` and `avail_acquisition` now run four folds lean;
  `prep_fixture` runs lean.
- `dense_risk_features`, `avail_terminal_resume` and `walk_forward` used to
  stop at a slice-4 family and now stop at sweep workers or walk-forward
  (slice 5).

No table differs, and no workload is refused that was not refused before.

## What the probe does (and the cut must do properly)

- **Coverage.**
  - Lift the corporate-action, fact-family and execution-restriction
    refusals.
  - Narrow the opening refusal to frozen openings and positions of
    unknown basis.
- **Marks trigger.** A run with any declared fact family other than
  sessions takes the marked path (slice 3's marks state). Without this,
  facts never reach P1.
- **Corporate actions (P1, first).**
  - The probe calls the pin's plan as a stand-in, as slice 3 did for marks.
    The calls are `check_clocks`, `post`, `check_quantity_effects`,
    dispositions and `bind_boundary`.
  - `post` writes event rows through a handler. The probe captures them
    instead (D3: no store write in the loop). After the loop, the probe
    publishes them in `event_seq` order, interleaved with the fill
    blocks.
  - Each fill keeps its own `event_seq`. Fill blocks are split where the
    numbering jumps over a corporate-action row.
  - The settlement state (cash, positions, lot state) updates the lean
    cash, positions, book and position facts.
  - A corporate-action refusal goes through the valuation-stop path.
  - The cut decides whether the lean loop owns the plan or keeps calling
    it.
- **Dispositions (P1).**
  - The plan's dispositions are posted first, then terminal dispositions
    of lifetime-inactive holdings (`ledgr_terminal_resolve`,
    `ledgr_disposition_post`).
  - `valuation/disposed/terminal_disposition` rows.
  - A blocked disposition (for example `held_terminal_position =
    "refuse"`) stops the run with `terminal_settlement_unsupported`.
  - One stop helper (`p1_stop`) serves every P1 stop. It generalises
    slice 3's valuation stop.
- **Execution view.** With facts, each pulse's execution view comes from
  the provider for the actionable instruments, in context order. The
  fixed-basket view is wrong once halts or lifetimes apply.
- **Context axis.**
  - P2 runs on the pulse's context: strategy call, target checks, sizing,
    risk, marks rows. Its targets are embedded back onto the run axis;
    outside the context, the target is the position and nothing is
    actionable.
  - The planner runs in the context frame and maps fill and rejection keys
    back. The pin plans on the context, and fills must come out in
    decision order.
  - Records use the context's cells per pulse. A decision number is the
    cell's ordinal in the context.
    `decision_order = (ordinal - 1) * axis size + run position`.
  - Members come from the marks state, not from the run's members.
  - Reconciliation gross is taken on the context.

## Workloads the cut must include

The 10 `s4_` workloads, and what each reaches on the pin
(`reach_pin.txt`):
- `s4_opening`, `s4_opening_sessions`: opening positions with fills, with
  and without declared sessions.
- `s4_dividend`, `s4_dividend_bought`, `s4_dividend_sessions`: a dividend
  CASHFLOW on an opening holding, on a bought holding, and on declared
  sessions.
- `s4_cash_acquisition`: a cash acquisition (CASHFLOW plus DISPOSITION),
  then lifetime-inactive decision cells.
- `s4_terminal`: a delisting with `valuation_stale(2)`; the terminal
  disposition and its valuation row.
- `s4_halt`: a halt on days 4-6 (`trading_halted` decision and no-fill
  rows).
- `s4_v201_refuse`: the v0.2.0.1 availability witness with
  `held_terminal_position = "refuse"`. It ends INCOMPLETE with
  `terminal_settlement_unsupported`.
- `s4_v201_default`: the same witness with defaults. Its context changes
  during the run (`membership_changed_before_execution`,
  `final_pulse_no_execution`, `execution_bar_missing`,
  `stale_mark_pass_through`).

Not covered by the probe. The cut should add these or refuse them:
1. Stock acquisitions and spin-offs.
2. Haircut and unlabeled terminal cases.
3. Frozen openings and positions of unknown basis (still refused).
4. A corporate-action refusal on a run without marks (still refused).
5. Strategy state that must follow a changing context.

## Notes for the cut

- **Debug gap.** The per-pulse debug checks do not compare cash after a
  corporate action. Step 3 shows a missed dividend passing debug on. The
  cut adds the check.
- **Probe shortcuts the cut must replace:**
  - a loop over pulses in the record expansion, to build the ordinal
    matrix;
  - P2's renamed context variables (`P_ids`, `P_pos`, ...), produced by a
    mechanical rewrite;
  - per-pulse context positions kept as a list (`hd_cpos`), with
    `lengths()` for the layout;
  - the planner's frame switch, done by index mapping around the call.
- **Size.**
  - Opening positions are free.
  - The context axis is the bulk: P2, the planner and the records. Part of
    the +261 lines is rename churn in P2.
  - Corporate actions and dispositions are moderate, because the pin's
    plan does the work.
  - `loop.R` is at 982 production lines against its 1,000-line cap. The
    cut needs a budget decision or a new file, as slice 3 put marks in
    `marks.R`.
  - A natural split is 4a (opening positions and dividends, which need no
    facts) and 4b (facts: acquisitions, dispositions, terminal stops,
    execution restrictions and the context axis).
