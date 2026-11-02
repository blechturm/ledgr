# Cut 7 Strategy-Authoring Pre-acceptance Probe

Purpose: answer the three bounded input questions required by the independent
Cut 7 review before accepting the implementation cut. This is diagnostic
evidence over the unchanged product at `14252ffb`; it implements nothing.

Run from the repository root:

```powershell
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" `
  dev/bench/v0_2_3_strategy_authoring_preflight/probe.R
```

Environment: Windows 11 x64, R 4.6.1 ucrt, DuckDB 2.0.0. The governance-only
head was `558d7eea`; its product tree is identical to `14252ffb`.

Recorded output:

```text
CUT7_PRE_ACCEPTANCE_PROBE
product_source=14252ffb;governance_only_head=558d7eea
ROUNDTRIP numeric error;class=ledgr_config_non_finite;message=canonical_json() does not allow non-finite numeric values in config (Inf/-Inf/NaN).
ROUNDTRIP integer ok;decoded_type=list;decoded_names=A|B;missing_is_null=TRUE
ROUNDTRIP logical ok;decoded_type=list;decoded_names=A|B;missing_is_null=TRUE
ROUNDTRIP character ok;decoded_type=list;decoded_names=A|B;missing_is_null=TRUE
ROUNDTRIP whole_double ok;decoded_type=list;decoded_names=A|B;missing_is_null=FALSE
RESUME full_three_start_idx=4;sparse_three_start_idx=2;full_finalization_only=TRUE;sparse_finalization_only=FALSE
CALLS pulses=5;context_builds=5;state_encodes=5;strategy_state_rows=5
```

The result confirms all three premises behind the revised cut:

- canonical config JSON is not a declared-state codec: numeric missing values
  refuse, the other missing values lose their atomic positions, and named
  vectors return as alphabetically ordered lists;
- sparse state-change rows cannot double as the durable progress cursor: after
  three completed pulses they resume at pulse two instead of four, and after a
  completed fold they fail to enter finalisation-only resume;
- the current unchanged-state public run builds one context, serializes state
  and writes one strategy-state row for each pulse.

Therefore Cut 7 must use an explicit declaration-driven state codec and must
retain one lightweight cursor record per completed pulse. Option A removes the
unchanged-state payload encode, not the resume cursor. The future split
progress/checkpoint architecture remains parked in `inst/design/horizon.md`.

## Limitations

The round-trip and resume probes call internal functions on synthetic
`strategy_state` rows. Only the call-count arm is a public run, and its
frame-based encode counter is exact only for this no-fill fixture. The
`.libPaths()` line is host-specific. The script measures whatever tree it
loads; this is input evidence for product source `14252ffb`, not product
acceptance evidence for the later implementation.
