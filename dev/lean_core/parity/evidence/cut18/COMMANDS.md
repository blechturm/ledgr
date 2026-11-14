# Cut 18 evidence: commands

From the package root, pin library `<pin>` (d5b3a151). Timed runs under the
High performance plan with P-core affinity through
`dev/bench/v0_2_3_lean_tuning_profile/pcore.ps1 <log> <script> <args>`;
the Balanced plan restored afterwards.

| file | command |
| --- | --- |
| census.csv, census_statements.csv | `Rscript dev/lean_core/parity/cut18_census.R --mode=census` |
| statements.csv, inventory.csv | `Rscript dev/lean_core/parity/cut18_classify.R` |
| inventory check | `Rscript dev/lean_core/parity/cut18_census.R --mode=check` (and `--commit=<sha>` for a frozen commit) |
| checker refusals | `Rscript dev/lean_core/parity/cut18_census.R --mode=selftest` |
| statement_cost.csv, clock_runs.csv, clock_loops.csv | `pcore.ps1 <log> dev/lean_core/parity/cut18_clocks.R --lib=<pin> --out=dev/lean_core/parity/evidence/cut18 --rounds=3` |
| bounds.csv | `pcore.ps1 <log> dev/lean_core/parity/cut18_bounds.R --lib=<pin> --out=dev/lean_core/parity/evidence/cut18/bounds.csv` |
| worklist.csv, package_costs.csv | `Rscript dev/lean_core/parity/cut18_worklist.R` |

statement_cost.csv: `gross_us` is the clocked statement's time per pulse;
`net_us` subtracts its own tick and the ticks of clocked statements it runs
(the effective tick, `tick_ns`, is the clocked arm's loop overhead over the
clocked evaluations per pulse). Rows `<statement>@<j>` are the statements
of a compound statement's block; the compound row's own net then excludes
them and can be negative. Every clocked run's fills and equity equal the
plain run's (clock_runs.csv signatures).
