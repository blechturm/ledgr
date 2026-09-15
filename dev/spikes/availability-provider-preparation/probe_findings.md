# Availability Provider Preparation Probe Findings

**Date:** 2026-09-15. **Stage:** prerequisite probe under
`spike_protocol.md` section 1. This is not a Charter, comparative spike, or
production implementation.

## Source state and environment

- Branch `v0.2.0.1`; HEAD
  `5edabae2364914523e18a486ec04db715d925a9e`.
- R 4.5.2 on Windows, collapse 2.1.8, duckdb 1.4.3; ledgr loaded from the
  working tree. The clean run explicitly prepended the existing isolated
  collapse 2.1.8 library through `LEDGR_PROBE_LIB`; the default R library still
  resolves collapse 2.1.7. No package file changed for this probe.
- Registered public fixture: 563 instruments, 505 constant members, 757 open
  weekday pulses, 60 identical complete lists, 30,300 membership rows, 563
  constant `active` status facts, and 563 constant `known_active` lifetime
  facts. Every fact is knowable before its first applicable pulse.
- Positions remain zero. The probe calls `decision_view()` directly, so bars,
  DuckDB, valuation, strategy, diagnostic writing, fills, and
  `execution_view()` are absent.

## Question

On the registered 757-pulse dense/static fixture, how much time does the
current provider spend rebuilding an unchanged decision view, and what lower
bound is exposed when that view is prepared once as primitive vectors before
the pulse loop?

## What ran

`probe.R` constructs normalized facts with the public constructors, converts
them to the same in-memory tables consumed by
`ledgr_availability_provider_build()`, and calls the production
`decision_view()` at every registered cutoff.

Before timing, it resolves the first view once and retains only its primitive
vectors. A deliberately constrained floor returns those vectors at each pulse.
The floor rejects non-zero positions and is valid only because the registered
facts never change their resolved meaning. Every current result is compared
with the floor by `identical()` over the complete returned list.

The current path is measured once at full scale. The floor is measured as 100
complete 757-call sweeps in each of five repetitions and divided by 100 so the
measurement exceeds the Windows timer resolution. `proc.time()` surrounds the
calls; the recorded R heap maxima are not process working-set measurements.

## Results

| measurement | result |
| --- | ---: |
| prepare first primitive-vector view | 0.39 s |
| current provider, 757 calls | 396.02 s |
| current loop including exact comparisons | 396.06 s |
| prepared floor, median 757 calls | 0.0036 s |
| prepared floor, minimum 757 calls | 0.0034 s |
| exact returned views | 757 / 757 |
| mismatched returned views | 0 |
| current maximum R Vcell / Ncell heap | 112.9 / 137.7 MiB |

The five normalized floor repetitions were 0.0036, 0.0034, 0.0042, 0.0036,
and 0.0034 seconds. A preliminary run against collapse 2.1.7 measured the
current calls at 395.44 seconds; the clean collapse 2.1.8 run measured 396.02
seconds. The current provider does not call collapse, so the version change
neither fixes nor causes this cost.

Current cost increases as identical membership headers accumulate:

| pulse segment | pulses | total seconds | median ms/pulse |
| --- | ---: | ---: | ---: |
| 1-40 | 40 | 15.50 | 390 |
| 41-189 | 149 | 63.50 | 420 |
| 190-379 | 190 | 93.54 | 490 |
| 380-757 | 378 | 223.48 | 590 |

## What this establishes

The remaining full-fold cost is not a ragged-universe effect. The fixture is a
complete rectangle with a constant member set, constant status, constant
lifetime, no holdings, and no executions. Yet the provider spends 6.6 minutes
reconstructing 757 identical answers.

The mechanism is visible in production source and exercised here. At every
pulse, membership resolution filters and sorts all applicable headers and
rescans the 30,300-row membership table once per applicable header. Status,
lifetime, and terminal-event resolution each loop over the 505-member axis and
subset fact data frames again. The latter alone creates
`757 * 505 * 3 = 1,146,855` per-instrument resolution passes.

This independently agrees with the completed writer spike. Its profiled
columnar run spent 82.7% of in-loop samples in provider resolution and took
506.98 seconds in `t_loop`; this direct probe consumes 396.02 seconds in the
provider alone. The older peer benchmark's durable canonical engine completed
a different 500-instrument by 1,260-session workload in 86.58 seconds. That is
context, not a direct ranking, but it confirms that the provider layer, not the
base fold, is now the performance discontinuity.

## What the next Charter may consume

- The prerequisite answer is **PREPARATION_REQUIRED**. Repeated data-frame
  reconstruction dominates the corrected availability path at full scale.
- Preparing primitive vectors before the fold exposes ample headroom. The
  0.0036-second floor is not a performance promise because it omits compilation
  and changing-fact semantics.
- The comparison should remain two arms: current production provider versus
  one prepared provider built from keyed primitive arrays or matrices and
  monotone change cursors. collapse operations may be implementation details,
  not a third arm.
- The current arm need not be rerun repeatedly at 757 pulses: 396.02 seconds is
  now the registered provider-only reference on this fixture.
- The Charter must make point-in-time semantics, not this static cache, the
  acceptance burden: late knowledge, changing complete and partial membership,
  status precedence and supersession, lifetime and terminal events, held
  non-members, decision and execution views, and deterministic arbitrary-cutoff
  behavior.

## What remains open

Compilation cost and memory; the correct primitive representation; whether a
monotone cursor needs an explicit random-access fallback; semantic parity once
facts change; non-flat execution behavior; durable reopen; and the full-fold
wall and working-set result after provider replacement.

## Handoff

**READY_FOR_INDEPENDENT_PROVIDER_CHARTER.** The Seed v2 author must not write
that Charter. Stop here until a different author writes it and it passes the
two pre-execution structural reviews required by `spike_protocol.md`.
