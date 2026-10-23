# WS49 close review (Type 1): LDG-3087 and the whole-workstream claim, ledgr `60ae907e`, research `bc11e3a..7c805ee`

## Verdict: PASS_AFTER_PATCHES (no blocking defect; one detector gap, one memory-record gap, two handoff gaps for LDG-3088)

The private build does what LDG-3087 asks. I opened a byte copy of the main
snapshot with the pinned ledgr. It verifies cold, the hash and schema match the
record, and every sealed count matches the witness census. Every dividend reads
`assumed`. A held-parent run on the real build posts exactly one dividend
CASHFLOW per complete fact and counts the refused ones publicly. The strict
preset stops at the first held refused fact. Together with phase A
(`close_review_49a.md`), the Workstream 49 claim holds. The four findings below
change no sealed byte.

What holds:

- Seal, verification and identity (acceptance 1).
  - The copy's sha256 equals the original file's, and both are unchanged after
    the review.
  - `ledgr_snapshot_open(copy, verify = TRUE)` with ledgr from the scratch
    `rlib` (`LEDGR_INSTALLED_FROM_COMMIT` = `60ae907e...`) passes in 9.9 s:
    - status `SEALED`, `verified_in_process` TRUE, hash rule 4;
    - hash `e8cbb805...6430a1`, equal to the pin;
    - `experiment_store_schema_version` 123;
    - 5,481,906 bars.
  - The rerun copy also verifies cold, with the same hash. Its 57,593
    corporate-action rows (fact_id, completeness, reason, amount, all three
    clocks and provenance) are identical to the main copy's.
  - I recomputed both corporate-action digests (sorted fact_ids, and fact_id
    plus `%.17g` amount) from the sealed rows. Both equal the pins.
- Sealed census (acceptance 2 and 3), from one grouped query:

  | complete | reason | rows | parents | amount present | validated | payment time |
  | --- | --- | ---: | ---: | ---: | ---: | ---: |
  | TRUE | - | 56,658 | 919 | 56,658 | 56,658 | 0 |
  | FALSE | rounding_unresolvable | 839 | 111 | 0 | 0 | 0 |
  | FALSE | adjacent_session_step | 51 | 51 | 0 | 0 | 0 |
  | FALSE | mismatch | 31 | 13 | 0 | 0 | 0 |
  | FALSE | prior_bar_missing | 14 | 5 | 0 | 0 | 0 |

  - The table has 57,593 rows on 923 parents, all `ordinary_cash_dividend`,
    with 57,593 distinct fact_ids. The complete amounts sum to 23011.608000.
    All of this equals the record.
  - Clocks, over all rows:
    - every entitlement falls on a declared open session, at its close;
    - effective equals entitlement;
    - knowledge sits at the session open, before effective time;
    - no knowledge time is missing.
- Knowledge label (acceptance 2), checked by execution.
  - I parsed all 57,593 `provenance_json` values with one `jsonlite` call. The
    top-level keys are `knowledge`, `knowledge_reason`, `payload` and
    `source`, and only `payload` is nested. No row has a second `"knowledge":`
    key.
  - Every row reads `assumed` / `knowledge_assume_effective`. The
    implementer's vectorised regex gives exactly the parsed vectors.
  - A seeded sample of 25 rows reads 25 of 25 assumed, with knowledge at the
    session open.
  - The family metadata reads `knowledge = assume_effective` with tier
    `upstream_vintage_bound`.
- Witness census against LDG-3086 (acceptance 2).
  - I compared the committed outcomes, same-date classes, basis-rule rows and
    dispositions with LDG-3086's full-lake census JSON. That covers three
    populations, two bases, every reason and class, every basis-rule field and
    the four dispositions. There are 0 differences.
  - The gate fields agree: whole, out-of-sample and in-sample all pass, the
    gate is open, and the rule selects `split_adjusted`, which equals the
    adapter pin.
