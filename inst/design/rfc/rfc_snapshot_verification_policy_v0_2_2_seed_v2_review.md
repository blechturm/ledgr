# Seed v2 Review: Snapshot Verification Policy for v0.2.2

- Role: Type 2 adversarial reviewer of seed v2 (pre-spike architecture review)
- Author: Claude (Fable 5.1), author of the stage-3 response
- Date: 2026-10-12
- Source baseline: `ba754286` (head); the cited hash, seal, locator, guard,
  adapter, inspection and derived-state paths are unchanged since `1c8df889`
  except one comment in `R/derived-state.R`
- Brief: maintainer-supplied; this review is provisional until the maintainer
  rereads brief and review together

## 1. Overall disposition

Seed v2 is architecturally coherent and keeps the smallest shape that gives
the required guarantee: one complete root per snapshot, one proof per
process, no components, no knob. It is not yet exact enough to hand a spike
author one empirical question. Five wording defects let two conforming
implementers produce different roots or let the spike kill a sound design,
and all five are patchable in place. No maintainer product decision is
required. Disposition: revise in place, then spike.

## 2. What was independently checked

Source walked at head: `R/snapshots-hash.R`, `R/snapshots-seal.R`,
`R/snapshot.R` (locator, held stores, store key), `R/run-snapshot.R`,
`R/backtest.R`, `R/backtest-config.R`, `R/backtest-runner.R`,
`R/run-prepare.R`, `R/snapshot-source.R` (split store), `R/sweep.R`,
`R/sweep-persistence.R`, `R/walk-forward*.R`, `R/precompute-features.R`,
`R/experiment.R`, `R/availability-persistence.R`, `R/availability-facts.R`
(fact projection), `R/config-canonical-json.R`, `R/availability-inspection.R`,
`R/snapshot-quarantine.R`, `R/backtest-results.R`,
`R/corporate-action-results.R`, `R/availability-results.R`,
`R/derived-state.R`, `R/public-api.R`, `R/db-schema-create.R` (migrations),
`R/pulse-snapshot.R`, `R/indicator-dev.R`, `R/parallel-workers.R`.

Two scratch probes ran, each under one minute, no package code changed, no
private data read:

- Probe A, 500,000 synthetic bars in 10,000-row blocks: a column-major block
  encoder took 0.14 s (0.28 us/row); a naive row-major record-framed encoder
  (`split()`/`mapply()`) took 2.11 s (4.22 us/row). Also: `digest(raw = TRUE)`
  returns 32 raw bytes; `round(x, 8)` is idempotent on one million values;
  `round(-1e-10, 8)` is negative zero and `+ 0` folds it; `NA_real_` and
  `NaN` are distinguishable; duckdb `dbGetInfo(con)$dbname` is the store
  path; DuckDB default `ORDER BY` on VARCHAR equals R radix order (`A B a b
  z e-acute`) while R's default collation does not (`"x" > "X"` is FALSE in
  R, TRUE in DuckDB).
- Probe B, same rows: a fully vectorized row-major encoder of the Section
  5.3 layout (offset arithmetic, no per-row calls) took 0.48 s (0.96
  us/row) against 0.16 s (0.32 us/row) column-major, a 3.0x ratio.

## 3. Findings, ordered by severity

### F1. The cost gate was measured on a layout Section 5.3 does not specify

- Claim: "base payload no more than 1 microsecond per bar" is evidence-backed
  (Section 10, citing the review's 0.5 to 0.6 us probe and the response's
  2.6 s at 5.5M rows).
- Evidence: both measured encoders were column-major blocks. Section 5.3
  specifies row-major records, each framed by its own byte length with a
  presence byte per field. Probe B measures that layout at 0.96 us/row on
  this machine; Probe A's naive form at 4.2 us/row.
