# Audit: v0.1.8.7 Representation-Site Enumeration + Open-Question Resolutions

**Date:** 2026-05-29 · **Author:** Claude · **Status:** Spec-cut precursor for the
v0.1.8.7 optimization round. Front-loads the four "Open Questions Promoted to
Spec-Cut" from `rfc_optimization_round_v0_1_8_7_synthesis.md` so the spec packet
starts with them resolved. **Does not edit the binding synthesis.**

**Relates to:** the synthesis (Lane R scope + the durable-identity fence), the
empty-fold profile (`dev/spikes/spike-empty-fold-profile.md`), ADR 0004 (R6
removal), `fold_path_hotpath_audit.md`.

## Purpose

Resolve the v0.1.8.7 spec-cut open questions in-cycle, with the de-legacy intent
("get rid of accumulated legacy gunk"):
1. **Representation-site enumeration** (the meaty one — scopes Lane R, separates
   addressable hot-path formatting from durable-identity formatting that is
   fenced).
2. **R6 mutation guard** decision.
3. **Seal reject-vs-truncate** binding.
4. **Buffer sizing** disposition.

---

## 1. Representation-site enumeration (Lane R scope)

Classification of every formatting site reachable on the fold / emission / per-
pulse path. **A — addressable** by Lane R (vectorize/defer/carry-POSIXct, output
not identity-bearing). **F — fenced** (durable identity; Lane R must not change
the bytes). **S — session-local lookup** (not durable identity; changeable in
Workstream A). **B — boundary/one-time** (SQL/query construction, cold).

| site | file:line | role | class |
| --- | --- | --- | --- |
| per-pulse ctx ts normalize | `R/pulse-context.R:13` → `:619-625` | every ctx build formats `ts_utc` via `format(...,"%...%SZ")` | **A** |
| per-fill payload ts round-trip | `R/backtest-runner.R:176-177` | normalize + reparse `ts_exec_utc` per fill | **A** |
| per-fill `meta_json` | `R/backtest-runner.R:188` | per-row `canonical_json` | **A (timing only)** — defer to flush, but stays **per-row canonical**, never batched |
| event-id construction | `R/backtest-runner.R:190`, `R/fold-core.R:389` | `paste0(run_id,"_",sprintf("%08d",seq))` per event | **A (build only)** — output string **bound byte-identical** |
| all-pulses ISO | `R/backtest-runner.R:950` | `format(pulses_posix, ...)` once per run | **A (one-time)** |
| feature hydration / cache read | `R/backtest-runner.R:1697,1783` | `format(x$ts_utc, ...)` on read-back | **A (read-back, not run-wall hot)** |
| **data-subset hash** | `R/data-hash.R:137` | `formatC(round(x,d),format="f",digits=d)` over numerics | **F** — feeds `ledgr_run_data_subset_hash` |
| canonical JSON POSIXt | `R/config-canonical-json.R:61-63` | timestamp formatting into canonical JSON | **F** — config/provenance hashes |
| snapshot hash ts | `R/snapshots-hash.R:26-29,66-69` | timestamp fields into snapshot hash | **F** |
| feature cache key | `R/feature-cache.R:101-119` | normalize start/end + hash | **S** — session-local lookup; changeable in Workstream A |
| SQL id/quote lists | `R/backtest-runner.R` many (`DBI::dbQuoteString` + `paste`) | query construction | **B** |

### Key finding — the addressable slice is smaller than the headline 62%

The empty-fold profile's formatting (`format.POSIXlt` 26.6% + `formatC` 14.7% +
`sprintf`/`paste`) is **not all Lane-R-addressable**:

