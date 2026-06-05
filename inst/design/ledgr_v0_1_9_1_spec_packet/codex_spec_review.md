# Codex Spec Review: v0.1.9.1

Review date: 2026-06-05

Reviewed packet: `inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md`

## 1. Verdict

Verdict: `revise before ticket-cut`.

The packet is directionally sound and appropriately scoped, but it should not
cut tickets until three concrete spec edits land:

1. Correct stale or wrong implementation anchors in Workstream B and the
   inspection-helper citation in Workstream A.
2. Tighten the THEME-004 `config_hash` contaminant language so the ticket cut
   matches the current implementation evidence.
3. Resolve the public `ledgr_backtest()` cost/timing argument decision that the
   synthesis explicitly left to spec-cut.

The scope envelope is correct. The packet is not too large: cost identity,
THEME-004 identity hardening, and the installed disclaimer break are load
bearing before the v0.1.9.x walk-forward culmination. The medium-severity
auditr documentation work is bounded enough if the spec records what is in and
what is intentionally deferred.

## 2. Blocker Findings

### Blocker 1: Workstream B cites a nonexistent fold-core file and the wrong inspection-helper section.

The spec tells implementers to rename `commission_fixed` to `fee` at the
cash-delta computation site in `R/fold-core.R` and related files
(`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:359` through
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:364`). There is no
`R/fold-core.R` in the current source tree. The current cash-delta write path is
in `R/backtest-runner.R`: `ledgr_fill_event_payload()` reads
`commission_fixed`, computes `cash_delta`, writes `fee`, and serializes
`commission_fixed` in `meta_json` (`R/backtest-runner.R:141` through
`R/backtest-runner.R:204`). The fold execution structure is in
`R/fold-engine.R` and the typed execution spec in `R/execution-spec.R`, where
`cost_resolver` is already a required execution-spec function
(`R/execution-spec.R:45` through `R/execution-spec.R:72`,
`R/execution-spec.R:216` through `R/execution-spec.R:219`).

The cost synthesis Section 12 names the correct migration neighborhood:
`R/fill-model.R`, `R/backtest-runner.R`, output handlers, lot accounting, and
tests (`inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:503`
through
`inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:504`).
It also says fold-core integration must happen through the existing
proposal/resolver seam with no fold-core changes
(`inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:507`
through
`inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:508`).

The same workstream has a smaller citation error: inspection helpers are
specified in synthesis Section 4.8, not Section 4.5. The spec cites Section 4.5
for `ledgr_cost_steps()` and `ledgr_cost_describe()`
(`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:348` through
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:349`), while the
synthesis places those helpers under Section 4.8
(`inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:279`
through
`inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:284`).

Required edit:

Replace Workstream B ticket 7 with source-accurate text:

```text
7. `commission_fixed` to `fee` rename. Rename the internal proposal and
   resolver field at the current fill-event/cash-delta path
   (`R/backtest-runner.R`), `R/fill-model.R`, `R/sweep.R` memory output
   handler rows, and `R/lot-accounting.R`; preserve the existing ledger
   `fee` column. Do not cite `R/fold-core.R`; it does not exist in this
   tree. Keep fold integration at the existing proposal/resolver seam.
```

Also change Workstream A ticket 5 to cite synthesis Section 4.8, not Section
4.5.

### Blocker 2: Ticket 11 overstates `run_id` as the proven `config_hash` contaminant.

