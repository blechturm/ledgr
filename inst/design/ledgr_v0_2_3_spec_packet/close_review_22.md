# Workstream 22 Close Review

**Mode:** Type 1 close review (independent, clean context)
**Verdict:** CHANGES_REQUIRED
**Range reviewed:** `04fac1bf..c817de49` (product `b87b230c`, `9a3b3f2a`)

The product change is correct, and this review does not reopen the direct
materialization design. Old and new code give identical results on every
case probed, the production P2 path performs no timestamp parse, and the
timing and allocation evidence reproduces. The required changes are bounded
to one detector gap and to evidence provenance. No product code change is
required.

## Findings

1. **F1, medium: the LTB-0549 timestamp witness only catches the
   spelling `ledgr_utc`.**
   `tests/testthat/test-feature-inspection.R:449-466`.
   The test rejects the strings `ledgr_utc`, `as.POSIXct` and similar in the
   deparsed long, wide and time-helper bodies. A parse reached through any
   other function passes it. Two mutations passed the whole file, and both
   reparse the timestamp on every call:
   - long: `ts_utc = rep(ledgr_pulse_inspection_time(list(cutoff_num =
     ledgr_pulse_context_fixture_cutoff(pulse$ts_utc))), n)`;
   - time helper: `cutoff <-
     ledgr_pulse_context_fixture_cutoff(ledgr_iso_utc(<cutoff as POSIXct>))`.

   The new `ledgr_pulse_context_fixture_cutoff()` makes this the obvious
   regression, because it is an existing one-line parse that the grep cannot
   see. LCL-0538 lists "Use the pulse timestamp string" as its smallest
   failing change. LDG-3198 acceptance requires that "changing the ... prepared
   timestamp fails a registered block". Neither is demonstrated yet. The same
   indirection also hides the guarded fallback from LTB-0547's attach-source
   grep. A run probe confirms that production never takes the fallback (0
   calls over a 30-pulse run with inspection in the callback, and 0 for
   `ledgr_pulse_snapshot()`), but no registered block pins this.
   *Minimal fix:* add two behavioural assertions to LTB-0549. (a) Make a
   second lookup copy with `cutoff_num` moved by `+86400`. Assert that
   `ledgr_pulse_features()$ts_utc` and `ledgr_pulse_wide()$ts_utc` follow the
   moved value, not `pulse$ts_utc`. (b) Build the test pulse inside
   `testthat::with_mocked_bindings(ledgr_pulse_context_fixture_cutoff =
   function(...) stop("P2 must not parse"), .package = "ledgr")`. This
   strengthens the test, so record the reason in the ticket evidence. It does
   not change an oracle.

2. **F2, low: evidence provenance is incomplete.**
   - `dev/spikes/pulse_inspection_materialization/record.csv` and
     `probe_findings.md` do not name the source commit of either Rprofmem arm
     or the command that reproduces them, which `rfc_cycle.md` "Evidence and
     findings" requires. `probe_findings.md:15-17` also still cites the
     initial timing pair `04fac1bf`/`68799f1b`, not the final record. The
     values themselves reproduce exactly: base `04fac1bf` gives 168482.4 /
     1341018.4 bytes, and candidate `9a3b3f2a` gives 167618.4 / 726690.4
     bytes, with equal dimensions and sums.
   - LDG-3198 evidence (`tickets.yml`, first evidence line) credits the
     `R/pulse-context.R` cutoff preparation to `b87b230c` alone. The
     projection-branch fallback, which two existing tests at `b87b230c`
     needed, is in `9a3b3f2a`.
   - The source-tarball R CMD check reported for this cut (no-build-vignettes
     tarball, only the two expected missing-`inst/doc` vignette warnings)
     appears in neither the LDG-3199 evidence nor the closeout. LDG-3199 scope
     names "source checks".

   *Minimal fix:* add both commits and the probe command to
   `probe_findings.md`, and point its timing sentence at `cut10-final`. Name
   `9a3b3f2a` in LDG-3198 evidence. Add one LDG-3199 evidence line for the R
   CMD check result and its two expected warnings.

3. **F3, low, pre-existing and not a Cut 10 blocker:
   `ledgr_pulse_wide()` on a nonempty universe with zero features fails with
   an untyped base error.** `R/feature-inspection.R:521`.
   `paste0("feature_", character())` returns `"feature_"`, so the names have
   length `n*6` but the values have length `n*5`. Both
   `ledgr_pulse_snapshot(snapshot, universe = ids, ts_utc = ...)` without
   features and a featureless fixture context raise `'names' attribute [12]
   must be the same length as the vector [10]` (`simpleError`). Base
   `04fac1bf` fails the same way. Cut 10 preserves it correctly, because its
   `out_of_scope` forbids changing empty or error semantics.
   *Minimal fix:* none in Cut 10. Record it for a later cut. The likely repair
   is `paste0("feature_", feature_keys, recycle0 = TRUE)` together with a
   typed-empty test.

