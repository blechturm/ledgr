# Cut 15 Review: Pre-History Foundations

- Mode: Type 1 cut review with an independent input and necessity check.
  Design concerns are returned as `NEEDS_TYPE_2`, not redesigned.
- Reviewer: fresh clean-context agent; did not author the draft, the spikes or
  the governance-lifecycle synthesis.
- Date: 2026-10-14
- Base: `f262e77a` on `spike/feature-keeping-v0.2.2`; the draft is the
  uncommitted diff to `tickets.yml`, the packet `README.md`, `macro_plan.md`
  and `rfc/README.md`, plus the untracked feature-keeping spike.
- Checks run here: `tickets.yml` parses as 15 cuts, 39 workstreams and 133
  unique tickets; Cut 15 has 8 workstreams and 15 tickets; every dependency
  resolves; `git diff --check` is clean; `test-documentation-contracts.R`
  passes (1,031 expectations, 0 failures); the draft modifies no product file.
  One reviewer probe (scratch store, public API, no package edit) tested
  precomputed-feature reuse after a captured value changes (finding R4). No
  private vendor data or credential was read.

## 1. Verdict

**CHANGES_REQUIRED**, with one `NEEDS_TYPE_2` item (N1, a narrow identity
decision). The cut's shape is sound. Each workstream has one claim, and the
two-track dependency graph is implemented exactly by ticket dependencies. The
three spike inputs support the product scope. But the draft does not yet
apply the accepted governance synthesis faithfully. It enlarges the guard into
blocking per-ticket detectors and drops three accepted obligations from the
pipeline. Four product tickets also contain an internal contradiction, an
acceptance item that cannot pass, or an unenumerated identity change.

## 2. Necessity and inputs

- **Governance (WS32-35).** Necessary: the synthesis is accepted and Section 7
  assigns the four workstreams. Excess: blocking detectors in LDG-3041, 3044,
  3046, 3047 and 3048 duplicate guard classes (R2). Omitted: the guard's
  Section 6 failure classes (R1), the M1 closeout reassessment (S9), the v11
  carrier's real owner (R3), and the receivers for check-mode activation (R4).
- **Feature-keeping spike.** It supports deleting both mechanisms.
  `evidence/run/decision.csv` recomputes RED: the cache saves 38.6 percent
  only on a repeated run but fails capture correctness (3 stale hits, 0 vs 3
  fills), and persistence has no public consumer. One input claim is wrong:
  "WS5-B has no surviving current artifact whose reuse key needs design"
  (macro_plan.md:1111). The explicit precomputed-feature object survives. It
  is validated by the same capture-blind fingerprint
  (R/precompute-features.R:186-198). The reviewer probe reused one after the
  captured value changed and `ledgr_sweep()` silently returned the stale
  result: no trades, final equity 100000, against 99995.43 fresh.
- **One-execution-mode RED.** Supports both-mode history.
  `probe_findings.md` shows the dense-only guard branch
  (R/run-snapshot.R:104), the different fill-timestamp conventions and an
  8.07x engine slowdown. Decision (9) and the history-wave row carry this
  correctly.
- **Growth-shape matrix.** Supports only the bounded TTR cleanup. Custom `fn`,
  result replay and availability fast-context stay with WS8, and segment-level
  TTR stays with WS4. The cut's `out_of_scope` names all of them. The witness
  set in LDG-3051 is wrong, however (R7).
- **Design tree.** The no-move decision is coherent and leaves no open
  decision. Cut 14 LDG-3037 excludes `inst/design` from builds and has a
  failing test, and its closed record routing the move to "the governance
  cut" is discharged by decision (2) and LDG-3045 acceptance item 5.

## 3. Workstreams

