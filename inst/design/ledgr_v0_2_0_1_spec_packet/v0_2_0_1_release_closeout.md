# v0.2.0.1 Release Closeout

**Status:** Local release gate complete after independent review and maintainer
acceptance.
Remote branch CI, merge, main CI, tag, tag CI, and GitHub Release remain later
evidence.
**Date:** 2026-09-18.
**Branch:** `v0.2.0.1`.
**Last accepted commit before this gate:**
`a7c078bf317357e39a0574cca00217f37e3fa123`.
**Stage O execution source:**
`bcced9457de58f10f9c862c2890576a7370b1140`.
**Spec packet:** `inst/design/ledgr_v0_2_0_1_spec_packet/`.

The closeout and the narrow source-package test guards described below passed
independent review and maintainer acceptance on 2026-09-18. Their commit
identity remains Git metadata rather than a self-referential field here.

## Scope Closed Locally

v0.2.0.1 productionizes the reviewed availability performance work without
changing the public execution model. It contains:

- one prepared availability provider built at each existing consumer boundary;
- typed diagnostic chunks and one diagnostic block per pulse;
- an atomic complete-equity-prefix merge for resumed availability-aware runs;
- grouped membership and lifetime conflict sweeps plus a supersession-exact
  status hybrid;
- direct collapse 2.1.8 character and list event-buffer writes;
- transient prepared fold-time valuation state;
- public one-candidate sweep rows for memory-backed peer measurements;
- dense timestamp validation without per-bar string formatting;
- within-chunk snapshot-hash timestamp deduplication with byte-identical hashes;
  and
- an accepted exact-parity proof template that remains evidence
  infrastructure rather than implementation authority.

The timestamp prerequisite selected `NEITHER`. No availability-ingestion
optimization entered the release. The old provider, row-list diagnostic
writer, scalar diagnostic construction, scalar dense timestamp path, and all
shipping selectors or fallbacks are absent. The public fact-inspection engine
remains independent.

The release adds no public API, schema, hash rule, identity field, persisted
cache, public telemetry field, or durable lane name. It does not promote
compiled accounting, add a public memory single-run API, change valuation
beyond the accepted fold-time correction, or import any parked optimization.

## Environment

The principal Windows gates used R 4.6.1 ucrt on Windows build 26200 with
duckdb 1.5.2, testthat 3.3.2, and collapse 2.1.8. The default R 4.6 user
library initially still contained collapse 2.1.7. It was upgraded to 2.1.8 so
ordinary child `R CMD build` and `R CMD check` processes resolve the declared
`collapse (>= 2.1.8)` floor without a private runtime fallback.

The documentation build used one coherent documentation library containing
rlang 1.3.0, pkgdown 2.2.1, collapse 2.1.8, and duckdb 1.5.5. This is recorded
as a documentation environment, not substituted for the principal runtime.

The local Linux gate used Ubuntu under WSL2, Linux 5.15.167.4, R 4.5.2,
duckdb 1.5.2, testthat 3.3.2, pkgload 1.5.2, and collapse 2.1.8. Missing Linux
build dependencies were installed into the repository-local `lib-wsl`
library; package source was not changed to make the gate pass.

## Accepted Stage O Records

Only the independently reviewed and explicitly accepted Batch 14 prefixes are
promoted:

- availability cold, warm, and profile:
  `dev/bench/results/v0_2_0_1_stage_o_availability_bcced94_20260918T123618Z/`;
- snapshot-hash pair:
  `dev/bench/results/v0_2_0_1_stage_o_hash_bcced94_20260918T124304Z/`; and
- peer record:
  `dev/bench/results/peer_benchmark_record_20260918T140507Z`.

The availability record measured 119.11 seconds cold and a 17.55-second warm
median. The 60-to-90-second cold figure was a forecast and is not presented as
achieved. The hash candidate reduced formatter inputs from 630,000 to 79,380,
measured 5.14 seconds against 7.66 seconds, stayed within the memory gate, and
preserved every hash exactly.

The peer record uses public workflows for both memory rows. Its canonical and
compiled public sweeps measured 30.96 and 16.63 seconds warm. Durable ledgr
measured 58.23 seconds warm. These are fixture- and environment-specific
measurements, not a universal runtime or a peer-superiority claim. LEAN was
`UNAVAILABLE`; missing phase values remain missing.

A later inspection found that Zipline's session labels are uniformly shifted
relative to the benchmark reference, so the timestamp-string join retained
only 1,008 of 1,260 rows and understated aligned correlation. The immutable
Stage O bundle remains accurate for the method it ran, its Tier 1 disposition
does not change, and no ranking claim is permitted. Corrected session
alignment, explicit join-retention guards, and threshold review are scheduled
for the next implementation packet rather than silently rewriting this
release record.

## Local Gate Evidence

- The complete Windows source-tree suite passed in 864.23 seconds with zero
  failures and zero warnings. Its one named conditional skip was the
  missing-`quantmod` negative path because `quantmod` was installed. No
  required v0.2.0.1 matrix case was skipped.
- `Rscript --vanilla tools/check-readme-example.R` passed under
  installed-package semantics in approximately 27.2 seconds.
- The final full pkgdown site rendered in 416.5 seconds. Twenty-four articles were
  scanned with no DuckDB shared-home notice, and the preflight anchor check
  passed.
- `R CMD build .` completed with vignettes in 251.41 seconds and produced
  `ledgr_0.2.0.1.tar.gz` without a build warning.
- `R CMD check --no-manual --no-build-vignettes ledgr_0.2.0.1.tar.gz`
  completed in 1,129.08 seconds with `Status: OK`. Package installation,
  examples, tests, and vignette-source checks passed with no errors, warnings,
  or notes.
