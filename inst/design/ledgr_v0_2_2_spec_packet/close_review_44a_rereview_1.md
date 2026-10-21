# WS44 phase A focused re-review 1 (Type 1), `c1dca21c..757a037f`

## Verdict: CHANGES_REQUIRED

Correction 1 closes F3, F4, F5 and F6 as claimed, and the notes it acted
on (N1-N4) are done. Every route the first review named in F1 is now
refused, and the F2 dot-name cases are back at their BASE tier. Two problems
remain, both against LDG-3072:

- R1 (blocking): F1 is not closed. Seven literal strategy bodies are still
  Tier 1, and each reads the whole eight-session substrate or feature
  projection at the first pulse. Their routes are rebinding a function's
  body (`body<-`) and evaluating quoted code in the context (`substitute()`,
  `bquote(where =)`, `do.call(with, ...)`, `do.call(evalq, ...)`). The
  contract's limits list does not cover any of them. LDG-3072 is `complete`
  while acceptance item 2 is unmet.
- R2 (medium): the F2 defect class recurs for the name `environment`. The
  new rule refuses any member extraction or string constant that equals an
  environment-reaching function name. So a strategy reading
  `params$environment`, an ESG score list's `$environment`, or a column
  `d[["environment"]]` moves from Tier 1 at BASE to Tier 3.

One low item: four mutations of the new rule survive their block (R3).

What holds:

- F1 routes from the first review: the 61-body probe gives the tiers the
  closeout states. `ledgr:::`, `getFromNamespace`, `asNamespace`,
  `getNamespace`, `getAnywhere`, `get0`, `mget`, string-named
  `environment`, `match.fun` and `baseenv()$environment` are Tier 3. LTB-0371
  runs every refused body through `ledgr_run()`. The refusal comes before any
  strategy call and leaves no store row.
- F2 cases: `$.fitted`, `$.pred`, `[[".pred"]]`, `lm()$.fitted` and the
  strings `".notes"` and `".positions"` are back at their BASE tier. So are
  tidymodels `.pred`, broom `.fitted`/`.resid`, purrr `.x`/`.y`, dplyr
  `.data`, the magrittr `.` and the base pipe (table below). Across all 632
  `function(ctx, ...)` literals in BASE's tests, vignettes, roxygen examples
  and README, BASE and candidate preflight give the same tier for every one
  except LTB-0055's strategy. That is the single change the closeout names.
- LTB-0055 test change: valid (see the item table).
- The full suite, census `--mode=check`, `--self-test-mode-branches` and the
  fold-phase checker pass. All of Q1-Q6 and X5-X9 are detected.

Method:

- Read AGENTS.md, `close_review_44a.md`, the Correction 1 section of
  `history_proof_phase_a_closeout.md`, LDG-3068/3071/3072 with their
  evidence and status, the Strategy Preflight text in `contracts.md`
  (1642-1678) and the units text (777-791), and the whole of
  `git diff c1dca21c..757a037f`.
- Source copies (scratchpad `ws44a_rereview/`):
  - the candidate (`git ls-files`; the working tree equals `757a037f` apart
    from CRLF churn in `R/cpp11.R` and `src/cpp11.cpp`);
  - a mutation copy;
  - BASE `6f019c6b` (`git archive`).
  Each was compiled once. Every R process ran sequentially.
- Probes:
  - `probe_bypass.R`: 45 bodies, classified on both copies. Each
    non-Tier-3 reader also runs in `ledgr_run()` on the WS42 fixture and
    records what it reached at the first pulse.
  - `probe_names.R`: ordinary names that the new list blocks.
  - `probe_scan.R`: every `function(ctx, ...)` literal in tests,
    vignettes, roxygen examples and README. Three arms: BASE sources under
    BASE preflight, BASE sources under the candidate, candidate sources under
    the candidate.
  - `probe_scale.R`: preflight time against strategy size.
  - The first reviewer's `probe_preflight.R`, re-run on the candidate.
- 22 mutations, each restored byte for byte. The mutation copy was diffed
  against the candidate afterwards; the only difference is a testthat
  `_snaps` directory.

## Findings

### R1 (blocking, LDG-3072 acceptance 1 and 2): Tier 1 bodies still read beyond the pulse

Verified, candidate copy (`probe_bypass.R`, WS42 fixture, first pulse
2021-01-04). Every body is Tier 1 on both BASE and the candidate.
"Reached" is what the strategy held at the first pulse.

