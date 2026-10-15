# Workstream 32 focused Type 1 re-review

**Mode:** Type 1 focused re-review
**Range:** `7419ad5f..07d1522d`
**Reviewer:** Claude Opus, high effort, independent of the implementing agent
**Verdict:** `CHANGES_REQUIRED`
**Date:** 2026-10-14

The correction closes the original F1 through F9 findings in the product, but
one medium normalization regression and two low witness or record gaps remain.
They are small and bounded. This verdict starts correction round 2 of 3 under
M1; another finding after this correction escalates to the maintainer.

## Closed findings

- **F1:** Resolved in the product; the remaining slight coverage overclaim is
  N2 below. Thirty-eight branch-deletion mutations show that every Section 6
  class, the reverse map, kind key, resolved print, claims path and claims
  warning kills one to three expectations.
- **F2:** Resolved. The notice and marker reverse loops in
  `tools/governance-report.R` report orphan mappings; disabling either fails
  one expectation.
- **F3:** Resolved. `rfc_cycle.md` restores the packet-closeout record and D8
  counters, including decision turns, expressly as evidence rather than
  success gates; no operative 0.5 gate remains.
- **F4:** Resolved. Role-embedded authority is accepted, the live synthesis is
  no longer `missing_authority`, the standalone header still works and the
  README marks the fixture labels provisional for Workstream 35.
- **F5:** Resolved. The 51 baseline entries equal the census in order by
  source, target, occurrence and kind with no duplicates; runtime never reads
  the census; the accepted 313-source digest reproduces from
  `git ls-tree 31ad6d39`; live 314 differs only by `close_review_32.md`.
- **F6:** The header-only boundary is resolved. The normalization regression
  is N1 below. Both the body `Verdict: MAYBE` witness and the backtick witness
  fail when their branches are removed.
- **F7:** Resolved in the product. Twenty-one new `/c:/Users/...` targets are
  reported correctly. The remaining witness-sensitivity gap is N2 below.
- **F8:** Resolved. `CLAIMS_INPUT` is `tests/claims.yml` with a canonical SHA;
  the LF/CRLF and two-location fixture witnesses fail when removed, and report
  content reproduces exactly. N3 below qualifies the capture boundary.
- **F9:** Resolved. Deleting the required fixture directory errors with no
  test blocks run, and the helper self-test is present.

## Findings

1. **N1 (medium): verdict normalization deletes internal underscores.** At
   `tools/governance-report.R:909`, ``gsub("[*`_]", "", verdict)`` changes
   `CHANGES_REQUIRED`, `PASS_AFTER_PATCHES`, `NEEDS_TYPE_2` and
   `REVISE_SEED` into invalid tokens. All five live `invalid_verdict`
   findings are therefore false positives, and no fixture uses an underscore
   token. Strip only `*` and backticks plus leading and trailing `_` emphasis.
   Change the Type 2 witness to decorated `REVISE_SEED`, add a Type 1
   `CHANGES_REQUIRED` pass case and confirm every accepted token remains
   exact.
2. **N2 (low): two detector claims are not failure-sensitive.** In
   `tests/testthat/test-governance-report.R:185-198` and
   `tests/claims.yml:3095-3096`, the root-link witness asserts only that no
   finding occurs. Restoring the original leading-slash external-link bug
   therefore passes 122/122. Removing the baseline, claims or tracked schema
   validators also passes because the malformed witnesses stop at YAML syntax
   or empty-population errors. Add a broken root-leading target such as
   `/missing-root.md` that must report `broken_local_target`, and at least one
   well-formed but structurally invalid input such as a baseline entry missing
   `kind`; otherwise narrow the claim exactly to its witnesses.
3. **N3 (low, record): the report hash capture method is unstated.** In
   `tickets.yml:515` and the LDG-3042 evidence, the recorded hash
   `6279bd601693eb6c7e310aa6597f0149426884515379e0793f86aa742a753307`
   is over report lines joined with LF and no terminal newline. Redirected
   plain `Rscript tools/governance-report.R` output on Windows uses CRLF and
   hashes differently. State the canonical capture in one sentence and do not
   claim that raw stdout bytes have platform-independent line endings.

## Probes run

- Package-loaded registered suites: governance 122/122, documentation
  contracts 1,031/1,031 and control plane 66/66, with no skips.
- Mutation matrix: 42 runs on temporary copies. The leading-slash external
  revert and the three schema validators survive as described in N2. The
  `--check` survivor is benign because the unknown-argument path still rejects
  it. The verdict probe confirms N1.
- Full report: exit 0 in 71.3 seconds with 1,098 findings: 51 baseline, 866 new
  structural and 181 advisory. `BASELINE_POPULATION_MATCH` is false at 313
  versus 314. Content matches the recorded hash under the LF/no-terminal
  capture. A second checkout was not rerun; the fixture two-location witness
  and exact content match cover it.
- Hygiene: `git diff --check` is clean, all three YAML files parse, and new or
  changed files are ASCII with LF. Existing `rfc_cycle.md` CRLF and non-ASCII
  bytes predate Workstream 32.

## Readiness and accounting

The workstream is not ready for maintainer acceptance until N1 is corrected
with a witness. N2 and N3 require only narrow witness and record corrections.
A focused check of N1 and N2 is sufficient. This is the second review
invocation for Workstream 32 and starts correction round 2; a further finding
is correction round 3 and goes to the maintainer. Under M1 no ratio is used as
a gate. Under M2 this file is the single packet home for these findings.