- **`formatC` 14.7% is entirely the data-subset hash** (`R/data-hash.R:137`, the
  only `formatC` in `R/`). It is a per-run **identity** setup (formats all touched
  numerics into the run's data-subset hash). **Fenced.**
- A share of **`format.POSIXlt` 26.6%** is also identity: `canonical_json` and the
  snapshot hash format timestamps. **Fenced.**
- The genuinely **addressable** `format.POSIXlt` is the per-pulse
  `ledgr_normalize_ts_utc` (`pulse-context.R:13`), the per-fill payload round-trip,
  the one-time `pulses_iso`, and the event-id *build* (output bytes preserved).

**Consequence for the RFC:** the synthesis's "Lane R low-turnover effect likely
large" should be read with a **fenced remainder** — a meaningful chunk of the
low-turnover formatting (the data-subset-hash `formatC` + identity POSIXt formats)
is *not* Lane-R scope. Lane R's realistic low-turnover win is **moderate**, not
the full 62%. (Confirm exact split via the post-B0 re-profile.)

### Update (2026-05-29) — the data-subset-hash `formatC` is legacy redundancy, not just fenced

Re-examined: the 14.7% `formatC` is **not** merely a fenced identity formatter
needing a byte-identical faster path. The whole run-time value-hash is **legacy
redundancy** for sealed-snapshot runs and should be removed:

- `ledgr_run_data_subset_hash` (`R/data-hash.R:58`) is computed per run
  (`R/backtest-runner.R:898`) and compared on resume (`R/backtest-runner.R:905-907`).
  Its purpose is **resume/replay drift detection** — "did the run's data change?"
- A **sealed snapshot is immutable and already carries `snapshot_hash`**, so the
  data cannot drift. Resume identity for a sealed-snapshot run is fully determined
  by `(snapshot_hash, instrument_ids, start_ts, end_ts)` plus the existing
  inclusive selector semantics (`ts_utc >= start_ts`, `ts_utc <= end_ts`);
  re-hashing values re-derives a guarantee the seal already provides
  (`snapshot_hash` covers the whole snapshot, hence any subset).
- It is **v0.1.0-era machinery** from the mutable raw-`bars` table (`ledgr_data_hash`
  doc: "Legacy v0.1.0 workflows require rows in the raw bars table"). The
  `data-hash.R:59-61` comment concedes the run hash and adapter hash are "the same
  implementation today," kept separate only to evolve independently.

**Decision (maintainer, 2026-05-29): remove it** — derive sealed-run resume
identity from `snapshot_hash + selector`, eliminating the per-run value-hash (and
its `formatC`) outright. This is a **resume/provenance contract change** (free
pre-CRAN) and a legacy-cleanup item that fits v0.1.8.7 — **not** Lane R, and not a
"faster formatter." Codex verification in
`v0_1_8_7_data_subset_hash_review_request_response.md` accepted this direction
for sealed snapshot-backed runs once the raw-`bars` legacy path is retired.

### Spec-cut guidance for Lane R

- Lane R touches only the **A** rows. Every **F** row is off-limits without an
  explicit identity-contract change.
- The **S** feature-cache row is session-local and changeable in Workstream A;
  it is not durable identity and should not block the composite-key cleanup.
- The data-subset hash row is legacy-cleanup scope, not Lane R.
- The event-id build may change; its **output string must stay byte-identical**.
- `meta_json` deferral must remain **per-row canonical**.
- The hot `%||%` (~10% of the empty fold; pervasive on the per-pulse path) is a
  separate micro-target — enumerate its hottest call sites during B0/R profiling.

---

## 2. R6 mutation guard → DROP (rely on stateless contract + static preflight)

**Current state.** `LedgrStrategy` (`R/strategy-contracts.R:98`) carries a
**runtime** mutation guard (`R/strategy-contracts.R:126`, class
`ledgr_strategy_mutation_detected`: "Strategy mutated internal state during
on_pulse()"). Function strategies currently inherit it
(`R/strategy-fn.R:35`, `R/backtest-runner.R:1997`). Separately, a **static
preflight** (`R/strategy-preflight.R`) analyzes the strategy AST for
`unsupported_context_mutations`, `rng_mutation_symbols`, and captured mutable
external objects.

**Decision: drop the R6 runtime mutation guard.** Rationale:
- ADR 0004 removes R6. Function strategies are **stateless by contract**
  (`(ctx, params) -> targets`; persistent state only via `state_update`), so there
  is **no internal R6 state to mutate** — the runtime guard's premise disappears.
- Context / captured-object mutation is already covered, **uniformly and
  function-based**, by the static preflight. Dropping the R6 guard therefore also
  removes the **replay-vs-direct inconsistency** Codex flagged (the runtime guard
  fired on one path only).
- No need to "port a uniform runtime check": the stateless contract + static
  preflight are the uniform guarantee.

**Confirm during implementation:** that the static preflight runs on **both** the
original and replay setup paths (so the uniformity claim holds), and migrate the
contract/provenance tests off `BadMutatingStrategy`/`LedgrStrategy`
(`R/strategy-contracts.R:212`) to function-based equivalents.

---

## 3. Seal sub-second handling → REJECT (bound)

Per the resolved whole-second / not-HFT contract: the snapshot seal **rejects**
sub-second timestamp input with a clear error, rather than silently truncating.
Reject is preferred — ledgr should not silently accept data it will not
faithfully represent. (Both reject and truncate honor the bound whole-second
contract; this binds the preferred one.)

---

## 4. Buffer sizing → stays an open question; defaults now, tune on the B0 re-profile

Not pinned in the RFC. The **B0 ticket** binds sensible defaults — initial
capacity ~1024, 2× growth, cap at the worst-case `n_inst*n_pulses` ceiling — and
carries "**tune initial capacity against the B0 real-run re-profile** (minimize
reallocations without reintroducing over-allocation)" as an acceptance step. The
re-profile gate B0 already requires is where the optimum is locked. No separate
RFC/spike; value-neutral, surface-preserving, in-cycle.

---

## Net dispositions for the spec packet

| open question | disposition |
| --- | --- |
| Representation-site enumeration | **Done** (table above); Lane R = the **A** rows only; fenced remainder → identity-format future obligation |
| R6 mutation guard | **Drop** the R6 runtime guard; rely on stateless contract + static preflight; confirm preflight path-uniformity |
| Seal reject-vs-truncate | **Reject** sub-second at seal |
| Buffer sizing | **Open by design**: defaults bound in B0, tuned on the B0 re-profile |

These feed the v0.1.8.7 spec packet directly; the binding synthesis is unchanged.
