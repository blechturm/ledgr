# Cut 21 review: Declarative strategy scheduling

Mode: independent cut review; Type 1 ownership and input check plus Type 2
ticket/workstream grain.

Baseline: product tree `1cd4e0c9` on `v0.2.2`, with the uncommitted accepted
scheduler RFC cycle and Cut 21 draft.

Verdict: **CHANGES_REQUIRED**.

The accepted scheduler is necessary and the implementation direction is ready.
Current public code has no declarative, identity-bearing schedule before P2;
the two real execution-spec construction sites are
`R/backtest-runner.R:1309` and `R/sweep.R:1698`; and the registered H1 result
shows material avoidable work. No Type 2 product decision is needed. Six cut
patches are required before implementation.

## Required patches

### F1 - High - Workstream 61 has no valid intermediate format

**Where:** `tickets.yml:330` (`cuts[21].sequencing`), `:2812-2830`
(`LDG-3111.scope`, `LDG-3111.dependencies`, `LDG-3112.scope` and
`LDG-3112.dependencies`), and `:865-870` (Workstream 61).

**Concrete failure:** LDG-3111 is currently required to land before LDG-3112.
It writes the new closed-vocabulary `scheduled_skip` diagnostic and changes
fold behavior while the sole current store remains schema 123 and lacks the
schedule provenance and counts needed to interpret that row. Such a store
passes the schema-123 gate at that commit, contrary to synthesis Section 4's
rule that one current store-format bump owns the diagnostic vocabulary,
provenance and telemetry together. Reversing the tickets is not sufficient:
schema 124 would then report compiled skips before the fold actually skipped
P2/P3. Neither intermediate is truthful.

**Minimal patch text:** append to Cut 21 sequencing and both ticket scopes:
"LDG-3111 and LDG-3112 are one atomic merge unit. The schema-124 DDL and gate,
schedule provenance/count writes and reads, `scheduled_skip` vocabulary, fold
branch, contracts, catalogue and registered oracles land in one commit; neither
ticket may be completed or merged alone." Keep the logical ownership split,
but make LDG-3112 depend on LDG-3110 as well as LDG-3111 and state that the
dependency is satisfied by the same atomic commit. The Workstream 61 review
runs only over that combined range. This is the smallest change that keeps
every mergeable commit and current-only gate coherent.

### F2 - High - The H1 gate changes the measured input and omits the shared-boundary rule

**Where:** `tickets.yml:328-329` (`cuts[21].source_table` and decision 8),
`:2842-2850` (`LDG-3114.scope` and acceptance item 3), and
`residual_cost_memory_closeout.md:17-20,126-133`.

**Concrete failure:** the 14.17-second lower bound was measured on the
registered private H1 **monthly-momentum** strategy over the 1,166-instrument,
7,213-session changing-membership input. LDG-3114 instead times the
minimum-variance article and still asks for a recovered share of that old
lower bound. Those clocks are not comparable. The current manual guards also
treat a missing predecessor as due, whereas the accepted schedule does not;
without synthesis Section 5's true shared boundary, the arms can differ at the
first pulse and cannot simultaneously satisfy exact due-date and economic
parity. Finally, "median ratio" does not say whether the gate is the median of
paired ratios or a ratio of two arm medians.

**Minimal patch text:** in LDG-3114 replace the timed minimum-variance arm with
"the exact registered H1 monthly-momentum strategy and snapshot identity that
produced the 14.17-second lower bound; the minimum-variance rewrite remains the
documentation witness." Add: "Both arms start at a true calendar boundary
with the same parent-axis predecessor, or at the first later boundary shared
by both arms. The gate is the median of at least three within-pair
`scheduled/manual` wall-time ratios, in alternating order, and is `<= 0.90`."
Require the record to retain input snapshot hash, strategy/source identity,
environment and host controls, product and acquisition commits, exact command,
raw paired clocks and result. Call the tracked runner public source over a
registered private H1 input; do not imply that the vendor rows are public.

The 0.90 threshold itself is proportionate: the accepted lower bound is 22.6%
of the diagnostic wall, so a ten-percent end-to-end gate leaves substantial
allowance for the retained P1/P4/P5 work and scheduler overhead while still
detecting a non-material implementation.

### F3 - Medium - Identity, recovery and contract ownership overlap three tickets

**Where:** `tickets.yml:2802-2810` (`LDG-3110.scope` and acceptance),
`:2822-2830` (`LDG-3112.scope` and acceptance), `:2832-2840`
(`LDG-3113.scope` and acceptance), and `:857-877` (Workstreams 60-62).

**Concrete failure:** LDG-3110 says schedule identity enters sweep and
walk-forward identity and owns trusted recovery; LDG-3113 again owns sweep,
walk-forward, promotion and parallel identity; LDG-3112 again owns trusted
`ledgr_run_strategy()` recovery. The Workstream 60 review also claims worker
serialization even though parallel workers are Workstream 62. An implementation
can satisfy either ticket's local detector while leaving the other ticket to
change the same payload later, so D11, Section 5 recovery/worker evidence and
the contract amendments do not have exactly one owner.