The spec repeatedly says the current `config_hash` is contaminated by `run_id`
or store-path differences
(`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:135` through
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:141`,
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:241` through
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:245`,
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:387` through
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:394`).

That is directionally right, but it needs sharper wording before ticket-cut.
The current hash implementation is simple: `config_hash()` hashes
`canonical_json(config)` (`R/config-hash.R:1` through `R/config-hash.R:3`).
The runner computes `config_json` and `cfg_hash` before it derives a fallback
`run_id` from that hash (`R/backtest-runner.R:648` through
`R/backtest-runner.R:659`). So the episode 043 same-session recomputation
evidence cannot be attributed to fallback `run_id` alone. The stronger direct
implementation evidence is that `ledgr_config()` puts `db_path` into the
hashed config and also stores `data$snapshot_db_path`
(`R/backtest.R:875`, `R/backtest.R:923` through `R/backtest.R:927`).
It only adds `config$run_id` when an explicit run ID is supplied
(`R/backtest.R:930`). The run-store reopen path also re-injects `db_path`
into loaded configs (`R/run-store.R:952` through `R/run-store.R:967`).

The auditr evidence matches that reading. Episode 043 says the first
same-session recomputation used the same snapshot ID, bars, aliased features,
grid, run ID, and seed, but a different DuckDB path; all inspected hashes
matched except `config_hash`
(`inst/design/ledgr_v0_1_9_1_spec_packet/categorized_feedback.yml:1180`
through
`inst/design/ledgr_v0_1_9_1_spec_packet/categorized_feedback.yml:1187`).
Episode 037 FB-002 says two same literal feature-map runs produced identical
`alias_map_hash` but different `config_hash`
(`inst/design/ledgr_v0_1_9_1_spec_packet/categorized_feedback.yml:973`
through
`inst/design/ledgr_v0_1_9_1_spec_packet/categorized_feedback.yml:980`).

Required edit:

Change the spec from "contaminated by `run_id` or store-path differences" to:

```text
`config_hash` must exclude storage-location fields (`db_path`,
`data.snapshot_db_path`) and explicit run identity fields (`run_id`, if present)
from the identity payload unless a field is intentionally retained with a
recorded rationale. The episode 043 reproduction specifically demonstrates
store-path sensitivity; explicit `run_id` is a potential contaminant because
`ledgr_config()` can include it in the config object.
```

This preserves the intended fix while preventing the ticket from asserting a
cause that the current implementation does not support.

### Blocker 3: The spec must decide the exported `ledgr_backtest()` cost/timing shape.

The cost synthesis explicitly leaves a spec-cut decision about the exported
`ledgr_backtest()` surface: either it gets `timing_model` and `cost_model`
arguments directly, or it becomes a legacy wrapper with classed migration
guidance (`inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:417`
through
`inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:420`).

The v0.1.9.1 spec requires `timing_model` on `ledgr_experiment()`
(`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:333` through
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:337`), and it
requires a non-null `cost_model` on `ledgr_experiment()`
(`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:379` through
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:383`). Workstream B
does say the `fill_model` to `timing_model` rename propagates across
`R/backtest.R` and the exported `ledgr_backtest()` argument
(`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:366` through
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:372`). It does not
say whether `ledgr_backtest()` gets the new required `cost_model` argument,
whether it errors as a legacy wrapper, or how the no-null-cost decision applies
to that convenience path.

Required edit:

Add one sentence to Workstream B ticket 8 or ticket 10:

```text
`ledgr_backtest()` receives the same public `timing_model` and required
`cost_model` arguments as `ledgr_experiment()`; legacy `fill_model` on this
path raises `ledgr_legacy_fill_model_shape`.
```

If the maintainer wants the other synthesis-allowed option, say that instead:

```text
`ledgr_backtest()` becomes a legacy convenience wrapper for this packet and
does not admit the new cost API; it fails with classed migration guidance when
users pass legacy `fill_model`.
```

Do not leave this as an implementation inference. It is explicitly spec-cut
work in the accepted synthesis.

## 3. High-Severity Findings

### High 1: Cost-API docs scope does not explicitly cover timing-vs-cost separation and non-scope disclosure.

This is not a blocker because the planned tickets can still be cut with a
minor edit, but it is load-bearing for first-use comprehension. The synthesis
Section 12 documentation cluster requires a vignette section explaining timing
vs cost separation, a section explaining price transforms vs explicit fees, the
quoted-spread worked example, and explicit non-scope documentation for
liquidity, financing, TCA, taxes, OMS, and broker reconciliation
(`inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:510`
through
`inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:515`).

