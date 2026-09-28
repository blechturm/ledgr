# Cut 20 Closeout: Audit-Discovered Product Boundary Repairs

**Status:** Agent-provisional; the focused Type 1 re-review verified both code
corrections and returned record-only provenance findings. Those are corrected;
the workstream awaits maintainer acceptance.

**Implementation:** `ac69370`, corrected at `55524e5` on `v0.2.0.2`.

| Ticket | Commit | Claim and detector |
| --- | --- | --- |
| LDG-2890 | `ac69370` | LCL-0112 / LTB-0112 |
| LDG-2891 | `ac69370`, `55524e5` | LCL-0113 / LTB-0113 |
| LDG-2892 | `ac69370` | LCL-0114 / LTB-0114 |
| LDG-2894 | `ac69370`, `55524e5` | LCL-0115 / LTB-0115 |
| LDG-2893 | `2e1e59c` | closeout and packet reconciliation |

## Result

Four public boundaries now fail or normalize where they previously leaked an
internal error, rejected a valid timestamp at DuckDB, discarded a supplied
bundle name, or let one string select two different feature series.

- Unresolved parameterized feature maps now make both contract-inspection
  helpers raise `ledgr_feature_factory_requires_params` with one actionable
  materialize-first message. Concrete maps retain their literal contract rows.
- Integer-backed `POSIXct` bars and fact clocks are canonicalized once to
  ordinary double-backed storage after timestamp validation and before DuckDB
  registration. Equivalent inputs persist identical bars, fact rows and
  snapshot hashes.
- Concrete and parameterized bundles must be unnamed inside
  `ledgr_feature_map()`. Bundle `prefix` and `naming` remain the supported
  controls; unnamed expansion is unchanged.
- A map alias may equal its own feature ID but may not equal another entry's
  concrete feature ID. The rule applies at construction and after parameter
  resolution, not on repeated reads. A bad sweep candidate fails independently
  of valid siblings.

No condition class, public helper, feature computation, snapshot identity, or
new feature-engine capability was added.

## Failure Sensitivity

Each registered detector was gutted independently in a detached worktree.

- Removing the unresolved-map guard restored the unclassed `vapply()` length
  error and produced four LTB-0112 failures across the two public helpers.
- Removing fact POSIXct storage canonicalization made LTB-0113 fail its family
  storage assertion and restored the public DuckDB transaction error before
  the integer-backed fact snapshot could seal. The original bars mutation
  remains recorded at `ac69370`.
- Removing the two named-bundle checks restored silent outer-name loss and
  failed LTB-0114. Concrete and parameterized branches are both covered.
- Replacing the collision validator with a no-op restored silent map
  construction and failed LTB-0115. The checked-in block also reaches public
  run resolution and proves per-candidate sweep isolation. Reintroducing that
  validator in generic object validation made the explicit-read detector fail.

## Performance And Shape

The data-scale changes are vectorized `storage.mode()` canonicalizations of
already validated bar and fact timestamp vectors. They add no R-level row
loop, per-element formatting, frame growth, repeated parsing, rescan by
instrument, or quadratic validator. The three feature changes run only at
construction or inspection boundaries over the declared feature set.

The first Type 1 review found that the collision check had also been placed in
generic object validation. Explicit-map reads therefore repeated it twice and
paid about 3.15 microseconds per lookup, roughly two seconds at the registered
630,000-call shape. Correction `55524e5` removes that scan from generic reads;
construction and resolution remain the two enforcing boundaries. LTB-0115
fails if the scan is reintroduced on lookup.

The registered constructor clock used 30,000 bars: 100 instruments by 300
days, in alternating fresh R processes.

| Arm | Runs | Median |
| --- | --- | ---: |
| before `70022b7` | 0.610 / 0.610 / 0.610 s | 0.610 s |
| current `ac69370` | 0.590 / 0.610 / 0.610 s | 0.610 s |

This is evidence of no observable regression at the measured shape, not a
speedup claim.

## Verification

The correction reran the feature-map, snapshot-adapter, availability-facts,
equity-corporate-action-facts and test-control-plane files. They passed; the
snapshot-adapter file retained its pre-existing deliberate optional-path skip.

The exact-commit ordinary fast profile at
`C:/tmp/ws27-fast-ac69370` passed 483 of 483 blocks in 102.840 seconds. The
independent gate checker accepted the one-run record against the unchanged
112-second bound.

The correction record at `C:/tmp/ws27-correction-fast-b462cd5` passed the
same 483 of 483 blocks in 98.410 seconds. The ordinary checker accepted that
one-run record against the unchanged 112-second bound. This is gate evidence,
not a correction speedup claim. The record ran at pre-rebase commit
`b462cd5`; its code and tests are identical to release-line commit `55524e5`.

The accepted audit routes P4 and P6 to `ac69370`, and P5 to `ac69370` plus
`55524e5`. Workstream 28 receives the exact materialize-first instruction,
bar-and-fact timestamp acceptance, unnamed-bundle rule, and cross-entry alias
rule; it remains blocked until this closeout is accepted.

The cut review is invocation one. The first Type 1 close review is invocation
two and returned `CHANGES_REQUIRED`. The focused correction review is
invocation three: 3/5 = 0.600, a historical gate breach that cannot be repaired
by padding this cut. Its only remaining findings were the stale pre-rebase SHA
and conditional arithmetic corrected here. This closeout remains
agent-provisional until the maintainer accepts the workstream.
