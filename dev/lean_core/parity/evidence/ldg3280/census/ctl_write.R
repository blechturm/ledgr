# Writes part_controls.csv and part_controls_excluded.txt (fork: retired controls and identity/format pins).
od <- "C:/Users/maxth/ledgr-wt/cut27-scratch/out/ldg3280"
r <- list()
add <- function(file, test, claim, asserts, depends_on, handling, target, why, in_seed = "no", probe = "pass") {
  r[[length(r) + 1L]] <<- data.frame(file = file, test = test, claim = claim, asserts = asserts,
    depends_on = depends_on, in_seed = in_seed, probe_status = probe, handling = handling,
    target_or_authority = target, justification = why, stringsAsFactors = FALSE)
}
q4 <- "pulse-plumbing Section 5 Question 4 (identity rule 5 -> 6, mode fields leave identity; each affected dependent identity recorded) with LR-12/LR-20; Cut 28 gate: the new value exists only after Cut 28 bumps ledgr_identity_rule_version"
st <- "pulse-plumbing Section 5 Question 4 and R8 (store schema/fingerprint successor of 125, old formats refused) with LR-12; Cut 28 gate: the successor schema exists only after Cut 28 removes the columns"

# ---- helpers ----
add("helper-fixtures.R", "helper-fixtures.R ledgr_test_run", "",
  "Test runner wrapper: builds ledgr_experiment(execution_mode = control$execution_mode %||% execution_mode) and runs it; accepts checkpoint_every = 10000L but never passes it on.",
  "ledgr_experiment(execution_mode=) argument (R/experiment.R:255); retired control checkpoint_every (formal only)",
  "b", "Drop the execution_mode and checkpoint_every formals and the execution_mode pass-through (and the control$execution_mode lookup); callers that pass a control have their own rows. Cut 28 gate: shown against the removed ledgr_experiment formal.",
  "Internal call site of a retired argument; with its default (audit_log, the one surviving path) every one of the 55 dependent blocks keeps its fixture and oracle. Finding: checkpoint_every is already ignored on the pin, so callers passing it (test-rng-isolation.R 'an ambient-RNG strategy gives identical results across store checkpoints and paths') never varied the checkpoint.")
add("helper-fixtures.R", "helper-fixtures.R ledgr_test_snapshot_backed_config", "",
  "Builds a snapshot-backed config and stamps identity_rule_version <- 5L before modernizing it.",
  "identity rule 5 literal (ledgr_identity_rule_version)", "c",
  q4, "config_hash_payload() and validate_ledgr_config() refuse any rule other than the current one, so the literal must follow the authorized bump; no oracle in the 10 dependent blocks reads the rule value itself.")
add("helper-fixtures.R", "helper-fixtures.R ledgr_test_modernize_config", "",
  "Rewrites a hand-built config into the current identity shape, stamping identity_rule_version <- 5L.",
  "identity rule 5 literal", "c", q4,
  "Same reason as ledgr_test_snapshot_backed_config; used by 14 blocks (2 of them also pass checkpoint_every and have own rows).")
add("helper-history-fixtures.R", "helper-history-fixtures.R ws42_with_schedule", "",
  "Rebuilds an experiment with a schedule, forwarding execution_mode = exp$execution_mode to ledgr_experiment().",
  "ledgr_experiment(execution_mode=) argument and experiment field exp$execution_mode", "b",
  "Delete the execution_mode = exp$execution_mode line. Cut 28 gate: shown against the removed formal.",
  "Internal call site forwarding a retired field unchanged; the 7 dependent blocks (test-history-*.R schedule cases) assert schedule behaviour only.")
add("test-config.R", "test-config.R ledgr_test_current_config", "",
  "File helper: stamps identity_rule_version <- 5L and current history/risk/corporate-action/state identities onto hand-built configs.",
  "identity rule 5 literal", "c", q4,
  "Hand-built configs (some start at 3L) are normalized to the current rule; 9 dependent blocks compare hashes relatively, except 'cost-model config hash is stable across internal cost-boundary refactors' (own row, golden).")
