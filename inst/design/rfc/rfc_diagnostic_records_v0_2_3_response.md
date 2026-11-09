# Diagnostic records amendment: Type 2 response

- Author: Codex, 2026-11-09. Mode: Type 2.
- Provisional until the maintainer reads the brief and response together.
- Reviewed source: `b96e060bf3a18238d641e1b1899136793ecfcea8`;
  executed installed build: `d5b3a151`. No worktree edits.
- Repository-relative citations resolve in the reviewed tree. `probe/...`
  resolves beside this response. **C** means `inst/design/contracts.md`;
  **S** means `inst/design/rfc/rfc_diagnostic_records_v0_2_3_seed.md`;
  **P** means `inst/design/rfc/rfc_lean_core_pulse_plumbing_v0_2_3_synthesis.md`;
  **D** means `inst/design/rfc/rfc_per_pulse_durable_records_v0_2_3_synthesis.md`.
- Stable contract groups used below: `C#contract-execution-fold-core`,
  `C#contract-persistence-fold-evidence`, `C#contract-result-read-surfaces`,
  and `C#contract-persistence-current-format`.

**Revise before synthesis.** The direction addresses the maintainer's position:
select retained evidence before expanding it, persist after execution, and
make expensive trace expansion a read operation. But D1 is not yet an exact
general codec, D4's formula omits clean-fill decisions, and D6 cannot be
derived from cash/events alone. D5 has a runnable SQL candidate here; it
does not yet meet the current query cost or establish complete reader parity.
The claim that the default costs only one count per pulse is premature.

The useful default is a cheap *evidence recorder*, with the complete logical
trace produced on demand. Do not equate fewer stored rows with cheaper
execution, or treat strategy intent as inferable from an unchanged portfolio.
Exact certified encoding, read-only explanation and no callback execution
remain required by `C:1537` and `C:2787`.

## Executed evidence and its limits

`probe/run.R:31` runs four committed workloads through the pin and tests a
SQL reconstruction after deleting only physical holds in disposable stores.
`probe/edges.R:1` executes missing-mark P2 stops, a P3 reconciliation fault,
sizing skips, risk reductions, a sub-actionability request, promotion,
comparison, publication recovery and a nonterminal restart. `probe/h1.R:1`
copies and verifies the registered private snapshot, runs monthly momentum,
and emits aggregates only. Environment: `probe/environment.csv:2`.

I also reran the existing rebuild on all six workloads, including the dynamic
membership fixture: exact trace equality in each case
(`probe/prior_rebuild/rebuild.csv:2`). I reran the keep-before-build sweep
fork on momentum, risk and membership fixtures: retained outputs match the
pin (`probe/prior_sweeps/fork_sweeps.csv:2`). The small momentum median was
0.89 s versus 0.71 s; the two small edge fixtures establish correctness,
not a performance ranking. These reproduce part of the closeout's evidence;
they do not promote its open questions into proven behavior
(`dev/spikes/diagnostic_records/closeout.md:53`).

The SQL candidate is a projection, not an execution engine. It derives
sequence gaps from residual rows, joins the configured axis and sealed closes,
and reads ledger positions using a window sum and an as-of join
(`probe/sql.R:4`). Counts are derived before removing holds; configuration
supplies the axis. No baseline hold row supplies reconstructed values.
Point queries restrict the pulse before gap expansion and retain its preceding
stored sequence anchor. This is fixed-axis evidence only. Membership SQL,
all corruption refusals, and integration into public explanations are open.

The checker reruns public probes, diffs correctness fields, and checks source
scope; it excludes timing differences (`probe/check.R:1`). The count gut
decrements one pulse certificate and must refuse; the P3 gut alters an internal
expected-cash value and reaches the existing stop (`probe/run.R:119`,
`probe/edge_p3.csv:5`). The inventory is `probe/probe_findings.md:1`.

## 1. Section 6 Q1: D2 needs a path-specific qualification

