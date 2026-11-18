# cut22-feature-1: the commands behind each record

Git Bash on Windows. `$PCORE` is
`dev/bench/v0_2_3_lean_tuning_profile/pcore.ps1` (P-core affinity 0xFFFF,
Rscript with the given arguments, log to the first argument). Before each
window the power plan was set with
`powercfg //setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c` (High
performance) and Balanced (`381b4222-f694-41f0-9685-ff5bb260df2e`) was
restored after. `$LAUNCH` is `dev/feature_parity/timing_launch.R`, which
points TMPDIR, TMP and TEMP at `--tmp` (a scratch directory outside
AppData/Local/Temp) so the runner's arm libraries are not created there.
No candidate overlay: each arm is its own installed commit.

    powershell -NoProfile -ExecutionPolicy Bypass -File $PCORE <log> $LAUNCH --tmp=<scratch> \
      dev/bench/timing/runner.R --protocol=dev/bench/timing/protocols/cut22-feature-1 \
      --base=<base> --candidate=<candidate> --label=<label>

The four unit records ran one after another from one driver process under
`$PCORE` (the same command per record).

| label | base | candidate | what differs |
| --- | --- | --- | --- |
| aa-cut-base | b33e01d7 | b33e01d7 | nothing: the A/A record on the immutable cut base |
| unit1-axis | ddcdb9d8 | 74d3e886 | unit 1 only (LDG-3250 without and with candidate 1) |
| unit4-admission | e793cfa6 | 74d3e886 | unit 4 only (LDG-3250 without and with candidate 4) |
| unit23-inputs-ttr | 74d3e886 | 9f4c1a24 | units 2+3 only (LDG-3251 on LDG-3250) |
| c5-matrices | 9f4c1a24 | 0fbdffe5 | candidate 5 only (LDG-3252 on LDG-3251) |
| final-vs-cut-base | b33e01d7 | 45df6928 | the whole cut: the final package (R/ as at the close) against the immutable cut base (decision 3a) |

ddcdb9d8 and e793cfa6 are timing-arm commits on the local branches
`ws41-arms` and `ws41-arms-u4` (LDG-3250's tree with candidate 1, or the
admission line of candidate 4, restored from the cut base); they are not
part of the workstream's history.

Each record was checked with

    Rscript dev/bench/timing/check.R --protocol=dev/bench/timing/protocols/cut22-feature-1 \
      --record=dev/bench/timing/records/cut22-feature-1/<label>/attempt-1
