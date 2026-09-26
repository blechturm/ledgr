# RFC Seed v2: Point-in-Time Historical Projection For Multivariate And Fitted Methods

**Status:** Revised architectural proposal; provisional until the maintainer
accepts the framing of the review-author-drafted brief. No API, implementation,
spec packet, release scope, or comparative spike is authorized.
**Date / author:** 2026-09-26 / ChatGPT, returning as Seed v1 author under
[role rotation](../rfc_cycle.md). A different author owns response and synthesis.
**Design baseline D:** `v0.2.0.2`, `491c4ed11a861c7d42ecd2f249020a738634d4cd`.
**Implementation baseline I:** `origin/codex/ws16-v0.2.1.0`,
`ae040e762e082dd9f347ae7bc1c1aa13be9fc6ce`. Code/contract citations mean I.
The release is planned as v0.2.1.0; I's DESCRIPTION still says 0.2.0.2.
**Window:** later v0.2.x; this seed does not add work to the current release.

This supersedes [Seed v1](rfc_point_in_time_historical_projection_v0_2_x_seed.md)
as a proposal; v1 and its [review](rfc_point_in_time_historical_projection_v0_2_x_seed_review.md) remain historical.
"First implementation" below means this capability, not ledgr v1.0.0.

Authority remains [contracts.md](../contracts.md), the accepted projection
[synthesis](rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md)
Directions 5.1–5.5, the accepted availability
[synthesis](rfc_asset_availability_point_in_time_universes_v0_1_9_8_synthesis.md),
and the strategy-context
[synthesis](rfc_strategy_context_surface_v0_2_x_synthesis.md) sections 3–8.
I's `tickets.yml:130` and packet `README.md:694-715` record acceptance of the
context synthesis at `d9daa4d`, including its amendment, and the maintainer's
override placing Cut 13 before the tag. Its stale draft header does not undo that
record. Cut 13 is pending at I; its proposed names are not yet shipped behavior.
D and I must converge before that cut opens. This seed neither merges them nor
silently applies pending contract amendments. The
[spike protocol](../spike_protocol.md) governs every probe and charter, and the
[optimization manual](../manual/optimization_coding_style.qmd) remains applicable.

## 1. Architectural intent

Covariance, clustering, representative selection, PCA and later fitted methods
need causal multivariate inputs. R already supplies the estimators. ledgr should
supply a bounded historical view of its existing sealed, point-in-time world.
It must not create another execution path, another market-history authority,
or independently assembled histories for portfolio and ML consumers.

Statistical missing-data policy stays outside the engine: no implicit complete-case
deletion, pairwise estimation, shrinkage, imputation, scaling, minimum-history
screen, clusterer or optimizer. Numeric absence and source evidence are
engine concerns; deciding what an estimator does with them is research policy.
Causally re-estimated transforms and frozen-on-train transforms remain distinct
by fitting regime, not algorithm name. The latter belong to the model recipe.

## 2. Reproduction: both load-bearing findings are correct

The [runner and findings](../../../dev/spikes/historical-projection/probe_findings.md)
record execution at I: sourced production functions run the real fold and memory
output handler, using ordinary and strict feature computation respectively.
This is not a public `ledgr_run()` or sealed-ingestion test.

| At pulse 1, three instruments and twelve prepared pulses | Dense | Availability |
| --- | --- | --- |
| `ctx$.feature_projection$feature_values$sma_3` shape | 3 x 12 | 3 x 12 |
| Public current feature values | all NA | all NA |
| Direct column 12 read | 111, 211, 311 | 111, 211, 311 |
| Fold with projection removed | classed rejection | classed rejection |

Both folds complete twelve callbacks; the future-reading strategy passes preflight
as Tier 1. The CSV rerun and raw-attachment gut reproduce/detect the evidence;
the gut is a detector demonstration, not a repair proposal.

The backing is instruments by the **entire prepared horizon**, one numeric
matrix per selected feature (`R/runtime-projection.R:1-54`;
`R/backtest-runner.R:991-1011`). It is mandatory through execution-spec validation
(`R/execution-spec.R:258-261`) and the fold (`R/fold-engine.R:250-253`). Dense
fast-context selection does not control its existence: both callback branches
attach it (`R/fold-engine.R:615-648`; `R/pulse-context.R:286-306,427-432`).
The ordinary public accessors read the current column; the raw field bypasses
that restriction. "Unbounded future" here means all later prepared columns,
not access to arbitrary dates outside the prepared run.

This is an existing decision-context contract defect. `contracts.md:113-116,736-742` does not exempt
dot-prefixed context fields. Static preflight is not an access-control boundary.
It does not follow that ordinary documented feature reads are forward-looking.

## 3. Disposition of the review

