Verdict: PASS
Role: record; independent clean-context focused re-review of LDG-3155 (correction round 2).
Status: accepted; review recorded 2026-10-29.
Authority: review evidence against the accepted cut; this file grants no new implementation scope.

Reviewed correction commits 7f3eeecb, 7577768e and 1f189850 against both previous reviews. Initial HEAD was 1f189850; the inspected harness and methodology files match that commit (diff exit 0). Authority is the accepted cut and LDG-3155/LDG-3156 in `tickets.yml:570-605`, with the methodology's paired-gate section at `inst/design/manual/benchmark_methodology.qmd:196-313`. This is Type 1: the implementation satisfies the requested corrections; I found no unresolved design question or gate correctness defect requiring another correction round. Product semantics remain governed by `contracts.md#contract-execution-fold-core` and `#contract-strategy-reproducibility`.

The smoke inputs remain appropriate independently of the implementation claims: two cells, eight pairs, one illustrative bound of each kind, public snapshot/run APIs and invariant work. A/A establishes validity and observed noise, not improvement. The accepted quiet-host prerequisite and observation-only CPU policy are preserved. This review adds no statistical precision claim or new host policy.

## N1: resolved

`protocol.R:131-170` now provides the shared input path construction, Git comparison and line-ending-insensitive text reader. All six harness and four protocol files are compared with `git show <harness_commit>:<source>/<file>`; missing/unreadable sources, failed Git reads and differing text fail. The runner's live, frozen-start and frozen-end checks use this helper (`runner.R:66-72,134-139,269`), and the checker independently checks the retained copies (`check.R:76-83`), including commit availability. Start/end success strings alone are insufficient. The existing supplied-protocol versus saved-protocol comparison remains at `check.R:43-47`.

`harness_source` and `protocol_source` are recorded from repository-relative normalized input paths (`runner.R:68-70,152`) and required by the checker (`check.R:51-58`). Their validity is established by successfully reading and matching every source file, rather than by requiring a canonical folder spelling. Missing protocol_source, a wrong harness_source and an unavailable commit each returned **1**, including `inputs changed`. The changed frozen measure.R demo returned **1**; unchanged copies and CRLF-only changes returned **0**.

**Changing protocol_source cannot substitute a different threshold map while checking the expected protocol.** In a temporary committed repository I supplied a sibling with identical matrix, workload and note but bounds of 2. Changing only protocol_source returned **1 / inputs changed**. Also replacing the saved threshold file with the sibling's committed file returned **1 / protocol changed**, because the caller still supplied the original protocol. The sibling control returned **0**. A different committed source containing all four identical files also returned **0**, appropriately: it changes no checked content. A source ending in `/.` returned **1** because that literal Git tree path does not resolve; the runner's normalization does not emit it. Changing the caller's protocol as well would explicitly ask to check a different protocol, outside the proposed source-only dodge. These checks establish content provenance, not authenticated authorship of session fields.

The fixture change is justified and recorded in the ticket evidence. Diff inspection confirms that the original synthetic timing, arm and host construction and existing case oracles are unchanged: only input provenance/copying, the retained interruption pointer, helpers and new cases change (`demo/check_demo.R:28-36,45-90,198-237`). All synthetic checker cases reach the same integrity check; none is exempted. The two allocation assertions intentionally exercise allocation functions, not checker records.

Using HEAD at demo invocation is sound for a runnable synthetic validator demonstration: copies and their recorded identity refer to the same real commit. It is not a promise to reproduce an old result CSV against arbitrary future source. Replaying historical code requires its checkout; normal future runs require the committed smoke files to remain available and consistent. Failure when required Git objects or protocol contents are unavailable is appropriate. Retained real records continue to name 7f3eeecb even after HEAD advances; both new attempts' ten saved inputs independently verified against that older commit.

## N2: resolved

`check.R:132-168` orders executed rows by launch sequence, computes each preceding boundary as max(launch, creation), and checks snapshot order and inclusive bounds. Before/after must have absent slots; before is no later than the first launch; each during snapshot is no earlier than the preceding boundary and no later than its own launch; after is at least every launch/creation boundary. Execution order is independently checked against OS creation order at `check.R:226-249`. The existing schemas, exact coverage, duplicate/unexpected-slot and root checks remain.

The stale-during, premature-after and before-slot-999 demonstrations all returned **1**. Independently, a during snapshot 0.001 ms before the previous creation returned **1 / host snapshots**. A snapshot exactly equal to its own launch returned **0**, and after exactly equal to final creation returned **0**. These are correct inclusive-boundary controls, not false passes. Moving the before and first during snapshots beyond the first launch returned **1**. No remaining false pass or valid-record rejection was found in these focused checks.

The real smoke-aa-r2 record has 32 successful rows and 34 snapshots (before, 32 during, after). Its chronology checks pass. The interrupted attempt has two ok rows, one process_failed, 29 not_run and five snapshots (before, three during, after); its chronology/input checks also pass while status, hook, missing executions and host departures correctly invalidate it.

