Verdict: PASS_AFTER_PATCHES
Role: record; independent clean-context focused re-review of LDG-3157 (correction round 2).
Status: accepted; review recorded 2026-10-29.
Authority: review evidence against the accepted cut; this file grants no new implementation scope.

Reviewed `ws2_rng_design.md` at `d13c6555`, specifically the response diff
`b0659204..d13c6555`, against the previous two reviews and cut 4 decisions
(14), (15), including B-1, and (16) in `tickets.yml:166`. References to
`note:N` below mean that pinned note. The working note matched the pinned
commit. The branch was `claude/ws2-rng`; HEAD during verification was
`7f3eeecb02344c07862eadd07c12e58dc2ab7916`. Product `R/` and `NAMESPACE`
had no diff from `aa2931e9`.

N1's expression/environment transport, N2's classification and numeric ledger,
and N3's typed schema are resolved. O1 and O2 landed. One bounded source-check
wording contradiction remains (P1 below); its exact patch implements the S3
exception the note already states. Apply P1's two text replacements; no further
re-review is needed. No new Type 2 question or third design correction round
is requested. This accepts a design specification after those patches, not
the future LDG-3158/3159 implementation or its release evidence.

## Required finding and exact patches

### P1 - P2: the source check includes a generic that the design expressly leaves unwrapped

**Evidence:** `note:32-36,434-438,611-617,624-636`;
`R/sweep.R:567-569`.

The partition correctly counts `ledgr_candidate` among 15 W exports, and
Section 5.4 correctly leaves its generic as `UseMethod("ledgr_candidate")`,
placing the force/preserve steps in its two operational methods. But the
source check says that all 15 export bodies, plus those methods and the two
returned helpers, must start with force and end with preserve. These cannot
both hold. Classification counts and counts of wrapped bodies are different.

**Failure scenario:** implement the S3 paragraph faithfully. A literal source
checker rejects the generic's dispatch-only body. Wrapping that body to pass
the checker contradicts the stated S3 rule and changes the intended boundary.
A local parsed-body checker accepted the specified capture prologue and
rejected the real dispatch-only generic under the literal all-15 rule.

**Exact required change, patch 1:** replace the first sentence about the
fifteen exports and two methods at `note:32-36`, ending with "after all
cleanup", with:

```text
Fifteen exports are W. Fourteen put `ledgr_rng_preserve_caller()` in their
own outermost frame. The dispatch-only export `ledgr_candidate` carries
the wrapper in its two operational registered methods,
`ledgr_candidate.default` and
`ledgr_candidate.ledgr_walk_forward_results`. Restoration runs after all
cleanup.
```

**Exact required change, patch 2:** replace the complete "Source check
(LDG-3158)" block at `note:624-636` with:

```text
**Source check (LDG-3158).** The test fails if any of these does not hold:

- the wrapper-shape bodies are exactly the 14 W exports other than
  `ledgr_candidate`, the two W methods `ledgr_candidate.default` and
  `ledgr_candidate.ledgr_walk_forward_results`, and the two R helper
  closures `test` and `test_dates` (18 bodies total);
- the generic `ledgr_candidate` is checked separately: its body remains
  `UseMethod("ledgr_candidate")` in the generic's own frame, with neither
  force/preserve steps nor cleanup. It remains W in the 15-export
  partition;
- each wrapper-shape body has `ledgr_rng_force_args()` as its first
  statement and exactly one `ledgr_rng_preserve_caller()` call, as its
  last statement;
- every statement between them is a permitted prologue assignment (above);
- the `lazy` argument matches the frozen set above;
- no `on.exit()` appears in any wrapper-shape body;
- no W or R implementation function recaptures a forwarded formal (the
  no-recapture rule above).
```

The braces around the generic's single dispatch statement are immaterial.
Keep the existing partition and census counts. These replacements reconcile
the source check with the already accepted method placement; they do not
authorize a new execution or isolation policy. P1 is required, not optional
polish. Neither replacement has been applied to the note by this reviewer.

## N1: resolved, with P1 needed for the source-check list

`note:542-575` now captures in the original export frame after the force step:
the ranking expression, original caller environment and missing flag; each
grid's filter expression and missing flag; and PBO's label expression while
forcing the metric value. Implementations consume these values rather than
recapturing forwarded formals. This preserves the actual evaluation owners in
`R/sweep-review.R:30-57,104-121`, `R/param-grid.R:31-53,178-215`, and
`R/validation-pbo.R:39-44,218-230`.

Executed R 4.6.1 probes copied the real product bodies in memory and changed
only the capture/transport points and entry envelope. Results were identical
to the unsplit originals for:

- `desc(sharpe_ratio)` ranking, including the returned ranking label/tables;
- a caller-local `score <- function(x) -x` used in the ranking expression;
- both grid filters (`n > 1`, `qty > 1`) and both omitted-filter calls;
- a named PBO callback `fun <- function(m) colMeans(m)`, with identical full
  output and metadata label `fun`.

