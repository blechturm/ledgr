# Charter: History Correction-Chain Evidence Spike

**Status:** Executable charter; binds nothing.
**Author:** Codex. **Date:** 2026-10-16.
**Protocol:** `inst/design/spike_protocol.md`.
**Feeds:** history-wave H2 Session F and the consolidated v12 synthesis.

## 1. Question

> Which correction-chain shapes do ledgr's current fact constructor, snapshot
> seal, runtime resolver and ingest conflict classifier accept, refuse or
> interpret differently?

That is the only question. The spike records current behavior. It does not
choose a correction policy or authorize product changes.

## 2. Cheaper prerequisite

H1 checked the two available Sharadar captures first. They contain redates,
same-key changes and one hard-coded terminal replacement, but no empirical
trading-status correction chains. More inference from those captures cannot
answer Session F. The cheaper remaining input is therefore a vendor-neutral
synthetic matrix over the existing public fact and run surfaces.

## 3. Runnable core

The core has nine cases, below the protocol's ten-case cap:

1. one direct, full-coverage replacement;
2. a monotone three-link chain;
3. the same chain learned out of order;
4. two competing descendants;
5. a partial replacement that may revive its predecessor;
6. a replacement extending beyond its predecessor;
7. a dangling reference;
8. a cycle; and
9. a chain plus a competing sibling.

Each case first uses `ledgr_facts_trading_status()`. Cases accepted there use
`ledgr_facts_validate()`, `ledgr_snapshot_from_df()`, `ledgr_experiment()`,
`ledgr_run()` and `ledgr_results(..., "availability")`. Only cases that the
public constructor refuses use the current private prepared resolver, because
no public status-resolution inspection surface exists. The private
`ledgr_status_runtime_conflicts()` result is recorded for every case to compare
the ingest classifier with runtime behavior.

## 4. One gate

GREEN means the spike produces a deterministic, diffable map that:

- distinguishes public refusal from resolver behavior that is unreachable
  through the constructor;
- exposes every registered D2-F1 through D2-F3 disagreement with at least one
  case; and
- leaves no tested case without an observed constructor, classifier and
  runtime-or-private-resolver outcome.

The result may be GREEN while product semantics remain undecided. GREEN means
only that H2 has adequate empirical input.

## 5. Kill condition

Stop and return to the maintainer if more than ten cases are needed, if the
matrix needs a second fact model, or if observing an accepted case would
require changing package code. A private read is allowed only for the
unexported status resolver or classifier and must be labelled as such.

## 6. Deliverables and gut

The runner writes raw case, timeline and classifier CSVs plus one derived
disagreement CSV. The checker reruns in scratch, diffs those files and guards
package scope. The gut removes supersession edges before private resolution;
the checker must reject the changed timeline. `inventory.md` records the gut,
demotions and package findings. `closeout.md` is the one-page terminal record.

## 7. Containment

No product code, tests, contracts, tickets, decision register, macro plan or
public API changes. No vendor or private data. Results are structural behavior,
not prevalence or ranking evidence.
