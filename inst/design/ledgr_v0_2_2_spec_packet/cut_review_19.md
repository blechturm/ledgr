# Cut 19 review: pre-CRAN research-strategy API cleanup

**Mode:** independent clean-context Type 1 cut review with adversarial design
and public-API input checks.

**Baseline:** Cut 18 tree `8e9af1c8`, with the uncommitted Cut 19 draft in
`macro_plan.md` and `tickets.yml`.

**Verdict:** `NEEDS_TYPE_2`

The cleanup is necessary. Public probes confirmed that the direct history
matrix, history-aware warmup predicate, rectangular sweep input, intent reason
and readable sweep parameters are missing. The existing public APIs already
supply history identity, aligned weights, structural history information,
save/reopen/promotion and Date pulse inspection, so the cut correctly reuses
those surfaces and allocates no Date-inspection ticket. Two remaining product
choices cannot be settled from the accepted Cut 19 decisions: dense-run intent
explanation, and the supported/persisted type domain of rectangular grids.

## Findings

1. **High, Type 2 — the single pulse-scoped intent row has no defined dense
   `ledgr_run_explain()` meaning.**

   **Where:** `tickets.yml:296-297`, LDG-3101 at `tickets.yml:2642-2650`;
   `contracts.md:2297-2313`; `R/db-schema-current.R:313-324`;
   `R/availability-results.R:46-70,700-727`; `R/fold-engine.R:795-817`.

   **Evidence/failure:** a public dense run returning
   `list(targets = ..., state_update = ...)` produced the typed zero-row
   diagnostics table and `ledgr_run_explain(bt, "AAA")` produced zero rows.
   This matches the current contract: durable diagnostics are the
   availability-aware trace and dense runs return its zero-row schema. In the
   availability path, explain first filters diagnostics by a non-empty
   `instrument_id` and then requires a per-instrument decision row. The table's
   `instrument_id` is `NOT NULL`, although the existing columnar writer uses
   `""` for pulse-scoped reconciliation rows. A single `instrument_id = ""`
   intent row can therefore be stored without a schema bump, but it cannot by
   itself make the current instrument-scoped dense explanation exist. Adding
   per-instrument decision rows would violate the one-row promise and materially
   change dense diagnostic cost; synthesizing the rest of an explanation would
   change the current result contract.

   **Decision needed:** choose one of these semantics before WS56 starts:

   - narrow durable `intent_reason` and its `ledgr_run_explain()` field to
     availability-aware committed runs, while dense strategies accept the
     field without promising a durable explanation; or
   - extend the dense result contract and specify exactly what
     `ledgr_run_explain(bt, instrument_id, ts_utc)` returns when its only new
     evidence is one pulse row, which other fields are typed missing, and the
     dense writer/performance obligation.

   After that decision, LDG-3101 must pin the physical row and join: one row
   with `instrument_id = ""`, fixed stage/outcome/reason code, and exactly one
   named `detail_json` key, joined by run and decision pulse rather than by
   instrument. It must also replace “before risk or store writes for that
   pulse” with “before risk or economic/pulse commit; the existing
   post-rollback `fold_exception` record remains the sole failure diagnostic”,
   unless suppressing that existing error evidence is separately chosen.
   Omission writing no intent row and yielding `NA_character_` is otherwise
   sound. The LFB-028 exclusion is explicit and must remain.

2. **High, Type 2 — rectangular-grid type preservation is incompatible with
   the current saved-sweep representation unless the supported type domain is
   narrowed.**

   **Where:** Cut decision (8) and (12) at `tickets.yml:297`; LDG-3102 at
   `tickets.yml:2652-2660`; `R/param-grid.R:127-160,207-257`;
   `R/sweep-persistence-schema.R:1-16,125-138`.

   **Evidence/failure:** an ordinary data frame is currently refused by
   `ledgr_sweep()` (`R/sweep.R:173-175`), establishing the real gap. A public
   `ledgr_strategy_grid()` containing a factor and a Date preserved those
   classes during the live sweep, but after `ledgr_sweep_save()` and
   `ledgr_sweep_open()` both values were character. Promotion from that reopened
   artifact would therefore pass different R types to the strategy. The current
   JSON is `{"group":"a","when":"2020-01-02"}` and carries no class tag.
   Also, the promised “corresponding `ledgr_strategy_grid()` candidate” does not
   exist for a list column: the current helper rejects every list-valued grid
   column. “JSON-safe scalar list column” and “non-scalar list column” are not
   defined; a tibble cell may be an atomic scalar, an atomic vector, or a named
   JSON object.

   **Decision needed:** bind the value domain before implementation:

   - either support only unclassed JSON scalar columns (integer, double,
     logical and character), define an accepted list-column cell precisely,
     and explicitly refuse factor, Date and other S3 columns before execution;
   - or preserve factor/Date and any accepted list-cell types through
     save/reopen/promotion with a tagged canonical representation and the
     stored-format version change required by `AGENTS.md`, amending decision
     (12)'s “no schema change”.

   The same decision must state the exact zero shapes. The rules “one candidate
   per row” and “duplicates refuse” imply that a one-row/zero-column frame is
   the empty-parameter candidate, a zero-row frame refuses, and two zero-column
   rows are duplicate candidates; if that is not intended, the maintainer must
   choose the alternative. Primitive data-frame rows can otherwise preserve
   order and canonical identity without a compatibility parser.

