Verdict: PASS
Role: record; independent clean-context Type 1 close review of workstream 11.
Status: accepted; review recorded 2026-10-29.
Authority: review evidence against the accepted cut; this file grants no new implementation scope.

Reviewed `565e8bbf..8e1880bf` on `claude/ws2-rng`, with final product
candidate `a19f7f23a68e6ed3b147a1bbb532f5bcd3218f97`. Initial and final HEAD
were `8e1880bfe9db4bc44330994f17d1618bbc5c1e7e`. Authority is AGENTS.md;
cut 4 decisions (1)-(17), amendment and LDG-3155..3161 in
[tickets.yml](tickets.yml); [ws2_rng_design.md](ws2_rng_design.md), especially
Sections 5 and 8; `contracts.md#contract-strategy-reproducibility` and
`#contract-execution-fold-core`; and the benchmark manual's Before/After
Regression Gates. The previous ticket/design reviews were treated as prior
evidence and spot-checked. This review concentrates on LDG-3160, LDG-3161 and
the harness changes after its PASS.

## Findings, ranked by severity

No required findings or patches. No wrong shipped behavior, unexplained
successor difference, weakened registered oracle, or unsound use of the
recorded timing gate was found. No unsettled design concern requires Type 2.
The optional wording notes below do not condition this verdict.

The inputs are appropriate independently of the recorded claim: the timing
matrix includes seeded and unseeded deterministic workloads and a genuinely
drawing stochastic workload with invariant nonzero work; the original native
records remain immutable; the economic successor expectations come from the
unchanged base with an independently implemented pulse rule; and source-copy
reversions reach the worker processes. Fresh control records reproduce the
committed successors byte for byte. These are stronger controls than accepting
new expected economic outputs from the candidate alone.

## 1. Shared harness after its PASS

The changes from `09e7fb82` preserve the checks that establish the ratio's
meaning. `dev/bench/timing/check.R:78` rechecks saved inputs against their
commit; `:85` checks arm separation/A/A classification; `:96` checks the saved
plan; `:106` checks exact slot coverage; `:138` checks host snapshot coverage
and chronology; `:188` checks loaded arm identity; `:192` checks fresh process
identity; `:215` checks the chain to the root; and `:219` checks actual executed
order. Work equality and per-cell medians remain checked at `:245`.

High performance and affinity 0xFFFF remain enforced before provisioning,
before the window, before each slot and in the recorded measurement evidence
(`runner.R:89`, `:219`, `:230`; `host.R:117`; `check.R:171`, `:190`).
`host.R:104` requires the measured process's chain to reach the specific root
identity, with every intervening affinity pinned. PID plus creation time,
including the binding between CIM identity and Get-Process affinity, remains
intact (`host.R:32`, `:53`; `host.ps1:25`). Removing the foreign-R and temporary
busy-process rules did not remove any identity, order, input or coverage check.

Background load, top processes and foreign R names are observations only.
Neither the root guard nor the row guard reads them as a rejection reason.
The `--host-policy=record` bypass was removed along with the rules it bypassed;
power/affinity checks are unconditional. The new observation control passes,
while power-plan, descendant-affinity, substituted-child, PID-reuse and
chronology negatives fail. All **42** shared checker/allocator cases and all
**6** ws2-timing-1 cases reproduced their expected outcomes on unchanged
harness copies outside the repository. No timing measurement was run.

`protocol.R:123` exclusively creates a slot directory, refuses an occupied
destination and registers removal before calling the slot. `runner.R:205`
uses it; `measure.R:31` checks emptiness before loading the workload. The direct
demonstrations cover consecutive identical store names, error cleanup and an
occupied slot. The final workload uses a fixed filename inside that fresh
directory, eliminating the reused-PID collision without changing timed work.

