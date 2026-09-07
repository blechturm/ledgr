# W14 Fixture: Full-Train Fit Used In An Early Training Replay

- Witness: `W14`; class: `semantic_oracle`; policy v4.
- Purpose: a transform fitted on the whole training window is requested by
  an early decision inside that window. Causal mode rejects the unavailable
  artifact; retrospective in-sample mode may use it only with an explicit
  label that bars an out-of-sample interpretation.
- Cases: `c1` causal mode; `c2` retrospective in-sample mode.

## Asset And Calendar

`A01` (alias AAA), member and listed throughout, status active. Training
window sessions S1 to S9 (venue XSYN, closes at 21:00:00Z):

| session | date | close |
| --- | --- | --- |
| S1 | 2024-01-02 | 100.00 |
| S2 | 2024-01-03 | 101.00 |
| S3 | 2024-01-04 | 102.00 |
| S4 | 2024-01-05 | 103.00 |
| S5 | 2024-01-08 | 104.00 |
| S6 | 2024-01-09 | 105.00 |
| S7 | 2024-01-10 | 106.00 |
| S8 | 2024-01-11 | 107.00 |
| S9 | 2024-01-12 | 108.00 |

All closes are accepted at their close times. No positions.

## Fitted Transform

- Recipe `center_v1` over the full window S1 to S9; population `A01`.
- Fit cutoff and artifact availability time: S9 close 2024-01-12T21:00:00Z.
- RNG identity `fixed:20240112`.
- Fitted mean `(100 + 101 + ... + 108) / 9 = 936 / 9 = 104`.

## Replay Decision

The S2 decision (2024-01-03T21:00:00Z) requests the transformed value of the
S2 close.

## Derivations

- `c1` causal mode: the artifact becomes available at 2024-01-12T21:00:00Z,
  after the S2 decision; the request is rejected with
  `artifact_not_available_at_decision`; no transformed value; the candidate
  stops at that decision with the same reason (an unsupported causal claim
  fails rather than being implied).
- `c2` retrospective mode: the artifact is used with label
  `retrospective_in_sample` and `oos_interpretation_barred` true; transformed
  value `101 - 104 = -3`.

## Identity Expectations

The fitted artifact identity is the same object in both cases (`equal`);
the mode label is part of the evidence, not of the artifact.
