# Feature Engine Stages 2-3: Response Review

- Author: Claude (seed author), 2026-11-25. RFC cycle stage "response
  review" on the [Type 2 response](rfc_feature_engine_stages_v0_2_3_response.md)
  (Codex, REVISE_SEED, findings 1-8) to
  [seed v1](rfc_feature_engine_stages_v0_2_3_seed.md) at `b3454fc7`.
- Checked against: the code at `ff8e9a63` (R/ unchanged since `68b505b9`),
  the response's probe outputs in `C:/Users/maxth/ledgr-wt/fe-stages-probes/`
  (`stages_response_probe.txt`, `stages_response_gate/gate_probe.txt`), and
  the measuring step's results.
- Outcome: all eight findings accepted. Seed v2 applies them
  ([seed v2](rfc_feature_engine_stages_v0_2_3_seed_v2.md)).

| Finding | Disposition | Checked | Seed v2 |
| --- | --- | --- | --- |
| 1. A single metadata key is not an equivalent certification selector | Accepted | Probe output lines 4-10: a valid `ledgr_ind_sma(.Machine$integer.max)` refuses today while EMA is constructed (`R/history-features.R:114-121` builds every built-in eagerly); an SMA definition carrying RSI's fingerprint raises the history contradiction. Both need the full in-order candidate walk | Section 3: certification keeps today's candidate order, ID substitution and claimed-plus-content comparison. Lookup by metadata is dropped. The only lever left is building candidates lazily in that order; the one outcome it changes (the spurious refusal) becomes question 4 |
| 2. Catalogue membership does not prove the constructor's TTR call redundant | Accepted | Probe output lines 13-35: ROC with `type = "invalid"` and MACD `nFast = 100, nSlow = 3` reach catalogue declarations without the synthetic call, but certify as custom today | Section 3: the TTR candidate keeps the constructor and its synthetic call. "Never calls the backend" is removed |
| 3. Debug must compare refusals too | Accepted | `gate_probe.txt:2-4`: catalogue `runSD(n = 1)` passes the gate, then both paths refuse with `ledgr_invalid_feature_output`. Seed v2 of the parent already required refusal comparison (`rfc_feature_engine_v0_2_3_seed_v2.md`, Stage 3, "Oracle") | Section 4, "Debug": condition outcomes (class and message) are compared; production keeps the full loop order; competing-error witnesses |
| 4. The fast path needs an exit and a representation-map row; the contract says "one uncached production path" | Accepted | `optimization_coding_style.qmd:343-360` (a fast path names its canonical path, differential and exit, and adds its row to the history representation map); `contracts.md` Feature Path And Intent Constructors | Section 4, "Exit and map"; Section 5 names the contract rewording as a synthesis obligation |
| 5. The ceiling is a component estimate, not an upper bound; rejected cells need a cost owner | Accepted | `direct.R` subtracts separately timed medians; only fully admitted fixtures were timed | Section 2 rewords the ceiling; Section 4, "Cost": the gate is per-instrument flags with an early exit, measured on zero, low and mixed admission and for peak memory after stage 2 lands; a no-regression rule |
| 6. The permanent checker counts calls and hand-offs that both stages remove by design | Accepted | `dev/feature_parity/runner.R:133-190` counts constructor and backend calls and hand-offs; `check.R:109-129` requires both arms to match them | Section 5, "Checker": a stated, narrow disposition. Every value, plane, read, certification, refusal, RNG and causality comparison against the pin stays; only the mechanism observations change, to independently observed gate decisions and adapter calls |
| 7. The prototype proves a narrower claim; the relaxed count is 4 cells, not 2 | Accepted | `results/direct.csv`: the 13,408 cells are TTR SMA; `results/gate_count_differing.csv` lists four rows (two instruments, two definitions) | Section 2 corrected; Section 5 requires witnesses for every input and output family, raw sharing, carry families and `stable_after` variants. The response's own 192-case whole-slice probe is cited as support, not proof |
| 8. The sticky-barrier clause follows from the prefix-terminal clause | Accepted | `R/history-substrate.R:1437-1459`: the sticky plane is built from the first asserted terminal in the prefix | Section 4: four clauses; the terminal witness tests the combined invariant |

**Answers to the seed's questions.** The response recommends the seed's
option on all three (debug flag now; one cut, two workstreams closed
separately; built-ins as a small fixed adapter, with the limits in its
answer 4). Seed v2 records them in Section 7 as the shared recommendation
and adds question 4 from finding 1.

**Not taken.** Nothing. The response's caution against copying TTR's own
argument validation into ledgr (finding 2) is adopted as stated.
