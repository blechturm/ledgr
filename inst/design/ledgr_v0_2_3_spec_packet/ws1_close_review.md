Verdict: CHANGES_REQUIRED

Role: record; independent clean-context Type 1 close review of v0.2.3 cut 1, workstream 1.
Status: working; review recorded 2026-10-29.
Authority: verification against accepted cut 1 in tickets.yml; this review grants no new implementation scope.

Reviewed range: `07dbbc87..d8906f77`, branch `claude/ws1-output-handler`.
Product/test candidate: `697f32ee42c395aa6dc282e8a3f05fa8e4ae8d05`.
HEAD was `d8906f77654848078c3c7f69943909cbbc7d2b5f`. Its differences from
the candidate are the timing record, tickets and disposition only. Paths and
line numbers below refer to this HEAD unless a revision is named.

The implementation satisfies the accepted handler boundary, R3 ownership,
capability preservation and test-migration constraints. Independent A0,
focused tests and binding checks support the product claim. Closure still
needs a disposition of the timing host's departure from the frozen protocol
and a correction of the governance-debt classification. Neither finding
requires redesign; there is no NEEDS_TYPE_2 concern.

## Required findings, ranked by severity

### F1 - P2: Numeric timing PASS is presented as a completed protocol gate despite the recorded host departure

**Evidence:** `dev/bench/v0_2_3_ws1_timing/protocol.md:104` says "Close
background applications first; no other R session." The maintainer-host
methodology at `inst/design/manual/benchmark_methodology.qmd:186` also
requires background applications closed. `records/base_aa/meta.csv:31`
names Positron and TotalMixFX; `tickets.yml:68` explicitly says these and
SpotifyLauncher remained open. For the final gate,
`records/gate_final/host_start.txt:6`, `:7`, `:37` show Positron, TotalMixFX
and Steam. The process CPU columns in `records/gate_final/cpu_samples.csv:1`
also record Positron/Codex activity during measurement. Nevertheless,
`ws1_disposition.md:27`, `:41` and `tickets.yml:137` accept the gate without
identifying this protocol departure or linking a maintainer disposition.
Record paths in this finding are relative to `dev/bench/v0_2_3_ws1_timing/`.

Both independent `check.R` invocations exit 0, and every final ratio really
is <= 1.03. This finding does not allege falsified seconds or demonstrate a
product regression. The checker verifies power plan and affinity; it does
not enforce the background-application instruction. Its own protocol
explicitly distinguishes internal consistency from provenance. Disclosure
of open processes is useful evidence, but is not an acceptance of departure
from the frozen procedure. The protocol/code precedence sentence does not
create a disagreement here: omission of an automated application check does
not say that the application instruction is waived.

**Failure scenario:** a reader treats CHECK PASS as verification of the
whole registered-host procedure. Interference can differ between adjacent
arms, especially for the subsecond cells; alternation reduces this risk but
does not establish compliance. The A/A record already contains a 0.925 cell.
Total host CPU includes the measurement itself, and cumulative CPU in
host_start is not an instantaneous load measurement; neither proves that
background load caused any particular ratio.

**Exact required change:** retain both records unchanged. In LDG-3127,
LDG-3132 and the disposition, distinguish the numerical checker passes from
the unmet host instruction. Obtain and link the maintainer's explicit
disposition on reuse of these named records under their actual conditions,
or supply new, separately labelled records under the frozen host procedure
and have their evidence reviewed. Keep the candidate/base identities, eight
pairs, alternation and 1.03 threshold unchanged. Do not overwrite records,
silently amend the frozen rule, or retry/select measurements until green.
The reviewer must not grant that missing maintainer disposition. No timing
runner was executed in this review.

### F2 - P3: The "83 pre-existing header and link findings" route includes workstream-created debt

**Evidence:** `ws1_disposition.md:89` and `tickets.yml:54` describe 83
findings as pre-existing header/link debt outside this cut. Source-specific
scans using the production scanner and Git's tracked populations find:

