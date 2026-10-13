# Cut 14 Review: Pre-CRAN Legacy Removal And Structural Hygiene

- Mode: combined Type 1 (ownership, fidelity, inputs) and Type 2 (ticket
  grain, sequencing, hidden decisions, evidence architecture)
- Reviewer: fresh clean-context agent; did not author or review any stage of
  the legacy-removal RFC. The accepted design is not reopened; Part 2 stays
  within ticket grain, sequencing, hidden decisions and evidence architecture.
- Date: 2026-10-13
- Base: `c7911eea`; the Cut 14 draft is the uncommitted diff to `tickets.yml`,
  `contracts.md`, `decisions.md`, both READMEs, the roadmap, the macro plan,
  `rfc/README.md` and the WS5-A synthesis
- Checks run here: `tickets.yml` parses (14 cuts, 31 workstreams, 112 unique
  tickets; Cut 14 has 13 tickets in one linear dependency chain LDG-3022 to
  LDG-3034); `git diff --check` clean; the diff adds no non-ASCII byte. Code
  censuses were re-derived at `c7911eea` in a disposable detached worktree with
  `pkgload::load_all()` and parse-data scripts (Section 4). The ledgr-research
  adapter and bench scripts were read for API use only; no private data,
  credential or vendor row was read.

## 1. Verdict

**CHANGES_REQUIRED.** No `NEEDS_TYPE_2` item: every finding is inside the
accepted synthesis, the macro-plan amendments or the cut's own decisions. The
contract edits, pipeline exit, decisions bridge and WS5-A amendment are
faithful, and most synthesis gates have a criterion that can fail. But the
re-derived current-tree inputs differ from the synthesis's 164e15ba picture in
ways the tickets do not yet absorb:

- the opener census misses two connection sources that reach ledgr tables
  without opening a file (the held-store registry and eight exported functions
  that accept a caller-supplied connection), and the amended Persistence
  Contract already requires the gate before every package-owned read or write;
- `canonical_json()` orders keys by locale collation, not radix, so decision
  (3) cannot be implemented by passing a radix-ordered list to it;
- the "LDG-3018 normalization" the tickets reuse is a cache key that omits
  indexes and column defaults;
- the claim inventory is stale (Cut 13 added LCL-0248, which asserts the
  legacy readability being removed) and its rewrites are assigned to LDG-3030
  although the deletions in LDG-3026 and LDG-3028 break those blocks first;
- LDG-3033 would face 228 undocumented public condition classes, 149 of them
  asserted in tests, with a rename option that conflicts with decision (6).

Eleven patches are required. Three of them move work between tickets or need
one maintainer choice (Patches 4, 6 and 8), so a focused re-check of the
patched draft is recommended rather than acceptance on patches alone.

## 2. Type 1 Ownership

### 2.1 Synthesis decisions, contract changes and gates

