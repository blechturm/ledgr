# Cut 13 Review: Snapshot Verification And Sweep Persistence

- Mode: combined Type 1 (ownership, fidelity, inputs) and Type 2 (shape)
- Reviewer: Claude (Fable 5.1), author of the accepted WS5-A synthesis;
  not author of the cut draft, the seeds or the spike
- Date: 2026-10-12
- Base: `8e0d7f81`; the Cut 13 draft is the uncommitted diff to
  `tickets.yml`, `contracts.md`, both READMEs and the macro plan
- Checks run here: `tickets.yml` parses (13 cuts, 28 workstreams, 99 unique
  tickets; LDG-3019 8 criteria, LDG-3020 9, LDG-3021 7); `git diff --check`
  clean on the Cut 13 files; two public-API probes for LDG-3021 (Section 3);
  no production, test or evidence file touched; no private data read

## 1. Verdict

**PASS_AFTER_PATCHES.** The draft owns every accepted decision, contract
change and gate, the contract edits match synthesis Section 5, the spec-cut
decisions are within the synthesis's promoted questions, and the governance
routing is correct except for two Section 9 obligations with no home. Four
patches are required before acceptance, all in-place and none a design
decision. The registered LDG-3021 input is narrower than the defect: a
reproducer run here shows every one-feature sweep fails to save, including
the concrete map and the plain list that acceptance criterion 4 currently
asks to leave unchanged. No `NEEDS_TYPE_2` item.

## 2. Type 1 Ownership Table

| Accepted item | Owner | Criterion that can fail |
| --- | --- | --- |
| D1 exact rule-3 bytes | LDG-3019 scope; Cut 13 decision (1) | acc. 1 (ten roots through production seal, both platforms); acc. 2 (order assertion gut fails the golden detector) |
| D2 process-local verified set over held-store | LDG-3020 scope; decision (2) | acc. 2 (one complete check per process, none per candidate or fold); acc. 4 (cold after serialization and in a worker) |
| D3 key, generation, population, invalidation, `:memory:` | LDG-3020 scope | acc. 3, 4, 5, 6 |
| D4 three read classes; aggregates are metadata, rows are not | LDG-3020 acc. 1; Snapshot Contract clause | acc. 1 fails on an unclassified reader |
| D5 mandatory marker, legacy refusal, no fallback | LDG-3019 scope; decision (3) | acc. 3 (missing, rule 1, rule 2 refuse with one class; no old encoder executable) |
| D6 UX: cold first use, eager `verify = TRUE`, validate recomputes, no knob, info reports state | LDG-3019 acc. 4; LDG-3020 acc. 3 and 7; decision (4) | acc. 3 (recompute on a warm entry); acc. 7 (truthful flag after seal, failure, reset) |
| D7 two ordered tickets, ticket 1 retains coverage | Cut 13 sequencing; LDG-3019 acc. 8 ("lands before LDG-3020 starts") | see Section 4 on reviewability |
| D8 gates retained | Section 6 gates below | |
| D9 scope boundary | Cut 13 `out_of_scope` | matches synthesis Section 9 except the two obligations in Section 5 of this review |
| Section 5: Snapshot Contract (rule 3 by reference, marker, legacy, classes, distinction clause, split-store ensure, eager verify) | contract diff lines in the Snapshot Contract | all seven elements present; `instrument_id` from summary named as non-metadata per the final-review patch |
| Section 5: Execution Contract (ensure, miss recomputes, sweep and walk-forward once) | contract diff | present |
| Section 5: Availability Contract (facts inspection ensures) | contract diff | present |
| Section 5: Persistence Contract (reconstruction ensures; legacy not executable) | contract diff | present |
| Section 5: Verification Contract (golden roots on both CI platforms; CI clocks advisory) | contract diff | present |
| Gate 1 golden roots | LDG-3019 acc. 1 | can fail |
| Gate 2 mutation, hostile order, gut | LDG-3019 acc. 2 | can fail |
| Gate 3 cost on the registered host, bar population, encoder share, exponent | LDG-3019 acc. 5 | can fail; thread pinning is a nit below |
| Gate 4 memory: one block; bar and fact peaks separate | LDG-3019 acc. 6 | can fail |
| Gate 5 end-to-end clocks after ticket 1 and after ticket 2 | LDG-3019 acc. 7; LDG-3020 acc. 8 | can fail only against a baseline; see Section 4 |
| Gate 6 verified-set counters | LDG-3020 acc. 2, 3, 4 | can fail |
| Gate 7 census completeness | LDG-3020 acc. 1 | can fail |
| Gate 8 legacy refusal on every class-3 entry | LDG-3019 acc. 3 for retained calls; LDG-3020 acc. 1 for readers without one | can fail; the interim gap is discussed in Section 4 |
| Synthesis 3.5: LTB-0018 literal re-pinned by decision | **unowned** | the pinned-hash test (`tests/testthat/test-snapshot-timestamp-branches.R:223`, claim LCL-0015) will fail under rule 3 and nothing names the decision that moves it |
| Synthesis 3.5: ticket 1 records the Sharadar rebuild time | **unowned by design** | Cut 13 `out_of_scope` defers the rebuild; the record must move to the WS7 cut explicitly |
| Synthesis 9: fact-projection memory to the memory release | **no home** | neither the roadmap memory row nor the pipeline mentions it |
| Synthesis 9: `ledgr_sweep_open()` class-2 option to sweep-persistence follow-ups | **no home** | the pipeline row does not mention it |

