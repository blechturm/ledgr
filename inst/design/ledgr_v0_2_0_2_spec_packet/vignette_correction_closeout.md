# Workstream 28 Documentation Correction Closeout

**Status:** Agent-provisional; awaiting Type 1 close review and maintainer
acceptance.

**Authority:** Cut 19, Workstream 28, LDG-2858 and LDG-2885 through
LDG-2889 in `tickets.yml`; the accepted findings in
`inst/design/audits/v0_2_0_2_vignette_audit.md`; and
`inst/design/vignette_styleguide.md`.

## Result

The first Type 1 close review returned `CHANGES_REQUIRED`. It found one broken
review detector, thirteen partly corrected article cells, four additional
factual or entry-path errors, and too little failure-sensitive protection for
claim-level teaching. The corrected README and all 26 executed articles now
teach the shipped surface against the accepted audit. The 53 failed
article/category cells are accounted for:
12 under LDG-2885, 17 under LDG-2886, 21 under LDG-2887 and 3 under
LDG-2888. Cross-cutting warning, navigation, style-guide and freshness-checker
findings are also corrected. No finding was dropped or converted into a
product claim.

The implementation commits are:

- `9edddb8` -- LDG-2858, first-user README rewrite;
- `110606f` -- LDG-2885, feature articles;
- `fec5269` -- LDG-2886, workflow articles;
- `6f7cd87` -- LDG-2887, availability, execution and remaining articles; and
- `e5d5d22` -- LDG-2888, warnings, navigation, style guide and checker.

Correction `93c93b9` closes the first review's findings: it restores the
LTB-0074 certification matrix, completes the named article corrections,
reorders the public learning path, registers LTB-0116, and rerenders the
affected Markdown.

This document and the final audit update are LDG-2889's provisional record.
LDG-2858 was completed with its accepted README implementation. LDG-2885
through LDG-2889 and Workstream 28 stay open until focused independent
re-review and maintainer acceptance.

## Teaching Outcomes

Each corrected article received a learner read using the style guide's review
checklist. The per-article results are recorded in Section 7 of the audit.
Across the set:

- the smallest useful dense path appears before optional point-in-time or
  availability evidence;
- whole-vector strategy access replaces scalar loops where the public surface
  supports it;
- active-alias scalar access is disclosed as a current API limit rather than
  taught as a preferred pattern;
- executable examples now demonstrate the claims they explain, including
  leakage, warmup, promotion, availability, no-fill clocks and adapter facts;
- current research capability is separated from planned paper/live operation;
  and
- stricter evidence never becomes an implied prerequisite for an ordinary
  dense backtest.

The two articles with no original finding, Point-In-Time Inputs and Selection
Integrity, were rechecked and left substantively unchanged.

## Cross-Cutting Decisions

Warnings are visible project-wide. This makes warning prose auditable in the
rendered Markdown and avoids a growing per-chunk suppression policy.

The style-guide reading flow and pkgdown navigation now cover the same article
families. Custom Indicators is the canonical home for scalar, series, R and
CSV adapter construction; TTR Indicators And Bundles owns TTR-backed features
and bundle naming.

`tools/render-vignettes-gfm.R --check --all` now discovers sources
recursively and copies companion R, CSV, RDS and JSON files into its temporary
render tree. Its first complete run caught a process-dependent run ID in
Custom Indicators. Fixed run IDs made the render deterministic; the second
complete run passed.

## Product Routes

No product behavior was implemented under this workstream. The accepted audit
routes remain:

- P3, a whole-universe active-alias read, to
  `inst/design/rfc/rfc_feature_map_read_surface_v0_2_x_seed.md`;
- P7, repeated explicit-map validation, to the v0.2.1.1 pulse/accessor
  optimization cut; and
- P4 through P6 to the accepted Cut 20 repairs already present in the reviewed
  product surface.

## Verification

- Six article-reading test files: PASS, including the restored LTB-0074 and
  new LTB-0116.
- `tools/render-vignettes-gfm.R --check --all`: PASS, 26 of 26 sources.
- Ordinary fast profile: PASS, 483 of 483 blocks, no non-pass result,
  105.170 seconds.
- Fast gate: `LEDGR_TEST_GATE_OK`, one run, median 105.170 seconds against the
  preregistered 112.000-second bound.
- `git diff --check`: PASS.
- Production R/C++ changes: none.

The fast evidence is in `.tmp/ws28-correction-fast`. It is local execution
evidence and is not a release artifact.

## Review Accounting And Stop

The initial Type 1 close review is one invocation over six Workstream 28
tickets: 1/6 = 0.167. The requested focused re-review will make that 2/6 =
0.333. Together with Workstream 26's accepted audit review, Cut 19 will stand
at three reviews over seven tickets: 3/7 = 0.429, within the 0.5 gate.

This closeout authorizes no release-gate command. Workstream 15 opens only
after the Type 1 review passes and the maintainer accepts Workstream 28 and
the routed dispositions above.