The permitted prologue at `note:590-599` is implementable as an AST allowlist:
simple symbol assignments whose RHS is one of the four specified calls, with
the formal names and lazy sets checked. A local checker passed a compliant
ranking wrapper. It rejected removal of force, a drawing prologue assignment,
`on.exit`, a second preserve call, a statement after preserve, and a wrong
lazy set. A separate traversal rejected recapture of a forwarded formal.
P1 fixes the only demonstrated contradiction in the list of checked bodies.

For missing ranking, invalid `n`, and failed ranking evaluation, the split
real-body model retained identical condition classes and `conditionMessage()`
text, including the parent error. Models moving the literal walk-forward and
candidate reserved-dots aborts into implementations likewise matched the real
product's classes/messages. The missing flag is transported rather than
re-tested on an explicitly forwarded formal. Ordinary argument forcing errors
remain subject to decision (15)'s intentional earlier evaluation.

`test_dates()`'s hold and release moving inside preserve is correct
(`note:601-609`; `R/indicator-dev.R:100-101`). Using its real body and a real
temporary snapshot, I instrumented the actual release closure to draw after
releasing. Two calls observed `release, restore, release, restore`; the final
caller stream matched the two argument `sample(dates, 3)` draws alone. This
also rechecks B-1: the two selected date sets matched two successive samples,
while callback and cleanup draws were restored.

## N2: resolved

`ledgr_candidate.default` is W in Sections 1, 5.2, 5.4, Appendix A and the
round-2 summary. The round-1 response row explicitly labels its former count
as historical and records the correction. P1 concerns body enumeration, not
the classification or numeric ledger.

I independently expanded the Appendix A lists and compared them with
`NAMESPACE`, including the grouped S3 method lists:

| Surface | W | H | N | Completeness |
| --- | ---: | ---: | ---: | --- |
| Exports | 15 | 55 | 111 | 181, no overlap or omission |
| Registered S3 methods | 2 | 41 | 50 | 93, no overlap or omission |

The two W methods are exactly the default and walk-forward candidate methods.
The filter-result method remains N. R remains the two development helpers.

The ledger's inputs are the registered case expressions, not just calls made
after the outer save (`probe.R:216-232`). I reran those expressions with
in-memory models of the store guard, entry wrappers, pinned envelope state
helpers and the NA-to-NULL repair. No candidate argument was precomputed.
The registered default S3 method was replaced in the S3 dispatch table as well
as the namespace, so this probe actually exercised its wrapper.

Observed counts, independently instrumented at preserve, capture, restore
and seeding, and cross-checked with the original probe's RNGkind trace:

| Original row | E / preserve | S | Query | Mutation | RNGkind total | Decision reads |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 01 | 1 | 0 | 1 | 1 | 2 | 10 |
| 02 | 1 | 0 | 1 | 1 | 2 | 20 |
| 04 | 3 | 0 | 3 | 3 | 6 | 10 |
| 05 | 1 | 0 | 1 | 1 | 2 | 19 |
| 06 | 1 | 1 | 2 | 2 | 4 | 10 |
| 07 | 1 | 2 | 3 | 3 | 6 | 20 |
| 09 | 3 | 1 | 4 | 4 | 8 | 10 |
| 10 | 1 | 6 | 7 | 7 | 14 | 19 |

Both promotion traces entered, in order, `ledgr_candidate.default`,
`ledgr_promote`, `ledgr_run`. Thus E includes the argument evaluation exactly
as now defined at `note:1017-1049`. Rows 04 and 09, and the after-LDG-3158-only
totals `2,2,6,2,4,6,8,14` at `note:1075-1086`, are correct.

The absent-state statement is now explicitly successor-only
(`note:944-960`). I observed all eight base case starts present and all eight
successor-model starts absent, with no reset between cases. The fixture's
appends no longer create the seed under the store guard; envelope and entry
restores preserve absence. All successor cases completed successfully. In
particular row 05 has zero seeds and 19 decision reads, retaining its positive
predicates. This verifies the LDG-3158 precondition, without claiming the future
LDG-3159 vector observer already exists in today's product.

## N3: resolved

`note:963-996` declares the seven appended columns, copy-row logical `NA`,
four `NA_integer_` cells and two character empty strings, with exact types
and header frozen by the comparator. Operational rows require `FALSE` and
nonmissing exact counts; the original 13 fields remain frozen.

I constructed the typed successor columns over the unchanged original
13-column record and passed them through the actual `a0_canon()` and
`a0_csv_text()` in `dev/bench/v0_2_3_output_freeze/lib.R:150-179`. The new
header matched the note's frozen string byte for byte. Both copy rows ended
in `NA,NA,NA,"",NA,"",NA`, with the declared logical/integer/character types;
the original 13 columns were unchanged. A literal empty string is no longer
specified for a logical or integer observer cell. See Optional below for
one harmless overstatement about the existing copy-row values.