The v0.1.9.1 spec's metrics-and-accounting ticket covers quoted spread,
cost-API surfaces, and the round-trip example
(`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:456` through
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:464`), but it does
not explicitly say the article must teach timing vs cost separation, price
transforms vs explicit fees, or the non-scope list. The non-goals section lists
these deferrals globally (`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:511`
through
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:521`), but the RFC
requires user-facing documentation.

Required edit:

Extend Workstream E ticket 19 with:

```text
The article must include timing-vs-cost separation, price-transform-vs-fee
separation, and explicit non-scope bullets for liquidity, financing, TCA,
taxes, OMS, and broker reconciliation.
```

## 4. Medium-Severity Findings

### Medium 1: Success criteria say four medium documentation themes even though the spec scopes five.

The thesis correctly says five MEDIUM-severity documentation themes were
surfaced (`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:95`
through
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:97`). Goal 8 also
names five themes: THEME-002, THEME-003, THEME-005, THEME-006, and THEME-010
(`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:166` through
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:195`). But the
success condition says "the four medium-severity documentation themes"
(`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:99` through
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:104`).

Required edit:

Change "four medium-severity documentation themes" to "five medium-severity
documentation themes scoped in Goal 8." This is a small text fix, but it
prevents a ticket coverage ambiguity.

### Medium 2: THEME-005 is broader than new cost-condition docs.

The triage report summarizes THEME-005 as 15 episodes and 21 feedback rows,
with missing help topics, generic messages, ambiguous classes, and examples
that do not expose key fields or offending inputs
(`inst/design/ledgr_v0_1_9_1_spec_packet/ledgr_triage_report.md:75` through
`inst/design/ledgr_v0_1_9_1_spec_packet/ledgr_triage_report.md:82`). The spec
covers new v0.1.9.1 condition classes
(`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:445` through
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:450`) and adds an
existing `LEDGR_LAST_BAR_NO_FILL` help topic
(`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:452` through
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:454`).

That is a reasonable bounded start, but two low-cost existing-condition rows are
already in the auditr evidence:

- `ledgr_run_info` not-found condition is not documented
  (`inst/design/ledgr_v0_1_9_1_spec_packet/cycle_retrospective.md:270`
  through
  `inst/design/ledgr_v0_1_9_1_spec_packet/cycle_retrospective.md:276`).
- `ledgr_feature_id()` does not document the unresolved-parameterized class
  `ledgr_unresolved_feature_id`
  (`inst/design/ledgr_v0_1_9_1_spec_packet/categorized_feedback.yml:865`
  through
  `inst/design/ledgr_v0_1_9_1_spec_packet/categorized_feedback.yml:872`).

Required edit:

Either add these two existing condition examples to Workstream E ticket 17, or
add one explicit deferral sentence naming them. My recommendation is to fold
them into ticket 17 because they are documentation-only and small.

### Medium 3: Compiled-accounting diagnostics should name stable condition classes, not only behavior.

The spec's metrics-and-accounting ticket says to document
`compiled_accounting_model` fail-closed behavior per auditr episode 040
(`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:456` through
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:464`). The auditr row
asks for a runnable example demonstrating both compiled-accounting error paths
and naming the stable top-level condition classes users should assert on
(`inst/design/ledgr_v0_1_9_1_spec_packet/categorized_feedback.yml:1108`
through
`inst/design/ledgr_v0_1_9_1_spec_packet/categorized_feedback.yml:1115`).

Required edit:

Append "and name the stable top-level condition classes users should assert on"
to Workstream E ticket 19.

## 5. Low-Severity Findings

### Low 1: The spec should explicitly defer the non-high disclaimer follow-ups.

