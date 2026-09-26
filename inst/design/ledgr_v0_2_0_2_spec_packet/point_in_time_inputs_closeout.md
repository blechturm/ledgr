# Cut 11 Closeout: Point-In-Time Input Model

**Status:** Accepted by the maintainer on 2026-09-26.

**Implementation:** `5c9c944..07ac360`, first corrections at `0354467`,
teaching split at `b14579f`, and integration at `704864d`; the fifth-review
correction is the current uncommitted LDG-2842 work.

| Ticket | Commit | Claim and detector |
| --- | --- | --- |
| LDG-2839 | `5c9c944` plus correction | LCL-0076 / LTB-0076; LCL-0077 / LTB-0077 |
| LDG-2843 | `7b23a97` plus correction | LCL-0078 / LTB-0078 |
| LDG-2840 | `8320690` plus correction | LCL-0079 / LTB-0079 |
| LDG-2841 | `a61e8ee`, `de8cf97` plus correction | LCL-0080 / LTB-0080 |
| LDG-2842 | maintainer acceptance, 2026-09-26 | this record |

## Result In One Sentence

ledgr now ships one deterministic point-in-time input bundle and a progressive
documentation spine whose plain observations and facts pass through public
construction, sealing, reopening and execution without undocumented rewriting.

## Shipped Input

`ledgr_sim_pit_inputs()` is an exported synthetic-data generator. It accepts
instrument identifiers, a date window, a seed, an explicit venue calendar and
switchable teaching cases. It declares the calendar before observations and
returns an ordinary named list of bars, instruments, sessions, membership,
lifetime, trading status, corporate actions, a construction recipe and a case
manifest. It never infers sessions from generated bars.

`ledgr_demo_pit_inputs` is the committed output for `DEMO_01` through
`DEMO_05`, 2020-01-01 through 2020-01-31, seed 1702, synthetic venue
`DEMO_VENUE` in `America/New_York`, and session times 09:30 through 16:00.
Its cases are a weekday venue closure, an observation missing on a declared
open session, a delisting, a halt with late knowledge, and an ordinary cash
dividend. Delisting retains the effective-boundary observation but has no
later bars. The halt retains its effective boundary, omits observations
strictly inside the interval and resumes at the excluded end. Its open-ended
base status and higher-precedence late-known halt make the same historical
cutoff unrestricted before knowledge, halted once known and active at the
interval end.

The dividend subtype is the settlement vocabulary's
`ordinary_cash_dividend`. LTB-0078 holds two `DEMO_03` units across that
committed fact: the research preset posts exactly 1.5 gross cash and the strict
preset refuses the same event. This catches an inert or misspelled subtype at
the public workflow boundary rather than merely checking that the fact seals.

The facts compose with the bundled bars. They are not an overlay for an
arbitrary slice of `ledgr_demo_bars`. The callable data-raw recipe regenerates
the object and its xz version-2 `.rda` byte for byte. Dataset help names all
elements, the five instrument identifiers, the synthetic venue, the universe
and direct constructor links. LTB-0078 sources and executes that script rather
than restating its call in the test.

LTB-0076 independently locates all five cases, constructs every enabled or
individually disabled family, and detects post-delisting or in-halt bars.
LTB-0077 seals and runs the plain frames through public APIs, checks the
late-known halt at three cutoffs, and proves that deleting every bar on one
declared open session preserves that session and produces a stale mark rather
than deleting the pulse.

## Documentation Spine

`data-input-and-snapshots.qmd`, rendered to its tracked GFM sibling, is now
**Importing And Sealing Market Data**. It establishes the required bar shape,
seals a minimal snapshot early, and routes readers to CSV, Yahoo, quarantine
and point-in-time evidence without making them cross the complete data model.

`point-in-time-inputs.qmd` is **Preparing Point-In-Time Inputs**. It starts
from an open session with a missing observation, then adds membership, a
late-known halt, lifetime and corporate actions from the committed demo
bundle. Only after it has sealed, reopened and run that bundle does it present
the detailed
data dictionary and ERD as reference material. The dictionary names grain,
keys, required columns, scope, time semantics, capability and the constructor
help that owns the exhaustive contract.

The article also states the runtime prerequisites that the reference table
alone cannot teach safely: availability requires a complete session calendar
and a stale-mark policy; corporate actions alone do not activate it;
membership, status and lifetime rows with missing evidenced knowledge remain
audit-only; and sessions require knowledge times under the evidenced policy
and follow stricter timing rules.

Its eight-entity Mermaid ERD separates snapshot, physical instrument, bar,
venue session, universe membership, trading status, lifetime and corporate
action. Membership resolves both universe and instrument; status and lifetime
resolve the physical instrument; a corporate action resolves its parent and
optional recipient against that same physical master. The article also names
the four corporate-action clocks and the guarantees a consumer may and may
not inherit from a sealed snapshot.

The progressive article executes the late-known halt rather than merely
describing it, shows the halt's base and overriding rows, shows the delisted
instrument's last observation beside its lifetime fact, and points to the
specialist lessons for changing membership and held-position cash effects. It
then constructs, seals, reopens and runs the committed bundle to DONE.
`experiment-store.qmd` alone owns closed-store backup alongside reopen,
recovery and archive guidance. LTB-0079 checks this three-document division,
the progressive section order, the exact ERD entity, edge and scope-key sets
in source and render, output-only halt evidence and the completed workflow.

All three specialist articles retain deliberately smaller local fixtures:

