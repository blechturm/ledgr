# cut17-helper-1: the commands behind each record

Recovered verbatim from the executing session's command history
(2026-11-13 and 2026-11-14), from the package root, Git Bash on Windows.
`$PCORE` is `dev/bench/v0_2_3_lean_tuning_profile/pcore.ps1`, which sets
P-core affinity 0xFFFF and runs Rscript with the given arguments, logging to
the first argument. Before each window the power plan was set with
`powercfg //setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c` (High
performance); every record's session.csv and raw.csv carry the plan GUID and
each slot's affinity. `$OVERLAY` is
`dev/bench/v0_2_3_helper/views.R,dev/bench/v0_2_3_lean_tuning_profile/descriptors.R,dev/spikes/r_floor/fixture.R`.

    powershell -NoProfile -ExecutionPolicy Bypass -File $PCORE <log> dev/bench/timing/runner.R \
      --protocol=dev/bench/timing/protocols/cut17-helper-1 --base=<base> --candidate=<candidate> \
      --label=<label> [--cells=<cells>] --candidate-overlay=$OVERLAY

| label | base | candidate | cells | protocol counts |
| --- | --- | --- | --- | --- |
| ldg3232-base-base | 176be4a7 | d6517d19 | all | first (base-calibrated) |
| ldg3232-base-base-2 | 176be4a7 | fa69ffa9 | all | raised about 30 percent |
| ldg3233-match-vs-gated | f27d3dc1 | a564a226 | reb_10,reb_500,reb_1166,adj_10,adj_500,adj_1166 | as base-base-2 |
| ldg3233-close | 176be4a7 | a564a226 | all | as base-base-2 |
| ldg3233-close-2 | 176be4a7 | (the corrected candidate, its session.csv) | all | raised for the candidate (close review round 1, finding 7) |

Each record was checked with

    Rscript dev/bench/timing/check.R --protocol=dev/bench/timing/protocols/cut17-helper-1 \
      --record=dev/bench/timing/records/cut17-helper-1/<label>/attempt-1

and the protocol refusals with

    Rscript dev/bench/v0_2_3_helper/protocol_refusals.R \
      --record=dev/bench/timing/records/cut17-helper-1/ldg3232-base-base-2/attempt-1 \
      --out=dev/bench/v0_2_3_helper/results/protocol_refusals.csv

The attempt folders keep the protocol and harness each record ran with
(`protocol/`, `harness/`); the counts above are those frozen copies.