- Unit check (acceptance 4), re-run independently from the private witness
  rows and the sealed bars.
  - Keys are unique on both sides, and the sealed rows and witness events
    biject on (parent, ex-date).
  - All 56,658 complete amounts equal the vendor amount exactly and fall
    inside the closeadj step tolerance. 10,818 of them sit on parents with
    F != 1.
  - The witness's vendor-date close equals the sealed bar close for all
    57,588 rows that have a sealed ex-date bar. The 5 rows without one are
    refused.
  - All 14 refused rows with no computable step are the `prior_bar_missing`
    rows.
  - My in-memory mutations U1 (one decidable complete amount divided by F)
    and U2 (one amount times 100) each make both unit predicates count
    exactly 1.
- Checker and rerun (acceptance 4).
  - `check_build.R data` prints OK.
  - `check_build.R data <rerun aggregate-results>` prints OK.
  - `diff -rq` against the main and rerun private `aggregate-results`:
    - all 16 counted files and `environment.csv` are byte-identical;
    - only the three timing files differ, and `process_memory.csv` lives in
      `data/` only.
  - Run on the main `aggregate-results` alone, the checker fails, correctly,
    because `process_memory.csv` is not there.
  - My mutations are in the table below. Seven are killed in single-record
    mode, and all twelve are killed in rerun mode (F1).
- Public results on the real build, from a held-parent probe on the copy.
  - Setup: one parent with 11 complete and 3 refused (`rounding_unresolvable`)
    dividends after its opening date, held at 100 shares, with a fixed-basket
    universe and a hold strategy.
  - Research preset:
    - the run is DONE and `corporate_action_fidelity` reads `unsupported`,
      with 3 `unsupported_facts`;
    - `refusal_counts` equals the parent's refused facts by reason, and the
      entitled quantity is 100 per fact;
    - `sealed_refusal_counts` equals the sealed census, 935 by reason;
    - `equity_corporate_actions` is among the assumption-backed families.
  - Ledger. There are 12 CASHFLOW events: 1 is the opening position and 11
    are `corporate_action_cash`.
    - Each of the 11 has exactly one complete `source_fact_id`.
    - Each posts at its fact's ex-date close.
    - Each `cash_delta` equals the amount times 100.
    - No refused fact posts.
  - Strict preset: the run stops INCOMPLETE with
    `corporate_action_quantity_refused` at the first held refused fact's
    time.
- Governance.
  - Aggregate only. The committed folder holds:
    - aggregate counts;
    - vendor action-type codes;
    - native ledgr and canonical identities and digests.

    A search for private roots, user paths and credential words finds nothing.
  - No ledgr package change came from this ticket:
    - `ledgr-wt/ws49` is clean at `60ae907e`;
    - integration commit `398c805c` changes only `tickets.yml` (2 lines).
  - LDG-3070 is untouched. Its two files keep their 2026-10-21 mtimes, and
    their sha256 is identical at the start and end of this review.
    `run_build.R` refuses any work directory under `LDG-3070-full-proof`.
  - Paths and push state:
    - `bc11e3a` touches only the five scripts, and `7c805ee` only
      `experiments/dividend-build-v004/`;
    - the branch has no upstream, and no remote branch contains `bc11e3a`
      or `398c805c`;
    - both worktrees are clean.

    I cannot see the `--only` flag in history. The per-commit path lists are
    what it protects.

What does not hold:

- F1 (low, LDG-3087 acceptance 3-4, detector): the single-record check leaves
  several recorded aggregates unpinned.
- F2 (low, record): the memory attribution is right, but the record gives a
  weaker argument than the data supports, and the control's numbers are not
  committed.
- F3 (low, handoff; provisional default 6): if LDG-3088 runs on the main
  snapshot in place, it writes run ledgers into the LDG-3087 file.
- F4 (low, handoff for G-025): the per-event witness-implied amounts that
  LDG-3088 must compare against are not named in the handoff.

Review ratio: 4 findings over 1 completed ticket (LDG-3087) = 4.0; over its
4 acceptance items = 1.0. With phase A, Workstream 49 has 8 findings over
4 tickets = 2.0. All are recorded, not gated.

## Method

