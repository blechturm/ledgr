# RFC Response: Snapshot Verification Policy for v0.2.2

- Status: Type 2 response to seed v1, non-binding
- Author: Claude (Fable 5.1)
- Date: 2026-10-12
- Mode: Type 2
- Seed: `rfc_snapshot_verification_policy_v0_2_2_seed.md` (Codex)
- Baseline read: the working tree at `1c8df889` plus the uncommitted seed
- Brief: drafted by Codex, used by the maintainer; this response stays
  provisional until the maintainer rereads brief and response together

## 1. Answer to the brief's question

No, not as written. The two-part shape, one cadence-neutral full hash plus
one proof reused inside a process, is the right size and survives the
attack. Three choices inside it do not:

1. the lease is carried by the wrong object: the locator never reaches the
   run guard, is rebuilt internally on the main paths, and its state
   environment survives `saveRDS()`;
2. the encoding direction inverts the evidence: a DuckDB-computed typed text
   is slower single-threaded, has no R oracle, and is the migration the
   parked placement RFC gates, while an R-side binary encoding is exact by
   construction and 22x faster than today in a probe at the Sharadar row
   count;
3. the seed bundles two separable levers, the fast hash and the reuse,
   whose measured value and risk differ by an order of magnitude.

Revise the seed around a process-local verified set keyed by store, snapshot,
root and rule, and an R-defined binary rule 3 computed in R over streamed
DuckDB fetches. Components and Merkle trees stay out, as the seed says.

## 2. Seed claims checked against code and measurements

| Claim | Result | Where |
| --- | --- | --- |
| Seal computes the full hash before `SEALED` | Holds | `R/snapshots-seal.R:164` |
| Every committed run recomputes the hash | Holds | `R/run-snapshot.R:55` |
| `ledgr_backtest()` hashes twice | Holds | `R/backtest.R:153`, then the guard |
| Walk-forward rehashes once per fold | Holds; finished test runs are reopened without it | `R/walk-forward.R:1043-1046` |
| Inspection and reconstruction rehash on demand | Holds | `R/availability-inspection.R:292`, `R/derived-state.R:60` |
| About 24 of 32 walk-forward minutes are rehash | An estimate (26 x 55 s), not a profile; the note says so | `dev/bench/notes/rehash_tax_findings.md` |
| A lease can live in the locator's private state | The environment serializes with the object (verified) | Section 4, F1 |

## 3. Probe: full-hash cost at the Sharadar row count

Scratch-only, synthetic, read-only against the repository: 1,166 instruments
x 4,717 bars = 5,500,022 rows in a temporary DuckDB, R 4.6.1, duckdb
1.5.6.9000, digest 0.6.39, Windows, one process, one repetition, 10,000-row
blocks throughout. Nothing under `E:/ledgr-data` was touched.

| Path | Elapsed |
| --- | ---: |
| Streamed fetch only (`dbFetch`, 10k rows) | 0.8 s |
| Current `ledgr_snapshot_hash()` (rule 1, R text) | 56.6 s |
| R binary typed encoding: length-prefixed UTF-8 ids, 8-byte epoch seconds, IEEE doubles with `-0` folded, validity bitmap, SHA-256 per block | 2.6 s |
| DuckDB `printf`/`strftime`/`string_agg`/`sha256`, 1 thread (hash_spike shape) | 7.1 s |
| Same, 8 threads | 1.2 s |
| `count(*)`, column sums, `min`/`max` timestamp | 0.10 s |

The 56.6 s reproduces the 55 s the rehash note derived for Sharadar, so the
synthetic shape is faithful enough for ordering the options. Hostile values
(2^-25 exact tie, 0.123456785, 1e15 + 0.5, 2^53, subnormal, `DBL_MAX`,
`-0`): `sprintf("%.17g")` agreed between R and DuckDB on 13 of 13; `%.8f`
after `round(x, 8)` disagreed on 4 of 13; `CAST(x AS VARCHAR)` on 9 of 13;
every value round-tripped through DuckDB bit-exactly; `CAST(DOUBLE AS BLOB)`
is unimplemented, so DuckDB cannot emit IEEE bytes. Limits: one machine, one
OS, synthetic ids of equal length, no fact rows; the rule-2 fact payload is
a separate 2 s on Sharadar and was not re-measured.

## 4. Findings