**Yes for eliminating normal clean-hold materialization; no as a blanket
equivalence for every decision-emission path.** Select from primitive vectors
before `ledgr_fold_diagnostic_segment()`, not merely before staging. The
executed pin still constructs the decision segment first
(`R/fold-engine.R:927`, `probe/decision_segments.csv:2`).

| Executed path | Required treatment |
| --- | --- |
| Successful decided pulse | Certify exact pre/post-risk target, before/after position, current finite close, zero mark age, no reasons/risk residual and no fill/rejection association. Existing predicates provide the starting oracle (`R/diagnostic-codec.R:60`). |
| Missing risk mark in P2 | Preserve the decision rows with `target_after_risk = NA`, then the risk stop. P3 was never reached (`probe/edge_risk_stop.csv:3`, `R/fold-engine.R:976`). |
| P3 reconciliation stop | Preserve the deferred decisions and stop without P4/P5 effects. The injected failure retains even CLOCK's numerically unchanged decision as explicit evidence (`probe/edge_p3.csv:4`, `R/fold-engine.R:1163`). |
| Sizing-skipped ID | Equal target/position does not mean clean: keep `sizing_unavailable`; the probe emits eight such decision rows (`probe/edge_counts.csv:3`, `R/fold-engine.R:940`; `C:1385`). |
| Risk-reduced target | Retain the original target even when risk makes the achieved quantity unchanged (`probe/edge_risk.csv:4`). |
| Tiny request | A target of `1e-10` survives as intent although no fill is actionable (`probe/edge_tiny.csv:4`). Exact certification must not use the execution tolerance. |
| Scheduled skip | Keep the empty-ID skip disclosure and any valuation evidence. The H1 run has 6,869 skips (`probe/h1_kinds.csv:3`); these are not instrument hold decisions (`C:149`). |

Initially restrict hold omission to the successful P3 certification domain;
leave stop-path decisions as residuals. A later exact stop encoding may remove
them too. This is one recorder rule in the existing fold, not a second
execution path. Economic checks, callback validation, risk, lot arithmetic
and stop precedence stay unchanged (`C:193`, `C:1537`).

**D1 also needs an exact position owner.** The fractional fixture is decisive:
at diagnostic sequences 26 and 28 the fold records
`0.20000000000000004`, whereas both sequential R addition of ledger deltas
and the SQL rebuild produce `0.20000000000000001`
(`probe/fractional_sequential.csv:8`, `probe/sql_differences.csv:2`). Six
numeric columns differ; toleranced comparison would miss this defect.
P4 takes positions from the lot book, not an algebraic event sum
(`R/fold-engine.R:1505`); the executed partial-close rule updates net as
`(net - old_lot) + remaining_lot` (`R/lot-accounting.R:471`).

My correction is to retain exact position anchors at position-changing
boundaries, reusing existing certified fill/explicit evidence where it suffices,
and adding typed position residuals where it does not. Cover openings,
partial closes, dispositions and corporate actions before claiming completeness.
Do not rerun FIFO in SQL or change the fold to match a convenient sum.
Whether the existing retained evidence suffices for every boundary is open;
the new probe disproves the proposed sum, not every possible exact codec.

## 2. Section 6 Q2: H1 supports buffering, not an unbounded-memory claim

The verified registered H1 run completed DONE. Its retained physical payload,
after excluding holds, is (`probe/h1.csv:2`):

| Payload | Rows | R object size |
| --- | ---: | ---: |
| Explicit diagnostic residuals | 23,036 | 5.795 MiB |
| Implicit clean fills | 8,797 | 0.998 MiB |
| Omitted holds | 163,775 over 344 hold-bearing pulses | Excluded |
| Ledger events | Measured separately | 3.023 MiB |
| Equity | Measured separately | 0.387 MiB |

