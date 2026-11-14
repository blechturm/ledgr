# cut17-helper-1: the commands behind each record

A parameterised summary, normalised from the commands as executed (Git Bash on
Windows, from the package root). The commands themselves, verbatim and in
order, are in dev/bench/v0_2_3_helper/results/commands_executed.txt.

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
| ldg3233-close-2 | 176be4a7 | d6a258f6 | all | raised for the candidate (close review round 1, finding 7) |
| ldg3233-close-3 | 176be4a7 | 4347bac8 | all | as ldg3233-close-2 |
| ldg3233-close-4 | 176be4a7 | 5eb67e6d | all | as ldg3233-close-2 |

Each row's base, candidate and cells agree with its attempt's session.csv;
the harness commit each record ran under is in the same file.

Each record was checked with

    Rscript dev/bench/timing/check.R --protocol=dev/bench/timing/protocols/cut17-helper-1 \
      --record=dev/bench/timing/records/cut17-helper-1/<label>/attempt-1

and the protocol refusals with

    Rscript dev/bench/v0_2_3_helper/protocol_refusals.R \
      --record=dev/bench/timing/records/cut17-helper-1/ldg3232-base-base-2/attempt-1 \
      --out=dev/bench/v0_2_3_helper/results/protocol_refusals.csv

The attempt folders keep the protocol and harness each record ran with
(`protocol/`, `harness/`); the counts above are those frozen copies.
