# Closeout: Terminal Disposition Policy Spike

**Status:** GREEN under Charter section 1: one configured
last-permissible-mark disposition let the public availability run finish,
resume and reopen while preserving an explicit approximation record.

## What Ran

The runner copied tracked source to scratch and inserted one option-controlled
branch before the existing terminal stop. The branch reused the production
FIFO lot kernel and event writer. Provider, valuation, strategy, finalization,
result reading and reopen remained on their ordinary paths.

Five cases ran: strict control, current mark, allowed stale mark, no
permissible mark, and interruption followed by resume. The checker reproduced
both CSVs byte-for-byte, gutted the branch, verified the exact fields that
changed and found package scope unchanged.

## Result

Current and one-session-stale cases reached `DONE`. Each emitted one sale and
one approximation diagnostic, sold two units at 100, moved cash from 1000 to
1200 and left the position at zero. The diagnostic persisted current versus
stale mark source, age zero versus one, position before and after, event
sequence and `last_permissible_mark_v001`.

The resumed case first returned `RUNNING`, then emitted the disposition once
and reached `DONE`. Its run, completion, diagnostic, ledger and equity
surfaces matched the uninterrupted case exactly after run and event identity
fields. All recorded cases that reopened reproduced events, equity and
diagnostics exactly.

Strict mode and the no-permissible-mark case stayed `INCOMPLETE` with
`terminal_settlement_unsupported`, no sale and no approximation row. The
prototype therefore did not need to invent a price.

## What The RFC May Consume

- A configurable terminal disposition is mechanically a bounded policy over
  existing FIFO accounting, not necessarily a new accounting primitive.
- A permissible current or stale valuation can close the holding and preserve
  normal resume, finalization and reopen behavior.
- The approximation must remain visible even when strict and modeled terminal
  equity happen to be numerically equal.
- The prototype `SELL` proves mechanics only. It does not establish the public
  event vocabulary or imply broker execution.

## Limitations And Finding

The fixture is one long holding, one terminal event, zero fees and constant
prices. It says nothing about shorts, multiple simultaneous terminals, model
defaults, bar-vintage identity or vendor settlement terms.

When the checker gutted the disposition, the resumed run correctly reverted
to `INCOMPLETE`; reopening that deliberately incomplete resumed run then hit
the previously known exact-equity-prefix validation defect. The normal
disposition path did not hit it and reopened exactly. This spike authorizes no
repair.

No production code, test, contract, ticket or release decision changed.