**Minimal patch text:** partition the fields explicitly:

- LDG-3110 owns attribute stripping, config/run/live-candidate identity, both
  execution-spec calls and in-memory config reconstruction only. Remove saved
  sweep, walk-forward, public durable recovery and worker serialization from
  its scope/review.
- LDG-3112 owns experiment-store `run_provenance`, `run_telemetry`,
  `ledgr_run_strategy()` and run reopen/reconstruct/resume, plus only the
  execution, current-store and result contract groups it implements.
- LDG-3113 owns saved/reopened sweep, reproduction key, walk-forward,
  promotion and parallel-worker payloads/readers, their current-only versions,
  and the matching orchestration contract clauses.
- LDG-3114 owns only documentation contracts and the integrated cross-owner
  detector/clock; it does not become a second product owner.

### F4 - Medium - The resolved provenance field names contradict each other

**Where:** `tickets.yml:329` (Cut 21 decision 7), `:2829-2830`
(`LDG-3112.scope` and acceptance), and `:2839` (`LDG-3113.scope`).

**Concrete failure:** decision 7 says every identity or provenance payload
uses `strategy_schedule`, but LDG-3112 requires the physical
`run_provenance.schedule_json` field and its acceptance repeats that name.
Both are plausible conventions: config/payload keys use semantic names, while
the current `run_provenance` table uses `_json` columns such as
`strategy_params_json`. The draft does not say that this is an intentional
layer distinction. An implementer can therefore pick either name and still
claim conformance, while readers and the golden catalogue expect the other.

**Minimal patch text:** amend decision 7 to say: "Canonical config and nested
identity/provenance payloads use `strategy_schedule`; the physical
`run_provenance` column is `schedule_json`; all layers use `schedule_hash`."
Add a registered round-trip detector that fails if either payload key or the
physical column is renamed or crossed. If one name was intended everywhere,
change LDG-3112 instead; do not leave both readings operative.

### F5 - Medium - Fixed diagnostic, display and condition choices are not failure-sensitive

**Where:** `tickets.yml:329` (Cut 21 decisions 5-6), `:2799-2810`
(`LDG-3109/3110` acceptance), `:2819-2820` (`LDG-3111` acceptance), and
`:2829-2830` (`LDG-3112` acceptance).

**Concrete failure:** the scopes name the six diagnostic literals and the
display strings, but acceptance can pass with any pulse-level
`scheduled_skip` row and any visible schedule wording. The six child condition
classes are listed without a failure-to-class mapping. A patch could emit
`instrument_id = NA`, `stage = "strategy"`, a non-empty detail payload, or
different print labels and still satisfy the current broad detectors. Likewise
duplicate sessions could be reported as a parameter error without failing an
acceptance item.

**Minimal patch text:** add these literal acceptance checks:

- LDG-3111: exactly one skip row has `instrument_id = ""`,
  `stage = "decision"`, `outcome = "skipped"`, `reason_code =
  "scheduled_skip"`, `reasons = "scheduled_skip"` and `detail_json = "{}"`;
  mutate each field independently.
- LDG-3112: scheduled experiment/run displays use exactly
  `Strategy schedule: <label>` and run print/summary additionally use exactly
  `Decision pulses: <n>; scheduled skips: <n>`; unscheduled output retains its
  pinned compact bytes.
- LDG-3109/3111: missing sessions map to
  `ledgr_schedule_sessions_required`; duplicate/misaligned axes to
  `ledgr_schedule_axis_invalid`; multiple pulses per session to
  `ledgr_schedule_intraday_unsupported`; out-of-range dates to
  `ledgr_schedule_date_out_of_range`; unresolved parameter forms to
  `ledgr_schedule_param_unresolved`; and the flat zero-decision refusal to
  `ledgr_schedule_no_decision`, all inheriting
  `ledgr_invalid_strategy_schedule`. General malformed declarations may use
  the parent, but the ticket must say so.

### F6 - Medium - Workstream 62 contains three independently reviewable claims

**Where:** `tickets.yml:332-334` (`cuts[21].workstreams` and closeout),
`:871-877` (Workstream 62), and `:2832-2850` (LDG-3113/3114); matching routes
in `macro_plan.md:414-417,772-774`, `decisions.md:28`, and
`rfc/README.md:62-65`.

**Concrete failure:** Workstream 62's recorded "one claim" combines five
current-only orchestration formats, public documentation freshness and a
host-timed performance gate. LDG-3113 can be wrong while all article and H1
checks pass, or the formats can be correct while the timing input is invalid.
Waiting until after documentation and timing also delays review of identity
formats until dependent work has made reversal harder, contrary to the normal
review point rule.

**Minimal patch text:** keep Workstream 62 for LDG-3113 alone, with its existing
cross-entry identity/current-format review. Move LDG-3114 to new serial
Workstream 63, dependent on accepted Workstream 62, with one claim: the
accepted public teaching and integrated detector/H1 evidence accurately prove
the already-reviewed scheduler. Update Cut 21's workstream list, closeout and
the three routing references from Workstreams 60-62 to 60-63. This adds no
ticket or product mechanism; it adds the one review point needed before the
format result is consumed.

