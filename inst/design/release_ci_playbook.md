# ledgr Release CI Playbook

This playbook records the release-gate lessons from v0.1.7.2. It is meant for
maintainers and coding agents working the final release ticket.

## What Went Wrong in v0.1.7.2

The release was not blocked by one bug. It was blocked by several different
classes of failure that looked similar from the outside:

- **DuckDB cross-connection visibility on Ubuntu.** Windows read-after-write
  behavior was forgiving. Ubuntu exposed cases where a write connection had
  committed data, but a fresh read connection did not reliably observe mutable
  metadata until an explicit checkpoint had happened.
- **DuckDB native instability on parameter-bound metadata queries.** The
  original comparison metadata query used a complex SQL shape with joins,
  subqueries, window-like aggregation, and DBI parameters. On Ubuntu CI this
  could abort inside DuckDB native code. The fix was to simplify metadata reads
  and do enrichment in R.
- **Main and tag CI are separate evidence.** A green `main` run does not prove a
  moved release tag is green. Tag pushes create a fresh workflow run on fresh
  runners, with fresh dependency installs and timing.
- **Coverage is not the same gate as `R CMD check`.** The coverage step runs the
  installed test suite again under `covr` instrumentation. That adds another
  layer around native code. A coverage-only native abort can happen after the
  strict package check already passed.
- **Local WSL parity is useful but not complete.** Matching Ubuntu and R
  versions reduces drift, but it does not perfectly match GitHub Actions runner
  timing, filesystem, package binaries, or process scheduling.

The practical lesson: treat each failed step as a separate signal. Do not call a
release ready because a similar run passed elsewhere.

## Release Order

1. Finish the release ticket on the release branch.
2. Run the local gates before merge:
   - full package tests;
   - `R CMD check --no-manual --no-build-vignettes`;
   - `tools/check-coverage.R` when coverage behavior changed;
   - pkgdown build when documentation, vignettes, or pkgdown changed.
3. Verify agent-facing release context:
   - `AGENTS.md` names the current active spec packet and tickets;
   - `AGENTS.md` does not point agents at a completed packet as the active
     source of truth;
   - `AGENTS.md` keeps the one-execution-path/fold-core invariant aligned with
     `inst/design/contracts.md`;
   - `inst/design/README.md`, when present, lists any new, moved, or
     retired design files and keeps the current-cycle pointer accurate;
   - any cycle-specific instructions that will become stale after release are
     either updated during the release gate or explicitly scheduled as the first
     prep task for the next cycle.
4. Run the local WSL/Ubuntu gate for any change touching executable R code,
   DuckDB persistence, snapshots, file paths, time zones, vignettes, pkgdown, or
   CI.
5. Push the branch and wait for branch CI.
6. Merge to `main` only after branch CI is green.
7. Wait for `main` CI to be green on both workflows.
8. Move the release tag only after `main` is green.
9. Wait for the tag-triggered CI. The tag is not release-valid until its own CI
   is green.

## Design Index Maintenance

`inst/design/README.md` is the canonical map of design documents once it exists.
Keep it current as part of ordinary work, not only at release time.

When adding, moving, renaming, or retiring any cross-cycle design document:

1. Update `inst/design/README.md` in the same change, or record why the document
   is intentionally not indexed.
2. Update `AGENTS.md` if the active packet, current-cycle pointer, or agent
   startup reading order changes.
3. Update path references in affected design documents.
4. At the latest, verify the design README during the release gate before merge
   and tagging.

Versioned spec packet internals do not need every file listed individually, but
the active packet directory itself should be discoverable from the design index.

## Tag Handling

Use tags deliberately. A tag push is a release candidate, not a proof of
release readiness.

```sh
git rev-parse HEAD
git rev-parse vX.Y.Z
git tag -f vX.Y.Z <green-main-commit>
git push --force origin vX.Y.Z
```

After pushing the tag, check the tag run directly:

```sh
gh run list --repo blechturm/ledgr --limit 8
gh run view <run-id> --repo blechturm/ledgr
```

Avoid open-ended polling. Prefer periodic status checks, or use
`gh run watch <run-id> --exit-status` only when you are prepared to wait through
the whole run.

## Ubuntu and DuckDB Triage

When Ubuntu CI fails around experiment-store behavior:

1. Pull the failed job log with `gh run view --log-failed`.
2. Identify whether the failure is:
   - an R assertion failure;
   - a DuckDB native abort;
   - a coverage-only abort after `R CMD check` passed.
3. Reproduce locally under WSL/Ubuntu with the same class of command:
   - targeted `testthat::test_file()` for a named failing test;
   - full `testthat::test_local()` for cross-test interactions;
   - `rcmdcheck::rcmdcheck()` for installed-package behavior;
   - `Rscript tools/check-coverage.R` for coverage-only failures.
4. If fresh connections miss writes, inspect checkpoint placement. User-facing
   metadata mutations that must be visible to later reads should checkpoint
   strictly before returning.
5. If a query crashes in native DuckDB code, simplify the SQL shape before
   trying to tune timing. Prefer simple reads plus R-side enrichment over a
   release-blocking complex query.

Do not weaken tests just because Ubuntu exposed the issue. If the assertion is
about ledgr's persistence contract, fix the persistence path.

### Local WSL/Ubuntu DuckDB Gate