| Population | Header/link findings | Other findings examined |
| --- | ---: | --- |
| Packet files at `07dbbc87` | 78 | Two invalid verdicts, at `macro_plan_review.md:9` and `strategy_grammar_closeout.md:5`; both files are unchanged |
| Packet files at `656ee7a5`, the activation evidence revision | 81 | The same two invalid verdicts; the three added header findings are in the newly introduced `ws1_phase_a_review.md:1` |
| Packet files at `d8906f77` | 85 | The same two invalid verdicts |

The current seven new header findings are three missing headers in
`ws1_phase_a_review.md:1`, an invalid Status in
`ws1_phase_a_review_2.md:4`, and three missing headers in
`ws1_phase_b_review.md:1`. Thus 83 at the cited activation revision is
80 inherited structural findings plus three new review-header findings,
not 83 inherited header/link findings. Current examined packet debt is
80 inherited plus seven WS1 review findings. The cut's scanner has not
changed these rules.

**Failure scenario:** the blanket outside-workstream route loses the owner
of new WS1 records' metadata failures and misstates the evidence behind
LDG-3126's clean-cut classification. It also makes the historical count look
like the current count.

**Exact required change:** correct the category, revision and inherited/new
split in `tickets.yml:54` and `ws1_disposition.md:89`. Preserve the historical
83 result as a result at `656ee7a5`, with its actual composition. Identify
the seven current WS1 review-header findings as this cut's record debt;
repair those headers under the scanner's accepted Role/Status/Authority
vocabulary or record their explicit maintainer deferral. Keep their verdicts
and substantive findings intact. The 80 inherited findings can remain
routed outside WS1; this finding does not request a packet-wide cleanup.

## Verification of the product claim

**Ownership and semantics.** `R/output-handler.R:390` contains the single
handler. Event columns/allocation/growth (`:418`, `:441`), row staging and
flush (`:534`, `:573`), status/failure/completion (`:606`, `:642`) and
diagnostic numbering (`:627`) have one owner. The DuckDB sink (`:25`) owns
transactions, persistence, seed/refresh queries, telemetry and state storage.
The memory sink (`:177`) owns leg/equity projections and retained diagnostics.
Neither sink duplicates the common event buffer or fill-row staging. Memory
leg staging is the distinct accounting projection specified by the accepted
design. The construction-time storage capabilities preserve absent optional
methods and existing discard policies.

The only product-file changes are the two constructor sites, removal of the
old handlers, the shared handler/sinks and publication-helper extraction.
The fold and compiled guard are byte-unchanged from base. There is no new
execution-mode branch, second fold core, constructor alias, migration or
old-format reader. This preserves
`contracts.md#contract-execution-fold-core` and
`contracts.md#contract-execution-compiled-accounting`.

**R3.** `R/ledger-writer.R:8` is the sole canonical-R publication formula.
The payload at `R/backtest-runner.R:132` supplies buffered DuckDB and memory;
the live writer calls it at `R/ledger-writer.R:83`. BUY/SELL casts and
arithmetic order are preserved. Memory does not compute another delta beside
the payload. The live writer retains validation, NO_OP, sequence selection
and transactions. The unchanged `ledgr_fill_leg_fees()` projects the resolved
fee across close/open quantities. Compiled batches publish supplied typed
deltas/leg fees unchanged. The amended
`contracts.md#contract-execution-accounting-events` matches that bounded
scope; the RFC pipeline closes only R3.

**A0.** Independent `check.R` exits 0: every frozen record is byte-identical;
agreement remains 213 checks with four documented differences. Independent
`gut.R` also exits 0: its control exits 0, all 17 corruptions exit 1, and
all 17 named-surface predicates are TRUE. The results were read back from
`T/ws1_close_gut_results.csv` and asserted independently. The range's A0 changes are only
the permitted observer/factory attachment, memory state adapter and two
DuckDB corruption wrappers. Active bindings reach the actual event buffer
and retained diagnostic owners. Fixtures, canonicalization, checker, control,
17 mutation identities/changes/expected surfaces and recorded bytes have
empty diffs. No frozen historical spike or A0 record was edited.

**Compiled admission.** LTB-0517 tests absent compiled append on buffered
DuckDB, refusal by both guard and fold, and memory admission under the same
spec. Existing memory compiled-parity and live-refusal cases passed. LTB-0518
pins exactly 21 callable methods on each DuckDB mode, 27 on memory and 19
shared names. The unchanged capability-sensitive guard therefore admits
exactly the former supported handlers.