The manual's paired-gate section (`benchmark_methodology.qmd:197`) and its
rendered Markdown match the code. Its normal-desktop policy is explicitly scoped away from the
fast-profile and peer policies. The clock probe's 32 rows reproduce wall
ratios **1.004163/1.011784**, with per-pair SD **0.003721/0.037432**; process-CPU
SD is **0.028632/0.042456**. This supports keeping wall time and lengthening
short cells. It does not prove immunity to arbitrary background load.
Together with the actual ten-cell A/A calibration, frozen repetitions,
alternating arms and the explicit maintainer policy, it is sufficient evidence
for this local gate. No general statistical precision or causal attribution
to background applications is claimed.

## 2. Timing records

The actual repository checker returns **0 / A/A VALID** for
`base-aa/attempt-3 --aa` and **0 / CHECK PASS** for `gate-final/attempt-1`.
Each has 160 successful slots, eight complete pairs per cell, distinct arm
libraries, matching commit stamps, verified frozen inputs and complete
plan/host evidence.

The A/A arms are actually **38d44a20**, not 3a67db60. I independently verified
that their R/src/DESCRIPTION/NAMESPACE object IDs equal those of the gate base
**3a67db60**. The gate candidate is **a19f7f23**, harness **99af6d1e**.
The first valid base window starts at 15:16 UTC, after repetitions were
committed at 14:42 UTC (`0de48f7f`) and slot/store naming at 15:08 UTC
(`5638b490`). Both checker protocol comparisons pass. No valid record predates
those edits.

Attempt 1 remains invalid after the busy-process stop; attempt 2 remains
invalid at slot 53 after the store collision. The next session in each case
records the previous failure and the maintainer's rerun disposition. Neither
was discarded, relabeled valid, or retried to improve a ratio.

| Cell | Candidate/base | Bound |
| --- | ---: | ---: |
| dense run seeded | 0.9293624 | 0.97 |
| dense sweep seeded | 0.9070576 | 0.97 |
| dense run unseeded | 1.0034124 | 1.03 |
| dense sweep unseeded | 1.0046113 | 1.03 |
| timing run seeded | 0.9630580 | 1.03 |
| timing sweep seeded | 0.9580263 | 1.03 |
| timing run unseeded | 0.9913020 | 1.03 |
| timing sweep unseeded | 1.0041803 | 1.03 |
| stochastic run seeded | 0.9566075 | 1.03 |
| stochastic sweep seeded | 0.9450611 | 1.03 |

The A/A ratios range from 0.9977674 to 1.0039290. Repetition counts are frozen
at four for timing-scale runs, six for its sweeps, and one elsewhere. The
workload checks every repetition and uses distinct committed-run IDs
(`protocols/ws2-timing-1/workloads.R:106`). The gate needs no exception.

## 3. Successor oracles

Both comparators rerun successfully: **A0 295/295**, **RNG 26/26**.
The fresh no-edit source-copy control also regenerates all **290 A0 files**
and **9 RNG tables**, including manifests, byte-identically to the committed
successors. Git diff across the full workstream range is empty for both
original oracle directories: their records, checkers, fixtures and guts are
unchanged.

Decision (17) is implemented narrowly at `a0/record.R:27` and tested at
`a0/compare.R:149`: the exclusion list gains exactly
`wf_folds.selected_at_utc`, keeps every old row unchanged, and the observed
table loses only that column. There is no other new wall-clock exclusion.

A1 covers exactly 14 seed-contract attribute files; A2 covers exactly 14
provenance files; A3 checks the precise rule-field addition and recomputed
config hashes in 11 seeded run directories, leaving two unseeded ones
identical (`a0/compare.R:113`, `:230`). A4 requires exact model equality and
the frozen changed-row counts, confined to `tight`: 5 ledger events, 5 fills,
6 equity rows, 2 trades, 7 metrics; memory events 6, fills 5, equity 6; sweep
1, returns 6, trades 2. All other A4 rows remain identical.

