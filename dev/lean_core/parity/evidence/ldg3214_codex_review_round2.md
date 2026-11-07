PASS

No wrong-answer findings in the two requested questions.

1. **The unused-overlay witness is blocked on the current execution path.**
   The original smoke-1 `small_dense` workload, through unmodified current
   `measure.R`, returns `outcome=error` on both arms when given an overlay:
   `workload did not report running the overlay for arm base|candidate`.
   A nonexistent overlay produces the same refusal. Seconds and work remain
   unset. Missing, wrong-arm, vector, NA, logical and empty acknowledgements
   also fail; an identical scalar arm succeeds.

   [probe_runner_slot.R](probe_runner_slot.R) additionally extracts and executes
   the production `run_slot()` function, without evaluating the runner driver.
   Both smoke slots fail through that function and its frozen copy of the
   current measure.R ([output](probe_runner_slot.txt)). The child exits zero,
   but `run_slot()` preserves its error outcome. Runner lines 271-273 stop on
   that outcome; lines 303-304 mark the attempt invalid. The checker rejects
   invalid attempts and failed rows (`check.R:66`, `144-154`). Every nonempty
   runner overlay directory is passed to every slot (`runner.R:230`).
   There is no current runner/measure path to a complete overlay record
   without the workload acknowledging the slot's arm (`measure.R:65-67`).

   The old synthetic fixture still passes the current checker
   ([probe_record.txt](probe_record.txt)). It constructed raw rows and session
   metadata directly, bypassing measure.R; it therefore does not reproduce a
   bypass of the corrected execution path. The acknowledgement is a workload
   assertion; the harness does not independently prove which code was timed.

2. **The fix does not change runs without `--candidate-overlay`.**
   The new check is conditional on a character `--overlay` argument, which
   the runner omits without an overlay. On both arms, current and prior
   measure.R succeeded without it, preserving raw columns, the selected clock
   and work `1240;1240`. Normalizing away the overlay-only argument plumbing
   and check leaves the prior measure function body identical as an R
   expression ([probe_record.R](probe_record.R)). The FIFO protocol's added
   return field does not affect non-overlay workloads.

Execution evidence: [probe_measure.R](probe_measure.R),
[output](probe_measure.txt), [summary](probe_measure_summary.csv).
Its 23 fresh processes include the real cut12-fifo-1 `fold_10_49` cell on both
arms: both succeed with 361 captured calls and identical work/result digests.
The two production-slot probes add two further fresh measure processes.
Every measure invocation received a fresh empty work directory.

Reviewed ff3afe275583ad75ea991503278833450c34d061 plus the present LDG-3214
worktree changes, with Windows/R 4.6.1 and the supplied d5b3a151 stamped library.
The initial sandboxed host probe could not list its process; the completed
execution probes used approved host access. No worktree files were edited.
No runner window was run; these are correctness probes, not timing-gate evidence.