**Identity.** Independently parsed every revision's `R/*.R` Git blobs and
evaluated its own top-level schema/rule-version assignments and its own
`ledgr_store_format_bindings()` in a private environment. Base and candidate
are identical over all 27 names, types and values, including store schema
124, identity rule 4 and snapshot hash rule 4. Current constants were never
substituted for base constants. Unchanged snapshot/config/identity sources,
A0's embedded config/run identities and unchanged store bindings support all
three "none" identity declarations. No dependency/public export changed.

**Final-candidate package verification.** LDG-3132 at `tickets.yml:136`
identifies `697f32ee` after the NEWS test repair and records full tests
(1228 blocks, zero failures/errors, only unrelated quantmod skip), build and
package-check exits 0, with the unchanged history-frame NOTE. The archived
candidate used for build/check is the product/test tree reviewed here;
`d8906f77` adds records only. This review independently reran the required
focused files, A0 and binding checks, not the full suite/build/check. It
accepts the explicitly identified full-suite/check record as reported
evidence, not as a second independent execution. Required worker/recovery
tests ran without skips in this review.

## Every changed test and the parity map

All eleven changed test-file diffs over the full requested range were read.
`tests/claims.yml` only adds the eight claims for LTB-0514 through LTB-0521.
No existing claim or fixture was removed or relaxed.

| Test file under tests/testthat | Existing-test change | Decision (5) assessment |
| --- | --- | --- |
| test-api-exports.R | Private export pins now name the handler and two sinks | Enumerated private-export migration |
| test-availability-economics.R | Factory capture/mock and constructor arguments; initial capacity remains 2 | Enumerated migration; growth/allocation oracle unchanged |
| test-corporate-action-recovery.R | Factory capture/mock; transaction/recovery source predicate follows handler plus memory sink | Enumerated owner relocation; fault and predicate unchanged |
| test-execution-spec.R | Six constructor calls; adds LTB-0517 | Enumerated migration plus required negative capability witness |
| test-governance-report.R | Adds LTB-0514 only | Explicit LDG-3126 default-path witness, not an existing-fixture migration |
| test-ledger-writer.R | Constructors and source owners for LTB-0138/0188; adds LTB-0515/0516/0518/0521 | Enumerated migration; all old expectations, fixtures and allocation bounds preserved |
| test-output-handler-sinks.R | New LTB-0519/0520 file | Explicit LDG-3131 witnesses |
| test-release-claim-boundary.R | LTB-0181 NEWS assertion made unconditional | Separate stated reason in LDG-3130 and exact Phase B P1 patch; restores the existing presence pin |
| test-research-cycle-scale.R | Two constructors | Enumerated migration |
| test-risk-fold.R | Constructors and captured/mocked factory names | Enumerated migration; fault methods and conditions unchanged |
| test-sweep.R | Seven constructors | Enumerated migration |

The relocated source assertions still inspect their actual owners. The
structural demonstration independently passes its three controls and rejects
all six predicate-specific violations: environment-held row/leg staging,
missing local row/leg writes, a MAX(diagnostic_seq) query and a memory
transaction call. R3's two blocks independently pass normally and fail with
39/1 expectations under each cash and position perturbation. The actual
LTB-0181 block, with only NEWS reads privately substituted, passes with the
paragraph and fails one expectation without it under the development heading.
No tracked NEWS or test file was mutated by that probe.

The map lists exactly the three files' 26 blocks (6 + 5 + 15), with correct
line locations and distinct claims. Their complete diffs are empty. None was
retired, so there is no replacement-equivalence claim to accept by name.
Promotion/reproduction, non-default metric context, candidate-varying features
and warmup, retention and recovery remain exercised. The finalization failures
at availability-parity lines 276/347 retain their original fault and no-replay
oracles. Event growth remains an in-process witness with unchanged bounds.

LTB-0519 installs its observer after package loading inside ledgr's own mirai
workers, asserts different PIDs, and compares typed event tables/all five
attributes, retained diagnostics/numbering and completion against identical
in-process inputs for both candidates. It checks nonzero fills and nonempty
diagnostics/completion. Its daemon-side event-ID mutation changes native
events while public status, completion_json and final equity remain identical.
LTB-0520 compares persisted and native event semantics, timestamp/sequence
and every fill's deltas for both nonzero-fill candidates. Both passed without
skips. LTB-0521 independently forces equity, diagnostic and strategy-state
growth boundaries; the small A0 fixtures alone would not cover those repairs.