| WS | Claim soundness | Missing or excess scope |
| --- | --- | --- |
| 32 | Sound: one rule text plus one report-only guard | LDG-3042 failure classes, identity and registration diverge from synthesis Section 6 (R1); LDG-3041 wording pins excess (R2); reassessment rule untested (S9) |
| 33 | Sound; correctly waits for schema 120 | LDG-3044 blocking triangle detector duplicates the guard (R2) |
| 34 | Sound; no-move decision recorded | LDG-3046 blocking detector (R2); macro-plan edits overlap LDG-3055 (S1) |
| 35 | Sound | LDG-3047 assigns the v11 amendment it cannot own (R3); LDG-3048 evidence form narrower than Section 5 and lands too late (R10); README-ledger detector excess (R2) |
| 36 | Sound and necessary | Deleting `R/feature-cache.R` wholesale removes identity functions (R5); identity-rule version unsettled (N1); DDL split, test ledger and entry-point list (S2, S3, S7) |
| 37 | Sound and authorized | Uncertified TTR witnesses, forgeable wrapper identification, missing precompute caller (R7); unenumerated engine-version change (R8); no materiality rule (S5) |
| 38 | Sound pure refactor | Per-phase-commit gates of the amendment relaxed, and the clock workload is unnamed (R9); LDG-3054 has no seven-shape walk (S4) |
| 39 | Sound; the history wave needs a current-format real-data store | Order dependency on LDG-3045; prior-build reconciliation must not open a schema-119 store; supersedes LDG-3036 routing (S1) |

## 4. Required findings

**R1. LDG-3042 does not implement the synthesis Section 6 guard.**
`tickets[LDG-3042].acceptance[2]` invents "missing current entry" and
"duplicate owner". It omits Section 6's classes: a broken local target or
anchor (including a new use of baselined dead debt); a duplicate explicit ID
or used slug collision; missing or invalid Role, Status, row-state or verdict
tokens and required provenance; a changed row without its notice or marker;
stage-inconsistent source/bridge/receiver mappings; and malformed inputs. The
scope also omits the baseline identity (source, target, occurrence index), the
scan population, `claims.yml`, working-tree targets, the untracked-target
witness and the one registered review-lane detector block. Patch: cite Section
6 in `scope`. Replace `acceptance[2]` with fixtures for each Section 6 failure
class and each listed pass case, including the untracked-then-deleted target.
Add one item for the baseline identity tuple and population. In
`acceptance[3]`, state that the registered block tests the tool's own
fixtures, while scan findings never fail any lane in Cut 15.

**R2. Per-ticket blocking detectors activate check mode under another name.**
`LDG-3044.acceptance[4]`, `LDG-3046.acceptance[4]`, `LDG-3047.acceptance[3]`
and `LDG-3048.acceptance[4]` add failing tests for governance findings: orphan
bridges, unclassified or unredirected entries, stale state and receivers, and
README content. These are guard classes (Section 6). As package tests they
contradict `LDG-3042.acceptance[3]` ("no ... package test ... treats findings
as blocking") and decision (1). `LDG-3041.acceptance[4]` pins superseded
wording; Section 3 says the guard checks metadata fields, "not quoted historic
words". Patch: rewrite each item as "the LDG-3042 guard reports this class in
report mode on a reviewed fixture". For the README and wording items, rely on
the reconciliation table and close review instead. Keep only the roadmap
doc-contract pin that macro_plan.md:909-910 authorizes.

**R3. LDG-3047 assigns the v11 supersession carrier to the wrong owner.**
`LDG-3047.acceptance[2]` requires "the v11 amendment carries the required
supersession table". Acceptance preceded the history-wave amendment, so that
amendment is the first carrier and "the history wave owns" it (synthesis
Section 7, lines 260-264; macro_plan.md:896-898). It is written only after
Cut 15 closes, so this item can never pass in WS35, or it would pull history
design forward. Patch: replace it with "the history-wave pipeline row and
decision register state that its v11 amendment is the first
application-specific supersession carrier under synthesis Sections 4 and 7".

**R4. The rfc/README.md diff drops obligations and breaks two anchors.**
The draft deletes the `governance-lifecycle` and `snapshot-verification-policy`
rows. Both anchors have live inbound links (decisions.md:32-33), and Section 4
requires a redirect stub. Two of the governance row's duties have no ticket
owner: check-mode activation (a later cut; `LDG-3042.acceptance[5]` names no
receiver) and the M1 reassessment at v0.2.2 closeout. Its v11-carrier duty
moves to the history-wave row under R3. The WS5-B row has no explicit
maintainer drop in decisions (1)-(9), and its premise is false (Section 2).
Patch: keep `governance-lifecycle` as Obligations open, narrowed to activation
and closeout reassessment, and name it in `LDG-3042.acceptance[5]`. Keep
`snapshot-verification-policy`, narrowed to the reuse identity of precomputed
features, including capture-blind fingerprints, unless the maintainer adds a
decision (10) that drops it with a reason. Do not fix the precompute path in
Cut 15. Add the v11 carrier to the history-wave row.

**R5. LDG-3049 contradicts itself on `R/feature-cache.R`.** `scope` says
"Delete R/feature-cache.R" and also "Remove no unrelated feature-engine
identity". That file defines `ledgr_feature_engine_version()`,
`ledgr_active_feature_fingerprint()` and `ledgr_feature_def_fingerprint()`
(lines 3, 82, 114). Precompute, sweep, runtime projection and walk-forward
call them. Patch: "Delete the cache registry, key, get, set and clear
functions; move the three identity functions unchanged to an existing
feature-engine file; their digests stay byte-identical".

**R6. LDG-3050 must state its identity consequence.** `features$persist` is
part of the config payload (R/backtest-config.R:246, 253) and therefore of
`config_hash`, so every run, sweep-candidate and walk-forward identity changes.
`LDG-3050.acceptance[4]` says only "intended config ... changes are
enumerated". Patch: name `config_hash` and its derived identities (experiment
hash, `session_id`, candidate keys) as the intended changes, and prove that
everything else is identical. Which identity rule applies is N1.

