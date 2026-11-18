PASS

Mode: focused re-review 1 of workstream 42 (Cut 23), Type 1, after the close review. Fresh session; no implementation authorship. Reviewed 9a4a4697d220f93632cbdd2499f6af64f48eb0a4 against a6f94960. R/ remains unchanged from 68b505b9.

F1 is fixed. The expected names match the recorder's actual fixture output, including the records specific to each arm. The new controls fail for the intended reasons. Cut 22's changed-engine behavior is preserved. F2 is recorded accurately in the ticket evidence. No new finding.

Repository references below are relative to C:/Users/maxth/ledgr-wt/ws42-close-review. Probe and output references are relative to C:/Users/maxth/ledgr-wt/ws42-close-review-out.

F1. Required: fixed.

The unchanged-engine mode now loads an independent committed name manifest instead of deriving completeness from the base observations (dev/feature_parity/identity_check.R:55). It validates the manifest, then checks duplicates, the engine record count, missing names and unexpected names separately for each arm (:58-71). It compares the manifest's shared names (:73). Thus a shared loss cannot shrink the expected comparison set, and the old saved_sweep:/old_ prefix exclusions cannot hide an unexpected name in this mode.

I ran identity.R afresh using the supplied base and final installed libraries, saving a new base store/precompute under rereview_identity/base and using it from rereview_identity/candidate. The base emitted 158 rows and the candidate 164. Each name set exactly matches its manifest selection, without duplicates. The positive CLI check reports 156/156 equal, the unchanged bc6a3ea2-prefixed engine, successful reuse with 30 strategy calls and equal reused/fresh table digests, a readable old run with 30 equity rows, and the old sweep's retained engine (rereview_identity/positive_cli.txt).

The expected set is right for these fixtures. I independently enumerated identity.R's recording sites, rather than generating expectations from either observed arm:

- Twelve definitions each record eleven items: five identity/declaration fields and three fields for each of fn and series_fn (identity.R:54-69): 132 shared names.
- The resolved parameterised SMA records two fingerprints (:71-78).
- Each clock records seven experiment/sweep items and the two run-info fields present on these fixtures, config_hash and feature_set_hash (:96-115): eighteen names.
- Walk-forward records three items, including the score candidate keys present here, followed by the engine record (:125-128): four names.
- Saving the base store adds saved_sweep:engine and saved_sweep:snapshot_id (:136-137). Candidate reuse/readback adds four old_precompute records and four old_store records (:149-171).

That is 156 shared, two base-only and eight candidate-only names, exactly the committed manifest. The conditional recording sites were exercised: both reuse digests, the score keys and old-run equity count are present. Evidence: rereview_identity_probe.R and rereview_identity/probe.txt. Fresh values also match the predecessor's fresh observations except for the newly generated base snapshot ID; that base-only value is expected to vary with the fresh store.

The manifest remains independent of identity.R. A recorder addition, omission or rename will produce unexpected or missing names when the fresh outputs are checked, even if it occurs identically in both arms. My probe also removed a shared manifest name and added an extra one while leaving observations complete: these fail with UNEXPECTED and MISSING respectively in both arms. A deliberate manifest change, including an explicit --expected replacement, remains an expectation change for a reviewer to inspect.

I executed the unchanged checker code in isolated R environments over 1,453 cases, capturing its printed diagnostics and exit requests. These include deletion, duplication and renaming of every record in each arm; deletion, duplication and renaming of every shared record in both arms together; unexpected ordinary, saved_sweep: and old_store: names in each arm; manifest drift; and the predecessor's saved negative records. Every case produced its expected status and diagnostic. In particular, every base-only and candidate-only name received the same three mutation checks. Evidence: rereview_identity/mutation_summary.csv and mutation_details.txt; the driver is rereview_identity_probe.R. This is a small checker probe, not a package test-suite run.