## Seven-shape walk

Names in the first column reproduce the manual's seven named shapes verbatim.
The walk covers both sinks and every nested buffer, staging, diagnostic,
accounting, equity, metadata/materialization helper in `R/output-handler.R`,
plus `ledgr_fill_publication_deltas()` and its payload/live consumers. Existing
event/fill-buffer primitives were also inspected at their call boundaries.

| Shape | Walk and evidence |
| --- | --- |
| **One-row frame per element, bound at the end.** | DuckDB state uses typed columns and manifests at flush (`R/output-handler.R:128`); memory equity uses five typed columns and manifests at summary (`:287`). Diagnostic retention stores emitted blocks, not newly constructed per-row frames (`:365`, `:384`). Pulse rows/legs remain local staged records gathered into indexed block writes (`:248`, `:573`). No new one-row-frame/bind loop. |
| **Full-table subset inside a loop over ids.** | None in the moved owners or publication helpers. Retention applies one vector predicate to the incoming diagnostic block (`:366`). No per-ID full-table scan or repeated resolver was added. |
| **Per-element parsing or formatting where a vectorised call exists.** | No new data-scale timestamp loop. Equity stores epochs until summary; compiled timestamps convert as a vector (`:750`). Existing field-gathering applies extract primitives over staged rows/legs. Scalar fill payload serialization remains the canonical single-fill publication boundary. |
| **Per-row JSON on repetitive strings.** | Inherited debt remains at memory append's per-row parse (`:724`) and event materialization's per-event metadata fallback/serialization (`:818`, `:843`). It is explicitly recorded, not repaired or duplicated in each sink. The typed/compiled paths retain typed deltas; inline summary avoids this event serialization. |
| **Work computed and discarded, or recomputed on every call.** | DuckDB does not populate memory accounting/equity representations; memory discards telemetry/state persistence. One R3 publication computation per fill; supplied compiled deltas are copied. Existing repeated event serialization remains debt when events() is repeatedly requested; this cut makes no claim to remove it. |
| **Quadratic validators.** | None added or moved into the handler/sinks/projection helpers. There is no pairwise event, diagnostic, pulse or fill validator. Scalar capacity/index validation delegates to unchanged buffer primitives. |
| **Scalar writes into an environment-held vector.** | Event/state/equity column writes use setv, with prefix copies only on geometric growth (`:140`, `:304`, `:458`, `:478`). Row/leg staging and diagnostic parts are closure-local lists (`:213`, `:377`, `:563`). Loops over five equity fields or 11/16 event columns have fixed width; scalar counters are not data-scale vectors. |

**Data-scale iteration, explicitly named:** memory `flush_legs()` gathers
each staged leg with `vapply` at line 254; `flush_pulse_events()` gathers
staged rows and typed fields with `lapply`/`vapply` at 584-593; memory
`append_event_rows()` loops over incoming rows at 724; compiled append uses
`Map` over batch events at 769; `materialize_events()` applies `vapply` over
events at 843. The unchanged `ledgr_event_buffer_write_rows()` primitive
gathers staged fields with `vapply` (`R/fold-event-buffer.R:86`). These are
inherited row-gathering/list projection or recorded JSON debt, not new loops
introduced by consolidation. The capacity helper's while loop is logarithmic
growth, not a traversal of events. No new data-scale loop was found.

## Timing audit and whether the inputs were right

The frozen matrix is suitable for this bounded consolidation claim: all eight
A0 timing workloads, plus 50x1260 with substantial fills, on both public paths.
The small fixtures cover semantic fixed costs; 20x252 and 50x1260 avoid
relying solely on fixed overhead. The clock includes complete warm public
calls and committed handle closes, with identical snapshot preparation,
warmup and retained surfaces in both arms. It is not a cold lifecycle,
isolated fold, worker scaling or db_live/compiled performance claim.