- I read:
  - AGENTS.md and the LDG-3087 brief;
  - the Cut 17 entry, decisions (1)-(20);
  - Workstream 49's claim, and LDG-3085, LDG-3086, LDG-3087, LDG-3088,
    LDG-3089 and LDG-3080's evidence;
  - `close_review_49a.md`, and `cut_review_17.md` with its re-review, at the
    LDG-3087 and memory lines;
  - commits `ae4103f`, `bc11e3a`, `7c805ee` and `60ae907e`;
  - the README, all 21 data CSVs, the five scripts, `progress.md`, the v003
    control script and the K2 mutant script;
  - `R/snapshots-list.R` and `R/backtest.R` in the `60ae907e` source export.
- Copies.
  - I made byte copies of the main and rerun snapshot files in
    `scratchpad/ws49_review/`, opened only the copies, and deleted them after
    the probes. The originals were never opened by R.
  - Mutations ran on copies of the committed CSVs.
  - R ran in one process at a time, and I did not touch `ledgr-wt/ws48`.
- Aggregates only. No vendor row, ticker, instrument identifier, date or
  amount appears here.
  - The probes print counts and booleans, plus the memory sampler's process
    numbers.
  - One over-wide probe printed ledgr's hashed fact_ids (`fact_<32 hex>`, no
    vendor identifier) into a local tool log. Nothing from it is recorded
    here.
- Probes, all in `scratchpad/ws49_review/`:
  - `probe_snapshot.R`: cold verification, the grouped census, clocks, the
    JSON-versus-regex label, digests and family metadata;
  - `probe_factid.R`: fact_id shape;
  - `probe_rerun.R`: the rerun's cold verification and row identity;
  - `probe_unit.R`: the independent unit check and U1/U2;
  - `probe_vs_3086.R`: the record against the LDG-3086 census JSON;
  - `probe_memory.R`: the 0.2 s sampler series;
  - `probe_run.R` and `probe_run2.R`: the held-parent research and strict
    runs;
  - `review_mutations.R`, with results in `review_mutation_results.csv`.

## Findings

### F1 (low, LDG-3087 acceptance 3-4, detector): the single-record check leaves recorded aggregates unpinned

Verified by execution (`review_mutations.R`). In single-record mode, these
mutations of copies of the committed CSVs pass `check_build.R`. Each fails
only in rerun mode:

- R1: corporate-action `instruments_with_facts` 923 -> 922, with one
  `51-100` histogram instrument removed. The histogram reconciliation accepts
  the consistent pair, and 923 is not a literal.
- R3: `complete_on_split_factor_not_one` 10,818 -> 10,817. The README cites
  this number, but no check reads it.
- R9: `adapter_package_commit` (`ae4103f`, the commit with the phase-A F3
  test) changed.
- R10: `declared_fact_families` loses `equity_corporate_actions`.
- R11: `snapshot_hash_rule_version` 4 -> 5. The evidence states "identity and
  hash rule 4".
- R12: corporate-action `facts_per_instrument_max` 344 -> 345. The median,
  p90, p99 and the 899 instruments with more than one row are not pinned
  either.

The snapshot hash pins content indirectly, and the rerun comparison catches
every change. So nothing recorded is wrong now. But the README and the ticket
evidence state these numbers as census results, and a later edit to the
record would pass the single-record check.

Smallest fix (`check_build.R`):

- Add to `pinned`:
  - `adapter_package_commit = "ae4103f6e6a6342c6fb5174d4a98e16420bc4fe7"`;
  - `snapshot_hash_rule_version = "4"` and `identity_rule_version = "4"`;
  - `declared_fact_families = "equity_corporate_actions+lifetime+membership+sessions"`;
  - `first_bar_date = "1998-01-02"` and `last_bar_date = "2026-09-04"`.
