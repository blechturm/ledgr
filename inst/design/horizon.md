# ledgr Horizon

**Status:** Active parking lot.
**Authority:** Non-binding design memory.

This file holds design observations that are not ready for the roadmap, an ADR,
or a versioned spec packet. It is not a backlog and does not imply commitment.
`Open` contains non-binding parked ideas. `Historical redirects` preserves old
heading links after bodies move to `horizon_archive.md`; those stubs are
navigation, not active work or authority.

Use lightweight entries only:

```text
### YYYY-MM-DD [area] Short title

Freeform note.
```

Area tags:

```text
execution, ux, data, risk, cost, research, infrastructure, adapters
```

Do not add owners, due dates, priorities, acceptance criteria, or ticket
statuses. If an item becomes planned work, promote it into the roadmap, an RFC,
an architecture note, or a spec packet.

## Open

### 2026-10-26 [architecture] Core boundary and incubated sister packages

The wishlist after the first CRAN release cannot all live in one package
without making the compatibility promise unbounded. It covers point-in-time
fundamentals, more asset types, shorting and margin, intraday bars, ML,
portfolio optimizers, selection statistics, an OMS and a live-trading
adapter. The working shape is a small core plus a few sister packages: the
"ledgr-verse".

Core keeps what only ledgr can make correct:
- point-in-time truth: sealed snapshots, facts, knowledge and effective
  clocks, sessions;
- the one deterministic fold and event-sourced ledger with its accounting,
  including future shorting, margin and multipliers and the order and event
  vocabulary a live runtime would consume;
- provenance: identities, the experiment store and an honest snapshot-wide
  trial record;
- the public seams that sister packages build on.

Candidate sister packages:
- vendor adapters: `ledgr.crypto2` and the private Sharadar adapter;
- selection statistics such as PBO, DSR and minimum track record, computed
  over the trial record rather than over one sweep;
- portfolio optimizers that emit targets;
- an ML lifecycle on causal history;
- a broker, paper and live runtime.

Two rules make this a family rather than a sprawl:
1. Dependencies point one way. A sister package uses only exported API and
   never `ledgr:::`; core at most Suggests a sister package.
2. Sister packages incubate in the private ledgr-research repository until
   they graduate. Public parallel maintenance then accrues one package at a
   time, and each incubating sister package is the second consumer that
   proves a seam before CRAN freezes it. A `ledgr:::` call in an incubating
   sister package marks a missing seam, not an acceptable workaround.

Measure before deciding. There are four inputs:
- the export census, starting from the export shape audit's CSV;
- a coupling and size map per candidate sister package: its code, its tests
  and the internal calls that would cross the boundary. For example, the
  validation statistics reach `ledgr_return_panel()` and
  `ledgr_effective_trials()`, and `R/business-objective.R` consumes them;
- a seam audit of the private adapters for non-exported use;
- an inventory of the public seams that exist versus those needed.

One design session then produces a core-boundary ADR: the core list, the
seams, the dependency and versioning rules, the graduation criteria and the
naming.

Maintainer, 2026-10-26: scheduled for the next release. The measurement and
the decision precede export tiering, because tiering a surface that is about
to move is wasted work. This entry authorizes no package split, unexport,
move or ticket.

### 2026-10-26 [ux] Export shape audit findings and their routes

The read-only [export shape audit](audits/v0_2_2_export_shape_audit.md) at
`8a00a3be` asked whether any of the 179 exports violates one of four shapes:
a layout expressed as a function name, two names for one operation, plumbing
or placeholders in user-facing groups, and names the bound naming rules
forbid. Nine findings, none a correctness defect, all at seams between eras
rather than inside a family. 63 exports postdate the 2026-06 naming
synthesis and five of them carry a finding. The per-export census is
`audits/v0_2_2_export_shape_audit_exports.csv`.

Routes, as recorded in the audit's Section 6:

- F1 to F4 and F6 (the five `ledgr_sweep_returns_*` layouts, the two
  pulse-inspection layouts, the promotion-context pair, `ledgr_run_fills()`
  beside `ledgr_results(bt, "fills")`, and the `ledgr_opening_from_broker()`
  placeholder) ride the next release's result-reader and symbol-surface work
  through the roadmap's deferred maintenance inventory.
- F5 (`ledgr_backtest()` beside `ledgr_run()`, and the bench helper's stale
  message) belongs to the execution-core consolidation, whose bars-only
  acceptance decides what the hello-world path becomes.
- F7 and F9 (tier placement of three plumbing names; six family help topics
  named after one member) ride the documentation-surface input already
  listed for the next release.
- F8 (three verb-first strategy helpers outside the closed allowlist) needs
  one contracts amendment decision. The smallest is scoping R1's prohibition
  to artifact-scoped exports, as the 2026-06 synthesis intended.

The parked questions stay parked: block-level earn-its-keep with the
2026-10-12 `[research]` entry below, and the usage-based export gate with the
2026-10-12 `[infrastructure]` entry below. This entry authorizes no removal,
rename, unexport, contract amendment, ticket or release scope.

### 2026-10-26 [ux] Explicit export tiering before CRAN

Today the pkgdown reference index does a job the export list cannot. Its
Low-Level Utilities group is the package's de facto internal tier, holding
the timestamp utilities, `ledgr_db_init()`, `ledgr_temp_store()`,
`ledgr_validate_schema()`, `ledgr_backtest_bench()` and the two simulation
fixtures, while three names of the same kind sit in user groups (export
shape audit, F7). That works while the only readers are the maintainer and
the vignettes. On CRAN every export is a first-class help page to a
stranger, so the tier has to become a decision rather than a grouping that
drifts.

The design question is small but must be answered once for every export:
which of three tiers it belongs to (ordinary research surface; low-level and
recovery; fixtures and simulation) and how each tier is expressed. Candidate
mechanisms are `@keywords internal` (exported, documented, hidden from the
index), a named reference group per tier, or unexporting with examples
reaching the helper through `ledgr:::`. The export lock in
`tests/testthat/test-api-exports.R` and `tests/claims.yml` should encode the
tier so a new export cannot land untiered, and the contract's Internal Names
rule group is where the tiers get their sentences. Inputs: the audit's
per-export census, the 2026-06 naming synthesis Section 4 recovery-pair
decision, and whatever the prove-or-retire pass removes first, since tiering
a surface that is about to go is wasted work.

Maintainer, 2026-10-26: scheduled for the next release, after its cleanup
work (the prove-or-retire pass, the one-result-reader merge and the
export-shape repairs) and before the first CRAN tag; recorded as a carried
commitment in the roadmap. This entry authorizes no mechanism choice,
unexport or ticket.

### 2026-10-25 [data] Cross-asset price precision and tradability

The completed spot-crypto readiness spike found that ledgr rounds stored prices
to eight decimals and that `ledgr_target_rebalance()` floors desired quantities
to whole units. Those are not crypto-only defects and should not be patched as
two unrelated special cases. They expose one cross-asset contract covering
price representation, tick size, quantity step, minimum quantity and notional,
target normalization, fill/accounting parity, disclosure and identity across
equities, crypto, FX, futures and other instrument families.

Open a focused asset-precision and tradability RFC after v0.2.2. Use the
micro-priced-token and fractional-target probes as vendor-neutral evidence.
Until it is accepted, the current workaround is to re-quote micro-priced assets
and construct fractional targets explicitly; do not infer granularity from an
instrument symbol or silently add a crypto exception. Cut 20 owns neither the
fixed-decimal rule nor quantity-step semantics.

<a id="2026-10-25-adapters-public-ledgrcrypto2-after-the-promotion-ready-core"></a>
### 2026-10-25 [adapters] Public `ledgr.crypto2` after the promotion-ready core

The three-stage spike on `spike/crypto-readiness` shows that ledgr can already
run daily, unlevered, long-only spot research with fractional quantities, a
complete 24/7 calendar, point-in-time membership, lifetime terminals and
explicit 365-day metrics. Its 2020-2025 CMC exercise covered 484 historical
top-100 identifiers, 455 with bars, and measured a 2.73 percentage-point annual
CAGR difference between point-in-time and survivor-only equal-weight universes.
Because 29 ranked identifiers had no served history, the honest public claim is
survivorship-bias-aware coverage, not survivorship-bias-free data.

Keep the adapter private through v0.2.2 and the next release's performance,
memory, execution-core and cleanup work. Then open a separately versioned
public `ledgr.crypto2` sister package with a user-run resumable downloader,
local cache, coverage diagnostics, native sealed-snapshot adapter, synthetic
fixtures and one point-in-time top-100 article. Publish no provider rows. Review
the upstream endpoints and terms before release, and do not create a generic
adapter package until multiple public adapters demonstrate the same boundary.

Token unlocks are supply information, not holder accounting events unless the
simulated portfolio owns the locked allocation. Airdrops, forks, staking,
rebases, migrations, venue/lifetime changes and non-spot funding remain with
the cross-asset accounting-critical-events route; this adapter does not invent
their semantics.

### 2026-10-25 [ux] Advanced portfolio-construction teaching arc

The minimum-variance article now keeps one primary job: causal returns to a
ready sample, an ordinary R estimator, identified weights and rebalance
targets. Its October 2026 teaching review deliberately removed carried-price
screening, retained estimation exclusions and a large decision-outcome
taxonomy from that introductory path. Those topics remain useful, but they
should not return as local article plumbing merely because the underlying
diagnostic surfaces exist.

After the portfolio-construction RFC settles omitted holdings, current
weights, turnover-aware allocation and universe exits, add one advanced
portfolio-construction article that distinguishes:

1. data admitted to estimation;
2. the optimizer's allocation over that sample; and
3. the strategy's resulting execution intent.

That article may demonstrate an explicit data-quality screen, retaining or
liquidating an omitted holding, index-leaver policy, turnover constraints,
no-trade bands and allocation diagnostics. It must consume the settled product
semantics rather than decide them through example code.

Keep the neighboring subjects in their existing homes. Carried observations
and missing-return semantics stay in Reading Causal History. Liquidity and
capacity mean whether an intended quantity can realistically trade and remain
with the execution-policy RFC. Durable factors, ranks, selections and weights
remain LFB-028. Numerical covariance repair is ordinary estimator practice and
needs no ledgr abstraction unless repeated methods expose a product boundary.
This entry authorizes no API, RFC, article or release scope.
### 2026-10-21 [execution] Cheap, versioned pulse-seed derivation

The seeded fold currently derives every `ctx$pulse_seed` by canonicalizing a
list containing the execution seed and pulse index, hashing it with SHA-256,
splitting the hexadecimal result and combining the chunks. An exploratory
v0.2.2 narrow-long clock (10 instruments, 7,200 pulses) measured about 1.35
seconds between the seeded and unseeded engine arms, or roughly 0.19 ms per
pulse. The strategy did not consume randomness, so the difference isolates
the cost of supplying deterministic pulse seeds closely enough to justify a
dedicated follow-up; it is not release-grade benchmark evidence.

The contract needs a deterministic, ambient-RNG-independent mapping from
`(execution_seed, pulse_idx)` to one valid R integer seed. It does not need
cryptographic unpredictability, JSON or SHA-256. The next release should bind
a versioned, platform-independent counter rule: either direct normalized
integer arithmetic or a small integer mixer that avoids adjacent execution
seeds becoming shifted copies of one another. Derivation may be constant-time
at the pulse or batched during preparation; a stored vector is not required
when the scalar rule is already negligible. Scheduled-out callbacks need no
strategy-visible seed.

Changing the mapping intentionally changes stochastic results. The owning cut
must pin exact values on supported platforms, include the rule in execution
semantics or identity, and prove continuous/resumed, run/sweep/promotion and
serial/parallel parity while leaving the caller's `.Random.seed` unchanged.
Measure total run time as well as the fold-loop reduction so moving identical
hash work out of the loop cannot be presented as a speedup. This note does not
select the arithmetic, authorize a compatibility path or bundle the separate
target/fill/event optimization investigation.

### 2026-10-21 [execution] Typed P3-P5 execution batch

The extracted fold stages expose the target-to-event path clearly: P3 computes
target deltas, resolves fills and affordability, and builds diagnostics; P4
applies lot, cash and position transitions; P5 publishes the staged event
rows. The current path is linear and preallocated, but one fill crosses several
nested R representations and some primitives are derived more than once.
Repeated work includes rebuilding instrument indices already present in the P1
packet, constructing proposal and execution-context lists per fill, extracting
the same fields through several `vapply()` passes, deriving cash and position
deltas for affordability, event materialization and state mutation, and
packing then unpacking the whole lot carrier around the compiled batch.

The next release should investigate one typed internal batch carried across P3,
P4 and P5 on the surviving availability execution path. Candidate reductions
are reuse of P1's prepared indices, a no-action fast path, one canonical cash
and position delta computation, prepared or vectorized built-in cost
resolution, and direct typed writes into the unified output handler. Dense mode
is frozen and should not receive an independent optimization.

The evidence should distinguish many-pulse/no-fill, sparse-rebalance and wide
all-fill workloads and report total run time, stage time, allocations and peak
memory. Economic outputs remain exact: targets, fills, ordered ledger events,
trades, equity, metrics, continuous/resumed execution, run/sweep/promotion and
serial/parallel behavior. The existing fold-phase synthesis already owns the
single-delta and leg-fee-projection obligation; an internal typed-R
representation therefore needs no new RFC merely for being faster.

Implementation follows both output-handler consolidation and execution-core
consolidation so the representation is built once for one handler and one
execution path. A persistent compiled lot carrier, a P3-plus-P4 compiled
kernel, another compiled call site or a compiled-default change remains behind
the existing compiled-execution-envelope RFC. This route is promoted to the
next-release roadmap; the next version's macro plan should assign the
workstream and its measurement gate.

### 2026-10-21 [infrastructure] Execution extension guide after consolidation

Once execution-core consolidation, output-handler unification, context cleanup
and the typed P3-P5 representation have landed, survived profiling and carried
at least one real extension, capture the resulting practice in an internal
execution-extension manual beside the optimization coding guide. The manual
should explain phase ownership, the stable typed fields and invariants,
optional companion blocks, fill versus non-fill economic events, validation
boundaries, and the parity, mutation, performance and memory evidence expected
from a new execution or accounting extension. It should also name prohibited
shapes such as parallel execution paths, per-fill data frames, growing nested
lists, repeated identity resolution and duplicated delta calculations.

The same pass should refresh the maintainer-facing documentation into a concise
navigation layer linking contracts, accepted RFC decisions, manuals, tests and
implementation entry points, and remove or archive descriptions of the retired
execution paths. Contracts remain the authority and the implementation remains
the executable truth; the manual records proven extension practice rather than
freezing the transitional architecture. Do not begin this documentation pass
until the unification work and its first extension demonstrate that the
boundary is stable.

### 2026-10-21 [execution] Cutoff-bound context internals or a strategy sandbox

Strategy preflight is a best-effort static check, not a sandbox (Cut 16
decision 30). The private context carriers, the closures behind public
context functions and ledgr's namespace hold prepared data beyond the pulse,
so a strategy that deliberately subverts R evaluation can read it. Two
options were deferred: make the context internals cutoff-bound (each carrier
and closure holds only data known at the pulse), or run strategies in a
separate process that receives only the pulse's public context. Trigger:
ledgr needs to run untrusted strategies. Raised by the WS44 phase A close
review and its re-review (2026-10-20/21). This entry authorizes no RFC, API
or release scope.

### 2026-10-20 [data] Raw bars with point-in-time adjustment

ledgr accounts in split-adjusted share units (contracts, Units, Price Basis
And Universe): back-adjusted price levels encode later splits, so price
thresholds, lot sizes and integer sizing before a split are in post-split
units. Returns are unaffected and the limitation is documented. A fully
point-in-time price model would store as-traded bars and apply split and
distribution adjustments as known at the decision time, with splits acting
on positions as events. Raised by an external review of the WS44 API demo
(2026-10-20). This entry authorizes no RFC, API or release scope.

### 2026-10-15 [execution] Fused plan-plus-apply compiled kernel and a unified stop-or-abort type

Parked at acceptance of the fold-phase RFC synthesis
(rfc/rfc_fold_execution_phase_ownership_v0_2_2_synthesis.md, Section 11). Two
speculative deferrals, neither authorized: a compiled kernel fusing P3 plan
execution with P4 apply, which the compiled-execution-envelope RFC may weigh
against keeping P4 alone as the seam; and one typed stop-or-abort result that
also covers the P5 reconciliation mismatch, today a fold exception rather than
a stop. Both wait for the measured stage profile LDG-3054 records.

### 2026-10-14 [ux] Compress the conceptual surface without erasing semantics

Ledgr's concepts are individually defensible, but the ordinary research path
still exposes too many neighboring distinctions at once. The future design
question is not whether backtesting can be made simple; it is whether ledgr can
teach a small progressive model while keeping the deeper state explicit for
researchers who need it.

The likely compression points are:

- indicators and features: present identity, validity and gap behavior as the
  primary model instead of making users assemble IDs, aliases, maps, bundles,
  warmup and implementation form in their heads;
- historical data: put causal cutoff, time axis, missingness, hydration and
  identity-preserving frame/matrix conversion behind one coherent history
  surface;
- universe state: provide an intuitive default for estimation eligibility
  while preserving the real distinctions among membership, lifetime activity,
  tradability, observability, admissibility and already-held instruments;
- strategy decisions: teach signal -> selection -> weights -> target ->
  execution as one ladder, with an explicit opt-in path for retaining upstream
  research evidence;
- identity and persistence: let users experience one promise -- the same
  declared data and experiment produce the same identified result -- while
  hashes, fingerprints and format versions remain explainable internals;
- scheduling: express when a strategy acts in experiment setup rather than as
  repeated timestamp control flow inside callbacks; and
- maintenance: use fold-core consolidation to collapse duplicate semantic
  tests and review concepts without weakening their oracles.

Do not create a universal facade merely to reduce vocabulary. Test this after
the accepted history surface, scheduling direction and fold-core consolidation
exist, using real strategy articles and research methods. A useful compression
removes repeated explanation or boilerplate across several workflows while
retaining the underlying contract boundaries and an escape hatch for advanced
inspection. This entry authorizes no API, deprecation, RFC or release scope.

### 2026-10-13 [adapters] Exchange archives as a free, survivorship-complete real-data source