- missing data keeps its three-session `AAA`/`BBB` hole because it exposes mark
  ageing, `stale_close`, `no_target_change` and the no-fill rule;
- survivorship keeps its losing `AAA` and surviving `BBB` because their return
  difference is the direct bias detector; and
- cash distributions keeps two opening `AAA` units because gross cash 2.5 and
  the later price change make the settlement rule visible.

Each article labels those identifiers local, uses the installed-vignette call
for Preparing Point-In-Time Inputs, loads the committed bundle and executes a
touchpoint against the corresponding gap, delisting or cash-dividend row.
LTB-0080 rejects raw `.qmd` targets and protects the exact call and rendered
teaching outputs, including the missing-observation row's literal `FALSE` and
the committed dividend's `ordinary_cash_dividend`, `DEMO_03` and 0.75 terms.

## First Review And Corrections

The first Type 1 close review returned `CHANGES_REQUIRED` with six findings.
The correction:

- replaced the invalid Date-versus-NA closure predicate and exercised every
  case disabled alone;
- represented the late-known halt as a precedence override rather than a
  foresight-leaking sequence of replacement rows;
- removed observations after delisting and strictly inside the halt;
- added the independently empty declared-session run and covered all cases;
- made the source data-raw recipe callable and tested the real script;
- first expanded the canonical article into the requested data dictionary and
  ERD, then split that dense result by user task after a teachability review;
- replaced misleading MIC-like demo naming with `DEMO_VENUE`; and
- corrected the ticket statement from a later listing to the losing delisted
  instrument actually demonstrated by the survivorship article.

The split itself was documentation-only. The fifth review then found that the
bundle emitted an unrecognized dividend subtype. The correction aligns that
synthetic input with the already shipped settlement vocabulary, regenerates
the committed artifact, and adds public research and strict workflow evidence;
it changes no settlement rule or fact-family contract.

The sixth review found two factual reference errors introduced during that
correction. The ERD no longer marks membership, status or lifetime revision
coordinates as primary keys, and the knowledge guidance now distinguishes the
session family's required evidenced timestamp from the audit-only behavior of
missing membership, status and lifetime knowledge.

## Gates And Check Boundary

The corrected focused suites passed. After the fifth-review correction,
`test-pit-input-documentation.R`, `test-sim-pit-inputs.R` and
`test-documentation-contracts.R` passed with no failure, error, warning or
skip. LTB-0079 now compares the exact ERD and output-only evidence in both
source and render and proves backup absent from both input articles. LTB-0080
checks the installed-vignette target and the cash touchpoint's rendered row.
Changing only the rendered known-halt row produced one LTB-0079 failure. A
combined gut that retargeted one specialist call, miswired the corporate-action
edge, copied backup guidance into the import article and changed the rendered
cash terms produced five failures across LTB-0079 and LTB-0080. Both guts were
fully restored before the final green run.
An alternate-cardinality edge plus a universe key moved from membership to
session produced three additional LTB-0079 failures: one for the relationship
set and one for each corrupted entity block. That gut was also fully restored.

The final corrected ordinary fast profile passed 455 of 455 blocks in 76.32
seconds, and its independent one-run checker passed the unchanged 90-second
bound. The records are in
`.tmp/ws18-integrated-review-correction-fast`.

The full review-profile attempt selected 276 blocks in 402.4 seconds. Both
WS18 blocks passed, but the profile finished red: 272 passed, one declared
optional missing-package-path block skipped, and three unrelated blocks failed
in walk-forward and Workstream 8 mock counters. Each of those three files
passed alone immediately afterward. This is recorded as a cross-file isolation
failure, not hidden and not attributed to WS18. The earlier pre-correction
review record remains 276 of 276 passed in 402.39 seconds with the one declared
skip.

The R CMD check boundary remains the one disclosed in the first closeout: the
touched cash article executes installed, while pre-existing source-tree-path
tests and the unrelated adapter-authoring vignette keep the overall check red.
LDG-2825 owns the final package check; this record does not convert either red
boundary into a pass.

The generator is offline example-data construction, not a fold, ingest, seal,
hydration, finalisation or result-reader hot path. Its column-wise `vapply()`
use does not introduce any of the seven scale-growing production shapes. No
runtime performance claim is made from the documentation gates.

## Governance And Declined Work

The Type 2 cut review is invocation one. The first Type 1 close review is
invocation two and returned corrections. The focused re-review is invocation
three. The teachability review is invocation four and produced the
documentation split. The integrated Type 1 review is invocation five and
found the inert dividend, five detector gaps, broken specialist targets and
lost family-specific teaching. The focused re-review is invocation six; it
confirmed all ten earlier findings closed and found two factual reference
errors: false primary-key markings on revision-bearing fact rows and a session
knowledge rule stated too broadly. The total is 6 / 5 = 1.200, a historical
breach of the 0.5 gate recorded without merging or padding tickets.

The workstream declined automatic prose discovery of every optional
constructor column, forcing every lesson onto one large fixture, presenting
facts as portable across unrelated observation panels, and implying that the
synthetic calendar replaces a vendor or exchange calendar.

Cut 11 retains its historical v0.2.0.2 packet identity, but the maintainer
subsequently promoted the release target to v0.2.1.0. LDG-2825 verifies the
shipped bundle, rendered articles and final release gates under that target.
The maintainer accepted the corrected workstream after the sixth review and
waived a seventh review for the two final factual corrections.