- After the corporate-actions `total_facts` line, pin the per-instrument
  shape:

  ```r
  need(fv("corporate_actions", "instruments_with_facts") == 923 &&
         fv("corporate_actions", "facts_per_instrument_median") == 58 &&
         fv("corporate_actions", "facts_per_instrument_p90") == 115 &&
         fv("corporate_actions", "facts_per_instrument_p99") == 121 &&
         fv("corporate_actions", "facts_per_instrument_max") == 344 &&
         fv("corporate_actions", "instruments_with_more_than_one_row") == 899,
       "corporate-action per-instrument census changed")
  need(fv("lifetime", "instruments_with_facts") == 751, "lifetime instruments changed")
  ```

- In the unit-check block, add
  `need(num(uv("complete_on_split_factor_not_one")) == 10818, ...)`.
- Add R1, R3 and R9-R12 to `mutate_check.R` as killed mutations.

### F2 (low, record): the memory attribution is right, but the record understates the evidence and the control is not committed

The claim is that dividends add about 1.9 GiB, attributed to the adapter's
lake-side projection and not to ledgr sealing.

Verified by execution (`probe_memory.R`, on the sampler series in the private
`samples/` folders). The table gives each worker's working set in GiB:

| run | stage end | peak | time of peak | last 60 s (sealing) |
| --- | ---: | ---: | ---: | ---: |
| v004 main build | 216 s | 7.89 | 153 s | max 6.12 |
| v004 rerun build | 214 s | 7.89 | 151 s | max 6.27 |
| v004 witness stage (no seal) | 179 s | 8.04 | 155 s | - |
| v003 control build | 194 s | 5.89 | 186 s | max 5.89 |

What this shows:

- The v004 peak falls inside the adapter projection. The witness stage, which
  runs the same projection without sealing, peaks at the same elapsed time.
- v003 peaks during sealing.
- v004 sealing peaks at about 6.1-6.3 GiB against v003's 5.9 GiB. Sealing
  57,593 more facts adds a few hundred MiB, and the projection adds the rest.
- The R heap peak is 1,501 MiB in the witness projection, against an OS peak
  of 8,249 MiB. It is 3,088 against 2,940 MiB in the two builds. So the extra
  memory is DuckDB-native memory on the lake connection, which supports
  "lake-side".

Is the control like for like? Yes, within what one run can show.

- By reading, `6be0b99..8692311` in `R/ledgr-adapter.R` changes only the
  policy string, the dividend call and docs.
- The same ledgr library, runner, 0.2 s sampler, canonical build and window
  are used.
- The control ran once under light load (2 other R processes, 56 CPU s).
  v004's two builds agree within 1 MiB, so run noise is small.

Two gaps in the record:

- The argument in the README and the evidence, "witness stage 8,249 MiB is
  about the same as the build", shows only that the projection can reach the
  build peak. It does not show where v003 peaked. The series closes that gap,
  and the record does not cite it.
- The v003 control's `process_memory.csv` and `timings_build.csv` exist only
  in `scratchpad/ldg3087/v003-data/` and the private directory. The committed
  record has no control numbers to back "6,134 MiB".

Whose concern is it? The private adapter's. It is a one-time build cost in the
adapter projection's DuckDB query. It is disclosure-only under the Cut 17
defaults, and it is unrelated to the E8 run bound that LDG-3088 measures. Any
reduction is an adapter matter (a DuckDB `memory_limit`, or a narrower witness
read). It is not a ledgr route.

Smallest fix (record only):

- Commit the control's two CSVs as
  `data/control_v003_process_memory.csv` and
  `data/control_v003_timings_build.csv`, and add both to `disclosed` in
  `check_build.R`.