add("test-acceptance-v0.1.1.R", "test-acceptance-v0.1.1.R v011_make_runner_cfg", "",
  "File helper: modernizes a v0.1.1 runner config and stamps identity_rule_version <- 5L.",
  "identity rule 5 literal", "c", q4, "Literal must follow the bump or every one of its 3 runner blocks refuses at config validation.")
add("test-runner-snapshots.R", "test-runner-snapshots.R runner_snapshot_config", "",
  "File helper: builds a snapshot runner config and stamps identity_rule_version <- 5L.",
  "identity rule 5 literal", "c", q4, "Literal must follow the bump; 5 dependent blocks assert runner/snapshot behaviour, not the rule.")
add("test-terminal-policy-identity.R", "test-terminal-policy-identity.R terminal_policy_hash", "",
  "File helper: config_hash() of a minimal config with identity_rule_version = 5L, used to compare terminal-policy identities.",
  "identity rule 5 literal", "c", q4, "config_hash() refuses a non-current rule; the dependent block compares hashes relatively, so only the literal changes.")
add("test-fifo-opening-positions.R", "test-fifo-opening-positions.R fifo_opening_config", "",
  "File helper: builds a ledgr_config with execution_mode = execution_mode (default audit_log).",
  "ledgr_config(execution_mode=) internal argument", "b",
  "Drop the execution_mode formal and argument. Cut 28 gate: shown against the removed ledgr_config formal.",
  "Internal call site of a retired argument; its one caller (LTB-0023 resume block) never passes a mode.")
add("test-fifo-opening-positions.R", "test-fifo-opening-positions.R fifo_opening_run", "",
  "File helper: ledgr_experiment(..., execution_mode = execution_mode) then ledgr_run().",
  "ledgr_experiment(execution_mode=) argument", "b",
  "Drop the execution_mode formal and pass-through. Cut 28 gate: shown against the removed formal.",
  "Internal call site; 4 of 5 callers use the default; the mode-parity caller has its own row (c).")

# ---- retired-control blocks ----
add("test-accounting-consistency.R", "equity curve state is reconstructed from ledger fills", "",
  "For audit_log and db_live, a buy-then-sell run gives fills BUY/SELL at 101/102, one trade with realized 1, final cash/equity 1001 and total return 0.001.",
  "execution_mode = 'db_live' arm through ledgr_test_run", "c",
  "LR-12 / R8 (db_live retired; pulse-plumbing Section 7 'replace the latter by single-path ... witnesses'): drop the mode loop and keep one run with the same literal oracle. Cut 28 gate.",
  "The literal oracle is independent of the mode and survives unchanged on the one write path; only the db_live arm, whose subject is retired, goes.")
add("test-backtest-audit-log-equivalence.R", "audit_log matches db_live results", "",
  "A six-bar BTC run gives identical fills, equity curve and diagnostics (including final_pulse_no_execution) under audit_log and db_live.",
  "execution_mode audit_log vs db_live", "c",
  "LR-12 / R8: delete the block; its claim (equivalence of the two write paths) is retired with db_live. Single-path content stays covered (final_pulse_no_execution by LTB-0525; durable vs memory equality by the run/sweep parity blocks). Cut 28 gate.",
  "The block has no surviving subject: both arms become the same path, so keeping it would assert x == x. Heavy-protocol file profile; no LTB id or claims.yml entry to retire.")
add("test-active-alias-runtime.R", "alias maps affect config identity independently of feature set identity", "",
  "Two configs differing only in alias name share the feature-set hash but differ in alias_map_hash and config_hash.",
  "ledgr:::ledgr_config(execution_mode = exp$execution_mode)", "b",
  "Delete the execution_mode = exp$execution_mode argument. Cut 28 gate.",
  "Internal call site forwarding a retired field; the assertions compare two configs built the same way, so dropping the field from both preserves the oracle.")