Severity: A = architectural defect, must change the seed; B = design
revision; C = spec-cut detail, recorded here so it is not lost.

### F1 (A). The lease cannot ride the locator through the package's object flow

- The run guard never sees a locator. `ledgr_run()` builds a config holding
  only `db_path`, `snapshot_id`, `snapshot_hash` and `snapshot_db_path`
  (`R/backtest.R:507`, `R/backtest-config.R:276`); the fold opens its own
  connection (`R/backtest-runner.R:725`) and the guard receives path and id
  from `R/run-prepare.R:68-69`. A locator lease needs a new side channel
  through `ledgr_run_fold()` for every run, resume, promotion and fold.
- Fresh locators are built internally on the main paths: every adapter seals
  through a raw connection and then constructs a new locator
  (`R/snapshot_adapters.R:434`, the `from_df`, `from_csv` and `from_yahoo`
  route); `ledgr_pulse_snapshot()` opens a dedicated one
  (`R/pulse-snapshot.R:226`); walk-forward candidate inspection reopens with
  `verify = FALSE` (`R/walk-forward-inspection.R:296`). A missed "explicit
  transfer" is a silent full rehash, not an error.
- The locator's `.state` is `new.env(parent = emptyenv())` (`R/snapshot.R:12`).
  Verified in this session: a field placed there survives `serialize()` and
  `saveRDS()`/`readRDS()`, and every copy shares the environment. The seed's
  "cleared when the locator crosses a serialization boundary" has no
  mechanism; it needs a process nonce the seed does not name. Workers are
  safe only by accident: sweep tasks carry an experiment payload without the
  snapshot (`R/sweep.R:1096`, `:1194`).
- `ledgr_state_reconstruct(run_id, con)` takes a raw DBI connection
  (`R/public-api.R:155`); there is no locator to hold a lease at all.

Smaller carrier, same threat boundary: a namespace-level verified set keyed
by (`ledgr_store_key(db_path)`, `snapshot_id`, stored root, rule version),
the shape of the existing `.ledgr_held_stores` registry
(`R/snapshot.R:96-116`). Seal and any full verification insert; the guard,
inspection and reconstruction look up with values they already hold; nothing
is serialized, transferred or threaded; a worker process starts empty. The
trust granted is wider by one case only, a second locator to the same store
and root in the same process, which is inside the seed's own exclusion (raw
DBI after trust). Falsifier: a supported public path that mutates sealed rows
under an unchanged root; none exists (`R/snapshots-seal.R:93-105`).

### F2 (A). The encoding direction inverts the evidence

The seed prefers typed text computed through DuckDB and rejects binary "for
v1 unless the conformance probe shows that typed text cannot be made exact or
affordable". The record already shows the opposite order:

- Exactness: the only text rule DuckDB and R agreed on in the probe is
  `%.17g`, which still rests on two C runtimes and one `fmt` library being
  correctly rounded at an exact tie (2^-25 is one), and has no R-side oracle
  for the DuckDB computation. IEEE bytes have no rounding step, tie, locale
  or formatter; the only fidelity needed is DBI returning the stored double
  and whole-second timestamp exactly, confirmed on every hostile value.
- Cost: R binary 2.6 s versus DuckDB text 7.1 s on one thread. The 8-thread
  1.2 s is not a product number: ledgr does not pin DuckDB threads
  (`R/public-api.R:1-7`, default is all cores), so a DuckDB-side root would
  cost whatever the host has, and the standing rule is single-core first.
- Authority: contracts name canonical R as the normative oracle for optimized
  paths. A rule defined by `writeBin()` and SHA-256 is that oracle; a DuckDB
  reproduction must match it byte for byte (F8). Observation 5 in
  `durable_path_observations.md` measured the same shape at 42x and named
  the four canonicalization choices; the seed does not cite it.

Revise Section 4.2: rule 3 is an R-defined typed binary stream over the
existing streamed `ORDER BY` fetch in fixed 10,000-row blocks: section and
column tags, length-prefixed UTF-8 text, 8-byte epoch seconds, IEEE-754
doubles with negative zero folded, a NULL bitmap, NaN and infinities refused
as today (`R/snapshots-hash.R:63-65`). Keep the reviewed rule-2 fact payload
(exactness reviewed in the Cut 3 spike) as one tagged section rather than
re-encoding facts in v1; it costs 2 s on Sharadar and its oracles exist.