The model archives **aa2931e9** and replaces only the scalar pulse-rule
function for sequential execution (`a0/model.R:27`; `rng/model.R:29`).
`lib.R:42` implements an independent logical-bit/shift-and-add reference;
it neither calls nor copies the production 16-bit split routine and passes
all 63 fixed golden values. A5's agreement mask is sound here: I independently
checked that the original w1/w2 files agree completely in all four affected
files, so its predicate requires full successor equality. Those successor
files are also independently byte-identical between w1/w2. The remaining
224 A0 files are unchanged.

The RNG recorder reuses the original fixture and strategies, replacing only
the permitted current-rule/accessor observations and census observations
(`rng/probe.R:31`, `:48`, `:100`). The comparator freezes the original 13-column
header plus the seven typed columns, copy rows 03/08, entry absence, exact
callers and the independent E/S ledger (`rng/compare.R:102`, `:139`). There is
no blanket census exemption. Row 05 must succeed unseeded with 19 reads.

Every changed economic group has its named cause: v2 supplies the sequential
stochastic model; kind pinning makes worker trades equal the sequential
successor; RNG-neutral storage supplies the two frozen store-equity values.
Worker trade counts are 33/36/39, with nonzero actions across six instruments.
Only caller-state rows 01/05/09/13/15 change their permitted state fields;
`detection_gap` is identical. No additional economic allowance was found.

The original A0 checker independently returns **1**, with exactly the same
52 attributed file differences and 213 agreement checks/four existing
disagreements. I independently matched that entire changed-file set to the
successor differences, excluding the successor's new exclusion-list row.
The original RNG checker independently returns **1** at the deleted scalar
observer, with nine missing rerun tables. These are expected historical-oracle
failures, not passing unchanged-oracle claims.

## 4. Replacement guts and R8 disposition

I reran **control, R1-R8, R8v, R9 and R10** on archives of a19f7f23.
The complete generated CSV equals the committed `guts.csv` in every value.
The control fails nothing. Each of the ten regression guts, using R8v for
R8's A3 obligation, fails every named predicate with **zero errors**:

| Gut | Predicate actually discriminated |
| --- | --- |
| R1 | Worker agreement and stochastic w2/w1 equality |
| R2 | Frozen store-equity equality |
| R3 | Caller state, drawing unseeded run and captured-service/helper witnesses |
| R4 | Census row 05 successful unseeded walk-forward |
| R5 | Independent pulse values and A4 |
| R6 | Seed-sensitive pulse values and stochastic model equality |
| R7 | A1 and A2 markers |
| R8v | A3 in ten files plus A4+A3 in the eleventh |
| R9 | Census immediate seeding caller/kind |
| R10 | Walk-forward results-marker copying and early refusal |

The mechanism is worker-visible: edits are applied to archived R sources
before subprocess loading (`guts.R:129`), and mirai loads the loaded package's
source path (`R/parallel-workers.R:195`, `:295`). Compiled objects are reused
only for unchanged src code. Comparators run from the unmutated tree. Expected
predicate failures, recorder errors and test-block errors are counted separately.
R4's captured expected product error is correctly a failed outcome predicate.

**R8/R8v is sound.** R8 alone has one recorder error and never reaches A3;
it is explicitly labeled validator evidence. Its final recorder error is a
missing resumed run, so I additionally executed a direct seeded run on that
mutated source. It raises `ledgr_seed_rule_mismatch/ledgr_invalid_config`
for the missing field and leaves **zero run rows**. R8v removes that validator
check as well, reaches the stored configuration, and independently fails A3
with zero errors. It exposes the downstream oracle's sensitivity without
weakening the shipped validator or counting an error as an A3 success.

The runner's process exit 0 is evidence generation, not sufficient proof of
gut success: I separately asserted every CSV verdict, expected failure and
error total. No automated consumer relying only on that exit was found.

## 5. Final candidate and incidents

I reproduced the digest
`44a82e00f12744f54c47ab3c1a2fe98dbe4da1dec3cbd7cefd16f187b30ed9db`
from the seven `path object-id` lines, LF-separated with a final LF.
The product trees in that digest are unchanged from a19f7f23 through HEAD.
The earlier 9f189027 differs only by the documented census-fixture relocation
within those product paths.