| Accepted item | Owner | Criterion that can fail, or gap |
| --- | --- | --- |
| D1 one opener, one gate; per-site checks deleted | LDG-3025, LDG-3026 | 3026 acc. 1 and 5. Gap: held-store borrows and caller-supplied connections are outside the census (Patch 1) |
| D2 marker pair; namespace-enumerating guard | LDG-3025 | acc. 2 can fail. acc. 1 cannot fail if production and test both enumerate (Patch 2) |
| D3 record branches deleted; one equality assertion each | LDG-3028 | acc. 1 and 6. Gap: convention-string branches such as `availability_close_v1` are not numeric version fields (Patch 1) |
| D4 one DDL; legacy path, migrate, ensure, template, validator, sweep column list deleted | LDG-3024, LDG-3026, LDG-3027 | 3024 acc. 3; 3026 acc. 3; 3027 acc. 3 |
| D5 strict catalogue comparison, extra is a difference | LDG-3027 | acc. 1 and 2. Gap: the reused normalizer and cache key do not cover indexes or defaults (Patch 3) |
| D6 rule 2 required; hand-built configs fixed | LDG-3028 | acc. 2 |
| D7 three current behaviours kept | LDG-3028 | acc. 4 |
| D8 `ledgr_store_rebuild_required`, parent, cause | LDG-3025 | acc. 3. Gap: synthesis 2.3 folds `ledgr_future_schema_version` into it; no criterion removes it (Patch 7) |
| D9 old call forms | LDG-3029 | acc. 1 to 3 |
| D10 scope boundary | Cut 14 decision (6), `out_of_scope` | n/a |
| 2.4 `ledgr_snapshot_rebuild_required` removed with the legacy marker branch | LDG-3028 scope ("legacy snapshot markers") | no criterion checks the class, its `@aliases` entry or its reference text are gone (Patch 7) |
| Section 5 Execution, Config, Snapshot, Availability, Persistence, Strategy, Verification | applied at this cut | all named sentences changed as specified. Residual: the Config Contract schema-1 policy paragraph and three "historical run" clauses still promise removed readability (Patch 9) |
| Section 5 elsewhere: WS5-A amendment | applied at this cut | faithful (Section 2.3) |
| Section 5 elsewhere: `vignettes/sweeps.qmd`, NEWS | LDG-3030 | acc. 2 |
| Section 5 elsewhere: condition reference and aliases | LDG-3029 acc. 3; LDG-3030 acc. 5 | can fail; covers only three of the six retiring classes (Patch 7) |
| Gate 1 byte identity per code step | LDG-3024 acc. 4 to LDG-3030 acc. 6 | can fail; see Patch 5 for the LDG-3025 intermediate state |
| Gate 2 opener census | LDG-3022 acc. 2; LDG-3026 acc. 1 | can fail for the sites it lists (Patch 1) |
| Gate 3 gate witnesses, empty-file create, interrupted create | LDG-3025 acc. 3 to 6 | can fail |
| Gate 4 fingerprint enumeration | LDG-3025 acc. 1 | see Patch 2 |
| Gate 5 catalogue witnesses, create-close-reopen | LDG-3027 acc. 1 and 2; LDG-3024 acc. 2 | can fail (Patch 3 for the cache) |
| Gate 6 branch census | LDG-3028 acc. 1 and 6 | "fails" is undefined for a report-only tool (Patch 5) |
| Gate 7 config census | LDG-3028 acc. 2; LDG-3030 acc. 4 | can fail |
| Gate 8 claims | LDG-3030 acc. 3 | inventory stale and mis-sequenced (Patch 4) |
| Gate 9 cost; profiles; rebuild time | LDG-3027 acc. 5; LDG-3030 acc. 6; LDG-3031 acc. 3 | can fail; noise floor unmeasured (Section 4.3) |
| Gate 10 docs, aliases, `R CMD check` | LDG-3030 acc. 5 and 6 | can fail |
| Section 8 spec-cut questions | Cut 14 decisions (2) to (4) | all four answered; the key-order answer is not implementable as worded (Patch 2) |
| Section 9 CRAN compatibility policy; consolidation inherits one opener | **no home** | the pipeline row that carried them left `rfc/README.md`; neither the roadmap consolidation row nor `rfc_cycle.md` records them (Patch 10) |
| Section 10 routing | this cut | pipeline row removed; bridge row kept and points to Cut 14; Section 5 applied; WS5-A amended |

### 2.2 Brief checklist and macro-plan hygiene items