### F3 (A). One ordering rule in rule 2 is locale-dependent today

Fact tables are ordered by SQL (`R/availability-persistence.R:199`, byte
order). Quarantine rows are re-ordered in R with `order()` on a character key
(`R/availability-persistence.R:305`), which follows the session collation: in
this session `order(c("b","B","a","A"))` gives `a A b B`, `method = "radix"`
gives `A B a b`. Two quarantined rows whose supplied instrument ids differ in
case pattern can therefore hash to different rule-2 roots on a C-locale Linux
runner and an English Windows session. I did not construct the cross-platform
witness; the v2 hostile corpus must, and rule 3 must bind byte order for every
R-side sort, including `order(names(normalized))` at line 315. This is the
brief's "unverifiable canonical-encoding rule"; it predates the seed.

### F4 (B). The content-consuming surface list is incomplete

Readers of snapshot rows that the seed's Section 6 table does not name:
result reopen and metrics (`ledgr_estimate_bars_per_year()`,
`R/backtest-results.R:166`), availability marks and corporate-action
composition reports (`R/availability-results.R:405`,
`R/corporate-action-results.R:299`), `ledgr_sweep_save()`
(`R/sweep-persistence.R:506`), `ledgr_snapshot_quarantine()`
(`R/snapshot-quarantine.R:20`), `ledgr_feature_contract_check()`,
`ledgr_indicator_dev()`, `ledgr_pulse_snapshot()`, and `summary()` of a
snapshot. Under "the first operation that consumes snapshot content must
verify fully", reopening a finished run in a fresh process would trigger a
full hash to annualize a metric, contradicting the table's "no snapshot
verification" row for result reopen. The v2 must classify reads:
trust-bearing reads (execution, identity, facts inspection, reconstruction)
require the verified set; reporting reads require only that the stored root
equals the one recorded in the result, as `ledgr_sweep_assert_snapshot_row()`
already does (`R/sweep-persistence.R:389`). The every-call clause for facts
inspection (`contracts.md:597`) must be rewritten with it.

### F5 (B). Sequence the two levers; both are justified, neither alone

Arithmetic on the recorded walk-forward (1,894 s, 26 folds, about 1,430 s of
it rehash): a 5 s exact hash (2.6 s bars plus 2 s facts, rounded up) makes it
about 594 s with 22% still hashing; reuse takes that to under 1%. One run
goes from about 55 s of 110 s to about 5 s of 60 s. The fast hash is the 3x
lever and changes no trust model; the verified set is a further 1.25x on the
registered walk-forward and is the only part that changes trust semantics.
Cut them as two tickets in that order, each with its own gate, which is what
WS5's "separate faster full verification from scoped or reused verification"
already says. The seed's single policy hides that the second ticket can be
rejected without losing the first.

### F6 (B). The cost gates have the wrong shape

"10% of a representative run" and "5% of the registered walk-forward" depend
on the strategy's cost; a cheap strategy makes any exact hash material, and a
fresh process always pays one verification. Replace with: an absolute
per-row cost at one DuckDB thread (the probe gives 0.5 us per bar for the R
binary path), a growth exponent of at most 1.05 across 0.5M to 50M rows,
peak memory bounded by the block size, and "one full verification per
process, none per fold" for walk-forward. Define the intraday witness by row
count and bars per instrument, not cadence. Keep "no calendar components".

### F7 (B). Refusing executable rule-1 and rule-2 snapshots is justified, with two conditions

No `.duckdb` file is shipped under `inst/` or `tests/`; fixtures are CSV and R
builders; one test pins a literal rule-1 hash (`LTB-0018`,
`tests/testthat/test-snapshot-timestamp-branches.R:223`) and must be re-pinned
by decision under the pre-CRAN policy. Identity rule 2 already folds
`snapshot_hash` into `config_hash` and `session_id`, so a rule change forks
every run and session identity exactly as the contracts foresee. The Sharadar
lake in ledgr-research is rebuildable from its adapter; the v2 should record
its rebuild time. Conditions: (1) rule 3 makes the rule marker mandatory;
today a missing marker silently means rule 1
(`R/availability-persistence.R:159`), and the refusal must not inherit that
default; (2) the refusal is one classed condition raised before any content
read, including from inspection.

