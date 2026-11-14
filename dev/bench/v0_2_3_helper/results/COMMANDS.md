# dev/bench/v0_2_3_helper: the commands behind each result

A parameterised summary, normalised from the commands as executed (from the
package root). The commands themselves, verbatim and in order, failed
attempts included, are in commands_executed.txt. Libraries are scratch
installs: `R CMD INSTALL --no-docs --no-multiarch --no-test-load
--library=<lib> <git archive of the commit>`, then the commit's full sha
written to `<lib>/LEDGR_INSTALLED_FROM_COMMIT`. `<pin>` is the pinned library
of d5b3a151 (lean core reference). `$PCORE` is
`dev/bench/v0_2_3_lean_tuning_profile/pcore.ps1` (P-core affinity), run under
the High performance plan; each result's host file records plan and affinity.

| result | command | library / arms |
| --- | --- | --- |
| oracle_ldg3232 | `Rscript dev/bench/v0_2_3_helper/oracle_check.R --pin-lib=<pin> --pin-source=d5b3a151 --cand-lib=<lib> --cand-source=HEAD --wrong-source=f848ed80 --out=<scratch>` | candidate 176be4a7 |
| oracle_ldg3233 | same, `--cand-source=a564a226 --wrong-source=d5b3a151` | candidate a564a226 |
| oracle_ldg3233_r1 | same, `--cand-source=d6a258f6 --wrong-source=d5b3a151` | close review round 1 corrections |
| oracle_ldg3233_r2 | same, `--cand-source=4347bac8 --wrong-source=d5b3a151` | close review round 2 correction |
| measure_base (timings) | `powershell ... -File $PCORE <log> dev/bench/v0_2_3_helper/measure_helper.R --mode=timing --lib=<lib> --out=dev/bench/v0_2_3_helper/results/measure_base` | 176be4a7 |
| measure_base (sites) | the same with `--mode=sites` | 176be4a7 |
| collapse_semantics.csv | `Rscript dev/bench/v0_2_3_helper/collapse_semantics.R --out=dev/bench/v0_2_3_helper/results/collapse_semantics.csv` | collapse 2.1.8 |
| fmatch_compare.csv | `powershell ... -File $PCORE <log> dev/bench/v0_2_3_helper/fmatch_compare.R --out=dev/bench/v0_2_3_helper/results/fmatch_compare.csv` | none (base R and collapse) |
| protocol_refusals.csv | see dev/bench/timing/records/cut17-helper-1/COMMANDS.md | |
| lean_helper | `powershell ... -File $PCORE <log> dev/bench/v0_2_3_helper/lean_helper_compare.R --base-lib=<pin> --cand-lib=<lib> --out=dev/bench/v0_2_3_helper/results/lean_helper` | candidate a564a226 (round-1 rerun on d6a258f6, in lean_helper_r1) |
| lean_helper/insitu.csv | `powershell ... -File $PCORE <log> dev/bench/v0_2_3_helper/lean_helper_insitu.R --lib=<lib> --arm=<base or candidate> --row=<csv>`, three rounds per library, rows concatenated | pin and a564a226 |
