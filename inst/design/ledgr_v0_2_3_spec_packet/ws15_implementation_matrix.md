# Workstream 15 implementation matrix

Status: implementation complete; independent Type 1 close review pending.
Authority: accepted Cut 7 synthesis D1/D2 and LDG-3179--LDG-3181.

Necessity judgment: the old nested/scalar context duplicated whole-axis reads
and could not expose canonical entry/exit facts. The smallest addition is one
lazy view over the existing prepared pulse and one compact anchor component in
the existing accounting carrier. No new execution, accounting, replay,
identity, schema, manifest or generic orchestration layer was added.

| Requirement | Owner | Product boundary | Primary evidence |
| --- | --- | --- | --- |
| surface/detector/timing inventory | LDG-3179 | existing test profiles and shared timing harness | `dev/bench/v0_2_3_ws5/`; `ws5-timing-1` |
| flat lazy named columns | LDG-3180 | `R/pulse-context.R` | `test-flat-lazy-context.R` |
| alias-first dynamic feature reads | LDG-3180 | existing prepared resolver | `test-active-alias-runtime.R` |
| frozen views and one build per read | LDG-3180 | pulse-local lookup/cache | `test-flat-lazy-context.R` |
| retired readers and warnings | LDG-3180 | strict context S3 methods | `test-scalar-accessor-warning.R`; source census |
| holding value and sizing refusal | LDG-3180 | existing availability mark and target helper | `test-strategy-context-entrances.R` |
| live position anchors/facts | LDG-3181 | canonical accounting transition | `test-position-facts-context.R` |
| same-bar order and non-fill changes | LDG-3181 | transition event order | `test-position-facts-context.R` |
| prefix rebuild and durable resume | LDG-3181 | existing accounting replay | `test-position-facts-context.R` |
| contiguous carry and shared bar ages | LDG-3181 | existing carried opening and bar axis | `test-position-facts-context.R` |
| supplied-position unknowns | LDG-3181 | pulse context default facts | `test-position-facts-context.R` |

Identity and persistence: snapshot and configuration identity do not change in
this workstream. Position facts are derived canonical run state and are not a
new research manifest or persisted duplicate. The already identity-bearing
carried opening gains only the provenance required to preserve known anchors.

The old reader warning claims LCL-0071 and LCL-0102 are retired with their
behavior. LCL-0066 and LCL-0103 now protect strict reader absence and current
flat-column teaching. This is a deliberate claim migration, not an oracle
weakening.

