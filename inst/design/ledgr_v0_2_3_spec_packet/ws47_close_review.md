# Workstream 47 / Cut 27 Type 1 close review

Verdict: **CHANGES_REQUIRED**

Reviewed detached HEAD `c047db44397a15aaa1a4c49303a6d278ca29e66d`, implementation range `9cfd7cd6..c047db44`, against workstream 47's recorded claim and the accepted Cut 27 brief. This session authored none of the work. The bounded parity checks passed. Two evidence issues prevent close acceptance; neither requires changing the accepted execution design.

## Findings

**F1 - Blocking: the checker controls fail on the published read-only records.**

Locations: `dev/lean_core/parity/oracle_controls.R:33` (copy helper), `:37` (file copy), `:63` (unchecked deletion), `:73` (corruption write); `dev/lean_core/parity/evidence/ldg3282/README.md:10` (records are read-only).

The control driver copies the records with their Windows read-only attribute. On a fresh scratch directory, `missing_record` reports exit 0 instead of the expected exit 1: its unchecked `unlink()` has left `rec_missing/gate/avail_acquisition.rds` present. The corresponding `scratch/oracle_controls/missing_record.log` says `IDENTICAL 3875 / ORACLE CHECK PASS`. The driver then terminates at the corrupt-record write with permission denied for `rec_corrupt/gate/avail_acquisition.rds`. The scratch file has `ReadOnly, Archive` attributes. Thus the delivered driver does not pass its controls against the delivered inputs, contrary to the close claim and LDG-3282's evidence.

Fix: make only the scratch copies writable, check that copies/deletions/corruptions actually happened, then rerun the controls against the read-only records and refresh the evidence. Keep the original records read-only. To isolate the problem, I copied the driver and checker under this review's output directory and added `Sys.chmod(..., mode = "0666")` to the copied driver's copy helper. All ten standard scenarios then produced their expected results. The unmodified checker also rejected the separately overlaid recorded `fill_price_ulp` candidate (13 failures). This local demonstration does not patch the worktree or clear the finding.

**F2 - Blocking: LDG-3278's green prerequisite is for a different experiment.**

Locations: `inst/design/ledgr_v0_2_3_spec_packet/tickets.yml:4796` and `:9585` (required prerequisite), `:9599` (green prerequisite claim), `:9604` (acknowledged substitution); `dev/spikes/explicit_state/README.md:12`, `:26`, `:138`; `dev/spikes/explicit_state/copy_probe.R:22`.

The accepted brief requires one stage to take and return explicit state on a small existing workload before mechanically extending that representation. The implemented prerequisite instead moves one concern into a shared environment read and written by several stages. The README expressly says the stage take-and-return form was not forked. The small `list_in_out` copying benchmark is useful cost evidence, but it does not execute a ledgr stage or test its retained-view ownership and outputs. Therefore the reported green prerequisite and subsequent red shared-environment timing result do not discharge the specified experiment. No maintainer disposition accepting this substitution is recorded. A negative spike result is allowed; the issue is which representation was tested.

Fix: execute the requested smallest stage take-and-return prerequisite and report its actual green/red/inconclusive result, stopping there if appropriate. Alternatively, obtain and record an explicit maintainer disposition accepting the substitute experiment and limiting its conclusion. Do not treat the measured shared-environment ratios as measurements of the unimplemented stage interface. No adoption or production change is requested by this finding.

## Verification

All R commands used `C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe`, with absolute script and argument paths, from the output directory. Package-source runs were serialized. In the commands below, these variables abbreviate the absolute paths used:

```powershell
$R = 'C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe'
$repo = 'C:/Users/maxth/ledgr-wt/cut27-close-review'
$out = 'C:/Users/maxth/ledgr-wt/cut27-close-review-out'
$p = "$repo/dev/lean_core/parity"
$records = 'C:/Users/maxth/ledgr-wt/pin-outcomes-7f65733f'
$candidate = 'C:/Users/maxth/ledgr-wt/cut27-scratch/candidate-oracle'
$lib = 'C:/Users/maxth/ledgr-wt/pin-lib-7f65733f'
$src = 'C:/Users/maxth/ledgr-wt/pin-src-7f65733f'
```