- In the README memory section, replace the "inference from the stage peaks;
  not profiled" sentence with:

  > The 0.2 s sampler series locate the peaks: v004 peaks about 150 s into
  > the build, inside the adapter projection (the witness stage, which does
  > not seal, peaks at the same elapsed time); v003 peaks at 186 of 194 s,
  > during sealing. v004 sealing peaks at about 6.1-6.3 GiB against v003's
  > 5.9 GiB, so sealing adds a few hundred MiB and the projection's
  > DuckDB-side dividend query adds the rest (R heap 1.5 GiB of the
  > projection's 8.2 GiB).

- In the LDG-3087 evidence, replace "attributed by stage peaks to" with
  "attributed by the sampler series to", and append "; sealing itself adds
  about 0.2-0.4 GiB".

### F3 (low, handoff; provisional default 6): using the main snapshot in place writes LDG-3088's runs into the LDG-3087 file

Verified by reading. `ledgr_run()` writes its run ledger into the snapshot's
own DuckDB file (`R/backtest.R:493`, `db_path = exp$snapshot$db_path`). My
probe runs added `ledger_events` and `run_diagnostics` rows to my copy.

Opening alone does not write. The main file's mtime is the build's end,
before the census stage's `verify = TRUE` open, and my copy's sha256 was
unchanged after my own verified open. A run does write.
Under the provisional default, LDG-3088's run, sweep, buy-and-hold and
walk-forward would all be written into the file that is LDG-3087's evidence
of record. The snapshot hash would survive, but the file would no longer be
the build output. LDG-3070 kept its run files separate (`full-run.duckdb`,
`changing-run.duckdb`).

Smallest fix:

- Replace the README handoff bullet "Open it with ledgr at or after
  `60ae907e`" with:

  > LDG-3088 copies `sp500-1998-2026-v004.duckdb` into its own fresh
  > experiment directory, opens the copy with
  > `ledgr::ledgr_snapshot_open(path, verify = TRUE)` and confirms
  > `e8cbb805...`; runs write their ledgers into that copy. Both LDG-3087
  > directories stay unchanged as the record.

- In the LDG-3087 evidence, replace "LDG-3088 uses the main snapshot and keeps
  the rerun copy pristine" with "LDG-3088 runs on its own copy of the main
  snapshot; both LDG-3087 files stay pristine", and make the same change in
  the handoff sentence.

### F4 (low, handoff for LDG-3088 acceptance 5): the per-event witness amounts are not named

The G-025 acceptance compares each posting with "the witness-implied amount
times the held quantity within the LDG-3086 tolerance".

- The per-event implied amount and tolerance (`d_step`, `tol_step`, keyed by
  `parent_instrument_id` and `ex_date`) exist only in the private
  `private/witness-rows.rds` beside the main snapshot. It has 57,593 rows,
  one per entered dividend.
- Sealed fact_ids are ledgr hashes of `source` and the adapter's `div:` id,
  so the join is by parent and ex-date. I verified that both sides are unique
  and biject.
- Neither the README handoff nor the evidence names this file. LDG-3088
  would have to re-run the witness stage, or compare against the sealed
  amount, which equals the vendor amount and not the witness-implied one.

Smallest fix: add one handoff bullet to the README and the evidence:

> The per-event witness (implied amount `d_step`, tolerance `tol_step`,
> vendor amount, keyed by parent and ex-date; one row per sealed dividend) is
> the private `private/witness-rows.rds` beside the snapshot, written by the
> witness stage at the same adapter and canonical build. LDG-3088 joins
> postings to it by parent and ex-date and commits only aggregates.

### Notes (no change required)

- N1. Acceptance precondition.
  - On `integrate/cut15-v0.2.2` at `398c805c`, `tickets.yml` marks LDG-3087
    `complete`, while its dependencies LDG-3085 and LDG-3089 still read
    `open` with no evidence.
  - Their completion record and the phase-A patches (`d71b8e9e`,
    `60ae907e`) are on the unmerged `ws49/dividend-disclosure`.
  - Merge that branch before Workstream 49 is accepted. LDG-3088 then pins a
    ledgr commit that contains `60ae907e`.
- N2. LDG-3087's evidence names the private data root
  (`E:/ledgr-data/sharadar/...`) in the public `tickets.yml`.
  - Local paths have precedent there (`C:/Users/maxth/...`), and the path
    reveals no vendor data.
  - The private README deliberately writes "under the guarded root".
    Optionally, write `<guarded root>/experiments/LDG-3087-dividends-v004/`
    instead.
- N3. Expect `unsupported` on this build.
  - 172 of the 923 dividend parents carry refused facts, so a full-universe
    research run will almost surely hold one. My probe shows fidelity reads
    `unsupported`. LDG-3088's headline must say so, as its acceptance 4
    requires.
  - Phase-A N1 still applies: `summary()` and `print()` read the events of
    refused parents. LDG-3088 should record their time.
- N4. Under v004, the v003 control snapshot is named
  `sp500-1998-2026-v004.duckdb`, because the worker hard-codes the name. This
  is cosmetic, and the directory name disambiguates it.
- N5. The main timed build ran loaded: 5 other R processes used 223 CPU s.
  The record discloses this and names the quiet rerun (213.8 s, 8,078 MiB) as
  the clean clock.
- N6. The witness census comes from a second projection, not from the build
  itself. Three things tie the two together, which is enough: the
  canonical-build guard, sealed outcomes equal to the witness by reason, and
  the bijective parent/ex-date join with equal amounts. Optionally, the
  witness stage could also record the split-adjusted constructor's ledgr
  fact_id digest for a direct identity tie.

## Provisional defaults (maintainer review at acceptance)

| Default | Verdict | Reason |
| --- | --- | --- |
| Witness census from a separate witness stage re-running the adapter projection | accept | The public builder does not return the witness. Several checks tie it to the sealed build: a guard that the canonical build is unchanged, sealed outcomes equal to the witness by reason, every complete fact joined to a witness event with an equal amount, and a reproducing rerun. See N6 |
| Unit check joins complete dividends to witness events by parent and ex-date (asserted unique) | accept | Verified unique and bijective. The code sums vendor values per key with `rowsum`, so a future summed same-date fact still joins |
| Snapshot hash, both digests and amount sum pinned after the first build | accept | No prior oracle exists for a new build's identity. I recomputed both digests from sealed rows, and the rerun reproduced all four |
| v003 memory control added | accept, with F2 | It is like for like by diff and setup. Commit its numbers and cite the sampler series |
| Knowledge labels read from `provenance_json` with a vectorised regex | accept | A full JSON parse of all 57,593 rows gives the identical vectors. A miss yields `(none)`, which fails the checker closed |
| LDG-3088 uses the main snapshot and keeps the rerun copy pristine | amend (F3) | `ledgr_run()` writes into the snapshot file. LDG-3088 should run on its own copy |

## Whole-workstream claim (Workstream 49)

The claim: "Sharadar cash dividends enter a sealed private build as validated
ordinary_cash_dividend facts in split-adjusted units, proven per event against
the vendor's dividend-adjusted series, or, where the witness cannot prove them,
refuse with named reasons that public results count; assumed knowledge is
labelled as assumed and every unmapped or refused row is disclosed."

| Clause | Evidence | Holds |
| --- | --- | --- |
| validated split-adjusted dividends, proven per event | 56,658 complete, all `gross_cash_validated`. Each equals the vendor amount and lies inside the preregistered closeadj-step tolerance (this review, by execution). The witness closes equal the sealed bars. The basis rule passes out of sample, 8,513 of 8,531 with 0 as-traded (LDG-3086, and recomputed in phase A) | yes |
| refused with named reasons that public results count | 935 refused under four closed reasons. On the real build, `sealed_refusal_counts` reads 935 by reason, held refusals count with their quantity, fidelity reads `unsupported`, and strict stops (this review). The route is LDG-3089 (phase A) | yes |
| assumed knowledge labelled | 57,593 of 57,593 `assumed`. The family metadata says so, and the valuation summary lists the family (this review). Phase-A F1 is patched at `60ae907e` | yes |
| every unmapped or refused row disclosed | Refused rows are disclosed by ledgr. Unmapped rows never enter ledgr, so they are disclosed in the private aggregate record: 495,308 off axis, 19 out of window, 3 not a session, and non-cash actions by code | yes; the private headline (LDG-3088 G-016) is where unmapped counts reach the reader |

What LDG-3088 still needs to consume the build: F3 (its own copy), F4 (the
witness file), N1 (merge `ws49/dividend-disclosure`) and N3 (expect
`unsupported`). Nothing else is missing.

## Acceptance items (LDG-3087)

| Item | Result |
| --- | --- |
| 3087-1 seals, verifies cold, records hash, format, build time and peak beside LDG-3080 | met. Hash, schema 123, SEALED and cold verification by execution on both copies. Time and peak by reading the records and sampler series; the load is disclosed. F2 for the control record |
| 3087-2 witness census recorded, gate follows the preregistered rule, every dividend reads assumed | met. 0 differences against the LDG-3086 census JSON. Gate arithmetic checked by the committed checker. 57,593 assumed by full JSON parse |
| 3087-3 fact census re-run; corporate-action, knowledge and segment counts recorded | met. Corporate actions 57,593 on 923 parents and 0 late-known by execution. Segment census by reading and the checker. F1 for the unpinned shape |
| 3087-4 check script fails on a changed count or one-event unit error (mutation recorded); rerun reproduces the counted files | met. The implementer's K-series read; my R2 and R4-R8 killed; U1 and U2 fire on exactly one event; the rerun files are byte-identical and the rerun snapshot verifies. F1 (R1, R3, R9-R12 survive single-record mode) |

## Mutations (reviewer's own, on copies of the committed CSVs)

| ID | Mutation | Single-record | Rerun mode |
| --- | --- | --- | --- |
| R0 | control | passes | - |
| R1 | corporate-action instruments 923 -> 922, with one histogram bucket -1 | passes (F1) | killed |
| R2 | membership segment total +1 | killed (segment totals) | killed |
| R3 | complete on F != 1, 10,818 -> 10,817 | passes (F1) | killed |
| R4 | non-cash `spinoff` +1 | killed | killed |
| R5 | out-of-sample decidable C/F matches 0 -> 1 | killed (basis rule changed) | killed |
| R6 | complete-dividend knowledge `assumed` -> `evidenced` | killed | killed |
| R7 | one complete amount outside the step tolerance | killed (unit error) | killed |
| R8 | store schema 123 -> 122 | killed | killed |
| R9 | adapter package commit changed | passes (F1) | killed |
| R10 | declared families lose `equity_corporate_actions` | passes (F1) | killed |
| R11 | hash rule 4 -> 5 | passes (F1) | killed |
| R12 | corporate-action max per instrument 344 -> 345 | passes (F1) | killed |
| U1 | in memory: one decidable complete amount / F | both unit predicates count 1 | - |
| U2 | in memory: one complete amount x 100 | both unit predicates count 1 | - |

I did not re-run the implementer's K0-K3b or the K2 mutant build. I read the
scripts and `mutation_results.csv`, and the targets match the claims. K2 also
fires four identity checks, which the README states.

## Seven-shape walk (experiment scripts; no package code changed)

- No loop runs per event or per fact.
  - The census is one grouped tabulation.
  - The unit check is one `match` plus `rowsum`.
  - The knowledge labels come from one vectorised `sub`.
- The witness is the adapter's one set-based query.
- Two loops are bounded and inherited:
  - the loop over 1,166 instruments in `prepare` is LDG-3080's unchanged
    feature-range method;
  - the runner's per-sample loop over the process tree is a sampler.
- Nothing is parsed or formatted per row where a vectorised call exists.

## Verification record

Windows 11, R 4.6.1, sequential:

- ledgr comes from the implementer's scratch `rlib`, installed from a
  `git archive` export of `60ae907e`. That commit is recorded in the library
  and confirmed by `find.package`.
- `check_build.R` was run on `data/` (OK) and on `data/` against the rerun
  `aggregate-results` (OK).
- File sha256 values, identical before and after the review:
  - main snapshot `1f8be31f...`;
  - rerun snapshot `cb783af5...`;
  - LDG-3070 `full-run.duckdb` `70b6741b...` and `changing-run.duckdb`
    `a1e74f01...`.
- Nothing was written to either LDG-3087 directory, to LDG-3070, to any
  worktree or to any commit. The snapshot copies were deleted after the
  probes.
