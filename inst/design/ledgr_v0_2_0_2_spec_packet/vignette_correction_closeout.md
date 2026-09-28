# Workstream 28 Documentation Correction Closeout

**Status:** Agent-provisional; final focused Type 1 review PASS at `ecb3962`;
awaiting maintainer acceptance.

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

The focused re-review also returned `CHANGES_REQUIRED`. Correction `40eeb42`
closes its six Workstream 28 defects: all article-reading checks pass, rendered
provenance is dependency-version independent, the sweep reports four and six
feature combinations, Strategy Basics interprets its actual 24 trades, Custom
Indicators teaches both supported scalar arities from one parameter source,
and all five registered LTB-0116 mutations fail.

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

The focused re-review also exposed that `?ledgr_indicator` documents only
`fn(window)` although the engine supports `fn(window, params)`. The article now
teaches both shipped forms. P8 routes the public-help correction through
LDG-2895 to a named owner; Workstream 28 does not edit production roxygen.

Its broader editorial findings already have Cut 21 owners: LDG-2897 covers
hand-offs, LDG-2898 safe IDs and non-executed chunks, LDG-2899 warnings and
candidate outputs, LDG-2900 duplicated or contradictory facts, and LDG-2901
maintainer language and the shared-input wording.

## Verification

- Six article-reading test files: PASS, including the restored LTB-0074 and
  new LTB-0116.
- `tools/render-vignettes-gfm.R --check --all`: PASS, 26 of 26 sources.
- Ordinary fast profile: PASS, 483 of 483 blocks, no non-pass result,
  104.400 seconds.
- Fast gate: `LEDGR_TEST_GATE_OK`, one run, median 104.400 seconds against the
  preregistered 112.000-second bound.
- LTB-0116 mutation checks: PASS. Scalar-first guidance, the obsolete sweep
  non-goal, one-date survivorship, the false reader limitation and a one-arity
  custom-indicator claim produced 1, 1, 1, 1 and 2 failures respectively.
- `git diff --check`: PASS.
- Production R/C++ changes: none.

The fast evidence is in `.tmp/ws28-final-correction-fast`. It is local execution
evidence and is not a release artifact.

## Review Accounting And Stop

Three Type 1 reviews ran over six Workstream 28 tickets. The close review and
the focused re-review returned `CHANGES_REQUIRED`. The final focused review at
`ecb3962`, a mechanical check the maintainer counts as the third invocation,
returned PASS on 2026-09-28. It found that:

- the six article-reading test files pass;
- the recursive freshness check verifies all 26 articles on the maintainer's
  machine;
- LTB-0080 and LTB-0074 fail when their protected text is removed;
- 17 of 18 LTB-0116 mutations fail; and
- the fast-gate records pass 483/483 in 104.400 seconds.

The one surviving mutation rewords the proof-of-generalization claim, which the
exact-phrase pin does not cover.

Workstream 28 stands at 3/6 = 0.500. Together with Workstream 26's accepted
audit review, Cut 19 stands at four reviews over seven tickets: 4/7 = 0.571,
an honest historical gate breach. No ticket is added to repair the arithmetic.

This closeout authorizes no release-gate command. Workstream 15 opens only
after the Type 1 review passes and the maintainer accepts Workstream 28 and
the routed dispositions above.
