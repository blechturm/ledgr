# Cut 11 Closeout: Point-In-Time Input Model

**Status:** Agent-provisional; awaiting the independent Type 1 close review.

**Implementation:** `5c9c944..de8cf97` on
`codex/ws16-v0.2.1.0`.

| Ticket | Commit | Claim and detector |
| --- | --- | --- |
| LDG-2839 | `5c9c944` | LCL-0076 / LTB-0076; LCL-0077 / LTB-0077 |
| LDG-2843 | `7b23a97` | LCL-0078 / LTB-0078 |
| LDG-2840 | `8320690` | LCL-0079 / LTB-0079 |
| LDG-2841 | `a61e8ee`, `de8cf97` | LCL-0080 / LTB-0080 |
| LDG-2842 | pending close-review acceptance | this record |

## Result In One Sentence

ledgr now ships one deterministic, inspectable point-in-time input bundle and
one decision map that carry matching observations and facts through the public
construct, seal, reopen and run workflow without undocumented rewriting.

## Shipped Input

`ledgr_sim_pit_inputs()` is an exported synthetic-data generator. It accepts
instrument identifiers, a date window, a seed, an explicit venue calendar and
switchable teaching cases. It declares the calendar before observations and
returns an ordinary named list of plain data: bars, instruments, sessions,
membership, lifetime, trading status, corporate actions, a constructor recipe
and a case manifest. It never infers sessions from generated bars.

`ledgr_demo_pit_inputs` is the committed output for `DEMO_01` through
`DEMO_05`, 2020-01-01 through 2020-01-31, seed 1702, venue `DEMO_XNYS` in
`America/New_York`, and session times 09:30 through 16:00. Its default cases
are a weekday venue closure, an observation missing on a declared open
session, a delisting, a halt with late knowledge, and an ordinary cash
dividend. The facts compose with the bars in this bundle. They are not an
overlay for an arbitrary slice of `ledgr_demo_bars`.

The recorded data-raw call reproduces the xz version-2 `.rda` byte for byte.
LTB-0076 independently locates each case and detects loss of the observation
gap. LTB-0077 sends the generated plain frames through public constructors,
seal, verified reopen, availability activation and persisted DONE completion.
LTB-0078 repeats that proof for the committed bytes.

## Documentation Spine

`data-input-and-snapshots.qmd` is the canonical decision map. It distinguishes
bars, the physical instrument master, venue sessions, both membership shapes,
trading status, lifetime and equity corporate actions. Constructor help owns
the exhaustive optional-column contracts. The article states the shared
stable-identifier, whole-second-UTC and per-family-knowledge rules, diagrams
the distinct physical, venue and universe scopes, and executes the committed
bundle through DONE. LTB-0079 protects the map, links, exact eight-node diagram
and rendered completion.

All three specialist articles retain deliberately smaller local fixtures:

- missing data keeps its three-session `AAA`/`BBB` hole because it exposes mark
  ageing, `stale_close`, `no_target_change` and the no-fill rule;
- survivorship keeps its losing `AAA` and surviving `BBB` because their return
  difference is the direct bias detector; and
- cash distributions keeps two opening `AAA` units because gross cash 2.5 and
  the later price change make the settlement rule visible.

Each article says those identifiers are local, links to the canonical map,
loads the committed bundle and executes a touchpoint against the corresponding
gap, delisting or cash-dividend row. LTB-0080 protects that relationship and
the three retained teaching outputs. Renaming one canonical-map link made the
block fail. All three sources rendered with every chunk successful.

## Gates And Check Boundary

The final ordinary fast profile selected and passed 455 of 455 blocks in
75.89 seconds. The independent one-run checker passed against the unchanged
90-second bound. The review profile selected and passed 276 of 276 blocks in
402.39 seconds; its only skip was the declared missing-package-path test under
an installed `quantmod`.

A source tarball built successfully under R 4.6.1. R CMD check reported no
missing documentation, data or code/documentation mismatch. Its first run
found that the touched cash article relied on source-tree `load_all()`; adding
`library(ledgr)` made that article pass under installed-package vignette
execution. The repeated overall check remains red for the pre-existing
source-tree-path test failures and the unrelated
`corporate-action-adapter-authoring.qmd` lookup of a vignette helper through an
`NA` source root. Those failures are not presented as a green package check or
absorbed into this workstream. The release gate in LDG-2825 owns the final
package check.

## Governance And Declined Work

The Type 2 cut review is the first review invocation. The requested Type 1
close review is the second. No focused cut re-review occurred. If the close
review passes without a correction round, the final ratio is 2/5 = 0.400.

The workstream declined automatic prose discovery of every optional
constructor column, forcing every lesson onto one large fixture, presenting
facts as portable across unrelated observation panels, and implying that the
synthetic calendar replaces a vendor or exchange calendar.

Cut 11 retains its historical v0.2.0.2 packet identity, but the maintainer
subsequently promoted the release target to v0.2.1.0. LDG-2825 verifies the
shipped bundle, rendered articles and final release gates under that promoted
target.
