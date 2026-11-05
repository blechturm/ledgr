# WS25 public candidate closeout: restart and compact diagnostics

Source boundary: Cut 11, LDG-3206 through LDG-3209. LDG-3206 through
LDG-3208 are complete on the public candidate. LDG-3209 remains open for the
maintainer-run private rebuild, the rule-16 milestone clocks and the H1 memory
gate. This is therefore a candidate record, not Workstream 25 acceptance.

## Fresh-attempt boundary (LDG-3206)

`strategy_state` is no longer a durable table. Declared asset and portfolio
state remain typed fold-local values and still reset at each walk-forward test
run. There is no pulse cursor, state codec, restore reader,
`ledgr_run_resume()` or `ledgr.interrupt` soft stop.

A call for a nonterminal run first passes the ordinary identity, snapshot and
terminal-evidence checks. In one transaction the restart boundary then removes
the prior attempt's derived rows, publishes zero diagnostic coverage and the
empty-trace summary, posts opening positions once and starts the fold from
pulse one. DONE and INCOMPLETE rows keep their terminal early return, while
completion-publication recovery remains strategy-free. A real R interrupt
still rolls back the fold transaction and records FAILED. The durable opening
tail seeds the first fold boundary after each fresh attempt.

`checkpoint_every` remains part of configuration and controls event-buffer
flushing. It makes no pulse-durability promise.

The deletion and teaching census is LTB-0555/LCL-0544. Behavioral witnesses
include LTB-0198, LTB-0202, LTB-0207, LTB-0245 and LTB-0534. The opening-tail
mutation is also detected. Exact configuration-hash witnesses show that the
removed ambient surfaces do not alter the retained public configuration.

## Logical diagnostic boundary (LDG-3207)

`ledgr_diagnostic_decode()` is the sole logical trace reader. It supports run,
stage, outcome, reason, instrument and bounded-time filters in SQL before
materialization. Result diagnostics, explanations, valuation and
corporate-action summaries, completion validation, assumption flags, sizing
summaries, diagnostic-presence queries and next-sequence queries use the
decoder or its persisted exact summary/coverage rows. Store-wide listing and
summary surfaces do not repeatedly decode or validate the complete trace.
Detail and logical-trace reads still validate exact coverage and association.

Every run publishes zero coverage and an empty summary at registration and at
fresh restart. A process killed while CREATED or RUNNING therefore remains
listable and reports empty evidence rather than poisoning the store. Corruption
errors name the run where relevant.

LTB-0557 constructs both rows only through the production registration and
restart boundaries. Process-local omission mutations were run separately for
the registration initializer and the restart initializer; each makes the
block fail when `ledgr_run_list()`/`ledgr_run_info()` reaches the orphan.

The fills reader no longer reads diagnostics. It associates typed fill times
with the unique declared session axis through one vectorized match; ambiguous
or missing session anchors yield typed missing recording pulses. No logical
read invokes strategy, indicator, risk or cost code, and no read writes the
store. Split-store readers attach the snapshot on the connection used by the
decoder, including closed-handle summary and terminal-evidence paths.

LTB-0554/LCL-0543 owns the complete and bounded decoder, empty nonterminal
evidence, the no-callback witness, the store-wide no-decode counters and the
literal production-source census. LTB-0210 owns fill/session semantics;
LTB-0559/LCL-0546 independently owns the vectorized `match()` shape and its
missing and ambiguous-session behavior.

## Exact compact codec (LDG-3208)

Only exact current-close clean decision/fill pairs become implicit evidence.
Certification occurs after P2 and before general row/data-frame/JSON
expansion. Risk, stale, restriction, rejection, sizing, scheduled skip, stop,
error and missing-comparison rows stay explicit. Memory sinks allocate no
durable implicit buffer.

The physical representation consists of explicit residual diagnostics,
certified implicit rows, exact coverage and a persisted hashed summary. The
decoder reconstructs one logical trace with the same types, missing values and
sequence positions as the all-explicit oracle. Coverage refuses missing,
duplicated and permuted in-pulse decision or execution positions before any
logical result is returned. Writer counters pin certification before row and
JSON expansion; the P2 next-bar witness pins the no-lookahead boundary; exact
documentation searches reject a restored one-physical-row-per-axis claim.

Each compact decision-order token pairs its context ordinal with its run-axis
ordinal in one exact BIGINT. The independent DuckDB validator anchors the axis
half to the stored run universe and the context half to fixed-axis identity or
the sealed membership facts. Integer arithmetic, joins and one `LAG` window
remain inside DuckDB; the R boundary receives at most one offending run. It
therefore accepts availability contexts whose order differs from the run axis
while detecting a coordinated rewrite of the token and diagnostic sequence.
Instrument and timestamp reads restrict the checked pulse set before the
window, and no implicit row or per-row string key is materialized in R.

