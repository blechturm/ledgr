# Per-element iteration audit of `R/`

**Date:** 2026-09-15. **Trigger:** sealing the registered 757-pulse availability
fixture (563 instruments, 426,191 bars, 60 complete membership lists) takes
850-868 s, against 19.78 s for 630,000 bars in the dense peer benchmark. The
maintainer asked for every instance of the anti-pattern: R-level iteration
over data-scale collections (for/while loops, `vapply`/`lapply` over rows or
column elements, `apply(df, 1, ...)`, `do.call(rbind, lapply(...))`, and
scale-growing list appends) where the count grows with bars, fact rows,
instruments x pulses, events, diagnostics, candidates, or folds.

**Method.** Three read-only passes over `R/` (114 files) by alphabetical third,
each grepping the loop forms above and reading the enclosing function to
record what is iterated, the per-iteration work, the execution path, and a
severity: HIGH = data-scale count with non-trivial per-iteration work on an
ingest/seal, fold, results, or hashing path; MEDIUM = data-scale but cheap, or
candidate/fold/instrument scale with non-trivial work; LOW = bounded or cold.
Totals are a discovery estimate from a non-reconstructive read of the source
(about 68 HIGH, about 90 MEDIUM, 350 LOW reviewed and listed by `file:line`
only); use them for direction, not as a census or an RFC claim. Nothing was
modified.

## Root cause of the 14-minute seal (measured)

| candidate | measured on the registered data |
| --- | ---: |
| `ledgr_fact_validate_membership_conflicts()` at seal (`availability-persistence.R:318`), O(n^2) pairs over 30,300 rows | 47.7 s for 6,000 rows; about 1,200 s extrapolated (459 M pairs); traced at 95.1% of the profiled seal (`probe_findings.md`) |
| per-timestamp `for` loop in `ledgr_availability_observation_times()` (`availability-ingest.R:200`) | about 17 s for 426,191 bars (0.02 s vectorised) |
| session-close token check on all bars | about 9 s |
| per-fact-row hash payload plus canonical JSON (30,300 rows) | about 7 s |
| per-row provenance JSON validation at seal | about 1 s |

The pairwise membership validator is the discontinuity. It runs at seal on all
persisted membership rows regardless of shape, although for complete-list rows
it cannot fire (every row asserts `member = TRUE`; it flags only overlapping
rows with different flags) and the snapshot constructor itself skips it. The
status and lifetime validators have the same O(n^2) shape (`availability-facts.R:1305`,
`:1347`) and run both at construction and at seal; they were small here only
because those tables were small. The dense benchmark never reached this path.

## Tier 1: fix first (data-scale, on hot paths)

1. **Seal validators, O(n^2).** `availability-facts.R:1326-1327` (membership,
   also called from `availability-persistence.R:318`), `:1305-1306` (status),
   `:1347-1348` (lifetime), `:1283/1286` (supersession chains, potentially
   O(n^2) when supersession links exist; the no-supersession path returns
   immediately). Replace each with a grouped, state-aware sweep: within
   each group (instrument and universe; instrument, source, and precedence
   for status), sort by `effective_from`, keep a running maximum end per
   state, and flag a row whose start lies before the running maximum of any
   other state, keeping half-open intervals, open ends, and the supersession
   exemption: O(n log n). A single running maximum across states does not
   preserve the current "overlapping opposing assertions" semantics.
   Set-backed membership rows may be excluded only after a setwise check that
   every persisted set row has `member = TRUE`, a valid header, and the
   snapshot invariants; the database does not enforce `set_id` implying
   `member = TRUE`.
2. **Fact payload and hash loops, run at least four times per seal.**
   `availability-facts.R:778` (`ledgr_fact_family_hash`, re-run by every
   `ledgr_facts_assert()`), `:938` (`ledgr_fact_ids`), `:962` (dedupe), `:931`,
   `:916`, `:927` (provenance), `:155` (set-id digest); `availability-persistence.R:184`
   (hash payload), `:232`, `:315`, `:340` (provenance JSON per row). Build one
   canonical string per row from column vectors, hash `unique()` provenance
   strings, and cache family hashes so `ledgr_facts_assert()` verifies instead
   of recomputing.
3. **Per-bar loops on ingest.** `availability-ingest.R:200` (timestamp loop;
   `ledgr_fact_time()` is already vectorised), `:167`, `:172` (quarantine rows,
   all bars on dirty input); `snapshot_adapters.R:139` (mixed character
   timestamps), `:557` (Yahoo index); `indicator-adapters.R:138`;
   `timestamp.R:128` (`ledgr_utc()`); `precompute-features.R:329`
   (`ledgr_normalize_ts_utc` per bar per instrument); `public-api.R:163`.
