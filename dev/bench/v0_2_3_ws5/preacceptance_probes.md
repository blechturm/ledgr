# Pre-acceptance probes

Base authority: `14252ffb`. The bounded probes were public-API probes and did
not reconstruct a private first-pulse context.

- Typed round trip: a whole-number double survived, an integer returned as a
  double, and typed empty atomic values returned as untyped lists. Ownership:
  LDG-3185/3186; no WS5 workaround.
- Unchanged-tail/finalisation resume: the sparse state row doubled as a cursor
  and resume restarted after the last state change. Ownership: LDG-3186; the
  accepted cursor design remains required.
- Call counts over five pulses: five strategy contexts, five state encodes and
  five state writes. WS5 retains one context view per pulse and makes columns
  lazy within that view; state encode/write ownership remains LDG-3186.

