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

The performance and final gate rows are filled only from checked-in raw
evidence. Until those rows exist and pass, this closeout remains
agent-provisional and Workstream 16 remains open.
