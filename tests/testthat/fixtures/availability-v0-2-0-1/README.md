# Availability v0.2.0.1 Frozen Witnesses

These seven CSVs are historical, reviewed v0.2.0.1 evidence. Regeneration
copies the recorded blob from immutable release-closeout commit `3f1605d`; it
does not execute the current provider, fold, writer, or finalizer that the
fixtures guard.

Run the named command from the repository root.

| Fixture | Regeneration command |
| --- | --- |
| `completion.csv` | `Rscript dev/regenerate-availability-v0-2-0-1-fixture.R --file=completion.csv` |
| `diagnostics.csv` | `Rscript dev/regenerate-availability-v0-2-0-1-fixture.R --file=diagnostics.csv` |
| `equity.csv` | `Rscript dev/regenerate-availability-v0-2-0-1-fixture.R --file=equity.csv` |
| `events.csv` | `Rscript dev/regenerate-availability-v0-2-0-1-fixture.R --file=events.csv` |
| `identity.csv` | `Rscript dev/regenerate-availability-v0-2-0-1-fixture.R --file=identity.csv` |
| `scenario-summary.csv` | `Rscript dev/regenerate-availability-v0-2-0-1-fixture.R --file=scenario-summary.csv` |
| `state.csv` | `Rscript dev/regenerate-availability-v0-2-0-1-fixture.R --file=state.csv` |