| Item | Owner | Assessment |
| --- | --- | --- |
| schema 119; one DDL authority | LDG-3024, LDG-3025 | owned |
| `ledgr_store_open(path, mode)` as sole gate | LDG-3025, LDG-3026 | owned for path opens; not for borrowed or caller-supplied connections or the ATTACH entry's name (Patch 1) |
| `ledgr_db_init()` create-empty-or-open-current | LDG-3025 acc. 6 | owned; `:memory:` behaviour is implicit (should-fix) |
| version plus fingerprint marker pair, marker last | LDG-3025 acc. 5 | owned |
| enumeration rule, radix order, scalar type identity | LDG-3025 acc. 1 and 2 | type identity is real: `canonical_json()` writes `2L` as `2` and `2` as `2.0`. Radix order is not achievable through `canonical_json()` (Patch 2) |
| two atomic rule-version bindings, old shapes removed without alias | LDG-3025 scope | no criterion fails if an alias is kept; the old names do not match the regex, so acc. 1 cannot see them (Patch 2) |
| rebuild condition, closed causes, typed fields, message family | LDG-3025 acc. 3 | owned; cause precedence unstated (should-fix) |
| refusal before split-store ATTACH exposes rows | LDG-3025 acc. 4 | owned |
| strict validation incl. extras and interrupted creation | LDG-3027 acc. 2; LDG-3025 acc. 5 | owned |
| removal of migrations, readers, fallbacks, old call forms | LDG-3026, LDG-3028, LDG-3029 | owned; residual classes in Patch 7 |
| three retained behaviours | LDG-3028 acc. 4 | owned and can fail |
| lake rebuild after all format changes, native and aggregate only | LDG-3031 | owned; build entry and measurements underspecified (Patch 11) |
| report-to-gate transition | LDG-3022, LDG-3033 acc. 5 | owned; definitions missing (Patch 8) |
| advisory lint one cut, isolated styler, blocking | LDG-3023, LDG-3032 | owned and can fail |
| no-uncalled-function floor versus one-caller review rule | LDG-3034 acc. 1 and 2 | owned |
| macro-plan item (4) "small Type 1 review" for the Verification clause | Workstream 31 close review | folded in, not stated (should-fix) |

### 2.3 Contract edits and routing

- `rfc/README.md`: the `pre-cran-legacy-removal` pipeline row is gone and no
  link to its anchor remains anywhere under `inst/design/`.
- `decisions.md`: the bridge row remains, its pipeline cell is emptied and it
  points to Cut 14 in `tickets.yml`.
- WS5-A synthesis: D5, Section 3.5, the Section 5 Persistence bullet and gate
  8 now make non-current stores unreachable and keep "missing or non-3 in a
  current store refuses". Rule-3 bytes, the verified set and the three read
  classes are untouched, so rule-3 verification is not weakened. One open
  point: the amended text no longer says which read classes refuse an invalid
  marker inside a current store; Patch 4 asks the LCL-0248 rewrite to pin it.
- Macro plan header, roadmap row, design index and packet README agree on
  "Cuts 1 to 13 closed; draft Cut 14; then interim rebuild, one-execution-mode
  probe, WS3/WS4". The roadmap's snapshot-verification row is correctly moved
  to "Done in Cut 13".
- Obligations that disappear without a route: synthesis Section 9 (Patch 10)
  and the Cut 13 routing of the rule-3 Sharadar rebuild time, peak RSS and
  post-verification clock to "the WS7 lake rebuild", which LDG-3031 now
  precedes (Patch 11).

## 3. Type 2 Grain And Sequencing

**Three claims.** Workstream 29 (one schema, one gate) is one claim. Workstream
30 joins record branches, public call forms and the lake rebuild under
"current-only"; LDG-3029 does not depend on the gate and could run anywhere,
but the grouping is coherent and serial order costs only calendar time.
Workstream 31 is one claim spread across the cut. Its census tool is relied on
by the Workstream 29 and 30 close reviews before Workstream 31 is itself
reviewed; that is acceptable because the Workstream 29 review reason already
re-verifies the opener rows it uses.

**LDG-3022 and LDG-3023 as prerequisites.** LDG-3022 is a genuine
prerequisite: the synthesis citations are stale at `c7911eea` (22 check or
create call sites in ten files, not about twenty in nine; the backtest-results
open moved to line 1076; Cut 13 added the verified set, LCL-0248 and new
snapshot readers). LDG-3023 is a prerequisite only for the advisory interval;
the removal does not use lint. That is honest, but the cut-level text "used
throughout the removal" overstates it (nit).