Ticket 16 resolves the high-severity installed-link breakage:
`DISCLAIMER.md` must be included at the installed path or the vignette link must
point to an installed help/article surface
(`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:437` through
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:443`). That is
adequate for episode 046 FB-001
(`inst/design/ledgr_v0_1_9_1_spec_packet/categorized_feedback.yml:1261`
through
`inst/design/ledgr_v0_1_9_1_spec_packet/categorized_feedback.yml:1268`).

However, the same episode includes medium/low discoverability follow-ups:
overview surfaces do not expose the disclaimer, strategy-development does not
link it, and NEWS does not provide a readable path
(`inst/design/ledgr_v0_1_9_1_spec_packet/categorized_feedback.yml:1270`
through
`inst/design/ledgr_v0_1_9_1_spec_packet/categorized_feedback.yml:1295`). The
spec can defer those, but it should say so explicitly because the triage theme
summary recommends surfacing the disclaimer from package overview, doc index,
relevant articles, and NEWS
(`inst/design/ledgr_v0_1_9_1_spec_packet/ledgr_triage_report.md:155` through
`inst/design/ledgr_v0_1_9_1_spec_packet/ledgr_triage_report.md:162`).

Required edit:

Add to Section 3.5 or Ticket 16:

```text
FB-002 through FB-004 are optional follow-ups unless the chosen install-path
fix naturally exposes a stable help/article URL; the release blocker is FB-001.
```

### Low 2: The spec's review question on contracts.md should be converted to a decision before implementation starts.

The spec asks whether contracts.md should be updated for the cost API
(`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:593` through
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:596`). The current
contracts document already has execution and sweep identity constraints,
including behavior-preserving internal refactors not changing the same
canonical config hash
(`inst/design/contracts.md:86` through `inst/design/contracts.md:87`), but it
does not name the new cost API or its identity fields.

The prompt says not to prescribe a contracts.md update if the spec excludes it.
So this is not a required workstream edit. But before tickets are cut, the spec
should mark Review Question 10 as answered one way or the other in a short
"review resolution" note. Otherwise the implementation batch can drift on
whether cost identity is a contract-surface change.

Required edit:

After maintainer review, add a one-line review-resolution note:

```text
Contracts.md update for public cost identity: in scope / deferred by maintainer
decision on YYYY-MM-DD.
```

## 6. Coverage Matrix

