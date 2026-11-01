# Workstream 13 checkpoint: re-review 2

- Reviewer: Codex, independent clean-context reviewer.
- Date: 2026-10-31.
- Mode: focused Type 1, LDG-3165/3166, v0.2.3 cut 5; limited to re-review 1's N1/N2 under the maintainer-owned brief drafted by Claude.
- Reviewed commit: `d138529e2bfd83f8293ef1b163add7ff119a5c6d` (HEAD), branch `claude/ws4a-carrier`; product correction `167dc947`; comparison `92f03745..HEAD`.
- Verdict: **PASS**.

Authority: `ws13_checkpoint_rereview_1.md` N1/N2; `contracts.md#contract-execution-fold-core`, `#contract-execution-accounting-events`, `#contract-execution-cost-model`. No design issue requiring NEEDS_TYPE_2 was found.

`ROOT` = `C:/Users/maxth/ledgr-wt/ws4a-impl`; `S` = `C:/Users/maxth/AppData/Local/Temp/ws13-rereview2`. Command abbreviations below were expanded to absolute paths when executed, with one simple shell command per call. R jobs were serial, using plain Rscript, R 4.6.1 on Windows. Base library: `E:/ledgr-data/r-lib/ledgr-v0.2.3-base-953338df`.

| Finding | Disposition, evidence and executed command |
| --- | --- |
| N1 | Resolved. `R/fold-carrier.R:41,162,237,240` exactly implements all four proposed edits. The regression at `tests/testthat/test-ws4a-carrier.R:2170` is identical to the proposed block; only an explanatory three-line comment and separating blank line were added. Existing test text is unchanged. Historical evidence at `tickets.yml:1343` has the exact requested replacement. Commands G/T/P below pass. |
| N2 | Resolved exactly. `tickets.yml:1335` now includes the refusal selector's fixed-check loop in the allowed-loop census. No product change for N2. Command G, including the focused ticket diff and tracked-text comparison, confirms the exact replacement. |

| Key | Command and result |
| --- | --- |
| G | `git -C ROOT diff 92f03745 HEAD`; focused diffs and `git -C ROOT show <revision>:<path>` for the product, tests, review and tickets. Exact replacement checks pass; the original test file is an unchanged prefix of HEAD. Initial and post-execution worktree status were clean. |
| T | `Rscript S/tests.R`: `testthat::test_local(ROOT, filter="^(ws4a-carrier\|fill-model)$", reporter="summary", stop_on_failure=TRUE)` exits 0. Both files pass, including the new five-assertion regression, existing Inf-fee/refusal-order assertions and their mutation control. Fourteen expected final-bar warnings; R startup also reports four locale-setting warnings. Output: `S/tests.txt`. |
| P | `Rscript S/probe.R base`, then `Rscript S/probe.R candidate`: both exit 0. Re-executes correction1's 21 small synthetic scenarios and adds two public NaN cases; all 23 results match exactly, including complete condition-class vectors, messages, warning classes/messages and normalized successful results. Candidate also passes 32 single-field and four paired validator controls. Captures: `S/base.rds`, `S/candidate.rds`. |
| R | After each pkgload-using job (T and candidate P), `git -C ROOT checkout -- R/cpp11.R src/cpp11.cpp` succeeds. Git required owner-account execution after sandbox ownership rejection; no Git configuration changed. |

Both added public probes use sealed synthetic snapshots, finite inputs, cash 1000 and price 10. Target -1e308 with fixed/notional fees 1e308 produces NaN cash; target +1e308 with zero notional bps produces NaN fee. Base and HEAD both raise `ledgr_invalid_lot_fill` with exactly `Invalid fill input for lot accounting.` Their complete class vectors match. These independent public executions confirm that the inputs reach the reported arithmetic boundary, rather than relying only on injected validator values.

Ordinary NA fee and cash are refused as `ledgr_invalid_pulse_plan`; so is NaN cash with a finite fee. Other double fill columns still refuse NA, NaN and infinities. Negative-infinite fee remains refused; positive-infinite fee and either infinite cash sign retain their prior admission. NaN cash with Inf or NaN fee reaches the intended later accounting refusal. The paired controls exercise both admissions and finite/negative-infinite-fee refusals.

Inf-fee behavior remains unchanged: dense public execution refuses at lot accounting; availability completes with zero fills and insufficient-cash diagnostics. The prior dense/availability refusal-order cases, missing-bar gate and final-bar warning behavior match the base by execution. This is a bounded equivalence result for these controls, not an exhaustive execution-path claim.

No new finding, product defect or weakened oracle was found within scope; no additional patch is requested. The product change remains confined to fee/cash validation, adds no execution-mode branch or growing-collection loop, and preserves the existing regression fixtures and assertions. The only patch deviation is the harmless explanatory test comment/spacing noted above.

The new product/gate identity is separately recorded in `dev/bench/v0_2_3_ws4a/records/ldg3166/correction2/README.md` and `sequence.log`; historical gate outcomes remain intact. Those broader gate results are implementer evidence, not independent reruns here. No timing, memory, real-data workload or full suite was run. Only this requested report was added to the repository; no commit was made.
