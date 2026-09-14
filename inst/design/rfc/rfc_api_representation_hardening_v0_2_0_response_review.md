# Response Review: API And Representation-Boundary Hardening

**Role:** Codex, Seed v1 author. **Date:** 2026-09-09.
**Status:** Review complete; no implementation or acceptance action taken.
Short citations use `seed.md`, `response.md`, and `probe_findings.md` for the
three same-topic files named in the review brief.

## What Ran

- Baseline: `v0.1.9.8` at
  `677ab9646a9988afa66bfc5c766b81dde25631f3`. No reviewed package or test
  file changed from the response baseline (`response.md:7`).
- From the package root: `Rscript
  dev/spikes/api-representation-hardening/probe.R`. Environment: R 4.5.2 ucrt,
  ledgr 0.1.9.7, duckdb 1.4.3, dplyr 1.1.4. All twelve observations in
  `dev/spikes/api-representation-hardening/probe_findings.md:19-58`
  reproduced; none differed. The probe's internal Git call hit the sandbox
  safe-directory check, so I confirmed the SHA separately. Verification:
  executed.
- Gut: in an archived scratch copy, I changed only the closing split-row fee
  at `R/backtest.R:1413-1417` to zero. Case 9 changed from derived/source fees
  `13.045/6.775` with six mismatches to `6.775/6.775` with zero mismatches.
  The scratch copy was deleted; repository `R/` stayed unchanged.
  Verification: executed.
- Source census: `R/backtest-runner.R:574-1496`, resume tests at
  `tests/testthat/test-runner.R:110-220`, parity at
  `tests/testthat/test-acceptance-v0.1.0.R:291-362`, and writer atomicity at
  `tests/testthat/test-ledger-writer.R:432-453`.

## Findings By Severity

### High

None.

### Medium

**M-1: the coordinator census is not extraction-safe as written.** It labels
runner lines 574-626 side-effect-free and preparation "Pure"
(`response.md:127,150`), but those lines read the clock, call `set.seed()`, and
overlap the store open (`R/backtest-runner.R:598,622-626`). Opening events are
not in the claimed registration block; they are at lines 973-982. Preparation
also records `RUNNING` at line 994 and mutates feature cache at lines 1190-1196.
The snapshot block creates TEMP views and updates the run at lines 873-875.
Verification: source.

The four stages remain viable only as extraction/commit order with calls left
in runtime order. Moving preparation before the snapshot stage would break its
connection, handler, TEMP-view, snapshot-hash, pulse, and resume dependencies.
Cleanup remains coordinator-scoped (`R/backtest-runner.R:629-633`), resume
cleanup depends on the handler (750-757, 914-965), and the second lot pass stays
after execution (1396-1417). No test injects failure through the coordinator's
multi-write sequence; the cited writer test is lower-level. Synthesis must use
an effect-aware phase map and say stage numbers are not runtime order.

### Low

**L-1: eager-only removal leaves `lazy` ambiguous.** The response removes the
cursor and `stream_threshold` (`response.md:214-215,277-280`), while the current
formal has both `lazy` and `stream_threshold` (`R/backtest.R:1158-1190`). State
explicitly that eager-only removes both arguments. The RFC index also omits
`stream_threshold` (`inst/design/rfc/README.md:41`). Verification: source and
accepted decision.

**L-2: "no new public surface" is too broad.** Response line 25 rejects a new
entry point, while lines 109-111 add a public `ledgr_run_info()` field. Say
"no new public export or entry point." Verification: source.

The decisions otherwise agree across response Sections 1, 2, 3, 6, 7, 9, and
10 and the RFC index: pro rata fees (`response.md:52,177-184,277`), eager fills
(50-51,67,209-215,278), durable locator handles (53,218-223,279-281), and
four-stage extraction (35,71,150-159,261-265,282-283). Section 9 puts
corrections before moves and failure injection before stages 3 and 4.

## Seed Reconciliation Table

| Seed proposal | Disposition | Review |
| --- | --- | --- |
| `ledgr_target_values()` (`seed.md:99-107`) | Accept rejection | The rerun confirms `c(target)` is sufficient (`probe_findings.md:39-41`). |
| Nine-file ownership map (`seed.md:137-158`) | Accept with wording change | It is an invariant map, not a required file manifest; split `backtest.R` first and use M-1's corrected phases. |
| Alternative B ordering (`seed.md:226-233`) | Accept with wording change | The seed already puts corrections before moves; the response specifies, rather than reorders, it. Stage numbers are extraction order only. |
| Compatibility framing (`seed.md:197-203`) | Accept amendment | Before/after examples and packet disposition replace migration guarantees; saved internal artifacts still need an explicit decision (`response.md:199-207`). |
| Cursor retention (`seed.md:95,119`) | Accept amendment | No public consumer or methods and data-dependent types were reproduced (`probe_findings.md:42-52`); remove cursor, `lazy`, and `stream_threshold`. |

## Decision

The response answers the prerequisite and supports the accepted choices. M-1
is a synthesis correction, not a reason to reopen Seed v1. A third author must
carry M-1 and both Low clarifications before any spec packet.

proceed to synthesis by a third author
