# WS25 restart and decoder checkpoint

Source boundary: Cut 11, LDG-3206 and LDG-3207. This checkpoint is not the
Workstream 25 closeout; LDG-3208 and LDG-3209 remain pending.

## Fresh-attempt boundary

`strategy_state` is no longer a durable table. Declared asset and portfolio
state remain typed fold-local values and still reset at each walk-forward test
run. There is no pulse cursor, state codec, restore reader or
`ledgr.interrupt` soft stop.

A call for a nonterminal run first passes the ordinary identity, snapshot and
terminal-evidence checks. The restart boundary then replaces the prior
attempt's ledger, equity, diagnostics, telemetry and completion rows and posts
opening positions once in the same transaction. The fold starts at pulse one.
DONE and INCOMPLETE rows keep their terminal early-return behavior, while
completion-publication recovery remains strategy-free. A real R interrupt
still unwinds the fold transaction and records FAILED.

`checkpoint_every` remains part of configuration and controls event-buffer
flushing. It makes no pulse-durability promise.

The registered deletion census is LTB-0555/LCL-0544. Behavioral witnesses are
LTB-0198, LTB-0202, LTB-0207, LTB-0245, LTB-0534 and AT8. Old tests that read
the retired table are migrated to observe typed state in the live callback;
tests whose only assertion was continuation from a cursor are retired because
that behavior is the removed product contract.

## Logical diagnostic boundary

`ledgr_diagnostic_decode()` is the sole logical trace reader. It supports run,
stage, outcome, reason, instrument and bounded-time filters in SQL before
materialization. The current LDG-3207 representation remains all-explicit, so
the decoder result is byte-for-byte the physical trace after the established
sizing empty-to-missing projection.

Result diagnostics, explanations, valuation and corporate-action summaries,
completion validation, assumption flags, sizing summaries, diagnostic-presence
queries and next-sequence queries use that boundary or decoder-owned exact
summaries. The fills reader no longer reads diagnostics: its recording pulse is
derived from the typed fill time and the unique declared session axis. No
logical read invokes strategy, indicator, risk or cost code, and no read writes
the store.

LTB-0554/LCL-0543 owns the full and bounded decoder, the no-callback witness
and the source census. LTB-0210 owns fill/session association and ambiguity.

## Identity and format at this checkpoint

Removing `strategy_state` changes the current schema catalogue and therefore
the store fingerprint. Run and snapshot identity rules do not change. The
diagnostic codec binding and final catalogue are deliberately not added here;
LDG-3208 and LDG-3209 own the one final current-format boundary.