| Body (strategy fragment) | Reached at the first pulse |
| --- | --- |
| `f <- ledgr::ledgr_history_frame; body(f) <- quote(ledgr_history_context_view(ctx)); v <- f(ctx)` | the substrate, 8 sessions; AAA's session-8 close 18 |
| `f <- ctx$feature; body(f) <- quote(feature_vector); fv <- f(); body(fv) <- quote(feature_values); v <- fv()` | the feature projection, 8 sessions; AAA's session-8 SMA 17.5 |
| `m <- utils::getS3method("print", "ledgr_history"); body(m) <- quote(ledgr_history_context_view); v <- m()(ctx)` | the substrate, 8 sessions, 18 |
| `g <- unserialize(serialize(ctx$feature, NULL)); body(g) <- ...` (as the closure row) | the feature projection, 17.5 |
| `v <- substitute(.history, ctx)` | the substrate, 8 sessions, 18 |
| `v <- bquote(.(.history), where = ctx)` | the same |
| `v <- do.call(with, list(ctx, quote(.history)))` | the same |
| `v <- do.call(evalq, list(quote(.history), ctx))` | the same |

The causes are in `ledgr_strategy_private_context_access()`
(`R/strategy-preflight.R:435-492`):

- The rule scans member-extraction names, string constants and symbols that
  `codetools::findGlobals()` reports. A symbol inside `quote()`, or inside
  the first argument of `substitute()` or `bquote()`, is none of these. So
  `.history` and `ledgr_history_context_view` written there go unseen.
- `body<-` (and `formals<-`, `as.function()` and their rlang equivalents)
  keeps a function's enclosure. Rebinding the body of any closure the
  strategy can reach evaluates arbitrary code in that enclosure, with no
  environment function named. The reachable closures include a public
  context function, an exported ledgr function and an S3 method that
  `getS3method()` returns.

