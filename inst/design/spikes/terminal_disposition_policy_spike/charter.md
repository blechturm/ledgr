# Charter: Terminal Disposition Policy Spike

**Status:** Executable charter; binds nothing.
**Author:** Codex. **Date:** 2026-09-23
**Protocol:** `inst/design/spike_protocol.md`
**Feeds:** the equity-settlement RFC after seed v5.

## 1. Question

> Can an availability-aware public `ledgr_run()` replace the current terminal
> stop with one configured last-permissible-mark disposition, finish normally,
> survive interruption and reopen, and report the approximation explicitly?

That is the only question.

## 2. Cheaper Prerequisite

Can one scratch-only seam at the existing terminal-stop branch apply an
ordinary FIFO sale, persist its event and diagnostic, and leave all later fold
work on the production path?

The first runnable case is the existing strict behavior. If the alternative
needs more than that one seam, the premise fails and the spike stops.

## 3. Fork

The runner copies tracked source to scratch and inserts one option-controlled
branch immediately before `terminal_settlement_unsupported`. The branch may
use existing lot accounting and event writing only. It may not replace the
provider, valuation, strategy, finalizer, result readers or reopen path.

The prototype event is an ordinary zero-fee `SELL`. That is a feasibility
device, not a proposed settlement vocabulary or execution claim.

## 4. Cases

The runnable fork will generate cases from these input shapes; expected
answers are not frozen until it has run:

- strict mode at a terminal pulse;
- configured disposition with a current permissible mark;
- configured disposition with an allowed stale mark;
- configured disposition with no permissible mark;
- interruption before the terminal pulse followed by resume and reopen.

## 5. Evidence

Evidence comes from public runs and persisted surfaces: terminal status,
completion reason, ledger events, fills, equity, diagnostics and reopened
results. The approximation row must state quantity, price, mark source, age,
position before and after, and a policy identifier. Narrated fixture values
are labelled and excluded from pass counts.

## 6. Kill And Recharter

Stop if the alternative needs more than the single terminal-branch seam or
requires a change outside the scratch fork. That means disposition is not a
bounded policy over the existing accounting primitives.

## 7. Deliverables And Gut

Exactly three executor deliverables:

- `spike_runner.R`, writing one CSV row per case plus parity evidence;
- `spike_checker.R`, rerunning, byte-diffing and guarding package scope;
- `spike_inventory.md`, naming what was demoted, deleted and learned.

The gut disables the disposition branch. The current-mark and resumed cases
must revert to the terminal stop, lose the sale and approximation diagnostic,
and change equity. Merely changing bytes is insufficient.

The closeout is the protocol's one-page terminal record.

## 8. Non-Goals And Budgets

No policy API, default, event vocabulary, vendor decoding, corporate-action
semantics, census claim or release scope is bound. Harness: 1,500 R lines;
single correction: 500 lines; charter: 150 lines; closeout: one page. An
overrun stops the spike.