Source chronology is correct: the executable protocol is frozen at
`3971cd1f`, before the base record at `0c6ac93a` and first product change at
`7a2bd764`. R/src/DESCRIPTION/NAMESPACE have empty diffs through the freeze;
the four executable timing files have empty diffs from freeze to candidate.
Both metadata records' commit/tree/product identities were independently
matched to Git. Their protocol/fixture/a0_retain digests match the checker.
Both contain 288 rows: eight pairs x 18 cells x two arms, expected statuses
and work counts, exact sequence and adjacent alternating arm order. Each
runner invocation creates a fresh Rscript process with its own arm library;
chronological row timestamps agree. Reused OS PID values across separate
invocations do not imply process reuse. The registered i9-12900K, R 4.6.1,
toolchain/dependencies, High performance plan and affinity 65535 are recorded
and consistent. F1 is the outstanding host-procedure qualification.

The checker rejects empty/missing/duplicate/unexpected rows, invalid times,
failed/skipped/wrong-completion work, wrong pinning, changed protocol,
malformed identities and non-alternating arms. Its independent demonstration
passes the clean control, rejects every named mutation, and verifies CLI exits
0/1/1 for clean/missing/1.031. No timing runner or timing smoke was rerun.

| Record/cell | Independently recomputed result |
| --- | --- |
| base_aa, 18 cells | CHECK PASS; ratios 0.9249943 to 1.0213026 |
| gate_final, 18 cells | CHECK PASS; ratios 0.9178997 to 1.0209283; no numeric exception needed |
| 50x1260 run | Final 1.0107578; A/A 0.9945641 |
| 50x1260 sweep | Final 1.0166439; A/A 1.0066729 |
| H6, 20x252 | Paired base 1.457607, candidate 1.435076 |
| H6, 50x1260 | Paired base 1.278615, candidate 1.271213 |

Every H6 value in the disposition rounds correctly from the gate record.
"Unchanged" is reasonable as "the gap remains, with no material closure,"
not literal equality of ratios. The possible approximately 1% large-workload
cost is cautious and honest; the record cannot prove a causal 1% regression
or an absence of regression outside its matrix. All final cells meet the
numerical 3% bound. The A/A noise and changed absolute medians do not justify
pooling records or choosing favourable repetitions.

A0 is the right independent native-output oracle: it freezes persistence,
db_live, interruption/resume, terminal outcomes, acquisition, failures,
walk-forward, memory and compiled surfaces, with actual corruption controls.
It cannot alone prove architectural ownership, growth or worker-native
equivalence. The source walk, unchanged parity claims and LTB-0515-0521
supply precisely those missing inputs. Keeping the 26 blocks is appropriate;
the A0 fixtures are not matching replacements for their richer public claims.
Large availability/parallel/db_live timings and private real-data workloads
would broaden coverage, but are not necessary for this accepted, explicitly
bounded warm matrix or grounds to redesign WS1. No further material product
surface was found unexamined for this cut. Timing host admissibility remains
the material evidence gap in F1.

## Routed points and Optional wording improvements

| Point | Classification |
| --- | --- |
| WS4 execution-core consolidation / H6 | Outside WS1 implementation. The unchanged fold, planner and mode census support deferral. Remaining cost attribution is not measured here. |
| WS7 INCOMPLETE annualized_return | Explicitly excluded by decision (2). The four A0 agreement differences remain unchanged; 0 versus NA is not silently fixed by consolidation. |
| WS3 peer smoke failure | Reasonably routed as pre-existing, based on Phase B's same-input base-constructor differential and the current constructor-only peer diff. I did not rerun peer smoke or claim an independent full-base reproduction. No benchmark tolerance/oracle was relaxed. |
| R CMD check head NOTE | Outside this change: history-frame source is identical by Git blob identity. Recorded check exit 0 with that NOTE is not a zero-NOTE claim. |
| Packet findings | Inherited debt can remain outside; the blanket 83 classification cannot. See F2. |
| R/accounting-replay.R:95 | Unchanged reader/reconstruction fallback, not resolved-fill row publication. Its separate cash arithmetic is outside accepted R3, not a second handler publication computation. |
| Recorded JSON debt | Inside the inspected moved code, but explicitly deferred repair in the accepted design, Section 12. Correct as retained debt, not as code exempt from this review. |