- The WSL minimum gate passed all four required files:
  `test-schema-validator-side-effects.R`, `test-schema-snapshots.R`,
  `test-schema.R`, and `test-persistence-fresh-connection.R`.
- Coverage was not rerun. No production source, coverage helper, coverage
  exception, or threshold changed in Batch 15, and coverage is not part of the
  accepted v0.2.0.1 release evidence. The playbook therefore does not require
  a duplicate coverage run.

## Failed Attempts And Corrections

Failures were retained as diagnostic history rather than erased:

- The first full-suite attempt ran for 914.1 seconds and failed only because
  the sandbox could not create `tests/testthat/Rplots.pdf`. The three affected
  files passed with repository write access, then the complete suite passed in
  one clean rerun.
- The first site build mixed library roots and loaded rlang 1.2 where pkgdown
  required at least 1.3. During the final closeout render, one invocation also
  supplied Quarto's directory rather than its executable, and one relied on an
  environment library order that R did not honor. Both stopped before a
  complete render. The final build set `.libPaths()` inside R, named
  `quarto.exe` explicitly, used one coherent documentation library, and passed.
- Initial source builds failed first because Quarto was not discoverable and
  then because child R processes resolved collapse 2.1.7. Quarto paths were
  made explicit and the default R 4.6 library was brought to the declared
  collapse 2.1.8 floor. The complete vignette build then passed.
- A diagnostic no-vignette tarball exposed nine non-portable historical RFC
  paths and two installed-package test assumptions. Exact `.Rbuildignore`
  entries keep those charter and review artifacts in Git but out of the source
  tarball. The peer-boundary and snapshot-hash source-hash blocks skip only
  their source-file checks when source-only files are absent from an installed
  package. The three installed-compatible optimization-oracle assertions stay
  unguarded. Harness-dependent peer assertions run whenever benchmark source is
  present, snapshot behavioral assertions remain mandatory, and both focused
  files pass in the checkout.
- The first WSL attempt found an incomplete repo-local Linux library. `Rcpp`,
  `collapse 2.1.8`, `cpp11`, `decor`, and `yyjsonr` were provisioned there;
  the unchanged package then compiled and passed the four-file gate.

These are packaging and gate-harness corrections. No `R/`, `src/`,
`DESCRIPTION`, or `NAMESPACE` file changed after the accepted Batch 14 commit.

## Release-Gate Adjudication

### Base specification

1. **Matrices:** PASS. Batches 1 through 6 name and execute the Section 4
   witnesses; Batches 8, 9, and 11 through 13 add the amendment matrices. The
   complete source suite passed with no required skip.
2. **Retirement:** PASS. `test-availability-production-retirement.R` and the
   batch source guards prove the old paths and selectors are absent while the
   public inspection resolver remains.
3. **Schema and identity:** PASS. No schema or identity source changed. The
   v0.2.0.0 reopen witnesses, full suite, package check, and Linux schema gate
   pass at schema version 115 without a migration.
4. **Complete suite:** PASS, with the one justified optional negative-path skip
   recorded above.
5. **Build and check:** PASS; final check status is `OK`.
6. **Collapse versions:** SUPERSEDED narrowly by the accepted hot-path
   amendment. The binding contract is now collapse 2.1.8 or later with no
   2.1.7 fallback. Batch 8 proved the route before the floor changed; the
   release gates resolve 2.1.8.
7. **Final records:** PASS; all three accepted prefixes are cited above.
8. **Documentation and artifact hygiene:** PASS after final render and cleanup.
   Source anchors resolve, generated release artifacts are excluded from the
   commit, and package-source artifacts are removed.
9. **Independent review stops:** PASS. Every named correctness, parity, and
   Stage O stop passed independent review before maintainer acceptance.
10. **Cross-artifact agreement:** PASS for the accepted local state. Ticket,
    YAML, batch plan, packet README, indexes, roadmap, horizon, manuals, NEWS,
    and this closeout all state that the accepted local gate is complete and
    remote evidence remains later.

### Hot-path complexity amendment

All seven additional gates pass. Batch 8 proves the direct collapse route,
exact event parity, failure boundaries, and absence of a selector or fallback.
Batch 9 proves prepared valuation semantics, linear structure, the 757-pulse
ratio, and the combined eventful availability case. Their independent reviews
passed. The accepted Stage O records replace provisional references, and the
maintainer authorized this release gate only after accepting that review.

### Timestamp and benchmark amendment

All six additional release requirements pass. The public benchmark boundary,
compensated inline equity reference, dense timestamp matrix, structural mutant,
within-chunk hash identity, tamper/reopen guards, and proof-template authority
boundary are durable. Stages M and N passed independent review; Stage O passed
independent evidence review; the maintainer explicitly authorized Stage P;
the prerequisite's `NEITHER` branch left `R/availability-ingest.R` unchanged;
and final records share the accepted source commit.

No benchmark result was used to waive a semantic, persistence, schema,
identity, hash, quarantine, rollback, resume, reopen, dependency, retirement,
source-removal, benchmark-boundary, or review gate.

## Release State And Next Evidence

This artifact records local evidence only. It does not claim a green remote
branch, `main`, tag, tag CI, or GitHub Release. Independent Batch 15 review and
explicit maintainer acceptance are complete. The next authorized step is to
commit and push `v0.2.0.1`, then wait for branch CI. Merge, main CI, tag
creation, tag CI, and release publication remain distinct later evidence under
`inst/design/release_ci_playbook.md`.
