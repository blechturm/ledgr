# WS44 phase A focused re-review 2 (Type 1), `1e29d86a..ba3d80db`

## Verdict: CHANGES_REQUIRED

Correction 2 closes most of what re-review 1 asked for:

- All eight R1 bodies are now Tier 3. LTB-0371 runs each of them through
  `ledgr_run()`, which refuses before any store row is written.
- The four R2 bodies are back at their BASE tier.
- Y4, Y5, Y7 and Y10 now fail their blocks.
- Decision (30) is recorded in `tickets.yml`, in the LDG-3072 amendment, in
  the contract, in `?ledgr_strategy_preflight` and as a non-binding horizon
  entry.
- No literal among the 632 strategy literals changes tier against BASE.

Four defects remain, all against LDG-3072 and the contract text it wrote:

- S1 (blocking): the R1 route still passes when it is spelled with a
  package prefix. `base::body(f) <- quote(feature_vector)` is Tier 1.
  `rlang::fn_body(f) <-` and `fn_env()` with rlang attached are Tier 2. Each
  reads the full eight-session feature projection at the first pulse. The
  contract says these functions are refused "whether called, qualified ...".
- S2 (medium): R2 recurs through the apply family. Ordinary `environment`
  data passed to a functional moves from Tier 1 at BASE to Tier 3. Examples:
  `tapply(d$environment, d$sector, mean)`, `sapply(s, "[[", "environment")`
  and `mapply(f, x, params$environment)`.
- S3 (low): the new rule that refuses a non-exported ledgr name anywhere in
  the syntax tree also refuses a strategy's own names when they match one,
  for example a local `config_hash`, a member `res$config_hash` or a local
  helper `compute_sharpe_ratio`.
- S4 (low, detector): four mutations of the new rules survive LTB-0371.

A fix would be correction round 3, so it goes to the maintainer under
AGENTS.md. None of the findings questions decision (30). Each one is either
a literal rule that decision (30) names and that is applied incompletely, or
a contract claim the code does not meet. So this is not a Type 2 matter.

Method:

- Read AGENTS.md, both earlier reviews, the Correction 2 section of
  `history_proof_phase_a_closeout.md`, decision (30), LDG-3072 and
  LCL-0361. Read the whole of `git diff 1e29d86a..6503c90a` and the merge
  `ba3d80db` (including `git show --remerge-diff`).
- Source copies in the scratchpad `ws44a_rereview2/`:
  - `head`, from `git ls-files` at `ba3d80db`;
  - `mut`, the same, used for mutations;
  - `base`, from `git archive 6f019c6b`.
  Every R process ran sequentially.
- Probes (in `ws44a_rereview2/probes/`):
  - re-review 1's `probe_bypass.R`, `probe_names.R`, `probe_scan.R` and
    `probe_scale.R`, re-run;
  - `probe_c2.R`: 40 new bodies, classified on HEAD and BASE;
  - `probe_run.R` and `probe_run_rlang.R`: the non-Tier-3 bypasses executed
    in `ledgr_run()` on the WS42 fixture, recording what each reached at
    the first pulse (2021-01-04);
  - `internal_names.R`: the names the new symbol rule refuses.
- 25 mutations:
  - the implementer's W1-W8 and the re-review's Y4, Y5, Y7 and Y10,
    regenerated from the committed `make_specs.py`;
  - 13 of my own (Z0-Z12) on the new rules.
  Each ran through the committed `mutate.py`, which restores the file byte
  for byte. Afterwards `diff -rq head mut` showed no difference.

## Findings

### S1 (blocking; LDG-3072 acceptance 2, `contracts.md:1658-1666`, LCL-0361): qualified and attached spellings of the refused functions pass

Verified on the `head` copy. The tier is from `probe_c2.R`. "Reached" comes
from `probe_run.R` and `probe_run_rlang.R` on the WS42 fixture, at the
first pulse.