The committed controls reproduce CONTROLS PASS. I separately invoked the checker through its real CLI on all five edited controls and inspected their full output. missing_both reports MISSING fingerprint:sma_20 in both arms. renamed_both reports that missing name and UNEXPECTED fingerprint:sma_20_renamed in both arms. The other controls report the changed engine, missing candidate identity and duplicate candidate identity respectively. They exit 1 with IDENTITY CHECK FAIL, rather than an execution error (rereview_identity/*_cli.txt and control_diagnostics.txt). The predecessor's jointly missing record now fails too. The fresh positive output and complete control summary match the committed round2 transcripts after startup messages and trailing whitespace are removed.

The changed-engine branch is textually unchanged from a6f94960. I also evaluated the Cut 22 checker from 6d12ef79 and the current default mode on the same valid changed-engine/refused-precompute records, then seven separate faults: unchanged engine, differing identity, missing candidate identity, accepted old precompute, strategy call before refusal, unreadable old run and changed stored-sweep engine. Exit statuses and complete diagnostics match in all eight cases (rereview_changed_mode_probe.R; rereview_identity/changed_mode.txt). The unchanged arms still fail that mode. No Cut 22 semantics were strengthened or weakened by this correction.

F2. Advisory: recorded.

inst/design/ledgr_v0_2_3_spec_packet/tickets.yml:7866 explicitly records the additional fingerprint-bearing, hand-edited return_1 carry case, its ledgr_indicator_history_contradiction refusal, the history_source = catalogue cause, its private-input scope, and the qualification that decision 3 is not equivalence over arbitrary hand-edited stored definitions. This satisfies the requested evidence correction without changing the product or reopening the accepted rebuild design.

I reproduced the case independently on both clocks with rereview_f2_probe.R. Each unedited public run succeeds and its rebuilt definition certifies builtin. Editing only the stored input_carry to eligible retains the fingerprint and overlay. The base definition has no history_source and certifies successfully; the final definition has history_source catalogue and refuses with ledgr_indicator_history_contradiction (rereview_f2/base/probe.txt; rereview_f2/candidate/probe.txt). R/precompute-features.R:664 supplies that provenance through conversion, and R/history-features.R:41-55 applies the existing carry-family check. This agrees with contracts.md#contract-context-indicator-computation and #contract-context-strict-features. The observed difference and its scope are recorded correctly; it supplies no public-input counterexample.

No new findings G1, G2, or others.

Checked:

- Read the original brief and close review, the correction diff, Cut 23/WS42/LDG-3256/3257 requirements and evidence, both cut-review reports, the F6 findings, AGENTS.md, the two named contract groups, the parity README and the seven optimization shapes. Retained round 1's accepted conclusions outside this correction.
- Inspected every changed file in a6f94960..HEAD, including the manifest, controls, README, command record, round2 outputs, ticket evidence and retained predecessor report. The correction changes no R/, registered tests, oracle fixtures or expectations, execution path, store format or engine identity. The two-arm loop is dev-checker work; no production data-scale loop was introduced.
- Ran the fresh identity workloads, positive CLI check, committed controls, full-diagnostic control checks, per-record mutation probe, predecessor negatives, Cut 22/default-mode comparison and focused F2 probes described above. All probes and outputs are under the authorized review output directory.
- Verified HEAD and an empty final git status --short using explicit git-dir/work-tree paths. Ordinary Git discovery hit the ownership check; explicit metadata paths worked without a Git configuration change. Git warned that the user ignore file was inaccessible. No tracked file was edited and no commit was made.

Not checked:

- Did not rerun the full suite, package check, timing windows, lean gate, full oracle/fault workload, census or registered witness files. Those accepted round-1 results were not reopened: the correction changes only identity tooling and evidence.
- Did not exhaust arbitrary private stored definitions or public inputs, or install a new package build. Used the supplied read-only base/final libraries; no library under AppData/Local/Temp, E:, ledgr-research or vendor data was used. R startup reported unavailable C.UTF-8 locale settings; the ASCII name checks and all probe assertions completed successfully.
