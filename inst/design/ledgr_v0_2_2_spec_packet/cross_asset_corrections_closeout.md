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

Dust normalization happens at the accounting transition, after FIFO state is
known. It changes neither the literal fill nor the ledger event and introduces
no reader-side cleanup. Reconstruction, resume and carried state consume that
canonical result. The compiled batch uses the same scale-sensitive tolerance
inputs for position and lot net.

The calendar marker is presentation provenance. It is captured when a public
constructor omits `calendar`, serialized in the existing display label and
excluded from the existing metric payload and hashes. Explicit US-equity and
crypto calendars remain unmarked. There is no schema, record-shape, format or
compatibility change.

The headline rename covers only the existing `not_supplied`, `none`, `modeled`
and `unsupported` fidelity states. Token, derivative, funding, tax and other
new event semantics remain out of scope.

## Detecting evidence

- LCL-0488 / LTB-0497 exercises public dense and availability runs with the
  exact fractional residue, reconstruction, replay, reopen and a later
  lifetime terminal.
- LCL-0489 / LTB-0498 pins the ordinary and compiled dust boundary and the
  three production call sites.
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

The seven optimization shapes were walked. The accounting change is O(1) per
existing transition and allocates no growing object. The display changes add
no fold work. No new scan, query loop, per-row frame, JSON hot path or cache was
introduced.

## Verification

The focused correction file passes 45 expectations. The ordinary fast profile
passes 577/577 blocks in three runs with a 108.99-second median against the
unchanged 112-second bound. The review profile passes 437/437 blocks with one
established optional-path skip, and the heavy profile passes 192/192 blocks.

The source package builds. `R CMD check --no-manual --no-build-vignettes`
passes installation, namespace, Rd, examples and tests. It reports the existing
unqualified `head()` NOTE and no-built-vignette warnings; its vignette execution
also reports that the local R 4.6 library lacks the suggested `tidyr` package.
The separately recorded review profile uses the compatible local R 4.5 library
behind R 4.6 and executes that claim successfully.

The fold-phase and codebase-contract checkers pass, the claims and ticket
catalogues parse, and `git diff --check` is clean.