**Optional:** in `ws1_disposition.md:53-54`, say "45 valid CPU samples at
30-second intervals over about 22 minutes" instead of "a 30 s CPU trace."
The computed mean/max really are 16.12481%/18.72992%. In `:70-72`, replace
the inference that the gap "lies outside" the consolidated code with:
"The measured H6 gap remains. WS1 did not materially close it under the
declared warm-call boundary; this comparison does not locate the remaining
cost." These edits improve precision without changing a gate or result.

## Commands run and exit codes

`P` below is `C:/Users/maxth/ledgr-wt/ws1-output-handler`; `T` is
`C:/Users/maxth/AppData/Local/Temp`. `G` expands to the read-only command:

```powershell
git --git-dir=C:/Users/maxth/Documents/GitHub/ledgr/.git/worktrees/ws1-output-handler --work-tree=C:/Users/maxth/ledgr-wt/ws1-output-handler -C C:/Users/maxth/ledgr-wt/ws1-output-handler
```

Each shell invocation was a single command; no timing runner was invoked.
Independent reads were batched by the tool, not chained in the shell.

| Command/invocation | Exit | Result |
| --- | ---: | --- |
| `Rscript P/dev/bench/v0_2_3_output_freeze/check.R --out=T/ws1_close_a0 --agreement=T/ws1_close_agreement.csv` | 0 | Every record byte-identical, 213 agreement checks, four known differences |
| Original gut.R evaluated by the redirected stdin command below | 0 | Control exit 0; all 17 corruptions exit 1 and name their expected surface |
| Private read-back assertions over T/ws1_close_gut_results.csv | 0 | Exactly 18 rows; all expected statuses and named-surface predicates asserted |
| First focused test_dir stdin command below | 0 | ledger-writer, execution-spec, output-handler-sinks, three parity files and release-claim-boundary; no failures/errors/skips |
| Same command, filter `^(api-exports\|availability-economics\|corporate-action-recovery\|risk-fold\|research-cycle-scale\|sweep\|governance-report\|codebase-contracts)$` | 0 | All remaining migrated files, governance and mode census; no failures/errors/skips |
| `Rscript P/dev/ws1/structural_relocation_demo.R P` | 0 | Three controls and six predicate-appropriate failures |
| `Rscript P/dev/ws1/r3_perturbation_demo.R P` | 0 | Two controls; cash and position mutants fail 39/1 expectations each |
| Private NEWS read-substitution of actual LTB-0181, ListReporter | 0 | Present 0 failures, absent 1, no errors |
| `Rscript P/dev/bench/v0_2_3_ws1_timing/check.R --record=P/dev/bench/v0_2_3_ws1_timing/records/base_aa` | 0 | CHECK PASS |
| Same checker, `--record=P/dev/bench/v0_2_3_ws1_timing/records/gate_final` | 0 | CHECK PASS |
| `Rscript P/dev/bench/v0_2_3_ws1_timing/check_demo.R` | 0 | All controls/mutations detected, including required CLI 0/1/1 |
| Private Git-source store-binding reconstruction, both revisions | 0 | 27 identical bindings |
| Private metadata-versus-Git and raw-sequence/CPU CSV audit | 0 | Identities match, 288 sequential rows each; CPU statistics above |
| Private source-specific production governance scans, current/base/656ee7a5 | 0 | Counts and source classifications in F2; two inherited verdict findings also inspected |
| Private unchanged-source blob checks and peer constructor diff | 0 | Fold, guard, planner, lot, replay and history sources unchanged; peer diff one constructor |
| `G rev-parse HEAD`; `G status --short`; `G log --reverse --format=oneline 07dbbc87..d8906f77` | 0 each | Candidate/range/chronology inspected |
| `G diff --stat 07dbbc87 d8906f77`; `G diff --numstat 07dbbc87 d8906f77 -- tests`; full changed-test diffs | 0 each | All eleven changed test files and additive claims reviewed |
| `G diff --name-only 697f32ee d8906f77` | 0 | Records/tickets/disposition only |
| `G diff --exit-code 07dbbc87 d8906f77 --` three parity files, frozen A0 records/fixtures/checker/gut/agreement, fold/guard/replay/store-gate/lot/history/DESCRIPTION/NAMESPACE/src | 0 | Empty committed diffs for the protected inputs |
| `G diff --exit-code 3971cd1f 697f32ee --` matrix.R/runner.R/measure.R/check.R | 0 | Executable protocol unchanged |
| `G diff --exit-code 07dbbc87 3971cd1f -- R src DESCRIPTION NAMESPACE` | 0 | Freeze precedes product edits |
| `G diff --exit-code HEAD -- . ':!inst/design/ledgr_v0_2_3_spec_packet/ws1_close_review.md'` | 0 | No normalized tracked content change outside this review |
| `G diff --name-only 07dbbc87 d8906f77 -- dev/spikes dev/bench/v0_2_3_output_freeze/records`; A0 agreement/gut-results protected diffs | 0 | Historical/frozen artifacts unchanged |
| `G ls-tree -r --name-only` for reviewed revisions; `G show` base runner; packet README diff | 0 each | Source populations and former implementation inspected |
| `rg -n` constructor/delta/buffer references over R, tests, A0 and peer source | 0 | Only historical/nonexistent missing-observer strings remain for deleted constructors |
| `rg -n` loops, contract anchors, parity blocks, timing metadata, debt routes and scanner definitions | 0 | Ownership, 26 block locations and finding lines inspected |
| `Get-Content -LiteralPath` on AGENTS, tickets, disposition/design/map, five previous reviews, contracts, design index/macro plan/inventory, both manuals, A0 checker/gut/lib/closeout, handler/writer/buffer/replay, changed/new/parity test sources, demos, protocol/runner/matrix/measure/check and both record metadata/host/CPU files | 0 each | Source/evidence reads; focused follow-ups supplied initially truncated portions |
| `Get-Command git -All`; `Get-Content -LiteralPath P/.git` | 0 | Explicit Git-directory workaround discovered |
| `G diff --check -- inst/design/ledgr_v0_2_3_spec_packet/ws1_close_review.md`; final private review UTF-8/header/completeness check and `G status --short` | 0 each | Review complete; only review added, plus the two existing line-ending-only source marks |

