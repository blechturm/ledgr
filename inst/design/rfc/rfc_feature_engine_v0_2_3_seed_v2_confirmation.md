CHANGES_REQUIRED

Mode: Type 1 confirmation; independent session, 2026-11-16.

Reviewed detached `fbe5c0703e71e6da334b3dae212f4214d8d059f6`. References below are relative to `C:/Users/maxth/ledgr-wt/fe-seed-confirm`; the seed filename means `inst/design/rfc/rfc_feature_engine_v0_2_3_seed_v2.md`. The direction and four maintainer answers remain unchanged. Three bounded text corrections are required.

| Finding | Applied faithfully and completely? | Seed v2 evidence |
| --- | --- | --- |
| F1 | Applied. Precedence corrected, re-measured table reconciles; savings remain subject to paired measurement. | `rfc_feature_engine_v0_2_3_seed_v2.md:84-105`, `:125-126`, `:210-211` |
| F2 | Applied. Sample estimates, unresolved costs, TTR-inclusive bucket, D+2 formatting and paired-measurement qualification. | `rfc_feature_engine_v0_2_3_seed_v2.md:86-90`, `:105-128`, `:210-214` |
| F3 | Not fully. Certified pruning and cutoff scope are retained, but the callback boundary says treated-only instead of preserving raw/treated selection. C1 below. | `rfc_feature_engine_v0_2_3_seed_v2.md:198-200`, `:215-229` |
| F4 | Applied. Pin differential, values/evidence/refusals, RNG/probes, hostile cases, durable failure, representation-test reason and paired timing are present. | `rfc_feature_engine_v0_2_3_seed_v2.md:221-235`, `:258-287`, `:395-416` |
| F5 | Applied. Registered seams retained; probe-comment correction included. | `rfc_feature_engine_v0_2_3_seed_v2.md:154-157`, `:251-256` |
| F6 | Applied to the proposal: dependency census, separate identities, mutation tests, bounded hashing and later adapter identity. Its supporting probe claim needs C2. | `rfc_feature_engine_v0_2_3_seed_v2.md:171-184`, `:236-250`, `:294-320`, `:326-329` |
| F7 | Applied. Segment/readiness/bounds records and leading/trailing evidence remain; only proven-absent exceptions disappear. | `rfc_feature_engine_v0_2_3_seed_v2.md:362-369` |
| F8 | Applied. Contextual certified gate, conservative coverage recount, unchanged causality, general oracle, fail-closed debug comparison and independent pin checks. | `rfc_feature_engine_v0_2_3_seed_v2.md:336-380` |
| F9 | Applied. Emitted functions/captures/params/declarations frozen; fingerprint pins, certification and concrete-diff escalation retained. | `rfc_feature_engine_v0_2_3_seed_v2.md:326-334` |
| F10 | Applied. Deterministic backend/input/catalogue identity, raw/output separation, compatible sharing, canonical certification, hostile tests and distinct later backends. | `rfc_feature_engine_v0_2_3_seed_v2.md:291-324` |
| F11 | Not fully. Identity layers and invalidation boundary are corrected, but the conditional post-warmup-NA oracle-ledger exception is missing. C3 below. | `rfc_feature_engine_v0_2_3_seed_v2.md:40-42`, `:188-194`, `:393-416` |
| F12 | Applied. Concrete-fingerprint union, remaining candidate work and existing reuse boundary are stated. | `rfc_feature_engine_v0_2_3_seed_v2.md:382-391` |
| F13 | Applied. Cache-miss framing, required-field admission slicing and duplicate explicit-precompute ownership are removal candidates under the pin/timing gate. | `rfc_feature_engine_v0_2_3_seed_v2.md:210-235` |

C1. Preserve the raw/treated callback boundary (F3).

At seed lines 198-200 and 217-220, "treated" loses an observable distinction. `R/history-features.R:342` selects raw fields for `input_carry = "excluded"`; `:230-242` supplies every OHLCV column to the frame. A custom close-only callback can inspect a non-required open gap: `as.numeric(is.na(bars$open))` distinguishes raw from carried open. A frame-only source probe returned `0,1,0` with the current raw selection and `0,0,0` with an always-treated substitution. Thus that substitution is not value-identical. This is the existing boundary required by F3 and `inst/design/contracts.md#contract-context-indicator-computation` / `#contract-context-strict-features`.

Replace the constraint at seed lines 198-200 with:

> - **The custom callback boundary.** Custom callbacks receive the complete instrument/time/OHLCV frame for their segment or window, using raw fields when `input_carry = "excluded"` and policy-treated fields otherwise. `required_fields` restricts admission, not callback columns. Narrowing this boundary needs a contract decision (F3).