| Finding | Seed-author disposition |
| --- | --- |
| F1: prepared backing in both modes | Accept the executed fact and remove the old plumbing question. Reject an inference from rectangular storage to completed historical semantics. |
| F2: future reachable through context | Accept; strengthen its classification to an existing contract defect. Copy-versus-view alone is insufficient while the source remains reachable. |
| F3: materialization and performance | Accept the inherited full-wide memory cost. Reject the literal claim that v1 forbids what the engine does: v1 forbids redundant full-panel **long** materialization, consistently with accepted Direction 5.1. Wide and long are different costs. |
| F4: stale public-surface baseline | Accept. Inherit accepted Cut 13 rules and its recorded scheduling override; do not describe its pending implementation as present at I. |
| F5: axis vocabulary | Accept Daxis versus M. Qualify: that settles the current axis, not historical sampling populations or which knowledge cutoff applies to old facts. |
| F6: prior-art contribution | Accept its mainly confirmatory role. Reject calling fit/rebalance separation new to ledgr: v1 already cited the June 9 horizon direction. The research is neither an executed ledgr result nor authority for a new engine or policy. |
| F7: false binary | Accept the criticism. Reuse is the starting direction; a missing semantic index does not justify a new projector. |

The [prior-art pass](../research/ML_historical_data_prior_art.md) is research input,
not execution evidence or a charter. Its portfolioBacktest text does not consistently
support v1's cadence claim; use ledgr's existing horizon direction. No competitor
performance, causality or exact API claim binds this seed; no new survey is needed.

## 4. One owner, bounded consumers

Reuse the existing runtime numerical projection and the production availability
semantics. Add a prepared semantic index only where executed evidence shows one
is missing. Do not repeat feature computation or independently resolve facts in
an estimator adapter. A lower shared owner is a contingency requiring a concrete
failure of reuse, never a precautionary alternative of equal standing.

Sharing semantic ownership does not require giving every consumer the same R
object or permissions. Strategy access is pulse-bounded. Later offline training
export may traverse an explicitly selected historical range through the same
value/semantic rules; it must preserve each row's causal cutoff. It is not a
strategy capability to retrieve the remaining full run. Forward labels, embargo,
model storage, fitted preprocessing and refit-artifact identity stay in the ML
cycle. History supports repeated/expanding fitting and sparse requests, without
forcing estimator work every pulse or equating fit and rebalance cadence.

## 5. Preserve Direction 5.4; extend its disclosure deliberately

Propose preserving the accepted single-feature `ctx$window(feature, lookback)`
direction: numeric `length(Daxis) x lookback`, rows in `ctx$universe` order,
oldest-to-current columns, leading `NA_real_` for unavailable early columns,
and feature `stable_after` semantics unchanged. No list-valued replacement or
multi-feature tensor. Proposed column clock: consecutive prepared **decision
pulses**, ending at the invoking pulse; never the last L nonmissing observations
per asset. In availability mode these are declared session closes. Pre-range
history is not silently fetched to replace the predecessor's leading padding.

This matrix read must join the context synthesis's reference table and actual
dense/availability surface comparison, documenting axes, units, cutoff, padding,
missingness and ownership; it is not a scalar or unnamed `ctx$vec` plane. Preserve
current scalar/plane/bundle parity. Semantic evidence must have an aligned bounded
companion surface; its spelling and physical encoding remain response questions.
Do not encode semantic flags in numeric NA. A different return shape requires
explicitly superseding Direction 5.4 in synthesis before implementation.

## 6. Proposed historical meaning, distinct from allocation policy

Inherit **Daxis = ctx$universe = ctx$vec$id** and **M = current investment members**
from the context synthesis section 3. Dense M equals Daxis; active Daxis may
include held nonmembers. Window rows use current Daxis, including held nonmembers;
allocation constructors default to M. A matrix is not an eligibility screen.
The zero-axis result is 0 x L. Fixed baskets retain their declared meaning.
Former members absent from current Daxis and an ever-member population belong
to a later explicit export/domain contract, not implicit row discovery here.

Propose **original-cutoff** columns: at historical pulse s <= current t, value
and fact evidence mean what was effective and knowable at s. Do not recompute
membership at t and broadcast it backward, or revise old columns using later
knowledge. A retrospective "history as known today" mode is a different contract
and is excluded from the first implementation. This proposal follows the
Availability Contract's non-retroactivity rule (`contracts.md:346-358`).

Membership and observation remain independent: an observed pre-membership value
is not automatically deleted; nonmembership alone does not imply absent history.
Expose source membership, expected-session/observation evidence and feature
availability without silently selecting a statistical sample. Distinguish leading
padding, incomplete feature warmup and observation gaps when evidence supports
that distinction; never infer a reason merely from NA or invent a second warmup
rule (`R/features-engine.R:286-343`; projection synthesis Direction 5.4).
Existing declared/omitted/assumption-backed fact-family meaning must survive.

A stale risk mark is not an observed close or feature input (`contracts.md:401-405`).
Market-cell metadata cannot replay historical `held`, `priced`, `mark_age` or
`tradable()` state. Exclude that promise from the first history contract; a valuation
view would require explicit policy/state inputs. Never backfill features with risk
marks or invent new durable availability reason tokens for this API.

## 7. The access boundary is part of the architecture