For changes touching DuckDB persistence, schema creation or validation,
snapshots, low-level CSV workflows, executable vignettes, pkgdown, file paths,
time zones, or release CI, run a narrow Linux gate before pushing when WSL or
another local Ubuntu environment is available.

The minimum DuckDB-sensitive gate is:

```sh
Rscript -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-schema-validator-side-effects.R')"
Rscript -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-schema-snapshots.R')"
Rscript -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-schema.R')"
Rscript -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-persistence-fresh-connection.R')"
```

If the ticket touched executable documentation or pkgdown-sensitive examples,
also run the narrow documentation path that owns the changed example, or a local
pkgdown build when the example owner is not obvious.

This local Linux gate is early warning only. It does not replace branch CI,
`main` CI, or tag-triggered CI. A local WSL pass is useful evidence; it is not a
release certificate.

### Release-Gate Debugging Guardrails

Remote CI logs define the initial scope. Before editing, record the first
package stack frame and the smallest owning file. The first fix attempt should
stay inside that file and its direct tests unless a minimal reproduction proves
the issue lives elsewhere.

Use this sequence for release-gate failures:

1. Fetch the failed remote log before changing code:

   ```sh
   gh run view <run-id> --repo blechturm/ledgr --log-failed
   ```

2. Write down a one-sentence hypothesis:

   ```text
   The failure is caused by X because Y.
   ```

3. Run the narrowest reproduction first:
   - the exact failing test file;
   - the exact failing test file under targeted `covr` if coverage failed;
   - then the related subsystem tests;
   - only then broader gates.
4. Keep release-gate fixes small. A typical release-gate correction should touch
   one production file and one direct test file. If the fix expands beyond three
   production files, stop and request review before continuing.
5. Do not make broad DuckDB persistence, snapshot, or runner changes unless the
   failed stack points there directly or a minimal reproduction proves that
   subsystem owns the failure.

Full local WSL runs are useful evidence, but they can be noisy. A broad local
failure should not override the first remote stack frame unless the local run
reproduces the same failing path.

### Ubuntu CI Surgery Stop Rule

Ubuntu CI doing its job is not a reason to perform live release-gate surgery.
If making Ubuntu green appears to require broad changes to schema creation,
schema validation, snapshots, persistence, runner behavior, or other core
infrastructure, stop immediately. Do not continue editing toward a green run.

Create a blocker ticket before touching more production code. The ticket must
include:

- the failed CI run id and first package stack frame;
- the exact failing command or narrow local reproduction;
- the smallest known evidence for the suspected root cause;
- the files believed to own the problem;
- a definition of done, including the targeted tests and remote gate that must
  pass;
- a rollback or containment plan if the fix expands.

The release gate should verify release readiness. If it uncovers a design issue,
the correct response is deliberate design work with review, not speculative
editing across the codebase. The release tag is not valid until the blocker is
resolved and the required release gates are green.

### DuckDB Constraint Probe Rule

Runtime schema validators must be read-only. They inspect table and constraint
metadata; they do not intentionally write invalid rows into ledgr tables to
prove constraints are enforced. Constraint enforcement belongs in isolated
tests that own their disposable database connection.

If a test or isolated development helper intentionally triggers a DuckDB
constraint violation, it must leave the connection usable for the next probe. On
Ubuntu under `covr`, a caught constraint violation can leave the connection in a
dirty transaction state unless it is cleared explicitly.

Use an isolated disposable connection, or issue a safe rollback before the error
handler returns:

```r
try(DBI::dbExecute(con, "ROLLBACK"), silent = TRUE)
```

The rollback may fail harmlessly when no transaction is active. The important
contract is that an expected failed probe must not contaminate later DML on the
same connection. Runtime validators should avoid this pattern entirely.

### Stop Rule

If a release-gate debugging session starts producing edits outside the initially
failing subsystem, pause and ask for review. Do not continue accumulating
speculative fixes while the root cause is still uncertain.

## Coverage Triage

The coverage gate enforces the numeric threshold, but it also reruns tests under
instrumentation. For v0.1.7.2, Ubuntu occasionally aborted in native code during
this coverage run even when:

- README cold-start passed;
- acceptance tests passed;
- `R CMD check` passed;
- pkgdown passed;
- local Ubuntu coverage passed.

The CI coverage step therefore retries up to three attempts. This is acceptable
only for coverage-run native aborts. It is not a substitute for fixing package
test failures or `R CMD check` failures.

If all coverage attempts fail, treat it as a release blocker and inspect the
failed log. Do not lower the coverage threshold to pass a release.

## What Counts as Green

A release tag is ready only when all of the following are true:

- local Windows or primary development checks passed;
- local WSL/Ubuntu gate passed when the ticket touched OS-sensitive behavior;
- `AGENTS.md` points to the active design context for the release or the next
  prep cycle, and does not contain stale active-cycle instructions;
- `inst/design/README.md`, when present, reflects all design-document additions,
  moves, removals, and current-cycle context;
- `main` `R-CMD-check` workflow is green;
- `main` pkgdown workflow is green;
- tag `R-CMD-check` workflow is green;
- no failed run remains unexplained as a real package failure.

Old failed runs can remain in the GitHub history. They are acceptable only when
a newer run on the same intended release commit or tag is green and the failure
mode is understood.