**Pause and resume.** The 13 tickets form one dependency chain, so the order
is enforceable. What is not stated is whether LDG-3032 waits for Workstream 30
acceptance. If it does not, a Workstream 30 correction round lands on a
whole-tree restyled tree and the Workstream 30 re-review diff spans the styler
commit (should-fix).

**LDG-3024 to LDG-3027.** Serial is right. One boundary is wrong: synthesis
step (2) raises the version and routes every opener together; LDG-3025 raises
the version and adds the gate, but routing waits for LDG-3026. At the LDG-3025
commit, `ledgr_snapshot_from_df()` on a new file still creates through the raw
`dbConnect()` plus `ledgr_create_schema()` path (`R/snapshot_adapters.R:273-277`)
and would stamp 119 without a fingerprint, which the gated `ledgr_db_init()`
then refuses. The ladder criterion would catch it, but the ticket boundary
invites the failure (Patch 5).

**LDG-3028 to LDG-3031 and Workstream 29 acceptance.** LDG-3028 must wait: its
deletions are safe only because the gate makes non-current records
unreachable. LDG-3029 need not wait but may. LDG-3031 is correctly last: after
LDG-3028 nothing changes a stored format. A cheap closing check that the
final-commit fingerprint equals the one LDG-3031 recorded protects the rebuild
against a late constant change (should-fix).

**LDG-3030.** Partly real, partly duplicate. The contract and WS5-A text it
"completes" was applied at this cut, and its condition-reference criterion
repeats LDG-3029 acc. 3. Its real content is NEWS, `vignettes/sweeps.qmd`,
generated help (`R/identity-reference.R` still teaches rule-1 readability),
the residual contract clauses, LCL-0128 and the full package gates. Its claim
rewrites are mis-sequenced (Patch 4). After that patch it is real
consolidation work of effort M, not L.

**Styler and blocking lint.** Correctly separated, with a parse-equivalence
oracle. Because ledgr fingerprints implementation bodies through `deparse()`
and the ladder's `identity` family is reported but never gated, the style
commit is the one place where an ungated family deserves a gate (should-fix).

**LDG-3033 and LDG-3034.** Distinct claims: executable detectors versus the
claim-defining text. LDG-3034 is thin (S) and its acc. 6 restates process, but
it is where macro-plan item (4)'s Type 1 check of claim-defining text lands.
Merging it into LDG-3033 would give 4/12 = 0.333; keeping it is acceptable.
LDG-3033 is undersized as M (Patch 8).

**Missing conflicts or dependencies.** No parallel product work, so no file
conflict. The registered opener detector of LDG-3026 has no named file or
profile, while LDG-3033 creates `test-codebase-contracts.R`; name the home so
the two tickets do not create competing files (Patch 5).

**Non-failing criteria.** These restate process and cannot fail under an
implementation regression: LDG-3024 acc. 5 second clause, LDG-3027 acc. 6
second clause, LDG-3031 acc. 6 and LDG-3034 acc. 6. Move them into the review
reasons (nit). LDG-3025 acc. 1 is the one load-bearing criterion that cannot
fail as worded (Patch 2).

## 4. Inputs

### 4.1 Re-derived censuses at `c7911eea`

Methods are first-pass parse-data and namespace scripts, not the LDG-3022 tool;
they bound the work rather than define the gate.