None of these routes is in the stated limits at `contracts.md:1671-1678`
and `R/strategy-preflight.R:44-46`: names built at run time, positional
extraction, iteration, a non-carrier name in a variable, other packages,
objects from outside the body. Each fragment is literal base R. So item 2
("every such path is refused by the same rule or documented as
unreachable") is unmet. So is item 1 for the carrier, which these bodies
reach directly. `tickets.yml` records LDG-3072 as `complete`.

Not findings:

- `Filter()`/`Find()` over `as.list(ctx, all.names = TRUE)` also reach the
  carrier at Tier 1. That is iteration over the context, a stated limit.
- `baseenv()$eval(quote(.history), ctx)` passes preflight but is refused
  later, at config fingerprinting (`ledgr_config_non_deterministic`).
- `rlang::eval_tidy()`/`eval_bare()` with a quoted carrier are Tier 2. Their
  run crashed the R process (eval_tidy) or raised a strategy error
  (eval_bare). I did not chase this further.

Smallest fix within the accepted direction (two parts):

- Refuse the concrete classes:
  - a symbol naming a future carrier or a non-exported ledgr object
    anywhere in the AST, including inside `quote()`, `substitute()` and
    `bquote()`;
  - `body<-`, `formals<-`, `as.function()`, `unserialize()` and their
    rlang equivalents;
  - `substitute()`/`bquote()` given an environment or list argument.
- State the general residual class in the contract and the help: code
  evaluated in the context or in a function's enclosure. Then add the eight
  bodies to LTB-0371 and set LDG-3072 back to `open` until it passes.

A design note for the maintainer, not a verdict change: this is the second
round in which a name denylist misses literal routes. The open question is
whether item 1 can be met statically at all, or whether the carriers should
hold only cutoff-bound data. That question belongs to a Type 2 review if the
next correction is again a list extension.

### R2 (medium, LDG-3072 acceptance 3): ordinary `environment` names change tier

Verified (`probe_names.R`, BASE against the candidate):

| Body | BASE | Candidate |
| --- | --- | --- |
| `if (identical(params$environment, "live")) NULL` | tier_1 | tier_3 (`$environment`) |
| `s <- list(environment = 0.3, social = 0.2); s$environment` | tier_1 | tier_3 |
| `d <- data.frame(environment = 1); d[["environment"]]` | tier_1 | tier_3 |
| `lbl <- c("environment", "momentum")` | tier_1 | tier_3 (`"environment"`) |

`blocked <- c(private, reaching)` (`R/strategy-preflight.R:443`) checks
member names against every environment-reaching function name. The
string-constant check at `R/strategy-preflight.R:487-490` does the same.
"environment" is an ordinary word and an ESG pillar label. The other names
(`get0`, `mget`, `current_env` ...) are unlikely field names. The refusal
fails closed and names the access, so this is not blocking. It is the same
defect class as F2, and contract line 1655-1660 now states it as the rule.
`own_notes` and `own_positions` (a strategy's own `.notes`/`.positions`
field) also move from Tier 1 to Tier 3. The contract accepts that
explicitly (first bullet, "on any object"), so it is not a finding.

Smallest fix:

- Refuse a reaching name in member position only when it is called
  (`x$environment(...)`, `x[["environment"]](...)`) or passed as a
  function argument.
- Refuse a string naming one only in function-argument position (`FUN` of
  the apply family, `match.fun`, `do.call`, `Map`/`mapply`'s `f`, `Reduce`,
  `Filter`).
- Add `params$environment` and an `"environment"` label to LTB-0371's kept
  set.

### R3 (low, detector): four rule mutations survive LTB-0371 / LTB-0407

| ID | Mutation | Result |
| --- | --- | --- |
| Y4 | `@` extraction not scanned | LTB-0371 passes (no `@` body) |
| Y5 | `ns_env`, `pkg_env`, `ns_imports_env` dropped | passes (no body) |
| Y7 | string check limited to base names (rlang names in strings allowed) | passes |
| Y10 | sufficiency consistency check skipped for the long layout | LTB-0407 passes; its filtered and broken results are wide |

The code is right on my probes (`at_s4`/`slot_s4` are Tier 3). Each is one
body or one long-layout refusal away from being pinned. LCL-0361's scope
names `@` and the rlang getters, and LCL-0397 names "a filtered or
column-dropped result", so the claims are wider than their detectors.

## Item results

| Item | Result |
| --- | --- |
| F1 | Not closed (R1). The first review's routes are all refused, and the limits text is accurate for what it lists. It is not complete. |
| F2 | Closed for dot-prefixed names: every listed body is at its BASE tier, and the 632-function scan shows one change only (LTB-0055). Recurs for `environment` (R2). |
| LTB-0055 test change | Valid. At BASE the body called `ledgr:::ledgr_normalize_ts_utc()` and was Tier 2 through the captured `fixture`. Moving the timestamp outside keeps it Tier 2 through the captured `fail_at`. That value is the same value the body computed, so the same pulse fails: the `c("DONE", "FAILED")` status oracle still requires the injection to fire. The subject (disposition artifacts discarded for the failed candidate only) and every oracle are unchanged. The reason is the product rule the review asked for, which follows the pre-existing contract line that only the exported namespace is Tier 1-compatible. It is not bending setup around a product defect, and the reason is stated in the block and the closeout. |
| F3 | Closed. `ledgr_history_sufficient()` calls `ledgr_history_require_consistent()` (`R/history-frame.R:1243`). Q6 fails LTB-0407 (2). Help and condition reference agree. Long-layout detector gap: R3 Y10. |
| F4 | Closed. `contracts.md:780-791`: the recipient term is in the recipient's own split-adjusted units. The as-traded ratio converts as ratio times the recipient's factor divided by the parent's, over the entitlement-to-reference span. Cash divides by the parent's factor. I checked the arithmetic independently. |
| F5 | Closed. LTB-0413's literals match my hand derivation (40, 42, 45, 45, 52, 57 at their own pulses; 85, 95 after the relisting; 59 using session 4). X7, X8 and X9 each fail LTB-0413 (1, 3, 1) and pass the other 20 history blocks, so LTB-0413 is the sole detector, as LCL-0403 says. |
| F6 | Closed. LDG-3068 is `review_pending` (a status `tools/governance-report.R` recognises). The closeout records item 5 as pending and the fixture lane as 48 of 50 with the disposition. |
| N1 | Routed into LDG-3069's scope with the measured numbers. |
| N2 | Closed. Three cyclic names and an `"admissible"` read are added. X5 and X6 each fail LTB-0407 (1). |
| N3 | Closed. `?ledgr_history_weights` names `ledgr_invalid_strategy_type`. |
| N4 | Routed as a phase-B teaching note (closeout 327-330). |
| Census tooling | Correct. `call_name()` now requires a symbol in `head[[1L]]`, so `f(x)(y)` heads no longer stop it. `--mode=check` gives the closeout's counts (helpers 1,823, findings 72, 158 branch and 55 flow sites). The CSV deltas are line shifts and new call sites. |
| Shapes and cost | Preflight is not a hot path: it runs once per run, sweep or walk-forward, not per pulse or candidate. The new code adds one `%in%` per AST node and one export lookup per qualified reference, with no new loop over a growing data collection. `probe_scale.R`, medians of 3: 250/1,000/4,000 generated statements take 0.14/0.63/3.25 s at BASE and 0.16/0.67/3.93 s on the candidate (+6 to +21 percent). The slight superlinearity is pre-existing (BASE shows it too). |
| IDs and docs | New claims LCL-0361 and LCL-0396..0403 and blocks LTB-0371 and LTB-0406..0413 are within the reserved ranges, one block each. Roxygen, Rd and contract text agree. `contracts.md:1868` still says "dot-prefixed context internals and closure-environment introspection", which is accurate but omits the namespace route (cosmetic). |

Valid-strategy tiers (`probe_bypass.R`, BASE / candidate): tidymodels
`.pred`, broom `.fitted` + `[[".resid"]]`, a vector of dot strings and the
base pipe are Tier 1 / Tier 1. purrr `~ .x + .y`, `function(.x)` and dplyr
`.data[["a"]]` are Tier 2 / Tier 2. dplyr `.data$a + .env$a` and magrittr
`.`, `.$a` are Tier 3 / Tier 3, as unresolved `.env` and `.` at BASE too.

## Mutations (mutation copy, each restored)

| ID | Mutation | Block | Result |
| --- | --- | --- | --- |
| M0 | none (comment) | LTB-0371, 0407, 0408, 0413 | 155, 65, 180, 23 expectations; none failed |
| Q1 | non-exported `ledgr:::` allowed | LTB-0371 | fails (6) |
| Q2 | environment names in strings allowed | LTB-0371 | fails (26) |
| Q3 | environment names as members allowed | LTB-0371 | fails (7) |
| Q4 | any dot-prefixed extraction refused again | LTB-0371 | fails (3) |
| Q5 | every private field name refused in strings | LTB-0371 | fails (1) |
| Q6 | sufficiency reads stale metadata | LTB-0407 | fails (2) |
| X5 | named weights by the inverse permutation | LTB-0407 | fails (1) |
| X6 | `excluded_ids` ignores `requested` | LTB-0407 | fails (1) |
| X7 | `used_before_window` from the vintage row | 21 history blocks | LTB-0413 fails (1); the other 20 pass |
| X8 | knowledge at the pulse instant counted as later | same | LTB-0413 fails (3) |
| X9 | vintage terminal flag from the base mask | same | LTB-0413 fails (1) |
| Y1 | `utils::`/`methods::` getters not checked | LTB-0371 | fails (11) |
| Y2 | `get0`, `mget` dropped from the list | LTB-0371 | fails (8, error) |
| Y3 | single-bracket extraction not scanned | LTB-0371 | fails (1) |
| Y4 | `@` extraction not scanned | LTB-0371 | survives (R3) |
| Y5 | rlang namespace getters dropped | LTB-0371 | survives (R3) |
| Y6 | `.pulse_lookup` dropped from the carriers | LTB-0371 | fails (6) |
| Y7 | string check for base names only | LTB-0371 | survives (R3) |
| Y8 | `[[` names checked against private fields only | LTB-0371 | fails (1) |
| Y9 | exported-ness read from the whole namespace | LTB-0371 | fails (6) |
| Y10 | sufficiency consistency for wide layout only | LTB-0407 | survives (R3) |

## Suite and checkers

- Full suite on the candidate copy (`load_all()`, then `test_local(...,
  reporter = 'summary', stop_on_failure = FALSE, load_package = 'none')`):
  1,159 blocks, 19,123 expectations, 0 failures, 0 errors, one optional
  skip (`ledgr_snapshot_from_yahoo requires quantmod`), 686 s of block time.
  This matches the closeout.
- `tools/check-codebase-contracts.R --mode=check`: `LEDGR_CODEBASE_CENSUS_OK`
  (helpers 1,823, findings 72) and `LEDGR_MODE_BRANCH_CENSUS ...
  branch_sites=158 flow_sites=55`. `--self-test-mode-branches`:
  `LEDGR_MODE_BRANCH_SELF_TEST_OK`.
- `tools/check-fold-phase-contract.R .`: `LEDGR_FOLD_PHASE_CONTRACT_OK`.
- `git diff --check c1dca21c 757a037f` is clean, and every changed file is
  ASCII.
- Not run: the fixture lane, the fast, review and heavy profiles, and
  `R CMD check`.

## Review ratio

Three findings (R1-R3) over eleven re-reviewed items (F1-F6, N1-N4 and
the census tooling fix): 3/11 = 0.273. This is correction round 1. A
further correction of R1 would be round 2. The design note under R1 is for
the maintainer, if that round is again a list extension.