3. **Medium, Type 1 — equivalence to the current direct strategy grid can
   preserve a namespace leak that the workstream claims to remove.**

   **Where:** LDG-3102 acceptance 1, 3 and 5 at `tickets.yml:2658-2660`;
   `R/param-grid.R:374-384`; `R/sweep.R:1209-1214`.

   **Evidence/failure:** a direct `ledgr_strategy_grid(qty = c(0, 1))` sweep
   currently stores `qty` in both `params` and `feature_params`; its promotion
   context consequently contained `params_json = {"qty":0.0}` and
   `feature_params_json = {"qty":0.0}`. The helper
   `ledgr_grid_candidate_feature_params()` returns the whole plain candidate
   list when no explicit namespace envelope exists. Thus “equal the
   corresponding strategy-grid candidate” can make a new data-frame strategy
   grid feed strategy parameters to feature resolution, contrary to the cut's
   separate-namespace claim.

   **Exact patch:** add to LDG-3102 acceptance:
   “A direct rectangular grid and a direct `ledgr_strategy_grid()` are strategy
   namespace inputs: their result rows and promotion contexts have the row in
   `params` and exactly `list()` in `feature_params`; a parameterized feature
   map never receives those columns. Only `ledgr_grid_cross()` supplies a
   non-empty feature namespace. A mutation restoring the current plain-list
   feature fallback fails.”

4. **Medium, Type 1 — `min_observations` needs a failure-sensitive definition
   of a finite usable cell, especially for output carry.**

   **Where:** Cut decision (3) at `tickets.yml:297`; LDG-3100 acceptance 1-3
   at `tickets.yml:2632-2640`; `R/history-treatment.R:500-566` and
   `R/history-frame.R:381`.

   **Evidence/failure:** the current admission helper counts
   `calculation_valid`. A feature cell carried by output policy has a finite
   returned value but deliberately has `calculation_valid = FALSE` and
   `output_carried = TRUE`. Reusing that helper can therefore satisfy the
   generic “carried cells” test while contradicting “finite usable cells”.

   **Exact patch:** add to LDG-3100 acceptance:
   “`finite_observation_count` is the count of finite values in the returned,
   policy-treated value plane. A finite bar input carry and a finite feature
   output carry count; warmup, structural/inactive, expired carry, ordinary
   missing and non-finite calculated cells do not. The default finite
   requirement is the requested lookback even when fewer sessions are
   available; the `Inf` default is the common returned-axis row count. The
   registered truth table independently covers input carry and output carry.”
   This is the smallest specification that makes the accepted rule executable
   without restoring `na_action` or a second sufficiency predicate.

5. **Medium, Type 1 — matrix parity does not explicitly cover the existing
   long adapter or both empty dimensions after the adapter becomes classed.**

   **Where:** LDG-3099 acceptance 1-2 at `tickets.yml:2622-2630`; current
   adapter at `R/history-frame.R:1019-1040`.

   **Evidence/failure:** current public probes show wide and long adapters are
   numerically identical, with valid `0 x N` and `N x 0` matrices. Those are
   native guarantees worth retaining, but LDG-3099's new identity comparison
   names only “the corresponding frame”, and its estimator witness is
   non-empty. Base R also preserves custom attributes under arithmetic while
   dropping them under ordinary subsetting; the ticket correctly requires a
   transformed matrix to refuse, so that part is already adequate.

   **Exact patch:** append to LDG-3099 acceptance 1:
   “The wide-frame adapter, long-frame adapter and direct matrix have the same
   values, dimnames and history identity, including `0 x N` and `N x 0`
   results; no adapter retains the source frame. Registered checks cover a
   value transformation (whose base operation otherwise preserves custom
   attributes) and row/column subsetting.”

