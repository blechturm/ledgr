# Workstream 10 Closeout: Boundary And Sealed Facts

**Status:** Agent-provisional; awaiting the independent Type 1 close review
and maintainer acceptance.

**Authority:** cut 6, Workstream 10, LDG-2804 through LDG-2808 in
`tickets.yml`, under the accepted equity-settlement synthesis.

**Initial implementation range:** `ea22976` through `c109e7e`. The focused
correction after the first close review is committed separately under
LDG-2808 and is part of the range supplied to the re-reviewer.

## What Shipped

- Pulse plans declare their economic-event kinds. Both accounting arms read
  the same prepared event source. Canonical R refuses every kind for which it
  has no handler, and compiled spot-FIFO separately refuses `CASHFLOW`,
  `DISPOSITION`, and every other non-`FILL` kind before accounting. Neither
  arm can complete while silently dropping a declared event.
- The public `ledgr_facts_equity_corporate_actions()` constructor validates a
  vendor-neutral typed family. Its header keeps stable fact and parent
  identity, four optional clocks, completeness, one refusal reason, and a
  provenance tier. Each supplied cash, recipient, or quantity term requires
  its own independent-validation flag.
- The family persists, migrates from schema 115 to 116, participates in the
  rule-2 snapshot hash, and is checked again at the seal boundary. A snapshot
  that never declared it retains its rule-1 hash.
- Corporate-action evidence is intentionally absent from availability's
  activation list. Facts alone therefore require neither a session calendar
  nor a staleness policy.
- An executable fictional adapter maps unrelated field names and source codes
  to the canonical constructor. Its output and a hand-built family seal to
  identical snapshot hashes.
- Snapshot constructors accept an optional `price_basis` declaration.
  `split_adjusted` and absence reach experiment and config identity;
  `distribution_adjusted` refuses at experiment construction, with or without
  corporate-action facts. A declared basis is read from the verified snapshot
  handle rather than queried again from storage.

No posting policy, `CASHFLOW`, `DISPOSITION`, fidelity summary, or account
mutation shipped in this workstream. It establishes the boundary and sealed
inputs on which those later workstreams depend.

## Registered Claims And Gate Cases

| Claim | Detector | Profile | Protected result |
| --- | --- | --- | --- |
| LCL-0022 | LTB-0026 | fast | both accounting envelopes refuse every unhandled kind |
| LCL-0023 | LTB-0027, LTB-0029 | fast | terms validate independently and facts stay runtime-inert |
| LCL-0024 | LTB-0030 | review | the fictional adapter produces canonical sealed facts |
| LCL-0025 | LTB-0031 | review | declared price basis prevents distribution double counting |
| LCL-0026 | LTB-0028 | review | facts persist, migrate, and participate in snapshot identity |

Synthesis gate case 1 is LTB-0030, the fictional non-Sharadar adapter.
Synthesis gate case 10 is LTB-0026, the compiled economic-event-envelope
refusal. LDG-2807's double-counting boundary is LTB-0031; it is not relabelled
as one of the synthesis's numbered fourteen cases.

Three review blocks were moved out of fast only after exact-tree gates showed
why: LTB-0028 cost 3.81 seconds, LTB-0030 cost 1.25 seconds, and LTB-0031
cost 2.85 seconds in their censuses, principally from repeated seals,
experiment construction, and one migration. No assertion was removed. Their
claims were split or rerouted so each detector still runs in exactly the
profile promised by `tests/claims.yml`.

## Spec-Cut Decisions

**Refusal reasons are closed by validator, not enumeration.** A complete fact
must omit the reason. An incomplete fact must carry exactly one non-empty,
stable lower-snake-case code. The accepted synthesis did not enumerate a
vocabulary, and freezing speculative codes here would make every new upstream
evidence limitation a schema change. Shape and stability are closed; semantic
codes remain adapter evidence that later integration must document.

**The fictional adapter is vignette-local executable code.** It lives in
`vignettes/fictional-corporate-action-adapter.R`, is sourced and executed by
LTB-0030, and will be consumed by LDG-2817's adapter-authoring article. It is
not package API because ledgr supports the canonical constructor, not a
fictional source integration. Shipping it as API would add a second supported
ingestion surface solely to demonstrate that the first is vendor-neutral.

**Activation exclusion.** Corporate-action facts are sealed evidence rather
than an availability provider. Activating availability from this family alone
would turn a cash-distribution or terminal-evidence user into a consumer of a
complete session calendar and a staleness policy. LTB-0029 mutates that list
and fails.

## Failure Sensitivity

- Before LDG-2804, all three non-`FILL` table rows completed on the compiled
  arm with their event dropped. The first close review found that the new
  declaration layer still allowed the canonical arm to do the same. A
  `CASHFLOW`-only compiled guard leaves `DISPOSITION` and the synthetic unknown
  kind exposed; removing the canonical handler-set check exposes all three.
  LTB-0026 detects both mutations independently.
