# Availability Hot-Path Representation - Response Review

**Status:** Response Review v1; verification of Seed v1 and Response v1.
**Author:** Codex, the Seed v1 author. Defenses of Seed v1 are explicit below.

## Reviewed source state

- Branch `v0.2.0.1`; HEAD `cb3047b8b45c64e34589b58ef2e8bfb33f5b2cc2`.
- Worktree: six pre-existing modified files and four untracked paths, including
  Seed v1, Response v1, and two spike directories. Nothing cleaned or staged.
- Windows x86_64; R 4.5.2. The source probe reran with isolated collapse 2.1.8
  and exited 0; character, list, and all frame parity checks passed.
- The independent temporary seam test used duckdb 1.4.3 and exited 0.
- Both default R 4.5.2 and R 4.6.1 libraries currently contain collapse 2.1.7;
  exact 2.1.8 was loaded only from the isolated source-built library.

## Verdicts

### F1 - NARROW

The Response correctly challenges Seed 6's certainty, but does not establish
provider resolution as the dominant wall lane. Source verification shows one
`decision_view()` per flat-fold pulse (`R/fold-engine.R:374-380`). The external
7.876 seconds contains one decision view plus 505 per-target execution views
(`batch2-review.md:310-318`); the flat control performs no per-target
`execution_view()` work (`batch2-review.md:161-167`). Multiplying all 7.876
seconds by 757 gives 5,962 seconds arithmetically, but its premise is wrong.

The external 12x ladder measures membership resolution as complete-list headers
accumulate (`batch2-review.md:132-159`). It proves cutoff-sensitive growth, not
the total cost of 757 decision views. Seed 6's "minutes rather than the
thirty-minute class" is at most an inference, not a measured lane total.

The diagnostic extrapolations are arithmetically sound if linearity is assumed:
505 x 757 = 382,285 rows, about 298 constructor seconds and about 2,071 MiB of
retained row-list objects at the Response's rates. They remain synthetic
inferences. Although `do.call(rbind, ...)` follows the loop
(`R/fold-engine.R:1077-1108`), `RUNNING` does not prove the killed process had
not entered it; the external record says no stage marker existed.

I defend Seed v1 only this far: its memory mechanism is verified. Seed 2 must
stop calling the unlocalized external blocker its production consequence.

### F2 - ACCEPT

The collapse probe establishes eligibility of one mutation primitive, not the
cheaper prerequisite for selecting the first performance lane
(`spike_protocol.md:20-25`). A lane profile is prior to any wall-first claim.
The database primitive is a seam check, not the unresolved attribution question.

Direct execution confirmed starts 1 and 4, five committed rows, and next
sequence 6 after forced rollback. Source confirms one current diagnostics write
after the loop (`R/fold-engine.R:1082-1108`), one transaction over the invocation
(`R/backtest-runner.R:260-262`; `R/fold-engine.R:1113-1119`), write-time
`MAX + 1` (`R/backtest-runner.R:426-437`), and exception evidence after rollback
(`R/fold-engine.R:1121-1139`). Clean/resume equality, exception sequence, and
avoiding a second `write_run_evidence()` write remain fork cases.

### F3 - ACCEPT

`build_columns_once()` is one complete frame from known vectors
(`probe.R:68-94`), not per-row typed writes plus bounded flushes and persistence.
It excludes live `[[id]]` lookups (`R/fold-engine.R:623-649`), varying JSON,
transaction-buffer memory, and `dbAppendTable()`. Its timing is an attainable
bound clue, not a measurement of Seed 4.2's writer.

### F4 - NARROW

A Seed may propose a spike but its author may not charter it
(`rfc_cycle.md:234-243`). Seed 5 should call its fixture and parity surfaces
candidate constraints for the charter author. The Response overstates
`spike_protocol.md:27-38`: Seed v1 has no expected table, frozen witness list,
or checker, and its ten-case cap repeats the protocol's own cap.

### F5 - ACCEPT

Seed 2 misattributes all three rules to v0.1.8.9. That packet binds typed
scale-growing buffers and `setv()` (`v0_1_8_9_spec.md:72-88,129-143`). The
boundary-frame rule is in the primitive-internals synthesis, lines 197-220;
`audits/fold_path_hotpath_audit.md:53-61,232-247` records the exact
per-row-frame plus final-bind anti-pattern. Source verified.

### F6 - CONTEST

Seed 4.3 does not require collapse 2.1.8: it says the spike may test it, must
retain a base/vectorized alternative, and cannot infer production safety from
the probe (`Seed v1:112-124`). Open question 3 already asks about a version
floor. The official 2.1.8 changelog confirms issue 876 could cause memory
corruption, cryptic errors, or crashes, so a loud ledgr reproducer does not
disprove Seed's safety framing.

The Response also mislabels the existing reconstruction buffer as chunked. It
is preallocated to twice the input size and grows geometrically if needed
(`R/fold-reconstruction.R:155-202,288-300`); it never flushes. Character
`setv()` exists at lines 219-227, but does not prove a new writer safe under
2.1.7. `DESCRIPTION:22-30` correctly has no collapse version floor.