add("test-active-alias-runtime.R", "active alias identity is order- and parameter-stable at the right layers", "",
  "Alias-map hash and config hash are invariant to declaration order and change with parameters at the right layer.",
  "ledgr:::ledgr_config(execution_mode = exp$execution_mode)", "b",
  "Delete the execution_mode = exp$execution_mode argument. Cut 28 gate.",
  "Same as the sibling block: relative hash comparisons of configs built identically.")
add("test-feature-map.R", "feature maps preserve concrete feature-set identity while aliases affect config hash", "",
  "A feature list and an equivalent feature map share the feature-set hash; the map's alias changes config_hash.",
  "ledgr_config(execution_mode = exp_*$execution_mode)", "b",
  "Delete the two execution_mode arguments. Cut 28 gate.", "Internal call site of a retired argument; relative comparison unchanged.")
add("test-metric-context-storage.R", "metric context changes do not change execution config hashes", "",
  "Two experiments differing only in metric context produce identical config hashes and no metric_context field.",
  "ledgr_config(execution_mode = exp$execution_mode)", "b",
  "Delete the execution_mode argument. Cut 28 gate.", "Internal call site; relative hash equality unchanged.")
add("test-experiment.R", "ledgr_experiment builds a validated experiment object", "",
  "ledgr_experiment() returns a validated object with snapshot, universe, features, opening, timing/cost identities, execution_mode 'audit_log' and metric context, writing no run.",
  "experiment field exp$execution_mode", "c",
  "LR-12 / R8 (the execution_mode argument and field are removed): replace expect_identical(exp$execution_mode, 'audit_log') by an assertion that the field is absent. Cut 28 gate.",
  "A semantic assertion on a retired field; every other assertion is unchanged.")
add("test-experiment-store-schema.R", "runs.execution_mode rejects values outside current modes", "",
  "The runs.execution_mode CHECK refuses 'other' and admits 'db_live'.",
  "store column runs.execution_mode and its CHECK constraint", "c",
  paste("LR-12 / R8 and", "pulse-plumbing Section 5 Question 4 (stored columns removed, schema successor): delete the block; column absence is pinned by LTB-0258's regenerated catalogue. Cut 28 gate."),
  "Subject retired. Hazard: left unchanged, its expect_error on 'other' would pass vacuously (the column no longer exists) while expect_no_error on 'db_live' fails, so it must not be kept half-edited.")
add("test-experiment-store-schema.R", "run telemetry constrains execution_mode to current values", "",
  "The run_telemetry.execution_mode CHECK refuses 'other' and admits 'audit_log'.",
  "store column run_telemetry.execution_mode and its CHECK constraint", "c",
  "LR-12 / R8 and Section 5 Question 4: delete the block; absence pinned by LTB-0258's regenerated catalogue. Cut 28 gate.",
  "Same as the runs sibling, including the vacuous-pass hazard on the expect_error half.")
add("test-feature-inspection.R", "feature inspection views match across execution modes", "",
  "Inside the strategy, ledgr_pulse_features()/ledgr_pulse_wide() return nonempty long and wide views; the terminal views are identical under audit_log and db_live.",
  "execution_mode audit_log vs db_live", "c",
  "LR-12 / R8: one run on the single path; keep the in-callback view assertions, retire the cross-mode equality. Cut 28 gate.",
  "The cross-mode comparison has no second path; the inspection assertions inside the callback survive unchanged.")
add("test-pulse-context-accessors.R", "feature-map strategies match across execution modes", "",
  "Mapped feature value equals the scalar accessor inside the callback; fills and equity are equal under audit_log and db_live.",
  "execution_mode audit_log vs db_live", "c",
  "LR-12 / R8: one run on the single path; keep the in-callback accessor identity check (it stops the run on mismatch), retire the cross-mode equality. Cut 28 gate.",
  "Cross-mode parity has no surviving subject; the accessor check is the block's remaining claim.")
add("test-fifo-opening-positions.R", "db_live and audit_log opening-position accounting agree", "",
  "With an opening position (100 AAA at basis 50), fills, equity detail and reconstructed state are equal under db_live and audit_log.",
  "execution_mode audit_log vs db_live", "c",
  "LR-12 / R8: delete the block; opening-position accounting on the one path stays covered by the file's other blocks (LTB-0023 and the four opening-lot blocks). Cut 28 gate.",
  "Pure two-path parity; heavy_protocol profile; no surviving subject.")