Every ticket acceptance criterion read here names a witness that can fail,
with one exception: LDG-3021 criterion 4 cannot fail in the intended
direction because the behavior it preserves is the defect (Section 3).

## 3. Independent Reproduction Of LDG-3021

Two scratch scripts ran `pkgload::load_all()` on the current tree with a
two-instrument simulated snapshot and `ctx$flat()`:

| Features | Grid | Fingerprints per candidate | `ledgr_sweep_save()` |
| --- | --- | --- | --- |
| `ledgr_feature_map(signal = ledgr_ind_sma(ledgr_param("n")))` | `ledgr_grid_cross(features = ledgr_feature_grid(n = c(2L, 3L)))` | 1 / 1 | `ledgr_config_invalid_json` |
| `ledgr_feature_map(signal = ledgr_ind_sma(2L))` | strategy grid of two rows | 1 / 1 | `ledgr_config_invalid_json` |
| `list(ledgr_ind_sma(2L))` | strategy grid of two rows | 1 / 1 | `ledgr_config_invalid_json` |
| map with two features | feature grid | 2 / 2 | saved |
| no features | strategy grid | 0 / 0 | saved |

The failing frame is `ledgr_sweep_storage_json(row$feature_fingerprints[[1]])`
in `ledgr_sweep_storage_candidate_rows()` (`R/sweep-persistence-schema.R:104`,
`:132` in the row builder). The cause is exactly the one LDG-3021 names:
`canonical_json()` treats a length-one character as JSON text to parse
(`R/config-canonical-json.R:114-123`), so a single fingerprint is rejected
while `character(0)` encodes as `[]` and two fingerprints as an array. The
registered shape is therefore one instance of "any sweep with exactly one
feature". The ticket's scope sentence ("zero, one and many fingerprints") is
right; its source-table framing and acceptance criterion 4 are not.

## 4. Type 2 Assessment

**Workstream 27 shape.** One workstream for the encoder and the reuse is
coherent: both serve one claim and share the same guard sites. The cost is
that the synthesis's D7 "each independently reviewable" becomes "reviewed
together at close": LDG-3019 lands alone as a commit but is not reviewed
alone. The maintainer chose this on 2026-10-12 in the macro plan, so it is
not for this review to reverse. It should, however, be explicit that the
close review may accept LDG-3019 on its own evidence if LDG-3020 fails,
otherwise a reuse defect could hold a finished identity change hostage.