LTB-0554, LTB-0556, LTB-0558 and LTB-0560 (LCL-0543/LCL-0545) own logical
parity, physical omission, typed certification, lazy allocation, writer order
and the corruption matrix. LTB-0558 mutates the fixed-context and run-axis
halves independently; LTB-0560 owns the dynamically reordered membership
context. The codec is store-format authority only: schema stays 125, the new
codec-rule binding changes the store fingerprint, and run/snapshot identity
rules do not change. An otherwise current schema-125 store carrying the
WS24-close fingerprint refuses with `fingerprint_mismatch`.

## Retired and migrated tests

The accepted product change removes continuation, so tests were changed only
where their old observation seam or contract disappeared:

- the ambient-RNG resume-only preflight test was retired with its helper;
- LTB-0490/LTB-0493 moved durable `strategy_state` and continuation evidence
  to logical diagnostics and fresh restart;
- LTB-0532/LTB-0533/LTB-0536 observe typed state inside the callback;
  LTB-0534 owns restart/default state instead of a cursor;
- availability-economics interruption and finalization-prefix witnesses use a
  real interrupt rollback followed by a fresh attempt;
- strict and TTR witnesses compare the expected failed partial attempt with a
  fresh complete attempt;
- table-list assertions replace `strategy_state` with the three codec tables;
- the WS4a mutation accepts `ledgr_diagnostic_corrupt`, the exact current
  decoder refusal, as detection;
- the frozen availability provenance witness moves from tier 1 to tier 2
  because its real-interrupt helper captures a function; its economic oracle
  is unchanged;
- position-fact and pulse-seed continuation witnesses now test fresh restart;
- strategy-context projection/surface tests observe the live P2 state rather
  than undefined persistent-state readers;
- terminal-outcome helpers read logical diagnostics, never the physical
  residual table.
- LTB-0138 no longer forces the dead non-preserving diagnostic writer branch;
  it stages a diagnostic block inside a rolled-back pulse transaction, then
  pins the production-reachable exception row whose sequence is re-read once
  from the committed store. Replacing the refresh with `FALSE` fails because
  it reuses the rolled-back handler counter;
- LTB-0190's grouped-reader count first moved from three to seven because
  current listing reads persisted summary/coverage plus the logical decoder
  and one grouped equity projection, then to nine when the correction anchored
  compact decision order to the independently stored run universe; the count
  remains constant in the number of requested runs;
- LTB-0281 adds `diagnostic_decision` and `diagnostic_risk` because P2 now
  hands both typed diagnostic segments to P3 for pre-expansion certification;
- the ambient-RNG restart witness reopens fresh handles after destructive
  restart and normalizes only `run_id`, `event_id` and data-frame row names,
  the unavoidable new-attempt identities; every economic and state-derived
  ledger/equity value remains exact.
- the typed-accounting source census drops the three dead
  `backtest-runner.R` diagnostic-table references with the post-interrupt
  repair branch; the decoder's independent order check replaces, rather than
  adds to, its prior implicit-table query count; deleting the two orphaned
  corporate-action readers removes their shared ledger-table row, so the exact
  census moves from 90 to 86 populated seams.
- the two corporate-action readers that existed only to seed a continued
  fold are deleted after their last production call disappears; LTB-0555's
  exact-name census makes restoring either orphan fail.

## Public verification on the correction candidate

- source profiles exercise every registered block: fast is 633/633; review
  reaches 532 blocks with only the three established Windows C-locale
  encoding failures, each of whose complete files passes under the supported
  UTF-8 locale; heavy reaches its end with only the five established native-
  encoding assertions in `test-sweep-retention.R`, whose complete file also
  passes under the supported locale;
- focused decoder, restart, writer, session-association, split-store and
  control-plane suites: pass, including registered mutations;
- A0: 300 canonical files (634,264 bytes), byte-identical on re-record;
  204 agreement checks and two declared differences pass, and every registered
  corruption fails with its named surface;
- typed-accounting checker: 86 seams, 30 accounting fields and 22 diagnostic
  fields, pass; its private gate remains open;
- codebase census checker: 2,007 helpers, 2,486 conditions and 89 findings,
  pass;
- `R CMD build --no-build-vignettes` succeeds; supported-locale
  `R CMD check --no-manual --no-build-vignettes` passes installation,
  examples, installed-package tests and all executable vignette code with the
  two established missing-`inst/doc` warnings.

