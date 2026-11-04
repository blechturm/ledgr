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

The fills reader no longer reads diagnostics. It associates typed fill times
with the unique declared session axis through one vectorized match; ambiguous
or missing session anchors yield typed missing recording pulses. No logical
read invokes strategy, indicator, risk or cost code, and no read writes the
store. Split-store readers attach the snapshot on the connection used by the
decoder, including closed-handle summary and terminal-evidence paths.

LTB-0554/LCL-0543 owns the complete and bounded decoder, empty nonterminal
evidence, the no-callback witness, the store-wide no-decode counters and the
literal production-source census. LTB-0210 owns fill/session association and
its vectorized shape.

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

LTB-0554, LTB-0556 and LTB-0558 (LCL-0543/LCL-0545) own logical parity,
physical omission, typed certification, lazy allocation, writer order and the
corruption matrix. The codec is store-format authority only: schema stays 125,
the new codec-rule binding changes the store fingerprint, and run/snapshot
identity rules do not change. An otherwise current schema-125 store carrying
the WS24-close fingerprint refuses with `fingerprint_mismatch`.

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

## Public verification on the correction candidate

- package suite: 1,347 blocks, no failure;
- focused decoder, restart, writer, session-association, split-store and
  control-plane suites: pass, including registered mutations;
- A0: 297 canonical files (619,011 bytes), byte-identical on re-record;
  control passes and every registered corruption fails with its named surface;
- typed-accounting checker: 90 seams, 30 accounting fields and 22 diagnostic
  fields, pass; its private gate remains open;
- codebase census checker: 2,008 helpers, 2,485 conditions and 89 findings,
  pass;
- R CMD build and `R CMD check --no-manual --no-build-vignettes`: pass on the
  final candidate.

The first R CMD check exposed a metadata error in the newly added decoder test
file: a block-profile marker applied only to its first block. It was corrected
to a file-profile marker; the static claim checker then assigned all four
blocks to `review`, and the final build/check passed.

## Gates still open under LDG-3209

The public harness and proof families are ready, but the following evidence was
not run or inferred:

1. the private Sharadar rebuild and aggregate comparison;
2. the rule-16 milestone timing record;
3. the paired H1 public memory protocol.

No E: data was read. LDG-3209 and Workstream 25 remain pending until the
maintainer-run evidence is recorded and an independent close review accepts the
complete workstream.
