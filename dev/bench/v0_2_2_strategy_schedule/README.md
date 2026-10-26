# Strategy schedule evidence

This directory records the vendor-neutral evidence for Cut 21. Workstream 60
introduces declarations and pre-fold compilation only; fold skipping and
durable formats belong to later workstreams.

## Workstream 60 fixture record

`evidence/ws60/pre.csv` and `candidate.csv` are aggregate family hashes from
the registered real-data-scale fixture recorder. The corresponding phase files
are descriptive clocks, not performance gates.

- pre-cut product: `42ddf3aa`;
- candidate product: `8c5cbc39`;
- fixture: 800 instruments, 1,260 sessions and 300 active members;
- command: `run_record.R <tree> <record>` on each tree, then
  `check_record.R <pre> <candidate>`;
- result: 50 of 50 gated families byte-identical and the informational identity
  family identical;
- checker self-test: 51 of 51 family corruptions detected alone.

The first candidate attempt at `8a00a3be` was rejected: merely touching the
attributes of an unscheduled function changed its captured source and therefore
walk-forward candidate identity. Commit `8c5cbc39` returns an ordinary function
unchanged and restores an implicitly classed scheduled function without leaving
an explicit `class = "function"` attribute. The retained aggregates are from the
corrected record only.

## Compiler shape

A seven-repetition synthetic clock over 7,213 weekday sessions recorded a
0.030-second median for a month-start declaration with 331 decision pulses.
This is a bounded diagnostic of once-per-run preparation, not a public speed
claim. The compiler uses vector operations over the parent axis, allocates one
logical verdict, and performs no pulse-loop calendar work.