### F8 (A). Hashing in DuckDB is the migration the parked placement RFC gates

The pipeline row "Persisted-data execution placement and DuckDB boundary"
triggers "before any broad migration of hashing ... into DuckDB". Seed 4.2
performs that migration for the largest hashed table inside WS5. Either the
seed is routed through that RFC first, or rule 3 stays R-computed (F2) and a
DuckDB reproduction is a later optimization against the R oracle. The second
is smaller and is what the evidence supports.

### F9 (C). UX

Keep `verify = FALSE` as the open default with automatic verification on
first trust-bearing use, `verify = TRUE` as the eager form, and no knob (B6
holds). Emit one classed message when an automatic cold verification starts,
naming rows and expected cost, so a 50M-row pause is not mistaken for a hang.
`ledgr_snapshot_info()` reports root, rule and whether this process verified.

### F10 (C). The cheap check can be stronger for free

The seal already stores `n_bars`, `n_instruments` and `fact_family_count`
(`R/snapshots-seal.R:264-285`). Comparing live counts to them costs about
0.1 s at 5.5M rows and detects row insertion and deletion after trust, not
in-place edits; it is not a component hash. A spec-cut option, not a guarantee.

## 5. The revised shape

1. Rule 3: R-defined typed binary encoding, computed in R, byte ordering
   everywhere, fact payload kept as one tagged section, rule marker
   mandatory, old rules refused with one classed rebuild condition.
2. Verified set: process-local, keyed by store key, snapshot id, root and
   rule; populated by seal and by any full verification; consulted by the run
   guard, sweeps, walk-forward, precompute, facts inspection, reconstruction
   and the split-store source check; cleared on mismatch; never serialized.
3. Trust boundary as in the seed. Cross-process writes while the store is
   held are refused by DuckDB's file lock; offline mutation is caught by the
   next process's cold verification; same-process raw DBI stays excluded.
4. Two tickets, fast hash first, then reuse, each with the F6 gates.

## 6. Survives, revise, falsifiers

Survives: one cadence-neutral full root; no components or Merkle in v1; no
calendar boundaries; no public bypass; `verify = FALSE` default with automatic
first-use verification; refusal of old rules; bets B1, B4, B5, B6; the
Section 5.4 threat boundary. Revise: the lease carrier (F1), the encoding
and where it runs (F2, F8), byte ordering (F3), the surface table and read
classes (F4), the ticket split (F5), the gates (F6), the marker default (F7).

What would falsify my direction: an R binary rule-3 root that differs
between ubuntu-latest and windows-latest on the hostile corpus; an R-side
full verification above about 1 us per bar or growing faster than linear at
50M rows; a supported public path that mutates sealed content under an
unchanged root; or a maintainer decision that the parked placement RFC is
the right place for this hash, in which case F2 becomes a sequencing finding.

No spike is needed to decide. The v2's pre-ticket probe (seed Section 10)
adds the hostile corpus on both CI platforms and the F3 quarantine witness.

## 7. Spec-cut details, kept separate from the architecture

- Exact byte layout of rule 3, section tags, the block-combination rule, and
  whether whole-second timestamps are 8-byte doubles or integers.
- The classed conditions: rule refused, cold verification started,
  verification failed, verified set invalidated.
- Whether `ledgr_state_reconstruct()` looks the raw connection up by
  `dbGetInfo(con)$dbname` or always verifies; the F10 count checks.

## 8. Answers to the seed's Section 12

1. Yes, too broad in the wrong way: the lease is narrow by object but leaks
   through serialization and copies; key trust by process and content (F1).
2. Meaningful for status flips, resealing and offline corruption; ceremony
   against raw DBI, which is declared out of scope; F10 widens it cheaply.
3. Typed text smuggles in a formatter contract and a DuckDB dependency (F2).
4. Yes, keep `verify = FALSE` (F9).
5. No; use absolute per-row and growth gates at one thread (F6).
6. Nothing that cannot be rebuilt; two conditions (F7).

## 9. Reviewer bias

I hold session memory of the maintainer's stated preferences (single-core
before parallel, canonical R as oracle, end-to-end speedups) and my
recommendation aligns with them. The probe ran once, on one Windows machine,
on synthetic rows with equal id lengths and no facts; no Linux check was run.

TYPE_2_DISPOSITION: REVISE_SEED
