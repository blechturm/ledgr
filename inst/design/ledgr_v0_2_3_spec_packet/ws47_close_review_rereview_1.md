# Workstream 47 / Cut 27 focused Type 1 re-review 1

Verdict: **PASS**

Reviewed detached HEAD `66cc9a4bfad0bd71847a52e0d7935cb05c07bb6f`, fixes `c047db44..66cc9a4b`, after reading the round 1 report and AGENTS.md. This session authored no implementation. Both blocking findings are resolved. **No new findings.**

**F1 - Resolved.** `dev/lean_core/parity/oracle_controls.R:36` makes only scratch copies writable; `:52` and the mutation sites check setup effects. The unmodified driver, using a fresh output-directory scratch and the supplied read-only records, candidate and mutation, returned all 11 expected results (exit 0). Its CSV matches the committed controls CSV. Independent before/after SHA-256 and attribute inventories show the same 236 files, 71,164,890 bytes, zero changed hashes or attributes, and zero writable files. The subsequent unmodified oracle checker passed all 3,875 comparisons. The refreshed README and LDG-3282 evidence accurately describe the correction.

**F2 - Resolved.** `dev/spikes/explicit_state/take_return.R:23` derives P5 from the current envelope's AST, adds a state-list argument and return value, and assigns the four returned fields back at the call site. It executes an existing stage on small existing workloads without copying economic rules. The strategy-state updates remain replacements through the existing helpers; context-view construction is unchanged, preserving retained-view ownership (contract groups `inst/design/contracts.md#contract-execution-fold-carrier` and `inst/design/contracts.md#contract-availability-context-and-state`). The README explicitly acknowledges the remaining free inputs and by-reference environment effects; this is a bounded prerequisite, not a claim that all P5 inputs are explicit.

The runner, diff checker and gut demonstration exist and reproduce their recorded evidence. At debug 0 and 1, P5 gives 92 identical tables, six PASS workloads, two forked workers and six checked frozen paths per run. The gut gives the expected 26 differences among 32 tables and two FAIL workloads, including the reported `ledgr_config_non_finite` finalisation error. Both checkers exit 0 and every recorded phase CSV matches. The three large-shape records report 48 identical tables; I inspected those records without rerunning them.

**The red stop is fair as a judgment.** `dev/spikes/explicit_state/README.md:8` reports it first and `:14` expressly calls it a judgment. Raw timing records contain five alternating pairs per shape with equal output digests; recalculating their medians reproduces pulse-loop ratios 1.1805, 1.3995 and 1.0541, and whole-run ratios 1.1176, 1.2803 and 1.0168. The shared run-long matrix and indexed list-field write explain the copying cost; the recorded probe supports its run-length dependence. Stopping before multiplying that mechanism across stages reasonably answers decision 6's acceptable-cost prerequisite. The spike protocol supplies human stop signals, not a numeric performance threshold: no formal 1.40x limit or size-budget breach is established here. Returning only a row would change the representation and remains open. Adoption remains the maintainer's decision. The earlier variant is explicitly limited to shared environments (`README.md:102`, `:247`); its timings are not attributed to take-and-return state. LDG-3278's rewritten evidence agrees.

**Regression scope.** The fix-range stat is 26 files, +724/-57, confined to the control driver/documentation, spike code/evidence, ticket evidence and filed round 1 review. Its package/lean-root code diff is empty. The requested *full-cut* diff needs a qualification: package paths `R tests vignettes DESCRIPTION NAMESPACE src` are empty, but `dev/lean_core/*.R` is not. Even narrowed to direct children with `:(top,glob)dev/lean_core/*.R`, it contains nine previously reviewed lean files (+500/-424). The ordinary Git wildcard also matches parity descendants. These predate the fixes; none changed in this correction range. Final worktree status is clean.

Commands below abbreviate the absolute paths actually used. Each R invocation was a separate call. Package-loading checks were serialized; oracle controls/checking load no ledgr. `LC_ALL=C`; R temporary directories were redirected under `$out/tmp`. The P5 checker inherited explicit `GIT_DIR`/`GIT_WORK_TREE` to avoid repository discovery problems. Git emitted global-ignore permission warnings but exited 0 with clean status.

```powershell
$R = 'C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe'
$repo = 'C:/Users/maxth/ledgr-wt/cut27-close-review'
$out = 'C:/Users/maxth/ledgr-wt/cut27-close-review-out/rereview_1'
$p = "$repo/dev/lean_core/parity"
$records = 'C:/Users/maxth/ledgr-wt/pin-outcomes-7f65733f'
$candidate = 'C:/Users/maxth/ledgr-wt/cut27-scratch/candidate-oracle'
$mutated = 'C:/Users/maxth/ledgr-wt/cut27-scratch/oracle_mutated'
$lib = 'C:/Users/maxth/ledgr-wt/pin-lib-7f65733f'
$gitdir = 'C:/Users/maxth/Documents/GitHub/ledgr/.git/worktrees/cut27-close-review'

& $R "$p/oracle_controls.R" --records=$records --manifest="$p/evidence/ldg3282" --candidate=$candidate --mutated=$mutated --scratch="$out/oracle_controls" --out="$out/oracle_controls.csv"
& $R "$repo/dev/spikes/explicit_state/check.R" --lib=$lib --phase=p5 --scratch="$out/p5"
& $R "$repo/dev/spikes/explicit_state/check.R" --lib=$lib --phase=p5gut --scratch="$out/p5gut"
& $R "$p/oracle_check.R" --records=$records --manifest="$p/evidence/ldg3282" --candidate=$candidate --out="$out/oracle_check.csv"
git --git-dir=$gitdir --work-tree=$repo diff c047db44 66cc9a4b --stat
git --git-dir=$gitdir --work-tree=$repo diff 9cfd7cd6 66cc9a4b --stat -- R tests vignettes DESCRIPTION NAMESPACE src 'dev/lean_core/*.R'
git --git-dir=$gitdir --work-tree=$repo diff 9cfd7cd6 66cc9a4b --stat -- R tests vignettes DESCRIPTION NAMESPACE src
git --git-dir=$gitdir --work-tree=$repo diff 9cfd7cd6 66cc9a4b --stat -- ':(top,glob)dev/lean_core/*.R'
git --git-dir=$gitdir --work-tree=$repo diff c047db44 66cc9a4b --stat -- R tests vignettes DESCRIPTION NAMESPACE src ':(top,glob)dev/lean_core/*.R'
git --git-dir=$gitdir --work-tree=$repo rev-parse HEAD
git --git-dir=$gitdir --work-tree=$repo status --short
```

All commands above exited 0; results are stated above. PowerShell `Get-ChildItem`, `Get-FileHash` and `Compare-Object` produced `rereview_1/records_before.csv` and `records_after.csv` and confirmed no changes. PowerShell grouping of `timing_p5_raw.csv` reproduced the committed timing medians and checked pair completeness and equal digests. R logs, scratch comparisons and phase evidence are under `rereview_1/`.

No timing, full suite or package check was rerun. This verdict closes the two evidence findings within the requested scope; it does not grant switch acceptance. Only the review output directory was written. No worktree edit, commit or push was made.

