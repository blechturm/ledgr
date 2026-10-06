# Feature-Map Read Surface Reconciliation

**Status:** Agent-provisional closeout for Cut 7 / Workstream 16.
**Authority:** Accepted feature-map read-surface synthesis.
**Implementation range:** `6ef9b19..HEAD` until the close commit is recorded.

## Ownership

Each accepted decision has one implementation owner.

| Rule | Owner | Detecting evidence |
| --- | --- | --- |
| D1 alias-first singular resolver | LDG-2962 | LTB-0183, LTB-0184 |
| D2 singular-only plane | LDG-2962 | LTB-0183, LTB-0139 |
| D3 explicit-map refusal | LDG-2963 | LTB-0185, LTB-0141 |
| D4 alias-keyed mapped wide views | LDG-2963 | LTB-0185 |
| D5 signal values, eligibility and origin | LDG-2962 | LTB-0183 |
| D6 parameterized inspection | LDG-2964 | LTB-0186, LTB-0112 |
| D7 actionable loop warnings | LDG-2962 | LTB-0102 |
| D8 run-local prepared ownership | LDG-2962 | LTB-0139, LTB-0140 |

The contract and teaching consolidation is owned only by LDG-2965 and is
detected by LTB-0187. The registered performance record is also owned only by
LDG-2965 and is checked by the record checker in
`dev/bench/v0_2_2_feature_map_read_surface/`.

## Contract Changes

| Synthesis Section 3 rule | Standing home | Owner | Detector |
| --- | --- | --- | --- |
| 1. Singular aliases or IDs | Strategy and Context contracts | LDG-2962 | LTB-0183, LTB-0187 |
| 2. Explicit-map read boundary | Context Contract | LDG-2963 | LTB-0185, LTB-0187 |
| 3. Mapped wide aliases | Context Contract | LDG-2963 | LTB-0185, LTB-0187 |
| 4. Signal semantics and origin | Strategy Contract | LDG-2962 | LTB-0183, LTB-0187 |
| 5. Parameterized inspection | Context Contract | LDG-2964 | LTB-0186, LTB-0187 |
| 6. Active bundle warnings | Context Contract | LDG-2962 | LTB-0102, LTB-0187 |
| 7. Prepared run-local resolver | Context Contract | LDG-2962 | LTB-0139, LTB-0140, LTB-0187 |

## Synthesis Section 4 Evidence

| Required witness | Owner | Detecting evidence |
| --- | --- | --- |
| Dense scalar, plane, bundle and signal parity | LDG-2962 | LTB-0183 |
| Availability restriction and empty axis | LDG-2962 | LTB-0183, LTB-0139 |
| Parameterized public run and pulse snapshot | LDG-2962 | LTB-0184 |
| Two-candidate sweep isolation | LDG-2962 | LTB-0184, LTB-0140 |
| Small walk-forward integration | LDG-2962 | LTB-0184 |
| Character and object explicit-map refusal | LDG-2963 | LTB-0185 |
| Long and wide mapped identity | LDG-2963 | LTB-0185 |
| Signal, error and origin parity | LDG-2962 | LTB-0183 |
| Parameterized inspection parity | LDG-2964 | LTB-0186 |
| Axis-sized warnings and output neutrality | LDG-2962 | LTB-0102 |
| Prepared lookup and no per-read normalization | LDG-2962 | LTB-0139 |
| Three-arm 500 by 1,260 clock and exact outputs | LDG-2965 | checked-in performance record |
| Workstream 11 five-pair no-regression gate | LDG-2965 | checked-in Workstream 11 record |

## Accepted Boundary And Routing

The surface remains singular. `ctx$vec$feature()` accepts an active alias or a
concrete feature ID; there is no `ctx$vec$features()` or selected-subset plane.
Explicit maps may introduce local names but cannot redefine a name already
owned by the active context.

The Strategy Callback Addendum's alias-map interaction and feature-map vector
output obligations are discharged by this cut. Its conditional
`ctx$feature_at()` shortcut remains in the strategy-callback follow-up route.
The feature-map RFC pipeline row was removed at ticket cut. The accepted-change
bridge in `decisions.md` remains until release closeout. Context-frame and
historical-projection planning link the accepted synthesis rather than
restating its naming design.

## Verification Record

The checked-in three-arm record under
`dev/bench/v0_2_2_feature_map_read_surface/evidence/accepted/` has exact
normalized fills, equity and strategy state across every arm. Its initial
triplet measured 35.24 seconds for the pre-cut bundle loop, 37.31 seconds for
the candidate bundle loop and 27.88 seconds for the candidate plane. Because
the candidate/pre-cut ratio was 1.059, the preregistered retry ran. The retry
measured 44.07, 45.10 and 28.21 seconds respectively: the plane/loop ratio is
0.625 and the candidate/pre-cut ratio is 1.023. Both gates pass.

The first ordinary Workstream 11 run exposed a real implementation defect:
availability rebuilt immutable alias and feature-name environments on every
pulse. `a1f9349` prepares that state once per run. The provenance-clean
five-pair record under `evidence/long_window/` compares accepted `6ef9b19`
with candidate `a473140`; its checker and self-test pass without a retry.
Cold ratios are 1.000 for `feature_gaps`, 1.034 for `fact_churn_terminal` and
1.045 for `availability_sweep`. Warm ratios are 0.994, 1.037 and 1.000. All
are within the existing 1.10 gate. A prior timing-equivalent run was rejected
because another session advanced the candidate commit during measurement;
its mixed provenance was not checked in.

The focused feature-map, accessor, warning, inspection,
documentation-contract and control-plane suites pass. The four named Quarto
articles reproduce their checked-in Markdown renders. The first final fast
run also exposed and caused correction of a claim registration error:
LCL-0187 promised `fast` while its file-level detector belongs to `review`.

The remaining blocker is the absolute ordinary fast timing gate. The final
committed tree executes all 530 blocks with zero non-passes, but its clean
three-run record at
`C:/Users/maxth/ledgr-research/.tmp/ledgr-ws16-final-fast-cool` is 122.41,
108.62 and 119.51 seconds. The 119.51-second median exceeds the unchanged
112-second bound. A same-host accepted pre-cut control took 140.55 seconds,
so this does not attribute a regression to Workstream 16, but it also does not
satisfy the absolute gate. The closeout remains agent-provisional and
Workstream 16 remains open. No further timing series is selected post hoc.