- Read `AGENTS.md`, the Cut 27 decisions and amendments, ticket acceptance/evidence, cut-review history, the fourteen-entry audit and changed contracts, rules ledger, interface amendments, synthesis Section 5/Q3, evidence records and both draft holistic briefs. The latter remain drafts. LR-27 and LR-28 remain pending switch blockers; I found no claim of their approval. Resource gates, H1/private reference work and O1-O8 remain open as specified.
- `git --git-dir=C:/Users/maxth/Documents/GitHub/ledgr/.git/worktrees/cut27-close-review --work-tree=C:/Users/maxth/ledgr-wt/cut27-close-review diff 9cfd7cd6 c047db44 --stat -- R tests vignettes DESCRIPTION NAMESPACE src`: empty, exit 0. `rev-parse HEAD` confirmed the reviewed commit. Explicit Git paths bypassed the environment's ownership-discovery failure without changing Git configuration.
- `& $R "$p/oracle_check.R" --records=$records --manifest="$p/evidence/ldg3282" --candidate=$candidate --out="$out/scratch/oracle_check.csv"`: exit 0, 3,875 identical comparisons. This checks all record file digests and the recorded table/case digests as well as candidate equality.
- `& $R "$p/oracle_controls.R" --records=$records --manifest="$p/evidence/ldg3282" --candidate=$candidate --scratch="$out/scratch/oracle_controls" --out="$out/scratch/oracle_controls.csv"`: exit 1, F1. The scratch-adjusted driver under `scratch/checker/` ran the same arguments into `scratch/oracle_controls_writable`: all ten standard scenarios OK, exit 0. Separately, the original `oracle_check.R` against `scratch/mutated_candidate` (candidate outputs with the recorded `oracle_mutated/gate/crossover_3x40_lean.rds` overlaid) returned exit 1, `FAIL 13, IDENTICAL 3862`, as expected. Logs and CSVs are in `scratch/`.
- `& $R "$p/evidence/ldg3282/matrix_check.R"`: exit 0; 235 workloads, 151 cited names/prefixes, zero unknown or uncited workloads. Independently inspected the family mappings, merge witnesses, feature consumers and reach checks, FIFO/refusal preservation and named deferred invariant/ownership/causality obligations. The name checker alone is not evidence that a workload exercises its assigned family.
- `& $R "$p/clarity_equiv.R" --base=afaceaba --final=bba035de`: all eight files identical after the permitted renames, exit 0. `--base=11176226 --files=loop.R` against the final worktree also passed. Git history shows no subsequent production-code change after `268bcd90` in the reviewed lean files.
- `& $R "$p/clarity_scan.R" --out="$out/scratch/clarity_scan.csv"`: zero findings. `& $R "$p/variant_anchor_check.R"`: 105 variants, PASS. `& $R "$p/stage_state.R" --out="$out/scratch/stage_state.csv"`: all six stages extracted; checked the headers against the direct read/write sets and the separately listed environment effects through helpers.
- `& $R "$p/evidence/ldg3280/suite_reconcile.R" --tests="$p/evidence/ldg3280/suite/tests.csv" --out="$out/scratch/suite_reconcile.csv"`: exit 0; 1,366 tests, 39 failing/erroring blocks, all 39 inventoried, none unaccounted for; 134 inventoried blocks pass. Inspected driver smoke controls, remap patches/mutations and fixture-identity records. The six no-mutation rows are separately identified; the twelve gates and four findings are not counted as passing remap demonstrations. Row approval and the independent switch review remain required.
- Ran `remap_demo.R --pin=$src --row="$out/scratch/remap_rows/R007" --out="$out/scratch/remap_runs"`, and the corresponding commands for R112 and R163. Row inputs and the shared helper were copied to the output directory first because the runner writes its patch/result into `--row`. All three: exit 0, DEMONSTRATED, replacement passes and intended mutation fails; both smoke guards pass. These are file runs with other inventoried failing blocks, not claims that the whole file passes.
- Ran `loop_parity.R --lib=$lib --debug=0` and `--debug=1`, each with `--workloads=ovf_sell_1.9,ovf_hold_1.9,ovf_sell_10,ovf_delta_then_lot,ovf_lot_then_delta --freeze="$p/loop_freeze.csv" --out="$out/scratch/overflow_debug<0-or-1>.csv"`. Each: five PASS, 90 tables, zero differences, five of five frozen paths checked. Debug-0 output passed; its initial PowerShell logging pipeline reported a nonzero shell status on startup locale warnings. Debug 1 used `LC_ALL=C` and preserved R's exit status, which was 0.
- `& $R "$p/evidence/ldg3283/integrated_diff.R" --dump=C:/Users/maxth/ledgr-wt/cut27-scratch/integrated_check --workloads=dense_cost,fe_declared,s4_dividend`: exit 0; exactly seven differing cells, all `feature_engine_version`. The full recorded integrated CSV has 94 nonidentical tables, all `sweep_attrs`, with the same digest difference. The explanation follows the bound-helper fingerprint and is appropriately retained as Cut 28 identity impact.
- `& $R "$out/scratch/evidence_audit.R"`: exit 0. Compared the three FIFO CSVs to the earlier committed evidence: ten new lot calls/two distinct keys from `test-indicator-evidence.R`; common population rows identical; parity counts increase by those ten; mutation differences only in `line`. All 38 retained FIFO files match their SHA-256 manifest. Suite candidate source hashes match the final checkout allowing only LF/CRLF conversion.
- `& $R "$p/evidence/ldg3279/ldg3279_probe.R"`: exit 0; 11 PASS and no FAIL. Independently reproduced missing-bar buyability, raw versus carried closes, qualified history admission, the final-pulse diagnostic and held decision quantity. On 39 busy pulses both recorded and virtual cash match their stated scans; they differ on 31, and `cumsum()` misses the recorded cash on 28. Output: `scratch/ledger_probe.log`.
- Read the prep run-width record: the whole-run width passes ordinary parity but cannot exercise a chunk edge, so its two edge mutations are MISSED. Widths 8/12 retain the registered edge tests and pass/catch as recorded. This explanation is sound.
- Read the full gate, batch-one, inert, variant, suite and FIFO census records instead of rerunning those jobs. No timing, resource, private-data, package-check or switch-acceptance result is inferred from the bounded reruns. The new overflow code uses a vectorized check and refusal-only prefix bisection; walking the seven optimization shapes found no new per-fill production loop.

Final worktree status is clean. Only this output directory was written. No commit or push was made.