| Body (strategy fragment) | Tier (BASE / HEAD) | Reached at the first pulse |
| --- | --- | --- |
| `f <- ctx$feature; base::body(f) <- quote(feature_vector); fv <- f(); base::body(fv) <- quote(feature_values); v <- fv()` | tier_1 / tier_1 | the feature projection, 8 sessions; AAA's session-8 SMA 17.5 |
| the same with `rlang::fn_body(f) <-` | tier_2 / tier_2 | the same, 17.5 |
| `library(rlang)` attached; `env_get(fn_env(ctx$feature), "feature_vector", inherit = TRUE)`, then `fn_env()` of that closure | tier_2 / tier_2 | the 3 x 8 feature-value matrix, 17.5 |
| `base::formals(f) <- list(instrument_id = quote(feature_vector), ...)` | tier_1 / tier_1 | ran; not instrumented further |

In contrast, the unqualified `body(f) <- quote(feature_vector)` is Tier 3
(`body<-()`), as LTB-0371 pins.

The causes are in `R/strategy-preflight.R`:

- Line 555 compares `qualified$name` with the list. R parses
  `base::body(f) <- v` as an assignment whose target is a call headed by
  `base::body`. So the qualified name is `body`, not `body<-`, and it does
  not match. codetools does not report `body<-` for the qualified form
  either.
- Line 548 checks codetools' global symbols against `env_fns$base` only. So
  every rlang name (`fn_env`, `env_get`, `current_env`, `fn_body<-` ...)
  is refused only when written `rlang::name(...)` in call form, or named in
  a string passed to a functional. With rlang attached, the same names are
  resolved as an attached package and come out Tier 2.
- The two new entries `fn_body<-` and `fn_fmls<-` therefore fire only for
  the literal backtick call `` rlang::`fn_body<-`(f, value) ``. That is not
  how a replacement function is normally written.

The contract (`contracts.md:1658-1666`) lists `body<-`, `formals<-` "and
their `rlang` equivalents", refused "whether called, qualified, passed as a
value ...". LCL-0361's scope says the same. The general limit sentence at
`contracts.md:1675-1681` ("by a route preflight does not recognise") cannot
cover a route that the rule list two sentences earlier names as refused.
The first row is R1's own route (rebinding a body in a closure's
enclosure), and `base::` qualification is an ordinary coding style. So this
is not one of the deliberate-subversion cases that decision (30) places
outside the guarantee.

The attached-rlang gap already existed at Correction 1, and re-review 1
missed it. It is reported here because Correction 2's contract text claims
the route is refused.

Smallest fix:

- When an assignment target is a call whose head is `pkg::name` or
  `pkg:::name`, also test `paste0(name, "<-")` against the list.
- Check the codetools symbols against `c(env_fns$base, env_fns$rlang)`
  (line 548). An attached rlang name in call position is the same access.
- Add `base::body(f) <-`, `rlang::fn_body(f) <-`, a `formals<-`-only body
  and an unqualified `fn_env()` to LTB-0371.

### S2 (medium; LDG-3072 acceptance 3, `contracts.md:1670-1672`, LCL-0361): `environment` data handed to a functional changes tier

Verified (`probe_c2.R`, BASE / HEAD):

| Body | BASE | HEAD |
| --- | --- | --- |
| `tapply(d$environment, d$sector, mean)` | tier_1 | tier_3 (`tapply("environment")`) |
| `sapply(d$environment, function(x) x * 2)` | tier_1 | tier_3 |
| `lapply(d[["environment"]], sqrt)` | tier_1 | tier_3 |
| `sapply(s, "[[", "environment")` | tier_1 | tier_3 |
| `vapply(s, getElement, numeric(1), "environment")` | tier_1 | tier_3 |
| `mapply(function(a, b) a, 1:2, params$environment)` | tier_1 | tier_3 |
| `Reduce(`+`, d$environment)` | tier_1 | tier_3 |
| `do.call(paste, list("environment", "score"))` | tier_1 | tier_1 |

The loop at `R/strategy-preflight.R:521-529` checks every argument of a
functional, not only its function slot. Any string, `$` member or `[[`
member equal to an environment-reaching name is refused wherever it sits in
the call. Pulling an ESG pillar out of a list of scores, or grouping a
column called `environment`, is the case re-review 1's R2 named. The
contract now says both that such a column keeps its tier (`1670-1672`) and
that a "member handed to a functional" is refused (`1665`). The fails-closed
refusal names the access, so this is not blocking. It is the third time the
name-collision class has come back (F2, R2, now S2).