add("test-pulse-seed-v2.R", "restart reads the same pulse seeds as a straight run on the same calendar", "",
  "A clean run and a max_pulses=3 attempt followed by a fresh run read the same v2 pulse-seed vector over the same 8 pulses.",
  "ledgr_config(checkpoint_every = 1L)", "c",
  "LR-20 (checkpoint_every retired, D3 terminal batches): drop checkpoint_every = 1L from ledgr_config(); fixtures and seed oracle unchanged. Cut 28 gate: before the switch the lean adapter refuses this control and the harness runs the pin, so the lean restart path is only exercised after the remap.",
  "The oracle (ledgr_pulse_seeds(7L, 1:8)) is independent of flush cadence; the per-pulse checkpoint was there for the retired pulse-resume path.")
add("test-pulse-seed-v2.R", "actual draws agree for continuous, restarted and windowed runs on the same calendar", "",
  "Draws through withr::with_seed(ctx$pulse_seed) give equal fills for a clean run, a max_pulses=5 attempt replaced by a fresh run (12 calls), and a window vs a direct slice run.",
  "ledgr_config(checkpoint_every = 1L)", "c",
  "LR-20: drop checkpoint_every = 1L; oracle unchanged. Cut 28 gate, as for the sibling restart block.",
  "Same reason as the restart block.")
add("test-rng-isolation.R", "an ambient-RNG strategy gives identical results across store checkpoints and paths", "",
  "An ambient-RNG strategy gives identical equity and fills with checkpoint_every 10000 and 3, equal fills through ledgr_run, and equal equity through ledgr_sweep.",
  "checkpoint_every through ledgr_test_run (ignored by the helper on the pin)", "c",
  "LR-20: drop the checkpoint arm (ck_small vs ck_large); keep the backtest vs ledgr_run vs ledgr_sweep RNG equivalence. Cut 28 gate.",
  "Its checkpoint subject is retired. Pre-existing weakness: ledgr_test_run never forwards checkpoint_every, so the two arms were already identical runs on the pin; nothing of value is lost.")
add("test-rng-isolation.R", "a seeded ambient-RNG fold agrees between ledgr_run and ledgr_sweep past the default checkpoint", "",
  "A 10,010-pulse seeded ambient-RNG run (past the 10,000-pulse default checkpoint) gives the same equity as its sweep candidate.",
  "the default engine.checkpoint_every = 10000 flush inside the fold (sweep uses 0)", "f",
  "LR-20 retires the in-fold flush this block was sized to cross. Question for the maintainer: keep it unchanged (it still passes and still proves run/sweep RNG parity on a long run), re-size it to cross the terminal batch bound (65,536 rows) so it guards RNG neutrality of terminal store writes, or retire it as redundant with the shorter run/sweep RNG blocks?",
  "No edit is forced and no oracle changes, but its named witness target (an RNG-neutral store write inside the fold) no longer exists after the switch, and choosing its successor target is a semantic choice.")
add("test-run-compare.R", "ledgr_run_compare compares stored completed runs without recomputation", "",
  "ledgr_run_compare() reads stored runs without recomputation or writes and returns metric and identity columns including execution_mode.",
  "reader column execution_mode in ledgr_run_compare()", "c",
  "LR-12 / R8 and pulse-plumbing Section 7 (remove execution_mode reader fields): remove 'execution_mode' from the expected column set (optionally assert it absent). Cut 28 gate.",
  "A reader-field assertion on a retired field; the no-recomputation and metric oracles are unchanged.")
add("test-run-store.R", "ledgr_run_info returns printable diagnostics and tolerates missing telemetry", "",
  "ledgr_run_info() returns completion, telemetry and provenance fields (execution_mode 'audit_log'), prints, and reports a FAILED status after a store edit.",
  "reader field info$execution_mode", "c",
  "LR-12 / R8, Section 7 (reader fields): replace the execution_mode equality with an absence assertion. Cut 28 gate.",
  "Only the retired field's assertion changes.")
