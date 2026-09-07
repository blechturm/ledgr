# Stage 2 Witness Evidence Contract

**Status:** Witness v3 correction maintainer-approved and independently
reviewed on 2026-09-07.

**Witness schema:** `asset_availability_witness_v3`.

**Revision history:** `asset_availability_witness_v1` was approved on
2026-09-07. Version 2 was approved before prototype work after the first
freeze-gate run exposed that the checker restored R's original `HOME` before
its late Git ancestry checks. Version 2 keeps the approved witnesses and
expected answers unchanged and extends the existing safe-directory environment
through every Git check.

Version 3 is the maintainer-approved and independently reviewed correction
after Stage 3 review. It changes two affected witnesses without changing
policy v4:

- W02 `c0a` records the real package coverage-error class,
  `LEDGR_SNAPSHOT_COVERAGE_ERROR`, instead of the incorrect
  `ledgr_missing_bars` label. W02 `c0b` must be observed through the real
  package fold rather than accepted from arithmetic alone.
- W22 records execution-bar availability, fill price, and fill status in the
  unmutated `c0` and `c1` cases. Its S3 execution open is 52 while the stale
  valuation mark is 50, making M1 an in-schema mutation that the checker can
  distinguish from valid execution.

The prior approved v2 evidence remains available at commit `b818d76`. The
v3 correction must be committed and recorded as the active Stage 2 evidence
commit before the Stage 3 gate can close.

**Charter base:** package commit `1f42cf7`.

## Purpose

This document defines how W01-W31 become independent reference evidence. The
shared fold fork and representation providers are implementations under test;
they must not generate or silently revise their own expected answers.

## Required Fixture Packet

Each witness gets a directory under `fixtures/` containing a manifest and the
smallest deterministic input tables needed by the case. Its manifest records:

- witness ID, case ID, and witness class;
- stable asset IDs and aliases;
- investment, estimation, and held-position domains;
- bars and other source observations;
- membership, lifetime, calendar, status, and revision facts;
- effective, knowledge, acquisition, and revision times where applicable;
- opening cash, quantities, lots, and carried state;
- strategy outputs and risk, cost, valuation, and execution policies;
- fit population, cutoff, label maturity, graph, and RNG identity where used;
- expected identity-equal and identity-change sets; and
- source notes and any bounded synthetic assumptions.

Inputs use UTC ISO-8601 timestamps and stable asset IDs. Row order is explicit.
Missing facts remain missing; fixtures must not create executable values by
forward filling, imputation, or valuation fallback.

Every manifest is self-contained. A case that expects a fill states its own
effective active-status assertion with source, precedence, effective
interval, and knowledge time; no manifest inherits facts from another.

Two boundary cases are mandatory:

- W02 includes a case where accepted same-pulse sale proceeds exactly fund a
  purchase. The expected table applies the policy `cash_tolerance`, proves the
  virtual and event-order final balances reconcile, and distinguishes any
  permitted intermediate negative cash from the completed-pulse balance.
- W22 includes a new positive target for an unheld instrument without a
  permissible risk mark. A mark-dependent risk step fails with
  `risk_mark_unavailable` before fill proposal or state mutation.

## Required Expected Table

Each witness gets one long table under `expected/` with these columns:

| Column | Meaning |
| --- | --- |
| `witness_id` | W01-W31 |
| `case_id` | Stable case within the witness |
| `step` | Ordered decision, risk, execution, accounting, or audit step |
| `event_time` | Event time or blank when not temporal |
| `asset_id` | Stable asset ID or blank for portfolio-level evidence |
| `field` | Exact field being asserted |
| `expected_type` | Logical, integer, double, character, timestamp, or absent |
| `expected_value` | Canonical expected scalar representation |
| `reason_code` | Typed reason or blank when not applicable |
| `identity_expectation` | Equal, changed, captured, absent, or not_applicable |
| `comparison` | `exact` for non-double values or `abs_tol` for doubles |
| `tolerance` | Non-negative absolute tolerance for doubles; blank otherwise |
| `derivation` | Short independent arithmetic or temporal justification |
| `identity_name` | Exact identity compared; blank for non-identity rows |
| `reference` | Comparison endpoint for `equal` or `changed`; blank otherwise |

Additional case-specific tables are allowed, but this long table is the
minimum checker input and cannot be replaced by prose.

Logical values use lowercase `true` or `false`. Integers are canonical
base-10 strings with no leading zeros and no negative zero. Timestamps are
calendar-valid UTC ISO-8601 strings of the form `YYYY-MM-DDTHH:MM:SSZ`.
Absent values use an empty `expected_value`. Double values use a canonical
decimal expectation and an explicit per-row absolute tolerance. There is no
implicit global numeric tolerance.

### Identity Rows