### F7 - ACCEPT

`v0.2.0.x` assumes a patch-series destination. The roadmap reserves v0.2.0.1
for crypto (`ledgr_roadmap.md:6-8,117`), and agent context authorizes no
representation optimization (`AGENTS.md:303-310`). Seed v2 should leave release
placement open for the maintainer.

### F8 - ACCEPT

Ordering is authoritative: the spec binds pulse/stage/axis order
(`v0_2_0_0_spec.md:424-429`) and the contract binds the ordered durable trace
(`contracts.md:462-471,872-883`). The handler sequences incoming row order
(`R/backtest-runner.R:426-437`), so any writer must preserve flush arrival order
and uninterrupted/resumed sequence continuity.

## Errors in the Response

1. The 5,960-second floor wrongly treats a mixed decision-plus-505-execution
   measurement as one flat-pulse decision cost.
2. `RUNNING` and source order do not prove final `rbind` had not begun.
3. `test-availability-parity.R:40` is an INCOMPLETE reopen test. Append/sequence
   coverage is `test-availability-economics.R:815-855`.
4. `R/fold-reconstruction.R` does not implement chunk flushing.
5. "Seed v2, then Response Review" reverses stages 4 and 5
   (`rfc_cycle.md:20-29`). This artifact is the Response Review.
6. The claimed R 4.6.1 default collapse 2.1.8 is now 2.1.7. Libraries are
   mutable, so the earlier environment claim is non-durable, not disproven.
7. Three noisy constructor points support "approximately linear over this
   ladder," not an unqualified linear claim.

## Decision

Seed v2 is warranted after the lane-profile probe. It must change:

- Header/Section 10: leave release placement open.
- Section 2: separate verified diagnostic memory cost from the unlocalized wall
  blocker and remove the causal "production consequence" claim.
- Section 4.2: label one-shot construction an attainable-bound clue; leave the
  fork to measure scalar/block writes, chunks, and persistence.
- Section 4.3: make 2.1.8 an optional mechanism, not the spike prerequisite.
- Section 5: name the lane profile as prerequisite and make fixture/parity items
  non-binding candidates for a different charter author.
- Section 6: let the profile decide diagnostic-memory correction versus
  rechartering around provider resolution; drop unsupported provider timing.
- Section 8: correct the F5 citations.

## Prerequisite probe specification

This is `spike_protocol.md` Section 1 work, not a spike.

- Fixture: public synthetic 563 instruments, 505-member axis, complete bars,
  zero holdings, flat strategy, synthetic membership/status/lifetime facts,
  40 decision pulses, and four complete lists spread across the window.
- Execute current production code only: one warm-up and three identical measured
  runs, each in a fresh scratch store, with no execution-view calls.
- Record raw and median wall, process peak working set, and
  `Rprof(memory.profiling=TRUE)` self/total time and allocation for provider
  membership/status/lifetime, valuation, diagnostic construct/append, final
  `rbind`, DuckDB append, and residual fold.
- State that current `t_loop` includes transaction, bind, and persistence, not
  only the `for` loop (`R/fold-engine.R:1113-1141`).
- Falsify diagnostic-first wall attribution if diagnostic construct plus
  bind/persistence is not the largest wall lane, or provider resolution is
  larger. That result leaves the independent memory defect intact but forces
  Seed v2 to frame it as memory-only or recharter.

## Open decisions

1. Cycle objective after profiling: diagnostic-memory correction or leading
   full-fold wall lane. Authority: maintainer before Seed v2.
2. Release destination. Authority: maintainer by synthesis acceptance.
3. Minimum collapse version, only if the alternative depends on character/list
   `setv()`. Authority: synthesis and spec-cut.

## Commands and evidence

```text
git branch --show-current -> v0.2.0.1
git rev-parse HEAD -> cb3047b8b45c64e34589b58ef2e8bfb33f5b2cc2
probe.R, isolated collapse 2.1.8 -> exit 0
  setv parity TRUE/TRUE; 70k writes 0.85 s
  rows: 5k/10k/20k; construct: 3.87/7.22/16.08 s
  bind: 2.15/7.05/25.47 s; list: 27.08/54.17/108.34 MiB
  all one-shot column-frame parity checks TRUE
temporary seam, duckdb 1.4.3 -> exit 0
  starts 1/4; rows 5 after commit and rollback; next sequence 6
R 4.5.2 and R 4.6.1 default collapse -> 2.1.7
```

No private lake or licensed rows were read. External evidence was limited to
the assigned aggregate sections. Collapse safety was checked against the
official 2.1.8 changelog.

## Revision history

- 2026-09-14 - Response Review v1 of Seed v1 and Response v1 at `cb3047b`.
  Probe and seam rerun; no other repository file modified by this review.

RECOMMENDED_NEXT_STAGE: prerequisite lane-profile probe, then Seed v2
