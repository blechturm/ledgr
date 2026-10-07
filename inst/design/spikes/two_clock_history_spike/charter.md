# Charter: Two-Clock History Spike

**Status:** Draft charter, written by Claude at the maintainer's request on
2026-10-07 and revised after peer review on 2026-10-08; awaiting maintainer
acceptance. Binds nothing.
**Protocol:** `inst/design/spike_protocol.md`
**Probe:** `dev/spikes/two-clock-history/probe_findings.md` (run at `9452e9e`)
**Feeds:** accepted synthesis v11 section 7, parts (a) semantic evidence and
(b) two-clock representation, before the WS3 history interfaces are fixed.

## 1. Question

> Can one representation, prepared once before the fold, answer "the fact
> state applicable at historical day `s`, as knowable at decision day `t`" for
> trading status, membership (snapshots and intervals) and lifetime, by
> applying the existing resolution rules unchanged to the facts effective at
> `s` and knowable at `t`, without callback-time SQL, a second resolver or
> portfolio replay?

That is the only question. Numerical feature revision (v11 section 7(d)),
carry, missingness and the history API are not asked. Sessions and corporate
actions also carry knowledge times; they are out of scope here and stay open
(section 8).

## 2. Cheaper Prerequisite

> On the probe fixture, does choosing the applicable facts by both clocks
> (effective at `s`, knowable at `t`) and handing them to the unchanged
> production resolution rules give the answers v11 section 3 demands, while
> keeping knowledge time in each family's ordering?

The probe already shows part of the answer. Re-timing facts makes trading
status and lifetime come out right, but the membership constructor refuses,
because knowledge time is part of how a membership correction is identified
and ordered (probe P2). The prerequisite therefore keeps knowledge time as a
key and filters on it; it never rewrites it.

If the prerequisite needs any change to a resolution rule, the spike stops:
the question is semantic, not representational, and returns to the maintainer
as a v11 amendment question.

## 3. Fork

The runner copies tracked source to a scratch directory and adds one
spike-only function beside the prepared provider. It may not edit the
provider, the fold, the facts constructors or any resolver.

The single candidate representation is **bitemporal segments**. For each
instrument (and each membership universe), every segment carries an effective
interval, a knowledge interval `[known_from, superseded_from)` and the
resolved state. A segment is written once, when an epoch changes its answer;
unchanged segments carry their knowledge interval forward. A query `(s, t)`
picks the segment whose effective interval contains `s` and whose knowledge
interval contains `t`, reusing the existing resolution rules to compute each
segment's state at build time.

This is one plausible representation, not a comparison. If it fails, the
closeout says why; no second candidate is built in this spike.

## 4. Cases

The fork generates the cases from these input shapes; expected answers are
frozen only after it has run, in git, with the reviewer named:

1. the probe's retracted halt, at `(4, 5)`, `(4, 8)` and `(5, 9)`;
2. a supersession chain: a fact superseded at day 5 and again at day 8;
3. a precedence tie between sources whose facts become known on different
   days;
4. the probe's membership snapshot correction, at `(3, 5)` and `(3, 8)`;
5. a late-known membership interval (not exercised by the probe);
6. an incomplete membership snapshot later completed, so completeness is
   tested and not only `complete = TRUE`;
7. the probe's late-known lifetime fact (late knowledge only; the tried
   lifetime correction is refused at construction, probe P3);
8. the diagonal: `(d, d)` for every session must equal the shipped provider.

Eight shapes, within the protocol's cap of ten cases.

## 5. Evidence

The runner writes one CSV row per case and `(s, t)`: the fork's answer, the
shipped provider's answer at `s`, and the facts that decided it. Every row is
derived by running the fork over sealed facts built with the public
constructors; narrated literals are labelled and excluded from counts.

It also records, per family, as shape facts only: facts, revisions (facts
that change an earlier answer), segments written, and bytes, against the
shipped diagonal representation; and how many cursor seeks one window read of
`k` historical columns costs at one pulse, since the shipped cursor re-seeks
when a cutoff goes backwards (`R/availability-provider-prepared.R:14-15`).

## 6. Kill And Recharter

Stop and return to the maintainer if any of these happens:

- the prerequisite needs a change to a resolution rule (section 2);
- the representation needs fact filtering or SQL per query rather than once
  before the fold;
- segments written exceed a constant multiple of facts plus revisions on any
  case, so its size is not bounded by the facts;
- a correct answer needs a lifetime revision rule the constructors refuse.

## 7. Deliverables And Gut

Exactly three executor deliverables, under `dev/spikes/two-clock-history/`:

- `spike_runner.R`, writing the case CSV and the shape table;
- `spike_checker.R`, rerunning into a scratch directory, diffing against the
  recorded CSVs and guarding package scope (`R`, `src`, `tests`, `NAMESPACE`,
  `DESCRIPTION`, `man`, `inst/design`);
- `spike_inventory.md`, naming what was demoted, deleted and learned.

The gut replaces the bitemporal lookup with the shipped diagonal. Cases 1, 2
and 4 must then fail on a named `(s, t)` row, and case 8 must still pass.
Merely changing bytes is insufficient.

The closeout is the protocol's one-page terminal record under
`inst/design/spikes/two_clock_history_spike/closeout.md`.

## 8. Non-Goals, Open Families And Budgets

No history API, prepared-panel layout for feature values, carry or
missingness policy, instrument-specific session narrowing, lifetime revision
rule, memory budget or performance ranking is decided here. The WS3 memory
budget is set separately by the maintainer.

Open and owned elsewhere: session calendars as known at `t` belong with the
session-axis and narrowing work (v11 section 4); corporate actions as known at
`t` belong with the carry-barrier implementation (v11 sections 5 and 7(c)).
Neither is discharged by this spike.

Budgets: charter 150 lines; harness 1,500 R lines; single correction 500
lines; closeout one page. An overrun stops the spike.
