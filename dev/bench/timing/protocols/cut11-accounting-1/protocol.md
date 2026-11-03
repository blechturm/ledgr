# Protocol cut11-accounting-1

This is the descriptive Cut 11 accounting timing preregistration owned by
LDG-3200. The immutable before arm is `0d6c0b11`. The three cells hold the
economics and inputs fixed while timing a fill-heavy durable run, a quiet
durable run and a two-candidate sweep. Each cell uses eight alternating pairs
in fresh installed processes through the shared timing harness.

The durable-run work string pins status, total event count, fill count, final
equity and a digest of the public ledger table. The sweep work string pins
candidate status and final equity. The fill-heavy cell changes every one of
20 target positions on every pulse, rather than sampling one instrument.
Elapsed time, rows, bytes and the fresh-process peak boundary are reported.
Under macro-plan rule 16 these clocks are descriptive and cannot block a
correct workstream or be rewritten after seeing a candidate result.