**R7. LDG-3051's witnesses cannot run, and its skip is forgeable.**
`acceptance[1]` requires TTR SMA, EMA, RSI and MACD strict witnesses. Only
`ledgr_ind_ttr("SMA", input = "close", n)` is certified
(contracts.md:1449-1455; R/indicator-ttr.R:225-236, 255-270). The others
carry no `gap_contract` and refuse with `ledgr_indicator_gap_unsupported`.
Certifying them would reopen WS4.
`scope` also does not say how "the package TTR wrapper" is identified; a
`source = "TTR"` label is user-settable through `ledgr_indicator()`. Patch:
witnesses are the certified TTR SMA plus one custom strict-window indicator,
and uncertified TTR families still refuse unchanged. The parity skip
applies only when both `fn` and `series_fn` bodies are fingerprint-equal to
the `ledgr_ind_ttr()` templates. Add a hostile fixture: a hand-built
indicator labelled TTR with a mismatched `fn` must still refuse. Include the
precompute caller (R/precompute-features.R:661, per growth-shape findings) in
byte parity.

**R8. LDG-3051 changes a recorded identity digest without saying so.** The
availability `ledgr_feature_engine_version()` payload fingerprints the bodies
of `ledgr_compute_feature_series_strict()`, the scalar reference and the
completeness mask (R/feature-cache.R:39-76). Editing the strict loop changes
that digest, which enters sweep and runtime metadata (R/sweep.R:304) and
precompute validation. Patch: add an acceptance item that the availability
engine-version digest changes as expected, the dense digest stays
byte-identical, and the consumers are listed (precedent: Cut 2 decision 6,
LDG-2941).

**R9. WS38 relaxes the accepted per-phase gates.** The amendment says "Each
phase is its own commit, byte-identical on the fixture ladder and within the
1.05 rule on paired clocks" (macro_plan.md:979-982). LDG-3053 has neither
per-commit gate, and LDG-3054 gates only the final tree; neither names the
clock workloads. Patch: in `LDG-3053.acceptance[1]` and
`LDG-3054.acceptance[2]`, require that each phase commit passes the full
ladder. Either require per-commit paired clocks or record a maintainer
relaxation to a final-tree clock in decision (7). In
`LDG-3054.acceptance[4]`, name the dense peer fixture and one availability
fixture.