- `identity_expectation` is one of `equal`, `changed`, `captured`, `absent`,
  or `not_applicable`. Rows with `equal`, `changed`, `captured`, or `absent`
  are identity rows; they use `expected_type` `absent` with an empty value
  and a non-empty `identity_name`.
- A `captured` row declares a baseline: the identity observed at that row
  becomes the endpoint other rows compare against. It has no `reference`.
- An `equal` or `changed` row names its endpoint in `reference`, either
  `case:<case_id>@<step>` (a `captured` row of the same `identity_name` in
  the same table) or `source:<name>` (an external endpoint; the only
  declared source is `package_fold`, the package run of the same fixture
  under the same package version).
- An `absent` identity row states that no artifact exists; it has no
  `reference`.
- `identity_name` is an exact ledgr identity (`snapshot_hash`,
  `config_hash`, `feature_cache_key`, `risk_chain_hash`, `cost_model_hash`,
  `feature_set_hash`, `candidate_key`, `session_id`, `panel_hash`) or a
  prototype-declared identity prefixed `proto:`. Prototype identities are
  not ledgr fields; the fork declares their exact canonical payloads in its
  report, and the payloads must include at least:
  - `proto:provider_id`: provider implementation name and version, the
    sealed `snapshot_hash`, the approved policy ID, the witness
    specification version, the declared calendar identity, and the
    axis-ordering rule;
  - `proto:prototype_id`: the fork commit, `proto:provider_id`,
    `risk_chain_hash`, `cost_model_hash`, and the approved policy ID;
  - `proto:fitted_artifact_id`: recipe, hyperparameters, fit population
    identity, information cutoff, label-maturity rule, RNG identity, and
    the fitted numeric state;
  - `proto:graph_id`, `proto:raw_series_id`, `proto:feature_node_id`: the
    complete typed dependency identity of the node, including calendar,
    classification policy, and admissible-history rule;
  - `proto:dataset_id` and `proto:valuation_evidence_id`: the sealed facts
    and policy identities they summarise.
- Identity equality is additional to value assertions and never replaces
  them. Value stability and identity stability are separate assertions: a
  value that must stay equal under a perturbation is a value row; an
  identity that must change because a hashed input changed is an identity
  row.

The gate validates these representations before hashing.

## Freeze Protocol

1. The executor writes fixture manifests without running prototype output.
2. Expected tables are calculated independently by hand or by a tiny reference
   calculation that does not call the shared fork or a representation provider.
3. The maintainer approves the policy and expected outcomes.
4. A non-executing reviewer checks temporal reasoning, arithmetic, and table
   completeness.
5. Approved files receive immutable content hashes in
   `evidence/frozen_hashes.csv`.
6. Registry status changes to `approved` only after both approvals.
7. Commit the approved freeze targets and record that full commit in the
   evidence manifest.
8. Record the exact, sorted SHA-256 freeze set in
   `evidence/frozen_hashes.csv`.
9. `check_stage2.R --mode=gate` must pass before fold-fork code begins.

`check_stage2.R --mode=setup` validates every drafted or approved packet
that is present; `--mode=review` additionally requires all 31 packets and is
the pre-approval structural check. Neither mode approves anything.

Frozen inputs are UTF-8 or ASCII text. SHA-256 is computed after normalizing
CRLF and bare CR endings to LF, while preserving all other bytes and the final
newline. Paths are sorted bytewise with radix ordering. Any hash generator and
the gate checker must apply those same rules so checkout line endings cannot
change the freeze identity.

The clean-workspace guard intentionally rejects an in-place line-ending
rewrite even when normalized content would hash identically. Make such changes
through a reviewed commit before recording the Stage 2 evidence commit.

If an expected answer changes later, preserve the prior file or commit, record
the rationale and approver, increment the witness-specification version, and
rerun every affected provider. Observed output never replaces an expected
answer without this process.

## Checker Mutation Gate

Before provider conformance is trusted, the checker must reject the
deliberate mutations `M1` to `M5` defined in
`evidence/checker_mutations/README.md`:

- pass a stale valuation mark as an execution price;
- leave a superseded halt active;
- omit a carried holding;
- omit a required transform or cache dependency; and
- drop a virtually credited sale from the final accepted fill set.

The definitions file is a frozen Stage 2 input with role
`mutation_definitions`. The mutations test the checker, not a second
execution implementation.

Mutation executables are Stage 3 code. They apply a mutation to prototype
output, and no prototype output exists before the gate opens, so they cannot
be registered in the frozen `evidence/preprototype_code.csv`. After the
gate-record commit, Stage 3 creates `evidence/stage3_code.csv` with columns
`path`, `role`, and `first_appearance_commit`; every mutation executable and
every fork or provider file is registered there. The later-stage checker
verifies that each first-appearance commit descends from the recorded Stage
2 gate-record commit, that the registered mutation executables implement
exactly `M1` to `M5` as frozen, and that the registry is only ever appended.
A pure definition script written before the gate may still be registered in
`preprototype_code.csv` under the `checker_mutation` role, but none is
required.