Smallest fix: inspect only the argument that the functional calls. That is
`FUN` of the apply family (matched by name or position), `f` of
`Map`/`Reduce`/`Filter`/`Find`/`Position`, `what` of `do.call`, the first
argument of `match.fun` and `Vectorize`, and `f` of `rapply`. Matching the
call against the functional's formals with `match.call()` gives this
cheaply. Add `tapply(d$environment, ...)` and `sapply(s, "[[",
"environment")` to LTB-0371's kept set.

### S3 (low; LDG-3072 acceptance 3): a strategy's own name equal to a ledgr internal is refused

Verified (`probe_c2.R`, `internal_names.R`):

- Every one of these is tier_1 at BASE and tier_3 at HEAD, with the reason
  "`<name>` (not exported)":
  - `config_hash <- "abc"`;
  - `res <- list(config_hash = 1); res$config_hash`;
  - a local helper `compute_sharpe_ratio <- function(r) ...`;
  - `snapshot_state <- 1`.
- These stay tier_1: a string or a comment that mentions
  `ledgr_history_context_view`, an argument name (`list(config_hash = 1)`)
  and `res[["config_hash"]]`.

`ledgr_strategy_ledgr_internal_names()` returns 1,713 names. 96 of them do
not start with `ledgr_` or `.__`. About twenty of those are generic
analytics or bookkeeping names a strategy author could use:

- `compute_sharpe_ratio`, `compute_max_drawdown`,
  `compute_period_returns`, `compute_annualized_return`,
  `compute_annualized_volatility`, `compute_rf_period_return`,
  `compute_time_in_market`;
- `config_hash`, `config_hash_payload`, `backtest_state`,
  `snapshot_state`, `canonical_json`, `get_connection`,
  `snap_to_frequency`, `validate_ledgr_config`.

`all.names()` at `R/strategy-preflight.R:551` includes the member symbol of
`$` and `@`, and names the strategy binds itself. No literal in the repo is
affected (632-literal scan). Decision (30) prescribes the "anywhere in the
AST" rule. So this is low: the defect is the collision, not the rule.

Smallest fix: leave the right-hand symbol of `$` and `@` out of the
AST-wide scan. Then either prefix the generic internals with `ledgr_` or
skip names the body itself binds (`<-`, `=`, `for`, formals of an inner
`function`).

### S4 (low, detector): four mutations of the new rules survive LTB-0371

| ID | Mutation | Result |
| --- | --- | --- |
| Z4 | `formals<-` alone dropped from the list | LTB-0371 passes (no body uses only `formals<-`) |
| Z5 | rlang `fn_body<-` and `fn_fmls<-` dropped | passes (no body; see S1, the entries are nearly unreachable) |
| Z8 | `bquote()` given `where` by position (`bquote(.(x), ctx)`) not refused | passes (the only body names `where =`) |
| Z12 | the AST-wide carrier-symbol rule limited to `.history` | passes (no symbol body for `.feature_vector`, `.pulse_lookup` or `.feature_table_current`) |

LCL-0361 names `formals<-`, the rlang equivalents, `bquote()` with an
environment and every future-bearing carrier as a symbol. So the claim is
wider than its detector. Each gap needs one body.

## Item results