Propose a detached numeric result: callers may mutate their matrix without
changing engine storage, another consumer, or a later result. It has value
semantics, not a claim that base R matrices reject writes. A retained result
keeps its original axis and cutoff when the fold advances. Bound allocation to
the requested slice, not a copy of the full future-bearing projection per pulse.

The full projection remains engine-owned, and must no longer be a directly
indexable member of the strategy context. A replacement accessor must reject
requests beyond its captured cutoff and outside its permitted axis. Removing
one field while retaining another raw alias is insufficient; inspect attachments
reachable from the callback and accessor closure captures together
(`R/runtime-projection.R:364-465`). The response must state the
enforcement boundary, including R reflection; a renamed field or closure is not
a sandbox against hostile code recovering internal process state.

Do not fix exposure by breaking inspection. `ledgr_pulse_feature_table()` uses
the private projection when the long table is empty (`R/feature-inspection.R:296-317`).
The context synthesis section 5 retains inspection surfaces. A repair must give
that reader a bounded route preserving pulse and axis; no automatic full-long
rebuild or inspection removal. Repair may be separately prioritized under the current
contract; it must not wait for a model API. Neither repair nor access is implemented here.

## 8. Identity and cost: inherited backing, incremental allocation

Engine version alone is not projection identity. Existing feature-cache keys
include snapshot hash, instrument, feature fingerprint, feature-engine version
and range (`R/feature-cache.R:122-169`); active fingerprints also encode strict
history semantics (`R/feature-cache.R:29-62`). Preserve that reuse. Ordered axes,
cutoff, lookback and semantic contract/version must prevent incompatible view
reuse; result-affecting domain/window choices belong in canonical strategy or
consumer declarations. No mutable panel registry or matrix hash is required.

The baseline already retains O(FNT) feature doubles before callbacks. For
500 instruments, 2,500 pulses and ten features, payload alone is 100,000,000
bytes, about 95.4 MiB: arithmetic, **not measured peak RSS**. Bars, prepared pulse
views, names, transient copies, semantic indices and parallel workers add costs.
A detached one-feature window adds O(NL) payload per requested materialization;
it does not make total memory O(NL). A 500 x 252 slice is 1,008,000 payload bytes.

Keep the bans on per-callback DB history queries, R-level instrument-by-pulse
reconstruction, redundant full-panel long materialization, and market panels in
serialized strategy state. In particular, reusing the provider's name `history`
is not proof of a prepared path: its durable implementation queries storage
(`R/availability-provider.R:208-242`). Any later representation measurement must
separate inherited preparation, added window/metadata allocation, estimator cost,
and worker replication, with cold and warm clocks per spike-protocol section 10.

## 9. Replace the old gate with one semantic feasibility checkpoint

Withdraw v1 section 11's numerical-backing gate: section 2 answers it. The
response may now open after maintainer acceptance of this provisional framing.
Retain **one pre-synthesis checkpoint**, after the response has challenged the
proposed cell meaning; do not make a probe silently decide that meaning first.

The bounded empirical question is: **Can existing prepared feature values and
production fact semantics supply aligned original-cutoff evidence for the
proposed single-feature window, without a second resolver, per-callback storage
queries, or replay of portfolio state?** Its cheaper backing prerequisite is
recorded here. This proposes a probe, not the subsequent comparative charter.

Use a minimal changing-membership/gap fixture that can falsify the proposed
meaning, including a fact effective before it becomes knowable. Compare historical
evidence to the production provider at the original cutoffs, with current-plane
value parity and future-only perturbation as controls. Let failures choose additional
cases; use the existing directory and protocol's runner/CSV/checker/gut form.

**Kill condition:** if an indispensable cell distinction cannot be obtained from
the existing authority without reconstructing independent history or portfolio
state, stop. Record the exact missing evidence/ownership seam; revise scope or
return the architecture question to response. Do not automatically commission a
lower projector or start storage comparisons. Green establishes bounded semantic
reuse only, not future-access repair, training-export parity or research-scale
memory suitability. Findings bind no design under the spike protocol.

## 10. Response, synthesis and next action

The different-author Type 2 response should challenge five issues: Direction 5.4
within Cut 13; original-cutoff cell/domain meaning; callback authority and inspection;
identity/allocation bounds; and minimum useful scope. The maintainer owns the
operative brief under `rfc_cycle.md`; this is an agenda, not that brief.

The later synthesis must choose the matrix and companion contracts, disposition
the predecessor explicitly, assign one semantic owner, settle cutoff/axis and
copy/access authority, preserve inspection and authoritative contract hierarchy, and
name what the recorded semantic result supports. Unsupported distinctions must
be excluded or fail explicitly, never guessed. It must state detecting acceptance
requirements for future-read escape, future-fact perturbation, retained-result
mutation, axis alignment and warmup parity. Model lifecycle, estimators, labels,
embargo, financing, accounting, scheduling APIs and general SQL/history query
languages remain outside this cycle. No spec packet is written by the seed author.

Next: accept or revise this framing, open response, then resolve the semantic
checkpoint before synthesis. No comparative charter or current-release commitment.