| Family | Measured |
| --- | --- |
| Format constants | 20 regex matches: 18 length-one atomic (`ledgr_experiment_store_schema_version = 118L`, `ledgr_saved_sweep_schema_version = 4L`, five `"v1"` strings, the rest integers) and 2 functions (`ledgr_snapshot_hash_rule_version()`, `ledgr_sweep_assert_parent_schema_version()`). `ledgr_snapshot_hash_rule3_version = 3L` and the function `ledgr_availability_execution_timing_version()` do not match; after LDG-3025 the atomic set should be 20. Other atomic `*version*` bindings: `ledgr_promotion_context_version` (excluded by the synthesis) |
| Path openers in `R/` | 9 `ledgr_open_duckdb_with_retry()` sites, 20 `ledgr_run_store_open()` sites, 4 `ledgr_db_init()` call sites, 5 `dbConnect()` lines (two inside the primitive and its join, one in-memory template, one in-memory CSV parser, one raw creation in `R/snapshot_adapters.R:275`), 1 `ATTACH` (`R/snapshot-source.R:48`) |
| Connections not obtained by opening | held-store registry (`ledgr_store_register()` at `R/snapshot.R:142`, `:164`; `ledgr_held_store()` borrowed at four sites); cached snapshot and handle connections; 8 exported functions taking a caller-supplied `con` (`ledgr_snapshot_create`, `_info`, `_list`, `_seal`, `ledgr_state_reconstruct`, `ledgr_validate_schema`, `ledgr_corporate_action_summary(con =)`, `ledgr_valuation_summary(con =)`). Apart from `ledgr_validate_schema()`, none checks the store before reading or writing ledgr tables on that connection |
| Per-site schema checks | 22 `ledgr_create_schema()` or `ledgr_experiment_store_check_schema()` call sites in 10 files outside the schema files |
| Private functions | 1,654 top-level definitions, 168 exports, 84 S3 registrations; 29 non-exported functions (plus `.onLoad`) with no reference in `R/` by name or string; 19 of those are referenced from `tests/testthat` (for example `ledgr_snapshot_verified_reset` in seven files, the legacy wrapper `ledgr_validate_config` in two); 10 have no reference anywhere |
| Conditions | 1,510 `rlang::abort()` calls and 34 `stop()` calls; 17 aborts with a non-literal class; 363 distinct literal classes, 134 named in `R/condition-reference.R`, 1 `ledgr_internal_`; 228 undocumented non-internal classes, 149 of them named in tests; `ledgr_invalid_store` itself is undocumented |
| Claims touching removed surfaces | the ten synthesis claims, plus LCL-0248 / LTB-0250 (Cut 13: missing, rule-1 and rule-2 snapshots stay metadata-readable) and LCL-0210 / LTB-0210 (Cut 11: a version-1 `availability_close_v1` arm through `ledgr_fill_recording_pulses_from_evidence()`) |

### 4.2 Lake rebuild

Aggregate and native evidence is enough to cut LDG-3031. It matches the Cut 11
practice where `summarize_record.R` is the only form in which a Sharadar
record leaves the private store. The adapter in `packages/ledgr.sharadar`
uses only exported ledgr functions (no `:::` call), opens only in-memory
DuckDB connections of its own, and uses no removed formal. The research
scripts call `ledgr_db_init()`, which survives. Two facts need writing into
the ticket rather than discovering during it. First, the maintained build of
the ledgr snapshot is the `build` stage of
`dev/bench/v0_2_2_sharadar_run/run_record.R` in ledgr
(`sharadar_ledgr_snapshot()` from the canonical lake), not a ledgr-research
script, and that runner already samples per-stage peak RSS. Second, the
vendor canonical lake (`raw.*`, `core.*`) is not a ledgr store and is not
rebuilt.

### 4.3 Measure before implementation

1. The noise floor of the LDG-3027 clocks. Three alternating pairs at a 1.05
   median ratio on millisecond operations is unproven on this host, whose
   recent timing gates needed exceptions. One A/A record of the three clocks
   on the pre-cut tree shows whether the gate can resolve 5 percent, and how
   many repetitions each pair needs.
2. The LDG-3033 disposition, sized by Section 4.1, decided before Workstream
   31 resumes and preferably at acceptance (Patch 8).