4. **Fold pulse loop.** The current provider (`availability-provider.R:91`,
   `:113`, `:144`, `:190`, `:210`, `:224`; full-table subsets per instrument per
   pulse, repeated per actionable target through `execution_view()` at
   `availability-economics.R:251`) is what the provider spike replaced; the
   prepared arm is the model. Still open: one-row diagnostic frames per
   instrument per pulse (`fold-engine.R:623`, `:715`, `:828`, `:849`, plus the
   writer at `availability-diagnostic-writer.R:30/44` and the per-append
   character-column copy at `:158`), now 85% of loop samples; valuation marks
   scanning each instrument's whole close history every pulse
   (`availability-economics.R:16`, O(instruments x pulses^2)); `execution_view`
   once per target instead of once per pulse (`:225`); compiled FIFO packing
   and unpacking every open lot on every batch (`compiled-spot-fifo.R:102`,
   `:125`); the event buffer copying six character columns and the meta list
   per fill (`sweep.R:1576-1584`); one-row strategy-state frames per pulse
   (`backtest-runner.R:469/532`); R-level lot lists (`lot-accounting.R:91`,
   `:174`, `:190/208`, `:229`); `ledgr_target_rebalance` per-id loop
   (`strategy-helpers.R:283`) and the `ctx$feature(id)` fallback (`:84`).
5. **Feature hydration.** `features-engine.R:308/310` (strict windows: a
   data-frame window subset, four `vapply`s, and both `fn` and `series_fn` on
   every bar, plus an `all.equal` parity check per bar), `:273` (fallback);
   `precompute-features.R:562-593` (candidates x defs x instruments with a
   full-bars comparison and one-row rbinds each).
6. **Finalisation and results.** Ledger events are JSON-parsed and FIFO-replayed
   per event on every run, and in `ledgr_run_finalize` the results of
   `run-finalize.R:285`, `:309`, `:335` are never read when the fold supplied
   equity facts; `ledgr_state_asof` is called once per pulse in terminal
   recovery (`run-finalize.R:161`: O(pulses x events) with two DB queries per
   pulse); the same per-event parse and replay appear in `backtest-runner.R:1466`,
   `lot-accounting.R:123`, `fold-reconstruction.R:73`, `:116`, `:311`, `:500`,
   `backtest-fills.R:143`, `derived-state.R:290`, `:343`, `:310` (all lots per
   pulse), `:194` (bars scan per pulse). The `availability` result view
   re-parses positions per timestamp and runs one history query per instrument
   per timestamp (`availability-results.R:254`, `:279`, `:328`, `:366`);
   `execution-timing.R:163` scans all diagnostics per fill; `sweep.R:1650`
   builds `canonical_json` per event at materialisation.

## Tier 2: candidate, fold, or run scale with real work (MEDIUM)

Run-store readers filter the whole events or equity table once per run and
parse `config_json` three times per run (`run-store.R:129`, `:239`, `:395`,
`:490`, `:514`, `:555`, `:760`); sweep persistence and reconstruction serialise
or parse JSON per candidate (`sweep-persistence.R:154`, `:512`, `:618`, `:674`,
`:751`; `sweep-persistence-schema.R:80-140`, `:215`, `:222`); sweep filters and
retention filter the long panel per candidate (`sweep-filter.R:46-75`,
`sweep-retention.R:290`, `:443`, `:892`); walk-forward builds one-row frames
per candidate and metric (`walk-forward.R:296`, `:703`) and queries per fold
(`walk-forward-inspection.R:409`, `:469`, `:552`); validation helpers rbind
one-row tibbles per candidate (`validation-dsr.R:194`, `:338`,
`validation-k-ratio.R:39`, `validation-min-track-record.R:38`); per-pulse view
materialisation (`runtime-projection.R:195`, `:300`, `:341`); the pulse
snapshot dev tool queries per instrument (`pulse-snapshot.R:214`, `:247`);
param-grid and precompute hash per candidate (`param-grid.R:47`, `:160`, `:214`,
`:356`; `precompute-features.R:151`, `:363`, `:525`); promotion context
subsets per row (`promotion-context.R:109`); business-objective stable region
(`business-objective.R:718`, `:1014`, `:1235-1248`); misc readers formatting
timestamps per element (`snapshots-list.R:119`, `run-store.R:272`,
`run-tags.R:208`); hydration alignment per instrument (`backtest-runner.R:872`,
`:933`, `:955`); `fold-engine.R:98` asset-state normalisation per id;
availability facts group checks (`availability-facts.R:162`, `:168`, `:271`,
`:1276`, `:1372`, `:1383`, `:966`, `:1093`, `:1112`); results readers
(`availability-results.R:125`, `availability-inspection.R:204`,
`feature-inspection.R:390`, `:475`, `fold-reconstruction.R:97`, `:564`,
`backtest-fills.R:197`); the prepared provider's compile loop
(`availability-provider-prepared.R:112`, once per build).

## Cross-cutting shapes

