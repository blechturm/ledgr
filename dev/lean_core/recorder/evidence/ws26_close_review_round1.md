CHANGES_REQUIRED

Type 1 close review of workstream 26, limited to the brief's wrong-answer question. Two demonstrated comparison gaps make the joined claim false. Both witnesses use the pinned build and a real default-workload capture; neither changes a boundary function or any worktree file. The corruptions below are negative witnesses, not claims that the original captures already contain those corruptions.

1. **[P1] Comparison accepts broken sharing between stateful closures, including a provider that returns different lifetime facts.** Location: `dev/lean_core/recorder/compare.R:26-28`, with closure traversal at `:52`.

   `seen` records pairs already visited, but permits one expected environment to match multiple independent actual environments, and vice versa. Equal bindings at comparison time therefore certify different state machines.

   Ran [provider_graph_probe.R](provider_graph_probe.R) against `avail_acquisition.rds`, P1 record 9. Starting from a fresh thaw of its complete output, the probe gives the lifetime cursor's `read` closure an independent copy of its environment, leaving `seek` on the original environment. No binding value, function body, type, name or clock is edited. `lc_compare()` returns `NULL`, and pinned P1 replay against that altered captured output reports `pass=TRUE`.

   The behavioral difference is immediate: querying the two output providers at `2020-01-02 16:00:00 UTC` for AAA returns lifetime `known_inactive`, terminal event `acquired` from the original, but lifetime `unknown`, terminal event `""` from the altered provider. `seek` updates a cursor that `read` no longer shares. This loses the terminal fact used by execution and settlement. A full fresh-process `run.R --replay` also accepts the corrupted capture, **128/128**.

   Evidence: [probe output](provider_graph_probe.txt), [fresh-process replay](provider_graph_fresh_replay.csv). The separate [reader witness](reader_graph_probe.txt) reproduces the same defect on a captured fold reader: one `bars()` call gives `stats()$reads` of 1 versus 0 while comparison and replay pass. Enforce a consistent, bijective environment correspondence across the comparison graph, including closure environments, parents and attributes.

2. **[P2] Comparison ignores binding locks and accepts a provider that now refuses its next query.** Location: `dev/lean_core/recorder/compare.R:29-41`.

   The environment branch checks active bindings, values, attributes and parents, but never binding or environment lock state. The recorder already preserves those states in `capture.R`; comparison discards their semantic difference.

   Ran [provider_lock_probe.R](provider_lock_probe.R) on the same P1 record. The only change is `lockBinding("last_cutoff", cursor_environment)` in the captured output's lifetime cursor. `lc_compare()` returns `NULL`, pinned P1 replay passes, and full fresh-process replay again accepts **128/128** records. The original provider's next acquisition-time query returns `known_inactive`; the altered provider raises `simpleError`: `cannot change value of locked binding for 'last_cutoff'`.

   Evidence: [probe output](provider_lock_probe.txt), [fresh-process replay](provider_lock_fresh_replay.csv). Compare lock state alongside each environment's bindings so an accepted output preserves the pinned callback's behavior and refusals.

Both findings concern Section 14's complete semantic output and exact comparison claim, and the stateful providers identified in Section 9. The preserved execution rule groups are `inst/design/contracts.md#contract-execution-fold-core` and `#contract-execution-fold-carrier`.

Verification: existing captures replayed 2,415/2,415 calls across all eight A0 workloads and the history fixture. All seven registered omissions fail for their stated reasons; the complete regenerated omission evidence matches the committed CSV. A fresh `failures` capture replays 129/129 and reproduces its committed manifest. All 135 `R/` files match the pinned source after line-ending normalization. See [verification.txt](verification.txt), [small_replay.csv](small_replay.csv), [dense_cost_replay.csv](dense_cost_replay.csv) and [omissions.csv](omissions.csv). Momentum, fill-heavy and the full checker were not rerun. The brief's three disclosed limits are not findings here. All scripts and generated outputs are under this output directory.
