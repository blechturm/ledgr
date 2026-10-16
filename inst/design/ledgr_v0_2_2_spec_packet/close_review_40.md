# Workstream 40 Type 1 close review

Review tree: `ae88df62` (product commit `80c86012`)

Verdict: **CHANGES_REQUIRED**

The independent review found the factual and identity architecture sound, but
found two Date-boundary defects, one dense-economics acceptance conflict, four
failure-sensitivity gaps, two bounded-cost record errors and one integer
validation defect. The reviewer edited no repository file.

## Findings

1. **F1, high: Date-backed walk-forward folds leaked UTC midnight.** The
   experiment-window helper resolved the civil values, but the carry guard,
   persisted fold rows and reopened train scoring range used raw fold values.
   Contiguous New York Date folds could therefore refuse as gapped.
2. **F2, medium: explicit Date boundaries in feature precomputation leaked UTC
   midnight.** On an availability experiment the end boundary could exclude
   the named session instead of resolving to that session's close.
3. **F3, medium, maintainer decision: dense corporate-action economics
   changed.** Filling a missing knowledge clock from the event clock is a
   mode-neutral v12 fact rule. A dense dividend that was audit-only on the
   pre-cut tree now posts. Preserving the old dense result would require the
   execution-mode branch prohibited by `AGENTS.md`; the ticket nevertheless
   promised no dense economic change.
4. **F4, medium: the production clock-missing refusal was not pinned.** Removing
   the fold's `check_clocks()` call left every registered suite green even
   though public run and sweep no longer refused.
5. **F5, medium: `output_carry` and `segment_limit` were not pinned in config or
   precompute identity.** The implementation was correct, but dropping those
   fields from identity passed the registered tests.
6. **F6, medium: rule-4 golden roots contained no populated civil-time
   evidence.** The corpus stored only `"{}"`, so cross-platform timezone drift
   could pass. The record also attributed every rule-3 root change to civil
   bytes although the rule-4 domain separators change fact-free roots.
7. **F7, low: effective-end and knowledge Date resolution were not pinned.** A
   mutation resolving `effective_to` at session close passed.
8. **F8, low: LCL-0286 overstated its cutoff detector.** A collapsed
   `pmax(effective, knowledge)` cutoff is logically equivalent to testing both
   inequalities. The distinct prepared fields themselves lacked an oracle.
9. **F9, low: the seven-shape record was inaccurate.** Civil resolution used a
   row-wise timestamp formatter; POSIX-only bundles revalidated and rehashed
   because `"{}"` counted as civil evidence; lineage is recomputed at bounded
   construction and provider-preparation boundaries rather than once globally.
10. **F10, low: ages above `.Machine$integer.max` passed validation and became
    `NA_integer_` in identity with a warning.**

## Record-only routing

- Date-backed corporate-action event clocks currently resolve to session open,
  while availability execution pulses are session close. Which edge the civil
  event date names is a product decision for LDG-3060; Workstream 40 must not
  guess it.
- The pre-CRAN-removal census metadata used `ws40-working-tree` rather than the
  product commit. The reproduced census bytes were otherwise exact.
- Ubuntu rule-4 evidence was pending because the integration branch had not
  been pushed. Populated civil roots must be present before that run is useful.

## Checked and clean

- The correction-chain graph, precedence order, same-assertion exemptions,
  revival, cycle and dangling-link refusals match v12.
- Rule-3 config, sweep and walk-forward artifacts, missing markers and
  schema-120 stores refuse without migration or fallback.
- Precompute refuses a changed history identity before candidate execution.
- Dense history identity is mode-neutral and carries no execution-mode branch.
- Twenty-eight focused suites passed at the reviewed tree. The registered fast
  record passed 565/565 blocks with a 110.50-second median against 112 seconds;
  review passed 353/353 with one pre-existing optional-package skip.
- Both YAML files parsed, the current-only census passed and `git diff --check`
  was clean.

The correction round owns F1, F2 and F4-F10. F3 requires the maintainer to
accept the uniform v12 rule and amend the stale dense-parity criterion, or send
that question to Type 2.