- One-row `data.frame()` per element followed by `do.call(rbind, ...)`: the
  diagnostics writer, strategy state, precompute rows, validation tibbles,
  walk-forward score rows. Typed column buffers or `rep()`-built columns fix
  every instance the same way.
- Full-table subset inside a loop over ids (`df[df$id == x, , drop = FALSE]`):
  provider resolvers, run-store readers, sweep filters, features. `split()`
  once or `match()` into preallocated planes.
- Per-element timestamp formatting and parsing (`ledgr_normalize_ts_utc`,
  `ledgr_iso_utc`, `ledgr_fact_time`) where the vectorised call already exists.
- Per-row JSON parse or `canonical_json()` where the strings repeat
  (provenance, metadata): validate and hash `unique()` values and `match()`
  back; persist typed columns for the two numeric event fields.
- Work computed and discarded: the three event loops in `ledgr_run_finalize`
  when the fold supplied equity facts; `ledgr_facts_assert()` rehashing every
  family on every call.

## LOW hits reviewed (350), by file

A-F (161): availability-diagnostic-writer.R:125,141; availability-economics.R:49,63,306;
availability-facts.R:570,609,613,625,712,746,749,765,1042,1242,1244;
availability-ingest.R:109,120,217,231,270; availability-inspection.R:332;
availability-persistence.R:18,157,177,213,229,231,250,266,277,297,299,349,364;
availability-policy.R:176,180,229,230,235,247,257; availability-provider-prepared.R:41,68,79;
availability-results.R:97,232; backtest-config.R:197,233; backtest-results.R:404,408,409,410,773,796,881;
backtest-runner.R:361,719,906,953,988,992,995,1268,1282,1344,1390,1430,1561,1573,1579,1588,1608;
business-objective.R:30,31,62,303,332,423,663,1064,1181,1185,1193,1211,1213,1263;
config-canonical-json.R:136,150; config-hash.R:26; config-validate.R:37,338;
cost-model.R:124,145,225,233,241,275,350,414; db-schema-create.R:34,309,350,386;
db-schema-validate.R:530,659,683,733,735; derived-state.R:358; determinism.R:40,45,93,105,137;
execution-timing.R:243; experiment-store-schema.R:62; experiment.R:502;
feature-alias-map.R:13,69,116,120,157,158; feature-cache.R:155; feature-inspection.R:32,37,38,39,499;
feature-map.R:67,79,96,173,202,203,216,226,253; feature-parameters.R:47,64,75,101,106,150,182,284,328,335,356;
features-engine.R:88,93,414,489; fold-engine.R:19,105,271,410,674; fold-event-buffer.R:29; fold-reconstruction.R:178.

G-R (94): indicator-builtins.R:65; indicator-bundle.R:11,22,38,76,83,119,125,154;
indicator-dev.R:86,105,106,120; indicator-ttr.R:426,598,770; indicator.R:145,151,155;
lot-accounting.R:108; metric-context.R:529,543; parallel-workers.R:133,136,204;
param-grid.R:184,241,249; precompute-features.R:168,169,434,439,440,484,486,504,505,540,542;
promotion-context.R:209,307; public-api.R:15; pulse-context.R:120,225,421,503,509,755,897;
pulse-snapshot.R:64,243,315; risk-model.R:96,178,186,208,226,281,305,358,387,511,563; rng.R:27;
run-finalize.R:143,396; run-store.R:86,125,169,200,224,576,621,645,662,877,880,881,886,891,892,894,899,900;
run-tags.R:71; runtime-projection.R:23,91,103,136,218,239,317,485,526.

S-Z (95): sim-bars.R:48; snapshot-source.R:42,52; snapshot_adapters.R:146,634; snapshots-hash.R:115;
strategy-contracts.R:10; strategy-extract.R:287; strategy-preflight.R:194,231,240,242,249,282,347,415,462,469,485,521,568,624,651;
strategy-provenance.R:111; sweep-filter.R:81,100,166,193,212,217,282,308,310-315,325-326,336-337,354,365,367,391-409,441;
sweep-persistence-schema.R:159,252,343; sweep-persistence.R:335,726,797-815;
sweep-retention.R:117-125,189-191,874,1137,1144,1174,1194,1203,1349; sweep-review.R:53,122;
sweep.R:326,331,337,793,1030,1104,1284,1285,1565,1911,1929,2241,2269,2286,2291,2309,2319,2331,2335;
validation-dsr.R:183,307,378; validation-pbo.R:254,290;
walk-forward-folds.R:117,177,237,254-256,463-464,485,497,506; walk-forward-inspection.R:241,248,671,688;
walk-forward.R:83,104-112,813.

Verified vectorised (not findings): the seal hash row formatting in
`snapshots-hash.R` (column-wise `paste`/`sprintf` per 10,000-row block), all
of `snapshots-seal.R` (SQL), and `snapshots-import-bars.R`.
