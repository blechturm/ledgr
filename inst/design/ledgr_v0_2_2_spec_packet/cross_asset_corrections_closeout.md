# Workstream 59 closeout: cross-asset correctness and honest defaults

## Outcome

LDG-3106 through LDG-3108 implement three bounded, vendor-neutral corrections.
They do not add crypto-specific policy or claim crypto support.

- A fill that closes a FIFO lot within the existing dust tolerance now leaves
  canonical position state at exact zero in the live fold, compiled spot-FIFO
  batch and deterministic replay.
- An omitted metric calendar retains the existing US-equity computation and
  identity but its hash-excluded display label says `(default)` everywhere the
  current public surfaces disclose that calendar.
- The four existing corporate-action fidelity headlines now begin `Economic
  events`; their states, suffixes, data and public summary API are unchanged.

## Correctness boundary

Dust normalization happens inside the FIFO accounting transition. Each lot
mutation updates the instrument's net from the actual pre- and post-mutation
lot quantities; canonical position is then projected from that post-transition
book. An empty book is exactly zero, while a live residual lot remains held.
There is no independent position tolerance or reader-side cleanup.
Reconstruction, resume and carried state consume the same canonical replay.
The compiled batch carries the canonical per-instrument net across its native
boundary and through successive batches; it neither reconstructs that value by
resumming lots nor performs a different floating-point sequence.

The calendar marker is presentation provenance. It is captured when a public
constructor omits `calendar`, serialized in the existing display label and
excluded from the existing metric payload and hashes. Explicit US-equity and
crypto calendars remain unmarked. There is no schema, record-shape, format or
compatibility change.

The headline rename covers only the existing `not_supplied`, `none`, `modeled`
and `unsupported` fidelity states. Token, derivative, funding, tax and other
new event semantics remain out of scope.

## Detecting evidence

- LCL-0488 / LTB-0497 exercises public dense and availability runs with two
  adversarial multi-lot shapes: one truly empty book and one live residual
  lot. It checks reconstruction, replay, reopen and a later lifetime terminal.
- LCL-0489 / LTB-0498 pins the ordinary and compiled FIFO boundary, including
  an exact five-fill partial close in one native batch and five successive
  batches, public compiled-sweep parity and the production call sites.
- LCL-0490 / LTB-0499 covers every public omission and explicit-calendar form,
  payload and hash equality, experiment/run disclosure, persistence, sweep,
  promotion and walk-forward identity.
- LCL-0491 / LTB-0500 pins all four exact asset-neutral headlines, preserves
  `ledgr_corporate_action_summary()` and rejects the retired prefix in current
  product source.

The paired record under `dev/bench/v0_2_2_cross_asset_corrections/` compares
the pre-cut and candidate trees. Its checker reports unchanged event,
configuration, cash and numeric-metric evidence, exact-zero position state,
the one calendar marker and the one headline-prefix change.

## Resource shape

The seven optimization shapes were walked. The accounting change performs one
existing instrument lookup and scalar updates while each lot is mutated. It
does not allocate a per-fill vector, add a second lot scan or create a growing
object. The compiled path reuses the same transition net rather than rescanning
the book after mutation. The display changes add no fold work. No new query
loop, per-row frame, JSON hot path or cache was introduced.

The registered 40,000-event replay clock under
`dev/bench/v0_2_2_cross_asset_corrections/` records a 1.630-second median for
the first-review implementation and 1.420 seconds after the correction on the
same host. The correction is therefore about 13% faster than the rejected
allocation-heavy helper as well as semantically stronger.

## Oracle migrations

- The availability frozen-row fixture parses both metric-context records,
  normalizes only the accepted calendar display label, and requires every
  other member to remain identical. Extra record members therefore fail.
- LTB-0209 replaces the former nonzero dust expectation with exact zero and
  retains an independent replay oracle; restoring cumsum-based pulse positions
  remains a detecting mutation.
- LTB-0019 changes its near-zero accounting comparison from relative equality
  to an explicit absolute bound, because relative tolerance is undefined at
  the zero boundary this workstream makes exact.
- LTB-0217 replaces the deleted private position-only-helper comparison with a
  canonical replay comparison on interleaved whole and fractional fills.
- The result-output line count increases only for the accepted `Metric
  Calendar` disclosure line.
- Metric-context and backtest S3 text fixtures change only the accepted
  `(default)` display marker.
- Corporate-action result and documentation strings change only the accepted
  `Economic events` headline prefix; state and structured summaries remain
  pinned separately.

## Verification

The corrected focused file passes 69 expectations. The ordinary fast profile
passes 577/577 blocks in three runs with a 109.08-second median against the
unchanged 112-second bound. The review profile passes 437/437 blocks with one
established optional-path skip, and the registered full-heavy protocol passes
192/192 blocks.

The source package builds. `R CMD check --no-manual --no-build-vignettes`
passes installation, namespace, Rd, examples and tests. It reports the existing
unqualified `head()` NOTE and no-built-vignette warnings; its vignette execution
also reports that the local R 4.6 library lacks the suggested `tidyr` package.
The separately recorded review profile uses the compatible local R 4.5 library
behind R 4.6 and executes that claim successfully.

The fold-phase checker and the codebase-contract checker in blocking mode pass;
the latter records 1,877 helpers with no orphan-helper finding. The claims and
ticket catalogues parse, and `git diff --check` is clean.