- Disabling any supplied-term validation flag made LTB-0027's three term
  witnesses fail. Adding the fact family to availability activation made all
  three LTB-0029 activation and construction assertions fail.
- Mapping fictional `PAYMENT` to `spin_off` made LTB-0030 fail both family and
  sealed-hash parity.
- Disabling the execution price-basis guard made exactly the two
  distribution-adjusted LTB-0031 rows fail, one with facts and one without.
- Closing a split-adjusted handle and replacing the persisted-metadata reader
  with an abort still returns the declared basis, proving the redundant query
  is absent rather than merely fast.
- Corrupting a persisted validation flag makes the seal validator fail, while
  changed cash or a copied missing clock moves the rule-2 hash.

These are behavioral and persistence detectors. No whole-file source hash was
introduced.

## Test Gate And Performance

The final exact-tree fast profile used R 4.6.1, duckdb 1.5.2, testthat 3.3.2,
collapse 2.1.8, and yyjsonr 0.1.22. It passed 441 of 441 blocks in 87.360
seconds. The registered checker passed the one-run rule against the 90-second
bound. Records:

`C:/Users/maxth/ledgr-research/.tmp/ws10/ldg-2808-correction-fast-v2`

Earlier per-ticket clocks remain in `tickets.yml`, including the red medians.
They are not overwritten by the final pass. An earlier exact-tree attempt with
442 fast blocks was also red at 90.210 seconds median over three runs. Its
census identified LTB-0031's 2.85-second repeated seal and construction cost;
moving that intact detector to review produced the final green record.

Two performance surfaces changed:

1. The compiled envelope now normalizes and checks a constant-size kind set
   once per pulse. An interleaved warm component clock over 1,260 pulses,
   repeated 100 times per measurement and divided back to one 1,260-pulse
   pass, gave five prior-path values with median 0.0021 seconds and five new
   boundary values with median 0.0332 seconds. The observed increment is
   0.0311 seconds per 1,260 pulses. It is a component clock, not a peer result.
2. The no-fact CSV-to-sealed-snapshot path was measured cold on the registered
   500-instrument by 1,260-session fixture, alternating the pre-workstream
   `c4874d5` tree with the implementation tree. Before: 7.93, 7.73, 7.72
   seconds, median 7.73. After: 7.82, 7.64, 7.64 seconds, median 7.64. The
   workstream therefore shows no ingestion or seal regression on that shape.

Both clocks wrap the named call in a fresh R process except that the first is
explicitly a warm component loop. Runs were serial on the same host. The
corporate-action family has no registered full-population shape yet, so this
closeout makes no full-scale fact-seal claim.

## Hot-Path And Complexity Audit

The changed production code was walked against the seven shapes and the
maintainer checklist.

- Fact construction and validation operate on whole columns. The only new
  `vapply()` iterates over four fixed logical field names, not rows. No
  per-row frame, timestamp formatting, JSON parse, append, environment-held
  vector write, or pairwise validator was added.
- Persistence uses one `dbAppendTable()` for the family. Seal validation reads
  the table once and applies vector predicates. Work grows linearly with fact
  rows through the existing table/hash boundary.
- The fold still loops over actual fills as before. The new per-pulse work is
  constant-size kind normalization plus canonical and compiled handler-set
  checks; it neither scans events nor grows with open lots.
- Price-basis resolution uses the verified handle metadata when a basis is
  declared and retains the construction-boundary query as the absence and
  legacy fallback. It is not inside ingest row loops, the fold, finalization,
  or result readers.
- The fictional adapter is evidence code at the ingestion boundary. Frames
  are appropriate there and it is not a production hot path.

No hidden O(fact rows squared), O(events squared), or
O(instruments times pulses squared) path was found in the workstream delta.

## Governance And Declined Work

The initial close review was the cut's third review invocation and found the
canonical silent-drop gap. The requested focused re-review would be the fourth
over fifteen tickets, ratio 0.267, below the 0.5 gate. The denominator is the
fifteen tickets present at cut; it does not grow as tickets are completed.

Declined here:

- posting policy, fidelity and ordinary summaries: Workstream 11;
- `CASHFLOW`, entitlement, and posting: Workstream 11;
- `DISPOSITION`, composition, recovery and the full fourteen-case gate:
  Workstream 12;
- exact recipient-quantity transformation: scheduled under its own RFC;
- a second execution engine, compiled support for non-`FILL` events, dynamic
  axis growth, or bypassing seal and hash verification: outside accepted
  scope;
- vendor decoding or adjustment formulas in ledgr: the adapter boundary owns
  them.

Maintainer acceptance may close Workstream 10 and open Workstream 11. This
agent-provisional draft does neither.