`final_candidate.csv:3` records the clean full-test rerun, zero failures/errors
and the existing quantmod skip. Lines 4-5 record build/check exits 0, no ERROR
or WARNING, and only the pre-existing unqualified `head` NOTE. This close
review did not repeat the full suite or package build/check. It independently
ran the control's isolation file (25 blocks/837 expectations), pulse-seed file
(16 blocks/230 expectations) and census test (10 expectations), all with zero
failure/error/skip. The previous LDG-3158 review independently exercised the
NMOF LSopt gate and its failing base control; the reviewed pinning path remains.

The LTB-0269 change is a pure relocation: `a19f7f23` changes only the fixture
address `R/sim-pit-inputs.R:317` to `:320`. The test file has no workstream
diff. I reran its exact scanner on the pre-documentation and final source
trees: the same 17 literals have identical source text; only this line moved.
The test itself also passes on the candidate copy.

The two platform logs contain the same 63 integer triples and zero mismatches.
`golden_platform.R:14` executes the installed production routine, rather than
printing expected values. Reuse of the 9f189027 platform executions is sound
because the installed code and golden fixture are unchanged at a19f7f23.
Linux was not independently relaunched in this review.

The concurrent-relink failure is retained as a failed attempt and followed
by a clean nonconcurrent full-test rerun. It is a source-loading incident,
not a changed test oracle. Rebuilding the cleared WSL library before the
successful installed-package check similarly leaves no missing platform
evidence. Neither incident invalidates the final records. This review's
concurrent checks used separate source copies for package execution.

## 6. LDG-3160 contract, article and NEWS

The amendment matches the implementation. In particular:

| Contract sentences | Code/evidence |
| --- | --- |
| Direct ambient-RNG detection limit and supported recipe (`contracts.md:1868`) | `R/strategy-preflight.R:267`, `:682`, `R/run-resume.R:1`, parallel refusal in sweep; no detector widening |
| Pinned kinds and unseeded distinction (`:1881`) | `R/rng.R:157`, `R/fold-engine.R:1619`, simulator envelope calls, `R/parallel-workers.R:203` |
| Exact versioned pulse rule and run-calendar equality (`:1889`, `:1907`) | `R/rng.R:42`, `:50`, `:75`, `:101`; one vector at fold entry; straight/resume/window/skip/worker/promotion witnesses |
| Version markers, seeded configuration and fingerprint (`:1900`) | `R/backtest-config.R:194`, `R/sweep.R:456`, `R/walk-forward.R:302`, `R/walk-forward-inspection.R:143`; identity rerun |
| RNG-neutral storage (`:1915`) | Sole operational raw append in `R/rng.R:235`; source inventory, drawing error controls and checkpoint/path witnesses |
| Caller restore and its boundary (`:1922`, `:1932`) | Force/preserve exports and methods, `R/rng.R:161`, `:175`, `:196`, `:208`; cleanup in inner implementation frames; argument/S3/helper/interrupt/Box-Muller witnesses |
| Candidate/configuration/store refusal (`:1951`) | `R/rng.R:114`, `R/sweep.R:848` before hold at `:849`, `R/config-validate.R:78`; actual old-store/candidate identity checks |

Decision **(15) validly refines (14)**: it explicitly states the operative
replacement for the earlier S3 wording, identifying dispatch after entry as
inside restoration. This is a recorded maintainer choice, not an inference
from newer prose. Ordinary supplied arguments are forced before capture;
captured `rank_by`/`.filter` expressions remain inside; S3 calls inside the
restoring implementations are restored. Unwrapped entry points leave user
methods as caller code. The dispatch-only candidate generic places the guard
in its two operational methods. Decision (16)'s signal-strategy and adapter
callables remain machinery without their own preserve. Returned indicator-dev
test helpers force arguments and restore on each call. The docs state exactly
this boundary, including Box-Muller and externally held generator-state limits.