## N3: resolved

`check.R:196-209` documents and implements `created >= floor(launched_ms) - 1` and an upper bound of the next launch, or after for the final slot. There is no elapsed-60-second cutoff. PID plus creation time remains the identity; the chain must start with that identity and affinity (`:207-222`).

The reasoning is appropriate at the recorded precision. Launches are R wall-clock doubles serialized to six fractional decimal places (`runner.R:201-206`); PowerShell uses integer Unix milliseconds for both creation observations (`host.ps1:25,32`). Flooring can put a creation in the launch's own millisecond below its fractional launch value. The extra millisecond covers boundary representation/rounding; it is not a one-second grace period. For example, a value just below the next millisecond can round upward when serialized to six decimals. Six printed decimals alone do not guarantee clock accuracy: the installed R Sys.time documentation describes platform-dependent resolution and Windows ticks. The actual retained Windows launches have fractional milliseconds, with smoke creation-minus-launch ranging **-0.238037 to +4.947021 ms**; this is consistent with the bounded representation allowance. The code does not need a universal sub-millisecond accuracy guarantee.

The registered sub-millisecond flooring, distinct-creation PID reuse and five-second delayed-creation controls all returned **0**; -999 ms and final creation beyond after returned **1**. Independently, exactly one millisecond early passed and two milliseconds early failed, matching the stated allowance. Creation exactly at the next launch passed **only after** its following pre-slot snapshot was also moved onto that boundary; keeping that snapshot earlier correctly failed N2. Creation one millisecond past the next launch failed. A final creation **65 seconds after launch**, with after extended beyond it, returned **0**, directly confirming removal of the arbitrary cutoff. These controls are synthetic chronology evidence, not observed process startup delays.

## N4: resolved for gate validation

`check.R:63-70` trims both disposition text and the required reference, rejecting NA, empty/whitespace-only strings and the trimmed literal `none`. The existing maintainer-role requirement and real-reference control remain. Both supplied whitespace negatives returned **1**; my literal `"none "` reference and text cases each returned **1 / disposition**. This agrees with the runner's trimmed nonblank requirement (`runner.R:79-86`). The runner is less strict about the sentinel itself; that is an early-refusal improvement below, not a checker false pass or rejection of a valid disposition.

## Regression evidence and commands

Artifacts are under `C:/Users/maxth/AppData/Local/Temp/ldg3155-r3-20261029` (T). Scripts are `C:/Users/maxth/AppData/Local/Temp/ldg3155-r3-{setup.ps1,probe.R,extra.R}`. R was 4.6.1 ucrt on Windows; startup emitted the existing C.UTF-8 locale warnings. No runner, workload measurement, product tests/build/check or frozen-input editing demo was executed. That demo was read only, since it edits live inputs. Only this review file was written in the repository; no repository commit or ticket edit was made. The unrelated design and held timing files were left alone.