**Interim legacy gap.** Between the LDG-3019 commit and the LDG-3020 commit,
a class-3 reader that has no verification call today (`ledgr_experiment()`,
`ledgr_snapshot_quarantine()`, `summary()` of a snapshot, the interactive
tools) would still read a legacy snapshot's rows without refusing. This is
the sequence the synthesis itself bound (ticket 1 guards existing calls,
ticket 2 adds the census), it exists only on an intermediate commit inside
one workstream, and no accepted state exposes it. Acceptable; the WS27 close
review should state it was closed.

**Workstream 28 separation and dependency.** A separate claim is right; the
two workstreams share no file (LDG-3021 lives in
`R/sweep-persistence-schema.R`, Workstream 27 in hashing, sealing, the guard,
inspection and the ensure sites). The dependency on completed Workstream 27
is not necessary for correctness: the LDG-3021 oracles compare fingerprints,
params and provenance, none of which is a snapshot root, and a saved sweep
carries whatever stored root the snapshot has. The stated reason (exercise
the artifacts against the final identity) is served equally by rerunning the
small suite after Workstream 27. Keeping the dependency delays an S-effort
user-facing P0 behind two L tickets. Recommendation, not a requirement:
make Workstream 28 depend on 26 so it may land first or in parallel.

**Independent reviewability of LDG-3019 and LDG-3020.** Each carries one
correctness claim plus its evidence; neither has accumulated a second. The
only overlap is end-to-end clocks recorded twice, which is intended.

**Performance and memory inputs.** Adequate to implement; the ten roots, the
0.676/0.999 us per bar, the 1.038/1.001 exponents, the 149/130 MB bar peaks
and the 418/474 MB fact peaks are recorded CSVs, not prose. Three points
need stating before implementation rather than during evidence:

- The 56.6 s current-hash figure is a one-machine scratch measurement from
  the response stage, and the 55 s per Sharadar run is derived from a
  sampled profile. Gate 5's "after this ticket" clocks need a same-host
  before-arm; the Workstream 8 regression suite's last accepted record is
  the registered before-arm for the fixture shapes, and the Workstream 22
  Sharadar clocks for the aggregate shape. LDG-3019 should name them.
- The spike's Ubuntu encoder median is 0.999 us per bar, at the spike's
  limit. The 1.5 us production gate includes retrieval measured at about
  0.15 us per row; the margin on the registered host is real only if that
  host is the Windows machine the spike used. If the registered host is the
  WSL Ubuntu environment, the margin is about 0.35 us. Not a blocker; the
  ticket should say which host is registered.
- Nothing else must be remeasured first. The fact-projection peak at the
  Sharadar population is correctly left to ticket evidence.

## 5. Required Patches

1. **LDG-3021, acceptance criterion 4 and Cut 13 `source_table`.** Replace
   "concrete one-feature maps ... retain their current rows, JSON and public
   behavior" with: concrete one-feature maps and one-feature plain lists,
   which cannot be saved today, save, reopen and promote exactly like the
   parameterized map; featureless and multi-feature sweeps and existing
   saved sweeps retain their current rows, JSON and behavior. Restate the
   source-table shape as "every sweep whose candidates resolve to exactly one
   feature fingerprint", with the three failing forms recorded here.
2. **LDG-3019, scope and acceptance.** Own the LCL-0015 / LTB-0018 re-pin:
   the checked-in bars fixture is re-pinned to its rule-3 root under the
   accepted synthesis, the commit message names the deciding artifact, and
   the claim's detecting block is updated in `tests/claims.yml`. Without
   this the first implementation commit fails a registered identity pin and
   invites a silent literal change.
3. **LDG-3020 scope and Cut 13 decision (5), raw-connection key.** State
   that the key is always the snapshot store: for a run-store connection in
   split mode (derived-state reconstruction) the key comes from the run
   config's `snapshot_db_path`, as `ledgr_rebuild_derived_state()` already
   resolves it (`R/derived-state.R`, `ledgr_snapshot_db_path_from_config()`);
   `dbGetInfo(con)$dbname` keys a raw connection only when that connection
   is the snapshot store. As written, "cacheable when `dbGetInfo(con)$dbname`
   resolves a stable non-memory path" keys the run store in split mode,
   which the contract clause forbids.
