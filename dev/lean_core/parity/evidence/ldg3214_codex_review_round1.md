CHANGES_REQUIRED

One wrong-answer finding.

**[P2] An unused overlay bypasses the same-commit A/A refusal.**
Locations: `dev/bench/timing/runner.R:80`, `dev/bench/timing/measure.R:59-60`,
`dev/bench/timing/check.R:90-108`.

Any nonempty `--candidate-overlay` makes identical installed commits a gate.
However, measure.R only passes two extra arguments to the workload; it does
not require the workload to acknowledge or execute the overlay. Existing
protocols ignore these arguments. For example, smoke-1's `small_dense` runs
the installed package on both arms even with
`--candidate-overlay=dev/lean_core`. Its `small_cold` cell permits a ratio
of 1.03, so an ordinary same-commit noise result can now receive CHECK PASS
as a gate. The checker verifies the overlay tree and product suffix, which
does not establish that the timed candidate used it. Other existing
protocols also ignore the arguments; WS4b has 1.10 bounds.

This violates the benchmark manual's Before/After Regression Gates rules:
the overlay workload runs candidate code, and an A/A record establishes
validity/noise rather than gate evidence. Reject overlays for protocols
that do not support them, and require that support before using the overlay
to distinguish otherwise identical arms.

Executed witness: [probe_overlay_unused.R](probe_overlay_unused.R), output
[probe_overlay_unused.txt](probe_overlay_unused.txt).

- The real `small_dense` workload succeeded with `.arm="candidate"` and a
  nonexistent `.overlay` directory, returning work `1240;1240`.
- A synthetic checker fixture, built using the repository's existing demo
  constructor, had identical real commit/product identities, eight alternating
  pairs and ratio 1. Its A/A control was valid; presenting it as a gate failed.
- Adding only the real `dev/lean_core` tree identity, its candidate-product
  suffix and gate mode made the same fixture pass with zero failures. No
  candidate execution changed. The passing fixture is in
  [unused_overlay_fixture](unused_overlay_fixture/).
- Changing candidate work still failed. Additional controls rejected a wrong
  overlay hash and missing product suffix
  ([probe_harness_controls.txt](probe_harness_controls.txt)).

Reproduction in PowerShell:

```powershell
& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" C:/Users/maxth/ledgr-wt/ldg3214-review-out/probe_overlay_unused.R
```

No FIFO arithmetic or refusal mismatch was found. Focused execution against
the installed d5b3a151 pin covered 1,560 generated stream steps, 3,003
extreme-value/empty-block cases and 2,251 captured kernel calls, each with
debug off and on. Captures included all 1,249 fill-heavy calls and all 37
unmocked suite kernel refusals. All 39 suite input refusals also matched
with debug on. Scripts and results: `probe_kernel.R/.txt` and
`probe_captures.R/.txt`.

Direct calls to all four cut12-fifo-1 cells on both arms reproduced the
registered counts (361, 888, 363, 887) and identical work/result digests
(`probe_protocol.R/.txt/.csv`). The lean R11 probe also passed parity on
all 21 momentum and 1,249 fill-heavy calls (`probe_r11.csv`). These were
correctness probes, not timing-gate evidence. The archive probe confirmed
that the runner's export reads the harness commit rather than live edits;
four existing no-overlay records produced identical results under the old
and edited checkers.

Reviewed ff3afe275583ad75ea991503278833450c34d061 plus the uncommitted
LDG-3214 changes on Windows/R 4.6.1. No worktree files were edited; no
runner window or full parity runner was run.
