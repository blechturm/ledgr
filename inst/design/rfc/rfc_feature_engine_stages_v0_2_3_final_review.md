# Feature Engine Stages 2-3: Final Review

PASS_WITH_PATCHES

The synthesis says what the cycle decided. All eight response findings are
carried into rules, and its load-bearing code claims hold, including the new
renamed-SMA3 counterexample, which I reran. Six findings remain. Three replace
an abstract or report-only rule with a concrete default: the lazy-construction
domain, the stage-3 retention test, and the Q3 fallback. Two close gaps in the
witness and reach lists, and one fixes citation slips. None reopens design.

- Mode: Type 1, final review (verification, not design). Claude subagent with
  clean context, 2026-11-25. Reviewed head `db3d0502` (worktree
  `C:/Users/maxth/ledgr-wt/fe-stages-final-review`, clean, R/ identical to
  `68b505b9`).
- Evidence used: the synthesis, seed v1, response, response review, seed v2,
  and the parent seed v2 (Stage 2, Stage 3, Sections 4, 6 and 7), read in full.
  I read the cited code in `R/` and `dev/feature_parity/`, the probe results in
  `dev/spikes/feature_stage23_probe/results/`, the saved outputs in
  `C:/Users/maxth/ledgr-wt/fe-stages-probes/` and
  `C:/Users/maxth/ledgr-wt/fe-stages-synthesis-out/` (the `.out` file is
  UTF-16), `AGENTS.md`, `inst/design/rfc_cycle.md:238-257` and
  `inst/design/manual/optimization_coding_style.qmd:343-360`.
- Probes I ran (installed build `final-68b505b9`, engine `bc6a3ea254d0a37b`):
  `C:/Users/maxth/ledgr-wt/fe-stages-final-review-out/final_review_probe.R`
  and `.out`, and `source_match_probe.R` and `.out`. The second confirms that
  all 215 top-level functions in the eleven files match this worktree. No
  timing run, full suite, package check or private-data access.

## Findings

### 1. Rule 4 leaves the lazy-construction domain abstract; the exact domain is small and known

- Claim (synthesis:110-123): retain eager construction "outside the proven
  equivalent domain, including extra ID-width cases". The cut has to discover
  what that domain is.
- Evidence: built-in constructors refuse only for an invalid `n` or for the
  `n + 1` overflow at `.Machine$integer.max` (`R/indicator-builtins.R:18,75,123,168`).
  Params widths are validated to 1..max (`R/history-features.R:100-103`). An
  ID width can be 0 or max (`:104-107`). TTR candidates come last and their
  errors are caught (`:123-152`). So lazy and eager construction differ only
  when a candidate after the match would refuse. That requires a discovered
  width of 0 or max. With one discovered width, the only difference is the
  approved max-width SMA. Probe lines (a1)-(a10) show: `ledgr_ind_sma(max)`
  builds, `ledgr_ind_ema(max)` refuses, eager certification of
  `ledgr_ind_sma(max)` refuses, and lazy certification gives built-in. SMA3
  renamed to `sma_2147483647` refuses eagerly but certifies lazily, which
  confirms the synthesis counterexample. SMA3 renamed to `sma_0` does the
  same: eager refusal `n must be an integer >= 1`, lazy certification. This
  second extra-ID-width case is not in the synthesis.
- Consequence: as written, rule 4 delegates a decision the review can settle
  now (rfc_cycle.md:257, procedural-only routing).
- Patch: in rule 4, replace "Retain eager construction outside the proven
  equivalent domain, including extra ID-width cases described below." with:
  "Construct eagerly exactly when certification discovers two widths (params
  and ID) and either is 0 or `.Machine$integer.max`. In every other case lazy
  in-order construction matches eager except for the approved single-width
  maximum SMA." In rule 12, replace "and the extra-ID-width counterexample"
  with "and the extra-ID-width counterexamples (SMA3 renamed `sma_2147483647`
  and `sma_0`)".

### 2. Rule 9 gates only zero-admission time; low/mixed admission and peak heap are report-only

- Claim (synthesis:201-215): the only hard condition is "zero-admission
  feature time must remain within the stage-2 label-exchange range".
  Low/mixed costs and peak R heap are "reported", and "no retained shortcut
  without resolved net benefit and an explicit size disposition" defines no
  net-benefit test.
- Evidence: response finding 5 names the risk directly ("rejected-cell cost
  needs an owner"; transient planes "can also increase peak memory",
  response:43-49). Seed v2:256-263 also gated only zero admission.
- Consequence: a shortcut that slows the mixed-admission PIT panel or raises
  wide-cell peak heap has no stated disposition, so the decision falls back to
  the close review (rfc_cycle.md:257).