6. **Medium, Type 1 — WS58's private-evidence claim conflicts with its ticket's
   optional narrowing.**

   **Where:** Workstream 58 claim at `tickets.yml:801-807`; cut closeout at
   `tickets.yml:301`; LDG-3104 acceptance 6 at `tickets.yml:2678-2680`;
   `macro_plan.md:1135-1142`.

   **Failure:** the workstream claim and cut closeout require the current
   private estimator rerun after the strategy source changes, while the ticket
   may instead narrow the release claim. Either outcome could currently be
   called acceptance, so the claim has no single failing oracle.

   **Exact patch:** because the cut closeout is the more specific accepted
   boundary, replace LDG-3104 acceptance 6 with:
   “The public synthetic proof and the current registered private Sharadar
   estimator arm are rerun at the final source hash; neither the Cut 17 hash
   nor its estimator result is carried forward by assertion.” If narrowing is
   intended to remain an allowed outcome, that is a maintainer decision and
   the Workstream 58 claim plus cut closeout must be narrowed together.

7. **Low, Type 1 — one cited design-input path is wrong.**

   **Where:** `tickets.yml:295`.

   **Evidence/failure:** the cited
   `inst/design/research_strategy_ux_brief.md` does not exist; the actual input
   is
   `inst/design/ledgr_v0_2_2_spec_packet/research_strategy_ux_brief.md`.

   **Exact patch:** replace that one path. No authority changes.

## Per-ticket coverage

| Ticket | Review coverage | Disposition |
| --- | --- | --- |
| LDG-3099 | Direct/adapter matrix shape, identity, transforms, estimator compatibility, memory boundary | Covered after finding 5's long/empty parity patch |
| LDG-3100 | Required lookback, `Inf`/zero, finite counts, carry, late listings, all-missing columns, panel readiness, removal of overlapping APIs | Covered after finding 4's exact usable-cell rule |
| LDG-3101 | Structured result validation, one pulse row, NOT NULL instrument ID, dense/availability writers, rollback/resume, explain/reopen, LFB-028 | `NEEDS_TYPE_2` under finding 1 |
| LDG-3102 | Rectangular shapes, types/list cells, duplicates/order/identity, namespaces, save/reopen/promotion, constructor removal | `NEEDS_TYPE_2` under finding 2; also patch finding 3 |
| LDG-3103 | Parameter visibility, deterministic abbreviation, namespace display, non-mutating live/reopened/review print | Covered; acceptance is failure-sensitive |
| LDG-3104 | Anti-pattern removal, accepted economics, scheduling/helper disclosures, intent reopen, source-sensitive evidence and final verification | Covered after finding 6; the close screen followed by one return read preserves the accepted carry-threshold economics without needing a new narrowing API |

## Areas found clean

- A classed double matrix remains an ordinary R matrix: base indexing,
  `stats::cov()` and `quadprog::solve.QP()` accepted the probe object. The
  existing transformed-object refusal and shared-reader/performance detectors
  are the right safeguards.
- Consolidating `na_action` and `ledgr_history_sufficient()` into recorded
  sample/panel requirements is a real simplification. `ledgr_history_info()`
  still exposes the axis and selection evidence for inspection, and fallback
  remains explicit strategy code.
- Omitted intent writing no extra row and explaining as `NA_character_` is the
  right sparse behavior; the ticket explicitly does not claim to solve
  LFB-028's factor/rank/selection/weight evidence gap.
- Readable sweep printing can be tested without changing stored bytes,
  candidate order or hashes; the existing result already retains both
  parameter namespaces.
- The article correctly leaves monthly scheduling and portable helper bundles
  disclosed and out of scope. A close-history carry screen followed by one
  direct return-matrix read with `min_observations` preserves the accepted
  estimator economics and removes the second return read.
- YAML parses with 182 unique ticket IDs and no missing dependencies. Cut 19's
  prose sequencing and ticket dependencies cover all three prerequisites of
  WS58. The already-landed Date pulse inspection correctly has no ticket.
