# Test execution

Use the one profile runner for ordinary membership:

```sh
Rscript --vanilla tools/run-test-profile.R --profile=fast --mode=ordinary
Rscript --vanilla tools/run-test-profile.R --profile=review --mode=ordinary
Rscript --vanilla tools/run-test-profile.R --profile=fast --mode=ordinary --records=.test-evidence/ordinary --run-index=1
Rscript --vanilla tools/check-test-gate.R --profile=fast --mode=ordinary --records=.test-evidence/ordinary
```

`fast` is the default block profile. `review` is the only other ordinary
profile. A mixed file puts `# ledgr-test-profile: review` or
`heavy_protocol` immediately before a block. A homogeneous non-fast file uses
one `# ledgr-test-file-profile:` declaration. Unknown, orphaned, malformed, or
contradictory metadata fails before tests run.

CRAN mode executes the exact `fast` membership from a recorded isolated
library and a read-only working directory:

The CI workflow shows the portable isolated-CRAN invocation. It prepares an
empty library, exports its recorded manifest and a read-only work directory,
runs this same runner with `--mode=cran`, then applies the CRAN clock.

The ordinary fast gate is the same command with `--mode=ordinary`. It fails
above 90 seconds. If run 1 reports `exceeded=true`, run indices 2 and 3 in
fresh processes before the checker applies the registered median rule. Inspect
the retained census and timings; do not widen the bound, drop selection, or
remove the measured full-collection checkpoint that stabilizes collector debt.

Heavy tests are outside ordinary membership. Their owner, invocation, and
diff-based checker are in `heavy-protocols.yml`; run the registered protocol:

```sh
Rscript --vanilla tools/run-heavy-protocol.R --protocol=full-heavy
```

`claims.yml` registers declared load-bearing claims by immutable `[LTB-nnnn]`
block prefixes. It is bounded authority, not a complete list of guarantees.
Every run reconciles static expected selection with reporter-observed execution;
skips are recorded, and a claim cannot rely only on skipped blocks.

Rules: close DuckDB/run resources and write only under session temp; keep
oracles independent of versions, timestamps, and unseeded draws; mocks isolate
dependencies but never supply asserted values; frozen fixtures name regeneration
commands that do not run the guarded implementation. No checker or review
requires an inline `Oracle` comment.