3. An aggregate list of the ledgr-format stores in the private root that the
   WS3/WS4 lane and the one-execution-mode probe will use, so LDG-3031 has a
   defined target. Also the Cut 11 `run1` build time and stage peak as its
   comparison arm.

The rule-3 Sharadar build time and peak themselves are correctly ticket
evidence.

## 5. Required Patches

1. **LDG-3022 scope and acceptance; LDG-3025 and LDG-3026 scope (connection
   sources).**
   - Extend the opener family to every way package code gets a connection
     that reaches ledgr tables: held-store registration and borrow sites,
     cached snapshot and handle connections, and exported functions that
     accept a caller-supplied connection.
   - LDG-3025 names the gate's one existing-connection check, used by the
     split-store ATTACH and by caller-supplied connections. LDG-3026 routes the
     eight exported `con` entries through it, so that a user `dbConnect()` to
     a 118 store passed to `ledgr_snapshot_list()`, `ledgr_snapshot_seal()` or
     `ledgr_state_reconstruct()` refuses with `ledgr_store_rebuild_required`.
     The amended Persistence clause ("before any package-owned persistent
     read or write") already requires this.
   - Name this check, `ledgr_store_open()` and the low-level primitive as the
     only entries LDG-3026 acc. 1 accepts.
   - Extend the version family to marker and convention strings
     (`availability_close_v1`), not only numeric version fields.
2. **LDG-3025 scope and acceptance (fingerprint).**
   - `canonical_json()` sorts keys with `order(nm)`, which collates by locale.
     A probe here returns `{"a":2,"B":1}`, where radix order gives `B` first.
     State that the fingerprint serializer imposes radix order itself and that
     `canonical_json()` is unchanged. Add a witness whose names order
     differently under radix and locale collation, or the same fingerprint
     under two `LC_COLLATE` values.
   - Rewrite acc. 1 against an independent literal list of the 20 expected
     names in the test, so that a production enumeration cannot satisfy the
     test by construction.
   - Add a criterion that `ledgr_snapshot_hash_rule3_version` and
     `ledgr_availability_execution_timing_version()` are absent from `R/`,
     `tests/` and `dev/` by source census.
3. **LDG-3024 and LDG-3027 (normalizer and cache).**
   - At `c7911eea` the "LDG-3018 normalization" is the validation-cache key
     (`R/db-schema-validate.R:785-835`). It hashes column name, type,
     nullability and order plus constraints, and omits indexes and column
     defaults. The per-dimension catalogue the synthesis cites does not exist
     in `R/`; only a test helper in LTB-0239 does.
   - LDG-3024 owns building the normalized catalogue (tables, columns with
     defaults, keys, foreign keys, CHECK text, indexes) as the shared
     comparator.
   - LDG-3027 extends the cache key to every compared dimension. Add a
     witness: validate a current store, then a store that differs only by a
     missing index must still fail in the same session.
   - State what happens to the LDG-3024 parity detector when LDG-3026 deletes
     the legacy builder: retire it with its claim, or freeze the pre-cut
     normalized catalogue as a checked-in golden. Otherwise acc. 3 holds only
     at one commit.
4. **LDG-3026, LDG-3028 and LDG-3030 (claim inventory).**
   - Re-derive the inventory at the implementation base. Add LCL-0248 /
     LTB-0250, rewritten to "in a current store a missing or non-3 marker
     refuses", with the read classes that refuse pinned. Add the LCL-0210
     version-1 arm.
   - Replace "retire only" with an exact list that includes them.
   - Assign each claim rewrite to the ticket whose deletion breaks it, so
     that registered blocks and `tests/claims.yml` stay green at every commit:
     - LCL-0026, LCL-0034, LCL-0039, LCL-0200, LCL-0237 and the nine
       unregistered `test-experiment-store-schema.R` blocks with LDG-3026, as
       the synthesis says ("go with the code");
     - LCL-0028, LCL-0158, LCL-0159, LCL-0160, LCL-0234, LCL-0242, LCL-0248
       and LCL-0210 with LDG-3028.
   - LDG-3030 then audits the inventory and keeps LCL-0128.
5. **LDG-3025, LDG-3026 and LDG-3028 (intermediate state and detector form).**
   - At the LDG-3025 commit every store-creating path goes through
     `mode = "create"` (`ledgr_db_init()`, `ledgr_create_schema()` and the raw
     creation in `R/snapshot_adapters.R`). Alternatively, move routing into
     LDG-3025 as synthesis step (2) binds.
   - Name the file and profile of LDG-3026's registered opener detector.
   - State whether the branch and config censuses of LDG-3028 and LDG-3030
     are registered detectors or review-time checks. Either way, give
     LDG-3022's tool a check mode whose non-zero exit is the "fails" in those
     criteria, since report mode always exits successfully.
6. **LDG-3027 scope (public validator conditions).** `ledgr_validate_schema()`
   is exported and today raises unclassed `stop()` errors whose text tests pin
   ("Missing table: bars"). The catalogue comparison necessarily changes them,
   which decision (6) forbids unless named. State the new class and message
   family, record the change as intended in NEWS, and say what the function
   raises for a non-current store.
7. **LDG-3025, LDG-3028 and LDG-3030 (retiring classes).** Six classes leave,
   not three. Add `ledgr_future_schema_version` (folded into the new
   condition, LDG-3025), `ledgr_snapshot_rebuild_required` and
   `ledgr_identity_rule_retired` with `ledgr_identity_rule_retired_abort()`
   (LDG-3028). Extend LDG-3030 acc. 5 to all six classes across `R/`, `man/`
   and `tests/claims.yml`. The LDG-3033 gate checks only raised-to-documented,
   so nothing else would catch a documented class that is never raised.
8. **LDG-3022 and LDG-3033 (definitions, disposition and size).**
   - Define a "package call site": `R/` only, or `R/` plus tests. 19 of the 29
     functions with no `R/` reference are test-only seams, including Cut 13's
     `ledgr_snapshot_verified_reset`. Also define treatment of hooks such as
     `.onLoad` and string dispatch.
   - Define "documented": an `@aliases` entry or a mention. Define which
     elements of a class vector must be documented; parents such as
     `ledgr_invalid_store` are undocumented today.
   - Reconcile the "rename to `ledgr_internal_`" option with decision (6):
     either documentation only, or renames limited to classes no test,
     contract or article names, listed in the record.
   - Re-size LDG-3033 against 228 undocumented classes, or split the
     disposition from the gate. This is a maintainer choice.
9. **`contracts.md` (residual clauses), now or in LDG-3030 scope by name.**
   - The Config Contract paragraph "Schema-1 policy records stay readable in
     their exact historical shape ..." contradicts decision (1) and D3 in the
     same section. Rewrite it now, as the cut's other clauses were.
   - Also name "Historical configs without that field return `NA_character_`"
     (`ledgr_run_info()` risk hash), "Dense and historical runs without that
     evidence" (completion projection) and "Historical runs retain ... Reads
     may classify timing provenance" (Result Contract).
10. **Routing of synthesis Section 9.** Add one sentence each:
    - the CRAN compatibility and deprecation policy before the first CRAN
      release, enforced at the gate and fingerprint, to `rfc_cycle.md`'s
      Pre-CRAN Compatibility Policy or the roadmap;
    - "inherits one opener and one gate; must not add a second" to the roadmap
      row "Post-v0.2.2 execution-core consolidation".
11. **LDG-3031 scope and acceptance.**
    - Name the build entry (`dev/bench/v0_2_2_sharadar_run/run_record.R`
      `build` stage at a pinned adapter commit) and the aggregate smoke path
      (for example `dev/bench/v0_2_2_real_data_scale/run_record.R
      --lane=sharadar` plus `summarize_record.R`).
    - Make peak RSS mandatory; the runner samples it.
    - Say that the vendor canonical lake is not rebuilt and that earlier
      ledgr-format stores are left unreachable, neither migrated nor deleted.
    - Route the Cut 13 deferrals explicitly: either LDG-3031 records the
      rule-3 Sharadar build time, peak and post-verification clock, or they
      stay with WS7 by name.

## 6. Should-Fix And Nits

Should-fix:

- **Workstream 31 resumption.** Make LDG-3032 wait for Workstream 30
  acceptance (Section 3).
- **LDG-3025 cause rules.** State the cause precedence (version first, then
  fingerprint presence, then equality). Classify 119 without a fingerprint as
  `invalid_marker`. Say what `mode = "open"` does on an empty, zero-table
  file: today `ledgr_run_list()` returns an empty tibble, read-only tools must
  not write DDL, and the closed cause set has no entry for it. Say how
  `:memory:` is handled and whether an unavailable `differing_constants` is
  `character(0)` or `NA_character_`.
- **LDG-3027 clocks.** Name the pre-cut comparator for `ledgr_store_open()`,
  which does not exist pre-cut (`ledgr_run_store_open()` plus
  `ledgr_validate_schema_once()` is the nearest). Name the repetitions per
  pair after the A/A record in Section 4.3.
- **Fingerprint cost.** Compute the enumerated fingerprint once per session,
  not per open.
- **LDG-3032.** Gate the ladder's `identity` family on the style commit and
  run the full suite, not only focused suites, because source-text pins can
  break under reformatting.
- **Final fingerprint check.** At the Workstream 31 close, confirm that the
  final-commit format fingerprint equals the one LDG-3031 recorded.
- **LDG-3030 generated help.** Add a census over roxygen and `man/` for
  removed-surface vocabulary. Known hits: `R/identity-reference.R` rule-1
  readability; the `ledgr_db_init()` title "v0.1.0 schema"; the condition
  reference's "Legacy shape classes" section.
- **LDG-3022 reach.** Report the 34 `stop()` calls and warning classes. List
  atomic `*version*` bindings outside the regex so that a misnamed format
  constant, the way `ledgr_snapshot_hash_rule3_version` was, is visible.
- **Record paths.** Name where the LDG-3022 report and the per-ticket ladder
  records live.
- **Workstream 31 review reason.** State that the close review discharges the
  macro plan's "small Type 1 review" of the Verification Contract clause.

Nits:

- Cut 14 `cut_review` field: lint is a calendar prerequisite of the advisory
  interval, not "used throughout the removal".
- LDG-3025 acc. 7 "apart from the expressly changed marker and store version
  families": the ladder drops version columns. Name the families or say none.
- LDG-3026 scope: name the `ledgr_experiment_store_upgrade_*` table rebuilds
  (the synthesis's "rebuilds") beside the migrate pass.
- LDG-3022 acc. 1: "one command on c7911eea" means the LDG-3022 commit.
- LDG-3030 acc. 5 duplicates LDG-3029 acc. 3; keep one owner per class.
- Move the four process-only criteria named in Section 3 into review reasons.

## 7. Review Accounting

The arithmetic in `tickets.yml` is correct: one cut review plus three Type 1
workstream close reviews is 4 invocations over 13 tickets, 0.308 against the
0.5 gate. No ticket is padding. LDG-3023 and LDG-3034 are small but carry
accepted macro-plan claims, and the counted reviews map one-to-one to the
three claims.

This verdict adds one focused re-check of the patched draft, giving 5/13 =
0.385. The gate allows 6 invocations, so one focused re-review across all
three workstreams remains inside it. A second would breach at 7/13 = 0.538.
Recent cuts needed about one correction round per workstream (Cut 13 ended at
6/3), so a recorded breach is plausible. The honest response is to record it
when it happens, not to add tickets or merge claims to lower the ratio.

CHANGES_REQUIRED