I rendered an unchanged archived article with Quarto outside the repository:
**all 41 chunks execute**, including the mirai two-worker chunk. The rendered
results agree with the committed Markdown: seed-required failure; fills
**123 versus 131** and different tables; execution seeds **359458135/724846829**;
worker equities **10018.95/10001.72**, trades **56/58**, equality TRUE; caller
state TRUE. NEWS names kind/worker changes, non-default-kind simulator changes,
v2 stochastic results, storage-dependent ambient-result repair, caller restore,
unseeded walk-forward, identity changes and old-marker/store refusal. Its
default-kind sequential statement is explicitly about kind pinning; the
separate v2 entry declares the additional result change.

## 7. Identity

The independent rerun of `identity.R` against **3a67db60/a19f7f23** passes all
19 checks. Snapshot content/identity rules stay 4 and the same canonical input
keeps hash `b54a78e3c666400c17a9670addcd2b51212ad1adef8519e6e72a045361d515d4`.
Seeded configuration gains only `pulse_seed_rule = 2`: hash
`a64da030...5894574c` becomes `91229b23...a317f72`, and generated run ID
`run_c2972ecc9472b4d8` becomes `run_e9c5c0be332eabfa`.

As a concrete independent spot-check, the unseeded configuration reproduces
the full hash `5946f113bd75b1c1ad748a408e7310aa3142bd56c7cbdb2cd79d5c71dcd8d2b5`
and `run_ddacac4bf6b7b5b3` in both arms. All 27 common store bindings are
identical; the sole addition is integer `ledgr_pulse_seed_rule_version = 2L`.
Fingerprint hashes reproduce `4943b947...19fc5731` and
`4b501900...b74b4b53`. The actual old store refuses with
`ledgr_store_rebuild_required`, cause `fingerprint_mismatch`, differing constant
exactly the pulse-rule version. The actual base candidate refuses with
`ledgr_seed_rule_mismatch` and creates zero run rows. Candidate execution seed
344820648 is unchanged.

## 8. Seven shapes on touched fold/hydration/finalisation paths

| Manual shape, verbatim | Assessment |
| --- | --- |
| One-row frame per element, bound at the end. | None added; existing append boundary frames are unchanged. |
| Full-table subset inside a loop over ids. | None added. |
| Per-element parsing or formatting where a vectorised call exists. | Vectorized pulse preparation; no new per-pulse formatting loop. |
| Per-row JSON on repetitive strings. | Per-decision JSON/SHA-256 removed. |
| Work computed and discarded, or recomputed on every call. | One vector per seeded fold; unused resume-prefix/skip entries are the accepted tradeoff. Fixed state guards per entry/append; no new replay/collection scan. |
| Quadratic validators. | None added; vector validation is linear and done once. |
| Scalar writes into an environment-held vector. | None added; pulse seeds are read-only indexed primitives and typed output buffers remain unchanged. |

The argument-force loop is over formals/call frames, not bars or candidates.
The store helper does fixed work around existing batch writes. Indicator-dev's
old interactive date loops were relocated unchanged. One fold core and its
execution branches remain; no second engine or execution-mode branch was added.
The end-to-end timing evidence above covers the resulting implementation.

## 9. Governance and record clarity

All seven tickets are complete; acceptance/evidence item counts match in order:
LDG-3155 **6/6**, 3156 **3/3**, 3157 **4/4**, 3158 **5/5**, 3159 **6/6**,
3160 **3/3**, 3161 **5/5**. Evidence identifies the relevant commands, revisions,
results, intentional test changes and incidents. The governance report has
**zero findings for these tickets or their review files**. It is not globally
clean: its unrelated population has 1171 findings, 846 new structural ones.
The existing review headers correctly mark records as accepted records,
without granting implementation scope. Cut/workstream remain open/in progress
pending maintainer close acceptance, which is consistent with completed tickets.