**R10. LDG-3048's evidence form is narrower than Section 5, and it lands
too late.** Section 5 requires a pointer and a one-line result for each
acceptance item. It also requires G D4's empirical fields (input identity,
environment, source commit, reproduction command, result and clock) where
they apply. "Pointer plus one sentence" drops the empirical fields. WS35 is
the last governance workstream, so most product tickets would close first.
Patch: restate Section 5 exactly in `LDG-3048.scope`, and add to Cut 15
`review_lifecycle` that Cut 15 ticket evidence uses the Section 5 form from
its first ticket.

## 5. NEEDS_TYPE_2

**N1. Identity rule version after removing `features$persist`.** Decision (4)
removes the field from identity but does not say whether
`ledgr_identity_rule_version` (R/config-hash.R:64; contracts.md:306-314)
stays at `2L` or moves to `3L`. LDG-3004 is the precedent: it bumped the rule
when the payload changed. The accepted sources do not settle this. The
maintainer chooses: (a) bump to rule 3, with a contract edit and rule-2
refusal; or (b) keep rule 2, with the recorded reason that schema 120 already
partitions every stored identity. Record the choice in decision (4).

## 6. Should-fix and nits

- **S1.** LDG-3055 edits the macro plan's "Remaining order", which LDG-3045
  creates. Add `LDG-3045` to `LDG-3055.dependencies`. In `acceptance[3]`,
  reconcile against the prior build's recorded aggregates; a schema-119 store
  refuses and must not be opened. Note that LDG-3055 supersedes LDG-3036's
  "WS7 lake rebuild with dividend facts owns the next private rebuild", and
  say whether the dividend rebuild remains a later second rebuild.
- **S2.** LDG-3049 and LDG-3050 change setup in about 20 test files and the
  golden fixtures. AGENTS.md requires a stated reason for each test change.
  Add a test-change ledger and the registered-block count delta to the
  evidence.
- **S3.** Align the entry-point lists: LDG-3049 omits backtest and reopen, and
  LDG-3050 omits pulse-snapshot.
- **S4.** Require a verbatim seven-shape walk in LDG-3050 and LDG-3054.
- **S5.** LDG-3051 `acceptance[5]` cannot fail ("or records a truthful
  materiality miss"). Predeclare the threshold and what a miss means.
- **S6.** State that WS37-39 make no `contracts.md` edit while WS33 runs; any
  needed edit joins WS33.
- **S7.** `R/db-schema-current.R:114-115` holds `persist_features` and the
  cache columns. State that LDG-3049 makes no DDL change and that LDG-3050 removes
  the columns under schema 120, and give the column values between the two
  tickets.
- **S8.** Decision (9) gates the RFC stage-2 resume on WS38 and WS39.
  Earlier amendments put fold extraction only before the implementation cut
  (macro_plan.md:996-1001). Confirm this serialization deliberately.
- **S9.** `LDG-3041.acceptance[2]` should include Section 5's reassessment:
  owner maintainer, trigger v0.2.2 closeout, dispositions keep, revise or
  drop, recorded in `rfc_cycle.md`.
- Nit: the WS33 and WS35 `depends_on_workstream` scalars name one predecessor;
  the ticket dependencies are correct.
- Nit: the history-wave row reads Active with paused prose (Section 3, line
  101); LDG-3047 should make it Paused.
- Nit: re-derive the probe line references (R/fold-engine.R:114, :154) at the
  base.
- Nit: LDG-3047 `acceptance[5]` "clean baseline" means a reviewed debt
  baseline.
- Nit: the R/feature-cache.R:4-5 comment becomes stale after deletion.

## 7. Governance and next step

M1/M2 are applied correctly. The 0.5 gate appears only as retired text,
findings get a packet artifact, a finding-free PASS is one line, and the third
correction round escalates. Implementation may begin after the maintainer
accepts the patched cut and decides N1. WS32 needs R1, R2 and R4 first; WS36
needs R5, R6 and N1. A focused re-review of the patched fields, or maintainer
acceptance of the patches directly, is sufficient.