add("test-run-telemetry.R", "successful runs persist compact telemetry outside the result print", "",
  "print(bt) shows no 'Execution Mode:' and no 'audit_log'; ledgr_run_info() has status DONE, execution_mode 'audit_log', finite elapsed, pulse_count 5, and prints 'Execution Mode:   audit_log'.",
  "telemetry/reader field execution_mode and its print line", "c",
  "LR-12 / R8, Section 7 ('Remove execution_mode telemetry/reader/config teaching'): drop the two positive execution_mode assertions; keep the print(bt) negatives and the other telemetry checks. Cut 28 gate.",
  "The negative print assertions remain true and keep their value; only the retired field's positive assertions change.")
add("test-run-telemetry.R", "failed runs persist minimum telemetry diagnostics", "",
  "A failing strategy leaves FAILED telemetry with execution_mode 'audit_log', finite elapsed and the error message, and one run_telemetry row selected with status, execution_mode, elapsed_sec.",
  "store column run_telemetry.execution_mode and reader field", "c",
  "LR-12 / R8 and Section 5 Question 4: drop execution_mode from the info assertion and from the SELECT; keep status, telemetry_missing, elapsed and error assertions. Cut 28 gate.",
  "The SELECT would error once the column is removed; the minimum-telemetry claim survives without the field.")
add("test-availability-parity.R", "[LTB-0064] incomplete completion evidence matches persisted record", "LTB-0064",
  "An incomplete availability run's completion evidence matches the persisted record, prints in order, run info prints every metadata label (including 'Execution Mode:'), and a rerun is a no-op.",
  "run-info print label 'Execution Mode:'", "c",
  "LR-12 / R8, Section 7 (reader/printing fields removed): remove 'Execution Mode:' from the expected label list (optionally assert it absent). Cut 28 gate.",
  "One label of a print-surface list; the completion-evidence oracle is untouched.")
add("test-result-output.R", "[LTB-0106] curated result prints respect selected columns", "LTB-0106",
  "Curated output tables print only the selected columns (here a ledgr_run_list fixture frame, built with an execution_mode column).",
  "fixture run-list frame column execution_mode", "c",
  "LR-12 / R8: drop execution_mode from the hand-built run-list frame so the fixture matches the post-switch reader shape. Cut 28 gate (only if the reader table constructor checks columns; otherwise the block passes unchanged).",
  "Fixture models a retired reader field; the assertion (selected columns print, no telemetry footer) does not read it. A fixture edit needs a stated reason, which is LR-12.")
add("test-result-output.R", "[LTB-0111] metadata prints align and bound elapsed precision", "LTB-0111",
  "A ledgr_run_info fixture (with execution_mode 'audit_log') prints 17 aligned metadata lines and bounds elapsed precision to 0.430.",
  "run-info print line 'Execution Mode:' and fixture field execution_mode", "c",
  "LR-12 / R8, Section 7: remove the field from the fixture and change the expected metadata line count from 17 to 16. Cut 28 gate.",
  "The line count is a semantic pin on the print surface and changes by exactly the retired line; alignment and precision assertions are unchanged.")

# ---- identity and format pins ----
add("test-pulse-seed-v2.R", "seeded configuration identity changes by the rule field only", "",
  "Real ledgr_run() configs pin unseeded/seeded config hashes and run_ids (2748c490..., 8e110242..., run_ac695906..., run_7818fbdf...); removing engine.pulse_seed_rule restores the pinned base seeded hash.",
  "config hash payload containing identity_rule_version 5 and engine.execution_mode/checkpoint_every", "c",
  paste(q4, "; the four golden hashes and two run_id literals are re-recorded as dependent identities"),
  "The relative property (only the rule field differs) is unchanged; the literal goldens change because rule 6 and the removed engine fields enter the payload. Section 5 Question 4 requires each affected dependent hash be recorded.")