The old `v0_2_3_cut3_successors` name is explicitly frozen in the accepted note
(`ws2_rng_design.md:894`) and used by the evidence. A rename is unnecessary;
the renumbering amendment and current workstream headers explain it. Historical
cut-review names/IDs likewise remain evidence and still count. A short routing
note is sufficient if additional navigation clarity is wanted.

## Optional

- `ws11_disposition.md:67` should distinguish the control from the mutations:
  say "The control fails nothing; R1-R7, R8v, R9 and R10 each fail their named
  predicates with 0 errors." The existing CSV and final-candidate record are
  unambiguous; this corrects loose summary wording.
- Add a short protocol-history note naming `0de48f7f`/`5638b490` and saying
  both earlier attempts were invalid before the first valid freeze. The manual's
  literal "never edited after its first record" at
  `benchmark_methodology.qmd:218` is stricter than this maintainer-directed
  history. The retained attempts and directions explain the exception; the
  valid base and candidate use identical frozen inputs. Do not silently relax
  the general freeze rule or rewrite the invalid records.

## 10. Governance count for cut 4

One invocation contributes one verdict, including combined-mode cut reviews.
There are **11 independent verdicts / 7 completed tickets = 11/7 (1.5714)**,
including this close review. No dropped ticket contributes; maintainer
decisions, implementation self-checks and individual gut subprocesses are not
additional independent verdicts.

| Invocation / record | Independent verdict |
| --- | --- |
| `cut_review_3.md` (historical cut 3 / WS4; now cut 4 / WS11) | CHANGES_REQUIRED |
| `cut_review_3_rereview_1.md` | PASS_AFTER_PATCHES |
| `ldg3155_harness_review.md` | CHANGES_REQUIRED |
| `ldg3155_harness_review_2.md` | CHANGES_REQUIRED |
| `ldg3155_harness_review_3.md` | PASS |
| `ws2_rng_design_review.md` (LDG-3157) | NEEDS_TYPE_2 |
| `ws2_rng_design_review_2.md` | CHANGES_REQUIRED |
| `ws2_rng_design_review_3.md` | PASS_AFTER_PATCHES |
| `ldg3158_review.md` | PASS_AFTER_PATCHES |
| `ldg3159_review.md` | PASS |
| `ws11_close_review.md` (this invocation) | PASS |

Totals: **4 CHANGES_REQUIRED, 3 PASS_AFTER_PATCHES, 3 PASS, 1 NEEDS_TYPE_2**.
The two cut reviews each combine Type 1 and Type 2 and count once. The initial
LDG-3157 verdict preserves its escalation; decisions (14)-(16) resolve it rather
than erasing that invocation. No third correction round is introduced here.

## Commands and exit codes

For compactness, R is `C:/Users/maxth/ledgr-wt/ws2-rng`, T is
`C:/Users/maxth/AppData/Local/Temp/ws11-close-audit`, S is
`C:/Users/maxth/AppData/Local/Temp`, and G is
`git --git-dir=C:/Users/maxth/Documents/GitHub/ledgr/.git/worktrees/ws2-rng --work-tree=R`.
Rscript is `C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe --no-init-file`.
Nested Git calls used process-local GIT_DIR/GIT_WORK_TREE for the ownership
fallback; no persistent Git configuration was changed. Temporary scripts
`S/ws11-close-*.R` and `S/ws11-close-run.ps1` retain the exact invocations.

