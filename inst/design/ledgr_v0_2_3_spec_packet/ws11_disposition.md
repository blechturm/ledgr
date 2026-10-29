# WS11 disposition: RNG reproducibility and cheap pulse seeds

**Role:** record; workstream 11 disposition for v0.2.3 cut 4 (LDG-3161).
**Status:** draft, awaiting the workstream close review.
**Authority:** `tickets.yml` cut 4, decisions (1)-(17), and LDG-3155 to
LDG-3161; the design note [ws2_rng_design.md](ws2_rng_design.md), Sections 7
and 8.

## Outcome

Seeded folds, both simulators and mirai workers pin the
Mersenne-Twister/Inversion/Rejection kind. Store writes keep the caller's
`.Random.seed`. Every exported entry point restores the caller's RNG kind and
state. Pulse seeds come from rule v2, computed once per fold. Old-rule
candidates, configurations and stores are refused. `ledgr_walk_forward(seed =
NULL)` works.

Final candidate: `a19f7f23a68e6ed3b147a1bbb532f5bcd3218f97`. Its product
digest is `44a82e00f12744f54c47ab3c1a2fe98dbe4da1dec3cbd7cefd16f187b30ed9db`
(sha256 over the git object ids of R, src, tests, man, vignettes,
DESCRIPTION and NAMESPACE;
[final_candidate.csv](../../../dev/bench/v0_2_3_cut3_successors/final_candidate.csv)).

## Identity declarations (cut decision (7))

Measured by
[identity.R](../../../dev/bench/v0_2_3_cut3_successors/identity.R) against
the cut base `3a67db60`; 19 checks pass
([identity.csv](../../../dev/bench/v0_2_3_cut3_successors/identity.csv)).

| Axis | Declaration | Hash evidence (base -> candidate) |
| --- | --- | --- |
| Snapshot content identity | unchanged | snapshot hash `b54a78e3c666...d515d4` on both; content hash rule 4 and identity rule 4 on both |
| Seeded run configuration | changed: `engine` gains exactly `pulse_seed_rule = 2` | config hash `a64da03069f9...5894574c` -> `91229b23572f...a317f72`; generated run id `run_c2972ecc9472b4d8` -> `run_e9c5c0be332eabfa` |
| Unseeded run configuration | unchanged | config hash `5946f113bd75...dcd8d2b5` and run id `run_ddacac4bf6b7b5b3` on both |
| Store format fingerprint | changed by one constant | bindings 27 -> 28, the only change `ledgr_pulse_seed_rule_version = 2L`; fingerprint sha256 `4943b947668e...19fc5731` -> `4b5019005fdf...b74b4b53` |
| Candidate markers | sweep `seed_contract` v1 -> v2; candidate `execution_seed` unchanged | `ledgr_seed_v1` -> `ledgr_seed_v2`; seed `344820648` on both; A0 A1/A2 rows |
| Old stores | refused | a store written by the base: `ledgr_store_rebuild_required`, cause `fingerprint_mismatch`, differing constant `ledgr_pulse_seed_rule_version` |
| Old candidates | refused before a run is created | a base sweep candidate: `ledgr_seed_rule_mismatch`, no run row |

## Successor oracles and guts

Both successors are recorded under
[v0_2_3_cut3_successors](../../../dev/bench/v0_2_3_cut3_successors/). They
call the unchanged original harnesses. A fresh rerecord on the final product
is byte-identical to each committed successor.

- **A0** passes 295 checks:
  - D17 adds exactly the `wf_folds.selected_at_utc` exclusion (decision (17));
  - A1 covers 14 files, A2 14 and A3 11, and the 2 unseeded run dirs are
    identical;
  - A4 and A5 equal a pulse-rule model built on `aa2931e9` with an
    independent bit-level v2 reference, at exactly the note's row counts;
  - 224 files are identical.

  The original A0 checker's 52 failing files are exactly the files those
  predicates attribute.
- **RNG baseline** passes 26 checks:
  - the Section 8.2.1 census schema, copy rows and expected-call ledger hold
    exactly;
  - worker agreement holds with 33/36/39 trades equal to the model;
  - `caller_rng` changes only in rows 01, 05, 09, 13 and 15;
  - `store_rng` holds the frozen values;
  - `detection_gap` is identical.

  The original RNG checker stops at the deleted scalar helper, as expected.
- **Guts** run on source copies that the workers load. The control fails
  nothing; R1-R7, R8v, R9 and R10 each fail their named predicates with 0 errors.
  R8 as written is blocked by the shipped validator, which refuses before
  any run row exists; it is kept as validator evidence. R8v, the same
  omission with the validator check reverted, is the A3 gut. The session
  lead accepted it under the maintainer's standing direction, 2026-10-29.
- **Golden tables:** 63 of 63 rows match on Windows (R 4.6.1 ucrt) and on
  Linux (WSL Ubuntu 24.04.4, R 4.6.0), with identical integers.

## Timing (protocol ws2-timing-1)

The gate record
[gate-final/attempt-1](../../../dev/bench/timing/records/ws2-timing-1/gate-final/attempt-1/session.csv)
passes `check.R` (CHECK PASS). It compares base `3a67db60` with candidate
`a19f7f23` over eight alternating pairs, 160 fresh processes. The window ran
from 21:26 to 22:09 UTC, under the High performance plan with affinity
0xFFFF, and the inputs were verified at start and end.

- Seeded dense cells, bound 0.97: run 0.929 and sweep 0.907.
- Seeded timing_scale cells: run 0.963 and sweep 0.958.
- Stochastic cells: run 0.957 and sweep 0.945.
- Unseeded cells: 0.991 to 1.005, all within 1.03.

On the normal desktop, sampled host CPU averaged 5.2% (maximum 28%). The
busiest processes were Chrome, TotalMixFX, Snagit and Positron. Two idle
Rscript processes from another session were present throughout.

## Open points

- **LTB-0269 census relocation:** LDG-3160 ran focused tests only. Its
  roxygen lines moved the census literal in `R/sim-pit-inputs.R` from line
  317 to 320. The fixture was relocated in the final candidate. The test's
  scanner finds the same 17 literals with identical text, and the test is
  unchanged.
- **R CMD check NOTE:** `head` in `ledgr_history_bar_mask_view` has no
  `utils` import. This is pre-existing and also recorded in
  [ws1_disposition.md](ws1_disposition.md).
- **Protocol history:** `ws2-timing-1` was edited twice before its first
  valid record, by maintainer direction: `0de48f7f` lengthened its short
  cells, and `5638b490` moved its store into the harness's per-slot work
  directory. Both earlier base attempts (`base-aa` attempts 1 and 2) were
  invalid and are kept with their dispositions. The valid base (attempt 3)
  and the gate use identical frozen inputs. The manual's rule that a
  protocol is never edited after its first record stays as written.