ledgr has no users (maintainer, 2026-10-13), and a newcomer cannot reproduce a
point-in-time result without paid survivorship-free data: free US equity
sources drop delisted companies or forbid redistribution. Crypto exchange bulk
archives (for example Binance's public data portal) appear to keep the full
history of pairs the venue later delisted, which would make them the one free,
survivorship-complete real universe. Unverified: archive coverage, delisting
dates, and the terms on fetching versus redistributing. A Deep Research prompt
drafted on 2026-10-13 is meant to check them.

Shape if it holds: a fetch-at-runtime adapter (the user downloads under the
exchange's terms; ledgr ships no data) that seals a snapshot with lifetime
facts from the venue's listing history, plus one article: a point-in-time
study of how much of crypto cross-sectional momentum is survivorship bias,
against a naive universe of today's surviving pairs. The audience framing
decides who arrives. Crypto factor and portfolio research (daily, long-only,
research-minded) fits ledgr; trading bots, intraday, leverage and perpetuals
do not. The article is written for the first group and says what ledgr does
not do.

Semantics to settle first: a pair delisted on one venue is untradeable there,
not a dead asset, so the adapter labels that terminal outcome as
venue-specific and maps it honestly onto the existing terminal policies.
Prerequisite: the spot-crypto readiness probe (the 2026-09-14 entry below:
fractional accounting, 24/7 sessions, one venue, one quote currency); the
one-execution-mode probe's implied calendar may already cover the session
side. This entry authorizes no adapter, API, data commitment or release scope.

### 2026-10-12 [research] Prove or retire the thinly used product surfaces with real data

A per-file census on 2026-10-12 (117 R files) found that the 23,000 lines no
article touches are the engine, while about 4,500 lines, 8% of the package,
sit in product surfaces that are large, thinly taught and separable:

| Block | Lines | Exports | Article uses |
| --- | ---: | ---: | ---: |
| Validation toolkit (`validation-pbo`, `-dsr`, `-min-track-record`, `-k-ratio`) | 1,329 | 4 | 15 |
| `business-objective.R` | 1,343 | 9 | 5 |
| `sweep-filter.R`, `sweep-review.R`, the three `sweep-retention` projections | about 1,000 | 5 | 9 |
| `sim-pit-inputs.R`, `indicator-dev.R`, `signal-strategy.R` | 976 | 3 | 0 |
| `walk-forward-inspection.R` beyond open, scores and folds | part of 782 | 3 | 0 |

Each came from an accepted synthesis (the validation toolkit and business
objectives from v0.1.9.6), so removing any of them is a product decision
with its contract sentences, not a cleanup. Article use is a signal, not a
verdict: the statistics surface is thinly taught because it is statistics,
and the simulation aids have zero article use and heavy test use.

Maintainer, 2026-10-12: park for the release after v0.2.2. The plan is to
use every one of these surfaces in actual research on the Sharadar lake
first, and then be ruthless: a block that did not earn its keep is removed
under the pre-CRAN policy, one maintainer decision per block, recorded in
the roadmap as retired before CRAN with the contract sentences it removes,
riding whichever cut is already deleting surfaces. No deprecation cycle.

Companion package question, same day. Splitting surfaces into a companion
package is worth it when the satellite has a different dependency profile,
release cadence or audience, and when the seam between the two is stable.
Neither holds yet: the heavy optional dependencies (`quantmod`, `qlcal`,
`TTR`, `xts`, `mirai`) are already in Suggests, the research package already
holds the vendor adapters, and the public seams the consolidation will
change (strategy context, result readers, execution mode) are exactly where
a split would freeze the wrong boundary. Revisit after the real-data pass
and after the execution-core consolidation, when the surviving surfaces and
the stable seams are known. This entry authorizes no removal, deprecation,
package split, ticket or release commitment.

### 2026-10-12 [infrastructure] Structural gates deferred to the release after v0.2.2

The legacy-removal cut carries a codebase-hygiene workstream (macro plan,
2026-10-12 amendment): report-only census tools, then failing fast-profile
blocks for uncalled functions and undocumented error classes, a lint job,
one styler commit, the helper rule in the optimization style manual and one
Verification Contract clause. Two further gates were measured the same day
and deliberately left report-only until the execution-core consolidation
changes the surfaces they would police:

- Export census. 168 exports and 84 S3 methods; an export used by no man
  example, vignette or article becomes `@keywords internal`. Enforcing it
  before the strategy-context and result-reader surfaces settle would make
  the WS3/WS4 cut fight a gate on a surface it is about to replace.
- Test-oracle rule. 1,096 `test_that()` blocks, 248 with a registered claim.
  Correction, same day: the accepted testing-architecture synthesis binds
  that unregistered blocks need no durable ID and leaves undeclared claims
  to its Shrink, Merge and Delete reviews (Section 2.4 and line 107), so a
  per-block rule would reopen an accepted decision. The count stays a
  signal; the 848 blocks are classified through that existing lane when
  their suites are rewritten, not by a new gate.

The rationale for mechanical gates over more review: the per-ticket review
loop is strong, but nothing reads the whole package between cuts, so drift
accumulates exactly where reviews do not look.

**For the hygiene workstream: pin the collation of documentation
generation (2026-10-12).** Regenerating the man pages with roxygen2 7.3.3
from a shell whose `LC_COLLATE` differs from the maintainer's usual
environment reordered `NAMESPACE` (export lines) and 27 unrelated Rd files
(argument order and blank lines) with no content change; the thirteen-export
documentation chore (`90a701d1`) kept only its seven intended pages and
reverted the rest by hand. Same class of defect as the quarantine ordering
found in the snapshot-verification cycle: a sort that depends on the
session locale. The workstream adds a `tools/document.R` entry point that
sets `LC_COLLATE = "C"` (or `Sys.setlocale("LC_COLLATE", "C")`) before
`roxygen2::roxygenise()`, names the roxygen2 version it expects, and makes
one such regeneration the committed baseline so later diffs show content
only. roxygen2 is not installed for the current R; the chore used the copy
in the previous R version's user library, which the entry point should not
assume. This entry authorizes no ticket or release commitment.

### 2026-10-12 [architecture] Where the package's weight is, and the four levers that reduce it

Sized on 2026-10-12 at `a2464434`: 121 R files, 54,702 lines; 177 test
files, 56,536 lines. By subsystem: availability 6,570 lines in 11 files,
sweep 5,985 in 6 (`R/sweep.R` alone 2,629), features and indicators 5,199
in 13, backtest 4,588 in 6, strategy context 4,067 in 9, walk-forward 3,087
in 5. The pre-CRAN legacy removal RFC takes out about 950 R and 1,700 test
lines, roughly 2% and 3%; it removes code that lies about what a store can
be, not the weight.

The weight is duplication of paths: the package runs the same economics
two or three ways and proves them equal. Four levers would reduce it, in
order of payoff. None is authorized here.

1. One execution mode, dense as a special case of availability (the
   2026-10-11 execution entry below). Today there are two of almost
   everything: a dense pulse calendar from bar timestamps and a session
   calendar; a fast prepared context (`use_fast_context <-
   !availability_active`) and a general per-pulse helper path; dense and
   availability coverage checks in the run guard; dense and availability
   reconstruction in `R/derived-state.R`; `ledgr_backtest()` as a dense-only
   wrapper with its own validate and guard. A dense snapshot with an implied
   calendar and no facts deletes one side of each pair. Reading estimate:
   3,000 to 5,000 lines and one semantics instead of two parity
   obligations.
2. One output handler. The persistent and memory handlers stage the same
   fill events, equity and diagnostics and are held equivalent by contract
   and parity tests. One handler with a sink interface (DuckDB or memory)
   removes the second implementation and the suite that guards it, and
   closes most of the committed-run-versus-sweep gap parked in the
   2026-10-12 execution entry, because the sweep stops being a separately
   optimized engine. It does not depend on lever 1: persistent versus
   memory is a different axis from dense versus availability, so it is the
   lower-risk lever and may go first after v0.2.2 (review, 2026-10-12).
3. Retire the context frame views and shrink the context surface
   (scheduled: RFC pipeline `ctx-frame-retirement`, and the strategy
   context design session in the roadmap). `R/pulse-context.R` is 1,311
   lines for a surface of about thirty members; a typical strategy uses
   six.
4. Merge the three result-reader families (`R/backtest-results.R`,
   `R/availability-results.R`, `R/corporate-action-results.R`), which read
   the ledger and equity with their own helpers and print paths. After
   lever 1 there is one run shape, so there should be one reader.

Measure before touching: `R/sweep-retention.R` (1,379 lines) and
`R/business-objective.R` (1,343) are large for what they do and may carry
their own frame-per-row shapes; the `mirai` parallel sweep path is a second
execution environment ranked below single-core work. File-count or
line-count cleanups on their own are not a lever.

Two companions to the levers, from the 2026-10-12 review of this entry:

- **Split the fold into phase functions, before unification.**
  `ledgr_execute_fold()` (`R/fold-engine.R:238-1417`, 1,180 lines) is about
  280 lines of setup and one pulse loop whose body runs about 880 lines in a
  fixed sequence: inputs and corporate actions, the availability decision
  (176 lines), context build, strategy call and target validation, fill
  planning, accounting, event emission, availability valuation, then state
  update, telemetry, checkpoint and interrupt. `availability_active` is
  tested 29 times in the file and `sample_telemetry` runs through every
  phase. Extract one phase per commit as top-level package functions
  (byte-compiled at install; a closure body is JIT-compiled only for its
  first instance), passing one fold-state environment for scalars, flags
  and references. Condition from the optimization style manual's shape 7:
  per-pulse buffers stay written by `collapse::setv()` or outside that
  environment, because a vector held in an environment is copied whole on
  every subassignment. Gates: the fixture ladder identical at every commit,
  paired clocks (about ten extra calls per pulse are microseconds against
  milliseconds), the seven shapes walked. `ledgr_run_fold_impl()`
  (`R/backtest-runner.R:698`, 675 lines) gets the same treatment next. After
  the split, each phase shows its dense-versus-availability fork in one
  place, so lever 1 becomes a per-phase deletion with a per-phase witness,
  and the probe's first kill condition becomes legible. The probe itself
  can run on the unsplit fold, since it only compares outputs, and is the
  cheaper step.
- **Audit the defensive code; collapse, do not delete.** There are 1,533
  `abort` and `stop` calls in `R/`, in three groups: public-function input
  checks with named classes (about 386, needed, claims test them);
  validator helpers (173 functions, about 5,680 lines, 352 aborts, mostly
  needed but called repeatedly, for example `validate_ledgr_config()` from
  six sites and `ledgr_validate_feature_map_object()` from eleven); and
  other internal invariants (about 793), the real candidates. Two
  mechanisms: validate once at construction and mark the object, where the
  mark is a class, not an attribute (attributes drop through subsetting),
  and never crosses a persistence boundary, so the store re-validates; and
  one internal assertion helper, `ledgr_assert(cond, "what broke")`, for
  impossible states, keeping an error class wherever a registered claim
  asserts one. Internal invariants stay because much of ledgr is written by
  agents and these checks fail at the line that caused the mistake rather
  than three layers later. Route: a Type 2 audit brief producing a table
  and proposed tickets, per `rfc_cycle.md`; the review's unverified guess is
  1,000 to 2,000 lines. The same audit carries the complexity review
  (maintainer, 2026-10-12): candidates come from metrics, not reading
  (length over 150 lines, more than one `availability_active` fork in a
  function, argument count, the single-call-site helpers), capped at about
  twenty functions, each classified as contract-driven complexity (two
  execution modes, durable atomicity, fail-closed inputs) or accidental
  (layered validation, carried-forward compatibility, patches on patches);
  only accidental complexity earns a ticket, and every ticket is a pure
  refactor under the fixture ladder, paired clocks and the seven shapes,
  with any behaviour change routed to design instead. Measured on
  2026-10-12: nine functions over 300 lines and 24 between 150 and 300,
  led by `ledgr_execute_fold()` (1,180), `ledgr_validate_schema()` (766),
  `ledgr_run_fold_impl()` (675), the memory handler (615), the legacy
  schema path (453), `ledgr_snapshot_from_df()` (394),
  `ledgr_corporate_action_plan()` (392), `validate_ledgr_config()` (366)
  and the persistent handler (353); nesting is not the problem (nine lines
  in the package sit six levels deep). Two of those are deleted by the
  legacy-removal cut and four are already the fold split's and lever 2's
  targets, so the audit runs after the removal cut and before the fold
  split, fed by the hygiene workstream's census tool.

Order: lever 1 before lever 4, because one run shape means one reader;
lever 2 is independent and lower risk; lever 3 is already scheduled. The
unification probe runs in v0.2.2 between the legacy-removal cut and the
WS3/WS4 implementation cut (maintainer, 2026-10-12). After v0.2.2 the
sequence this entry suggests is: lever 2, the fold split, the unification
slices, with the defensive-code audit alongside.
Identity: unification moves dense config and snapshot identity, because
canonical omission is dense mode's identity today. After the pre-CRAN
legacy-removal cut that costs a version and fingerprint bump plus a lake
rebuild, so land it in the same release as another format change to save a
rebuild (review, 2026-10-12). This entry records a direction; it
authorizes no API, schema, ticket or release commitment.

Current-state route (later accepted release-line authority `4397f58f`): lever
1 is now committed before first CRAN and owned by
[execution-core consolidation](ledgr_v0_2_2_spec_packet/macro_plan.md#execution-core-consolidation).
The output-handler, result-reader and defensive-code questions remain parked
here with their own triggers.

### 2026-10-12 [execution] Close the gap between the committed run and the ephemeral sweep

On the v0.2.1.0 peer record (500 instruments, 1,260 sessions, 630,000 bars)
the committed `ledgr_run()` row took 57.9 s cold with a 45.5 s engine phase,
while the public compiled sweep took 20.1 s with an 11.3 s engine phase and
the canonical sweep 37.9 s with 28.8 s, on identical bars and strategy. The
durable run is the audited product path: ledger, resume, provenance and
reopen live there. When it is three times slower than the throwaway path,
research drifts to the throwaway path.

Three levers were visible on 2026-10-12, in order of least semantic risk:

1. The per-run snapshot rehash, about 5 s of the engine phase at this shape
   and about 55 s per Sharadar run. The WS5-A verification cycle (rule 3 and
   the process-local verified set) owns it in v0.2.2; whatever lands there is
   subtracted first.
2. Per-pulse persistence inside the fold. The durable engine phase was about
   17 s slower than the canonical sweep's on the record; most of that is
   DuckDB writes of events, equity and strategy state per pulse. The
   Workstream 6 fill-event flush
   (`ledgr_v0_2_2_spec_packet/writer_scaling_closeout.md`) shipped after the
   record, so the remaining gap must be re-measured on the v0.2.2 record
   before any lever is sized. [Macro-plan Section 5](ledgr_v0_2_2_spec_packet/macro_plan.md#5-explicit-non-goals)
   retains one store connection per composite public call as non-gating work
   on the same boundary.
3. The compiled accounting model for committed runs. `ledgr_run()` refuses
   `compiled_accounting_model = "spot_fifo"`, so the 4x engine result exists
   only on the ephemeral sweep. Widening it is owned by the compiled-execution
   envelope row in the RFC pipeline
   (`rfc/README.md#compiled-execution-envelope`) and the older entry below,
   "Decide whether compiled spot-FIFO should become the default"; parity
   through the existing canonical oracle is the gate, and the LDG-2992
   closeout is the carrier evidence.

Measure the gap on the v0.2.2 peer and Sharadar records first, then decide
which lever is worth a cycle. The maintainer parked this on 2026-10-12 for
the release after v0.2.2 because v0.2.2 is full. This entry authorizes no
API, schema, ticket or release commitment.

### 2026-10-11 [data] Derive off-session bar evidence live instead of storing it

Cut 12 LDG-3011 records each sealed bar that falls on no declared open-session
close as a row in `snapshot_observation_quarantine` (reason `off_session_bar`).
The row is derived from hashed bars and sessions, so it stays outside the
snapshot hash, the quarantine acknowledgement and the seal checks; deleting or
injecting such a row therefore goes unnoticed (WS24 close review F8, accepted
for v0.2.2 by the maintainer on 2026-10-11).

A reader-side derivation would be tamper-evident by construction: the
off-session set is an anti-join of `snapshot_bars` against the open-session
closes in `snapshot_sessions`, both hashed. `ledgr_snapshot_quarantine()`,
`ledgr_snapshot_info()$off_session_bar_count` and the run summary could read
that query instead of stored rows, which would also remove the stored rows'
special cases in the hash payload, the acknowledgement check and the seal JSON
checks. The open question is cost on large snapshots (the anti-join runs at
read time) and whether the supplied row's extra columns, which only the stored
record keeps, matter to anyone. This entry authorizes no API, schema, ticket
or release commitment.

### 2026-10-10 [research] Durable factor and decision evidence

External practitioner feedback from an integrated research, paper and live
platform identified a traceability gap. ledgr durably records target intent,
risk and execution diagnostics, fills, costs, ledger events and accounting,
and can persist declared feature rows. It does not preserve the factor or
prediction actually used to rank an instrument, its rank or selection, and
the weights handed to target construction as one queryable decision chain.

That chain matters for ex-post information-coefficient and rank-decay work,
prediction calibration and drift, attribution between factor, construction,
cost and execution, and eventual backtest/paper/live comparison. The stages
must remain distinct:

```text
factor or prediction -> rank or selection -> weights -> target
  -> costs and fills -> accounting outcome
```

Do not infer an artifact store or retain arbitrary callback objects from this
observation. After the WS3/WS4 history amendment has bound causal cutoff,
instrument and feature identity, first inventory the existing feature,
diagnostic, target and result evidence. Then run one bounded public-API spike
that follows a single factor through run, sweep, walk-forward and reopen and
measures storage and read cost. If the gap survives, a dedicated RFC decides
the smallest opt-in decision-evidence contract and its retention policy.

WS3 owns downstream-compatible point-in-time identity, not factor capture.
The later ML RFC owns model artifacts, fitting provenance and prediction
lifecycle. A future paper/live handoff may consume the same evidence shape.
The existing prediction-store and ML horizon notes are related but narrower:
this question also applies to ordinary non-ML factors. Research-side evidence
is `LFB-028` in `ledgr-research/docs/governance/ledgr-feedback.md`. This entry
authorizes no API, schema, ticket or release commitment.

### 2026-10-05 [ux] Non-fungible portfolio sleeves and mandate attribution

The Momento application case distinguishes an active stock book, a benchmark
sleeve and a risk-free sleeve. Ordinary ledgr positions are sufficient when
the latter two are simply tradable instruments excluded from active selection.
No new representation is needed for that case.

The unresolved case is one instrument owned by more than one mandate, for
example SPY held both as an active selection and as harvested-profit benchmark
exposure. ledgr correctly nets both into one instrument position, but the
target, fill and result contracts cannot preserve which mandate owns which
shares after costs, failed fills, resume or later rebalancing. Strategy state
can remember intended attribution but is not authoritative accounting evidence.

Do not introduce subaccounts, sleeve IDs or tagged fills from this single
application. Reopen in the portfolio-construction RFC only when a second real
workflow requires non-fungible ownership or when a product claim requires
mandate-level accounting rather than ordinary instrument-level positions. The
RFC must first decide whether this is allocation diagnostics, subportfolio
accounting or an external reporting concern. This entry authorizes no code,
schema or ticket.

Evidence and routing:
`ledgr_v0_2_2_spec_packet/portfolio_method_ux_exercises.md`, application case
"Momento cross-sectional momentum", inspected at upstream commit
`b7264cd290d717b7bb3fe4f7f8a861c09529a4f4`.

### 2026-10-04 [infrastructure] Long-window memory and parallel workers

The post-Cut-3 long-window record makes memory efficiency a standing design
concern, but not a v0.2.2 release blocker. Peak working set was about 1.3 GiB
at 1,514 sessions by 600 instruments, 2.1 GiB at 3,028 by 600, 3.8 GiB at
6,056 by 600 and 2.3 GiB at 1,514 by 2,300. EXP-0003 previously observed
about 7 GiB at its larger research shape. The measured growth is not an
obvious quadratic failure, and one process remains practical on a research
workstation.

The unresolved product risk is multiplication. Candidate or fold workers can
each retain hydrated bars, availability state, feature matrices, fold state,
DuckDB buffers and result materialization. A tolerable single-run peak can
therefore become unacceptable when multiplied by parallel workers. Parallel
defaults and worker-count guidance should eventually account for a memory
budget rather than CPU count alone.

Before changing representation, take a phase-level memory profile that
separates bar hydration, availability and feature matrices, fold state,
feature-persistence preparation, database buffers, finalization, result
materialization and retained caches. Check that sequential candidates and
walk-forward folds release memory, then measure representative parallel
worker counts. Feature persistence is already a known contributor, but its
policy remains a macro-plan WS5 decision and should not be removed merely to
improve a memory clock.

Evidence: `ledgr_v0_2_2_spec_packet/long_window_cut3_baseline.md` and the
ledgr-research record at commit `e95a581`, directory `long-window-cut3/`.
The bounded dead-hydration lifecycle repair is promoted to v0.2.2 Cut 5,
Workstream 12 and LDG-2951 after a phase profile measured about 14% lower peak
RSS without a runtime tradeoff. The broader representation, feature-policy,
sweep, walk-forward and parallel-worker questions remain parked here. This
entry authorizes no other implementation, memory target, worker default or
RFC.

### 2026-10-04 [research] Sweeping experiment assumptions, not only strategy parameters

Parked by the maintainer while scoping the terminal-outcome RFC. Sweeps and
walk-forward vary strategy and feature parameters. They cannot vary the
assumptions an experiment is run under: the untradable-holding policy, the
valuation horizon, the cost model, the corporate-action policy or the risk
chain. A researcher who wants to see a result under write-off, a 50% haircut
and the last permissible mark has to run the experiment once per assumption
and compare by hand.

The question is broader than adding a grid axis. Every assumption enters
experiment and run identity, so a grid over assumptions changes what a
candidate is. It also interacts with:
- the business objective and selection, which should not pick the most
  favorable assumption;
- trial counting, where an assumption scenario is a sensitivity case, not a
  separate trial;
- saved-sweep compatibility.

Design work is needed before any API. The terminal-outcome seed
(`rfc/rfc_terminal_outcomes_v0_2_2_seed.md`) compares scenarios by separate
runs and does not depend on this. This entry authorizes no implementation.

### 2026-10-04 [ux] Experiment templates that carry opinionated defaults

Raised by the maintainer while deciding the terminal-outcome defaults. ledgr
must stay usable with opinionated defaults, while every default used is
recorded, shown and changeable. Experiment templates could bundle such
defaults into named starting points, for example a research template and a
strict audit template, instead of each policy constructor carrying its own
preset. The existing `ledgr_corporate_actions_research()` and
`ledgr_corporate_actions_strict()` pair is the nearest precedent.

Open questions:
- how a template enters identity;
- how a run discloses which template and which overrides applied;
- how templates relate to the 2026-09-29 "Sensible defaults versus required
  configuration" entry.

The terminal-outcome seed must not block templates but does not design them.
This entry authorizes no implementation.

### 2026-10-01 [benchmark] A suite of peer workloads, not one

The maintainer wants the peer benchmark to grow from one workload into a
suite of workloads and strategies, measured against the same peers. The
registered record is one shape: 500 instruments, 1,260 daily sessions and one
SMA crossover. It is a single point.

Two reasons. Parity across many shapes is a stronger quality signal than
parity on one: each new workload is another place where ledgr must compute
what the peers compute or explain the difference. And a cost map across
shapes gives the optimization work data it does not have today, because
ledgr's cost floor is per pulse more than per bar. A wide daily universe spreads
each pulse's fixed cost over many instruments; a narrow and long intraday
workload, such as 100 instruments over a year of minute bars, has thirty times
the pulses for the same bar count and has never been measured. Intraday at
whole-second resolution or coarser is within the timestamp contract; this
entry is how to learn what it costs.

Candidate shapes: narrow and long intraday, wide and short cross-sectional
ranking, availability-aware universes with entries and exits, corporate
actions, multiple feature families, and strategies with state. Each keeps the
current record's rule that parity is checked before timing is read.

Maintainer, 2026-10-01: ledgr makes no public performance claim, not even a
same-host version-over-version speedup, until this suite exists; its results
then become the official comparison. Parity comes first and is the near-term
interest, also for the API: writing the same strategy for each peer shows where
ledgr's interface and semantics differ, which could become a guide for users
coming from those peers.

The release-claim rule is bound in the v0.2.2 macro plan and the RFC
pipeline's `benchmark-methodology` row. The candidate suite design remains
parked here.

**Memory as a measured dimension (maintainer, 2026-10-04).** The suite reports
peak memory per engine and workload row, beside time and parity. Today's
record samples one combined process-tree peak once per second: 2,284.1 MiB at
500 instruments × 1,260 days, Python peers included. It cannot say which engine
used what (`dev/bench/peer_benchmark/peer_benchmark.md`). Each engine row
therefore runs in its own process with its own peak sampler, like the
Workstream 11 runner's per-child RSS polling. The suite should include at
least one long-window, wide-universe shape near the EXP-0003 scale, because
memory separates engine architectures there. Full-array vectorized engines,
event-driven engines that keep full per-feed history, and streaming engines
that keep only lookback windows behave differently as history grows. That
characterization is general knowledge, not a measurement; the suite is what
would measure it. The motivation is the
[next-release memory theme](ledgr_roadmap.md#next-release) and
`dev/spikes/ctx_frame_views/churn_findings.md`; no 2 GB release promise is
current. The publication rule above
applies to memory as well: no comparative memory claim until the suite
exists.

**Parity as onboarding trust, on dense known shapes (maintainer,
2026-10-12).** The suite's first job is to give external users a reason to
trust an implementation built with LLM assistance: on the strategies,
indicators and shapes they already know, ledgr must produce the same fills
and equity as the peers or explain every residual, as the current record's
per-bar divergence attribution already does for backtrader (position sizing)
and quantstrat (fill timing). The same rows are a testing ground that catches
implementation errors, and speed claims on them become defensible because the
parity table proves that the fast number and the slow number compute the same
thing. The majority of parity shapes therefore stay dense, daily and
conventional (SMA crossover, momentum, mean reversion, TTR indicators);
point-in-time universes stay out of the parity majority because
implementation differences between engines grow large there and would be
read as ledgr's error. Two consequences recorded the same day: once dense
becomes a special case of the availability core (the 2026-10-11 execution
entry above), the dense parity suite is the byte-for-byte regression oracle
for that unification; and the suite may carry one point-in-time row of a
different kind, labelled a demonstration and never a parity or speed claim,
showing what a dense engine computes on a survivorship-free universe with
listings and delistings and why it is wrong. This addendum changes no
publication rule above.

**PyBroker v2 and suite ownership (maintainer, 2026-10-20).** Add a pinned
PyBroker v2 row when this suite is designed. PyBroker is a chronological
bar-driven engine whose normal execution surface calls a Python strategy once
per active symbol per bar and schedules later fills; it is neither a
whole-universe callback nor an event-sourced store. The comparison must measure
that architecture rather than infer speed from its NumPy and Numba components.

Keep four distinct workload lanes: dense conventional parity, scaling
geometry, whole-universe portfolio construction, and one point-in-time
demonstration that is never ranked as a parity or speed row. The first new
portfolio workload is top-N rotation with the same ranking, rebalance schedule,
next-bar fills and holdings in PyBroker and ledgr. It should expose the
per-symbol-callback versus per-pulse-whole-universe crossover. The initial
shape set is deliberately non-Cartesian: 10 instruments by about 7,200
sessions, the existing 500 by 1,260 reference, 1,166 by 252, and a separately
budgeted 1,166 by about 7,200 stress row.

Each engine and workload runs in its own process. Report parity before timing.
The public timing surface has three distinct views: cold end to end from raw
input through comparable results; warm end to end with reusable preparation
retained but a real public experiment still constructed and executed; and an
engine-only diagnostic that must never replace the public headline. Report
input preparation, indicator preparation, orchestration, engine time, result
materialization, instrument-bars and strategy callback count for both the cold
and warm boundaries.

Setup is normally paid once in an interactive research session, so also report
an amortized session: one preparation followed by a predeclared sequence of
real public runs or candidates, initially at 10, 100 and 1,000 repetitions
where feasible. Peers receive equivalent reuse when their supported public
APIs permit it; wrappers must not rebuild reusable state merely to make a peer
look slow. If a framework cannot safely reuse prepared state, record that as
part of its performance profile rather than silently choosing a private path.
Measure peak child RSS separately for cold preparation and warm execution.

Warm end-to-end time is the primary research-speed comparison. Cold end to
end, engine-only diagnostics, amortized session cost and both memory peaks stay
adjacent so the headline neither penalizes reusable setup as if paid every run
nor hides its real first-use cost. PyBroker reports cold-JIT and warm-JIT rows
and distinguishes minimal output from a result-retention boundary comparable
to the ledgr row. Every peer version, environment and workload contract is
pinned.

The durable home is this repository under `dev/bench/peer_benchmark/`: workload
specifications, peer adapters, lockfiles, generators, parity oracles, compact
promoted evidence and the rendered method report travel with the ledgr source
they evaluate. `ledgr-research` may hold exploratory probes, private-data runs
and bulky raw evidence, but it must not become the only home of a release claim
or its reproducer. This is an amendment to the existing benchmark-methodology
obligation, not authority to publish a speed claim before the suite exists.

### 2026-09-29 [execution] Design homework: where intent meets the universe and the market

The maintainer wants this done soon. It is RFC work, a continuation of
`rfc/rfc_execution_policy_pipeline_audit_signal_north_star.md` (a 2026-05-16
maintainer RFC that predates point-in-time universes), not a new seam.

The principle is already stated in `vignettes/risk-and-cost.qmd`: the strategy
answers what it wants to hold, and downstream layers answer what it is allowed
to hold, when it executes and what it cost. Order management comes later as
another composable step
(`rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md`). The point-in-time
work added cases that the layer table does not yet place. Cut 22 decisions 3
and 4 (`ledgr_v0_2_0_2_spec_packet/tickets.yml`, 2026-09-29) are the inputs:

- **Mandate.** A departed holding that can still trade is sold by default,
  with a declared setting that keeps it instead. That is a constraint step
  after the strategy, not constructor behaviour. Increasing a holding outside
  the declared universe stays an error.
- **Market restriction.** A halt is an execution outcome, recorded rather than
  raised. Only intent formed while the instrument was tradable is acted on,
  so a halt cannot cause a sale at the reopening followed by a buy back.
- **Order management.** Selling at the reopening, grace periods, buffers and
  queued exits are order policies. The 2026-06-11 protective-exit gap and the
  2026-09-29 untradable-holdings entry belong to the same arc.

Questions for the homework:

- Where does each layer sit in the pipeline?
- What does each layer record, and which of its outcomes are errors?
- How is each setting declared, shown in the print and entered into
  experiment, sweep and walk-forward identity?
- What happens today to intent the engine could not act on?

The companion entry on sensible defaults (2026-09-29) supplies the rule for
which of these settings get a default.

Requirements from a product review of the same day, weighing the users in
`vignettes/articles/who-ledgr-is-for.qmd`. The intent model suits ledgr's core
users and matches how professional systems separate alpha from execution.
Whether demanding users accept it depends mostly on the first requirement.

1. **Pluggable, not just configurable.** A user can write their own
   step against a typed contract: its input, its output and what it
   records. Built-in steps are defaults, not the only options. Without
   this, a quant who needs their own impact model, turnover or buffer
   constraint, or order policy will put execution logic back into the
   strategy, which is what the model exists to prevent.
2. **Observable.** Every step records what it changed, per pulse and per
   instrument; the north-star RFC calls these audit signals. Professionals
   need the records to trust a step, and learners need them to answer "why
   do I still hold this?".
3. **Identity-bearing and counted.** Every setting is part of run identity,
   and a sweep over execution settings counts as trials in selection
   integrity. Otherwise running the same strategy under different settings
   becomes a new way to overfit.
4. **Visible to the strategy, read-only (open question).** Some strategies
   react to what happened, for example reducing exposure elsewhere when a
   sale did not execute. A read-only view of the last pulse's execution
   outcomes in `ctx` would allow that without the strategy owning the books.
   The homework decides whether it is needed.
5. **The escape hatch stays.** Strategies remain free-form R (design
   philosophy section 2.7). The model removes the need to handle execution
   in the strategy, not the ability to.

Some strategies stay out of reach until the timing and order-management
layers exist: stops and bracket exits (the 2026-06-11 gap), limit and close
orders, partial fills and market impact. The articles should say so, as the
Research To Production shared fact does for live trading.

Until the homework lands, ledgr keeps today's behaviour, and Cut 22 makes it
predictable and documented. `ctx$flat()` is literal: it sells departed
holdings at the next open. A zero target for a halted holding is recorded as
not executed and discarded, not queued, so the holding is sold only when the
strategy states zero again after the halt ends; `ctx$flat()` does that on
every pulse. The helpers keep departed holdings. Increases outside the
universe or on a restricted holding fail with an error.

This entry authorizes no implementation.

### 2026-09-29 [ux] Sensible defaults versus required configuration

Parked on purpose: a full pass could grow into a large change, and nothing
changes before the tag.

The principle stands (maintainer, 2026-09-29): users should not have to
configure dozens of things before they can run an experiment, and every choice
must remain configurable. `ledgr_ux_decisions.md` asks for defaults that are
"informative and opinionated"; `ledgr_design_philosophy.md` section 2.6 asks
that important choices be visible. Visible does not mean required.

The trigger is `valuation_policy = ledgr_valuation_stale(max_sessions = ...)`.
Every availability-aware experiment must supply it, and the contract says the
package supplies no default stale horizon. The same day, Cut 22 decision 3
chose the opposite pattern for departed holdings: a default that users expect,
shown in the print, with the other setting taught.

`ledgr_experiment()` today:

- always required: `snapshot`, `strategy`, `cost_model`;
- required when the run is availability-aware: `valuation_policy`;
- defaulted: `opening` (100,000 cash), `timing_model` (next open),
  `risk_chain` (none), `corporate_action_policy` (research), `features`
  and `execution_mode`; `metric_context` and
  `risk_free_rate` resolve when omitted.

The chore is a rule for deciding which choices get a default and which must be
declared, and then applying it across these arguments and the new
departed-holding setting. Questions the rule has to answer:

- does a default silently move the conclusions a researcher draws, or only
  the numbers they would pick anyway?
- can the default be shown where users look, in the experiment and run print
  and in `ledgr_experiment_plan()`?
- how does a default enter experiment, sweep and walk-forward identity?
- could a currently required choice become a default with a visible note
  instead?

Schema 120 deleted `persist_features`; it is not part of this current default
inventory. Route the surviving defaults rule through the next RFC that proposes
changing an identity-bearing required argument or default. This entry
authorizes no implementation and no argument change.

### 2026-09-28 [ux] Pilot runtime estimates for large experiments

Large sweeps, walk-forward studies, portfolio optimizers and ML-adjacent
strategies may eventually justify a public runtime-estimation command. The
useful product is an execution-backed pilot, not a static promise: run one or
a few representative candidates through the real public path in scratch,
separate reusable preparation from warm orchestration, engine and results
costs, then report a range with its sample, assumptions and largest source of
uncertainty. Prior timings from a matching snapshot, configuration and runtime
environment may reduce the pilot cost.

Sampling disconnected pulses is not generally sound. Stateful strategies need
their preceding pulses, later windows can cost more than early windows, and
rebalance or model-refit pulses may dominate ordinary pulses. The default pilot
should therefore preserve the complete state transition for each sampled
candidate; independent pulse sampling is admissible only under an explicit
strategy contract that makes it valid. The pilot needs a hard time budget,
scratch-only outputs and a clear statement that it executes user code and does
not create completed experiment evidence.

This is low urgency and is not on the v0.2.2 critical path. Promote it only
when real large experiments show that an up-front pilot would save material
time or compute. Because it defines execution, state and side-effect semantics,
promotion requires an RFC rather than a small convenience ticket.

### 2026-09-27 [data] Interval facts cannot express per-endpoint knowledge

An interval fact carries one `knowledge_time` for the whole assertion, so it
cannot express that a start was known earlier while the end was learned later.
Keeping the earlier knowledge time declares an end that was not yet known;
moving it to the later one hides the start information that genuinely was known.
There is no third encoding, because opposing overlapping assertions are rejected
before execution.

**Corrected 2026-09-27 after peer review.** This entry first claimed the engine
applies `effective_to` without a knowledge gate, reading
`R/availability-provider.R:55` in isolation. That stopped one line early:
`ledgr_availability_applicable()` returns `effective & knowable & before_end` at
`:56`, so the end test is conjoined with knowability and never applied on its
own. The prepared builders implement the same joint condition, with `start` as
`pmax(seconds(effective_from), seconds(knowledge_time))` and eligibility as
`start <= cutoff & cutoff < end` (`:85` for membership intervals, `:119` for the
status and lifetime segment builder). A row whose end precedes its knowledge
time is never applicable at all. `contracts.md:354` requires both clocks and
these sites implement that rule faithfully, so there is no runtime causality
defect here. The limitation is the row-level rule itself: one timestamp cannot
carry two separately learned boundaries.

ledgr-research found this independently against real data and ratified a
workaround on 2026-09-14 (SHR-D033): for membership, the interval shape "drops a
member one session before its removal is knowable under the declared lag,
reporting `unknown_no_usable_evidence` for an instrument the source asserts as a
member", and `ledgr_fact_validate_membership_conflicts()` rejects the open-ended
encoding that would have preserved the removal's knowledge time. They prohibited
`ledgr_facts_membership_intervals()` for that universe and moved to
`ledgr_facts_membership_snapshots(complete = TRUE)`, calling it "a correctness
requirement, not a preference between equally faithful encodings."

Successive open-ended assertions are **not** an escape, which the same review
established and which makes the gap worse rather than better.
`ledgr_fact_validate_lifetime_conflicts()` (`R/availability-facts.R:1813`) calls
`ledgr_fact_opposing_state_overlap()`, which compares `effective_from` and
`effective_to` with no knowledge term (`:1693-1695`), so a `known_active`
interval open from January and a `known_inactive` interval open from June are
rejected as an incompatible overlap whatever their knowledge times. Validation
runs at the public constructor (`:343`) and again at sealing
(`R/availability-persistence.R:594`), so the encoding never reaches the resolver
and last-wins ordering cannot rescue it. Membership has the one genuine route, a
later knowable complete set that removes an instrument by omission, and that
needs real complete-set evidence. `lifetime` and `trading_status` have no route
at all.

Practical exposure today is low and not zero. The Sharadar adapter emits
open-ended terminal inactivity and bounded *active* intervals, so it never
produces a bounded inactive interval; a bounded active interval's end only means
"evidence stops here". The reachable cases are hand-supplied facts and any
future adapter modelling a suspension with a known end date.

A second finding belongs with this one, because it explains why nobody hit the
first. Vendor history cannot supply a knowledge clock at all. Research into the
Sharadar documentation established no first-availability or announcement column
in ACTIONS or TICKERS, no archive of dated snapshots or prior row versions, and
`lastupdated` as a last-modified date rather than a first publication - so
filtering `lastupdated <= D` excludes a corrected row instead of restoring its
earlier version. SF1's ARQ/ARY/ART are genuinely as-reported against filing
dates, and DAILY is documented point-in-time, but ledgr's snapshot holds bars
and availability facts with no fundamentals table, so the one place the vendor
does supply two distinct clocks is the one ledgr cannot currently store.

Two consequences worth keeping. The research adapter's `assume_effective`
translation policy is forced rather than chosen, and it is already declared and
surfaced as `assumption_backed / knowledge_assume_effective` with the source
clocks kept in lineage. And ledgr's point-in-time machinery is forward-looking:
a knowledge clock can be accumulated from the operator's own timestamped
captures from now on, but not recovered retrospectively. Every fact family any
current adapter produces has the two clocks coincident.

**Corrected 2026-09-27.** This entry first added that the two-clock paths have
therefore never been exercised against genuinely two-clock data. That is false.
`ledgr_sim_pit_inputs(cases = "halt")` emits a bounded `trading_status` interval
that is effective on one session and knowable two sessions later, and
`tests/testthat/test-sim-pit-inputs.R` asserts `knowledge_time >
effective_from` outright, then runs a fold and reads `ledgr_run_explain()` at
the effective instant, at the knowledge instant and at the interval end to
confirm the halt appears only once knowable. Workstream 18's `LDG-2842`
correction introduced that late-known case on purpose. So the two-clock
resolution path, including the `pmax` start, is exercised end to end by
synthetic fixtures.

Two narrower statements survive. No *adapter* produces distinct clocks, so the
paths are tested against constructed cases rather than against a real vendor's
clock structure, and the first genuinely two-clock vendor family remains an
integration risk. And the `pmax` collapse is lossy only for an off-diagonal
query - column `s` under a cutoff `t > s` - which nothing performs today, so
that loss is latent rather than unexercised for want of data.

Route: its own cycle, once a capture-based or fundamentals-bearing snapshot
exists to exercise it. Until then the release should state the limitation among
its non-claims rather than imply a retrospective point-in-time guarantee.

### 2026-09-26 [research] Fitted imputers after the simple missingness policy

The maintainer's
[historical-projection missingness amendment](rfc/rfc_point_in_time_historical_projection_v0_2_x_missingness_amendment.md)
sets the ML-release direction: simple carry-forward plus missingness
information for prices and indicators. Fitted imputers need a separate design
pass; they must not delay that simple capability. This entry extends the
2026-06-14 "General ML-strategy preparedness" direction and the availability
synthesis's deferred preprocessing obligation. It does not select a fitted
method or assign the ML work a numbered release.

**Fitting regime and information bounds.** Distinguish deterministic causal
treatment, rolling/expanding re-estimation and transformations frozen on a
training set. Define the fit population and cutoff at each outer evaluation and
inner candidate-selection boundary. Fitted preprocessing cannot learn from the
scored test period. A rolling refit has its own admissible history and use
interval; it is not a whole-snapshot fit. Cross-sectional inputs need a declared
point-in-time population, and historical requests retain their simulated
decision-time knowledge cutoff. Missing labels and immature outcomes remain
separate from imputable predictors.

**Composition and delivery.** Support source-domain transformations before
indicators and feature-domain transformations afterward without conflating
their effects. Preserve original missingness, transformed-input provenance,
direct output filling and readiness separately. Models that accept native `NA`
must be able to bypass filling. Review recipe adapters, cross-instrument
dependencies, stable feature schemas and all-missing columns rather than
assuming every transformation fits a per-instrument finite rolling window.
Training export and prediction must share the same declared transformation
semantics at the same information bounds. Generic recipe steps are not proof of
temporal safety; verify their fit and application behavior.

**Artifacts, preparation and replay.** Keep frozen fitted state in the
model/adapter layer and compose its recipe/state identity with ledgr's source,
feature and policy lineage. Reuse the existing ML artifact direction rather
than introducing an imputation registry. Distinguish replay of a stored fitted
artifact from refitting it, including RNG, package versions and declared use
intervals. Prepare work at the declared fit/refit boundaries and cache outputs
where appropriate; ordinary pulse access must not fit a model, query historical
storage or reconstruct a full panel. Inspect memory and worker replication for
multivariate methods before claiming a scalable representation.

**Methods and research usability.** Consider simple training-statistic fills,
nearest neighbours, regression/tree imputers and models with native missingness
through existing R tools such as recipes. More complex reconstruction is not
automatically a better predictor. Compare against the shipped strict and carry
policies, retain missingness information, and examine sample retention and
downstream research results as well as reconstruction error. Keep fitted
algorithm selection explicit and outside the execution fold.

Route: a focused fitted-preprocessing/imputation RFC in the v0.2.x ML design
window, coordinated with the existing ML-architecture and historical-projection
cycles. Its requirements should inform the simple preparation boundary before
that boundary is frozen; its implementation may follow the simple release.
The immediate no-lock-in constraints belong to the amendment's section 4, so
they are not deferred here. Any probe or comparative work follows
`spike_protocol.md`; this entry records direction and authorizes neither a
spike nor implementation.

### 2026-09-18 [ux] Public single-evaluation memory surface

The benchmark-boundary review exposed a product-level gap rather than a missing
engine. `ledgr_sweep()` already runs candidates through the shared fold with the
memory output handler, but its public result is intentionally compact and
candidate-oriented. `ledgr_run()` supplies rich result views only by creating a
durable, reopenable run. There is no public surface for evaluating one strategy
once in memory and receiving rich equity, fills, trades, metrics, diagnostics,
and completion evidence without creating a durable run.

A future RFC should decide whether that workflow merits an explicit ephemeral
evaluation surface, provisionally described as `ledgr_evaluate()` rather than a
memory mode on `ledgr_run()`. The distinction matters: a durable run is an
immutable, reopenable and resumable evidence artifact; an ephemeral evaluation
would be an interactive research object. It may carry snapshot, configuration,
strategy, seed and engine-version identity, but it must not claim durable
archive, resume or reopen semantics. Promotion should reproduce it through
`ledgr_run()` rather than blessing mutable memory state after the fact.

Any such surface must reuse the existing sweep/fold implementation and must not
create a second execution engine. Its case depends on real research ergonomics,
debugging and rich single-evaluation inspection, not on making a benchmark row
faster. Until it exists, peer-comparable memory timing uses the public
one-candidate `ledgr_sweep()` workflow; private fold timings remain internal
diagnostics. This entry is non-binding and is not part of v0.2.0.1.

### 2026-09-15 [infrastructure] Containerized reproducible benchmark laboratory

After the v0.2.0.1 benchmark closeout stabilizes the workload definitions and
phase clocks, consider moving repeatable performance testing into a separate
Docker-based benchmark repository. Its purpose would be twofold: detect ledgr
performance regressions across pinned releases, and run honest peer comparisons
over standardized public or synthetic workflows and data. It would be a
measurement laboratory, not a ledgr package dependency or a public leaderboard.

The ledgr suite should cover representative cold and warm tasks: snapshot build
and seal, durable and in-memory experiments, sweeps, point-in-time availability,
fill- and event-heavy runs, and result materialization. Each image should pin its
base image by digest, language and toolchain versions, package release or commit,
dependency lock, and fixture generator, seed, and content hash. Measured phases
should not require network access. Results should retain the phase clock, host
and container metadata, repeated-run medians and spread, peak working set, and a
compact machine-readable comparison with an accepted baseline release.

Peer images may include quantstrat, Backtrader, Zipline, and a local LEAN engine
where their licenses and installation paths permit reproducible execution. They
should consume the same public or generated market inputs and the closest honest
statement of one strategy and accounting workflow, emit canonical outputs for
parity or documented-difference checks, and use the same cold-versus-warm phase
boundaries. Comparisons must disclose semantic work that is not shared rather
than treating unlike provenance, persistence, or accounting guarantees as equal.

One first-party investigation belongs in that laboratory. The v0.2.0.1 Batch
10 record measured the durable TTR-backed SMA row at 78.21 seconds cold and
49.33 seconds in the engine, while the otherwise matched built-in SMA row took
70.59 and 43.19 seconds. Their 1,260 equity rows, 68,201 fills, and trade record
are exactly identical after normalizing the engine label. This is an
interesting observation, not yet an optimization claim: the peer rows ran once
in a fixed order, and an isolated 1,000-call comparison of the two SMA series
primitives explained only about 0.04 seconds rather than the 6.14-second engine
gap.

The future laboratory should therefore include an order-controlled indicator
path experiment over one reused sealed snapshot. It should compare the native
`ledgr_ind_sma()` path, the benchmark's TTR wrapper, and public
`ledgr_ind_ttr("SMA")`; clear feature caches between arms; alternate or randomize
arm order; repeat in fresh child processes; and separate feature hydration and
preflight from the fold clock. No package optimization, default change, or
performance claim follows unless the difference reproduces and the responsible
mechanism is identified.

Docker can reproduce software environments but cannot make unlike hardware or
contended hosts comparable. Regression interpretation should therefore prefer
same-host release series, quiet-host repetitions, warm-ups, and predeclared
noise thresholds. Licensed Sharadar data, credentials, and paid hosted services
stay outside the repository. Keeping the laboratory separate also keeps peer
dependencies, image weight, and license constraints out of ledgr itself. This
entry records a direction only; it does not authorize creating the repository or
publishing cross-engine rankings before the current benchmark methodology and
v0.2.0.1 closeout have been reviewed.

### 2026-09-14 [research] Spot-crypto readiness and Austrian tax handoff

The old v0.1.9.x crypto-readiness plan was never executed and predates the
v0.2.0.0 point-in-time availability surface. The
[RFC pipeline route](rfc/README.md#spot-crypto-readiness) retains a refreshed
spot-only readiness probe. It asks whether the released
engine can support deterministic, unlevered, long-only spot-crypto research on
one venue and in one quote currency. `inst/design/spike_protocol.md` requires
an executable package probe and one-page findings record before any charter or
RFC prose is written.

The readiness work should exercise fractional accounting, complete 24/7
sessions, availability and valuation gaps, the existing metric and cost
surfaces, and durable research workflows. It must not infer maker/taker state
from coarse bars or claim sub-second execution support. Derivatives, funding,
margin, staking, token events, exchange adapters, multi-currency accounting,
and tax remain outside that spike. The accounting-critical-events RFC remains
the named dependency for support claims involving non-trade crypto economics;
the event-free spot probe may run before that RFC, with a correspondingly
narrow claim boundary.

A separate Austrian private-investor tax-accounting RFC is worth opening only
after the readiness probe and the accounting-critical-events research can
identify the evidence boundary. That RFC should cover crypto and non-crypto
investments together, distinguish tax-law interpretation from ledger facts,
and decide taxable-event classification, lot selection, fee treatment,
withholding, foreign-currency conversion, loss offsetting, and after-tax return
reporting. The crypto spike may report missing inputs for that work, but it must
not implement Austrian KESt or define tax policy. This entry authorizes neither
cycle.

### 2026-09-13 [research] Minimum evidence for annualized summary metrics

Batch 15 of v0.2.0.0 withholds annualized return, annualized volatility, and
Sharpe when recorded completion evidence says a run covers only an achieved
prefix. A separate question remains for complete but very short runs: complete
status establishes that the requested window finished, not that annualization
is statistically meaningful.

A future metrics-policy review should define the minimum evidence required to
print annualized summary statistics, including whether the surface should
withhold, warn, or disclose the observed period count and annualization factor.
That decision must remain separate from completion status and metric-context
cadence. It is not part of the v0.2.0.0 print-honesty correction.

### 2026-06-26 [evaluation] Business-objective completion and robustness arc (deferred from v0.1.9.7)

v0.1.9.7 ships the business-objective eligibility layer (`ledgr_business_objective()`
plus the evidence-only, all-candidates `ledgr_sweep_filter()`) with the seven Pardo
criteria, the diagnostic-threshold criteria, and a strict-lattice `stable_region`
detector. Four threads were held back; they cluster into one future
"business-objective completion / robustness" RFC candidate:

- Objective-filtered walk-forward identity (synthesis D4): letting the objective drive
  walk-forward selection and enter `session_id`. In v0.1.9.7 the objective is
  evidence-only and `business_objective_hash` stays provenance, not identity. Refreshes
  the v0.1.9.6-era objective-filtered deferral notes recorded further below.
- Broader robustness-criterion family: the v0.1.9.7 `stable_region` detector is a strict
  lattice over ordered, full-factorial grids (level-index adjacency, `is.ordered()`
  gate) and fails closed otherwise. Hold-fixed handling of nominal axes, and non-factorial /
  sparse / unordered-categorical grids, would need separate criteria (kNN, normalized-radius,
  Gower, or density / dbscan modes), never a silent broadening of `stable_region()`.
- Public third-party criterion-extension contract: v0.1.9.7 criteria implement an
  internal classed / serializable / hashable step contract; exposing it so users can
  define their own criteria needs a deterministic-hash rule for user logic (stable
  criterion id plus serializable params plus a pure evaluate function), function / S3
  based, not R6.
- Scored / weighted objective composition: v1 is all-pass (AND); a scored composite is
  the synthesis's named future additive.

The trade-distribution criteria (`even_trades`, `even_profit`, `stable_runs`) and their
closed-trade retention extension were pulled into v0.1.9.7, so they are no longer
deferred. Routing: a dedicated RFC when this arc opens, after the v0.1.9.8 talib
adapter; it extends the accepted D2 / D4 contracts in the validation-toolkit synthesis.
This entry authorizes nothing.

Related v0.1.9.7 closeout deferrals remain separate from that four-part RFC:
Triple Penance stays gated on original-paper verification; cadence-aware
walk-forward short-window warnings and the bounded intraday example stay with
the later intraday RFC; purging/embargo/CPCV, portfolio optimization,
point-in-time data, and benchmark-relative metrics need their own substrate;
and OMS, broker reconciliation, paper/live trading, and liquidity/capacity
remain later execution-policy work. The talib adapter, crypto-readiness spike,
target-helper Pass 2, and strategy schedule decorator retain their separately
planned homes rather than entering this release.

### 2026-06-14 [architecture] General ML-strategy preparedness (QRF ranking as the motivating spike)

Goal: a general architectural substrate for supervised-ML trading strategies,
not a single model. The motivating case is a cross-sectional
quantile-regression-forest (QRF) ranking strategy -- target is the within-date
percentile rank of forward N-day return, the model is a QRF over today-known
features, the score is predicted median rank or `P(rank >= 0.8)`, and the
portfolio is long-top / short-bottom -- but this entry scopes the capability,
with QRF as the first spike that stress-tests it.

The part that makes ML ledgr-shaped is not the model (ranger / glmnet / xgboost
do that, and Python does it better) but the discipline around it: leakage-safe
training data and reproducible model artifacts. "ML without fooling yourself" is
the brand applied to ML, and it is exactly what most ML-backtesting tutorials
get wrong. That framing also fixes the boundary: ledgr owns the substrate and
the temporal discipline; the model library stays in the user / adapter layer.

Architectural requirements (the RFC surface):

- Leakage-safe training-panel export: materialize the historical
  `(instrument x ts) x features [+ label]` panel as a training matrix with
  strict as-of cutoffs. Today features are per-instrument series accessed at
  pulse time; training needs the flat labeled panel.
- Forward-looking label construction with horizon embargo: supervised targets
  are built from future data (forward return, future rank, future volatility,
  class labels) and are training-only. The label-availability lag is
  load-bearing: a model deployed at t may train only on labels whose realized
  outcome is fully earlier than t. An N-day horizon means the most recent usable
  label is from t-N; training to t leaks N days of future. This embargo must be
  enforced structurally, not left to user discipline. A cross-sectional rank
  label is additionally relative to the date-t ELIGIBLE UNIVERSE as it existed at
  t (not today's survivors): point-in-time universe / eligibility membership is
  part of the label/panel contract, because anachronistic universe construction
  is the biggest rank-target leakage in practice.
- Sample uniqueness / overlap weighting: overlapping forward labels make training
  rows non-independent. The engine can export optional overlap / concurrency
  weights derived from the label intervals, but whether to export them or leave
  weighting policy entirely to the adapter is an open RFC decision; default to
  adapter-side policy until a concrete use case justifies engine standardization.
- Model-as-artifact identity: fitted models become version-addressed, hashed,
  auditable artifacts -- hash the training recipe (data window + feature set +
  hyperparameters + seed + environment lock), store the blob, and replay from the
  stored artifact (recipe rebuild is exact only in a frozen environment; see the
  determinism note). Extends the snapshot / cost-plan / risk-plan identity
  pattern to models.
- In-loop / walk-forward refit semantics: refit at intervals on pulse-known
  history and deploy forward until the next refit. This is distinct from the
  v0.1.9.4 walk-forward, which selects candidates by metric; model retraining
  inside the loop is a different mechanism and the RFC must keep the line clean.
- External-model adapter boundary plus a prediction hook: ledgr hands the model
  leakage-safe pulse features and consumes predictions to form targets; it never
  reimplements a model library. Same posture as the PerformanceAnalytics / pbo
  adapters.
- Cross-sectional feature support: ranking / normalization across the universe
  at a pulse. Mostly expressible today via the pulse context; confirm rather
  than build.

Tooling for the artifact / serving contract -- vetiver + pins. Do not
reimplement an MLOps registry. The Posit stack (`pins` for versioned artifact
storage; `vetiver` for model packaging, plumber serving, and drift monitoring on
top of pins) is the R-native storage / versioning / serving layer for the model
artifact. It is not a full experiment/dataset-lineage registry by itself -- it
does not own the training-panel manifest, label recipe, or experiment lineage;
that lineage is ledgr's job. Boundary: ledgr's content-addressed recipe hash is
the identity of record (it captures the snapshot hash, feature manifest, label
recipe, purge/embargo policy, hyperparameters, seed, and environment lock);
`pins` is the versioned storage backend. A refit is recorded as an event in a
new typed model-artifact stream -- NOT in the accounting `ledger_events` table,
which stays scoped to FILL / FEE / CASHFLOW execution evidence -- and that event
references the pin version and carries the recipe hash. Write the recipe hash
into the vetiver/pins metadata so the artifact carries ledgr identity -- do not
let the pin version become the model identity, since it does not see the
training-panel / label / snapshot lineage. Two same-contract payoffs: the model
pinned during backtest is the same artifact vetiver serves in paper / live (no
reimplementation on the deployment side), and vetiver's input prototype
(`ptype`) doubles as the pulse-feature schema contract (requirement 5). Posture:
`Suggests`, not `Imports`; keep the core artifact contract storage-agnostic (a
pin board is one backend, a plain file another); verify maintenance / license at
packet-open (vetiver MIT, pins Apache-2, both permissive and actively
maintained).

Determinism -- replay from the stored artifact, not reconstruction from the
recipe. Event-sourced replay implies determinism, but learners are stochastic
(seeds, thread counts, platform, CPU vs GPU), so re-running a recipe does not
guarantee the same fitted model. Separate three guarantees: (1) replay is exact
from the stored, version-addressed model artifact -- the bytes are kept, so the
deployed model is always recoverable; (2) the recipe hash + lineage is always
auditable -- you know exactly how the model was made; (3) reconstruction from
the recipe to byte-identical weights is best-effort, achievable only under a
frozen environment (pinned `renv` lockfile, fixed adapter code, seed, thread
count, deterministic algorithm/backend). ledgr's strong ML guarantee is
therefore stored-artifact replay plus recipe-level audit; bitwise rebuild is
reserved for pinned environments. This is the one place the same-contract /
deterministic-replay premise must explicitly weaken for ML: "same model" means
the same stored artifact, not a guaranteed identical retrain.

Open design question -- the feature-engineering boundary. Where each feature
transform lives (ledgr indicators, tidymodels recipe steps, or user code) is
open and the RFC must resolve it. Organizing principle: train/predict parity --
a feature must have the same value in the training panel and at the live pulse,
or you get training-serving skew. The boundary is the FITTING REGIME, not the
transform type:

- Causally re-estimated: parameters recomputed from a trailing or expanding
  window at every point, never frozen across a train/test split (rolling
  z-score, rolling volatility, causal expanding-window PCA). These produce the
  same value in training and at the pulse by construction. -> ledgr indicators /
  the engine, computed once and shared between the training-panel export and the
  pulse payload. Leakage-safe and parity-correct for free.
- Frozen-on-train: parameters estimated once on the training set and applied
  unchanged to all future rows (`step_normalize` mean/sd, a PCA basis fit once,
  target encoding). The frozen state is part of the model recipe, and the
  prep-on-admissible-history / bake-on-pulse split is the leakage control. ->
  tidymodels recipe in the adapter. ledgr supplies admissible history for
  `prep()` and the pulse payload for `bake()`; it does not own the fitted state.
- Forward-looking targets belong to the label-availability export, never the
  feature path.

The same math can live in either place: a z-score frozen on the training window
is a recipe step (and a leakage risk if mis-windowed); the same z-score over a
causal rolling window is an indicator. So a user does not declare a feature
"type" -- the user declares its fitting regime, and that declaration both routes
the feature and determines which identity hash it flows through. The model
recipe hash composes ledgr's feature-manifest hash (causally-re-estimated
indicators) with the adapter's fitted-recipe hash (frozen-on-train steps).

Two sub-questions stay genuinely open. First, cross-sectional support is the
real gap: ledgr indicators are per-instrument time series today, but a
within-date rank or cross-sectional z-score is computed across the universe at a
date. Parity says it should be engine-computed (so train and pulse agree), but
it does not fit the per-instrument `series_fn` shape -- so does the indicator
system grow a first-class cross-sectional feature kind, or do within-date
transforms live in the adapter as stateless-per-date steps. The QRF ranking
spike presses on exactly this. Second, out-of-band enforcement: how ledgr keeps
users from computing leaky features in raw code outside both systems (the "give
me a tibble and trust the user" anti-pattern the research flags) by making the
leakage-safe path the path of least resistance -- a UX/contract problem more
than a data-model one.

Dependency gates (why this is not a v0.1.9.x item):

- The temporal-CV / embargo / purging machinery is the prerequisite. It is
  explicitly deferred out of v0.1.9.6 (non-scope) and is a later
  validation-toolkit increment. ML leakage discipline reuses it directly; ledgr
  must not ship ML training that cannot express it.
- Feature-store maturity: the training-panel export depends on the DuckDB
  feature store, which is not yet feature-complete.
- Model-artifact identity design: extends the existing identity surface and
  needs its own contract.

Sequencing:

- Now: this seed.
- Spike first, no architecture change: prototype the QRF ranking strategy as
  user-layer code on current ledgr -- train ranger outside, inject the frozen
  model as a `param`, predict per pulse on pulse-known features, enforce the
  train/test split by hand. Like the PBO spike, it surfaces the real ergonomic
  and leakage pain and feeds the RFC concrete requirements instead of
  speculation. It doubles as a dogfood of feature-access ergonomics.
- RFC after the embargo machinery lands; v0.2.x earliest; likely its own design
  arc given the size.

Scope guard: this entry authorizes no implementation. ledgr stays
model-agnostic -- no bundled model library, no reimplemented learners. The
capability's value is the leakage-safe substrate and reproducible artifacts, and
it is gated on prerequisites that do not yet exist.

Related: the validation-toolkit temporal-CV / embargo increment (deferred from
v0.1.9.6); feature-store / DuckDB maturity; the snapshot / cost-plan / risk-plan
identity pattern; the walk-forward machinery (v0.1.9.4, candidate selection --
not model refit); the standing leakage discipline and the "research-loop
leakage" non-guarantee in the leakage vignette.

### 2026-06-13 [architecture] Async I/O belongs at the live edge, not the kernel

Live and paper execution introduce concurrent external I/O for the first time:
market data, order acknowledgements, fills, rejects, and heartbeats all arrive
asynchronously and interleaved. The backtest kernel must stay synchronous,
deterministic, and replayable. The live adapter's job is to serialize the async
event stream back into the same ordered, whole-second-stamped event log the
backtest already consumes. If async ordering reaches the kernel, replay and
backtest/live parity are lost. This is a boundary commitment, not a feature.

Dependency posture: `mirai` is already a direct Import for parallel sweeps, and
`nanonext` (the NNG socket binding) is already transitive underneath it.
Promoting `nanonext` to a direct edge dependency when live arrives is not a new
dependency family. Candidate edge stack to evaluate at adoption time, all
non-binding: `nanonext` for persistent broker/data sockets, `promises`/`later`
for the event loop, `websocket` for live feeds, `httr2` async for REST broker
APIs.

Scope: this is I/O concurrency at the adapter edge, a distinct axis from
backtest compute parallelism, which remains single-core-first. No engine async
is authorized before the v0.2.x OMS and v0.3.0 paper packets. The prep work that
is in scope now is free: keep the kernel synchronous and serializable so the
live adapter can bolt onto the event log without reaching into the loop.

Related: the roadmap OMS prerequisite (v0.2.x) and paper adapter (v0.3.0); the
targets-not-orders boundary and OMS-at-the-edge discipline; the standing
single-core-before-parallel stance, which this entry does not revisit.

Non-commitments: no package selection is fixed; no live or paper work is
authorized; the candidate stack is an evaluation list for the v0.2.x/v0.3.0
window, not a dependency decision.

### 2026-06-13 [execution] Decide whether compiled spot-FIFO should become the default

**Status update 2026-06-15:** v0.1.9.6 did not flip the default and the
current-surface peer benchmark redo did not authorize a default change. The
compiled spot-FIFO path remains an explicit opt-in pending a separate spike and
RFC cycle.

The compiled spot-FIFO path is currently an explicit opt-in, not default
execution. That is the right state until a fresh measurement spike and RFC
cycle decide otherwise. The default path is user-facing semantics, not merely a
performance toggle: even if the event stream is intended to remain identical,
changing the default accounting implementation changes the path most users
exercise, the failures they see, and the platform matrix that must be trusted.

Candidate next-packet shape:

- run a focused measurement spike comparing canonical R accounting versus
  `compiled_accounting_model = "spot_fifo"` on current v0.1.9.x workloads;
- include parity checks for fills, ledger events, trades, equity, metrics,
  sweep summaries, retained return panels, saved/reopened sweeps, walk-forward
  sessions, and promotion-ready candidates;
- measure failure and fallback behavior when compiled symbols are unavailable,
  unsupported accounting shapes appear, or the workload is non-spot;
- separate three possible defaults: keep opt-in; default only for ephemeral
  spot sweeps; default for all supported spot execution surfaces;
- assess Windows/macOS/Linux CI confidence, CRAN/installation consequences,
  package-size or toolchain risks, and whether the default would still preserve
  one execution semantics rather than creating a second practical engine;
- use the RFC synthesis to bind the default, fallback, error-class,
  documentation, release-gate, and rollback rules before any implementation
  ticket changes defaults.

The spike should be measurement-first. The RFC may decide that the right answer
is "do not make it default yet." Default compiled execution, durable compiled
integration beyond the already scoped surface, non-spot accounting, and a
general compiled fold core remain unauthorized until that RFC is accepted and a
versioned packet cuts implementation tickets.

### 2026-06-13 [risk] User-defined cost and risk steps: extensibility against the identity and bounded-stance constraints

Raised during the v0.1.9.5 risk-and-cost vignette work: should ledgr give
users tooling to build their own cost and risk steps, beyond composing the
built-in allowlist?

First, a distinction the "More steps are planned" vignette callout blurs.
Shipping more **built-in** steps (the closed allowlist grows, ledgr owns and
serializes each step) is different from **user-defined** steps (the user
supplies the function). The callout promises the former; this entry is about
the latter.

The precedent exists. Indicators are already user-extensible via
`ledgr_indicator()` + the `series_fn` contract + `ledgr_indicator_register()`
/ `ledgr_indicator_dev()` + the custom-indicators vignette, with feature
fingerprints preserving identity. Custom cost/risk steps would reuse that
machinery, not invent it.

The crux is identity. Cost and risk are hash-bearing: `cost_plan_json`,
`cost_model_hash`, and `risk_chain_hash` are consumed downstream by sweep
persistence and walk-forward candidate/session identity. A built-in step
serializes to canonical `{type_id, args}`; a user closure needs
source-capture plus fingerprinting (as strategy source already does) and its
tunables forced through `ledgr_param()` so they land in the plan JSON. This is
the hard 80 percent of the work. Cost is heavier than risk because its
identity surface fans out across more consumers.

The bounded-stance tension is the deeper issue. The v0.1.9.5 risk-and-cost
vignette now teaches a sharp boundary -- risk is not portfolio optimization,
cost is not liquidity or capacity. An open function interface is the backdoor
through which a "risk step" becomes a solver and a "cost step" becomes a
market-impact model, making the deliberately bounded layers unbounded.
Indicators do not have this problem (any feature is fair game); cost and risk
are narrow on purpose. Any extensibility RFC must answer this with a
constrained contract (pure `targets -> targets` for risk; pure
`(proposal, fill_context) -> price/fee` for cost) plus preflight-style tiering
to fail closed on non-deterministic or lookahead-violating steps.

Recommended sequencing (a recommendation, not a decision):

- **Risk-step extensibility is the more natural first member.** A custom risk
  step is a strategy-shaped pure transform with `ctx` access, and the real
  long tail (sector caps, turnover, vol-targeting, gross/net exposure) is
  legitimately target transforms.
- **Cost-step extensibility is heavier; expand the built-in vocabulary
  first.** Tiered/maker-taker fees, borrow cost on shorts, and simple slippage
  are a finite set that may cover most demand without source-capture. A
  user-defined-cost API only if built-ins prove insufficient.

Related horizon entries: 2026-06-09 [risk] Palomar risk-chain constraint
expansion (the built-in convex-constraint track); 2026-06-07 portfolio
optimization scaffolding (solver dispatch); 2026-06-09 [ux] weight-strategy
wrapper (authoring surface).

Non-commitments:

- not a roadmap commitment; no public API is bound;
- the constrained-contract and preflight-tiering sketches are illustrative;
- the risk-first / cost-built-ins-first sequencing is a recommendation, not a
  resolved fork.

### 2026-06-13 [risk] Portfolio optimization placement: optimizers emit intent, but optimization is risk-flavored

Maintainer note (2026-06-13) while reviewing the risk-and-cost vignette.
Portfolio optimization is planned as a first-class capability (see the
2026-06-09 Palomar adapter family and 2026-06-07 portfolio optimization
scaffolding entries). The maintainer leans toward placing a full optimizer in
the **strategy** layer rather than the risk step, because an optimizer outputs
an intent -- target weights or holdings -- which is the strategy's job. But
many portfolio-optimization algorithms (mean-variance, minimum-variance,
risk-parity) are inherently about risk, which muddies the sharp
strategy-is-intent / risk-is-constraint distinction the vignette now teaches.

The resolution is to notice that the word "risk" is doing double duty:
risk-as-constraint-layer versus risk-as-optimization-objective. Those are
different things. A coherent architecture keeps them separate:

- the risk **chain** stays a post-intent constraint transform (what am I
  allowed to hold?), and the "risk is not portfolio optimization" boundary in
  the vignette holds verbatim;
- an **optimizer is a strategy** that produces intent, even when its objective
  is risk-derived. Its natural authoring home is the weight-strategy surface
  (2026-06-09 [ux] entry), which already outputs weights as strategy intent.

That preserves the four-layer model instead of breaking it: optimization is
intent generation that happens to use risk math, not a new optimization layer
bolted onto the risk chain.

What still needs design before the v0.2.x optimization arc:

- **Where do convex constraints live when an optimizer is the strategy?**
  Inside the optimizer's objective (the strategy), still as a post-hoc risk
  chain, or both. This interacts directly with the Palomar entry's
  convex-as-risk-step versus solver-dispatch fork.
- **Doc reconciliation.** The vignette's "risk is not portfolio optimization"
  line likely needs a companion sentence clarifying that an optimizer is a
  strategy whose intent is risk-derived, so readers do not conclude
  optimization is unsupported.
- **Vocabulary.** Avoid letting "risk step" and "risk objective" collide in
  the public API surface.

Recommendation: do not flip the risk chain into an optimization layer; place
optimizers as intent-producing strategies via the weight-strategy authoring
surface; reserve the risk chain for post-intent constraints; reconcile the
vignette framing when the optimization capability is scoped. This is the key
placement/vocabulary fork for the v0.2.x portfolio-optimization arc, named here
but not resolved.

Related horizon entries: 2026-06-09 [risk] Palomar risk-chain constraint
expansion; 2026-06-07 portfolio optimization scaffolding; 2026-06-09 [ux]
weight-strategy wrapper; and the v0.1.9.5 risk-and-cost vignette as the
bounded-layer framing to reconcile.

Non-commitments:

- not a roadmap commitment; no public API is bound;
- the optimizer-is-a-strategy placement is a recommendation, not a resolved
  decision;
- the constraint-placement and doc-reconciliation items are open design forks.

**Status update 2026-10-05: history-first research UX.** The v0.2.2 research
strategy UX discussion sharpened this later RFC's inputs without advancing its
trigger. The public history object should retain instrument identity through
the estimator boundary. A turnover-aware optimizer needs an authoritative
current-weight helper whose denominator, cash, reserved exposure, held
nonmembers, stale and frozen marks and rounding semantics are not yet bound.
Those questions belong here after causal history ships; they must not be
smuggled into the v0.2.2 representative minimum-variance proof.

The placement conclusion is now clearer: constraints that define an optimum
belong inside the allocation model, while the target-risk chain independently
enforces post-intent limits. A constrained solution followed by the same hard
risk guard is not duplication; solving unconstrained and clipping later is not
equivalent. The Tidy Finance 120-period constrained-backtest workflow is a
useful future acceptance scenario. The active non-binding narrative is
`ledgr_v0_2_2_spec_packet/research_strategy_ux_brief.md`.

**Status update 2026-10-05: Schur frontier-method exercise.** Schur
complementary allocation fits the intended boundary without a Schur-specific
engine surface: causal return history, an identity-preserving matrix adapter,
an ordinary batch estimator, identified weights, then ledgr-owned targets,
execution and accounting. Its damping parameter and lookback are ordinary
candidate parameters; selecting them and reporting them on the same interval
would still be selection leakage.

The exercise exposed one general allocation question. Dropping an instrument
from an estimation matrix because its history is incomplete is not the same as
assigning it a zero target. The later portfolio-construction RFC must bind an
explicit keep, liquidate or refuse policy for omitted held instruments and
decide whether bare `ledgr_weights` remain sufficient or a small allocation
result must also carry exclusions and deterministic model diagnostics. The
history implementation owns included IDs, excluded IDs and exclusion reasons;
it does not choose the execution consequence.

Park the method integration itself behind that RFC trigger. Compare a native R
implementation with a locked adapter to the maintained external implementation,
require parity evidence, and preserve requested versus effective damping when
the implementation can cap it. External runtime provenance belongs to the
research adapter. None of this makes Schur, a Python bridge or a generic method
catalogue a v0.2.2 commitment.

### 2026-10-05 [strategy] Declared source bundles for reusable user strategy helpers

The strategy tier model currently leaves a usability cliff. An unqualified
user helper outside `function(ctx, params)` is Tier 3 and refused. Nesting the
helper inside the strategy makes its source capturable but prevents ordinary
reuse; putting every emerging estimator in a package is safe but premature.
The v0.1.7.2 strategy specification anticipated `strategy_helpers` and
deliberately deferred it until parallel sweeps made dependency transport a
real product concern. That prerequisite now exists.

Park a focused post-v0.2.2 RFC for an explicit strategy source bundle. Its
candidate UX is a strategy entry function plus a named list of user functions.
The mechanism must capture and hash every helper's source, recursively
preflight declared dependencies, include the bundle in strategy identity,
store and recover the complete source set, reconstruct the same private
environment for ordinary runs, resume and parallel workers, record qualified
package dependencies, and reject undeclared functions and mutable closure
state. Serializing an arbitrary closure environment is not an acceptable
shortcut.

This is independent of portfolio optimization. The constrained-optimization
example exposed the gap, but indicators, schedules and other substantial
strategies can need the same reusable pure helpers. The RFC should therefore
remain a strategy reproducibility and transport cycle, not become an optimizer
API. It is explicitly outside v0.2.2.

Non-commitments:

- no public constructor name or helper-bundle syntax is bound;
- no Tier 1 promotion occurs until source recovery and worker parity are
  proven; and
- this entry does not authorize function objects in JSON strategy parameters
  or arbitrary environment capture.

### 2026-06-13 [ux] Walk-forward fold visualization helper and plotting dependency posture

The v0.1.9.5 walk-forward article added an article-local ggplot timeline that
made the train/test window contract much easier to inspect: blue train sweep
window, green selected-candidate test run, and a thin selection-boundary line.
That is a real UX signal, not just decoration. Users need a fast way to see
whether fold windows, step sizes, anchored/rolling behavior, gaps, and overlap
match what they intended before they trust walk-forward output.

Potential future surface:

```r
ledgr_plot_folds(folds)
ledgr_plot_folds(walk_forward_result)
```

This should stay non-binding until a visualization / reporting surface is
scoped. Open design choices:

- whether ledgr exports plotting helpers at all, or keeps returning plain data
  frames and teaches plots in articles;
- whether `ggplot2` stays in `Suggests` with `rlang::check_installed()` at
  plotting entry points, or becomes a core dependency because plotting and
  tables are part of the expected research workflow;
- whether interactive output such as `plotly` belongs only in optional adapter
  surfaces rather than core;
- whether the first plotting family is folds only, or includes equity curves,
  drawdowns, sweep heatmaps, degradation tables, retained-return panels, and
  run-inspection tear sheets;
- whether plotting helpers return ordinary `ggplot` objects so users can add
  themes, scales, and labels without ledgr owning a closed charting system.

Current bias: native ggplot helpers are likely the right R-native default once
visualization is scoped, with optional adapters for richer or interactive
surfaces. That does not imply promoting `ggplot2` to `Imports` yet. Treat the
dependency posture as part of the future visualization/reporting RFC, alongside
table output and the existing external-package adapter plan.

### 2026-06-12 [evaluation] Per-fold train-sweep PBO column in the walk-forward degradation table

Parked at maintainer request during the validation-toolkit D1 resolution
(2026-06-12): "honestly pretty interesting in its own right."

Every walk-forward fold runs a sweep internally -- the train-window
sweep IS the selection event. Once two predecessors land, CSCV/PBO can
run per fold on each train window's candidate return panel, yielding a
per-fold selection-fragility score surfaced as a degradation-table
column (indicatively `train_pbo`):

```text
fold_seq  selected     train_metric  test_metric  train_pbo
1         fast_10_40   1.31          0.94         0.18
2         fast_10_40   1.42          1.10         0.22
3         fast_5_20    1.55          1.21         0.81   <- distrust:
                                                            winner came
                                                            from a noisy
                                                            selection
```

The degradation table then carries not just IS -> OOS metric drift but
the trustworthiness of each fold's selection event. Diagnoses two
things nothing else surfaces: folds whose good test results came from
fragile selections (lucky picks from noise), and regime windows where
the candidate space loses structure (train_pbo rising across
consecutive folds is a regime-shift signal on the SELECTION layer, not
the returns).

Dependencies, in order:

1. **Validation toolkit ships** (in-flight cycle): the CSCV/PBO
   machinery over retained panels, per the D1 A-prime resolution --
   sweep-level PBO is the per-fold building block.
2. **Walk-forward `fold_seq` return retention** (the deferred half of
   the original Option A; recorded fast-follow of the toolkit cycle):
   per-candidate per-period returns per train window.
3. **Degradation-table extension**: Amendment 2 Section 16.5 binds the
   operational table fields; adding `train_pbo` is additive but the
   print contract should be extended deliberately (small amendment or
   an additive-columns allowance), not silently.

Indicative slot: a small evaluation tick after the validation toolkit
ships, bundled with the `fold_seq` retention fast-follow it depends on.

Non-commitments: not a roadmap commitment; no public API or column name
bound; the sketch is illustrative; per-fold PBO interpretation caveats
(few folds, short train windows -> wide PBO uncertainty) are a design
question for the eventual cycle, not assumed away here.

### 2026-06-11 [strategy] Unscheduled strategy-family gaps: intra-bar exits, lot-selection policies, time-accrual costs, and the unscoped shorting contract

A 2026-06-11 sweep of the horizon, roadmap, and RFC corpus against a
strategy-family taxonomy asked: which strategy classes are neither
architecturally supported nor scheduled for an RFC? Most families are
covered, deliberately excluded, or already parked (weight strategies,
ML-first, portfolio optimization, multi-strategy allocation, PIT
regressors, derivatives/futures/FX under the non-spot umbrella, ragged
universes, crypto spike; intraday/HFT is a permanent non-goal). Four
genuine gaps remain. This entry parks them with routing so the relevant
future cycles inherit them instead of rediscovering them.

### Gap 1 -- Intra-bar protective-exit semantics (the stop-loss family)

The largest unscheduled family. Strategies whose definition includes hard
intra-bar exits -- trend-following with stops, breakout strategies with
bracket exits, take-profit and trailing-stop families -- cannot be
expressed honestly today. Pulse-granularity approximation (observe breach
at close, exit at next open) is a materially different strategy when the
economics live in the stop discipline. The pieces exist around the gap:
OHLC bars support the standard conservative intra-bar trigger simulation
(worst-case fill within the bar range); the execution-policy north star
(`rfc/rfc_execution_policy_pipeline_audit_signal_north_star.md`) has an
"order policy / sizing" pipeline stage where this belongs; and the
2026-06-07 MAE/MFE excursion entry plans stop *calibration* analytics
with no stop *execution* semantics to calibrate for. The OMS synthesis
correctly keeps strategies as target-vector functions, which means
protective exits must be an execution-policy declaration, not strategy
code -- and that declaration surface is undesigned.

**Routing:** scope inside the execution-policy pipeline arc (order-policy
stage), not as a fresh seam. Conservative intra-bar fill bounds and their
determinism contract are the core design questions.

### Gap 2 -- Lot-selection and tax-aware accounting policies

FIFO is hardcoded into both accounting paths (it is in the kernel's
name). Strategies and workflows that depend on which lots close -- HIFO,
specific-lot identification, tax-loss harvesting -- are unsupported and
appear nowhere in the corpus. The closed accounting enum's error message
says future accounting models require a separate RFC, but no entry
records lot-selection policy as a candidate family. For the retail / PM
audience, tax-aware rebalancing is a strategy class, not an accounting
nicety.

**Routing:** the accounting-model RFC family (the same seam the closed
`compiled_accounting_model` enum reserves). Lot-selection policy is an
accounting-policy axis orthogonal to the compiled-vs-canonical axis; an
RFC must decide whether policy is per-run identity (hash-bearing) and
how R/C++ parity extends to non-FIFO policies.

### Gap 3 -- Time-accrual cost events (interest, borrow, funding)

The cost API is fill-event-based by design: costs resolve on accepted
fill proposals. An entire cost family accrues on balances over time
instead: interest on idle cash, borrow fees on short positions,
perpetual-futures funding payments, margin interest. No entry names the
accrual family, and two scheduled items collide with it head-on: the
crypto-readiness spike (perps are economically defined by funding
payments) and the shorting gate (short backtests without borrow costs
systematically flatter every market-neutral result). This is an
event-grammar question -- a ledger event type driven by time rather than
fills.

**Routing:** the v0.2.x "explicit accounting-critical event types" RFC
is the natural home; the crypto-readiness spike and the shorting
contract RFC (Gap 4) must both name it as a dependency when they open.

### Gap 4 -- The shorting/leverage contract RFC is a gate without a seed

Referenced three times as a predecessor gate (long-short authoring
helpers; Palomar dollar-neutral / market-neutral / leverage
constraints), but it has no entry of its own scoping what it must bind.
The engine mechanically tolerates negative targets and the FIFO kernel
already handles short lots correctly, so the temptation will be to
"just allow it" -- when the actual contract questions are: short
proceeds cash treatment, borrow availability and cost (Gap 3), margin /
maintenance semantics for equities distinct from the derivatives arc,
and what `ledgr_risk_long_only()` defaulting means once shorting is
legal. Risk if left unscoped: v0.2.x Palomar constraint scoping arrives
and finds its named predecessor is an empty pointer. Pairs / statistical
arbitrage -- a headline strategy family -- sits entirely behind this
gap plus Gap 3.

**Routing:** give the shorting/leverage contract RFC its own seed-shape
entry (or seed) before v0.2.x Palomar constraint scoping begins; bind
the Gap 3 dependency explicitly in that seed.

### Non-commitments

- this entry authorizes nothing; it records gaps and routing;
- no public API, event schema, or accounting semantics are bound here;
- gap priority ordering is left to the cycles that consume them
  (execution-policy arc, accounting-model RFC family, accounting-event
  RFC, v0.2.x Palomar scoping);
- "not scheduled" claims are as of 2026-06-11; sweep this entry against
  the corpus before citing it in a future packet.

### 2026-06-11 [adapters] Canonical run return stream before reporting adapters

The v0.1.9.2 retained-sweep surface gives sweeps a canonical return-series
projection through `ledgr_sweep_returns()` and `ledgr_sweep_returns_wide()`.
Single committed runs do not yet have the symmetric result view; users derive
adjacent returns manually from `ledgr_results(bt, what = "equity")`.

This is an API ergonomics gap, not an execution gap. Preferred shape as of
2026-06-14 is a `ledgr_results()` result-table extension, not a standalone
helper:

```r
ledgr_results(bt, what = "returns")
```

It should return the canonical single-run portfolio stream:

```text
ts_utc
equity
period_return
```

Design constraints if promoted:

- do not invent a second return formula; consume the same equity / adjacent
  return semantics used by `ledgr_compute_metrics()` and retained sweep
  returns;
- keep metrics out of the result-table surface: `ledgr_results()` remains
  evidence tables, `ledgr_compute_metrics()` remains metric values, and this
  view is only the canonical return stream;
- use `period_return` to match sweep retention naming;
- keep standalone helpers such as `ledgr_returns(bt)` or
  `ledgr_run_returns(bt)` deferred unless a later UX review finds a stronger
  reason than result-table symmetry;
- keep this separate from first-class position / exposure time-series helpers,
  which imply larger semantics around weights, shorts, leverage, margin,
  missing prices, multi-currency, and later derivatives;
- keep this out of v0.1.9.4 unless a walk-forward ticket explicitly promotes
  it. Walk-forward can continue to use internal score rows and retained test
  run artifacts without adding a new public return API.

Relationship to existing roadmap entries:

- this is a likely predecessor seam for the v0.2.x PerformanceAnalytics /
  external-package adapter work, where adapters should consume ledgr's own
  canonical return stream rather than reimplementing return math;
- this does not commit to a tear sheet, charting API, `what = "metrics"`,
  position-level result table, standalone returns helper, or adapter package.

### 2026-06-09 [research] Selection-session archive / evaluation registry is parked, not committed

Discussion around a snapshot-scoped "candidate graveyard" surfaced a real
future substrate idea but not a current product commitment. The strong version
is not a generic auto-persisted table of every evaluation keyed only by
`snapshot_hash`; it is a selection-session archive that records which
candidates were considered together, under which scoring / validation protocol,
on which snapshot, slice, fold, metric context, cost model, risk chain, and
seed surface.

Possible future use:

- reopen the research decision that produced a promoted run;
- support selection-integrity diagnostics that need the candidate family and
  validation protocol, not just the winning candidate;
- connect walk-forward sessions, retained sweep evidence, and promotion
  lineage into one inspectable audit trail;
- preserve enough trial-count evidence for later PBO / CSCV / DSR style
  diagnostics without pretending provenance itself proves statistical validity.

Reasons not to promote now:

- user demand for an explicit evaluation registry is speculative;
- v0.1.9.2 already provides explicit sweep persistence for saved exploratory
  evidence;
- v0.1.9.4 walk-forward should first establish the operational session shape;
- auto-persisting scalar evaluation rows by default would change ledgr's
  side-effect model and create cleanup, schema, privacy, migration, and
  parallel-write obligations;
- snapshot-level row accumulation can overstate selection families by mixing
  unrelated research sessions against the same data.

If this comes back, the entry point should be a dedicated RFC after the
walk-forward MVP and first selection-diagnostics scoping work. The RFC should
start from session identity rather than snapshot identity, make persistence
defaults explicit, and decide whether the feature is an index over existing
sweep / walk-forward artifacts or a new always-on write path. Until then,
existing packets should only preserve identities and promotion lineage that keep
such an archive possible later.

### 2026-06-09 [research] ML-first capability shape for v0.2.x

A 2026-06-09 review of whether ledgr is usable with ML models concluded the
existing strategy contract, walk-forward windowing, sweep candidate identity,
and feature path are sufficient for a useful class of ML strategies today:
pre-trained model loaded into closure, `predict()` called per pulse,
hyperparameter sweeps under future PBO / CSCV / DSR correction. That is enough
to honestly describe ledgr as ML-compatible. It is not enough to describe ledgr
as ML-first.

Closing the gap needs four pieces named explicitly so a v0.2.x packet can scope
them as one coherent cycle rather than discovering the need ad hoc:

1. **Model artifact identity (`model_artifact_hash`).** `strategy_hash`
   captures source bytes, not the bytes of a pre-trained model loaded from
   disk. Two runs with the same strategy code but different trained models
   currently produce the same `strategy_hash`. Honest ML reproducibility wants
   a first-class `model_artifact_hash` that threads into `config_hash` the
   way `cost_model_hash` does. Constructor sketch:
   `ledgr_strategy_artifact(model)` wraps a model with its serialized-bytes
   hash; the hash flows into identity composition as a sibling of cost / risk
   / metric-context hashes.

2. **Train hook distinct from inference loop.** ML workflows fit on a train
   window and predict on a test window. Today training has to happen inside
   the strategy callback on the first pulse, which misattributes telemetry
   and conflates contracts. A `ledgr_strategy_ml(train = , predict = )`
   constructor would let walk-forward call `train()` once per fold's test
   window and cache the trained model under the fold's `candidate_key`. Fold
   core unchanged; only the strategy-contract wrapper.

3. **Prediction-table provenance with PIT semantics.** A common ML pattern is
   generating predictions ahead of time and storing them as a table; the
   strategy then queries `predictions_at(ts_utc, instrument_id)` rather than
   running inference per pulse. Requires the v0.2.x PIT data tables RFC plus
   a prediction-store with hash-bound provenance back to (model artifact +
   feature set + training window). Also unlocks heavy-compute / Python-GPU
   models via precompute-and-query rather than per-pulse roundtrips.

4. **Label-leakage instrumentation.** ML backtests systematically have labels
   accidentally derived from future data. The feature-level no-lookahead
   checks do not catch this because labels are a different surface from
   features. A label-PIT contract would bind that labels are visible during
   training only, not during the pulse loop, and would name a classed
   condition for the runtime-visible-label case.

Sequencing dependencies:

- Selection-integrity diagnostics (PBO / CSCV / DSR / CPCV) should ship before
  ML-first capability. The hyperparameter-sweep selection-bias problem is the
  hardest part of honest ML backtesting; solving it first makes ledgr's ML
  story differentiating rather than "another backtester with `predict()`."
- v0.2.x PIT data tables are a hard predecessor for items 3 and 4.
- Item 2's `ledgr_strategy_ml()` constructor sits cleanly on top of the
  existing strategy helper layer; it does not require its own helper-layer
  cycle.

Indicative minimum-viable v0.2.x cycle:

```text
v0.2.x PIT data tables RFC
  -> model_artifact_hash + ledgr_strategy_artifact() helper
  -> ledgr_strategy_ml(train, predict) constructor
  -> prediction-store with PIT-bound provenance
  -> label-PIT contract + classed leakage condition
```

Total scope is roughly comparable to the v0.1.9.1 cost-API arc if the four
pieces are scoped together.

The earlier inline note in this file ("ML strategy artifact management
depends on stable walk-forward windows, point-in-time feature tables, model
artifact identity, prediction-table provenance, and selection diagnostics.
Do not bolt it on as 'call `predict()` inside a strategy.'") stands; this
entry names the concrete pieces that would operationalize it. The current
[ML-architecture pipeline row](rfc/README.md#ml-architecture) owns the accepted
causality and model-lifecycle obligations. This entry remains non-binding
parking until that row's causal-history and concrete-workflow trigger fires.

Non-commitments:

- this is not a roadmap commitment;
- no public API is bound by this entry;
- naming sketches are illustrative, not contractual;
- if v0.2.x sequencing pulls PIT data tables later than expected, the ML-first
  capability cycle slides with it.

### 2026-06-09 [research] Post-sweep candidate clustering as selection-integrity input

A 2026-06-09 conversation about cross-sectional features surfaced a low-risk
immediate-value capability worth naming separately from the harder
cross-sectional indicator design: clustering sweep candidates by return-stream
similarity AFTER a sweep completes, as a diagnostic over the candidate space.

The proposition is simple. Sweep candidates carry retained return series
under the v0.1.9.2 retention contract. Clustering those return streams
identifies which candidates are effectively running the same bet wearing
different parameter clothes. A 240-candidate sweep that clusters into 12
groups has 12 effective independent trials, not 240, which directly informs
PBO / CSCV / DSR multiplicity-correction methodology when the
validation-toolkit cycle opens.

This capability is risk-free because it lives entirely on the analysis side:

- does not affect trading decisions, so no leakage path back into the
  backtest;
- consumes already-stored sweep artifacts, no new precomputation surface
  needed;
- does not enter the fold core, the strategy callback, the risk chain, the
  cost model, or the persistence schema;
- composes with selection-integrity diagnostics as the natural
  effective-trial-count input, but does not pre-empt their design.

Indicative public shape (illustrative, not contractual):

```r
clusters <- ledgr_sweep_cluster(
  sweep_results,
  method = "kmeans",
  k = 12L,
  signal = "period_return"
)
# returns a tibble mapping candidate_id to cluster_id with cluster centroids
# and effective-independent-trial-count summary
```

Sequencing dependencies:

- v0.1.9.2 sweep retention infrastructure must be present (it is);
- selection-integrity diagnostics RFC scoping should reference this capability
  as the effective-trial-count input rather than redefining it;
- this is independent of the cross-sectional indicators question (see paired
  entry below); it is a pure post-hoc analyzer over sweep return matrices and
  reuses no fit machinery.

Indicative slot: v0.1.9.x post-walk-forward, or rolled into the
selection-integrity diagnostics packet when that lands. Could ship earlier
if a focused doc-and-helper packet has bandwidth.

Route: open a focused evaluation RFC only when a real selection workflow needs
an effective-trial-count method and can supply retained-return evidence.

Non-commitments:

- this is not a roadmap commitment;
- no public API is bound by this entry;
- the constructor sketch is illustrative;
- clustering method selection (kmeans vs hierarchical vs Gaussian mixture)
  is a v0.2.x design choice, not a horizon commitment.

### 2026-06-09 [research] Cross-sectional indicators are a v0.2.x capability cluster

A 2026-06-09 conversation about clustering as a strategy feature surfaced
that ledgr's feature engine is instrument-local: one instrument's series in,
one series out. Cross-sectional features (clustering by trailing
characteristics, factor exposures, ranks within universe, beta against
universe mean, cross-sectional residuals) need whole-universe-at-t in, one
value per instrument out. ledgr has no native surface for this. This is a
real architectural gap.

But cross-sectional indicators are not a standalone feature-engine
extension. They sit at the intersection of four pieces, three of which are
already on the roadmap or in horizon:

- feature engine architecture (current instrument-local shape);
- PIT data tables (v0.2.x roadmap: `known_at`, `available_at`,
  `effective_at`, alignment policy);
- ML strategy artifact management (the 2026-06-09 ML-first capability shape
  entry above);
- walk-forward (v0.1.9.4) with its `hydration_start` / `scoring_start` /
  `execution_start` / `opening_state_policy` window semantics.

Cross-sectional fitted indicators are functionally "ML strategy artifact
management applied to a model that produces per-instrument output." Same
machinery, same identity discipline.

Hard design problems this surface raises that need RFC-level attention before
any public API is bound:

- **Fit schedule semantics.** "Refit monthly" is gestural. Precise binding
  needs: does the refit fire at the start of the test window or mid-window?
  Does it trigger warmup hydration? Does the fit at time t use data through
  t-1 (strict) or through t (inclusive)? How does the schedule interact with
  walk-forward fold boundaries?
- **Identity composition.** The feature value at time t depends on (fit window
  + fit method + fit params + input feature set + universe + fit schedule).
  Needs a `fit_artifact_hash` analogous to the `model_artifact_hash` in the
  ML-first entry. Without it, two runs with identical strategy / features /
  params / risk / cost can produce different feature values if the underlying
  fits drift, and `config_hash` will not catch it.
- **Dependency graph among features.** Cross-sectional indicators commonly
  consume per-instrument scalar indicators (k-means on rolling volatility,
  ranks within universe by momentum, PCA on returns correlation matrix).
  This is a layered feature engine, not the current flat shape. Needs:
  declared input dependencies on cross-sectional constructors; topological
  sort for precompute order; identity composition where cross-sectional hash
  includes input indicator hashes; cache invalidation across layers when an
  upstream indicator changes.
- **Seed management for stochastic fits.** k-means initialization, SGD
  embeddings, random projections, RANSAC-like procedures all introduce
  non-determinism. Needs: per-fit seed derivation from `master_seed`; seed
  isolation across candidates (a `k = 4` fit must not leak entropy into a
  `k = 8` fit); possible multi-seed averaging for robust fits; integration
  with the existing `execution_seed` machinery.
- **Precomputation and fit-artifact storage.** Pulse-time refitting is
  prohibitive. Realistic workflows refit sparsely (monthly / quarterly) and
  look up cached fitted artifacts per pulse. Needs a fit-artifact store with
  PIT lookup semantics, same shape as the prediction-store named in the
  ML-first entry.

Related but worth noting separately: cross-sectional features could be
consumed by the risk chain, not just the strategy callback. A
`ledgr_risk_one_per_cluster(cluster_feature_id, n_per_cluster)` step that
reads cluster_id and zeros targets exceeding a per-cluster cap fits the
chainable risk architecture naturally. Cluster-id-as-portfolio-constraint is
structurally cleaner than cluster-id-as-alpha and avoids the methodology
question of whether clusters predict returns. Same observation applies to
factor exposures, sector caps, and beta-neutrality.

Sequencing dependencies:

- PIT data tables (v0.2.x) are a hard predecessor;
- ML-first capability shape (v0.2.x, see 2026-06-09 ML-first entry) shares
  most of the load-bearing machinery; cross-sectional indicators should be a
  named workstream inside that packet, not a separate cycle;
- walk-forward (v0.1.9.4) must be stable so fold-boundary semantics for refit
  scheduling are bound;
- a layered feature engine architecture is a predecessor for any
  cross-sectional surface that consumes other indicators.

Indicative slot: v0.2.x ML-first capability packet as a named workstream.
Not earlier, not standalone.

Route: the first concrete cross-sectional or ML workflow opens that packet
after the history surface exists; this entry does not authorize an engine.

Non-commitments:

- this is not a roadmap commitment;
- no public API is bound by this entry;
- the `ledgr_xs_indicator()` and `ledgr_ind_cluster()` constructor sketches
  discussed are illustrative, not contractual;
- the cluster-as-risk-step note is a downstream application, not a separate
  cycle.

### 2026-06-09 [risk] Risk-chain constraint expansion RFC family (Palomar-anchored)

A 2026-06-09 review of Palomar (2024) Chapter 6 against ledgr's current
risk-chain step set found that ledgr ships 1.5 of 10 canonical portfolio
constraints: long-only fully via `ledgr_risk_long_only()`, and the upper
half of a symmetric box via `ledgr_risk_max_weight()`. The remaining 8 are
intentionally deferred per the v0.1.9.3 chainable-risk synthesis Section 2
minimum-adapter-set scope. See `inst/design/methodology_references.md`
Palomar entry for the full coverage table and citation anchors.

The gap is strategic, not accidental. But it will define ledgr's positioning
ceiling as the package moves toward CRAN and beyond: serious quantitative
portfolio research expects at minimum long-only, capital budget, asymmetric
box, turnover, and some form of risk constraint (sector cap, beta, or
tracking error). That is 5 of 10. Until ledgr covers most of those, the
honest framing is "research framework for simple strategies," not "research
framework for portfolio research."

Closing the gap is not one RFC. Different constraints need different
machinery and predecessors:

- **Long-only / asymmetric box / max-weight refinements.** In-place
  additions to the current risk-step model, no new context fields, no
  solver dispatch. Could open as a focused v0.1.9.x or v0.2.x cycle once
  v0.1.9.5 docs land.
- **Cardinality `||w||_0 <= K`.** Non-convex constraint. Either
  select-top-k-style heuristic (cheap, in the risk chain) or solver
  dispatch (out-of-fold, in portfolio optimization scaffolding). First
  design fork future RFCs will hit.
- **Turnover `||w - w_0||_1 <= u`.** Needs current-position state exposed
  to the risk context. The v0.1.9.3 spec §14 standing future-context
  obligation must land first.
- **Market-neutral / beta / tracking error.** Needs v0.2.x benchmark
  context plus the beta substrate (see the 2026-05-24 beta-as-three-uses
  horizon entry). Far downstream.
- **Dollar-neutral / leverage `||w||_1 <= u`.** Needs long-short authoring
  support (gated on the shorting / leverage contract RFC per the
  2026-06-01 horizon entry).
- **Margin.** v0.2.x derivatives arc territory; permanently out of scope
  for v0.1.x per the whole-second / spot-only contract bindings.

This implies the constraint expansion is a multi-cycle family of RFCs at
different points in the roadmap, not a single packet. Trying to scope them
all together would mix near-term (asymmetric box, cardinality heuristic)
with far-future (margin, dollar-neutral) and produce a packet that cannot
ship.

Cross-cutting decisions any expansion RFC in this family must bind:

- **Quantity-space vs weight-space translation.** Palomar writes
  constraints in weight-space (`w` summing to 1 or zero). ledgr's risk
  chain operates in quantity-space. The translation
  `quantity = weight * decision_equity / decision_price` is mechanical for
  long-only fractional workflows and is what `ledgr_risk_max_weight()`
  already does internally. Any expansion RFC must bind the translation
  explicitly so "max weight 0.20" interpreted on `|w|` versus on
  `|w * P / E|` does not silently drift.
- **Convex vs non-convex partition.** Most Palomar constraints are convex
  (long-only, box, turnover via L1, market-neutral, dollar-neutral,
  leverage via L1) and can live as chainable risk-step adapters.
  Cardinality is non-convex; future risk-step extensions must decide
  between heuristic in-chain implementation and solver dispatch out-of-
  fold. This decision also tells future portfolio-optimization-scaffolding
  work which Palomar constraints become risk-step adapters versus
  PortfolioAnalytics / CVXR adapter targets.
- **Vocabulary stability.** Future risk-step names should follow Palomar's
  labels where they fit naturally. `ledgr_risk_box_weight()`,
  `ledgr_risk_cardinality()`, `ledgr_risk_turnover()`,
  `ledgr_risk_market_neutral()` are the anchored names. Do not coin
  alternatives.

Sequencing dependencies:

- the asymmetric box and minimum-weight cycle has no hard predecessor
  beyond the v0.1.9.3 risk-chain architecture (shipped);
- turnover needs the v0.1.9.3 spec §14 future-context obligation bound;
- cardinality needs an explicit heuristic-vs-solver decision; if heuristic
  is chosen, it can ship near-term, if solver is chosen, it sits in
  portfolio optimization scaffolding;
- market-neutral / tracking error sit behind the v0.2.x benchmark
  substrate; not earlier;
- dollar-neutral / leverage sit behind the long-short contract RFC; not
  earlier;
- margin / leverage with derivatives sits in the v0.2.x derivatives arc.

Indicative slot for the first member of the family: an
asymmetric-box-plus-cardinality-heuristic cycle could open as a focused
v0.2.x packet once the v0.1.9.x arc closes and v0.1.9.5 docs land. Later
members slot in as their predecessors come online.

Related horizon entries that share the same v0.2.x cluster and should
coordinate at scoping time:

- 2026-06-07 portfolio optimization scaffolding (four-level decomposition
  and architectural footguns);
- 2026-05-24 beta as three distinct uses;
- 2026-06-01 strategy callback contract + authoring helpers
  (long-short / hedged / levered authoring helpers gating);
- 2026-06-09 ML-first capability shape (model artifact identity + PIT
  data tables that this family shares predecessors with);
- 2026-06-09 cross-sectional indicators are a v0.2.x capability cluster
  (cluster-as-risk-step is a downstream application of this family).

Route: a real portfolio constraint selects one bounded member of this family
for a portfolio/risk RFC; the family itself is not an implementation owner.

Non-commitments:

- this is not a roadmap commitment;
- no public API is bound by this entry;
- the `ledgr_risk_box_weight()` / `ledgr_risk_cardinality()` /
  `ledgr_risk_turnover()` / `ledgr_risk_market_neutral()` constructor
  sketches are illustrative, not contractual;
- the cardinality heuristic-vs-solver decision is named here as the first
  design fork; it is not resolved here;
- which constraint cycle opens first is a v0.2.x scoping decision, not a
  horizon commitment.

### 2026-06-09 [ux] Weight-strategy wrapper as alternative authoring surface

**Status update 2026-06-12: rebalancing schedule policy -- generalized
to ALL strategies, not wrapper-only.** A 2026-06-12 design conversation
added rebalancing intervals to this surface's design space, then
generalized them on a maintainer observation: "in general all
strategies could use that -- hold until the next date." The eventual
RFC inherits the following considerations instead of rediscovering
them.

- **General schedule decorator, weight wrapper as consumer.** The
  calendar policy is a strategy-level concept applicable to any
  `function(ctx, params)` strategy: a decorator (indicative shape
  `ledgr_strategy_schedule(strategy, rebalance = "monthly")`) that on
  non-scheduled pulses emits hold-shaped targets WITHOUT calling the
  inner strategy. `ledgr_weight_strategy()` consumes the same schedule
  machinery rather than owning it; one schedule concept, two authoring
  surfaces.
- **Skip-callback semantics must be bound.** "Hold until next date"
  means the inner strategy is not called on non-scheduled pulses: its
  `state_prev` does not advance and its features are not read. That is
  the honest semantics and the cheap one (a monthly EOD strategy skips
  ~95% of strategy callbacks), but stateful strategies that expect
  per-pulse state updates behave differently under a schedule --
  document, do not paper over. MVP shape is a pure strategy-layer
  decorator (zero fold-core touch; ctx is still constructed).
  Skipping ctx construction entirely on held pulses is a later
  fold-core optimization lever with its own gate.
- **Separate `optimize` from `rebalance` (weight wrapper only).**
  portfolioBacktest's most useful knob split: re-running the optimizer
  (re-estimates mu/Sigma from a lookback window; expensive) is a
  different decision from re-trading back to existing target weights
  (drift correction). Monthly-rebalance, quarterly-reoptimize is a
  standard institutional pattern; conflating the knobs forecloses it.
  Re-estimation is a weights concept and stays wrapper-level.
- **Drift bands compose with the calendar and are already parked.**
  Band-triggered rebalancing ("trade only when a weight drifts more
  than x% from target") is computable at pulse time from ctx
  (positions, prices, equity -> current weights) and is already named
  in the Pass 2 target-construction helper extensions ("rebalance
  bands"). Calendar and bands AND-compose: check on schedule, trade
  only outside bands. Bands are weight-shaped and stay at the
  weight/helper layer; the calendar schedule is general.
- **Identity and sweepability come free at this layer.** Schedule
  parameters are strategy/wrapper params, so they flow into
  params_hash and candidate identity with zero new machinery -- and
  rebalance frequency becomes a sweepable grid axis for free.
  Frequency-vs-cost is one of the most legitimate sweeps a cost-aware
  backtester offers.
- **Calendar semantics need one bound deterministic rule.** "monthly"
  must mean something exact against the pulse calendar (e.g. first
  pulse of each calendar month), defined without market-calendar
  dependencies, EOD/whole-second clean. One paragraph in the RFC, but
  a bound paragraph: it is result-affecting.
- **Boundary: turnover constraints are not schedules.** The Palomar
  turnover constraint (`||w - w0||_1 <= u`) limits how much is traded
  WHEN a rebalance happens and belongs to the risk-chain constraint
  family; the schedule decides WHEN. The RFC names the distinction so
  users do not reach for the wrong knob.

Non-commitments unchanged; the decorator shape is illustrative, not
contractual. The general schedule decorator now has a staged seed
(`rfc/rfc_strategy_schedule_decorator_v0_1_9_x_seed.md`, written
2026-06-12 as design preservation; cycle deliberately not opened --
see the rfc/README.md pipeline). The wrapper-level knobs (`optimize`,
`bands`) remain with this entry.

A 2026-06-09 conversation about strategy contract space (weights vs
quantities) concluded ledgr should not flip its quantity-space strategy
contract, but should add a `ledgr_weight_strategy()` wrapper constructor as
an alternative authoring surface for users who prefer to think in weights.

Route: repeated authoring boilerplate opens the staged strategy-schedule seed;
weight-specific optimization and bands then belong in its portfolio follow-up.

### The question

Today's strategy contract is `function(ctx, params) -> named numeric target
quantities`. Textbook portfolio construction (Palomar, Markowitz, Lopez de
Prado) operates in weight-space (`w` summing to 1 or zero). The chainable
risk layer (v0.1.9.3) operates in quantity-space with internal weight
translation -- `ledgr_risk_max_weight()` does
`abs(qty * decision_price) <= max_weight * decision_equity`. The question
raised was whether to flip the strategy contract to weight-space to align
with the literature.

### Decision: do not flip the contract

Keep quantity-space as the canonical execution contract:

- **Substrate uniformity.** Fills, ledger events, opening positions,
  snapshots, and the fold core are in quantity-space. The strategy contract
  matching them 1:1 means no translation lives in the middle of the
  execution path.
- **Internal translation already works.** Every Palomar weight-space
  constraint can be expressed in the existing quantity-space chainable
  risk-step pattern (see the 2026-06-09 Palomar constraint expansion family
  entry above for the convention). The math IS in weight-space at the
  constraint level; only the user-facing contract is quantity-space. The
  pattern is established and scales to the rest of the Palomar taxonomy
  without contract changes.
- **Quantity-space is execution-honest.** Crypto fractional quantities,
  equity round-lot semantics, opening positions, and multi-currency
  accounting are all natural in quantity-space and would need a translation
  boundary if the strategy contract were weight-space.
- **Migration cost would be substantial.** Vignettes, examples, tests,
  helpers, demo strategies, and the v0.1.9.3 chainable risk layer all assume
  quantity-space. Pre-CRAN posture authorizes the break but the
  artifact-rewriting cost is real and would set up a second migration
  immediately after the v0.1.9.3 target-risk migration.

### Add a wrapper constructor instead

The cleaner answer is a `ledgr_weight_strategy()` constructor that wraps a
weight-space strategy and translates to quantities at the boundary:

```r
my_strategy <- ledgr_weight_strategy(function(ctx, params) {
  weights <- c(AAA = 0.30, BBB = 0.20, CCC = 0.10, CASH = 0.40)
  weights
})
```

The wrapper handles `quantity = weight * decision_equity / decision_price`
and emits a normal quantity-space target vector. The fold core never sees
weights. Strategy preflight, identity hashing, and the chainable risk layer
all see a normal quantity-space strategy.

Users who want weight-space write weight-space; users who want quantity-
space (especially crypto fractional or explicit-share workflows) write
quantities. Strategy helpers like `target_rebalance(equity_fraction = ...)`
already do something like this implicitly; making the pattern a first-class
wrapper constructor surfaces it.

### Why this is better than flipping

- **Substrate identity preserved.** Quantity-space stays the canonical
  contract; nothing else needs to know about the wrapper.
- **Palomar risk-chain expansion stays clean.** Each new constraint
  (`ledgr_risk_box_weight`, `ledgr_risk_turnover`, etc.) does its own
  weight-to-quantity translation at constructor time. That is already the
  established pattern from `max_weight`. The Palomar entry from 2026-06-09
  explicitly bound this translation as a load-bearing convention; this
  approach honors it.
- **Multi-strategy meta-allocation gets a natural home later.** When the
  portfolio optimization scaffolding lands (2026-06-07 horizon entry), it
  consumes weight-strategy artifacts. The wrapper makes that surface
  composable from day one without retrofitting the strategy contract.
- **Existing artifacts unaffected.** Vignettes, examples, and demo
  strategies all continue to work. The wrapper is additive.

### Indicative constructor sketch (illustrative, not contractual)

```r
ledgr_weight_strategy(
  fn,
  cash_target_id = "CASH",
  normalize = c("none", "to_one", "to_one_with_cash"),
  ...
)
```

Design questions an eventual RFC must bind:

- whether the wrapper validates that weights sum to a constant or trusts
  the user;
- how a cash weight is represented (reserved name, attribute, return-value
  contract);
- whether negative weights are accepted (gated on long-short authoring per
  the 2026-06-01 horizon entry);
- whether the wrapper produces a fully-named target vector or only the
  non-zero weights with the engine completing the rest;
- how decision-time price normalization handles instruments with NA or
  zero prices, consistent with the risk-chain context discipline from
  v0.1.9.3 Batch 5.

### Sequencing dependencies

- v0.1.9.3 chainable risk layer (shipped) -- the established
  weight-to-quantity translation convention this wrapper extends;
- v0.1.9.x decision-time `ctx$equity` and `ctx$vec$close` surfaces
  (shipped) -- the context the wrapper consumes;
- portfolio optimization scaffolding (v0.2.x, 2026-06-07 horizon entry) --
  the future surface that benefits most from this wrapper;
- strategy callback + authoring helpers (2026-06-01 horizon entry) -- this
  wrapper is naturally a member of that helper family;
- Palomar constraint expansion family (2026-06-09 horizon entry above) --
  every constraint added there benefits from a weight-space strategy
  authoring surface that does not require contract changes.

### Indicative slot

A focused v0.2.x cycle, plausibly bundled with either the portfolio
optimization scaffolding or the strategy authoring helpers Pass 2 work.
Small surface (one constructor + tests + docs), no fold-core touch, no
identity-bytes change.

### Non-commitments

- this is not a roadmap commitment;
- no public API is bound by this entry;
- the `ledgr_weight_strategy()` constructor name and signature are
  illustrative, not contractual;
- whether the wrapper validates weight-sum semantics is left to the RFC;
- the cash-weight representation question is left to the RFC;
- which packet this lands in (helpers, scaffolding, or its own cycle) is a
  v0.2.x scoping decision.

### 2026-06-02 [verification] macOS parity gate for B2 spot-FIFO opt-in

LDG-2526 can expose the scoped B2 spot-FIFO accelerator as a public
memory-backed sweep opt-in on the platforms verified in the current workspace,
but this Windows workspace cannot close Apple hardware parity. Before any
future default-promotion or CRAN-readiness decision, rerun the small FIFO parity
suite and the peer/workload-grid smoke with
`compiled_accounting_model = "spot_fifo"` on macOS, including a source install
with the local C++ toolchain. Failure UX should also be checked on a macOS
install where the compiled kernel is unavailable.

### 2026-06-07 [research] MAE / MFE per-trade excursion analytics

Peterson (2017) treats Maximum Adverse Excursion and Maximum Favorable
Excursion as core per-trade analytics: empirical-risk-stop calibration,
trailing-take-profit identification, and per-trade-quantile diagnostics.
The substrate already exists on ledgr promoted runs (lots + fills
retained, durable equity curve recorded); no public helper computes the
excursions today.

A future `ledgr_run_excursions()` helper would consume the existing fills
and per-pulse OHLC (or higher-frequency data when available) and emit a
per-trade tibble with MAE / MFE / time-to-MAE / time-to-MFE columns. The
flat-to-flat trade definition is the natural groupwork; multi-asset and
non-spot accounting would extend the helper once the trade-definition RFC
(flat-to-reduced vs increased-to-reduced) opens.

This is a small future helper, not a major architectural addition. It
fits naturally inside the v0.2.x diagnostic-retention surface or as a
standalone parallel release between named ticks. The promotion-context
surface (v0.1.8.x) already exposes the trade-extraction interface
`ledgr_closed_trade_rows()`; MAE / MFE would compose on top of it.

Defer until the spot-FIFO multi-asset accounting question is settled --
otherwise the trade-definition contract is in flux and the excursion
semantics would shift.

This entry is non-authorizing.

### 2026-05-29 [research] Snapshot administration and research-loop helpers deferred

The v0.1.8.6 `LDG-2451` gate for snapshot administration, ETL provenance,
sweep-review helpers, and promotion-recovery-summary helpers was deferred by
maintainer decision during release closeout. The work remains useful, but it is
not required for the v0.1.8.6 materialization, benchmark, and attribution cycle,
and it should not distract from the v0.1.8.7 Optimization Round 2 hot-path
lanes.

When revived, likely in a v0.2.0-class RFC/spec cycle, keep the original shape:
separate engine-computed metadata, user-supplied descriptive metadata, and
administrative lifecycle state; preserve `snapshot_hash` independence from
mutable user metadata; keep sweep-review helpers explicit about ranking rules;
and keep promotion-recovery summaries factual rather than automated candidate
selection or validation.

This entry records direction, not committed work.

### 2026-05-13 [ux] Future tune-wrapper naming

After `ledgr_sweep()` exists and the fold core is stable, revisit whether a
convenience wrapper such as `ledgr_tune()` is useful. This should remain parked
until sweep result shape, objective/ranking ownership, and candidate promotion
are stable.

### 2026-05-13 [ux] Research workflow scaffolds and companion templates

ledgr may eventually benefit from templates, but the first core-owned template
surface should be research workflow scaffolding rather than alpha/strategy
cookbooks. The useful core template is a complete reproducible study scaffold:
snapshot creation, feature registration, strategy file, feature and strategy
parameter grids, sweep script, held-out validation, report skeleton,
assumptions log, and candidate-promotion checklist.

Possible future core helper:

```r
ledgr_new_research_project(
  path = "research/sma-crossover",
  template = "active-alias-sweep"
)
```

Possible first core scaffold:

```text
my-ledgr-study/
  README.md
  data-raw/
  snapshots/
  R/
    strategy.R
    features.R
    params.R
  scripts/
    01_make_snapshot.R
    02_single_run.R
    03_sweep_train.R
    04_validate_test.R
    05_promote_candidate.R
  reports/
    sweep_review.qmd
    validation_report.qmd
  ledgr.yml
```

The point would be to encode the boring correct workflow: sealed data,
registered features, explicit feature and strategy params, train/sweep/evaluate
discipline, review artifacts, and promotion decisions. Tiny example strategies
such as flat baseline or SMA crossover can appear in core only as contract
demonstrations, not as profitable-strategy templates.

A companion repository can own richer strategy templates after the v0.1.8.4
active-alias and grid-helper UX stabilizes. That repository should be framed as
educational templates or recipes, not official strategies. It can contain
copyable examples such as SMA crossover, RSI threshold, breakout,
mean-reversion, and volatility-filter studies, each with its feature map,
feature grid, strategy grid, sweep script, and explanation. Keeping these
outside the core package lets examples be richer without turning ledgr into a
strategy library.

Suggested split:

- core `ledgr`: `ledgr_new_research_project()` or equivalent scaffold command,
  plus one or two minimal built-in workflow templates;
- companion repo: opinionated educational strategy templates and longer
  walkthroughs;
- core docs: link to the companion repo once it exists, but continue to teach
  the canonical workflow through package-owned examples.

This fits the agentic-research thesis because agents can work more safely in a
known structure with explicit files such as `hypothesis.md`, `strategy.R`,
`params.R`, `sweep_results.rds`, `validation_report.qmd`, and
`promotion_decision.md`.

Do not pull this into v0.1.8.4. Active aliases, grid helpers, pulse-debug
inspection, and the single demo strategy should land first; scaffolding should
encode that stabilized workflow rather than shape it.

The accepted research workflow synthesis places canonical workflow
documentation in v0.1.8.5. Treat that as the prerequisite for any scaffold
helper: first teach the workflow, then generate it only if review evidence
shows project setup remains too costly.

When the v0.1.8.5 spec packet is cut, carry these synthesis-review notes into
acceptance criteria:

- the workflow article should be runnable end to end and should produce or
  walk through a review/report shape matching the synthesis outline:
  hypothesis and data window, snapshot hash and source assumptions, feature and
  strategy declarations, candidate-grid summary, top-N candidate table,
  warning/failure review, equity/drawdown plots, promotion note, and rejection
  rationale for alternatives;
- any small helper admitted by the spec must be documentation-supporting
  inspection or summary ergonomics only. It must not add storage layers,
  dispatch paths, identity surfaces, scaffold generation, or execution
  semantics;
- the spec should name the auditr tasks that exercise the canonical workflow
  and route findings against those surfaces;
- the spec should make visible that point-in-time regressor design is a
  prerequisite for broad ML/factor strategy workflows.

### 2026-05-26 [storage] Snapshot lineage and live data logs

Long-running research and production use different data lifecycle contracts.
Research snapshots are immutable replay inputs. New historical data, vendor
corrections, universe changes, and multi-vendor comparisons should create new
sealed snapshots rather than mutating old snapshots in place.

Future research-facing snapshot lineage should likely be lightweight metadata,
not a full versioning subsystem:

- `family`: logical group for related snapshots;
- `family_version`: monotonic or date-stamped version inside the family;
- `extends`: previous snapshot when the new snapshot adds later data;
- `supersedes`: previous snapshot when the new snapshot replaces corrected
  history;
- `lineage_note`: human-readable reason for the reseal.

A helper such as `ledgr_snapshot_family()` could make quarterly reseals,
vendor-correction reseals, universe expansion, and walk-forward snapshot
families inspectable without introducing split stores yet.

Production live data is a separate future surface. A promoted algorithm runs
against append-only ticks or bars that arrive after the backtest snapshot. That
surface needs feed identity, session/calendar policy, gap detection, repair or
backfill policy, correction policy, and linkage back to the promotion evidence.
Live ticks or bars should not be appended to the sealed snapshot that justified
the promotion. If live history becomes research evidence, the future workflow
should seal a historical range from the live log into a new immutable snapshot.

Do not implement this in v0.1.8.4. Keep it as production/paper-trading and
long-horizon storage design input. The important near-term rule is the
boundary: immutable snapshots for replay, append-only logs for live observation.

### 2026-05-26 [data] External point-in-time regressor snapshots

Serious quant research eventually needs point-in-time external data beyond
OHLCV bars: fundamentals, macro releases, analyst estimates, vendor factors,
and alternative data. These inputs have vintage semantics. A replay must use
what was known at the historical decision time, not later-revised values.

**Overlaps the 2026-05-25 "Point-in-time data tables" entry** — same v0.2.x
PIT external-data substrate from two angles (this one is the regressor/feature
use case; the other is the table/storage model). The eventual "External Data
And Point-In-Time Regressors" RFC should unify both, and also covers the
late/revised-tick axis of the 2026-05-28 live bad-data resilience entry.

DuckDB is the right default backbone for this in ledgr's foreseeable roadmap.
It is local-first, R-friendly, columnar, and supports ASOF-style lookup patterns
that fit point-in-time joins. That should cover daily, moderate intraday,
fundamental, macro, and many research-scale alternative-data workflows. The
breakpoints are large single-file stores, tick-scale data, and multi-writer
team platforms; those remain split-store or external-backend questions.

Future design should likely introduce sealed regressor snapshots with their
own lineage and hashes, then expose PIT-correct lookup/projection into the
existing pulse context:

```text
regressor source data
  -> sealed regressor snapshot with vintage metadata
  -> PIT-correct projection at pulse timestamps
  -> ctx feature/regressor values
```

Do not implement this opportunistically inside active aliases, ML, or adapter
work. It deserves a dedicated "External Data And Point-In-Time Regressors" RFC
covering schema, vintage fields, ASOF lookup semantics, leakage prevention,
lineage, feature-map integration, and storage scale breakpoints.

This should precede broad ML/factor strategy workflows. Those workflows depend
on vintage-correct external inputs, so model artifact provenance alone is not
enough.

### 2026-05-25 [education] Strategy family field guides

Future documentation should include literature-informed field guides for major
EOD trading strategy families. These are broader than reference strategy
templates: the goal is to teach the economic rationale, data requirements,
implementation shape, leakage risks, validation protocol, metrics, and
cost/capacity caveats for each family.

Possible families:

- time-series momentum;
- cross-sectional momentum;
- mean reversion;
- trend following and moving-average systems;
- carry or yield;
- value;
- quality;
- low volatility or defensive equity;
- sector or asset rotation;
- pairs or spread trading;
- event or earnings drift;
- volatility targeting;
- benchmark-aware active equity.

Each field guide should be literature-informed, with recognizable sources for
the economic rationale and known critiques. User-facing articles should stay
readable and practical, but they should not be winged. They should include a
short further-reading section and make clear that ledgr examples are
educational implementations, not trading advice or profitability claims.

Suggested article shape:

```text
1. Economic idea
2. Literature anchor
3. Data requirements
4. Causality/leakage traps
5. Minimal ledgr implementation
6. Variants
7. Metrics that matter
8. Validation protocol
9. Costs, capacity, and failure modes
10. Further reading
```

This depends on several future roadmap layers: target construction helper
extensions, benchmark context and active metrics, walk-forward and selection
integrity diagnostics, liquidity/capacity policy, point-in-time data tables,
corporate actions/instrument master, and reference strategy templates. It is
therefore a v0.2.x+ documentation/education arc, not near-term v0.1.8 work.

### 2026-05-13 [research] Deferred strategy and integration families

The shortened roadmap no longer carries detailed scope for portfolio
optimization support, calendar/event-driven strategies, pairs and spread
trading, reporting adapters, additional indicator backends, ML strategy
artifact management, or expanded asset-class support. Keep these families
parked until the research-to-paper arc is stable enough for focused RFCs.

Do not confuse full portfolio optimization with the existing helper pipeline
(`signal_*()` -> `select_*()` -> `weight_*()` -> `target_*()`). The
`Target construction helper extensions` horizon entry owns small additions to
that helper surface. Full solver-style portfolio optimization remains deferred.

ML strategy artifact management depends on stable walk-forward windows,
point-in-time feature tables, model artifact identity, prediction-table
provenance, and selection diagnostics. Do not bolt it on as "call `predict()`
inside a strategy."

The likely long-term abstraction is still pulse-based. An ML strategy should
make decisions at the same no-lookahead pulse boundary as every other ledgr
strategy:

```text
current pulse context -> model prediction or prediction lookup -> target vector
```

Naively calling `predict()` inside every pulse will be expensive, especially
for cross-sectional models, wide universes, and large sweeps. That cost should
be handled with implementation choices rather than by changing the abstraction:
load models once per run/candidate, precompute prediction matrices when the
model and feature set are fixed, cache prediction artifacts by snapshot hash,
feature-set hash, alias-map hash, and model artifact hash, and let strategies
read prediction values from the pulse context when that is the chosen mode.

Future ML design should distinguish:

- live pulse prediction: clearest semantics, highest cost;
- precomputed prediction artifacts: faster for sweeps and replay, still causal
  if generated from point-in-time features and immutable model artifacts.

Do not lock this API now. The insight to preserve is that ML decisions remain
pulse decisions; optimization should move model loading and prediction
materialization out of the hot path when possible.

When ledgr reaches ML strategy workflows, `pins` and `vetiver` are likely the
right boundary tools for model artifacts. `pins` can version and share R
objects or files on local, Posit Connect, S3, and related boards with metadata,
versions, and hashes. `vetiver` builds on that model-artifact layer for trained
models, input prototypes, deployment, model cards, environment checks, and
monitoring.

Future policy should likely be:

- ledgr DuckDB store remains the source of truth for sealed snapshots, runs,
  sweeps, fills, metrics, promotion notes, and references to external model
  artifacts;
- `pins` / `vetiver` own trained model objects, model metadata, input
  prototypes, renv lockfiles, model cards, and monitoring artifacts;
- ledgr provenance records exact model artifact references such as board,
  name, version, pin hash, training snapshot hash, feature-set hash, alias-map
  hash, and strategy hash;
- ledgr must not depend on "latest model" lookup for deterministic replay. A
  backtest or promotion record should identify an immutable model version or
  hash;
- live vetiver endpoints are production-serving surfaces, not replay evidence,
  unless they resolve back to a specific pinned model artifact.

Do not turn this into a near-term dependency decision. The relevant ledgr API
surfaces are not stable yet, and pins/vetiver integration deserves its own RFC
when ML workflows become active scope. For now, workflow/artifact-topology RFCs
may mention pins/vetiver as future-compatible tools, but should not lock a
production API around them.

### 2026-05-16 [research] Randomized and blocked slice diagnostics

Walk-forward should ship before randomized slice protocols. For time series,
"random slices" must not mean arbitrary row-level train/test splits that violate
causality. Future designs should build on the walk-forward window model and
make slice semantics explicit.

Possible future protocols:

- random contiguous train/test windows;
- random anchored train/test windows;
- blocked or bootstrapped windows with no-lookahead constraints;
- combinatorial symmetric cross-validation;
- PBO/CSCV-style selection-bias diagnostics.

These should remain separate from the first `ledgr_walk_forward()` release.
They require stable sweep result shapes, metric context, grid ergonomics,
parallel dispatch, slice-aware feature validation, and a clear explanation that
provenance records what happened but does not prove selection integrity.

The accepted first walk-forward design is
`inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md`
(with Amendment 1 dated 2026-06-04 in Section 14, Amendment 2 dated 2026-06-04
in Section 16, and Section 17 ticket-cut gates; final-review artifact and
closure update at
`inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_final_review.md`).
Amendment 2 strengthens four Amendment 1 routings from procedural constraints
on open spec-cut questions to substantive defaults: opening-state policy
defaults to `carry_test_state` with a warned `flat_test_state` opt-in;
selection rules fail closed for level metrics with metric-registry
classification; extraction has no implicit fold default and requires a
`selection_rationale` when `"latest"` is used; and default print method's data
contract is an operational per-fold degradation table with named fields and a
render-order contract. Section 17 binds a two-gate ticket-cut matrix
(packet-open and release-gate enforcement) over Amendments 1 and 2. Future
diagnostic work should consume its fold/session/score artifacts rather than
reopening the v1 wrapper-over-run/sweep architecture, and must not assume
per-fold independence under the `carry_test_state` default (see synthesis
Section 16.6 path-dependency obligation).

Route: a study that needs randomized or blocked windows opens an evaluation
RFC over the shipped walk-forward and PBO artifacts; no generic protocol is
scheduled now.

### 2026-05-13 [infrastructure] Parallel interrupt and partial-result semantics

The v0.1.8 architecture currently recommends discard-all interrupt semantics
for the first sweep implementation. Returning partial sweep results later would
need a polling collector, checkpoint semantics, cancellation rules, and clear
atomicity guarantees. Do not add partial-result behavior casually as a UX patch;
it is a parallel output contract.

Evidence:

- `inst/design/spikes/ledgr_parallelism_spike/architecture_synthesis.md`
- `inst/design/manual/sweep.qmd`

Route: any retained partial result requires a sweep output/identity RFC before
the parallel collector changes.

### 2026-05-13 [cost] Broker and exchange cost templates

Core ledgr should own stable cost primitives before any broker/exchange-like
templates are considered. Real fee schedules are account-specific,
jurisdiction-specific, and change over time. If templates are added later, they
should likely live in adapter packages or be clearly labelled approximations.

Route: the first real fee schedule is owned by its vendor adapter and opens a
cost/adapter RFC if core primitives prove insufficient.

### 2026-05-25 [execution] Liquidity and capacity are not transaction cost

Future liquidity and capacity policy should be named separately from
transaction-cost modeling. Cost models answer "what price and fee did this
proposed fill receive?" Liquidity/capacity policy answers "is this proposed
quantity feasible, should it be clipped, or should it be refused?"

Possible future concepts:

- participation limits;
- ADV/volume filters;
- minimum price and minimum volume constraints;
- turnover and capacity diagnostics;
- liquidity refusal or quantity clipping.

These policies require execution-bar data such as next-bar volume and may
change quantities. They therefore belong in execution/liquidity policy, not in
cost application. Route the first strategy needing those bounds through a
focused execution/liquidity RFC.

### 2026-05-14 [execution] Structured RNG preflight metadata

LDG-2104 added human-readable strategy preflight notes for RNG state mutation
and ambient RNG use. Future sweep audit/provenance work may want structured
fields such as `ambient_rng_symbols` and `rng_mutation_symbols` instead of
parsing notes or reasons.

Source: LDG-2104 code review.

### 2026-05-14 [execution] Broader ambient RNG detection

LDG-2104 classifies `runif()`, `rnorm()`, and `sample()` as ambient RNG Tier 2
calls. Future preflight hardening should consider the broader `stats` RNG
family, such as `rbinom()`, `rpois()`, `rexp()`, and `rgamma()`, so stochastic
strategies are not accidentally classified Tier 1.

Source: LDG-2104 code review.

### 2026-05-25 [strategy] Target construction helper extensions

The public helper pipeline already includes `signal_return()`,
`select_top_n()`, `weight_equal()`, and `target_rebalance()`. Future work should
extend that pipeline conservatively instead of introducing a separate portfolio
construction engine.

Potential additions:

- rank-weight helpers;
- inverse-volatility weighting;
- explicit normalization helpers;
- rebalance bands or no-trade zones where semantics are target-construction
  rather than execution policy;
- small diagnostics that explain how weights became full target quantities.

Keep this separate from target risk, liquidity/capacity, transaction cost, and
full portfolio optimization. Cut 16 Workstream 23 shipped the context-first
signal and selection entrances, kept-position sizing and strict missing/
partial-selection policy recorded in the
[strategy-helper closeout](ledgr_v0_2_0_2_spec_packet/strategy_authoring_helpers_closeout.md).
The additions above did not all ship. They remain parked here and route through
the [portfolio-construction pipeline row](rfc/README.md#portfolio-construction)
after the public historical surface ships; there is no surviving roadmap row.

### 2026-05-24 [research] Beta as three distinct uses

Beta is semantically important and architecturally complex partly because the
"same" beta means three different things at different layers:

```text
1. beta as post-run diagnostic
   Did the strategy just load on the market?
2. beta as strategy feature
   Did this instrument have high/low rolling beta at the decision time?
3. beta as target-risk constraint
   Should the target portfolio be scaled/hedged to a beta exposure?
```

Each use has a different complexity profile and different upstream
dependencies. Diagnostic beta needs benchmark returns only. Feature beta also
needs point-in-time alignment with the strategy's decision time and would
interact with feature fingerprinting (the determinism module extracted in
LDG-2212). Constraint beta needs both of the above plus the v0.1.8.9
target-risk chain.

When beta work eventually opens, keep these three uses as separately scoped
sub-questions rather than collapsing them into one design pass. Each use
unblocks on different upstream work:

```text
diagnostic beta : after benchmark/reference-return substrate
                  (`ledgr_metric_context$benchmark` per the accepted
                  v0.1.8.2 synthesis).
feature beta    : after benchmark substrate plus a point-in-time
                  feature/reference alignment design that defines whether
                  rolling beta at pulse t may use returns ending at t or
                  must use returns strictly before t.
constraint beta : after benchmark substrate, feature-alignment design, and
                  the v0.1.9 target-risk chain.
```

Do not gate diagnostic beta on the risk chain; the dependency is
benchmark-only.

Route: a concrete diagnostic, feature, or constraint use starts from the
benchmark substrate and opens only the RFC for that one use.

### 2026-05-24 [data] External benchmark first, universe-derived later

Future benchmark reference-return support should start with explicit external
series (for example SPY total returns, Fama-French market return, or a CRSP
value-weighted market series) rather than benchmarks derived from the ledgr
trading universe.

Universe-derived benchmarks require point-in-time membership semantics,
introduce survivorship-bias risk depending on snapshot construction, and
depend on market-cap or other reference data that ledgr does not own.
External benchmarks are cleaner and let benchmark work proceed without
resolving universe-membership semantics first.

This aligns with the accepted v0.1.8.2 metric-context synthesis, which
reserves `benchmark` as a NULL field with an "aligned return provider"
contract and prohibits ticker-symbol hidden lookup.

A future `ledgr_benchmark_from_universe()` may still be useful but should be
designed after external benchmarks ship and after point-in-time universe
semantics are explicit.

Current route: no packet or RFC-pipeline row owns an aligned external
benchmark provider. The accepted metric-context contract above remains the
design input, and provider work is parked here until a concrete diagnostic or
comparison workflow opens its focused RFC. The pipeline's
[benchmark-methodology row](rfc/README.md#benchmark-methodology) governs public
performance claims, not this provider implementation.

### 2026-06-28 [data] Cross-asset accounting-critical economic events

Vendor-ingestion work in the separate `ledgr-research` monorepo surfaced a
specific upstream feedback item:

```text
C:\Users\maxth\ledgr-research\docs\governance\ledgr-feedback.md
LFB-001 No dividend cashflow event in ledger accounting
```

Completed deep-research input:
`inst/design/research/Cross-Asset-Accounting-Critical-Events.md`.
Treat it as non-binding RFC source material: it records the prior-art and
cross-asset design-space pass, but any load-bearing claim still needs
primary-source verification when the RFC opens.

The concrete gap is equities: ledgr can execute fills, fees, cash deltas, and
mark-to-market positions, but it has no first-class dividend/distribution event.
That means ledgr must not claim accounting-faithful dividend-inclusive total
return for dividend-paying instruments. Split-adjusted bars are
accounting-like but dividend-incomplete; total-return-adjusted prices are
return-complete but accounting-fictional because fills, fees, and notional
exposure occur on counterfactual prices.

Do not scope this as just `DIVIDEND`. The broader planning object is
cross-asset accounting-critical economic events: non-trade events that change
cash, quantity, cost basis, margin, collateral, instrument identity, or
eligibility.

Examples to audit before the RFC:

- equities / funds: dividends, special dividends, return of capital, capital
  gains distributions, splits, spin-offs, mergers, delistings, withholding tax;
- crypto spot: airdrops, forks, staking rewards, token migrations, burns,
  rebates or fees paid in asset units;
- crypto perps: funding payments, margin, liquidation, collateral-currency
  effects;
- futures: variation margin, expiry, rolls, multipliers, delivery or cash
  settlement;
- options: exercise, assignment, expiry, adjusted deliverables after corporate
  actions;
- FX: rollover / swap interest, multi-currency cash balances and conversion;
- fixed income: coupons, accrued interest, amortization, calls, maturity
  repayment.

Architecture split to preserve:

1. source event records from vendors with PIT/provenance metadata;
2. explicit interpretation policy (raw prices plus economic events versus
   adjusted-price shortcuts);
3. ledger economic events emitted into ledgr's event stream;
4. replay/accounting semantics over cash, positions, cost basis, realized /
   unrealized PnL, and equity;
5. research-claim boundary: until an event family is implemented and tested,
   ledgr reports are price-return or method-validation evidence only for
   strategies where that event matters.

The completed research pass covers QuantConnect LEAN, Zipline /
zipline-reloaded, quantstrat / blotter, Backtrader, vectorbt, PMwR,
Freqtrade, and Norgate. The eventual RFC should re-check the load-bearing
primary sources and compare adjustment policy, dividend/distribution
treatment, corporate actions, instrument identity, multi-currency cash,
margin/funding, expiry/exercise/assignment, and replay semantics.

Routing: v0.2.x corporate-actions / instrument-master plus explicit
accounting-critical event-types RFC. An accepted RFC synthesis should precede
implementation. Likely implementation starts with equities (cash distributions
+ splits) after the interpretation contract is accepted;
crypto/futures/options/FX/fixed-income families follow only after their
accounting assumptions are separately scoped. This entry authorizes nothing.

### 2026-05-24 [adapters] External reference-data adapter provenance pattern

Any future external reference-data adapter (tidyfinance, FRED, central-bank
providers, broker APIs) should record provenance fields beyond the
data-identity hash:

```text
source            = "<provider name>"
function          = "<provider function called>"
provider_version  = packageVersion(...)
download_args     = <serialized args>
retrieved_at      = <ISO8601 UTC>
upstream_domain   = <provider-specific>
upstream_dataset  = <provider-specific>
date_range        = <ISO8601 UTC>
symbols           = <if applicable>
```

These fields let a future audit reproduce or at least verify what was
downloaded when. They should not enter the reference object's identity hash
unless they change the data interpretation; they are reproducibility
metadata, not execution identity.

Adapter shape conventions to preserve when adapter work eventually opens:

- `Suggests:` not `Imports:` for the upstream package;
- `rlang::check_installed(...)` at adapter entry;
- empirical verification of upstream unit/format semantics before the
  adapter ships (see `spikes/ledgr_tidyfinance_unit_probe/`);
- no hidden downloads inside metric, strategy, indicator, or fold-core paths.

Per the accepted v0.1.8.2 metric-context synthesis, external adapters are
deferred until the substrate they produce (`ledgr_metric_context` fields
with aligned-provider contracts) is stable.

Route: the first external provider owns acquisition and interpretation in an
adapter RFC; ledgr records only the stable aligned-provider contract.

### 2026-05-25 [infrastructure] DuckDB-backed feature storage and out-of-core projection

The v0.1.8.3 grid-level feature artifacts synthesis intentionally starts with
an R-memory runtime projection because the measured hot path is per-pulse R
object churn, not persistent feature storage. DuckDB is still the natural future
backing for precomputed feature libraries once parameterized indicator grids,
parallel sweep workers, and ML/export workflows need persistence and shared
feature storage.

Future direction:

- `ledgr_precompute_features()` computes feature values through the existing R
  indicator engine (`series_fn()`, TTR adapters, custom indicators) and writes
  concrete feature values to DuckDB-backed feature tables;
- the fold consumes the same projection interface introduced in v0.1.8.3, with
  a DuckDB-backed implementation that loads pulse blocks into memory;
- DBI access happens at block boundaries, not per pulse;
- layer 4 research/export artifacts and out-of-core runtime projection share
  the same DuckDB storage rather than introducing separate schemas;
- parallel workers can read shared DuckDB-backed feature storage instead of
  each materializing the same feature library.

Do not turn this into a DuckDB indicator-computation engine by default. The
authoritative indicator extension surface remains the R `series_fn()` contract
and the planned TTR/custom-indicator path. SQL-native built-in indicators may
be explored later as an opt-in fast path, but only with a separate RFC covering
feature identity, determinism, DuckDB-version sensitivity, mixed R/SQL feature
maps, and parity against the R implementation.

Dependencies before promotion:

- v0.1.8.3 runtime projection interface and R-memory backend have landed;
- v0.1.8.4 active aliases have fixed the alias-map identity and grid-level
  concrete-feature-union contract;
- the post-v0.1.8.3 residual report shows memory scaling, repeated precompute,
  ML/export, or parallel-worker sharing as the next load-bearing bottleneck.

Schema 120 deleted the `features` table and `persist_features`; this entry does
not preserve either surface. Route any new feature store through the
[persisted-data execution-placement RFC](rfc/README.md#persisted-data-execution-placement),
with explicit new schema and identity decisions.

### 2026-05-26 [ui] Shiny research-store exploration UI (opt-in companion package)

ledgr's store is a DuckDB file containing snapshots, sweeps, runs, promotion
context, and metrics. A read-only Shiny UI over that store is the obvious
shape for visual exploration when the API surface alone is not enough.

Likely shape:

- A companion package such as `ledgr.ui` rather than a core dependency. Shiny
  pulls in a meaningful dep tree that core should not require for headless
  research, scripted execution, or auditr probes.
- Local-first: `ledgr_ui()` reads a project's `artifacts/ledgr_store.duckdb`
  with no hosted server, no auth surface, no tracking infrastructure.
- Read-only: the UI never writes to the store. Concurrency and locking stay
  the responsibility of the writing scripts.
- Pure inspection scope. No strategy authoring, no run launch, no promotion
  decision recording from the UI in the first pass; those remain script-driven
  and audit-traceable.

Plausible first-version views:

- project view: list snapshots, sweep results, promoted runs;
- snapshot inspector: bars summary, instruments, time range, hash, sealed_at;
- sweep results browser: candidate ranking by metric, sort/filter;
- candidate detail: feature params, strategy params, alias map, metrics;
- run inspector: equity curve, fills table, events stream, warnings,
  telemetry;
- run comparison: side-by-side equity, key metrics, ranking deltas;
- promotion timeline with decision notes (depends on the future promotion
  notes API);
- cross-snapshot view of the same strategy or feature map across data
  windows.

This is correctly deferred. Reasons not to start now:

- v0.1.x speed and workflow work has higher leverage per engineering hour;
- the API surface is still moving (active aliases, alias-map storage, future
  promotion notes, future walk-forward); a UI built against a moving target
  requires constant rework;
- the most valuable screen (promotion decision timeline with rationale)
  cannot exist before the promotion notes API does;
- the gap versus MLflow's web UI is not a real disadvantage for ledgr's
  current target user, who is comfortable with R REPL inspection.

Realistic timing: not before v0.2.x. A short personal-tool prototype during
v0.1.x is fine and may be useful for the author; a release-quality companion
package belongs after the workflow has stabilized and after promotion notes
have an API home.

### 2026-05-26 [ui] Shiny operations dashboard for production deployments

Much further out than the research-store UI. Once ledgr has live trading or
paper trading via OMS adapters, a separate Shiny operations dashboard becomes
useful for monitoring deployed strategies:

- promotion record browser linking each deployed algorithm to its training and
  validation snapshots, strategy hash, alias map, and approval record;
- live position and equity monitoring against the broker or paper account;
- drift indicators comparing live execution to the promoted backtest;
- alert surface for cost, slippage, or risk breaches;
- retraining trigger view linking each new promotion record to the prior one.

This is a v0.2.x or later product. It depends on:

- production promotion record schema landing in its own RFC;
- OMS/paper-trading adapters existing as a public API;
- a live execution layer with deterministic linkage back to the backtest
  identity surfaces;
- a stable view of what "deployed" and "approved" mean in ledgr terms.

Until those pieces exist, the operations dashboard is a sketch, not a design.
Record it here so the eventual UI work has a target shape rather than being
invented under deployment pressure.

### 2026-05-27 [evaluation] Baseline strategies and opinionated comparison

The current roadmap retains reference strategies only as a later direction.
This horizon entry is the non-binding detailed owner so an eventual RFC author
starts from a known shape.

Two things already exist in v0.1.8.4: `ledgr_demo_sma_crossover_strategy()` as
a single teaching fixture, and `ledgr_compare_runs(snapshot, run_ids = ...)`
as a multi-run comparison surface that returns side-by-side metrics. What is
missing is the opinionated layer that connects them: a small library of
baseline strategies the user can run against the same sealed snapshot, plus a
comparison wrapper that produces a structured "does this beat the baseline"
report instead of two unannotated equity curves.

Three categories that must stay distinct in the design

The v0.2.x RFC must keep these three surfaces separately named. Conflating
them is the most likely failure mode:

- **Baseline strategy.** Runs *inside the engine on the same snapshot* as the
  user's strategy. Same data path, same fill semantics, same accounting.
  Produces an in-sample comparison. This horizon entry is about this
  category.
- **Benchmark return series.** An *external* time series (e.g., SPY total
  return, 60/40 model portfolio NAV) compared post-hoc to the strategy's
  equity curve. Different data path. This is what `PerformanceAnalytics`
  users expect and is a separate future RFC.
- **Reference / teaching strategy.** Same mechanical shape as a baseline,
  but the intent is education, not measurement.
  `ledgr_demo_sma_crossover_strategy()` is one of these. Useful for
  vignettes; not a measurement surface.

Sketch of the v2.x API (not bound)

```r
# Baseline constructors -- same engine, same snapshot, in-sample
ledgr_baseline_flat()                          # always flat (zero positions)
ledgr_baseline_buy_and_hold()                  # equal-weight long at t=0, hold
ledgr_baseline_equal_weight_monthly()          # rebalance to equal weights monthly
ledgr_baseline_random_walk(seed)               # random target per pulse -- sanity check

# Comparison wrapper -- opinionated about which stats matter
ledgr_compare_against_baseline(
  bt,                                          # your committed run
  baseline = ledgr_baseline_buy_and_hold()     # the baseline strategy to run
)
```

The wrapper runs the baseline on the same snapshot with the same opening
state and reports a fixed structured comparison.

The opinionated metric set

The wrapper reports a small fixed set of statistics, chosen because they
answer "does this add value over the baseline" rather than "what are this
strategy's performance attributes":

- difference in total return;
- Sharpe difference;
- max drawdown difference;
- tracking error (stdev of return difference);
- information ratio (return difference / tracking error);
- percent of pulses where the strategy outperformed.

The bounded metric set is itself a design decision. ledgr should refuse to be
a generic stats library here; the comparison surface should teach the
specific question "does my strategy add value relative to a known baseline,"
not enumerate every possible benchmark-adjusted metric.

Scope risks

- **Template library creep.** Ship "buy and hold," users will ask for
  "rebalanced 60/40," "equal-weight momentum," "minimum-variance," etc. Cap
  the core library at ~4-6 templates that genuinely teach the comparison
  discipline. Anything fancier belongs in a companion package or user code.
- **Baseline vs benchmark conflation.** Users will read "baseline" as
  "benchmark" and expect SPY-relative attribution. The API name and the
  documentation must make the distinction obvious — `ledgr_baseline_*`
  constructors run a real strategy inside the engine; a future
  `ledgr_benchmark_*` family (if added) would consume external return
  series.
- **Opinionated metrics still bind a research-method choice.** Picking five
  comparison stats teaches the user to optimize against those five stats.
  The metric selection should be informed by the same Bailey / Lopez de
  Prado / Harvey-Liu-Zhu literature that informed the walk-forward and
  selection-integrity work.
- **In-sample comparison is still in-sample.** If the user's strategy was
  selected from a sweep on the same snapshot the baseline runs against,
  "beats baseline by 3 bps" is in-sample evidence. The walk-forward
  synthesis already warns that single-snapshot evidence is exploratory; the
  baseline comparison surface inherits that caveat and must say so in
  user-facing docs.

Dependencies on prior cycles

This RFC lands well after the prerequisite work:

- walk-forward (v0.1.9.x) so comparisons can be made over OOS fold windows,
  not just full snapshots;
- target risk (v0.1.9) so baselines can be risk-adjusted comparable to
  risk-aware strategies;
- public cost API (v0.1.9.x/v0.2.0) so cost-aware comparisons are honest
  (baselines have different turnover; comparing without cost can mislead);
- selection-integrity diagnostics (v0.1.9.x) so the comparison can be paired
  with multiplicity-aware significance reporting if the user wants it.

The v0.2.x slot is the right window — after the prerequisites stabilize and
before paper/live shifts the question from "does this beat the baseline" to
"is this still working in production."

Current parked routes

- baseline strategy library RFC, parked here until a concrete comparison
  workflow needs it after walk-forward and the cost API
  stabilize);
- baseline-comparison API RFC, coordinated with the baseline library;
- benchmark-return-series adapter RFC (later, if external-time-series
  comparison surfaces user demand — distinct from baseline strategies);
- companion-package reference strategy library (out of core, when the
  in-core library hits maintenance-burden limit);
- statistical-significance layer for baseline comparisons (coordinated with
  selection-integrity diagnostics RFC).

Cross-cycle note

The v0.1.8.5 canonical workflow article (Batch 1, just shipped) intentionally
does not teach baseline comparison. A reader of that article is likely to
ask "but how do I know if my strategy is any good?" — and the honest answer
today is "you run a baseline yourself and compare manually." The v0.2.x
baseline-comparison API is what that answer should point to once it lands.

Until then, the strategy-development vignette's existing note that the demo
SMA crossover and the `single_instrument_strategy()` helper can be used as
ad-hoc comparison baselines is the user-facing guidance.

This horizon entry does not authorize any of the above. It records the
direction so that when each follow-up cycle opens, the seed author starts
from a known shape rather than re-deriving the boundary.

### 2026-05-27 [infrastructure] Snapshot administration surface and ETL provenance metadata

ledgr today stores a small set of snapshot fields plus a free-form
`meta_json` envelope on the `snapshots` DuckDB table
(`R/db-schema-create.R:233-242`). The engine writes `n_bars`,
`n_instruments`, `start_date`, and `end_date` into `meta_json` at seal time
(`R/snapshots-seal.R:199-253`), but the user-facing constructor
`ledgr_snapshot_from_df()` does not even expose the `meta = list(...)`
argument that `ledgr_snapshot_create()` accepts. There is no documented
place for ETL provenance, no notes field, no labels or tags, and no
listing or filtering surface beyond `ledgr_snapshot_info()` on a known ID.

This gap surfaced in v0.1.8.5: the canonical research-workflow article
teaches users to seal data into a project store but cannot teach the
companion discipline of recording *how* the data was prepared. A user can
reopen the exact sealed bytes, but cannot reopen the human reasoning that
produced them.

Three categories that must stay distinct in the design

The eventual RFC must keep these three surfaces separately named so the
schema and API do not collapse into a single freeform blob:

- **Engine-computed metadata.** Derived deterministically at seal time
  from the sealed contents: `n_bars`, `n_instruments`, `start_date`,
  `end_date`, `snapshot_hash`, instrument list, calendar. Reproducible
  from the snapshot and not user-editable.
- **User-supplied descriptive metadata.** Free-text notes, ETL provenance
  (source URL or vendor, retrieval timestamp, ETL script path and
  version, transformations applied), tags or labels, author. Human-
  authored documentation that ledgr stores faithfully but does not
  interpret.
- **Lifecycle and administrative state.** Existing `status`
  (`CREATED`/`SEALED`/`FAILED`) plus potential additions like
  `deprecated_at`, `superseded_by`, `archived_at`. State transitions
  managed through dedicated API rather than freeform edits.

Conflating any two is the most likely failure mode. ETL provenance is
not lifecycle state; engine-computed fields are not user metadata.

Sketch of the API (not bound)

```r
# Constructor surface -- both expose the same metadata fields
ledgr_snapshot_from_df(
  bars,
  db_path     = ...,
  snapshot_id = ...,
  notes       = NULL,    # free-text human notes
  source      = NULL,    # list: vendor, url, retrieved_at, etl_script, etl_version
  tags        = NULL,    # character vector of labels
  author      = NULL     # character scalar
)

ledgr_snapshot_create(con, snapshot_id, notes = NULL, source = NULL, ...)

# Inspection and listing
ledgr_snapshot_info(con, snapshot_id)          # returns all three categories
ledgr_snapshot_list(                           # navigates the store
  con,
  tags          = NULL,                        # filter by label
  author        = NULL,                        # filter by author
  status        = NULL,                        # filter by lifecycle state
  created_after = NULL
)

# Lifecycle administration
ledgr_snapshot_deprecate(con, snapshot_id, reason)
ledgr_snapshot_supersede(con, snapshot_id, by = new_snapshot_id, reason)

# Note administration (audit-logged, not silent overwrite)
ledgr_snapshot_note(con, snapshot_id, append = "...")
```

Schema direction

The cleanest shape is a dedicated set of `snapshot_meta` columns on the
`snapshots` table (or a sibling `snapshot_provenance` table for the
structured ETL fields), with engine-computed values remaining in
`meta_json` until the spike confirms which fields are stable enough to
promote to typed columns. A `snapshot_audit` append-only table can record
administrative edits to notes, tags, or lifecycle state.

Scope risks

- **Metadata creep.** Once the API exposes notes, users will ask for
  arbitrary key/value extension. Cap structured fields at a small
  defensible set and route everything else into one explicit
  `extra = list(...)` slot stored as JSON, not into ad-hoc top-level
  columns.
- **Lifecycle confusion.** "Deprecated" and "superseded" sound similar
  but mean different things; the RFC must define semantics precisely
  before exposing them. Avoid soft-delete unless audit and recovery
  semantics are clear.
- **Mutable metadata vs immutable provenance.** Notes are mutable by
  design (users learn things later). The `snapshot_hash` must not depend
  on mutable metadata, or the audit trail breaks. ETL provenance
  recorded at create-time should be append-only after seal, with later
  edits routed through a dedicated audit-logged path.
- **Listing API as a sweep substitute.** `ledgr_snapshot_list()` is a
  research-management tool, not a query engine. Resist filters that pull
  bar data ("snapshots containing instrument X") into the list surface;
  those belong in `ledgr_snapshot_info()` or a separate query API.
- **Migration burden.** A schema change to the `snapshots` table is a
  breaking change to existing project stores. The pre-CRAN window
  authorizes it, but the cycle must ship a migration script or an
  explicit "rerun your experiments" gate.
- **Intraday-readiness regression.** Schema additions must stay
  cadence-neutral. The snapshots table is timestamp-resolution-agnostic
  today: a user can seal 1-minute or 1-hour bars. Do not introduce
  columns, types, or `meta_json` conventions that imply one row per
  instrument per day, one snapshot per market session, or EOD-only
  frequency. The intraday support arc (2026-05-27 horizon entry) names
  this as a pre-v0.2.x footgun; the RFC author should confirm the
  proposed schema preserves the existing cadence-neutral posture.

Dependencies on prior cycles

- v0.1.8.5 canonical workflow article (Batch 3 / LDG-2437) surfaced the
  user-facing need and started teaching the convention on the existing
  `meta` argument as a documentation-only patch — shipped;
- pre-CRAN compatibility policy (2026-05-25 horizon) authorizes the
  breaking schema change without a deprecation cycle;
- the v0.1.8.6 DuckDB feature-storage spike shipped independently; its
  outcome does not gate the snapshot administration schema.

Status: the v0.1.8.6 cycle deferred the snapshot administration planning
(LDG-2451) per the 2026-05-29 "Snapshot administration and research-loop
helpers deferred" entry. The work is now a v0.2.0-class RFC/spec cycle
candidate, not a near-term v0.1.x slot. This entry stays the binding
seed-shape input for whenever that cycle opens.

Current route and parked follow-ups

- snapshot administration and ETL provenance metadata RFC: the current
  [instrument-master-data pipeline row](rfc/README.md#instrument-master-data)
  owns the accepted provider and PIT boundaries when its trigger fires; this
  entry is its seed-shape input.
- `ledgr_snapshot_list()` filtering and listing API (coordinated with
  the metadata schema RFC).
- `ledgr_snapshot_deprecate()` and `ledgr_snapshot_supersede()`
  lifecycle API (coordinated with the metadata schema RFC; final scope
  decided in RFC synthesis).
- audit-log table for administrative edits (coordinated with the
  metadata schema RFC; final scope decided in RFC synthesis).

Cross-cycle note

Until the RFC lands and ships, the v0.1.8.5 workflow article's teaching
path remains "your store path is explicit, but the discipline of
recording ETL provenance belongs in your project README or
workflow_review.md report next to the store." That documentation-only
guidance was landed inside the v0.1.8.5 Batch 3 (LDG-2437) scope.

This horizon entry is the seed-shape input for the snapshot
administration RFC. It does not replace the RFC cycle, and the RFC
synthesis (not this entry) is what authorizes any future spec scope.

This horizon entry does not authorize any of the above. It records the
direction so that when the snapshot administration RFC cycle opens, the
seed author starts from a known shape rather than re-deriving the
boundary.

### 2026-05-27 [execution] Intraday support arc and pre-v0.2.x architectural footguns

ledgr's roadmap permanently excludes high-frequency, sub-millisecond, and
tick-by-tick execution. It does not exclude minute-to-hour bar resolution.
User feedback during the v0.1.8.5 cycle indicates intraday is real future
demand: many users who would use ledgr for EOD research also want to use it
for intraday research, and "the same backtester for both" is a defensible
USP. This entry captures the multi-cycle arc to support intraday as a
first-class workflow, plus the architectural footguns the in-progress
v0.1.x cycles must avoid so the eventual flip is not a rewrite.

This entry supersedes the earlier 2026-05-13 "Intraday architecture
feasibility" stub. The parallelism-spike evidence it cited remains at
`inst/design/spikes/ledgr_parallelism_spike/summary_report.md` and
`.../architecture_synthesis.md`; that spike used intraday-like payloads only to
stress data movement and did not test intraday snapshot schema, pulse
calendars, sub-day fill timing, or metrics at intraday scale.

The user will initiate a design audit before committing to the intraday
arc. This entry is the audit's input shape.

#### Today's posture: EOD-first, intraday-tolerant

The snapshot schema is timestamp-resolution-agnostic. A user can seal
1-minute or 1-hour bars today, declare a feature map, and run a strategy
against them. The fold core, pulse model, ledger events, and accounting
mechanics are calendar-agnostic at the storage layer.

Every layer above storage assumes EOD shape, however:

- **Session calendars do not exist.** Warmup, annualization, and metric
  context all assume one bar equals one day. A 50-period SMA on 1-minute
  bars is 50 minutes, but annualization treats it as 50 days.
- **Fill timing is EOD-shaped.** The v0.1.8 internal cost boundary
  (`validated_targets -> next_open_timing -> fill_proposal -> cost ->
  fill_intent`) is swappable by design but ships with only `next_open`
  semantics. Intraday wants next-pulse-touch, mid-point, VWAP, or
  session-close policies that do not exist.
- **No OMS.** Strategies return target vectors. Intraday usually wants
  order lifecycle (place / modify / cancel, partial fills). That work is
  v0.2.x with an accepted synthesis at
  `inst/design/rfc/rfc_ledgr_oms_seed_synthesis.md`.
- **Cost / liquidity policy is not intraday-aware.** The v0.1.9.x/v0.2.0
  cost API works for intraday in principle, but participation, capacity,
  and minimum-ADV policy (also v0.2.x) is what intraday actually needs.
- **Storage scale changes.** The v0.1.8.6 feature-storage spike measures
  EOD workloads. Intraday changes the answer.

Users who run intraday today get coherent reproducibility on the data and
strategy axes and broken semantics on the metric and fill-timing axes. The
honest framing for v0.1.8.5 docs is "intraday bars seal fine but metric
annualization assumes EOD; treat results as exploratory until v0.2.x."

#### The required arc

First-class intraday is a multi-cycle endeavor:

1. **OMS semantics** (v0.2.x, accepted synthesis) — load-bearing for
   order lifecycle, partial fills, and the two-stream `order_events` /
   `ledger_events` separation.
2. **Session calendar infrastructure** (new RFC, post-OMS) — exchange
   sessions, holidays, half-days, lunch breaks, pre/post-market handling.
3. **Intraday fill-timing policy** (extends v0.1.9.x cost API arc) —
   next-pulse-touch, mid-point, VWAP, session-open / session-close, with
   the same swappable boundary the EOD `next_open_timing` already uses.
4. **Intraday-aware metric context** (extends v0.1.8.2 metric context
   work) — annualization factor parameterized by cadence and sessions,
   not hardcoded.
5. **Liquidity / capacity policy** (current
   [execution-policy route](rfc/README.md#execution-policy)) — execution
   feasibility separate from cost, with participation limits that mean
   something different intraday vs EOD.
6. **Storage scale evidence** (extends v0.1.8.6 spike) — the spike's
   exit-decision changes once intraday workloads enter the comparison.

The arc is parked across the RFC pipeline's
[OMS lifecycle](rfc/README.md#oms-order-lifecycle),
[execution-policy](rfc/README.md#execution-policy), and
[instrument-specific session-axis](rfc/README.md#instrument-specific-session-axis)
routes. The accepted OMS synthesis is the entry point; calendar infrastructure
still needs its focused RFC.

#### Architectural footguns the v0.1.x cycles must avoid

This is the operative section. The completed v0.1.8.10 cycle, the active
v0.1.8.11 documentation/cleanup cycle, and the planned v0.1.9/v0.1.9.x cycles
must not paint the framework into corners that the intraday flip will have to
rip out. The list below is the audit checklist.

- **Pulse cadence is a snapshot-derived property, not a global constant.**
  Any code path that hardcodes "trading day" semantics in the fold core,
  metric annualization, or warmup teaching is a footgun. Cadence must be
  read from the snapshot.
- **Warmup is bar-count, never time-implied.** `passed_warmup()` and the
  active-alias warmup pipeline are bar-count today. Correct for both EOD
  and intraday. Preserve. The trap lives in metrics, not warmup itself.
- **Metric context must expose a cadence/annualization slot.** The v0.1.8.2
  metric-context templates (US equity, crypto) reserved this surface.
  Audit them to confirm `annualization_factor` is a parameter, not a
  constant. Intraday metric context shares the calendar; the cadence
  changes.
- **Fill timing stays a swappable internal boundary.** The v0.1.8 cost
  boundary already reserved this. Preserve. No v0.1.x ergonomics work
  should bake `next_open` into a code path that should be policy-pluggable.
- **Strategy contract preserves intraday signatures.** Strategies return
  full named numeric target vectors. That signature works for both EOD
  and intraday. Do not add EOD-flavored methods to the canonical strategy
  context (`ctx$today()`, `ctx$is_market_open()`) in v0.1.x — those
  belong on a future intraday-aware context, not on the existing one.
- **Risk-layer affordability check must be net across one pulse's
  proposed fills, not per-instrument sequential.** The fold core's fill
  loop iterates per instrument and updates cash sequentially
  (`R/fold-core.R:233-287`). When the v0.1.9 target-risk layer adds
  affordability adapters, they must check feasibility against the net
  cash delta from all proposed fills at one pulse, not per-instrument:
  a per-instrument check would reject rebalancing strategies depending
  on instrument iteration order (BUYs checking cash before paired SELLs
  free it up), even though both fill at the same `t+1` open in reality.
  Intraday rebalancing makes this acute because rebalances fire more
  often; an equity-EOD test won't surface it. This also threads into
  the v0.2.x OMS two-stream design — `order_events` recorded as a
  batch atomic at the fill bar makes "shared cash pool at one fill
  timestamp" structural rather than implicit.
- **Storage schema stays timestamp-resolution-agnostic.** Today it is.
  The snapshot-administration RFC (v0.1.8.6) must explicitly preserve
  this and must not introduce fields that imply one row per instrument
  per day.
- **Sweep result and run identity stay frequency-agnostic.** `run_id`,
  `snapshot_hash`, `config_hash`, and sweep candidate identity must not
  encode "EOD" anywhere. They do not today — preserve.
- **OMS-shaped target-decision storage from the start.** The accepted
  OMS synthesis explicitly warns that intraday-compatible target storage
  needs retention-dependent, batchable, potentially sparse / columnar /
  payload-reference shapes. v0.1.x EOD work can implement the simple
  per-decision shape but must not commit to a schema the OMS work will
  have to rip out destructively.
- **Cost API spread / participation assumptions stay EOD-neutral.** The
  accepted v0.1.9.x cost API synthesis keeps `cost_spread_bps()` as a
  quoted-spread function over a fill context. Intraday extends the
  context, not the cost API. Preserve that boundary.
- **Demo data and demo strategies stay EOD-shaped.** That is fine. The
  footgun is letting demo-data assumptions leak into runtime invariants.
  Already correct today — preserve.
- **Walk-forward window semantics generalize from EOD-day folds to
  intraday-session folds.** The accepted walk-forward synthesis represents
  scoring windows explicitly. Audit to confirm the window model does not
  hardcode day semantics.
- **Dense-panel fail-fast is a backtest seal-time gate, not a universal
  invariant.** `ledgr_missing_bars` aborts the run if any instrument lacks a
  bar at any pulse (verified: cross-join completeness check
  `backtest-runner.R:1541-1564`; per-instrument alignment
  `backtest-runner.R:1154-1159`). That is correct for sealed backtest data and
  wrong for live streaming, where missing/garbled ticks are routine. The
  v0.2.x data-model and live-data work must not treat the dense panel as
  permanent — see the 2026-05-28 live bad-data resilience entry.

#### Migration efficiency requirements

A clean migration to first-class intraday means:

- existing EOD users' runs remain reopenable after the intraday flip
  lands;
- the public strategy contract `function(ctx, params) -> target vector`
  survives intact; the context object gains intraday-aware methods but
  loses none;
- cost API stays additive — new timing/cost policies are opt-in
  constructors, not breaking changes;
- run identity hashes stay stable for unchanged EOD inputs after the
  intraday code lands;
- the snapshot administration schema accommodates intraday bars without
  schema migration on EOD stores.

The pre-CRAN compatibility policy authorizes breaking changes within
v0.1.x to clean up footguns before they become permanent. Use that
window deliberately. After CRAN, the migration becomes much more
expensive.

#### Design audit scope

The user will initiate a design audit. The audit's input is this entry
plus the affected code paths. Suggested audit scope:

- every code path that assumes "day" semantics: metric annualization,
  calendar inference, warmup teaching prose, demo data shape;
- every API boundary that could plausibly be cadence-aware but isn't:
  `metric_context`, fill timing, `ledgr_run_info()` cadence reporting,
  sweep candidate metadata;
- every place where session boundaries (open/close, lunch breaks,
  holidays, half-days) would matter once intraday lands: pulse calendar
  construction, opening/closing fill behavior, warmup hydration across
  sessions;
- the OMS synthesis target-decision-storage section, to confirm v0.1.x
  EOD storage decisions do not preclude the intraday-compatible shape;
- the cost API synthesis fill-context section, to confirm the context
  shape supports intraday extensions without API rewrite;
- the walk-forward synthesis window model, to confirm window semantics
  generalize from EOD folds to intraday session folds;
- the snapshot-administration RFC seed-shape (this horizon), to confirm
  the metadata model is cadence-neutral;
- demo data, vignette code, and contract tests for any place that
  conflates "one bar = one day" with "one pulse = one decision".

Audit output: a list of footguns that exist today, a list of footguns
the in-progress cycles must not introduce, and a list of decisions that
are already correct and worth pinning with contract tests so they do
not regress.

#### RFCs to revisit after the audit

The audit will read existing synthesis documents to check whether their
accepted designs survive an intraday flip. The list below is grouped by
how directly each RFC touches cadence, fill timing, target lifecycle,
or storage shape. A "revisit" outcome can be one of three: confirm the
design is already cadence-neutral and pin it; identify a specific clause
that needs to be amended before the corresponding implementation cycle
opens; or open a follow-up RFC to extend the existing synthesis.

**Tier A — load-bearing for intraday, must revisit:**

- `rfc/rfc_ledgr_oms_seed_synthesis.md` — the target-decision-storage
  section already mentions intraday-compatible storage shape (retention-
  dependent, batchable, potentially sparse/columnar/payload-reference).
  Confirm that any v0.1.x EOD per-decision storage work does not preclude
  the future shape destructively.
- `rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md` —
  confirm the `fill_context` shape supports intraday extension (next-
  pulse-touch, mid-point, VWAP, session-close timing) without breaking
  the public cost-model factory API.
- `rfc/rfc_risk_free_rate_metric_context_v0_1_8_1_synthesis.md` —
  confirm `metric_context` exposes `annualization_factor` (or
  equivalent) as a parameter, not a hardcoded 252 anywhere downstream.
  Audit the US-equity and crypto templates for hidden EOD constants.
- `rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md` — confirm the
  training/test-window model represents windows in calendar terms that
  generalize to intraday session folds, not just EOD-day folds. The
  synthesis says windows are explicit; verify "explicit" includes the
  cadence axis.
- `rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md` — confirm
  the risk-step interface is cadence-neutral. Risk decisions intraday
  fire much more often; the boundary must not embed EOD-pulse-rate
  assumptions in the step semantics.

**Tier B — architectural foundations intraday inherits, recommend revisit:**

- `rfc/rfc_research_workflow_artifact_topology_v0_1_8_x_synthesis.md` —
  confirm sealed-snapshot lineage and one-store topology decisions stay
  cadence-neutral. Intraday lineage (e.g., yesterday's session bars
  rolled forward into today's snapshot) is a v0.2.x roll-forward concern;
  the v0.1.8.5 topology should not preclude it.
- `rfc/rfc_sweep_single_core_optimization_routes_v0_1_8_synthesis.md` —
  confirm the runtime projection interface and R-memory backend make no
  "one row per instrument per day" assumption. Intraday volume changes
  the memory profile; the projection contract should already handle this
  but worth pinning.
- `rfc/rfc_pulse_context_data_model_consolidation_v0_1_8_3_synthesis.md` —
  confirm the consolidated pulse-context model does not embed EOD-flavored
  methods or shape assumptions. The strategy contract is the long-term
  intraday boundary.
- `rfc/rfc_sweep_candidate_promotion_contract_v0_1_8_synthesis.md` and
  `rfc/rfc_sweep_promotion_context_v0_1_8_synthesis.md` — confirm
  candidate and promotion-context identity (seeds, hashes, params) is
  frequency-agnostic. Already believed to be true; pin with contract
  tests if so.

**Tier C — feature and storage shape, scan for footguns:**

- `rfc/rfc_active_parameterized_feature_aliases_v0_1_8_x_synthesis.md` —
  confirm feature-parameter semantics do not imply EOD frequency.
  `ledgr_param("fast_n")` is a count, not a calendar duration; preserve.
- `rfc/rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x_synthesis.md` —
  scan for memory and volume assumptions tied to EOD bar counts. Wide
  runtime views at intraday scale are a v0.1.8.6 spike concern.
- `rfc/rfc_multi_output_indicator_ux_synthesis.md` — confirm bundle
  output shape is frequency-neutral.
- `rfc/rfc_indicator_codebase_simplification_v0_1_8_x_synthesis.md` —
  confirm indicator surface (series_fn contract, adapters) treats bar
  cadence as snapshot-derived, not global.

**Tier D — performance and measurement:**

- `inst/design/spikes/ledgr_parallelism_spike/architecture_synthesis.md` —
  worker assumptions and serialization costs change at intraday volume;
  re-evaluate if intraday lands.
- `rfc/rfc_collapse_primitive_internals_v0_1_9_synthesis.md` — the
  primitive-internals decisions assume EOD-scale workloads. Intraday
  changes the cost/benefit math; the synthesis already conditions
  implementation on measurement, so this is mostly "rerun the
  measurement at intraday scale before promoting Phase B/C.1."

**Horizon entries (seed-shape inputs) that should also be re-read:**

- the snapshot administration entry (2026-05-27, this file) — already
  amended with an intraday-readiness scope risk;
- the research-loop ergonomics helpers entry (2026-05-27, this file) —
  helper output shape must be cadence-neutral;
- the walk-forward post-v0.1.9.x direction entry (2026-05-27, this file)
  — confirm follow-up directions extend cleanly to intraday folds;
- the cost-model post-v0.1.9.x direction entry (2026-05-27, this file)
  — confirm timing/cost extensions accommodate intraday fill policies.

The audit should record, for each RFC above, whether it is **pinned**
(design is cadence-neutral, add contract tests), **amend** (one or more
specific clauses need updating in the existing synthesis), or **extend**
(open a new RFC that extends the existing synthesis for intraday). The
audit output is itself an input for the v0.2.x intraday-arc cycle
planning.

#### Current routes and parked follow-ups

- intraday support arc (multi-cycle, not committed) — depends
  on OMS, session calendars, intraday fill timing, liquidity/capacity,
  intraday-aware metric context, and intraday storage scale evidence;
- session calendar infrastructure RFC — parked new work routed through the
  instrument-specific session-axis row after OMS lands;
- intraday metric context extension — extends v0.1.8.2 metric context
  work; same calendar surface, parameterized cadence;
- intraday fill timing policy — extends v0.1.9.x/v0.2.0 cost API arc;
- intraday storage scale evidence — extends v0.1.8.6 feature-storage
  spike with intraday workload comparisons if the spike is rerun;
- design audit for intraday-readiness footguns — user-initiated, no
  committed cycle, but this entry provides the input shape.

#### Cross-cycle note

This entry does not authorize new cycles. Its operative effect is on the
completed v0.1.8.10 cycle, the active v0.1.8.11 documentation/cleanup cycle,
and the planned v0.1.9 and v0.1.9.x cycles: each must avoid the footguns named
above.
The user-initiated design audit will produce a sharper list of "preserve
this" and "fix this before it becomes permanent" findings. Until the
audit lands, treat this entry as a soft constraint on architectural
decisions in cycles that touch metric context, fill timing, target
storage, pulse cadence, or sweep candidate identity.

The "EOD-first, intraday-tolerant" posture remains the right user-facing
framing for v0.1.8.5 documentation. Do not pre-document intraday
support; do not pre-commit to it in user-facing prose; do not let
intraday assumptions sneak into v0.1.x code that should be cadence-
neutral.

This horizon entry does not authorize the intraday arc itself. It
records direction so that when the arc opens, the seed authors start
from a known shape rather than re-deriving the boundary, and it
constrains the in-progress v0.1.x cycles to avoid footguns that would
make the eventual flip a rewrite.

### 2026-05-28 [data] Live bad-data resilience and sim-to-real backtest fidelity

The overall arc is backtest -> paper -> live. Live data is structurally
different from backtest data, and the difference is a fault line the
backtest-first design has not had to confront. Surfaced while reviewing the
fold core; the maintainer has flagged it as RFC-worthy.

The fault line

ledgr's backtest correctness rests on a **sealed dense panel**, enforced
fail-fast: every instrument must have a bar at every pulse or the run aborts
with `ledgr_missing_bars` (verified: cross-join completeness check
`backtest-runner.R:1541-1564`; per-instrument alignment
`backtest-runner.R:1154-1159`). Live data is the opposite posture — a
streaming partial feed where missing, garbled, late, duplicated, or revised
ticks are routine. You cannot abort a live session because one symbol's tick
did not arrive. "Validate everything upfront, fail fast" and "tolerate and
degrade per-tick" are structurally opposed.

Second fault line — offline ragged universes (not just live)

The dense-panel gate also blocks a purely *offline* case: a realistic surviving
universe is inherently ragged. IPOs / late listings, delistings, halts, and
exchange holidays mean a security legitimately has no bar at some pulses — yet
the coverage check (`backtest-runner.R:815-822`, `LEDGR_SNAPSHOT_COVERAGE_ERROR`,
plus the `ledgr_missing_bars` cross-join check) requires every instrument to
have a bar at every pulse, so survivorship-realistic research is impossible
without external pre-cleaning. This is independent of the live/streaming arc.

Peer evidence (2026-05-29 research): among multi-asset / panel backtesters,
hard-failing on any per-instrument gap is an **outlier**. The mainstream
tolerates ragged panels — Zipline and LEAN forward-fill and model **asset
lifetimes** (start/end/delist, masking outside the active window with NaN/zero;
`zipline data_portal.py:1018-1030`, LEAN fill-forward-until-delisted); `bt`
(Python) and VectorBT carry not-yet-listed / delisted assets as NaN columns and
object only on a *held* NaN position. The only hard-failers are *single-asset*
frameworks (backtesting.py) or per-symbol loops (quantstrat), where there is no
cross-sectional alignment to solve. So strict single-series rejection is
mainstream; strict *multi-asset-panel* rejection is not.

Design target: **per-instrument active windows** (asset lifetimes) — an
instrument is active over `[first_bar, last_bar]` and the fold tolerates its
absence outside that window — plus an **explicit, sealed** absence/imputation
policy. The ledgr-specific constraint vs peers: their ffill is *silent*; ledgr's
"evidence you can defend" USP requires the active-window and any
fill / NaN / staleness policy to be **declared and sealed into the snapshot**
(and visible in provenance), not silently imputed in the fold — otherwise the
backtest runs on a quietly different data world than the inputs claim. The
*where* matters: active windows + the ingest policy live at the seal boundary;
the fold then consumes a panel marked "present / absent-by-lifetime / imputed",
and never hard-fails on legitimate absence.

Failure taxonomy (each needs a different policy)

- **Missing tick** — skip the symbol, carry forward last value with a
  staleness flag, halt the symbol, or halt the session.
- **Garbled tick** — zero/negative/NaN price, OHLC violation, absurd spike.
  Backtest catches this at seal time; live must catch it at ingest time and
  quarantine/reject before it reaches a decision.
- **Late / out-of-order tick** — needs a watermark/lateness policy.
- **Duplicate tick** — idempotent ingest.
- **Revised tick** — vendor corrects a past bar after the decision was made;
  you cannot un-decide. Hardest case.

What carries over vs what breaks

Carries over: the event-sourced ledger (a live session is a longer append-only
event stream), the pulse model (a live pulse is information available at
decision time t; no-lookahead is trivially satisfied), and the v0.2.x OMS
two-stream design. Breaks: the dense-panel fail-fast, and snapshot
immutability (live appends as data arrives — an append-only data log, not a
sealed snapshot).

Chosen direction: B — the backtest must model degraded data

Two ways to close the sim-to-real gap:

- **(A)** force live into the dense-panel model — buffer/wait/skip. Simple,
  preserves the backtest model, adds latency, not always viable.
- **(B)** give the backtest the ability to model degraded data — gap
  injection, staleness, halts, bad-tick spikes — so strategies are validated
  against realistic data conditions before live.

**Decision: direction B.** The "evidence you can defend" USP collapses if the
evidence was gathered on a cleaner data world than the strategy will face live.
When paper trading is designed, the maintainer wants to simulate data streams
with all kinds of deficiencies, at a much higher frequency than EOD, to test
the seams — and the backtest engine must be able to swallow that bad data on
the same execution path. So the backtest data model has to grow a "this bar is
missing / stale / suspect" representation it does not have today.

Design principles

- **Strategy contract does not change.** A strategy sees "current pulse-known
  information" in both backtest and live. What changes is what the *data layer*
  decides "current" means when a tick is missing or suspect. Degradation
  policy must not leak into every strategy.
- **Late/revised ticks intersect Point-In-Time Data Tables** (v0.2.x:
  `known_at`, `available_at`, `revision_time`, source version). A PIT model
  keeps "the decision at t used the data available at t" true even after a
  later revision — the revision is a new vintage, not a rewrite of history.
- **Missing/garbled at ingest needs a live data-quality layer** with an
  explicit degradation policy (quarantine / reject / carry-forward-with-
  staleness / halt-symbol / halt-session), distinct from the backtest
  seal-time gate.

RFC scope (when it opens)

A unified data-quality model spanning sealed backtest and streaming live; the
degradation-policy surface; **per-instrument active windows (asset lifetimes) for
ragged offline universes, with an explicit sealed absence/imputation policy
(vs peers' silent ffill)**; the bad-data simulation harness for backtest
(deficient high-frequency streams); and the PIT-tables intersection.

Sequencing

Behind PIT tables and the live data log (v0.2.x) and the OMS work; lands around
v0.2.x -> v0.3.0 paper trading. The high-frequency deficient-stream simulation
is a v0.3.0 paper-trading design input. Near-term footgun is already recorded
in the intraday-readiness entry: the dense panel is a backtest gate, not a
universal invariant.

This horizon entry does not authorize the work. It records the direction and
the chosen approach (B) so the eventual RFC starts from a known shape.

### 2026-05-28 [adapters] External-package output adapters (PerformanceAnalytics first)

ledgr's stable public result tables (equity, fills, trades, ledger) plus the
stored metric context are the right substrate for thin, optional, output-only
adapters into the established R quant ecosystem. No current packet, roadmap
row or RFC-pipeline row commits this work; it remains parked here until a
concrete output-consumer workflow triggers a focused RFC. An accepted RFC
synthesis — not this entry — would authorize any public API.

The first adapter is **PerformanceAnalytics**, scoped to its real strength — the
drawdown/return tables and long-tail risk/return stats, not its charts. It is a
pure output projection (equity -> return stream -> PA), so it touches no
causality, strategy-contract, determinism, or engine-mutation surface, and is
the cleanest public proof of the hexagonal pattern: ledgr owns the canonical
evidence, adapters enrich the analysis.

Charting is a separate, swappable renderer over the same return stream — not a
PA lock-in. PA's base-R graphics are a familiar/legacy option; the modern faces
are tidyquant (ggplot2 over the same PA metrics — distinct from the academic
tidyfinance) or a native ledgr ggplot tear-sheet (`R/plot.R` already exists).
The reusable port is the equity -> return conversion; many renderers consume it.

Why high-value: one stable result-table contract unlocks the whole
PerformanceAnalytics / PortfolioAnalytics / tidyfinance reporting and research
surface — a large host of additional capabilities (tear sheets, risk/return
tables, factor research, portfolio optimization) — without ledgr reimplementing
any of it.

Adapter ranking (later ones gated on their own readiness):

- PerformanceAnalytics — reporting / tear-sheet; first, output projection only.
- PortfolioAnalytics — portfolio construction / post-ledger optimization; after
  the v0.1.9 target-risk chain stabilizes.
- tidyfinance — factor / data research; with the v0.2.x PIT / vintage semantics.
- quantmod — data ingestion; useful but less differentiating.
- PMwR / quantstrat / blotter / fPortfolio — low priority or skip (accounting /
  engine overlap that would blur which engine is the source of truth).

Boundary the RFC must bind:

- output projection only — no second canonical metrics path;
- consume ledgr's OWN canonical return series (whatever `ledgr_compute_metrics`
  derives); never reinvent the return formula inside the adapter, or the base
  series silently diverges;
- PerformanceAnalytics metrics use PA conventions and can differ from ledgr's;
  scope PA to what ledgr does NOT already compute and label any overlap rather
  than presenting two conflicting Sharpe numbers as both authoritative;
- optional dependency (`Suggests` + `check_installed`), never `Imports`;
- adapters inspect, they do not select winners (no sweep ranking / promotion
  automation) — selection stays human, per the promotion-is-not-validation
  stance;
- benchmark-relative metrics coordinate with the v0.2.x benchmark-context layer
  so PA does not become the de-facto benchmark-metrics surface ahead of ledgr's
  own contract;
- one shared adapter namespace pattern (e.g. `ledgr_<pkg>_*`) decided up front;
- live `findInterval`+`cumsum` reconstruction and the reopened DB-replay path
  must yield identical adapter output.

Inside ledgr under `Suggests` for the first adapter (it proves the pattern
publicly); split into `ledgr.adapters` or per-package packages only if the
surface grows. Source: the 2026-05-28 maintainer review of an adapter-ecosystem
proposal.

This entry records direction, not committed work.

## Historical redirects

These exact headings preserve links into bodies moved to
`horizon_archive.md`. Redirects are navigation, not active parking or
authority.

### 2026-10-12 [adapters] Sharadar dividend-fact mapping before the WS7 lake rebuild

Promoted: [post-gate live routes](ledgr_v0_2_2_spec_packet/macro_plan.md#post-gate-live-routes) name the current adapter, lake-rebuild, WS7, WS8 and headline owners. [Historical body](horizon_archive.md#ws34-open-006).

### 2026-10-11 [execution] One execution mode: dense as a special case of availability

Promoted: [execution-core consolidation](ledgr_v0_2_2_spec_packet/macro_plan.md#execution-core-consolidation) records the later accepted owner and supersession. [Historical body](horizon_archive.md#ws34-open-009).

### 2026-10-02 [research] Research-side findings index and the EXP-0003 handoff

Promoted: [research findings index](research/ledgr-research-findings-index.md) is the one current owner. [Historical body](horizon_archive.md#ws34-open-015).

### 2026-09-25 [ux] Availability evidence has no convenient reader

Shipped: [Cut 9 closeout](ledgr_v0_2_0_2_spec_packet/availability_accessors_closeout.md#what-shipped) records LDG-2826 through LDG-2830 and the public readers/selectors. [Historical body](horizon_archive.md#ws34-open-022).

### 2026-06-04 [infrastructure] Installed design-tree footprint review

Shipped: Cut 14 excludes `inst/design` from built packages and Cut 15 keeps its source path. [Historical body](horizon_archive.md#ws34-open-044).

### 2026-05-26 [ux] Tidy/vectorized strategy authoring layer

Superseded by the accepted strategy-context and strategy-authoring designs named in the [historical body](horizon_archive.md#ws34-open-049).

### 2026-06-05 [planning] v0.1.9.4 walk-forward Section 17 gate-row obligations from the v0.1.9.x arc -- resolved by v0.1.9.4

Promoted and archived: [historical body](horizon_archive.md#resolved-001). Durable authority: [v0.1.9.4 packet](ledgr_v0_1_9_4_spec_packet/README.md).

### 2026-06-05 [planning] v0.1.9.1 cost-API spec-cut decisions on synthesis Section 13 open questions -- resolved by v0.1.9.1

Promoted and archived: [historical body](horizon_archive.md#resolved-002). Durable authority: [v0.1.9.1 packet](ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md).

### 2026-06-04 [documentation] Documentation, structure, and cleanup release shipped v0.1.8.11

Promoted and archived: [historical body](horizon_archive.md#resolved-003). Durable authority: [v0.1.8.11 release record](ledgr_v0_1_8_11_spec_packet/v0_1_8_11_release_closeout.md).

### 2026-05-15 [adapters] Multi-output indicator authoring bundles — shipped v0.1.8.1

Promoted and archived: [historical body](horizon_archive.md#resolved-004). Durable authority: [v0.1.8.1 packet](ledgr_v0_1_8_1_spec_packet/v0_1_8_1_spec.md).

### 2026-05-15 [ux] Parameter-grid construction helpers — shipped (core) v0.1.8.4

Promoted and archived: [historical body](horizon_archive.md#resolved-005). Durable authority: [v0.1.8.4 packet](ledgr_v0_1_8_4_spec_packet/v0_1_8_4_spec.md).

### 2026-05-25 [optimization] Grid-union shared pulse views — shipped v0.1.8.4

Promoted and archived: [historical body](horizon_archive.md#resolved-006). Durable authority: [v0.1.8.4 packet](ledgr_v0_1_8_4_spec_packet/v0_1_8_4_spec.md).

### 2026-05-15 [execution] Single-core sweep hot-path optimization — shipped v0.1.8.3

Promoted and archived: [historical body](horizon_archive.md#resolved-007). Durable authority: [v0.1.8.3 packet](ledgr_v0_1_8_3_spec_packet/v0_1_8_3_spec.md).

### 2026-05-13 [execution] Compact execution semantics article — shipped v0.1.8.5

Promoted and archived: [historical body](horizon_archive.md#resolved-008). Durable authority: [v0.1.8.5 packet](ledgr_v0_1_8_5_spec_packet/v0_1_8_5_spec.md).

### 2026-05-13 [data] Data input and snapshot creation article — resolved v0.1.8.5

Promoted and archived: [historical body](horizon_archive.md#resolved-009). Durable authority: [v0.1.8.5 packet](ledgr_v0_1_8_5_spec_packet/v0_1_8_5_spec.md).

### 2026-06-01 [optimization] Feature projection materialization + storage spike + benchmark closeout — shipped v0.1.8.6

Promoted and archived: [historical body](horizon_archive.md#resolved-010). Durable authority: [v0.1.8.6 packet](ledgr_v0_1_8_6_spec_packet/v0_1_8_6_spec.md).

### 2026-06-01 [optimization] v0.1.8.7 Optimization Round 2 — shipped v0.1.8.7

Promoted and archived: [historical body](horizon_archive.md#resolved-011). Durable authority: [v0.1.8.7 packet](ledgr_v0_1_8_7_spec_packet/v0_1_8_7_spec.md).

### 2026-06-01 [infrastructure] Parallel sweep dispatch + typed execution spec — shipped v0.1.8.8

Promoted and archived: [historical body](horizon_archive.md#resolved-012). Durable authority: [v0.1.8.8 release record](ledgr_v0_1_8_8_spec_packet/release_closeout.md).

### 2026-06-01 [optimization] v0.1.8.9 single-core optimization round — shipped v0.1.8.9

Promoted and archived: [historical body](horizon_archive.md#resolved-013). Durable authority: [v0.1.8.9 release record](ledgr_v0_1_8_9_spec_packet/v0_1_8_9_release_closeout.md).

### 2026-06-03 [optimization] v0.1.8.10 single-core substrate and B2 closeout - shipped v0.1.8.10

Promoted and archived: [historical body](horizon_archive.md#resolved-014). Durable authority: [v0.1.8.10 release record](ledgr_v0_1_8_10_spec_packet/v0_1_8_10_release_closeout.md).

### 2026-09-29 [execution] Untradable holdings end the run instead of booking the loss

Promoted and archived: [historical body](horizon_archive.md#open-004). Durable destination: [terminal-outcomes synthesis](rfc/rfc_terminal_outcomes_v0_2_2_synthesis.md).

### 2026-09-28 [planning] Dependency order for the next version

Promoted and archived: [historical body](horizon_archive.md#open-005). Durable destination: [v0.2.2 macro plan](ledgr_v0_2_2_spec_packet/macro_plan.md).

### 2026-09-28 [infrastructure] Binding decisions must be discoverable

Promoted and archived: [historical body](horizon_archive.md#open-007). Durable destination: [design-memory plan](ledgr_v0_2_2_spec_packet/design_memory_overhaul_plan.md).

### 2026-09-28 [data] Historical revision optimization, deferred

Promoted and archived: [historical body](horizon_archive.md#open-008). Durable destination: [historical-projection v11](rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis_v11.md).

### 2026-09-28 [ux] Feature-map read surface RFC seeded

Promoted and archived: [historical body](horizon_archive.md#open-009). Durable destination: [feature-map decision](decisions.md#feature-map-read-surface).

### 2026-09-27 [ux] Strategy callback inspection boundary

Promoted and archived: [historical body](horizon_archive.md#open-010). Durable destination: [strategy-context pipeline row](rfc/README.md#strategy-context-preflight).

### 2026-09-27 [data] Instrument-narrowed expected sessions, deferred

Promoted and archived: [historical body](horizon_archive.md#open-012). Durable destination: [historical-projection v11](rfc/rfc_point_in_time_historical_projection_v0_2_x_synthesis_v11.md).

### 2026-09-27 [execution] Writer and accessor levers measured

Promoted and archived: [historical body](horizon_archive.md#open-013). Durable destination: [v0.2.2 macro plan](ledgr_v0_2_2_spec_packet/macro_plan.md).

### 2026-09-26 [data] Latent behaviours surfaced by the preparation spike

Measured evidence archived: [historical body](horizon_archive.md#open-015). No current authority is claimed.

### 2026-09-24 [data] Equity corporate actions post-v0.2.0.2 direction

Promoted and archived: [historical body](horizon_archive.md#open-017). Durable destination: [equity-settlement synthesis](rfc/rfc_equity_settlement_post_v0_2_0_2_synthesis.md).

### 2026-09-24 [data] Exact equity quantity settlement remains a product gap

Promoted and archived: [historical body](horizon_archive.md#open-018). Durable destination: [equity-settlement synthesis](rfc/rfc_equity_settlement_post_v0_2_0_2_synthesis.md).

### 2026-09-22 [product] A quarantined row's copy is a diagnostic, not identity

Promoted and archived: [historical body](horizon_archive.md#open-019). Durable destination: [roadmap or owning released packet](ledgr_roadmap.md).

### 2026-09-22 [process] Sequential A/B timing invented a regression

Measured evidence archived: [historical body](horizon_archive.md#open-020). No current authority is claimed.

### 2026-09-22 [product] DuckDB reads the ingestion CSV

Promoted and archived: [historical body](horizon_archive.md#open-021). Durable destination: [roadmap or owning released packet](ledgr_roadmap.md).

### 2026-09-22 [product] One CSV ingestion surface

Promoted and archived: [historical body](horizon_archive.md#open-022). Durable destination: [roadmap or owning released packet](ledgr_roadmap.md).

### 2026-09-22 [architecture] Accounting core accepted; what it deferred

Promoted and archived: [historical body](horizon_archive.md#open-023). Durable destination: [accounting-core synthesis](rfc/rfc_accounting_core_consolidation_v0_2_0_2_synthesis.md).

### 2026-09-21 [infrastructure] Testing architecture accepted; what it deferred

Promoted and archived: [historical body](horizon_archive.md#open-024). Durable destination: [testing-architecture synthesis](rfc/rfc_testing_architecture_v0_2_0_2_synthesis.md).

### 2026-09-21 [infrastructure] Governance loop accepted; what it deferred

Promoted and archived: [historical body](horizon_archive.md#open-025). Durable destinations: [governance synthesis](rfc/rfc_governance_review_post_v0_2_0_1_synthesis_v2.md) and [benchmark-methodology pipeline row](rfc/README.md#benchmark-methodology).

### 2026-09-20 [ux] Real-data workflow costs beyond accounting

Measured evidence archived: [historical body](horizon_archive.md#open-026). No current authority is claimed.

### 2026-09-20 [data] Equity accounting events now block real portfolio research

Measured evidence archived: [historical body](horizon_archive.md#open-027). No current authority is claimed.

### 2026-09-20 [data] Point-in-time universe inspection before execution

Measured evidence archived: [historical body](horizon_archive.md#open-028). No current authority is claimed.

### 2026-09-19 [execution] Availability result reconstruction is quadratic

Measured evidence archived: [historical body](horizon_archive.md#open-029). No current authority is claimed.

### 2026-09-18 [execution] Per-pulse context and feature accessor costs

Measured evidence archived: [historical body](horizon_archive.md#open-030). No current authority is claimed.

### 2026-09-18 [infrastructure] Peer benchmark session alignment defect

Measured evidence archived: [historical body](horizon_archive.md#open-031). No current authority is claimed.

### 2026-09-18 [execution] Duplicated FIFO accounting replays

Measured evidence archived: [historical body](horizon_archive.md#open-032). No current authority is claimed.

### 2026-09-18 [infrastructure] Duplicated helper families

Measured evidence archived: [historical body](horizon_archive.md#open-033). No current authority is claimed.

### 2026-09-17 [infrastructure] Durable-path ingestion and serialization observations

Measured evidence archived: [historical body](horizon_archive.md#open-034). No current authority is claimed.

### 2026-09-18 [execution] Compiled execution RFC and proof architecture

Promoted and archived: [historical body](horizon_archive.md#open-036). Durable destination: [compiled-envelope pipeline row](rfc/README.md#compiled-execution-envelope).

### 2026-09-15 [infrastructure] Evidence-gated removal of scale-growing R work

Promoted and archived: [historical body](horizon_archive.md#open-038). Durable destination: [roadmap or owning released packet](ledgr_roadmap.md).

### 2026-09-09 [infrastructure] API hardening post-v0.2.0 direction

Promoted and archived: [historical body](horizon_archive.md#open-041). Durable destination: [API-hardening synthesis](rfc/rfc_api_representation_hardening_v0_2_0_synthesis.md).

### 2026-09-08 [data] Asset availability post-v0.1.9.8 direction

Promoted and archived: [historical body](horizon_archive.md#open-042). Durable destination: [availability synthesis](rfc/rfc_asset_availability_point_in_time_universes_v0_1_9_8_synthesis.md).

### 2026-09-06 [infrastructure] CI critical-path and release-gate runtime hardening

Promoted and archived: [historical body](horizon_archive.md#open-043). Durable destination: [roadmap or owning released packet](ledgr_roadmap.md).

### 2026-09-06 [data] Ragged-universe prior art and RFC evidence handoff

Promoted and archived: [historical body](horizon_archive.md#open-044). Durable destination: [availability synthesis](rfc/rfc_asset_availability_point_in_time_universes_v0_1_9_8_synthesis.md).

### 2026-09-04 [infrastructure] Post-v0.1.9.6 review findings and invariant-hardening RFC candidate

Measured evidence archived: [historical body](horizon_archive.md#open-045). No current authority is claimed.

### 2026-09-04 [docs] Post-v0.1.9.6 all-vignette review findings

Measured evidence archived: [historical body](horizon_archive.md#open-046). No current authority is claimed.

### 2026-06-13 [docs] Deferred v0.1.9.5 vignette-audit items

Measured evidence archived: [historical body](horizon_archive.md#open-049). No current authority is claimed.

### 2026-06-13 [infrastructure] Peer benchmark redo with the cost and risk chains (v0.1.9.6)

Promoted and archived: [historical body](horizon_archive.md#open-050). Durable destination: [cost-API synthesis](rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md).

### 2026-06-13 [execution] v0.1.9.6 intraday-readiness code audit

Measured evidence archived: [historical body](horizon_archive.md#open-052). No current authority is claimed.

### 2026-06-13 [ux] Walk-forward degradation table curated print (shipped v0.1.9.5)

Promoted and archived: [historical body](horizon_archive.md#open-056). Durable destination: [validation pipeline row](rfc/README.md#validation-toolkit-follow-ups).

### 2026-06-11 [audit] Vignette screening for the v0.1.9.5 teaching cycle

Measured evidence archived: [historical body](horizon_archive.md#open-059). No current authority is claimed.

### 2026-06-11 [audit] Deep code review findings for the next release cycle

Measured evidence archived: [historical body](horizon_archive.md#open-060). No current authority is claimed.

### 2026-06-09 [research] Business-objective constructor RFC (Pardo-anchored)

Promoted and archived: [historical body](horizon_archive.md#open-068). Durable destination: [validation pipeline row](rfc/README.md#validation-toolkit-follow-ups).

### 2026-06-09 [adapters] Palomar adapter family for portfolio optimization scaffolding

Promoted and archived: [historical body](horizon_archive.md#open-070). Durable destination: [v0.2.2 macro plan](ledgr_v0_2_2_spec_packet/macro_plan.md).

### 2026-06-05 [infrastructure] Release-gate harness around playbook checks

Promoted and archived: [historical body](horizon_archive.md#open-071). Durable destination: [roadmap or owning released packet](ledgr_roadmap.md).

### 2026-06-05 [infrastructure] Release-gate tickets must not absorb executable doc/example migration

Promoted and archived: [historical body](horizon_archive.md#open-072). Durable destination: [roadmap or owning released packet](ledgr_roadmap.md).

### 2026-05-29 [execution] v0.1.8.7 optimization-round post-synthesis direction

Promoted and archived: [historical body](horizon_archive.md#open-074). Durable destination: [roadmap or owning released packet](ledgr_roadmap.md).

### 2026-05-30 [optimization] Post-v0.1.8.7 remaining fold-loop levers

Measured evidence archived: [historical body](horizon_archive.md#open-075). No current authority is claimed.

### 2026-05-31 [optimization] LDG-2476 peer-benchmark turnover cost decomposition

Measured evidence archived: [historical body](horizon_archive.md#open-076). No current authority is claimed.

### 2026-05-30 [architecture] Compiled fold core as `ledgrcore` sister package

Dropped as the current route and archived: [historical body](horizon_archive.md#open-077). Current route: [compiled-envelope pipeline row](rfc/README.md#compiled-execution-envelope).

### 2026-06-01 [architecture] R-side data structures as shared substrate for compiled-core path

Measured evidence archived: [historical body](horizon_archive.md#open-078). No current authority is claimed.

### 2026-06-01 [architecture] Architecture B: in-place hot-frame compilation as alternative to ledgrcore

Measured evidence archived: [historical body](horizon_archive.md#open-079). No current authority is claimed.

### 2026-06-02 [architecture] B2 spot-FIFO accelerator is not a derivatives accounting model

Promoted and archived: [historical body](horizon_archive.md#open-080). Durable destination: [accounting-core synthesis](rfc/rfc_accounting_core_consolidation_v0_2_0_2_synthesis.md).

### 2026-06-02 [documentation] Documentation, structure, and cleanup release before v0.1.9 features

Promoted and archived: [historical body](horizon_archive.md#open-082). Durable destination: [roadmap or owning released packet](ledgr_roadmap.md).

### 2026-06-01 [optimization] Ephemeral-mode xlarge wall attribution as gate for ledgrcore / Architecture B2 commit

Measured evidence archived: [historical body](horizon_archive.md#open-083). No current authority is claimed.

### 2026-06-01 [architecture] K1 measurement-spike verdict: compiled fold core authorized for inline-output design only

Measured evidence archived: [historical body](horizon_archive.md#open-084). No current authority is claimed.

### 2026-06-05 [optimization] Post-LDG-2522 ephemeral wall picture and Architecture A status

Measured evidence archived: [historical body](horizon_archive.md#open-085). No current authority is claimed.

### 2026-06-05 [execution] Spot-FIFO as default for ephemeral spot workloads (v0.1.9.x candidate)

Dropped as the current route and archived: [historical body](horizon_archive.md#open-086). Current route: [compiled-envelope pipeline row](rfc/README.md#compiled-execution-envelope).

### 2026-06-05 [planning] v0.1.9.x line sequencing -- four-tick arc culminating in walk-forward

Promoted and archived: [historical body](horizon_archive.md#open-087). Durable destination: [validation pipeline row](rfc/README.md#validation-toolkit-follow-ups).

### 2026-06-05 [research] v0.1.9.2 sweep artifact persistence RFC cycle accepted

Promoted and archived: [historical body](horizon_archive.md#open-088). Durable destination: [sweep-persistence synthesis](rfc/rfc_sweep_artifact_persistence_v0_1_9_x_synthesis.md).

### 2026-06-07 [research] Post-synthesis sweep persistence future obligations

Promoted and archived: [historical body](horizon_archive.md#open-089). Durable destination: [sweep-persistence synthesis](rfc/rfc_sweep_artifact_persistence_v0_1_9_x_synthesis.md).

### 2026-06-07 [research] Peterson (2017) methodology reference added

Measured evidence archived: [historical body](horizon_archive.md#open-090). No current authority is claimed.

### 2026-06-07 [research] Hypothesis recording as a first-class identity artifact

Promoted and archived: [historical body](horizon_archive.md#open-091). Durable destination: [sweep-persistence pipeline row](rfc/README.md#sweep-persistence-follow-ups).

### 2026-06-07 [planning] Portfolio optimization scaffolding -- four-level decomposition and architectural footguns

Promoted and archived: [historical body](horizon_archive.md#open-093). Durable destination: [v0.2.2 macro plan](ledgr_v0_2_2_spec_packet/macro_plan.md).

### 2026-06-07 [planning] Validation toolkit -- bundling selection-integrity diagnostics with the business-objective constructor under an adapter-first posture

Promoted and archived: [historical body](horizon_archive.md#open-094). Durable destination: [validation pipeline row](rfc/README.md#validation-toolkit-follow-ups).

### 2026-06-07 [planning] Walk-forward fold output -- preserve per-period candidate return vectors for validation-toolkit PBO adapter optionality

Promoted and archived: [historical body](horizon_archive.md#open-095). Durable destination: [validation pipeline row](rfc/README.md#validation-toolkit-follow-ups).

### 2026-06-05 [planning] v0.1.9.5 documentation, teaching, and contracts release after v0.1.9.x arc

Promoted and archived: [historical body](horizon_archive.md#open-096). Durable destination: [roadmap or owning released packet](ledgr_roadmap.md).

### 2026-06-01 [strategy] Strategy callback contract + authoring helpers post-v0.1.8.x direction

Promoted and archived: [historical body](horizon_archive.md#open-097). Durable destination: [strategy-context synthesis](rfc/rfc_strategy_context_surface_v0_2_x_synthesis.md).

### 2026-05-26 [execution] Accepted OMS direction and intraday-safe target-decision storage

Promoted and archived: [historical body](horizon_archive.md#open-099). Durable destination: [OMS synthesis](rfc/rfc_ledgr_oms_seed_synthesis.md).

### 2026-05-25 [infrastructure] Pre-CRAN compatibility policy

Promoted and archived: [historical body](horizon_archive.md#open-100). Durable destination: [RFC-cycle policy](rfc_cycle.md#pre-cran-compatibility-policy).

### 2026-05-13 [infrastructure] Public parallel sweep backend

Promoted and archived: [historical body](horizon_archive.md#open-109). Durable destination: [sweep-persistence synthesis](rfc/rfc_sweep_artifact_persistence_v0_1_9_x_synthesis.md).

### 2026-05-13 [infrastructure] Parallel worker setup and Tier 2 packages

Promoted and archived: [historical body](horizon_archive.md#open-110). Durable destination: [roadmap or owning released packet](ledgr_roadmap.md).

### 2026-05-13 [infrastructure] mori as transport, not hot lookup

Measured evidence archived: [historical body](horizon_archive.md#open-111). No current authority is claimed.

### 2026-05-13 [infrastructure] Worker-local read-only DuckDB transport

Promoted and archived: [historical body](horizon_archive.md#open-112). Durable destination: [roadmap or owning released packet](ledgr_roadmap.md).

### 2026-05-13 [data] Feature payload scale and indicator-width stress

Measured evidence archived: [historical body](horizon_archive.md#open-114). No current authority is claimed.

### 2026-05-14 [sweep] Promotion-grade sweep artifacts

Promoted and archived: [historical body](horizon_archive.md#open-117). Durable destination: [sweep-persistence synthesis](rfc/rfc_sweep_artifact_persistence_v0_1_9_x_synthesis.md).

### 2026-05-27 [risk] Affordability belongs in target risk

Promoted and archived: [historical body](horizon_archive.md#open-121). Durable destination: [roadmap or owning released packet](ledgr_roadmap.md).

### 2026-05-25 [data] Point-in-time data tables

Promoted and archived: [historical body](horizon_archive.md#open-124). Durable destination: [feature-projection synthesis](rfc/rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md).

### 2026-05-25 [data] Corporate actions and instrument master

Promoted and archived: [historical body](horizon_archive.md#open-125). Durable destination: [equity-settlement synthesis](rfc/rfc_equity_settlement_post_v0_2_0_2_synthesis.md).

### 2026-05-24 [data] Provider risk-free source divergence

Measured evidence archived: [historical body](horizon_archive.md#open-128). No current authority is claimed.

### 2026-05-28 [optimization] Feature projection shape post-v0.1.8.x direction

Promoted and archived: [historical body](horizon_archive.md#open-130). Durable destination: [feature-projection synthesis](rfc/rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md).

### 2026-05-28 [optimization] Persistent DB-replay reconstruction via DuckDB SQL

Measured evidence archived: [historical body](horizon_archive.md#open-131). No current authority is claimed.

### 2026-05-25 [architecture] Primitive internals and collapse acceleration

Promoted and archived: [historical body](horizon_archive.md#open-132). Durable destination: [roadmap or owning released packet](ledgr_roadmap.md).

### 2026-05-25 [api] Future ctx$feature_table deprecation review

Promoted and archived: [historical body](horizon_archive.md#open-133). Durable destination: [strategy-context synthesis](rfc/rfc_strategy_context_surface_v0_2_x_synthesis.md).

### 2026-05-25 [infrastructure] Compiled fold core after pipeline stabilization

Promoted and archived: [historical body](horizon_archive.md#open-134). Durable destination: [compiled-envelope pipeline row](rfc/README.md#compiled-execution-envelope).

### 2026-05-27 [evaluation] Walk-forward post-v0.1.9.x direction

Promoted and archived: [historical body](horizon_archive.md#open-137). Durable destination: [validation pipeline row](rfc/README.md#validation-toolkit-follow-ups).

### 2026-05-27 [execution] Cost-model post-v0.1.9.x direction

Promoted and archived: [historical body](horizon_archive.md#open-138). Durable destination: [cost-API synthesis](rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md).

### 2026-05-27 [ux] Research-loop ergonomics helpers surfaced by the v0.1.8.5 workflow vignette

Promoted and archived: [historical body](horizon_archive.md#open-141). Durable destination: [roadmap or owning released packet](ledgr_roadmap.md).

### 2026-05-28 [execution] RNG resume is non-deterministic for stochastic strategies

Promoted and archived: [historical body](horizon_archive.md#open-144). Durable destination: [roadmap or owning released packet](ledgr_roadmap.md).

### 2026-05-28 [architecture] Fold-core structural debt surfaced by adversarial review

Measured evidence archived: [historical body](horizon_archive.md#open-145). No current authority is claimed.

### 2026-10-08 [execution] Carried state over overlapping walk-forward test windows

Resolved and archived: [historical body](horizon_archive.md#resolved-015). Durable authority: contracts.md, Walk-forward, Contiguous carry (maintainer Type 2 decision 2026-10-09, Cut 11 Workstream 21).