## Clean

- **`ledgr_pulse_features()`:** the map is resolved once
  (`ledgr_pulse_inspection_feature_map`). Each feature vector is read once:
  the counted wrapper reports 2 calls for 2 features, and the double-read
  mutation is caught. The timestamp comes from `lookup$cutoff_num` through a
  numeric `structure()` with no parse. Mapped, unmapped, explicit
  `ledgr_feature_map`, named character map, alias-name map, unknown-ID
  refusal, delimiter-alias, empty-universe, zero-feature, fixture and retained
  contexts are all identical to base.
- **`ledgr_pulse_wide()`:** it does not call the long helper, does not pivot,
  `rbind` or build a long table, and constructs one `new_tibble(nrow = 1L)`.
  Radix instrument blocks, map/alias keys, unmapped concrete IDs, values,
  `ts_utc`/`cash`/`equity`, the delimiter refusal and the empty-universe
  `1x3` result are all identical to base.
- **Fixture fallback (`R/pulse-context.R:359-361, 393-397, 457-458`):** it
  runs only when `cutoff_num` is NULL or non-finite. Production
  `ledgr_fold_stage_decide()` passes the numeric `packet$ts`. Traced fallback
  calls were 0 over a run and over `ledgr_pulse_snapshot()`. At `b87b230c`,
  the existing tests `projection contexts manifest inspection only on demand`
  and `[LTB-0089]` fail. At `9a3b3f2a` they pass with no test change.
- **Detector sensitivity (12 mutations, the full test file each time):**
  caught were a direct `ledgr_utc(pulse$ts_utc)`, transposed interleave,
  reversed aliases, general `tibble()` construction, a double vector read,
  wide calling long, a dropped wide row reorder, aliases replaced by IDs, and
  a per-column append loop. Only the two indirect-parse mutations of F1
  survived.
- **Seven shapes:** there are no per-element frames or `rbind` (1), no
  full-table subset per ID (2), no per-element parse (3, now none at all), no
  JSON (4), no discarded or repeated preparation (5), no pairwise validator
  (6), and no environment-vector scalar writes (7). The only loops are
  `lapply()` over the requested features and over the five fixed OHLCV fields.
  Two nits need no change: wide recomputes `match(instruments,
  lookup$universe)` once per OHLCV field, a fixed 5x O(n); and the "missing
  named bar column" message now refers to unnamed lookup vectors.
- **Helper criterion:** each of the three new private helpers has two callers
  and a nameable contract.
- **Identity and contracts:** `DESCRIPTION`, `NAMESPACE`, `man/`, schema and
  contracts are unchanged. `contract-context-inspection` (no callback-cost
  promise) and the numeric cutoff on the P2 path already describe the result.
  No speed promise is added.
- **Timing record:** `cut10-final/attempt-1` raw rows pin base `04fac1bf` and
  candidate `9a3b3f2a`. The frozen protocol and harness copies are
  byte-identical to the shared ones, and every work string is equal.
- **Tests and diffs:** the existing tests are unchanged (LTB-0549 is only
  added). `git diff --check` is clean.

## Commands and probes

- `Rscript dev/bench/timing/check.R --protocol=dev/bench/timing/protocols/cut10-pulse-inspection-1 --record=dev/bench/timing/records/cut10-pulse-inspection-1/cut10-final/attempt-1`:
  CHECK PASS. The long ratio is 0.08076 against a bound of 0.40, and the wide
  ratio is 0.06291 against 0.25. There is no `check.R` inside the protocol
  folder; the shared checker was used.
- `Rscript dev/spikes/pulse_inspection_materialization/check.R .../record.csv`
  printed `..._CHECK_OK`, and `gut.R .../record.csv` printed `..._GUT_OK`.
- `probe.R` was rerun on base `04fac1bf` and candidate `9a3b3f2a`, and the
  allocation record reproduces exactly.
- A differential probe compared base and candidate over 41 case pairs
  (mapped, unmapped, explicit maps, refusals, zero features, eight retained
  run contexts, fixtures, empty universe and non-pulse input). All 82 outputs
  or conditions are `identical()`.
- The eight focused files from the closeout, plus availability-economics,
  pass at head.
- The full `test_local` at `9a3b3f2a` (tests equal to head) has 4 failing
  tests: LTB-0408, LTB-0416, LTB-0247 and sweep-retention reserved-id
  escaping. All four fail identically at base `04fac1bf` in the same
  environment, so they are environmental and unrelated to Cut 10.
- Mutation runs and traces were done in disposable worktrees under
  `C:/Users/maxth/ledgr-wt/`.

## Tickets

- **LDG-3198:** the product is accepted. Completion waits on F1 (the
  behavioural cutoff witness) and on the F2 commit attribution.
- **LDG-3199:** the product is accepted. Completion waits on the F2
  evidence lines (allocation provenance and the R CMD check record). F3 is
  recorded only.
