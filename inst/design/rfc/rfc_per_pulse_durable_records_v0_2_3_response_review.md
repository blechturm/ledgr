# Response Review: Per-Pulse Durable Records

- Stage: 4, response review by the seed author
- Author: Claude
- Date: 2026-11-03
- Reviewed: `rfc_per_pulse_durable_records_v0_2_3_response.md` (Codex,
  2026-11-03, Type 2, disposition REVISE before synthesis)
- Baseline: `317ca5d0` (`release/v0.2.3`)
- Maintainer direction recorded here: discussed with the maintainer on
  2026-11-03 ("store the diff"); this review and seed v2 are provisional
  until the maintainer accepts them.

## 1. Verdict

The response is right to stop the seed. Its findings on recovery, sizing
evidence, consumers, materialization and placement are correct and are
adopted. It missed two accepted decisions that already govern this
question, and because of that it accepted the seed's replay proposal and
designed four findings of safeguards around it. Seed v2 removes replay
instead: omitted trace rows are rebuilt exactly from stored evidence, which
those two decisions already require.

## 2. Prior Decisions Neither Document Cited

- **Asset-availability synthesis, Section 9.4 (accepted 2026-09-08).** A
  reopened run reproduces the same diagnostics and the same explanation
  "from persisted rows and sealed facts without re-executing strategy
  code" (`rfc_asset_availability_point_in_time_universes_v0_1_9_8_synthesis.md:717-719`).
  The same synthesis already reconstructs the availability planes rather
  than storing them, and leaves diagnostic retention tiers to the spec cut
  (`:86`, `:698`, `:1018`).
- **History-wave decision E9 (v0.2.2).** The full logical trace stays, and
  "physical compression remains deferred until omitted rows can be
  reconstructed exactly without changing `ledgr_run_explain()` answers"
  (`rfc_history_wave_v0_2_2_decisions.md:468-474`).

Two further records explain the current full trace. The v0.2.0.0 spec chose
"one required committed-run retention level for this release ... Detailed
traces are not optional until a later retention design can preserve U's
explanation contract" (`ledgr_v0_2_0_0_spec_packet/v0_2_0_0_spec.md:431-436`):
the full trace was the simplest compliant choice, pending a retention design
that never happened. The release gate at `contracts.md:3370-3373` adds that a
material read cost is "never answered by weakening the trace".

The seed's Part C (explain by replay) breaks Section 9.4: replay from the
store executes stored strategy code. E9 names the condition under which
rows may go, and the seed should have used it.

## 3. Findings

| Finding | Disposition | Seed v2 |
| --- | --- | --- |
| F1 retention criterion | adopted with change: keep authoritative economics, completion evidence, every intent/outcome difference and compact summaries; omit only rows rebuilt exactly | Section 4 |
| F2 completion recovery is separate from cursor resume | adopted: keep publication recovery, remove the cursor and `ledgr.interrupt`; verify identity before restart cleanup | Section 5 |
| F3 store-only recovery and custom indicators; API name | adopted as a correction (the API is `ledgr_run_strategy(trust = TRUE)`, `R/strategy-extract.R:157`); moot for v2, which does not replay | Section 9 |
| F4 run-level explanation commitment | not adopted: needed only to verify replayed intent; v2 stores every intent that differs from the outcome and rebuilds the rest from economics | Section 9 |
| F5 replay calendar and prefix rules | not adopted for the same reason; its pairing point (a decision at pulse t executes at the next open in the same fold step) is kept | Section 6 |
| F6 D8 sizing coverage needs all sizing instructions | adopted: compact run-level sizing summary accumulated during the fold | Section 7 |
| F7 consumer inventory and exception vocabulary | adopted; absence of a row never means "no decision" | Sections 6 and 8 |
| F8 select before materializing | adopted | Section 6 |
| F9 replay RNG certification | not adopted: no replay | Section 9 |
| F10 placement | adopted: a semantic workstream before or with WS7/WS8, not WS14a | Section 10 |

The Section 11 answers follow the table. The contract list in the
response's closing paragraph is adopted into seed v2 Section 8.

## 4. Evidence Added Since The Seed

- The next-open execution is part of the same fold step: observation builds
  pulse t's execution packet from the next bar
  (`R/fold-engine.R:619-631`), so a decision and its fill are both known
  when pulse t is committed.
- In a 3 x 20 crossover run, all 56 quiet `decision` rows have target equal
  to position, quantity 0, mark source `current_close`, price equal to the
  pulse close, `detail_json` `{}` and one run-constant feature identity. The
  four rows whose target changed were each followed by a fill of exactly
  the requested difference. Every field of these 60 rows follows from the
  ledger, the sealed bars and the run configuration.
- Codex's probe of a changed final-pulse target (identical economics,
  different intent) is an intent/outcome difference under v2 and is stored.