## O1 and O2: landed and verified

O1's guard overclaim is removed (`note:513-525`). Inspection, rather than
the seeding ownership guard, supports the statement about today's defaults.
Direct calls of the four named default constructors again left `.Random.seed`
unchanged.

O2 now freezes mutation of the results attribute before extraction, for
seeded/unseeded and old/missing cases (`note:847-863`), and R10 names that
fixture (`note:1109`). I produced real seeded and unseeded walk-forward
results using the specified NA repair. An extraction/validation model copied
the attribute into the real extracted candidate; all four corrupted cases
were refused before a traced snapshot hold. Replacing copying with the R10
constant-derived marker made all four candidates pass the model validator and
actually promote through today's product. Hence the refusal and copied-marker
assertions detect R10. This is a model of the proposed new marker logic, not
a claim to have executed a successor gut that has not yet been implemented.

## Regression spot-checks and independent input assessment

- **Arithmetic, goldens and controls:** Section 2 is unchanged by round 2.
  Exact Python integers reproduced all 63 goldens; R's split arithmetic also
  matched all 63 and the original mixer matrix digest. Recomputed v2 maxima
  were B1 `0.025739358`, B2 `0.017400005`, B3 `0.016927657`; B4 was
  `10000/0`, B5 `0`, B6 `1000`. All bounds pass. Add, stride and seed-ignoring
  each fail; the bounded two-direction add B5 count is `9481`.
- **A0:** Section 8.1 is unchanged. I executed the independent v2 substitution
  on the real `dense_risk_features` sequential run and sweep paths. Only tight
  rows changed, with exactly the stated counts: ledger 5, fills 5, equity 6,
  trades 2, metrics 7, memory events 6, memory fills 5, memory equity 6, sweep
  1, sweep returns 6, sweep trades 2. Loose rows stayed identical. The model
  changed no configuration/identity field. Workers were not run in this review.
- **Storage model:** rerunning both real `rp_store_rng()` cases with every
  production append guarded, and no pulse-rule change, gave identical paths,
  no first differing pulse, and exact equities `99984.34987600008` and
  `99967.891749199887`. These remain attributable to RNG-neutral storage.
- **Identity and F2:** Section 7 is unchanged. The new constant still matches
  the actual store-binding discovery regex (`R/store-gate.R:3-12`). Seeded
  config changes, unchanged unseeded config, unchanged snapshot content identity,
  unchanged candidate/window seed derivation, and same-calendar qualification
  remain distinct. Results-marker copying and refusal before hold are retained,
  now with the stronger O2 fixture. No compatibility path was added.
- **F4:** Sections 3-4 are unchanged. Parsed-source inventory again found 27
  appends, three seeding calls, two daemon calls and zero existing RNGkind calls.
  A local ownership-check model passed clean proposed-owner examples, including
  the worker's quoted mutation, and rejected each specified injection: direct
  append, mutation inside the query owner, unowned query, unowned mutation.
  The wrapper-shape check is separately subject to P1.
- **Decisions (14)-(16):** the boundary paragraph, decision-(16) witnesses and
  seed/store ownership sections are unchanged. The service evaluators still
  receive restoration; supplied ordinary arguments run first; post-entry user
  S3 evaluation stays inside; only the two user-facing development helpers
  restore on their own calls. Signal and adapter machinery do not gain a
  separate restore. The real-helper probe above reconfirms B-1. R3's drawing
  witness and rows 13/15 requirement, and R9's seeding-caller predicate, remain
  intact.

The inputs are appropriate independently of the response table: the public
capture sites and S3 generic were read in product source, the complete partition
was checked against NAMESPACE, census arithmetic was checked against the actual
registered expressions and real fixture execution, and schema representation
was checked through the canonical writer. The numerical reference and causal
models are distinct from the future implementation. No timing runner, worker
session, full test suite, package check or Linux execution was run: these remain
implementation/release obligations, not missing evidence for this focused
design re-review. The excluded timing and ldg3155 review files were not edited.

## Optional

- **Error-call presentation:** moving aborts changes `conditionCall()` and
  backtrace frames to the implementation. Classes and `conditionMessage()`
  matched in the probes; full rendered call prefixes are not byte-identical.
  Preserving public-call attribution is optional polish, not another evaluation
  or error-message defect against the current design contract.
- **Copy-row prose:** `note:984-985` says the original 13 columns are "all
  character and blank in those rows as today". They are all character, but
  `path`, `seed_arg`, `set_seed_seeds`, `default_seed` and `case` retain values.
  Optional replacement: "The original 13 columns retain exactly today's
  character types and copy-row values." The explicit unchanged-field predicates
  already freeze those cells, so this wording does not reopen N3.