| Auditr item or theme | Evidence anchor | v0.1.9.1 response | Status | Review note |
| --- | --- | --- | --- | --- |
| 2026-06-04_037 FB-001: `feature_set_hash` not exposed | `inst/design/ledgr_v0_1_9_1_spec_packet/categorized_feedback.yml:964` through `inst/design/ledgr_v0_1_9_1_spec_packet/categorized_feedback.yml:971` | Workstream D ticket 14 exposes `feature_set_hash` on `bt$config$features`, `ledgr_run_info()`, and `ledgr_run_list()` | covered | Good. Ensure the implementation uses the existing fingerprint-set definition in `R/precompute-features.R:400` through `R/precompute-features.R:408`. |
| 2026-06-04_037 FB-002: same literal feature-map runs differ in `config_hash` | `inst/design/ledgr_v0_1_9_1_spec_packet/categorized_feedback.yml:973` through `inst/design/ledgr_v0_1_9_1_spec_packet/categorized_feedback.yml:980` | Workstream C ticket 11 | covered, revise wording | Blocker 2: evidence supports store-path/config-payload contamination more directly than fallback `run_id` contamination. |
| 2026-06-04_037 FB-003: alias declaration order changes `config_hash` | `inst/design/ledgr_v0_1_9_1_spec_packet/categorized_feedback.yml:982` through `inst/design/ledgr_v0_1_9_1_spec_packet/categorized_feedback.yml:989` | Workstream C ticket 12 | covered | Current `alias_map_hash` is order-canonical via `R/feature-alias-map.R:38` through `R/feature-alias-map.R:50`, so the likely contaminant is `alias_map_order` in the broader config payload (`R/backtest.R:918` through `R/backtest.R:921`). |
| 2026-06-04_037 FB-004: concrete feature params change `alias_map_hash` | `inst/design/ledgr_v0_1_9_1_spec_packet/categorized_feedback.yml:991` through `inst/design/ledgr_v0_1_9_1_spec_packet/categorized_feedback.yml:998` | Workstream C ticket 13 | covered | I confirm the spec's layering reading: concrete feature identity belongs in `feature_set_hash`, not alias identity. |
| 2026-06-04_046 FB-001: installed disclaimer link missing | `inst/design/ledgr_v0_1_9_1_spec_packet/categorized_feedback.yml:1261` through `inst/design/ledgr_v0_1_9_1_spec_packet/categorized_feedback.yml:1268` | Workstream E ticket 16 | covered | Adequate for the high-severity installed-link breakage. |
| THEME-002: Strategy Context And Indicators | `inst/design/ledgr_v0_1_9_1_spec_packet/ledgr_triage_report.md:41` | Deferred unless cost teaching touches strategy context | deferred (correct) | Cost synthesis preserves strategy contract; strategies do not receive cost state (`inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:102` through `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:122`). |
| THEME-003: Sweep And Candidate Workflows | `inst/design/ledgr_v0_1_9_1_spec_packet/ledgr_triage_report.md:42` | Workstream E ticket 21 adds cost non-participation note | partially covered | Correct for v0.1.9.1. Broader sweep examples belong to v0.1.9.2 artifact persistence. |
| THEME-005: Errors Warnings And Diagnostics | `inst/design/ledgr_v0_1_9_1_spec_packet/ledgr_triage_report.md:75` through `inst/design/ledgr_v0_1_9_1_spec_packet/ledgr_triage_report.md:82` | Workstream E tickets 17 and 18 | partially covered | Add or explicitly defer existing classes noted in Medium 2. |
| THEME-006: Metrics And Accounting Surfaces | `inst/design/ledgr_v0_1_9_1_spec_packet/ledgr_triage_report.md:43` through `inst/design/ledgr_v0_1_9_1_spec_packet/ledgr_triage_report.md:44` and `inst/design/ledgr_v0_1_9_1_spec_packet/categorized_feedback.yml:54` through `inst/design/ledgr_v0_1_9_1_spec_packet/categorized_feedback.yml:61` | Workstream E ticket 19 | covered for cost/API-touching scope | Add timing-vs-cost separation and stable condition-class examples per High 1 and Medium 3. |
| THEME-010: Runnable Examples And Reference Completeness | `inst/design/ledgr_v0_1_9_1_spec_packet/ledgr_triage_report.md:43` | Workstream E ticket 20 | covered for cost/API-touching scope | Correctly bounded to cost help pages. |

## 7. Cost-API Synthesis Conformance Check

Note: the prompt says "12 indicative ticket clusters," but the current synthesis
Section 12 lists 17 numbered items. This table maps all 17.

