PASS

Round 1's demonstrated false pass is fixed. No new wrong-answer finding was established in the requested scope.

I reran the round-1 witness and setup against the current worktree, preserving its injected `lean_bar_axis()` defect and original eight-session native capture. Only generated-file destinations moved into `round2/`. The full entry points still demonstrate eight pinned sessions versus seven lean sessions. The current parity runner now records `axis`, n = 1, pass = 0, with `<top>: double values differ, length 7 vs 8`, and exits **1**. It stops before downstream checks, as intended. The unmodified runner on the same capture at chunk width 2 exits **0**, with all 13 checks (70 comparisons) passing, debug off and on.

Evidence: [rerun script](rerun_round1.R), [relocated setup](probe_parity_gap_setup.R), [witness output](witness_stdout.txt), [failing axis CSV](parity_gap_native.csv), [exit status](parity_gap_exit.txt), [debug-off control](native_control_d0.csv), [debug-on control](native_control_d1.csv).

Additional executed checks:

- **Refusal ordering, classes and messages:** 276 differential comparisons of the full preparation entry points, at chunk widths 1, 2, 3, 8, 12 and 1000, debug off/on. Empty bar ranges refuse before missing/incomplete calendars or invalid coverage bounds; nonempty ranges with insufficient calendar coverage refuse before calendar construction; covered one-session declared windows produce the pinned short-window refusal. Native/declared successful ranges, a fractional end bound, empty/unknown/duplicate/subset/reversed universes, and invalid experiment input also match. See [probe](probe_refusals.R), [results](refusals.csv), and [log](refusals.txt).
- **Sparse hydration and duplicates:** a sealed declared-session snapshot has twelve axis sessions, four bar rows, and only two on-axis rows, exercising empty chunks and bars before/after the axis. Substrates match at widths 1, 2, 3, 4, 8, 12 and 100 with debug off/on. Fetch-boundary injection of duplicates for all rows, or only off-axis rows, matches the pinned result at six widths. See [probe](probe_sparse.R) and [log](probe_sparse.txt).
- **Installation/restoration:** the installed binding is the lean entry point and produces the pinned substrate; restoration preserves all namespace binding values and lock states. Included in the refusal probe.

Static inspection found no change under `R/` and no lean-core reference there. The new axis query holds the snapshot handle; hydration continues through the pinned held-handle fetch function. The shared preparation helper checks for bars before invoking the declared-axis callback, whose coverage/calendar order matches the pin.

I did not rerun the author's large-capture results or run parity on intraday/portable captures. All new probes and outputs are in this directory; worktree files were not edited.