## Should-fix

1. **Low - name atomic version ownership in LDG-3113.** Its five fixed format
   bumps belong to one payload-propagation ticket, but the scope does not say
   that each payload field and its version gate land together. Add: "For each
   format, the schedule fields, writer, reader, old-version refusal and version
   constant are one atomic change; no mergeable commit writes schedule fields
   under the old value or bumps a value before its fields/readers exist."

2. **Low - make `NULL` versus absent ownership explicit.** LDG-3109 says a
   `NULL` schedule means all decisions, while LDG-3110 correctly says an
   unscheduled config omits the field rather than hashing explicit null. Say
   once that `NULL` is the private compiler input for an absent public/config
   declaration, not a canonical declaration value. This prevents a future
   payload from serializing `strategy_schedule: null`.

## Nits

None.

## Obligation and detector reconciliation

After F1-F6, every accepted item has one owner:

- D1-D5 and calendar/declaration refusals: LDG-3109, with extraction and the
  two construction sites in LDG-3110.
- D6-D9 and the exact skip/hold/state/zero-decision behavior: atomic
  LDG-3111/3112, with LDG-3112 owning the current run record.
- D10: LDG-3109 for resolution; LDG-3113 for orchestration propagation.
- D11: LDG-3110 for inner/config/live identity, LDG-3112 for durable run
  provenance/recovery, and LDG-3113 for the disjoint orchestration formats.
- D12: LDG-3109 derives counts, LDG-3112 persists/displays them, and LDG-3113
  forbids sweep-summary columns.
- D13: the cut's out-of-scope list preserves the invocation-time-only boundary;
  LDG-3114 teaches it without adding delayed release or event stepping.
- Section 4's schema-124 change is atomic in Workstream 61; the saved-sweep,
  sweep-provenance/reproduction, walk-forward and promotion bumps belong only
  to LDG-3113; documentation belongs to LDG-3114.
- Section 5's dense, availability, run, sweep, window, walk-forward,
  promotion, resume, parallel, boundary, explicit-date, parameter,
  zero-decision, P1/P4/P5, P2/P3, state, recovery, old-version, identity and
  unscheduled-byte regressions are all named by LDG-3109 through LDG-3114.
  F2 and F5 make the remaining shared-boundary and literal detectors capable of
  failing.
- Every Section 7 choice is resolved. F4 only removes an internal naming
  contradiction; it does not reopen the choice. The public names include
  `ledgr_schedule_from_param()` and exactly the five scalar tokens. Week-end,
  quarter-end, explicit-date parameters and sweep count columns remain absent.

LFB-035 remains separate in the cut opening, decisions, out-of-scope list,
LDG-3110, LDG-3113, macro plan and RFC redirect. No future obligation is
absorbed.

## Independently checked and clean

- The accepted RFC cycle is internally closed: final review
  `PASS_AFTER_PATCHES`, focused re-review `PASS`, and maintainer acceptance on
  2026-10-26. D1 and D2 match the accepted maintainer decisions.
- Current code confirms exactly two production `ledgr_execution_spec()` calls,
  and `ledgr_strategy_spec()`, source capture, registry/preflight, schema 123,
  saved-sweep 5, sweep/reproduction v1, walk-forward v1 and promotion v2 are
  the cited current owners.
- The compiler/decorator public names, class, attribute, config/spec names,
  parameter tokens, no-sweep-count decision and exact fixed format bumps match
  the Cut 21 decisions, subject only to F4's layer clarification.
- The cut allocates all Section 4 documentation: the four executable articles,
  reproducibility and store articles, help/roxygen, reference index, rendered
  Markdown and NEWS. Explicit hold teaching is preserved.
- The scheduler pipeline obligation was removed from the live table, while its
  old `#strategy-scheduler` anchor remains as a redirect. `decisions.md` points
  to Cut 21 and the macro plan names Cut 21. The roadmap, horizon,
  `horizon_open_classification.md` and `dev/spikes/asset_availability_pit/`
  changes are unrelated dirty work and were not edited by this review.
- `tickets.yml` parses: 192 unique ticket IDs, 62 unique workstream IDs and 21
  unique cut IDs. All dependencies resolve, the dependency graph is acyclic,
  all ticket workstreams exist, Cut 21 has six pending tickets, and its stated
  chain matches the YAML. Status tokens are valid.
- `git diff --check` reports no whitespace error. The line-ending notices are
  warnings on pre-existing modified files, not diff failures.

## Governance record

This is one independent cut-review invocation under M1. It is not a ratio gate;
Cut 21 records the numerator and completed-ticket denominator once at close.
It found six Type 1/Type 2 cut findings that change specification ownership,
grain or evidence, with no maintainer decision turn yet. Under M2 this file is
the single packet home for the findings. After patching, `cuts[21].cut_review`
must record the verdict, link this file and summarize the corrections; a
focused re-review is a separate invocation. No ticket, workstream or review
field should duplicate the M1 ratio.