| Synthesis Section 12 item | RFC anchor | v0.1.9.1 workstream | Status | Notes |
| --- | --- | --- | --- | --- |
| 1. `ledgr_cost_chain()` with two-stage validation | `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:495` | A2 | covered | Construction-time error class included at spec lines 328-331. |
| 2. `ledgr_cost_spread_bps()` quoted spread | `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:496` | A1 | covered | Semantics match RFC lines 369-376 and maintainer decision lines 23-24. |
| 3. `ledgr_cost_fixed_fee()` non-negative validation | `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:497` | A1 | partially covered | Constructor named; validation detail should be in tickets. |
| 4. `ledgr_cost_notional_bps_fee()` resolved-fill-price semantics | `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:498` | A1 | partially covered | Constructor named; resolved-price semantics should be explicit in tickets. |
| 5. `ledgr_cost_zero()` identity constructor | `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:499` | A1, B10 | covered | Explicit zero cost required because no null default. |
| 6. Cost canonical JSON and `cost_model_hash` | `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:500` | A4 | covered | Hash exclusions listed at spec lines 339-346. |
| 7. Compiled cost plan worker-safe value object | `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:501` | A4, A6 | covered | `cost_plan_json` and resolver plan named. |
| 8. `ledgr_timing_next_open()` and `timing_model` on `ledgr_experiment()` | `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:502` | A3, B8 | covered | Also decide `ledgr_backtest()` per Blocker 3. |
| 9. `fill_model` to `timing_model` rename across source/docs | `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:503` | B8 | covered | Public `ledgr_backtest()` path needs explicit cost decision. |
| 10. `commission_fixed` to `fee` migration | `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:504` | B7 | partially covered | Blocker 1: stale `R/fold-core.R` anchor. |
| 11. Legacy scalar shape handling | `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:505` | A3, B9 | covered | Aggressive reject matches horizon lines 1512-1531. |
| 12. `ledgr_run_open()` reopen compatibility | `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:506` | B9 | covered | Aggressive reject matches horizon lines 1558-1571. |
| 13. Run/provenance fields `cost_model_hash`, `cost_plan_json` | `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:507` | A4 | covered | Run config and promotion provenance named at spec lines 345-346. |
| 14. Existing proposal/resolver seam | `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:508` | A6 | covered | No fold-core control-flow change stated at spec lines 351-355. |
| 15. Inspection helpers | `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:509` | A5 | covered with citation fix | Helpers are in RFC Section 4.8, not 4.5. |
| 16. Documentation package | `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:510` through `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:515` | E19, E20, E21 | partially covered | Add timing/cost separation and non-scope disclosure per High 1. |
| 17. Tests | `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:516` through `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:523` | A/B implementation tickets | partially covered | Tests are implied in workstream text; tickets should spell them out. |

## 8. Section 13 Spec-Cut Decisions Audit

| Decision | Spec answer | Independent reading | Reason |
| --- | --- | --- | --- |
| 1. Legacy `fill_model = list(...)` shape | Reject with `ledgr_legacy_fill_model_shape` | confirm aggressive answer | Horizon binds rejection and rationale: split plus quoted-spread shift makes auto-translation a numeric footgun (`inst/design/horizon.md:1512` through `inst/design/horizon.md:1531`). |
| 2. Cost-plan execution shape | Implementer's choice with stable outputs and identity | confirm aggressive answer | The synthesis already defers resolver shape to implementation constraints; horizon gates identity stability and no per-pulse DB writes (`inst/design/horizon.md:1533` through `inst/design/horizon.md:1545`). |
| 3. Diagnostic retention | `meta_json` only | confirm aggressive answer | RFC v1 retention is scalar with optional component breakdown in `meta_json` (`inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:430` through `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:434`). |
| 4. Reopen legacy configs | Reject with `ledgr_legacy_config_shape` | confirm aggressive answer | Pre-CRAN posture supports no translation; horizon binds rejection (`inst/design/horizon.md:1558` through `inst/design/horizon.md:1571`). |
| 5. `cost_model = NULL` | Raise `ledgr_cost_model_unspecified`; require `ledgr_cost_zero()` | confirm aggressive answer | Cost identity is execution identity; hidden zero-cost defaults are a worse long-run contract than one extra explicit constructor. Horizon binds no silent defaults (`inst/design/horizon.md:1573` through `inst/design/horizon.md:1593`). |

## 9. Scope Envelope Assessment

The packet size is correct.

Reasons:

1. The v0.1.9.x arc intentionally makes v0.1.9.1 the cost-API dependency that
   walk-forward consumes later. Horizon records `cost_model_hash` and
   `cost_plan_json` as v0.1.9.1 outputs and says walk-forward must include
   `cost_model_hash` in `candidate_key` and `session_id`
   (`inst/design/horizon.md:1420` through `inst/design/horizon.md:1455`).
2. The cost synthesis records the same future obligation:
   walk-forward must extend `candidate_key` and `session_id` recipes to include
   `cost_model_hash`
   (`inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:346`
   through
   `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:355`,
   `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:556`
   through
   `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:560`).