| Command / inspection | Exit and result |
| --- | --- |
| `git -C R status --short` | 1, ownership refusal; subsequent Git inspections use G. |
| `G status --short`, `branch --show-current`, `rev-parse HEAD`; range/source/test diffs, log, show and object-ID inspections | 0; expected branch/HEAD and unchanged original oracle trees. |
| `Get-Content` / `rg` authority, code, record and review inspections | 0 when matching; exploratory nonmatching rg calls returned 1. Two initial multi-path Get-Content calls and two exploratory missing log paths returned 1, then corrected. |
| `Rscript R/dev/bench/timing/check.R --protocol=R/dev/bench/timing/protocols/ws2-timing-1 --record=R/dev/bench/timing/records/ws2-timing-1/base-aa/attempt-3 --aa` | 0, A/A VALID. |
| Same checker/protocol with `--record=.../gate-final/attempt-1` | 0, CHECK PASS. |
| `powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File S/ws11-close-run.ps1 -TaskName demo` | 0; unchanged temporary copies run check_demo.R (42 cases) and ws2_timing_1_demo.R (6 cases). Expected individual checker exits are 0/1; allocator assertions all TRUE. |
| `Rscript R/dev/bench/v0_2_3_cut3_successors/a0/compare.R --result=S/ws11-a0-close.csv` | 0, 295 checks, zero fail. |
| Corresponding `rng/compare.R --result=S/ws11-rng-close.csv` | 0, 26 checks, zero fail. |
| `powershell ... -File S/ws11-close-run.ps1 -TaskName guts` | 0; archives a19f7f23, writes only T/guts and T/guts.csv; 11 PASS rows including control, separate R8 validator-evidence row. |
| `powershell ... -File S/ws11-close-run.ps1 -TaskName identity` | 0; 19/19 checks, base 3a67db60/candidate a19f7f23. |
| `Rscript R/dev/bench/v0_2_3_output_freeze/check.R --pkg=T/article --out=T/original-a0 --agreement=T/original-a0-agreement.csv` | 1 expected; 52 precisely attributed differences, 213 agreement checks/four pre-existing disagreements. |
| `powershell ... -File S/ws11-close-run.ps1 -TaskName originalrng` | 1 expected; runs unchanged checker/probe copies on T/article, deleted scalar observer, nine missing tables, clean product scope. |
| `Rscript S/ws11-close-records.R` | 0; digest, original-oracle immutability, A/A/base product identity and governance report to T/governance.txt. |
| `Rscript S/ws11-close-extra.R` | Initial 1 from a missing closing brace in my scratch script; corrected run 0. A5, clock arithmetic, 17-literal scanner, platform-log equality and unchanged final product verified. |
| `powershell ... -File S/ws11-close-run.ps1 -TaskName article` | Initial 1: my reduced archive omitted data/, so the demo dataset was unavailable. Copied unchanged data/ into T/article, then the command below passes; no article edit. |
| `C:/Program Files/RStudio/resources/app/bin/quarto/bin/quarto.exe render T/article/vignettes/reproducibility.qmd --to gfm --execute-dir T/article` | 0; all 41 chunks, including random-workers; results match committed outputs. |
| `Rscript R/dev/bench/v0_2_3_ws2_reverts/runner.R --root=T/guts/control/tree --mutation=none --tests=schema-version-literals --out=T/schema-test.csv` | 0; one block/10 expectations, no failure/error/skip. |
| `Rscript S/ws11-close-r8.R` | 0; independently asserts missing-rule refusal and zero run rows on R8's source. |
| `Rscript S/ws11-close-finalchecks.R` | 0; asserts fresh successor bytes, original A0 changed-file set, control-test totals, ticket counts and every gut outcome; fresh guts CSV equals committed values. |
| `G diff --check 565e8bbf..8e1880bf` | 1, six trailing spaces in the two raw golden logs only; no source issue or evidence edit required. |
| `G checkout -- R/cpp11.R src/cpp11.cpp` | Initial 1, external index.lock permission; authorized escalated retry 0. Only these generated bindings restored. |
| Final `G status --short`; `G diff --exit-code -- R/cpp11.R src/cpp11.cpp` | 0; only this review and the pre-existing held draft are untracked; generated bindings restored. |

Recurring R startup C.UTF-8 locale warnings did not change exit outcomes.
No timing measurement, full-suite/build/check rerun, Linux rerun, commit or
ticket edit was performed. The held `dev/bench/v0_2_3_ws2_timing/` draft was
neither read nor modified. Only this review was intentionally written in the
repository; all execution outputs are outside it.