Thus diagnostic payload is about **6.79 MiB**, and diagnostics plus ledger
and equity about **10.20 MiB**, before count/header records, extra exact-position
evidence, capacity slack, strings shared across objects, and terminal copies.
That is acceptable evidence for pursuing D3 on H1. It is not peak memory of
an implemented D1-D3 writer: this probe measures retained frames from the pin.
The public fill-heavy payload is 8.14 MiB (`probe/sql_metrics.csv:2`).

Adopt **no persistent write while pulses are being processed**, with compact
typed records retained by their existing owners and terminal materialization
in bounded batches inside the same transaction. "At the end" need not mean
one giant frame or one append per table. Keep accepted-prefix publication,
stop drainage and rollback guarantees (`C:1537`). A finite workload measurement
is a capacity observation, not a bound for arbitrarily long or exception-heavy
runs. Measure live capacity and peak during terminal materialization at cut.

D3's supersession must name P's R7/R8 and Section 5 full-chunk flushing,
not just a paraphrased "per chunk or at the end" clause (`P:148`, `P:259`).
Address `checkpoint_every` explicitly: P preserves it pending a named
identity decision (`P:305`, `P:432`). Do not retain an ignored compatibility
argument or quietly change a hashed flush control. Mandatory economic
effects remain computed once and retained (`C:205`).

## 3. Section 6 Q3: SQL is viable, read-cost parity is not shown

Three repeated warm queries at the same DBI result boundary, median seconds:

| Workload | Current full SQL | Rebuilt full SQL | Current point SQL | Rebuilt point SQL |
| --- | ---: | ---: | ---: | ---: |
| Crossover 500 x 1,260 | 0.32 | 0.50 | <0.01 | 0.03 |
| Momentum 500 x 1,260 | 0.01 | 0.05 | <0.01 | 0.01 |

`probe/sql_metrics.csv:2` records the measurements. These are exploratory
local clocks with approximately 0.01 s resolution, not release gates or
cold end-to-end timings. Integer-workload full and point rows match exactly;
the fractional full trace fails. Public baseline full/explain reads were
0.74/0.61 s and 0.19/0.16 s respectively. Those public clocks include work
outside SQL and must not be compared to the rebuilt query as equivalent APIs.

The point query expands only its pulse, unlike an outer filter over a full
gap expansion (`probe/sql.R:12`). Even so it is not a complete D5 proof:
it excludes the full production integrity protocol and the availability,
valuation and other explanation joins. `certify()` only exercises gap counts;
it does not replace current association/order checks (`R/diagnostic-decoder.R:285`).
The old coverage query itself counts the full logical union
(`R/diagnostic-decoder.R:341`); grafting holds onto that view could still
expand the run during a point read.

Keep one decoder, but give it parameter-aware dependency selection and
validate compact evidence without synthesizing every hold. I would add an
explicit decision-block sequence base and axis extent to the per-pulse
certificate, rather than depending permanently on the next physical row.
This is a proposed codec improvement, not a tested speed claim. It also
removes D1's dependence on D6 retaining a terminal row. In particular, deleting
reconciliation would invalidate this prototype's "next stored row" placement
on consecutive all-hold pulses (`probe/sql.R:8`).

Require exact full/filtered, point/history explain and reopen parity with
the existing no-callback/no-write and corruption refusals before adoption
(`C:2787`). Use the shared timing harness for the eventual paired gate;
this response does not claim D5 meets today's cost, especially on membership H1.

## 4. Section 6 Q4: D6 is not derivable from cash and events alone

Two executed long-only runs request CLOCK targets -1 and -2. Risk clips
both to zero. Ledger and equity outputs are identical, but every reconciliation
tuple has intended gross 100 versus 200, with cash 1,000 and post-risk/actual
gross zero (`probe/recon_economics.csv:2`, `probe/edge_tuples.csv:14`).
Successful cash reconciliation therefore does not make the tuple redundant.
It requires strategy/risk evidence and the original reduction order, not
just cash and events. P5 also derives cash-before by final cash minus the
sum of fill deltas (`R/fold-engine.R:1571`); do not replace it by an assumed
prior cash value or assume SQL arithmetic is bit-identical.