add("test-config.R", "cost-model config hash is stable across internal cost-boundary refactors", "",
  "A fixed hand-built config (normalized by ledgr_test_current_config) hashes to 7559b6eb....",
  "identity_rule_version 5 in the hash payload", "c",
  paste(q4, "; golden re-recorded"), "The rule version is part of config_hash_payload(); no mode field is in this config, so the only change is the rule.")
add("test-sweep-parity.R", "scalar execution config hash remains pinned across sweep parity work", "",
  "A fixed hand-built config with identity_rule_version 5L hashes to 84194b28....",
  "identity rule 5 literal and golden hash", "c",
  paste(q4, "; literal and golden re-recorded"), "As above: rule literal must follow the bump and the golden changes with it.")
add("test-current-only-records.R", "[LTB-0264] stored record readers are current-only", "LTB-0264",
  "ledgr_identity_rule_version is 5L; configs carry rule 5; missing, older (1-4), double and character rules refuse at every current-only reader; a round trip keeps 5L.",
  "identity rule 5 pins", "c",
  paste(q4, "; pin the successor and add 5L to the refused older rules"),
  "The current-only claim survives; its current value moves to 6 and rule 5 joins the refused set, which strengthens rather than weakens the witness.")
add("test-history-foundation.R", "[LTB-0287] history policy is canonical identity input", "LTB-0287",
  "A run's config records identity_rule_version 5L and history policy changes its config hash.", "identity rule 5 pin", "c", q4,
  "Only the rule literal changes; the history-policy identity assertion is relative.")
add("test-identity-locale.R", "[LTB-0266] identity JSON is locale-independent across processes", "LTB-0266",
  "Canonical JSON and config_hash of a fixed config (identity_rule_version = 5L) are identical across collation locales in subprocesses.",
  "identity rule 5 literal in the subprocess script", "c", q4,
  "config_hash() refuses a non-current rule in the subprocess; the cross-locale equality oracle is unchanged.")
add("test-pit-consistency.R", "[LTB-0236] run and session identity bind snapshot content under identity rule 5", "LTB-0236",
  "Run configs record identity rule 5; equal content under two snapshot ids gives equal config hashes, different content under one id does not.",
  "identity rule 5 pin (also in the title)", "c", paste(q4, "; title wording follows"),
  "The content-binding claim is relative; only the recorded rule value (and title) changes.")
add("test-pit-consistency.R", "[LTB-0244] walk-forward sessions use current content identity", "LTB-0244",
  "A walk-forward session's meta records identity_rule_version 5L and identical arguments reuse the session.", "identity rule 5 pin", "c", q4,
  "Only the recorded rule value changes.")
add("test-risk-config.R", "risk identity participates in config_hash without a separate risk params layer", "",
  "Hand-built configs (identity_rule_version = 5L) show risk identity changes config_hash.", "identity rule 5 literal", "c", q4,
  "Relative hash comparison; the literal must follow the bump.")
add("test-risk-config.R", "risk config validation fails closed on mismatched or invalid plan identity", "",
  "A hand-built config (identity_rule_version = 5L) with mismatched or invalid risk plan identity refuses validation.",
  "identity rule 5 literal", "c", q4,
  "Must follow the bump or the config refuses for the wrong reason (rule), which would make the risk refusals vacuous.")
add("test-corporate-action-policy.R", "[LTB-0032] corporate-action policy is closed and versioned", "LTB-0032",
  "Corporate-action policy identity is closed and versioned; each alternative policy changes a config_hash built with identity_rule_version = 5L.",
  "identity rule 5 literal", "c", q4, "Relative hash comparison; literal must follow the bump.")
add("test-sweep-persistence-api.R", "saved sweeps save, list, open, and inspect compact artifacts", "",
  "Saved sweeps round-trip; the reopened object carries identity_rule_version 5L; a stored rule 3 refuses.",
  "identity rule 5 pin", "c", q4, "Only the current-value pin changes; the old-rule refusal (3) stays.")
add("test-sweep-persistence-schema.R", "saved sweep storage projections use canonical JSON and validate denormalized identity", "",
  "Saved sweep parent rows store canonical JSON and identity_rule_version 5L and validate denormalized identity.",
  "identity rule 5 pin", "c", q4, "Only the current-value pin changes.")
