# Availability Hot-Path Representation - Spike Charter Review

**Status:** Independent Charter Review v1.
**Reviewer:** Codex; not the Charter v1 author or lane-profile executor.

## Reviewed source state

- Branch `v0.2.0.1`; HEAD `cb3047b8b45c64e34589b58ef2e8bfb33f5b2cc2`.
- Charter: 150 lines, ASCII-only, LF, untracked, and clean under
  `git diff --no-index --check`.
- Worktree retained the six pre-existing modified files and prior untracked RFC
  and probe artifacts. Nothing was cleaned, staged, committed, or pushed.
- This is the pre-execution structural review. No comparative spike runner or
  evidence CSV exists yet, so `spike_protocol.md` Section 7 cannot run in this
  stage.

## Verdict

**CHANGES_REQUIRED.** The Charter passes the Sections 2, 4, and 8 shape tests,
but its full-scale kill condition is not reproducibly bound. Two corrections
affect the terminal outcome and must land before execution; two smaller wording
corrections remove contradictory stage instructions.

## Smell test

| Check | Result |
| --- | --- |
| Exactly one question | PASS; one four-line blockquote at lines 15-18 |
| Cheaper prerequisite answered | PASS; `DIAGNOSTICS_DOMINANT`, bounded to 40 pulses |
| Exactly two arms | PASS; current versus one columnar/chunked alternative |
| Exactly one kill/recharter condition | PASS structurally; boundary needs correction below |
| No more than ten pre-authored cases | PASS; none are authored |
| No expected table, witness list, or checker | PASS |
| No hash ledger, registry, or workspace gate | PASS |
| No more than two alternatives | PASS |
| Cites executed behavior | PASS; both prerequisite probes exist |
| Charter budget | PASS at exactly 150 lines |

## Findings

### B1 - Blocking: the 1,800-second ceiling is attached to the wrong clock

Charter lines 88-91 register `t_loop <= 1,800 seconds` and call that the
external control's frozen ceiling. The external record instead says the process
was stopped after 1,804 seconds elapsed while the run remained `RUNNING`
(`batch2-integration-verification.md:45-52`; `batch2-review.md:294-303`). It
could not have persisted final `t_loop`: that value is assigned only after
`output_handler$run_transaction(run_loop)` returns
(`R/fold-engine.R:1113-1141`).

This is not cosmetic. A run can satisfy a 1,800-second internal `t_loop` while
exceeding the external process/`ledgr_run()` wall ceiling through setup or
post-fold work.

Required correction: if the charter means to reuse the external ceiling, bind
the 757-pulse ceiling to wall around `ledgr_run()`, with `t_loop` reported as a
secondary decomposition. The 4,096 MiB working-set limit may remain, but label
it a newly registered charter stop in MiB rather than an external measured
ceiling; the external 4,245.6 figure is an observed lower bound labelled MB,
not a frozen 4,096 MiB limit.

### B2 - Blocking: the 757-pulse fixture is not reproducibly specified

Lines 58-59 bind the existing 563-instrument/505-member fixture family, while
lines 88-91 introduce a 757-pulse "production-shaped" member without defining
its fact density. The existing runner is fixed at 40 pulses and four complete
lists (`lane_profile_probe.R:59-67`). This matters because Seed v2 and the lane
profile both state that provider cost grows with applicable headers.

An executor could extend the fixture to 757 pulses while retaining four lists,
or use the external shape's approximately 60 lists. Both satisfy the Charter's
words and can produce materially different kill/recharter outcomes.

Required correction: register one deterministic 757-pulse public fixture shape
before the fork. At minimum bind instrument and member counts, pulse count,
complete-list count and distribution, declared status/lifetime facts, bar
coverage, zero holdings, flat targets, and the no-`execution_view()` assertion.
Using 60 evenly distributed synthetic complete lists would match the aggregate
shape already cited by the cycle without importing licensed rows.

### M1 - Medium: repetition rules conflict across the two fixture sizes

Lines 108-110 require a warm-up and three measured runs per arm, without a size
qualification. Line 91 says the current arm need not finish the 757-pulse
shape. Both cannot govern the full-scale run unchanged.

Required correction: state separately which repetitions apply to the 40-pulse
comparison and which apply to the 757-pulse envelope check, including the
current arm's explicit kill behavior. Keep the two comparison arms unchanged.

### L1 - Low: the Review contract applies the evidence-review procedure too early

Lines 138-141 correctly require a pre-execution smell test, then say this review
must "rerun, gut one path, diff the evidence." Those Section 7 actions require
the runner and recorded CSVs that the executor has not created. A charter
review cannot perform them.

Required correction: distinguish this Sections 2/4/8 structural Charter review
from the later Section 7 evidence review. The latter must be performed after
execution by a reviewer who did not execute the spike.

## Verified non-findings

- The five evidence items are contract-level categories, not pre-authored
  expected rows or witnesses.
- `max_pulses` interruption is real and binding
  (`v0_2_0_0_spec.md:364-368`; `R/fold-engine.R:1067-1069`).
- Allowing base assignment and `collapse::setv()` as details inside one writer
  does not create a third comparison arm.
- The Charter preserves provider, valuation, schema, transaction ownership,
  evidence retention, public frames, and explanation semantics.
- The GREEN/RED/INCONCLUSIVE labels interpret the one result; they are not three
  independent gates.

## Required next step

Write Charter v2 as a new historical successor:

`rfc_availability_hot_path_representation_v0_2_0_x_spike_charter_v2.md`

Keep Charter v1 unchanged. Apply only B1, B2, M1, and L1, retain one question,
two arms, one kill condition, five claim categories, ASCII, and the 150-line
maximum. Do not execute the spike or update the RFC index. Return Charter v2
for one focused re-review; that is the second and final Charter review round
under `spike_protocol.md` Section 7's two-round discipline.

## Commands and evidence

```text
git branch --show-current -> v0.2.0.1
git rev-parse HEAD -> cb3047b8b45c64e34589b58ef2e8bfb33f5b2cc2
charter lines / non-ASCII -> 150 / 0
question headings / arms / kill headings / evidence claims -> 1 / 2 / 1 / 5
git diff --no-index --check -> clean
referenced repository files -> present
```

## Revision history

- 2026-09-14 - Charter Review v1 of Charter v1 at `cb3047b`; structural and
  source verification only, with no spike execution or other repository edit.

CHARTER_REVIEW_DISPOSITION: CHANGES_REQUIRED