4. **Cut 13 `out_of_scope` or LDG-3019.** Say where synthesis 3.5's "ticket 1
   records the rebuild time" now lives: the WS7 cut that performs the
   ledgr-research lake rebuild records it. One sentence closes the unowned
   row above.

## 6. Should-Fix And Nits

Should-fix:

- **Workstream 27 review reason.** Add that the close review may accept
  LDG-3019 on its own evidence if LDG-3020 is returned (Section 4).
- **Workstream 28 dependency.** Depend on Workstream 26, not 27 (Section 4).
- **Two Section 9 obligations without a home.** The accepted synthesis
  routes the retained fact-projection peak to the post-v0.2.2 memory release
  and the `ledgr_sweep_open()` class-2 option to the sweep-persistence
  follow-ups; neither the roadmap memory row nor the pipeline's
  `sweep-persistence-follow-ups` row mentions them. One sentence each, at
  acceptance, keeps the pipeline's "registered once with exact source" rule.
- **LDG-3019 acceptance 7.** Name the before-arm records (Section 4).

Nits:

- The regression suite does not pin DuckDB threads (`helpers.R` opens
  connections with defaults). LDG-3019's one-thread gate must set
  `threads = 1` explicitly on the measured connection and say so in the
  record, or the gate measures the host's core count.
- Cut 13 decision (3) names `ledgr_snapshot_hash_rule_unsupported` for an
  unrecognized future marker; today that class also fires for any marker
  outside 1 and 2 (`R/availability-persistence.R:159-165`). After rule 3 the
  set is {3}; the ticket should confirm the class keeps its "unrecognized"
  meaning and does not fire for legacy markers, which take
  `ledgr_snapshot_rebuild_required`.
- Spec-cut names `ledgr_snapshot_rebuild_required` and
  `ledgr_snapshot_hash_order_invalid` are new and consistent with the
  `ledgr_snapshot_*` vocabulary; `LEDGR_SNAPSHOT_CORRUPTED` is retained as
  the synthesis required. No hidden design here.
- `verified_in_process` and `hash_rule_version` as `ledgr_snapshot_info()`
  columns, and the print line, resolve the synthesis's spec-cut question
  without widening it. The private nonce stays private. Fine.
- The macro plan's header paragraph (now "Cuts 1 through 12") and the
  packet README describe the draft accurately.

Governance routing checked: WS5-A is owned by Cut 13 and the pipeline row
reads `Obligations open (WS5-B only)`; the decisions bridge row remains; all
five "Accepted change pending" links to the policy were removed from the
rewritten contract sections and no stale one remains; the packet README
states the draft and review state.

Scope-creep check: no ticket authorizes a saved-sweep schema or identity
migration, a `canonical_json()` behavior change (LDG-3021 forbids it and
stops for Type 2 if needed), component hashes, Merkle trees or a registry,
DuckDB-defined identity, a public bypass or cadence, legacy-root migration,
the WS5-B artifact policy, or the lake rebuild. All are named in
`out_of_scope` or in the tickets' negative clauses.

## 7. Review Accounting

Three invocations over three tickets, 1.000 against the 0.5 gate. The two
claims are genuinely different (snapshot identity and reuse; persistence of
one JSON column), share no file, and would mislead a single reviewer if
merged into one close review, because a pass on one could mask a failure of
the other. Padding the cut with unrelated tickets to lower the ratio would
be the dishonest option. Recording the breach is right. The one structural
alternative, moving LDG-3021 into the next larger cut, delays a P0 defect
users hit on the documented feature-map path; if the maintainer prefers that
trade, dropping the Workstream 28 dependency (Section 6) is the cheaper way
to the same ratio relief because the fix can then land early without waiting
for Workstream 27's evidence.

PASS_AFTER_PATCHES
