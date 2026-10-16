# Workstream 41 local-worker transport record

This record measures serialized task shape, not process RSS. The runner builds
one eight-session availability fixture and a six-candidate public sweep, then
captures the real task list immediately before and after the production
history-staging boundary. `package_head` is the committed parent from which
the candidate working tree was built; the eventual implementation commit is
recorded in the ticket and closeout. The staged total is the compact candidate-task list
plus one immutable invariant. R object-size accounting is the same in both
arms and is used only as a payload-shape estimate.

Reproduce from the package root with:

```powershell
& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" `
  dev/bench/v0_2_2_history_substrate/worker_transport.R . `
  dev/bench/v0_2_2_history_substrate/evidence/ws41_worker_transport/transport.csv
```

The runner also executes the same candidates sequentially and requires the
candidate rows to match the two-worker result on status, equity, trades, seed,
risk identity and errors. Worker memory and resource scaling remain owned by
LDG-3069; this record supplies its staged-byte input without claiming an RSS
improvement.