add("test-walk-forward-orchestrator.R", "walk-forward inspection helpers reopen completed and partial sessions read-only", "",
  "Walk-forward sessions reopen read-only; session meta records identity_rule_version 5L; a meta with rule 3 refuses.",
  "identity rule 5 pin", "c", q4, "Only the current-value pin changes.")
add("test-availability-fold-witnesses.R", "direct persisted rows match the reviewed baseline", "",
  "The direct availability witness reproduces the frozen v0.2.0.1 diagnostics, events, equity, completion and identity rows, with declared differences (schema 118 -> 125, identity rule 5, price basis, history, renamed source) and everything else exact.",
  "frozen identity.csv: runs.execution_mode column 'audit_log' and engine.execution_mode/checkpoint_every in config_json; actual schema '125' and rule 5L",
  "c",
  paste(q4, "and", st, "; add declared differences in the comparison (frozen fixture unchanged): the runs.execution_mode column and engine.execution_mode/engine.checkpoint_every are absent in the actual run, schema '125' -> successor, rule 5L -> 6L"),
  "After the switch the actual identity row lacks the mode column and engine fields that the frozen v0.2.0.1 row has, so expect_identical(actual_config, expected_config) fails unless the difference is declared, exactly as earlier rule/schema changes were declared in this block. The frozen evidence is never rewritten.")
add("test-schema-current.R", "[LTB-0258] current schema definition matches the schema-125 catalogue", "LTB-0258",
  "The independent current-schema definition reproduces every normalized row and dimension digest of the committed schema-125 catalogue (fixtures schema-current-golden.csv and schema-current-golden-rows.csv).",
  "golden catalogue rows for runs.execution_mode and run_telemetry.execution_mode (columns, ordinal positions, CHECK constraints) and the 125 literal", "c",
  paste(st, "; regenerate both golden fixtures for the successor schema and update the title and 125 literals"),
  "The golden catalogue is the store-format oracle; the authorized format change removes two columns and two CHECK constraints and shifts ordinal positions. Fixture regeneration is authorized only by the store bump and must be reviewed as a diff limited to those rows plus the version.")
add("test-store-gate-contracts.R", "[LTB-0260] store gate classifies every marker failure", "LTB-0260",
  "Every non-current marker classifies: 119-124 older, 999 newer, missing/invalid markers, and fingerprint mismatches on a '125' marker name the differing bindings.",
  "current store schema 125 literals", "c",
  paste(st, "; use the successor for the current-version cases and add marker '125' -> 'older'"),
  "With 126 current, a '125' marker classifies as older before any fingerprint inspection, so the fingerprint-mismatch witnesses must move to the successor; adding 125 to the older list keeps the precedence claim.")
add("test-typed-accounting-boundary.R", "[LTB-0550] typed accounting carrier owns fields and block boundaries", "LTB-0550",
  "Schema 125 binds the wide ledger catalogue; one prepared typed carrier validates rows as grouped blocks, carries ordering state and replays with exact reconciliation; trusted-write assertions refuse malformed producer rows.",
  "ledgr_experiment_store_schema_version == 125L pin (and trusted-write assertion witnesses)", "c",
  "pulse-plumbing Section 7 names this block (tests/claims.yml:4889, LCL-0539): keep the read field matrix, cross-block and replay mutations; update its schema pin for the authorized store change (Section 5 Question 4); move only its trusted-write assertion witnesses to explicit debug (R4/LR-15 narrowed by LR-26). Cut 28 gate for the schema pin.",
  "This row records the schema-pin half; the trusted-write half is a debug-only-assertion disposition that the parent's debug-class inventory should carry under the same Section 7 authority (one row per block in the merged inventory).")