## Commands and exit codes

Shell commands used absolute paths. Git used the supplied fallback after the
ownership refusal; no safe-directory configuration was changed. R probes used
PowerShell here-strings piped to `Rscript -`; Python used the same form with
`python -I -`. Probe source was supplied on stdin, with no scratch script added
to the repository. R loads used
`pkgload::load_all('C:/Users/maxth/ledgr-wt/ws2-rng', quiet=TRUE, compile=FALSE)`.
Baseline probe definitions were parsed without executing their load/main or
importing a timing runner. Stores were temporary.

For the Git rows below, `G` denotes the literal command prefix
`git --git-dir=C:/Users/maxth/Documents/GitHub/ledgr/.git/worktrees/ws2-rng --work-tree=C:/Users/maxth/ledgr-wt/ws2-rng`.

| Command / stdin probe | Exit | Result |
| --- | ---: | --- |
| `git -C C:/Users/maxth/ledgr-wt/ws2-rng status --short` | 1 | Ownership refusal; used supplied fallback. |
| `G status --short`; `G rev-parse --abbrev-ref HEAD`; `G rev-parse HEAD` | 0 each | Branch/HEAD recorded; concurrent timing artifacts left untouched. |
| `G diff b0659204..d13c6555 -- inst/design/ledgr_v0_2_3_spec_packet/ws2_rng_design.md` and `--stat` form | 0 each | Complete round-2 response reviewed. |
| `G diff --exit-code aa2931e9 -- R NAMESPACE` | 0 | Product input matches cited base. |
| `Get-Content -LiteralPath <absolute input>` and `rg -n <pattern> <absolute inputs>` | 0 each | Note, prior reviews, decisions, design/process index, contracts and relevant product/probe/writer source inspected. |
| `python -I -`: NAMESPACE partition, pinned note, unchanged sections, integer goldens, B5 and hashes | 0 | Complete/disjoint counts; 63 goldens; add B5 9481; input identities. |
| `Rscript -`: real-body capture transport and error probes | 0 after 1 | First scratch attempt misused positional `exists()` arguments; corrected. All comparison predicates then passed. |
| `Rscript -`: base/successor census model | 0 after three 1s | Scratch corrections: initialize `rp_here`; preserve NULL AST children; update the registered S3 dispatch entry as well as its namespace binding. Base starts present; final successor starts absent and all ledger counts pass. |
| `Rscript -`: typed census/writer and wrapper-shape checker | 0 after 1 | Scratch reader initially kept typed-header suffixes as data names; stripped those suffixes. Exact typed header/cells pass; P1 reproduced; invalid shapes rejected. |
| `Rscript -`: real `test_dates()` body and instrumented release | 0 | Release before restore; successive supplied samples and caller state pass. |
| `Rscript -`: O2 real-results extraction/validation model and R10 reversal | 0 | Four early refusals; four actual promotions under reversal. |
| `Rscript -`: B1-B6, controls, split-R goldens and mixer digest | 0 after 1 | Scratch table selector initially included later census rows; restricted to Section 2.5. All final assertions pass. |
| `Rscript -`: A0 sequential v2 model | 0 | Exact A4 table/row counts and unchanged loose rows. |
| `Rscript -`: real `rp_store_rng()` with guarded append model | 0 | Both exact equity predicates pass. |
| `Rscript -`: parsed-source inventory and F4 ownership injections | 0 | 27 appends/3 seeds/2 daemon calls; clean owner fixture passes, four injections fail. |
| `python -I -`: unchanged boundary, decision-(16) witnesses, Sections 3-4 | 0 | No round-2 regression in those sections. |
| `python -I -`: final review header/encoding and scoped input hashes; `G status --short`; `G diff --check` | 0 each | Required header and UTF-8/ASCII pass; inputs unchanged; only the review was added by this reviewer; no tracked whitespace errors. |

Scratch failures above are probe-construction failures, corrected without any
product, fixture or oracle edit. R 4.6.1 emitted startup locale warnings. Git
emitted warnings about reading the user's ignore file. Neither affected the
successful assertions.

Input SHA-256 values:

- Note at `d13c6555` (working-file bytes):
  `bfa48a0f2f8174ec4e0e16339faf56d0b1e3b1acc6485a644f322d836510b1fa`.
- Baseline `probe.R`:
  `43b565b0f5c0fcbba07b096bb9dd4c7f8fa7e0a7cecb5039c2e460ae5669e827`.
- Baseline `records/census.csv`:
  `0213a6b83c9e9c15cce6fd11038c3cc4e2cd5624cda062d41742a737dcd0dad1`.

This review file is the reviewer's only repository write. The note and ticket
authority were not edited, and no commit was made.