The focused decision-order shape probe under
`dev/bench/v0_2_3_diagnostic_order_validation/` validates 630,000 implicit
rows entirely in DuckDB. A clean full check returns zero rows (840 bytes) to R
in 0.36 seconds; the one-instrument, one-pulse check returns the same bounded
result in 0.11 seconds. These clocks are descriptive. LTB-0558 owns the
failure-sensitive SQL/no-materialization shape plus independent fixed-context
and run-axis corruption; LTB-0560 owns the dynamic-membership context anchor.

The first R CMD check exposed one metadata error in the newly registered
session-association shape detector: LTB-0559 promised the `review` profile but
lacked its immediately adjacent block-profile marker. The marker was added,
the static claim checker passed and a fresh source tarball completed R CMD
check with status OK.

Final confirmation correction `4fc1dedd` moves the compact decision-order
check wholly into one grouped DuckDB query, independently anchors dynamic
context order to sealed membership facts, strengthens the rolled-back
diagnostic-sequence detector and removes the final stale continuation
comments. The final public A0 run remains byte-identical (204 checks and two
declared differences), all registered A0 corruptions fail at their named
surface, and the typed-accounting and codebase censuses above pass.

The final `PASS_AFTER_PATCHES` correction `cf83d77c` changes no behavior. The
decoder keys its membership path from the already-bound non-NULL universe rule
rather than introducing a new `availability_active` mode branch, so the four
transient census rows disappear. The WS4b checker reports no WS25-owned
unclassified row; its sole remaining unowned row is the pre-existing
`ledgr_strategy_schedule_sessions` entry. Separate fixed-context-half and
run-axis-half mutations fail LTB-0558, and the public A0 remains byte-identical.

## Diagnostic reader correction

The private aggregate pass at product `1e6ae7b5` exposed repeated exact
store-wide validation on public result reads. The public correction chain
through `659c40de` keeps the full corruption check and reuses its proof only
inside one opened durable handle whose run store, attached snapshot store,
coverage and summary evidence are unchanged. Direct internal reads, in-memory
stores and explicit transactions remain cold. The reproducible public record
and unresolved cold-memory evidence are under
`dev/bench/v0_2_3_diagnostic_reader_reuse/`.

The final independent review returned `PASS_AFTER_PATCHES`. Exact correction
`a18c7957` closes its three findings:

- every DuckDB query on the logical validation/decode path uses one resource
  boundary, and a real 90,000-row run under a 16 MB connection limit raises
  `ledgr_diagnostic_resource_exhausted` without product-side memory mutation;
  the same run also seeds one exact proof before lowering a fresh connection's
  local limit, proving that final logical decode maps the backend refusal;
- a same-handle attached-snapshot mutation invalidates the proof, while a
  transaction-local repair of persisted corruption cannot publish a proof
  that survives rollback;
- the README gives fresh-directory commands for both committed records and
  binds the exact eight-character `SOURCE_COMMIT`/`LEDGR_SOURCE_COMMIT`
  identity convention.

Failure-sensitive mutations confirm the three boundaries: one raw final
decode query fails LTB-0565, removing the publish-side transaction guard fails
LTB-0561, and dropping attached stores from the token fails LTB-0564. The
focused decoder, split-store and documentation-contract suites pass. The
4,419/4,875 MiB cold peaks are about 4.32/4.76 GiB; this correction does not
claim to reduce them.

Final bounded correction `f64d5711` extends that same query boundary to the
persisted-summary reader and terminal summary reduction, and proves the final
logical decode itself refuses with the stable class after a warm proof under a
connection-local 16 MB limit. It changes no memory setting in product code.

The maintainer accepts this cold-memory residual as LDG-3209's explicit memory
exception against v0.2.2 base `0d6c0b11`. The user-visible limit is one cold
full-trace validation and decode per opened run handle: about 2.4 to 4.9 GiB
peak on the largest private workload; the public dense cold record moves from
320 to 1,445 MiB and from 0.13 to 1.52 seconds. LDG-3210 is reserved in the
macro plan's later WS9b cut to reduce that cold cost without weakening exact
corruption refusal. For H1, a run/sweep ratio above 1.10x still needs causal
attribution: excess caused by cold validation/decode is covered and disclosed
by this exception; any other cause is a finding.

## Gates still open under LDG-3209

The public harness and proof families are ready, but the following evidence was
not run or inferred:

1. the private Sharadar rebuild and aggregate comparison;
2. the rule-16 milestone timing record;
3. the paired H1 public memory protocol.

No E: data was read. The memory exception is recorded, but LDG-3209 and
Workstream 25 remain pending until the maintainer-run private rerun, rule-16
milestone and H1 evidence are recorded and an independent close review accepts
the complete workstream.