3. THEME-004 is not optional polish. The auditr triage report classifies it as
   high severity with invariant mismatches and missing identity surfaces
   (`inst/design/ledgr_v0_1_9_1_spec_packet/ledgr_triage_report.md:52`
   through
   `inst/design/ledgr_v0_1_9_1_spec_packet/ledgr_triage_report.md:60`).
4. The disclaimer link break is the only other high-severity auditr item in the
   prompt's scope and is small enough to include without disturbing the cost
   packet (`inst/design/ledgr_v0_1_9_1_spec_packet/categorized_feedback.yml:1261`
   through
   `inst/design/ledgr_v0_1_9_1_spec_packet/categorized_feedback.yml:1268`).
5. The medium-severity docs are bounded by Section 3.5; only cost-touching or
   cheap tightly coupled fixes are in scope
   (`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:275` through
   `inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:291`).

Do not defer THEME-004 to v0.1.9.5+. Walk-forward identity needs a clean
foundation, and the v0.1.9.x arc was explicitly chosen to avoid retroactive
identity slots and schema churn before walk-forward
(`inst/design/horizon.md:1463` through `inst/design/horizon.md:1469`).

If the maintainer needs to shrink the packet, the only acceptable deferrals are
bounded documentation extras from Workstream E:

- defer THEME-002 entirely;
- keep THEME-003 to the cost non-participation paragraph only;
- defer non-high disclaimer discoverability rows FB-002 through FB-004;
- keep THEME-010 to cost help pages only.

Do not defer:

- public cost constructors and identity fields;
- quoted-spread rewrite;
- `fill_model`/`timing_model` migration decision;
- THEME-004 identity fixes and identity reference;
- installed disclaimer link fix.

## 10. Additional Conformance Notes

### Public surface conformance

The spec names all required v1 constructor and inspection surface items:
four primitives, chain, timing constructor, and inspection helpers
(`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:114` through
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:119`,
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:320` through
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:349`). This matches
the synthesis constructor catalog
(`inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:168`
through
`inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:184`)
and inspection helpers
(`inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:279`
through
`inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:284`).

The spec does not accidentally admit broker composites. The synthesis says only
`ledgr_cost_zero()` is a core convenience composite and broker-shaped
composites are not admitted in v1 core
(`inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:260`
through
`inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:277`).
The spec's non-goals exclude broker/exchange templates
(`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:516`).

### Quoted-spread conformance

Workstream A correctly binds quoted-spread semantics:
BUY `open * (1 + spread_bps / 20000)` and SELL
`open * (1 - spread_bps / 20000)`
(`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:320` through
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:326`). This matches
the synthesis
(`inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:367`
through
`inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:378`)
and maintainer decisions
(`inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_maintainer_decisions.md:13`
through
`inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_maintainer_decisions.md:25`).

### Cost identity conformance

The spec correctly names both identity fields:
`cost_model_hash` and `cost_plan_json`
(`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:121` through
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:124`,
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:339` through
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:346`). This matches
synthesis Section 6.1
(`inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:313`
through
`inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:320`).

The hash composition recipe and exclusions are also aligned with synthesis
Section 6.2
(`inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:322`
through
`inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:340`).
The spec explicitly excludes function addresses, environment serialization,
object print output, and package load order
(`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:339` through
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:345`).

The spec maintains orthogonality with `metric_context_hash` by not including it
in `cost_model_hash`, and by placing `metric_context_hash` in the identity
reference rather than the cost hash recipe. The synthesis binds this
orthogonality
(`inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:342`
through
`inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md:344`).

### Forward obligation propagation