Keep the reconciliation row for now. If compressed later, retain its six
typed values and logical presence/sequence, omitting a field only under an
exact field-specific reconstruction rule. The checks always execute.
An alternative worth implementing is a compact typed tuple with constant
fields and JSON rendered only on read; that avoids inventing a derivation
rule. This is a proposal, with no measured speed claim here.
"Only store when reconciliation is not exact" is not such a rule: it would
lose the two different successful tuples above. H1 also shows one row per
processed pulse, including skipped pulses, rather than only decided pulses
(`probe/h1_kinds.csv:6`). D6 must amend both D Section 3 and P LR-14's
"row remains" clause explicitly (`D:118`, `P:241`).

## 5. Section 6 Q5: physical consumers exist, with narrower assumptions

The executed consumer seams are recorded in `probe/consumer_boundaries.csv:1`
and their SQL in `probe/consumer_queries.csv:1`:

- Promotion invokes `ledgr_run()` and builds committed evidence; it does not
  copy a candidate's physical trace (`probe/edges.R:98`, `R/sweep.R:812`).
- Run comparison reads compact summary evidence. Preserve that path; do not
  force it to expand holds (`R/diagnostic-decoder.R:534`, `probe/comparison.csv:2`).
- The batched completion helper directly reads physical `outcome='stopped'`
  rows. It remains valid if stops remain explicit (`R/availability-results.R:118`).
- Numbering directly takes maxima of explicit and implicit sequence columns
  (`R/diagnostic-decoder.R:519`). It must account for any new logical tail
  encoding, especially if reconciliation is omitted.
- Restart clears the physical evidence tables (`R/run-resume.R:15`); add the
  new certificate/position tables to that atomic clearing boundary. Publication
  recovery must still validate terminal evidence without callback execution
  (`C:1594`). The probe executes both recovery and a fresh nonterminal restart.

Physical access is not automatically defective: a decoder/summary producer
must know its codec, and a stop-only query may rely on explicit stop storage.
Audit and update these assumptions with the format change; no legacy fallback.

## Additional corrections and recommendation

**D4's count formula is wrong.** On crossover the pin's summary counts
630,000 decisions. Residual decisions plus holds gives 562,275, missing
67,725 clean-fill decisions (`probe/reductions.csv:2`). Correct the rule to
include explicit decisions, certified hold decisions **and clean-fill
decisions**, preserving scheduled-skip/empty-axis counting and the distinct
named-ID time domain. Momentum similarly gives 29,703 versus the proposed
28,821 (`probe/reductions.csv:3`; executed reducer `R/diagnostic-codec.R:158`).
Move counts to their producers, but preserve sizing reduction values/order;
do not incrementally sum pulse subtotals merely because it is convenient.
Summary evidence accelerates reads and does not replace retained instructions
(`C:2787`; current reduction `R/diagnostic-codec.R:233`).

Keep full logical diagnostics by default provisionally. Exceptions-only
retention would change `C:2787` and explain's missing-trace refusal at
`C:2806`; it is a genuine product decision, not an implementation shortcut.
The seed has not established a cheap default: classification still examines
decision vectors, fill/residual recording remains, and D5 has remaining costs.
Demonstrate the whole recording/finalization boundary before declaring the
opt-in question settled. Preserve the rejected replay alternative's reason:
explanations must work without executing user code (`C:2792`).

I would proceed with the already-separated sweep keep rule, then revise the
durable amendment around exact position ownership, pulse certificates,
terminal-only I/O and correct producer summaries. The sweep rerun supports
early retention selection, not a promise of zero mandatory accounting work.
Keep reconciliation explicit in this amendment. D1/D5 exactness and read-cost
proof are the prerequisite before committing the durable format change.
Change only the recorder/read representation in the common core; preserve
every economic output. Bump the then-current store/codec versions and refuse
older formats with the existing classed gate (`C:1502`). No migration,
compatibility reader, strategy replay or alternate execution path is proposed.