add("tests/claims.yml", "LCL-0506 (LTB-0515, LTB-0516), LCL-0508 (LTB-0518), LCL-0539 (LTB-0550) registry entries", "LTB-0515;LTB-0516;LTB-0518;LTB-0550",
  "Registry scopes name the db_live writer and its validation order (4507, 4514), the DuckDB sink's audit_log and db_live method sets (4531), and 'Schema 125' (4891).",
  "db_live / audit_log / schema-125 wording in the claims registry", "c",
  "pulse-plumbing Section 7 (tests/claims.yml:4505, 4529, 4889 named explicitly) with LR-12: rewrite the retired live-writer parts of LCL-0506 into single-path/transaction witnesses, remap LCL-0508's method set, update LCL-0539's schema; the blocks themselves are in test-ledger-writer.R and test-typed-accounting-boundary.R.",
  "Registry text is a maintained detector input (profiles and smallest-failing-change); it must follow the block dispositions or the claim check reports drift.")

out <- do.call(rbind, r)
utils::write.csv(out, file.path(od, "part_controls.csv"), row.names = FALSE, quote = TRUE, fileEncoding = "UTF-8")

ex <- c(
  "test-schema.R:470-507 'validator fails if runs.status does not accept DONE' - hand-built runs DDL carries execution_mode, but the asserted refusal is the runs.status enum check, independent of extra columns; rerun at Cut 28 to confirm.",
  "test-schema.R:509-563 'create refuses an unmarked table before interpreting its constraints' - models an unmarked old store (schema 108) that rightly keeps the column; missing_marker precedes any column check.",
  "test-backtest-lifecycle.R:97-133 'durable backtest safety net checkpoints and messages' and :169-177 - DuckDB auto-checkpoint of the store, not engine.checkpoint_every.",
  "helper-fixtures.R:16 ledgr_checkpoint_duckdb - DuckDB WAL checkpoint, not the retired control.",
  "test-result-output.R:112-199 [LTB-0107] - asserts print(bt) has no 'Execution Mode:' line; stays true after the switch.",
  "test-store-gate-contracts.R:2-79 [LTB-0259] - pins binding names, types and count (31), not values; the rule and schema bumps change values only.",
  "test-schema-version-literals.R [LTB-0269] - census locations are in files outside the switch's code-ownership list (pulse-plumbing Section 7); rerun if Cut 28 edits a censused file.",
  "test-documentation-contracts.R:2152-2262 [LTB-0509] - matches 'schema 125' in a historical NEWS entry, which stays.",
  "test-one-execution-path.R:176-228 [LTB-0528] - rule-4 artifacts stay older than rule 6; the block mocks the old binding to 4L, independent of the current value.",
  "test-strategy-schedule.R:1316-1737 [LTB-0508] - uses ledgr:::ledgr_identity_rule_version symbolically.",
  "test-availability-schema.R, test-equity-corporate-action-facts.R, test-schema.R:165/185, test-sweep-persistence-schema.R:95, test-walk-forward-schema.R:25 - use ledgr_experiment_store_schema_version symbolically.",
  "test-availability-fold-witnesses.R:276-308 'run identity excludes exactly the three registered fields' - normalization of db_path/created_at fields; no mode or rule.",
  "test-walk-forward-identity.R - relative experiment-hash comparisons; the mode field leaves both sides equally.",
  "tests/claims.yml LCL-0088 ('both execution modes' = dense/availability), LCL-0089 ('without exposing execution-mode internals', stays true), LCL-0527 ('independent execution modes' = one vs two workers), LCL-0518/LCL-0241 scopes (already say rule 4; stale but not changed by this switch item).",
  "test-strategy-private-context.R:339 - a strategy parameter named 'live', unrelated.",
  "test-codebase-contracts.R:177, test-execution-spec.R, test-risk-fold.R, test-ledger-writer.R, test-sweep.R, test-fold-phase-contract.R, test-ws4a-carrier.R - hits owned by the parent or the other fork (not inventoried here).",
  "test-pulse-seed-v2.R:562-593 / :708-725 and other pulse_seed_rule pins - the pulse-seed rule, not the identity rule or a retired control."
)
writeLines(ex, file.path(od, "part_controls_excluded.txt"), useBytes = TRUE)
cat(nrow(out), "rows\n"); print(table(out$handling))