Replace stage 1 item 2 at seed lines 215-220 with:

> 2. **Narrow treatment only where certified constructor behaviour proves omitted fields unobservable** (F3). Compute the field union from certified canonical definitions, not source labels or claimed metadata. Preserve today's complete raw and treated callback inputs for custom definitions, including unregistered TTR forms; retain all five fields and the existing input-carry choice between raw and treated fields. Share treatment across definitions only within each instrument/knowledge cutoff, preserving probe behaviour. A broader restriction requires an explicit contract decision outside this neutral cut.

For consistent terminology at seed lines 222-223, replace "pass the treated close vector directly" with:

> pass the numeric close vector selected by the existing input-carry rule directly

C2. Narrow the probe attribution.

Seed lines 182-184 say the review's probe mutated each listed helper, including the TTR catalogue matching helpers. The committed probe mutates exactly eight individually named helpers (`dev/spikes/feature_engine/seed_review_probe/review_probe.R:95-104`); catalogue matching is absent. Its omission from the engine hash is supported by source inspection, not that experiment.

Replace seed lines 182-184 with:

> The review's probe changed the eight individually named helpers above in a private copy, and the hash stayed the same. The catalogue matching helpers are also outside the named-helper hash, as source inspection shows; the probe did not mutate them. The contract binds every helper of the calculation (Availability-Aware Strict Features).

C3. Restore F11's conditional oracle exception.

Seed lines 40-42 exclude the separate NA chore, but lines 188-194 and 265-267 otherwise require exact pin refusal parity. F11 explicitly required preserving the chore's deliberate oracle-difference ledger if it lands first. `inst/design/ledgr_v0_2_3_spec_packet/macro_plan.md:657-674` already owns that behaviour change. Exclusion alone does not state the required comparison exception.

Add after seed line 194:

> The separately accepted post-warmup-NA chore remains outside these neutral stages. If it lands first, retain its deliberate oracle difference against `d5b3a151` in the rules ledger. Compare against the pin with that recorded exception; do not absorb the behaviour change into this removal cut.

What I checked:

- **F1 precedence passes.** In `dev/bench/v0_2_3_lean_tuning_profile/feature_steps.R:39-59`, specific calculation children precede compute residual (`:53`), and projection children (`:54-56`) precede projection residual (`:57`); those residuals precede rebuild/payload wrappers (`:58-59`). Causality and certification retain their intentional outer ownership. Tiny synthetic stacks confirmed compute residual, runtime residual, direct formatting, named formatting and `ns$` handling.
- **The entire table passes.** All 60 bucket cells, six walls and six sample counts match the CSV under R's `sprintf("%.2f", ...)` formatting. Grouping: formatting = named pulse formatting + direct axis formatting; segment = frame + segment residual; planes = exceptions + records; checks = causality + certification; split/rebuild = both wrappers; other = ranges/bounds + projection indexing + projection residual + uncategorized other. Compute residual stays separate. These groups partition every CSV step exactly once. The three sweep split/rebuild sums are 0.003, 0.052 and 0.050 s. The 0.065 compute cell formats as 0.06; it is not a transcription error.
- **No untraceable empirical number found.** The compute table comes from `results/feature_split.csv:2-4`; H1 counts and SMA-pair timings from `results/features_h1.csv:2`; rounded end-to-end shares from `results/e2e_cut18_groups.csv:23,47,83`. Sweep bare-TTR clocks are 0.278 and 0.570 s in the new step CSV. Five repetitions are recorded in committed `summary.md:435`; the CSV itself does not record repetitions. The historical 0.13-0.20 s attribution remains traceable in the committed review/probe. D+2 formats follow `R/runtime-projection.R:35,40,48`.
- Read v1, F1-F13, v2, the preserved probe, relevant contract rule groups, RFC review rules and macro-plan NA/order passages. Checked callback selection, calculation/certification/sharing, projection/precompute, fingerprints, config/walk-forward identity and registered accessor callers. The shared timing runner records source/input identities (`dev/bench/timing/runner.R:68-85,167-178`), satisfying F4 through the required harness. Git comparison against `d5b3a151` found no differences in the five source files compared by the old probe.
- Inputs are adequate for this confirmation: committed aggregates establish the descriptive costs; source-derived boundary cases check semantic claims independently of smooth SMA fixtures. They establish no future speedup or production-gate coverage. Ran only tiny base-R checks, each successful script under 0.2 s; locale-startup warnings occurred. Did not rerun benchmarks, the old pinned-library probe, gates, package checks or private data.
- Verified HEAD, committed evidence files and a clean tracked diff using read-only `git -C` commands with the worktree's explicit gitdir. No tracked file was edited, no Git configuration changed, and no commit was made. This report is the only authored file.
