CHANGES_REQUIRED

1. **[P2] Parity can pass when lean preparation builds the wrong session axis.**

   Location: [prep_parity.R:70](C:/Users/maxth/ledgr-wt/ldg3216-review/dev/lean_core/parity/prep_parity.R:70), especially lines 73 and 77-78.

   The runner supplies `s$axis` from the pinned capture to `lean_hydrate()`, then builds the substrate with the pin's captured constructor arguments. It never calls `lean_history_substrate_for_experiment()` or `lean_bar_axis()`. Thus all subsequent substrate, packet, feature and history comparisons can pass despite a wrong axis from the preparation function that `lean_prepare_install()` installs. Adding bar-native captures alone does not close this gap.

   **Executed witness:** I captured a small sealed bar-native snapshot with instruments AAA and BBB and eight consecutive whole-second timestamps, 2021-01-04 21:00:00 through 21:00:07 UTC. In a copy of the parity runner outside the worktree, I injected only this deliberate preparation defect:

   ```r
   original_axis <- lean$lean_bar_axis
   lean$lean_bar_axis <- function(...) head(original_axis(...), -1L)
   ```

   Calling the full preparation functions on that snapshot produced eight axis sessions from the pin and seven from lean, silently omitting the final bar. Nevertheless, parity against the capture of that same snapshot at chunk width 2 exited **0**, with all 12 checks passing (69/69 comparisons). The unmodified runner also passed the native capture as a control. This finding concerns a demonstrated false pass in the runner; the injected defect is not present in the current preparation implementation.

   Reproduce with the retained probe and capture:

   ```powershell
   & "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" C:/Users/maxth/ledgr-wt/ldg3216-review-out/run_parity_gap.R
   ```

   Evidence: [probe setup](C:/Users/maxth/ledgr-wt/ldg3216-review-out/probe_parity_gap_setup.R), [native capture builder](C:/Users/maxth/ledgr-wt/ldg3216-review-out/capture_native.R), [observed axis mismatch and passing checks](C:/Users/maxth/ledgr-wt/ldg3216-review-out/parity_gap_log.txt), [passing CSV](C:/Users/maxth/ledgr-wt/ldg3216-review-out/parity_gap_native.csv), [exit status](C:/Users/maxth/ledgr-wt/ldg3216-review-out/parity_gap_exit.txt).

   Exercise the full lean preparation entry point when obtaining the substrate under comparison, including its axis construction and refusals, and retain a mutation that proves an incorrect axis fails parity.
