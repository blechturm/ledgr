# Cut 9 Review: Context Frame Retirement

- Date: 2026-11-03
- Reviewer: independent clean-context Claude CLI, Opus, high effort
- Mode: Type 1 ownership review with Type 2 ticket-grain challenge
- Baseline: `74015f96`, draft working tree
- Verdict: **CHANGES_REQUIRED**

## Answer

The core grain is right: one runtime claim followed by one migration and
closure claim. Reusing `.pulse_lookup` adds no second carrier, the measured
inputs are adequate to cut on, and identity, format and compatibility
boundaries match the accepted synthesis.

Nine corrections are required. Eight are mechanical. One needs maintainer
disposition because Cut 7 assigned a history-selection reason-vocabulary
obligation to WS6, while the accepted WS6 synthesis neither adopts nor rejects
that behavior.

## Findings

1. **Withdrawn Cut 8.** Cut 8 and LDG-3191-LDG-3193 were allocated on
   `claude/rule17-banlist`, then withdrawn unmerged at `e3bb4cec`. Their IDs
   remain retired, but Cut 9 has no merge dependency on that branch.
2. **Red intermediate candidate.** LDG-3195 removes fields that several tests
   still read, while LDG-3196 owned those rewrites. The breaking tests must move
   into LDG-3195 so the WS20 candidate is green.
3. **Undisposed Cut 7 handoff.** `contracts.md:1937-1941` assigns restoration
   of specific history-selection restriction reasons to WS6. The implementation
   would change `ledgr_history_frame()` output and is outside the accepted RFC.
   Maintainer must either open Type 2 design now or route it to another owner.
4. **Prepared-once detector too weak.** A per-read count would not detect
   rebuilding readable names once per pulse. A multi-pulse run and
   multi-candidate sweep must prove once-per-run/candidate preparation.
5. **Zero-frame detector too narrow.** Counting two named constructors does
   not detect an inline `data.frame()` or `ledgr_fast_data_frame()` in P2. The
   callback context and `.pulse_lookup` must contain no data frame.
6. **Shape closure incomplete.** The detector must walk every package callee
   of both helpers, not only exported bodies. Current scale-growing work already
   lives in `ledgr_pulse_wide_add_ohlcv()`.
7. **Expected differences unnamed.** The baseline must register B4's three
   deliberate output changes and B5's five removed names rather than requiring
   those rows to remain unchanged.
8. **Missing failure-sensitive gates.** Add mutations for alias-hash removal,
   live-buffer leakage, print/error frame work and fixture timestamp loops;
   explicitly gate name parity, missing-bar `NA`, and frame-free print/errors.
9. **Peer migration misstated.** Cut 7 already migrated the frozen peer recipes
   to flat columns. Only `dev/bench/shared/run_benchmarks.R` remains to migrate,
   and it has a smoke target rather than the frozen peer oracle.

## Ownership Coverage

| Accepted area | Owner after patches |
| --- | --- |
| B1-B2, retired names and no successor | LDG-3195; teaching in LDG-3196 |
| B3-B5, inspection semantics and metadata | LDG-3195 |
| B6-B10, primitive P2, freezing, fixture adapter, prepared names, trust boundary | LDG-3195 |
| B11 and six contract groups | LDG-3196 |
| Seed-v2 Section 8 and synthesis Section 7 matrix | LDG-3194, rerun by LDG-3197 |
| Integrated profiles, peer/smoke parity and routing | LDG-3197 |
| Cut 7 history-selection reason handoff | Maintainer disposition required |

## Should-Fix Incorporated With The Corrections

- State that `lookup$bars` becomes a named list of atomic OHLCV columns and
  that unrelated existing lookup members remain unchanged.
- Delete only directly retired/dead frame helpers in LDG-3195; leave the three
  synthesis-named general helpers to WS14a.
- Rerun the one-off hot-path scan descriptively after P2 shrinks.
- Name all RFC/roadmap routing rows and the roxygen/Rd surfaces.
- Make the exact-name census executable and allowlist only refusal tests and
  forbidden-string teaching lists.
- Pin delimiter refusal and the distinction between enumerated names and
  concrete-ID reads.

## Checked Clean

- YAML parses; cut, workstream and ticket IDs are unique and dependencies are
  serial.
- `git diff --check` is clean.
- Current P2 constructs the frames, snapshot inspection adds the five metadata
  fields and alias hash, names rebuild per read, and preflight carries the
  obsolete private field.
- Reusing `.pulse_lookup` is the smallest carrier change. The numeric cutoff
  and projection ordinal already exist at P2.
- No new dense path, schema, identity format, compatibility path, hash, seal,
  DuckDB query or provenance authority is proposed.
- The response probe and the unpreserved A/B are correctly descriptive, not
  acceptance clocks.

## Next Step

Apply findings 1-2 and 4-9 in place. The maintainer dispositions finding 3.
Then run one focused confirmation review because finding 2 changes ownership
between tickets.
