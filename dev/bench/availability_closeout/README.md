# Availability Closeout Runner

This internal runner records the v0.2.0.1 Stage H availability clocks over the
registered 563-instrument, 757-pulse fixture. It uses only the production
provider and diagnostic paths.

From the repository root:

```powershell
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" dev/bench/availability_closeout/availability_closeout.R all
```

The runner refuses tracked worktree changes and refuses to overwrite an
existing record. Raw records remain ignored under `dev/bench/results/`. The
cold clock starts before deterministic fixture preparation and ends after the
snapshot is sealed. Each warm clock surrounds `ledgr_run()` over a copy of the
same sealed snapshot; provider construction remains inside that warm clock.

The record contains one cold seal, one warm-up, three measured warm runs, and
one profiled warm run. Working set is sampled externally for every child. The
script fails if the production median exceeds 60 seconds, a measured warm peak
exceeds 1,024 MiB, the expected durable row counts differ, or a retired
test-only pairwise reference appears in the installed package namespace.

This is internal release evidence. It is not a public performance or peer
ranking claim.