| Item | Result |
| --- | --- |
| R1 | Closed for the eight bodies. `probe_bypass.R` on HEAD: `body_rebind_export`, `body_rebind_closure`, `formals_rebind`, `s3method_rebind`, `unserialize_rebind`, `substitute_ctx`, `bquote_where`, `docall_with`, `docall_evalq`, `baseenv_eval`, `with_symbol` and both rlang evals are Tier 3. LTB-0371 runs 42 refused bodies through `ledgr_run()` (`ledgr_strategy_tier3`), and store counts are unchanged (`test-strategy-private-context.R:326-341`). Not closed for the qualified and attached spellings (S1). `Filter()`/`Find()` iteration stays Tier 1, which the contract states as outside the guarantee. |
| R2 | Closed for the four named bodies (`probe_names.R`: `param_env`, `label_env`, `df_col_env` and `esg_env` are tier_1 on HEAD and BASE). Recurs through functional arguments (S2). `own_notes` and `own_positions` stay Tier 3, which the contract accepts. |
| R3 | Closed. Y4, Y5, Y7 and Y10 fail their blocks (4, 6, 4 and 1 failures; Y4 and Y7 with an error). New detector gaps are in S4. |
| Decision (30) in the contract and help | Present and accurate as a statement: best-effort, not a sandbox, R has no private memory; deliberate subversion and future-data files are outside the guarantee; ledgr guarantees its own history, feature and fact APIs (`contracts.md:1642-1681`, `R/strategy-preflight.R:32-51`, `man/ledgr_strategy_preflight.Rd`; the Rd matches the roxygen). The rule list it introduces overclaims for S1 and conflicts with itself for S2. `contracts.md:1867-1874` (Pulse Data) now names the namespace route; re-review 1's cosmetic note is done. |
| Decision (30) in `tickets.yml` | The decision text is present as Cut 16 decision (30). LDG-3072 acceptance 2 now reads "listed in the contract as outside preflight's static guarantee". The Correction 2 evidence entry is present, and the status is `complete`. That status is premature while S1 stands. |
| Horizon | `horizon.md:32`, "2026-10-21 [execution] Cutoff-bound context internals or a strategy sandbox": trigger "ledgr needs to run untrusted strategies"; "This entry authorizes no RFC, API or release scope". Non-binding as required. |
| Merge `ba3d80db` | Parents `6503c90a` and `a92b5765`. The integration side brings the brace-lint fixes (`R/walk-forward-folds.R`, `test-precompute-features.R`, `tools/governance-report.R`; layout only), the DuckDB 1.5.6 schema golden and planning text (`horizon.md`, roadmap, macro plan). `--remerge-diff` shows conflicts only in census `connections.csv` and `helpers.csv`, regenerated. No preflight, test-oracle or Correction 2 file is touched. Census check passes on the merged tree (below). |
| IDs, claims and docs | Correction 2 adds no new claim or block ID. It amends LCL-0361 and LCL-0397, and LTB-0371 and LTB-0407 gain bodies. `git diff --check 1e29d86a ba3d80db` is clean, and every changed file is ASCII. The reproducibility article's Tier 3 row and the leakage article's "not a sandbox" sentence agree with decision (30). LCL-0361's scope overclaims for S1, S2 and S4. |
| 632-literal scan | `probe_scan.R`: BASE sources under BASE give 38 ERROR, 506 tier_1, 23 tier_2 and 65 tier_3. BASE sources under HEAD give the same distribution and the same tier for every literal. The closeout's "BASE's tier for every one" holds in the scan's semantics (globalenv environment). LTB-0055's BASE strategy is Tier 3 in both arms there, because its captured objects read as unresolved. |
| Shapes and cost | Preflight runs once per run, sweep or walk-forward, not per pulse. The new code adds one `all.names()` pass, one cached `ls()` of the namespace and a per-node functional check, with no loop over a growing data collection. `probe_scale.R`, medians of 3, for 250, 1,000 and 4,000 statements: 0.16, 0.69 and 3.35 s at BASE against 0.18, 0.80 and 4.25 s at HEAD (+12 to +27 percent; re-review 1's candidate was 3.93 s at 4,000). Not material. |

## Notes (not findings)

- N1: `bquote(.(x) + 1, splice = TRUE)` is refused, with the reason
  `bquote(<expr>, where = <env>)`. `R/strategy-preflight.R:535-536`
  treats any third argument as `where`. This is rare and fails closed, but
  the reason is wrong. Matching `where` by name or as the second positional
  argument fixes it.
- N2: other bypasses I found. Decision (30) places these outside the
  guarantee, and the general limit sentence covers them.
  - Tier 1 at HEAD:
    - `(baseenv()$environment)(ctx$feature)` (the parentheses defeat the
      extracted-and-called check);
    - `g <- baseenv()$environment; g(ctx$feature)`;
    - `getElement(baseenv(), "environment")(ctx$feature)`;
    - `methods::functionBody(f) <- quote(feature_vector)` (it ran and
      reached the 8-session projection, 17.5);
    - `trace()`, which also mutates ledgr's namespace;
    - `Filter()`/`Find()` over `as.list(ctx, all.names = TRUE)`.
  - Stripping `(` in `extraction_name()` and adding `functionBody<-` are
    each one line, if wanted.
- N3: `get("environment")` stays Tier 3, through the existing forbidden
  `get`.

## Mutations (`mut` copy, each restored)

| ID | Mutation | Block | Result |
| --- | --- | --- | --- |
| Z0 | none (comment) | LTB-0371 | 227 expectations; none failed |
| W1 | carrier symbols not scanned | LTB-0371 | fails (11) |
| W2 | non-exported ledgr symbols allowed | LTB-0371 | fails (7) |
| W3 | `body<-`, `formals<-`, `as.function`, `unserialize` dropped | LTB-0371 | fails (14) |
| W4 | `substitute()` with an environment allowed | LTB-0371 | fails (7) |
| W5 | `bquote()` with `where` allowed | LTB-0371 | fails (1) |
| W6 | names handed to a functional allowed | LTB-0371 | fails (29, error) |
| W7 | members extracted and called allowed | LTB-0371 | fails (7) |
| W8 | member names checked against reaching names again | LTB-0371 | fails (1) |
| Y4 | `@` extraction not scanned | LTB-0371 | fails (4, error) |
| Y5 | rlang namespace getters dropped | LTB-0371 | fails (6) |
| Y7 | functional string check for base names only | LTB-0371 | fails (4, error) |
| Y10 | sufficiency consistency for the wide layout only | LTB-0407 | fails (1) |
| Z1 | AST-wide scan skips function heads | LTB-0371 | fails (6) |
| Z2 | AST-wide scan replaced by codetools globals (quoted code unseen) | LTB-0371 | fails (17) |
| Z3 | internal-name list includes exports | LTB-0371 | fails (2, error) |
| Z4 | `formals<-` alone dropped | LTB-0371 | survives (S4) |
| Z5 | rlang `fn_body<-`, `fn_fmls<-` dropped | LTB-0371 | survives (S4) |
| Z6 | `as.function` alone dropped | LTB-0371 | fails (2) |
| Z7 | `unserialize` alone dropped | LTB-0371 | fails (6) |
| Z8 | positional `bquote()` `where` not checked | LTB-0371 | survives (S4) |
| Z9 | `substitute()` needs a fourth element | LTB-0371 | fails (7) |
| Z10 | functionals reduced to `lapply` | LTB-0371 | fails (11) |
| Z11 | extracted-and-called check for `$`/`@` only | LTB-0371 | fails (1) |
| Z12 | carrier symbols limited to `.history` | LTB-0371 | survives (S4) |

## Suite and checkers

- Full suite on the `head` copy (`load_all()`, then `test_local(...,
  reporter = 'summary', stop_on_failure = FALSE, load_package = 'none')`):
  1,159 blocks, 19,196 expectations, 0 failures, 0 errors, and one
  optional skip (`ledgr_snapshot_from_yahoo requires quantmod`). Block time
  was 693 s. The expectation count matches the closeout. LTB-0258, which the
  closeout recorded as failing on DuckDB 1.5.6, passes on the merged tree
  with the integration golden.
- `tools/check-codebase-contracts.R --mode=check`:
  `LEDGR_CODEBASE_CENSUS_OK` (helpers 1,824, findings 72) and
  `LEDGR_MODE_BRANCH_CENSUS ... branch_sites=158 flow_sites=55`.
  `--self-test-mode-branches` gives `LEDGR_MODE_BRANCH_SELF_TEST_OK`.
- `tools/check-fold-phase-contract.R .`: `LEDGR_FOLD_PHASE_CONTRACT_OK`.
- Not run: the fixture lane, the fast, review and heavy profiles, and
  `R CMD check`.

## Review ratio

Four findings (S1-S4) over eight re-reviewed items (R1, R2, R3, the
decision (30) contract and help text, its `tickets.yml` record, the horizon
entry, the merge, and IDs, claims and docs): 4/8 = 0.500. This review
follows correction round 2. A correction of S1-S4 would be round 3, which
AGENTS.md sends to the maintainer.