Exploratory failures were tooling failures, not green product evidence:
plain `git -C P status --short` and per-command safe.directory variants
exited 1 (ownership refusal); the safe.directory diff variant exited 1
(could not access 07dbbc87). No global Git configuration was changed. Two
initial searches of guessed event-buffer/helper filenames exited 1; the
actual files were then located with rg and read. The first private NEWS
probe exited 1 because ListReporter had no started file; the corrected probe
starts/ends the file and produces the 0/1 result above. R emitted locale
startup warnings throughout. The first successful status already marked
R/cpp11.R and src/cpp11.cpp modified; their normalized content diff is empty.
No product/test patch or commit was made.

The first focused command was:

```powershell
@'
p <- 'C:/Users/maxth/ledgr-wt/ws1-output-handler'
pkgload::load_all(p, quiet=TRUE, compile=FALSE)
testthat::test_dir(file.path(p,'tests/testthat'), filter='^(ledger-writer|execution-spec|output-handler-sinks|sweep-parity|sweep-persistence-parity|availability-parity|release-claim-boundary)$', reporter='summary', stop_on_failure=TRUE, load_package='none')
'@ | Rscript -
```

gut.R has a fixed tracked CSV destination. Its original script was evaluated
with only that destination redirected in memory. The working directory for
this single command was `P/dev/bench/v0_2_3_output_freeze`, so its original
script-location discovery and child calls remained intact:

```powershell
@'
x <- readLines('C:/Users/maxth/ledgr-wt/ws1-output-handler/dev/bench/v0_2_3_output_freeze/gut.R')
i <- grep('a0_write_table', x, fixed=TRUE)
x[i] <- sub('file.path(here, "gut_results.csv")', '"C:/Users/maxth/AppData/Local/Temp/ws1_close_gut_results.csv"', x[i], fixed=TRUE)
stopifnot(length(i) == 1L)
eval(parse(text=x))
'@ | Rscript -
```

The checker output and agreement are in `T/ws1_close_a0` and
`T/ws1_close_agreement.csv`; the gut result is
`T/ws1_close_gut_results.csv`. These temporary outputs are not committed.
Only this review file was intentionally written in the repository.