- `git -C C:/Users/maxth/ledgr-wt/ws2-rng status --short`: **1**, ownership refusal. Repository inspections subsequently used the requested explicit `--git-dir=C:/Users/maxth/Documents/GitHub/ledgr/.git/worktrees/ws2-rng --work-tree=C:/Users/maxth/ledgr-wt/ws2-rng` form: **0**. No persistent Git configuration was changed. Target-files comparison with 1f189850: **0**. Correction-range diff for older retained records and both manual forms: **0**, empty. Other Git show/log/diff and file inspections: **0**.
- `powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:/Users/maxth/AppData/Local/Temp/ldg3155-r3-setup.ps1`: final **0**. It copies the harness unchanged to T/dev/bench/timing, points T's temporary .git file at the existing object store, and runs `Rscript T/dev/bench/timing/demo/check_demo.R`. Results are written only in T. All **40 cases** match the committed expectations: **38 checker subprocesses** (seven exits **0**, 31 exits **1**) plus **two allocation assertions**, both TRUE and without subprocess exit codes. The generated CSV is T/dev/bench/timing/demo/check_demo_results.csv.
- `Rscript C:/Users/maxth/AppData/Local/Temp/ldg3155-r3-probe.R`: final **0**, with the unchanged checker copy and a passing control. T/independent_results.csv and T/independent-good/*.log record the individual results below. A temporary independent repository supplies genuinely committed sibling/ten-cell inputs; no original Git object or ref was written.
- `Rscript C:/Users/maxth/AppData/Local/Temp/ldg3155-r3-extra.R`: final **0**. The 65-second and identical-committed-source controls each exit **0**. It also invokes the **repository's actual check.R** on smoke-aa-r2 with --aa, using process-local GIT_DIR/GIT_WORK_TREE for the supplied ownership fallback: checker exit **1**, exactly **host policy 1; foreign R 66**, with no integrity, snapshot, identity or order failure. Full output is T/original_smoke_aa.log.
- `Rscript -e "cat(tools::Rd2txt(utils:::.getHelpFile(help('Sys.time'))))"`: **0**, local R documentation inspection.

Temporary setup corrections were necessary: the first PowerShell wrapper returned **1** because Stop treated R's startup stderr warnings as a terminating native-command error; it was corrected to capture those warnings. An initial independent-probe run returned **0** as a script but its control failed integrity because git -C against the original worktree still hit ownership refusal; those results were discarded and the probes rerun with the unchanged temporary checker and a passing control. The extra probe initially returned **1** after completing its checks because of a scratch-script regex escape error; the final assertion was corrected and rerun successfully. None required changing a harness fixture or oracle.

| Independent case | Checker exit | Result |
| --- | --- | --- |
| Clean control; committed sibling fixture control | 0 each | Expected |
| Unavailable commit; missing protocol_source; wrong harness_source | 1 each | inputs changed (also missing field where applicable) |
| Sibling source with different bounds, saved copy untouched | 1 | inputs changed |
| Same substitution plus saved threshold replacement | 1 | protocol changed |
| Alternate committed source with all four identical files | 0 | Content still matches |
| Literal nonresolving source ending in `/.` | 1 | inputs changed |
| During exactly at its launch; after exactly at final creation | 0 each | Inclusive boundaries |
| Before after first launch; during before previous creation | 1 each | host snapshots |
| Creation exactly at next launch, next probe still earlier | 1 | host snapshots |
| Creation and next probe both at next launch | 0 | Inclusive boundaries |
| Creation one ms past next launch | 1 | host snapshots, process identity, executed order |
| Creation one ms early; two ms early | 0; 1 | Stated representation allowance |
| Disposition reference `"none "`; disposition text `"none "` | 1 each | disposition |
| Final creation +65 s, after extended beyond creation | 0 | No arbitrary startup cutoff |
| New retained interrupted attempt, --aa | 1 | Invalid/incomplete attempt and host departures; inputs/chronology pass |
| smoke-aa-r2, --aa | 1 | Only record-only policy and foreign R |
| Committed ten-cell, eight-pair, 0.97/1.03 synthetic gate | 0 | 160 planned and successful slots |

## Size, readability and first consumer

The six-file core is **986 lines**: check.R 307, runner.R 281, protocol.R 182, host.R 114, measure.R 66, host.ps1 36. That leaves only 14 lines before the requested 1000-line stop signal. It remains readable: direct validation sections, one shared input verifier, and explicit chronology calculations. Removing duplicated policy headers did not remove execution checks or conceal a new abstraction layer. These are bounded cold orchestration loops, not product execution-core changes.

The manual is now the central policy statement to which the shortened headers point, rather than a third copy of long rule lists. It is not literally the sole statement of every validation detail: record schemas remain in protocol.R, and the millisecond allowance/window mechanics are explained beside their checker code. The manual's Inputs paragraph describes runner checks but does not yet mention the new checker re-verification. This does not contradict it or weaken enforcement; documentation completion is Optional below. The rendered/manual pair is unchanged by this correction range.

**Fitness for LDG-3156: yes.** A temporary committed ten-cell protocol with two 0.97 bounds, eight 1.03 bounds and eight pairs produced a 160-slot synthetic gate accepted by the unchanged checker. The generic plan, bound map, argument transport and independent clocks impose no ten-cell obstacle. This checks layout and validation, not the unimplemented real consumer's workload correctness or noise.

Before the first real window, LDG-3156 must still commit its four-file protocol and demonstrate its specified corruptions, freeze the actual inputs/seeds/clocks and use invariant-by-construction stochastic work (the shared checker enforces invariant work; it does not implement arm-specific expected work). Run the base against itself and check with --aa. The host must have High performance, inherited affinity 0xFFFF and no foreign R processes, including all Positron ark kernels and other review Rscript sessions. Closing Positron alone does not satisfy the separate requirement to close other background applications. Arm installations/dependencies and readable matching CIM/Get-Process identities must succeed. A later gate attempt needs the recorded maintainer disposition/reference; an invalid window remains retained. A quiet A/A run must establish the actual noise. These are existing prerequisites; no remaining harness defect identified here blocks that window.

## Optional

- Align the runner's early disposition guard with the checker's trimmed `none` rejection (`runner.R:79-86` versus `check.R:63`). Presently a sentinel can waste an attempt before the checker rejects it; it cannot yield a passing gate, and it is not a valid disposition being falsely rejected. No patch is required for this verdict.
- Add one sentence to the manual's Inputs paragraph (`benchmark_methodology.qmd:249-254`, with its rendered sibling) that the checker re-verifies saved inputs against the recorded commit. Keep detailed schemas and precision reasoning beside the code. This is documentation polish, not another correction round.

No required patches and no re-review are needed for LDG-3155. Ticket disposition remains the maintainer's; this review did not perform or certify the first real timing window.