The spec records the v0.1.9.4 walk-forward cost-identity obligation as a
non-work item in release goal 9
(`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:197` through
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:202`) and disclaims
walk-forward implementation in Section 3.3
(`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:259` through
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:265`). That is
sufficient. A separate cross-cycle-obligation section in the tickets file is
optional; horizon already records the durable obligation and the Section 17 row
to add at v0.1.9.4 packet-cut
(`inst/design/horizon.md:1604` through `inst/design/horizon.md:1672`).

If a tickets file is generated, I recommend a short non-ticket note at the top:

```text
Cross-cycle obligation: v0.1.9.4 walk-forward must consume
`cost_model_hash` in candidate_key and session_id per horizon 2026-06-05 and
cost-API synthesis Section 14:560. No v0.1.9.1 implementation work.
```

This is not required for ticket-cut; it is an audit-trail convenience.

### Repo standard conformance

The spec follows the v0.1.8.11 packet shape: header fields, Source Inputs,
Thesis, Release Goals, Binding Boundaries, Planned Workstreams, Non-Goals, and
Review Questions are all present
(`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:1` through
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:7`,
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:11`,
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:61`,
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:108`,
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:210`,
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:313`,
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:506`,
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md:535`).
The v0.1.8.11 template used the same section sequence
(`inst/design/ledgr_v0_1_8_11_spec_packet/v0_1_8_11_spec.md:1` through
`inst/design/ledgr_v0_1_8_11_spec_packet/v0_1_8_11_spec.md:36`,
`inst/design/ledgr_v0_1_8_11_spec_packet/v0_1_8_11_spec.md:100`,
`inst/design/ledgr_v0_1_8_11_spec_packet/v0_1_8_11_spec.md:119`,
`inst/design/ledgr_v0_1_8_11_spec_packet/v0_1_8_11_spec.md:157`,
`inst/design/ledgr_v0_1_8_11_spec_packet/v0_1_8_11_spec.md:305`,
`inst/design/ledgr_v0_1_8_11_spec_packet/v0_1_8_11_spec.md:364`,
`inst/design/ledgr_v0_1_8_11_spec_packet/v0_1_8_11_spec.md:384`).

### ASCII check

I ran a byte-level check on
`inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md`. Result:
`ASCII_OK`.

The RFC source files still contain existing mojibake around section signs and
arrows in rendered PowerShell output, for example synthesis lines 172, 184, and
503. That is outside this spec review's ASCII requirement. Do not block
v0.1.9.1 ticket-cut on pre-existing RFC mojibake unless the maintainer wants a
separate cleanup.

## 11. Concrete Pre-Ticket-Cut Patch List

Apply these edits before cutting tickets:

1. Workstream B ticket 7: replace `R/fold-core.R` with actual source anchors
   and name `R/backtest-runner.R`, `R/fill-model.R`, `R/sweep.R`, and
   `R/lot-accounting.R`.
2. Workstream A ticket 5: change "synthesis Section 4.5" to "synthesis
   Section 4.8".
3. Workstream C ticket 11 and Section 3.2: revise contaminant language to
   distinguish proven store-path sensitivity from optional explicit `run_id`
   sensitivity.
4. Workstream B ticket 8 or 10: explicitly bind `ledgr_backtest()` behavior
   for `timing_model` and required `cost_model`.
5. Thesis success condition: change "four medium-severity documentation
   themes" to "five medium-severity documentation themes scoped in Goal 8."
6. Workstream E ticket 19: add timing-vs-cost separation, price-transform-vs-fee
   separation, and cost non-scope disclosure.
7. Workstream E ticket 17 or Section 3.5: add or explicitly defer
   `ledgr_run_not_found` and `ledgr_unresolved_feature_id` documentation.
8. Workstream E ticket 19: require compiled-accounting docs to name stable
   top-level condition classes.
9. Ticket 16 or Section 3.5: explicitly defer disclaimer FB-002 through FB-004
   unless naturally solved by the chosen installed-disclaimer surface.
10. After maintainer decision, answer Review Question 10 in a review-resolution
    note: contracts.md in scope or deferred.

After these edits, I would change the verdict to `ready for ticket-cut`.
