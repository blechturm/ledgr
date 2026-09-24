# Terminal Disposition Policy Spike Inventory

## Question And Boundary

The spike asked whether the public availability run can replace the existing
terminal stop with one configured last-permissible-mark disposition, finish,
resume and reopen while reporting the approximation. It did not choose a
default policy, a public API or a settlement event vocabulary.

The harness copies tracked package source to scratch and inserts one
option-controlled branch immediately before the existing terminal stop. The
rest of the provider, valuation, strategy, FIFO accounting, event writer,
finalizer, result readers and reopen path are production code.

The prototype writes an ordinary zero-fee `SELL`. That proves the existing
accounting primitives can express the economic effect. It does not prove that
a modeled terminal disposition should be represented to users as an exchange
fill.

## Executed Cases

Five aggregate cases are recorded in `evidence/cases.csv`:

- strict control;
- current permissible mark;
- one-session stale permissible mark;
- missing current mark with staleness forbidden;
- interruption before the terminal pulse, then resume and reopen.

The direct and resumed current-mark surfaces are compared in
`evidence/resume_parity.csv`. Identity fields alone are excluded.

## Learned

The single seam was sufficient. Current and allowed-stale dispositions both
reached `DONE`, sold the full two-unit holding at 100, moved cash from 1000 to
1200, left the position at zero and emitted one approximation diagnostic.
That diagnostic retained mark source and age, before and after quantities,
event sequence and the prototype policy identifier.

With no permissible mark, the policy proposed nothing and the existing
`terminal_settlement_unsupported` stop remained intact. Strict mode produced
the same stop. No price was invented in either case.

The resumed run first stopped in `RUNNING`, then completed with exactly one
sale. Run, completion, diagnostic, event and equity surfaces were identical to
the uninterrupted case after run and event identities were excluded. Every
recorded surface was identical after reopen.

The equity result also shows why approximation reporting is not cosmetic.
Strict and modeled paths both end at 1200 in this constant-price fixture, but
only the modeled path converts the holding into cash and completes the later
pulses. Outcome equality does not make the policy invisible.

## Demoted And Deleted

Demoted: the claim that usable terminal handling necessarily needs a new
accounting primitive or a multi-leg settlement design. One ordinary FIFO
close is mechanically enough for the configured-disposition question.

Deleted: any inference that this proves a default, that a synthetic sale is a
broker-exact fill, or that a permissible mark is always available. The
markless case refutes the last claim directly.

## Gut

The checker disables only the inserted disposition condition. In both the
current and resumed cases the run reverts from `DONE` to `INCOMPLETE`, the sale
and approximation row disappear, and cash stays at 1000 rather than 1200.
Equity remains 1200 because the holding is preserved and marked. The checker
asserts each field, not merely a changed file.

## Reproduction

From the repository root with R 4.6.1:

```text
Rscript dev/spikes/terminal_disposition_policy/spike_runner.R
Rscript dev/spikes/terminal_disposition_policy/spike_checker.R
```

Both commands operate through scratch forks. No production package file is
edited by the runner or checker.