- Patch: after "Report low/mixed costs and memory, not just successful-cell
  savings." insert: "Retain the shortcut only if at least one wide fully
  admitted cell shows a feature-time saving outside the label-exchange range,
  no measured cell (zero, low or mixed admission, 10 x 7,200) is slower than
  stage 2 beyond that range, and wide-cell peak R heap does not exceed stage
  2's beyond the recorded memory noise. Otherwise simplify or drop the gate,
  or bring a named exception to the maintainer at close review."

### 3. Rule 1 turns the conditional Q3 decision into a mandate with no fallback

- Claim: the header (synthesis:22-24) records Q3 correctly: the `ledgr`
  adapter is added "only if it removes the parallel built-in branch". Rule 1
  (synthesis:64-67) says the descriptions are "`ledgr`, then `TTR`" and that
  the built-in entry "must not wrap and retain a parallel branch". It does not
  say what happens if the branch cannot be removed.
- Evidence: seed v2:330-332 and the response's answer 4 (response:80) say
  "accept it only if it removes parallel bookkeeping". Today's built-in
  branches are the constructor list (`R/history-features.R:108-121`) and the
  `kind == "sma"` dispatch (`:303-306`).
- Consequence: the cut could read rule 1 as "always add `ledgr`". The decision
  was conditional.
- Patch: append to rule 1: "If the `ledgr` entry cannot replace the built-in
  candidate list and segment dispatch without keeping a parallel branch, the
  registry holds `TTR` only and the built-in code stays as it is. The stage-2
  close review records which case held."

### 4. Stage 2 should leave every counted mechanism observation unchanged; rule 11 does not say so

- Claim (synthesis:233-235): "Existing route and preparation hand-off counts
  assert work these stages may remove."
- Evidence: the runner counts `ledgr_strict_sma_series`, `ledgr_ttr_raw_call`,
  `ledgr_ttr_call` and the two callback entries by replacing namespace
  bindings (`dev/feature_parity/runner.R:74-80,133,185-200`). Probe (b1) and
  (b2): built-in constructors and built-in certification hit none of them.
  Probe (b3): TTR certification hits `ledgr_ttr_call` and
  `ledgr_ttr_raw_call` through its synthetic validation, which rule 3 keeps.
  Lazy construction affects only built-in candidates. Hand-offs come from
  ranges and inputs, which stage 2 does not touch (`runner.R:148-167`).
- Consequence: stage 2 can be held to the stronger gate of an unchanged
  checker. A change at the stage-2 close would then signal a defect, not
  intended removal. One practical condition follows: the counted seams must
  stay reachable by namespace lookup. If an adapter captures them as function
  objects at package load, the counts drop to zero silently.
- Patch: in rule 11, after the first sentence insert: "Stage 2 removes no
  counted work. Its close runs the permanent checker with every existing
  expectation unchanged, and the counted seams keep their names and are
  reached by namespace lookup. Only stage 3 replaces mechanism expectations as
  below."

### 5. Reach and witness lists omit pulse inspection and the empty-bounds witness

- Claim (synthesis:129-130): "Run, sweep and explicit precompute reach it."
  Rule 12 (synthesis:264-265) covers "run, implicit sweep, explicit
  precompute/reuse".
- Evidence: experiment-derived pulse inspection also reaches the preparer
  (`R/pulse-snapshot.R:395` through `R/history-substrate.R:381`). The runner's
  e2e family already includes pulse inspection
  (`dev/feature_parity/README.md:44-49`). The empty-bounds and no-definitions
  early return comes before any gate (`R/history-features.R:484-489`). It is
  required as a witness by response:33 and seed v2:297-299, but rule 12 lists
  only "empty/short/never-ready histories", which are a different case.
- Consequence: one production caller of the shortcut and one response-required
  witness are not named.
- Patch: in rule 5, replace "Run, sweep and explicit precompute reach it" with
  "Run, sweep, explicit precompute and experiment-derived pulse inspection
  reach it". In rule 12, replace "Cover run, implicit sweep, explicit
  precompute/reuse" with "Cover run, implicit sweep, explicit
  precompute/reuse, pulse inspection". After "empty/short/never-ready
  histories" add ", empty bounds and zero definitions returning before any
  gate is constructed".

### 6. Citation slips (nit)

- synthesis:135 cites `R/history-features.R:471`, which is the substrate
  guard. Certification is at `:475`, bounds at `:482` and the early return at
  `:484-489`. Patch: `R/history-features.R:475-489`.
- synthesis:36 cites `results/direct.csv:2` for 13,408 cells, which sum over
  rows 2-7. Patch: `direct.csv:2-7`.