- Failure: the spike implements Section 5 faithfully, measures 1.1 us on the
  maintainer's machine, and reports a red result against a sound design; or
  it switches to column-major to pass, which Section 5 forbids ("the spike
  may not silently choose different bytes").
- Severity: blocks the spike as written; patchable in place.
- Smallest correction: respecify 5.3 as column-major blocks. For each field
  in declared order: `N` presence bytes, then the payload vector (`8N` bytes
  for timestamps and numbers; for text, `N` uint64 byte lengths followed by
  the concatenated bytes). Block, section and root framing are unchanged.
  Alternative: keep row-major and set the gate from a measurement of that
  layout; it then has no margin.

### F2. The fact section is bound by prose that contradicts the code it retains

- Claim: Section 5.4 retains rule 2's projection, adds "columns use the
  declared schema order, never discovery order", "written once through
  ledgr canonical JSON v2", and "every table uses its declared identity-key
  order".
- Evidence: `ledgr_fact_canonical_frame()` orders columns by name with
  default `order()` (`R/availability-facts.R:1108`), not schema order; each
  table is written to JSON separately and embedded verbatim, then the outer
  object is written again (`R/availability-persistence.R:312-322`); the
  quarantine identity key is the five-field list at `:299-301`, declared
  nowhere the seed cites, while `ledgr_snapshot_availability_tables()`
  declares `quarantine_id`, which the projection drops.
- Failure: implementer A keeps the existing alphabetical columns and nested
  writes; implementer B uses DDL column order and one flat write. Different
  bytes, different roots, both conforming.
- Severity: design-level ambiguity; patchable in place.
- Smallest correction: bind the fact record by reference: "the string
  `ledgr_snapshot_availability_hash_payload()` produces at baseline
  `ba754286`, with exactly three changes: schema label
  `ledgr_snapshot_hash_rule_3`; every R-side `order()` in that path uses
  `method = "radix"` (quarantine rows, table names, column names); the
  quarantine identity key is `supplied_instrument_id, supplied_ts_utc,
  reason, original_row_json, provenance_json` in that order." Delete the
  "declared schema order" and "written once" sentences.

### F3. "Every nullable field starts with one byte" has two readings

- Claim: Section 5.1 defines the presence byte for nullable fields.
- Evidence: `instrument_id`, `ts_utc`, `open`, `high`, `low`, `close` are
  `NOT NULL` (`R/db-schema-create.R:287-298`); the fact record is never
  missing.
- Failure: one implementer tags only nullable columns, another tags every
  field. Different bytes.
- Severity: ambiguity; patchable in one sentence.
- Smallest correction: "Every field, nullable or not, starts with the
  presence byte."

### F4. Bytewise order is asserted by prose but produced by DuckDB

- Claim: Section 5.2, "no session locale participates"; Section 9, R
  "continues to define and compute the identity bytes".
- Evidence: the encoder will stream `ORDER BY instrument_id, ts_utc`
  (`R/snapshots-hash.R:176-182`). DuckDB's default collation is bytewise
  today (Probe A), but nothing in R checks it, and R's default comparison
  differs.
- Failure: a DuckDB build or session with a non-binary default collation
  reorders mixed-case ids; the R encoder hashes them in that order; the root
  moves with no R-side signal, and DuckDB collation has silently become part
  of the identity contract.
- Severity: ownership defect; patchable in place.
- Smallest correction: add to 5.2: "the R encoder asserts, per block and
  across block boundaries, that keys arrive in strictly increasing bytewise
  order (`method = "radix"` comparison) and refuses otherwise; it never
  re-sorts." This costs one comparison per row and no materialization.

### F5. The threat boundary cites a lock that is not held

- Claim: Section 6, "cross-process writes while a store is held are subject
  to DuckDB locking".
- Evidence: `ledgr_snapshot_hold()` opens the connection for one public call
  and the closer releases it (`R/snapshot.R:159-172`); the file is unlocked
  between calls while the proof lives for the process.
- Failure: a user reads the sentence as cross-process protection, edits rows
  from a second process between two `ledgr_run()` calls while preserving the
  `snapshots` row, and the first process reuses the proof.
- Severity: boundary visibility; patchable in place. Not a supported
  workflow, so not a rejection.
- Smallest correction: replace the sentence with "After proof, only the
  stored status, root and rule are rechecked. Any row mutation by any
  process that preserves them is undetected until explicit validation or a
  new process." Name `ledgr_snapshot_validate()` and `verify = TRUE` as the
  remedies.

### F6. The store key is underspecified for split stores and in-memory stores

- Claim: Section 6, "canonical store key uses the same normalized store
  identity as ledgr's held-store machinery".
- Evidence: in split mode the guard's connection is the run store and the
  snapshot is attached read-only from `cfg$data$snapshot_db_path`
  (`R/snapshot-source.R:23-51`, `R/run-prepare.R:68-69`);
  `ledgr_store_key(":memory:")` is `NULL` (`R/snapshot.R:98-104`).
- Failure: an implementer keys by the run store; two run stores over one
  snapshot verify twice, or a run store reused across two snapshot files
  with equal ids and roots reuses proof across files.
- Severity: patchable in place.
- Smallest correction: "the key is the snapshot store's key
  (`snapshot_db_path`), never the run store's; a store without a key
  (`:memory:`) is never entered and always verifies."

### F7. Section 10 asks the spike for evidence it cannot produce

- Claim: end-to-end seal, run, sweep and 26-fold walk-forward clocks under
  rule 3 are supporting evidence, while "the spike changes no product code".
- Evidence: those clocks require the encoder wired into `ledgr_snapshot_seal()`
  and `ledgr_run_snapshot_guard()`. The golden corpus also lists about
  fifteen dimensions before any runnable core; `spike_protocol.md` Sections 3
  and 8 cap the initial set at ten and return a charter that exceeds it. The
  kill condition "whole-snapshot R materialization" is met on day one by
  the seed's own fact design, which materializes every fact table and one
  JSON string.
- Failure: the charter is returned unread, or the spike kills itself on the
  fact record.
- Severity: spike-readiness; patchable in place.
- Smallest correction: move the end-to-end clocks to ticket 1's acceptance
  evidence (Section 9); label the corpus a menu from which the charter picks
  at most ten cases after the first run; restate the kill condition as
  "materializing bars or instruments beyond one logical block, or needing a
  second canonicalization engine"; the fact projection is governed by B4.

### F8. The read census cites a dead function and omits the usual cold point

- Claim: Section 7 lists availability marks and corporate-action reporting;
  the response and its review cited `ledgr_estimate_bars_per_year()` as a
  live result read.
- Evidence: that function has no caller (`R/backtest-results.R:136`, defined
  only); result metrics take `bars_per_year` from the metric kernel
  (`:267`). The live class-3 result reads are `summary()` and `print()` of a
  backtest through `ledgr_corporate_action_summary()`
  (`R/backtest-results.R:723`, `:891`, reading fact rows at
  `R/corporate-action-results.R:401`) and availability marks
  (`R/availability-results.R:435`). `ledgr_experiment()` reads instruments
  and fact headers (`R/experiment.R:371-375`) and is therefore class 3: it is
  where the cold verification lands in the ordinary workflow, before any run.
  `ledgr_backtest()` calls `ledgr_snapshot_validate()`
  (`R/backtest.R:153`), which Section 6 makes always-recompute; ticket 2
  must reclassify it as an ensure or the legacy path keeps a full rehash.
- Failure: a ticket-cut census built from the artifacts carries a dead entry
  and misses the first pause users will meet.
- Severity: patchable in place.
- Smallest correction: strike the dead citation; add "experiment
  construction (universe and fact headers)" to the class-3 list; say that
  the first class-3 call in a process, usually `ledgr_experiment()`, pays the
  cold verification; add the backtest validate reclassification to ticket 2.

### F9. Minor exact-byte notes (no root ambiguity, implementer guidance)

`writeBin()` refuses 8-byte integers in R, so int64 must be written as two
32-bit words or from a double that passed an integrality check; the seed may
say "written as two little-endian 32-bit halves of the two's-complement
value". The root's `uint32_le(3)` is the only 32-bit integer; say so. An
absent fact table and an empty one both project to `[]` today
(`R/availability-persistence.R:195`, `R/availability-facts.R:1135-1136`),
which is what "every declared table empty" needs; state the equivalence.
Fact-field doubles stay as yyjsonr shortest round-trip text (`digits = -1L`,
`R/config-canonical-json.R:21-35`), a C-library-independent formatter; the
fact section therefore keeps a text identity, which Section 5.4 should admit.

## 4. Exact-byte audit

| Item | Verdict |
| --- | --- |
| Little-endian, raw 32-byte digests, uint64 counts | Exact |
| Presence byte scope | Ambiguous (F3) |
| NaN and infinities refuse; missing uses the tag | Exact; `is.nan()` versus `is.na()` distinguishes them (Probe A) |
| Signed int64 seconds | Exact as a value; R writing needs F9's note |
| `round(x, 8)` then fold negative zero | Exact and idempotent (Probe A) |
| UTF-8 via `enc2utf8()`, no normalization | Exact |
| Bytewise ordering | Exact as stated, unowned (F4) |
| Tied row identities | Cannot occur for bars and instruments (primary keys); facts by F2's key |
| Record, block, section, root framing | Exact once F3 is fixed; redundancy of `N` and `length(B)` is harmless |
| Empty sections and empty fact projection | Exact after F9's equivalence sentence |
| Fetch-chunk and thread invariance | Exact: chunks feed fixed logical blocks; DuckDB threads never touch bytes |
| SHA-256 over raw bytes | Exact: `digest(serialize = FALSE, raw = TRUE)` verified |
| Fact section fixed by rule 2 plus canonical JSON | Not fixed by prose (F2); fixed once bound by reference |

## 5. Verified-set and usage-path audit

- Store key: `normalizePath(winslash = "/")`. Case variants, relative paths
  and junctions can yield two keys for one file; the miss direction is a
  spare verification, never stale reuse. `:memory:` has no key (F6).
- Process generation: a fresh process has an empty namespace; a fork keeps it
  but fails the PID compare and clears. The nonce adds nothing a PID compare
  does not; keep it only if it names the generation in diagnostics.
- Copied and serialized locators: nothing to carry; sweep worker payloads
  omit the snapshot (`R/sweep.R:1096`, `:1194`).
- Seal registration: the seal computes the root inside its transaction and
  commits (`R/snapshots-seal.R:160-185`); register after the `COMMIT`
  statement returns. A raw connection yields its key through
  `dbGetInfo(con)$dbname` (Probe A).
- Failed verification removes the entry and fails closed; close and reopen
  do not clear; a second locator reuses. Coherent.
- Supported mutation of sealed rows: none found. Sealing requires `CREATED`
  (`R/snapshots-seal.R:107`); schema migrations only add columns to
  `snapshot_*` tables and recreate `runs`, `bars` and `ledger_events`
  (`R/db-schema-create.R:339`, `:379`, `:438`, `:465-487`). Rebuilding a
  snapshot at the same path and id changes the stored root unless content is
  identical, so the key misses exactly when it should.
- Locking: see F5.
- Read classes checked: run, resume, promotion and walk-forward test runs
  reach the guard (class 3, once per outer call under the set); sweep
  evaluation reads bars once per sweep (`R/sweep.R:224`); precompute and
  window validation read bars (class 3); `ledgr_sweep_save()` compares the
  stored root only (`R/sweep-persistence.R:389`, class 2 as the seed says);
  `ledgr_sweep_open()` reads the universe (`:98`, class 3 as the seed says);
  `ledgr_walk_forward_open()`, `ledgr_candidate()` and `ledgr_run_open()`
  read run-store rows and the stored root (class 2); fact and quarantine
  inspection, interactive tools, `ledgr_feature_contract_check()` and
  `ledgr_state_reconstruct()` read rows (class 3); `ledgr_snapshot_info()`
  and `ledgr_snapshot_list()` read counts (class 1). Corrections: F8.
- A stored-root comparison never stands in for proof on a row read; the seed
  holds that line and this review found no exemption that breaks it.

## 6. Spike-readiness judgment

With F1, F2, F3, F4, F6 and F7 patched, the spike has one question and the
prerequisite (an executable R encoder of Section 5) is concrete. Portability
is testable from a scratch script on Windows and the WSL Ubuntu gate the
Verification Contract already names, with no product change. The growth gate
of 1.10 is backed by the review's 1.06 measurement over 0.5M to 5M rows. The
1 us gate is backed only for column-major blocks (F1). Encoder memory and
whole-process RSS are correctly separated; the fact JSON record does make the
memory question different, because every fact table and one string are held
at once, so the spike must report that peak at the largest fact-bearing shape
(the Cut 3 spike measured 300,000 membership rows for cost, not memory). The
end-to-end clocks are excessive for a no-product-change spike (F7).

## 7. Strongest simpler alternative and where it fails

The existing held-store registry (`.ledgr_held_stores`, one entry per store
for the duration of one public call) could carry the proof: verify once when
the hold opens, reuse it for every nested open until the closer runs. That
removes the process generation, PID compare and nonce, and makes the lock
statement true for the whole trust window, because the connection is open
throughout. It covers the measured problem exactly: a 26-fold walk-forward
and a sweep are each one public call under one hold.

It fails on cross-call reuse. `ledgr_run()` holds nothing today
(`R/backtest.R:402-520`), and every later public call, including `summary()`
of a result on a Sharadar-scale snapshot, would pay about 5 s. That is the
single reason the process-lifetime set is not overbuilt: the strongest
reason it is overbuilt is that its extra machinery exists only to save
those ~5 s per later public call in one session. If the maintainer prefers
to make the class-3 result readers durable and give `ledgr_run()` a hold,
the hold-scoped proof suffices and Section 6 shrinks by half. This is a
maintainer option, not a blocker.

Most damaging omitted supported-workflow scenario: no supported path reuses
stale proof; every one found changes the stored root or is refused. The
omission that will bite is cost placement. The cold verification lands in
`ledgr_experiment()`, not in `ledgr_run()`; every forked child and every
fresh worker process pays it again; and `ledgr_backtest()` keeps a full
rehash through its explicit validate unless ticket 2 reclassifies it (F8).

## 8. Required seed patches

1. Section 5.3: column-major block layout (F1), or a gate measured on the
   row-major layout.
2. Section 5.4: bind the fact record by reference with the three named
   changes and the quarantine key; delete the two contradicting sentences
   (F2); admit the text identity of fact doubles (F9).
3. Section 5.1: presence byte on every field (F3); int64 writing note and the
   empty-equals-absent sentence (F9).
4. Section 5.2: R-side bytewise order assertion (F4).
5. Section 6: boundary sentence (F5); snapshot-store key and `:memory:`
   rule (F6).
6. Section 7: census corrections and the cold-point sentence (F8).
7. Section 10: clocks to ticket 1, corpus as a menu, kill condition carve-out
   (F7).

All seven fit in place with a revision note; none reopens the architecture.

## 9. Bets upheld or falsified

| Bet | Status |
| --- | --- |
| B1 portable bytes | Upheld in direction; untested until the corpus runs on both platforms |
| B2 one fast root is enough | Upheld; gate evidence applies to the column-major layout only (F1) |
| B3 verified set safe for supported use | Upheld; no supported stale-reuse path found; boundary wording corrected (F5) |
| B4 one fact JSON record affordable | Open; cost measured, memory not |
| B5 no components | Upheld; the block list is flat, nothing is stored |
| B6 old snapshots rebuildable | Upheld for the package; the Sharadar rebuild time is still unrecorded |
| B7 no knob | Upheld |

What would reverse this review: a vectorized row-major R encoder at or below
0.5 us/bar on the maintainer's machine (F1 becomes a nit); a supported API
that mutates sealed rows under an unchanged root (the set is unsafe); a
measured fact-projection peak at the registered shape that breaches the
memory gate (B4 falls and the fact encoding returns to design); or a
maintainer decision to make result readers durable and hold in `ledgr_run()`
(the hold-scoped proof wins and Section 6 is overbuilt).

## 10. Recommended next RFC stage

Patch seed v2 in place with a revision note (seven items, Section 8), then
charter the Section 10 conformance spike under `spike_protocol.md` with the
column-major candidate. No maintainer decision stage is needed; the Section 7
option can be raised at synthesis.

TYPE_2_DISPOSITION: REVISE_SEED
