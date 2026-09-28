# Cut 20 Closeout: Audit-Discovered Product Boundary Repairs

**Status:** Agent-provisional; awaiting the Type 1 close review and maintainer
acceptance.

**Implementation:** `ac69370` on `v0.2.0.2`.

| Ticket | Commit | Claim and detector |
| --- | --- | --- |
| LDG-2890 | `ac69370` | LCL-0112 / LTB-0112 |
| LDG-2891 | `ac69370` | LCL-0113 / LTB-0113 |
| LDG-2892 | `ac69370` | LCL-0114 / LTB-0114 |
| LDG-2894 | `ac69370` | LCL-0115 / LTB-0115 |
| LDG-2893 | pending | closeout and packet reconciliation |

## Result

Four public boundaries now fail or normalize where they previously leaked an
internal error, rejected a valid timestamp at DuckDB, discarded a supplied
bundle name, or let one string select two different feature series.

- Unresolved parameterized feature maps now make both contract-inspection
  helpers raise `ledgr_feature_factory_requires_params` with one actionable
  materialize-first message. Concrete maps retain their literal contract rows.
- Integer-backed `POSIXct` bars are canonicalized once to ordinary
  double-backed storage after timestamp validation and before DuckDB
  registration. Equivalent inputs persist identical bars and snapshot hashes.
- Concrete and parameterized bundles must be unnamed inside
  `ledgr_feature_map()`. Bundle `prefix` and `naming` remain the supported
  controls; unnamed expansion is unchanged.
- A map alias may equal its own feature ID but may not equal another entry's
  concrete feature ID. The rule applies at construction and after parameter
  resolution. A bad sweep candidate fails independently of valid siblings.

No condition class, public helper, feature computation, snapshot identity, or
new feature-engine capability was added.

## Failure Sensitivity

Each registered detector was gutted independently in a detached worktree.

- Removing the unresolved-map guard restored the unclassed `vapply()` length
  error and produced four LTB-0112 failures across the two public helpers.
- Removing only POSIXct storage canonicalization restored the public DuckDB
  transaction error in LTB-0113 before the integer snapshot could seal.
- Removing the two named-bundle checks restored silent outer-name loss and
  failed LTB-0114. Concrete and parameterized branches are both covered.
- Replacing the collision validator with a no-op restored silent map
  construction and failed LTB-0115. The checked-in block also reaches public
  run resolution and proves per-candidate sweep isolation.

## Performance And Shape

The only data-scale change is one vectorized `storage.mode()` canonicalization
of the already prepared timestamp vector. It adds no R-level row loop,
per-element formatting, frame growth, repeated parsing, rescan by instrument,
or quadratic validator. The three feature changes run only at construction or
inspection boundaries over the declared feature set.

The registered constructor clock used 30,000 bars: 100 instruments by 300
days, in alternating fresh R processes.

| Arm | Runs | Median |
| --- | --- | ---: |
| before `70022b7` | 0.610 / 0.610 / 0.610 s | 0.610 s |
| current `ac69370` | 0.590 / 0.610 / 0.610 s | 0.610 s |

This is evidence of no observable regression at the measured shape, not a
speedup claim.

## Verification

Focused feature-inspection, feature-map, TTR, active-alias, snapshot-adapter,
documentation-contract, and test-control-plane files passed. The
snapshot-adapter file retained its pre-existing deliberate optional-path skip.

The exact-commit ordinary fast profile at
`C:/tmp/ws27-fast-ac69370` passed 483 of 483 blocks in 102.840 seconds. The
independent gate checker accepted the one-run record against the unchanged
112-second bound.

The accepted audit now routes P4, P5 and P6 to `ac69370`. Workstream 28
receives the exact materialize-first instruction, timestamp acceptance,
unnamed-bundle rule, and cross-entry alias rule; it remains blocked until this
closeout is accepted.

The cut review is invocation one and the planned Type 1 close review is
invocation two: 2 reviews over the 5-ticket cut is 0.400 against the 0.5
gate. This closeout remains agent-provisional until maintainer acceptance.