- synthesis:42 cites `results/gate_count_differing.csv:2` for four cells,
  which are rows 2-5. Patch: `gate_count_differing.csv:2-5`.
- synthesis:14-18 marks the commit attributions unverified. Git works in this
  worktree, so I checked them. `b3454fc7` is seed v1, `ff8e9a63` is the
  response, `a04ab730` is the review plus seed v2, `c01e7445` is the parent
  confirmation, `d5b3a151` is the Cut 11 close, and R/ is unchanged from
  `68b505b9` to `db3d0502` (`git diff --stat` empty). Patch: replace "are
  independently **unverified** ... attempts." with "were verified by the
  final review with `git log`; R/ is unchanged from `68b505b9` to `db3d0502`."

## Verified and correct

- Maintainer decisions. Q1 matches synthesis:19-21 and rule 8, with one
  unexported flag. "Defaults off" and "no lean-only removal in current R/" are
  scope limits implied by the decision, not additions. Q2 matches
  synthesis:21-22, rules 9 and 12. Q4 matches rule 4: conditional on
  measurement, one oracle exception, otherwise lapse. Q3 is covered in finding
  3. The real-data deferral holds (synthesis:26-27,375-379).
- Every correction to seed v2 is named with its reason (synthesis:323-348),
  and the cited v2 lines are right: 121, 147, 223, 234, 283, 293, 337. Each of
  response findings 1-8 maps to a rule: F1 to rules 3, 4 and 12; F2 to rules 3
  and 12; F3 to rules 7, 8 and 12; F4 to rule 5, rule 9 and the contract
  replacement; F5 to rules 6 and 9; F6 to rules 11 and 13; F7 to the evidence
  boundary and rule 12; F8 to rule 6.
- Rule 3: width discovery from params then ID, the order sma, ema, rsi,
  returns per width, then TTR, and ID substitution all hold
  (`R/history-features.R:96-153,30-33`). Recognition needs the claimed
  identity; content identity only feeds the contradiction check (`:41-59`).
  The SMA carrying RSI's claim still raises the contradiction
  (`stages_response_probe.txt:9-11`).
- Rule 7 raw-call key: canonical params without `output`, then required
  fields, carry family and history class (`:63-80`), then segment endpoints
  (`:308`). Cache lifetime is one instrument and range (`:503`). Probe (c1)
  and (c2) give BBands two keys (`mavg` eligible, the others excluded) and
  MACD one key.
- Rule 6 sticky implication: sticky is `first asserted column <= column` over
  the prefix (`R/history-substrate.R:1437-1459`), so no assertion in the
  prefix means no sticky barrier and no terminal breaks (`R/history-features.R:239-243`).
  Expected and finite coverage gives treated equal to raw
  (`R/history-treatment.R:32-61`), one run, and empty input, reason and
  output-carry records (`R/history-features.R:561-605`). Output carry is a
  value no-op, because series outputs refuse non-finite ready values
  (`R/features-engine.R:245-253`). The unnormalised strict SMA is finite on
  finite inputs (`:273-287`). Debug value comparison would catch a platform
  exception.
- Rule 2 and rule 13 citations hold for indicator-ttr.R lines 250, 288, 317,
  718, 806, 855-865 (MFI/CMF volume), 868, 888 and 969/995 (MACD histogram).
  The catalogue has 48 rows and no `ohlc` row (probe d1, `R/indicator-history.R:203-272`);
  `corpus.R:196` uses `ohlc` through custom fallback.
- Evidence numbers: 13,408 cells with 0 differing; 49-59 percent wide-cell
  shares; 197/200 and 4/6; four relaxed cells; 192 whole-slice matches; 10
  corpus gut differences; 215 functions; the runSD(1) refusals on both paths.
  All match their sources.
- Contract replacement (synthesis:276-293): it replaces only
  `contracts.md:2752` and is consistent with the rest of the group, which
  already says the segmented engine serves both clocks (`:2750-2751`) and the
  causality probe covers built-ins (`:2731-2746`). It names the general R
  calculator as the normative oracle and fails closed on disagreement, as
  AGENTS.md requires. It adds no user mode and no clock fork. The engine
  identity refusal it names already ships (`R/precompute-features.R:209-216`)
  but was not in contracts.md before.
- Scope (synthesis:381-393): no public API, compiled code, matrix path,
  catalogue rows, relaxed gate or caller-narrowing is authorized.

## Unverified

- Implementation parity, speed and memory, which belong to the cut.
- The historical CHECK PASS and the full 14-cell gut total, which were not
  rerun. The synthesis already marks both.
- Whether the timing harness can measure peak R heap as a resolved
  comparison. Finding 2's patch assumes the cut records a memory noise figure.