Any other executable file under this workspace before the gate closes it.
The extension and filename scan is a tripwire for common executable or
code-bearing files, including R, SQL, shell, command, profile, Makefile, and
text-script forms. It is not a content classifier. The frozen commit, clean
workspace requirement, exact hash set, and independent reviewer diff remain
the guarantees against disguised prototype code.

## Stage 2 Completion

Stage 2 is complete only when W01-W31 are approved in the registry, every
referenced fixture and expected table exists, the policy status is maintainer
approved, every frozen hash verifies, the freeze commit is recorded, no
prototype code exists, and the gate script exits successfully.

## Stage 2 Authoring Clarifications (2026-09-07, approved packet)

Recorded by the executor while drafting W01-W31 and revised after two
independent reviews. Items 7 and 12 are policy decisions bound by the approved
v4 policy in `initial_policy_config.md`. The remaining items make the packet
mechanically reviewable and change neither the approved policy nor the
charter.

1. Source tables are embedded in each `fixtures/Wxx/manifest.md` as Markdown
   tables so the hashed manifest is the complete fixture. Separate CSV copies
   are optional derived files and must match the manifest.
2. Identity rows follow the Identity Rows section above: `captured`
   baselines, `case:<case_id>@<step>` or `source:<name>` references, exact
   `identity_name` values, and declared `proto:` payload minimums. Value
   stability is asserted by value rows.
3. `step` is a 1-based integer ordinal within a case. `event_time` is the
   decision pulse close or the execution open the row describes, or blank
   for run-level facts.
4. Target-vector order is the declared member order followed by held
   non-members in stable-ID order; feasibility order is stable-ID order.
   Lists of stable IDs are joined with `|`; an empty list is an `absent` row.
5. Tolerances: cash, prices, exposures, and equity use `1e-8`; fitted means,
   feature values, and returns use `1e-9`; the `cash_tolerance` constant
   itself is asserted with `1e-12`.
6. Case identifiers: `c0`, `c0a`, `c0b` are current-package or dense
   controls; `c1`, `c2`, and so on are policy cases; W19 uses candidate
   names; W20 uses `<fixture>_<scope>_<path>`; W25 uses graph and mutation
   names.
7. Decision-time restriction: policy decision bound by the approved v4 policy
   in `initial_policy_config.md`. The packet applies it in W09 `c1` and W31 S2.
8. Reason codes used in the packet: `trading_halted`, `quotation_only`,
   `status_unknown`, `status_unknown_or_conflicting`,
   `execution_bar_missing`, `insufficient_cash`, `target_restricted`,
   `nonmember_exposure_increase`, `max_weight_reduction`,
   `max_weight_pass_through`, `stale_mark_reduction`,
   `stale_mark_pass_through`, `long_only_clamp`, `risk_mark_unavailable`,
   `valuation_horizon_exhausted`, `terminal_settlement_unsupported`,
   `artifact_not_available_at_decision`, `estimation_population_non_causal`,
   `stale_axis_token`, `missing_value_scalar_guard`,
   `model_native_missing_handling`, `incomplete_evidence`,
   `LEDGR_SNAPSHOT_COVERAGE_ERROR`, and `LEDGR_LAST_BAR_NO_FILL`. Codes the
   policy does not define are proposals for the Seed v2 vocabulary.
9. Observation-state values used: `accepted`, `expected_session_absence`,
   `scheduled_closure`, `observed_row_outside_expectation`,
   `instrument_not_yet_knowable`, and `observation_invalid`.
10. The reconciliation failure `affordability_reconciliation_failed` is not
    derivable from valid inputs; it is defined as checker mutation `M5` in
    `evidence/checker_mutations/README.md`.
11. `references/budget_arithmetic.R` and `references/series_and_clock.R`
    are registered as `reference_calculation`. They print the arithmetic
    behind the tables and call no ledgr, fork, or provider code.
12. Ordered no-fill reason contract and the affordability precision: policy
    decisions bound by the approved v4 policy in `initial_policy_config.md`.
    W31 at the S3 open applies the ordered contract.
13. Virtual-ledger rows: `trial_virtual_cash_after` is the balance a
    cash-consuming fill would leave and is recorded for every evaluated
    fill; `virtual_cash_after` is the committed virtual balance after the
    accept-or-reject decision and is unchanged by a rejected fill.
14. W21 asserts realized P&L under the package rule that every fill's fee
    reduces realized P&L (`R/lot-accounting.R`), lot basis equal to the fill
    price, and unrealized P&L as mark minus basis on open lots.
15. W20 asserts the identical evidence bundle on every provider path and the
    identical outcome bundle on every full-fork task; `proto:provider_id`
    and `proto:prototype_id` equality is additional to those values.
