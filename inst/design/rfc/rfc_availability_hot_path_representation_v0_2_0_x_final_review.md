# Final Review: Availability Hot-Path Representation Synthesis

**Role:** Codex, independent final reviewer. Claude wrote the synthesis; Codex
wrote Seed v2 and did not write the synthesis. **Date:** 2026-09-15.

**Under review:**
`rfc_availability_hot_path_representation_v0_2_0_x_synthesis.md`, initially
327 lines and 355 lines after the focused patch,
against branch `v0.2.0.1` at
`b0fe6b8fb8c44981ad9fc6f8692ce076be72e764` plus the reviewed uncommitted
spike seams and evidence.

## Verdict

**PASS_AFTER_PATCHES.** The synthesis correctly reconciles the three GREEN
spikes, separates cold sealing from warm research iteration, and routes
valuation without reopening it. The focused verification confirms that the
High, three Medium, and Low findings below are closed. No further review,
spike, timing run, or architecture round is required before the maintainer
decisions and acceptance.

The 327-line length is accepted: 300 was a prompt target, not a protocol
budget, and the document remains cohesive.

## Verification performed

- Recomputed every reported writer, provider, and block timing, median, range,
  spread, working-set bound, and lane share from the recorded CSVs. The
  synthesis's arithmetic is correct. `choose(30300, 2)` is 459,029,850.
- Ran the diagnostic-block checker against the current evidence after the
  disclosed background-run incident: all 54 checks passed. The six rewritten
  deterministic CSVs therefore still satisfy the reviewed exact-diff and
  semantic predicates; measurement CSVs were not regenerated.
- Checked every cited `R/...:line` anchor against the current worktree and
  traced the provider, diagnostic writer, seal validators, and finalization
  paths. All paths and line numbers resolve, but two cited interpretations need
  correction below.
- Confirmed ASCII, LF, final newline, sixteen required headings, no trailing
  whitespace, empty index, no running R process, and `git diff --check` clean.

## Findings

### High

**H1 - Section 10 permits a repair that preserves the data loss it is meant to
fix.** Lines 235-239 bind the correct invariant: a finalized run's equity curve
must contain every achieved pulse across all invocations. They then allow
either retaining and merging the prior prefix **or** validating only the
finalizing invocation's prefix.

The second branch would merely weaken the validator. Finalization currently
deletes the entire curve and appends only the last invocation's `eq_df`
(`R/run-finalize.R:422-424`); the validator correctly detects that loss by
requiring the full achieved calendar prefix (`R/run-finalize.R:97-113`).
Validating the tail alone would make the corrupted run reopen while its earlier
equity evidence remained absent, contradicting the bound invariant and the
accepted-prefix persistence contract.

**Required patch:** delete the validation-only alternative. Bind the repair to
preserving and deterministically merging the complete prior and new equity
prefix, with no missing or duplicate pulses, followed by successful reopen of
both `DONE` and `INCOMPLETE` resumed runs. Exact implementation remains
spec-cut work.

### Medium

**M1 - The public fact resolver is both incorrectly routed and deferred.**
Lines 111-115 say every provider consumer, including
`ledgr_facts_resolve()`, must use the prepared provider. Lines 222-225 then
defer how that same function consumes the prepared build.

`ledgr_facts_resolve()` is not a provider consumer. It resolves membership
directly through `ledgr_membership_resolve_at()` and sessions through
`ledgr_session_resolve_at()` (`R/availability-inspection.R:94-125`). Provider
Charter v2 lines 39-41 deliberately kept it unchanged as the independent
public membership reference; the provider harness compared its members with
the prepared arm. The `availability` result view does rebuild a provider and
is the read path that belongs on the prepared build.

**Required patch:** route actual provider-build consumers, including the
`availability` result/reopen path, through the productionized prepared build.
Keep `ledgr_facts_resolve()` as the independent public reference in this
packet. Remove it from both the bound route and the spec-cut question unless a
later separately evidenced change proves its complete public `rows`,
`evidence`, and metadata contract.

**M2 - Section 4 overstates the measured prepared representation.** Lines
98-103 describe membership and interval assertions as CSR segment tables with
monotone per-instrument cursors. The reviewed seam instead prepares membership
headers behind one eligibility cursor and retains membership interval
assertions as flat start/end/member/index vectors evaluated at each cutoff
(`R/availability-provider-prepared.R:23-93`). CSR segment tables and
per-instrument advancing/re-seeking cursors apply to status, lifetime, and
terminal-event planes (`R/availability-provider-prepared.R:99-163` and
`:165-323`).

This is not merely terminology: the synthesis would otherwise bind an
untested additional membership representation while claiming to adopt the
reviewed seam.

**Required patch:** describe the two prepared shapes separately and cite the
full implementation ranges. Preserve the general contract of primitive
prepared state and no per-pulse fact-frame scans without upgrading the flat
membership intervals to an unmeasured cursor design.

**M3 - The frame-boundary rule silently expands beyond the reviewed seams.**
Lines 108-109 say nothing anywhere inside the fold or compile step manifests a
frame. The reviewed evidence establishes that rule for the three selected
paths, not for all current fold work. Unchanged paths still construct internal
frames, including per-pulse strategy-state rows
(`R/backtest-runner.R:469-487`). Section 13 simultaneously rejects a
package-wide mechanical rewrite.

**Required patch:** scope "frames only at boundaries" to provider preparation
and diagnostic construction/writing in this packet. Retain Section 12's wider
rule as a profile-triggered engineering direction, not an implicit requirement
to remove every unrelated internal frame now.

### Low

**L1 - Three evidence-lineage sentences are inaccurate.** Lines 22-24 say each
spike had one Section 7 review and that no maintainer-decisions stage was
needed. The writer and provider evidence each required a first review and a
re-review; the block evidence passed in one round. Section 14 also has three
maintainer decisions still pending. Say that no separate decision artifact has
yet been created, not that the stage was unnecessary.

Lines 133-135 omit creation time from the persisted-table exclusions. Lines
213-214 cite PE as support for comparing `archived_at_utc`, but the provider
re-review explicitly records that PE excluded it; the later block evidence BE
is what compares it. State the exact three block exclusions and cite BE/BC.

## Verified without finding

- Cold and warm clocks are correctly separated. The 60-90 second seal estimate
  remains explicitly forecast, and the approximately 25-second fold is not
  presented as a peer benchmark.
- The seal-time sort-and-sweep direction preserves opposing-state, half-open,
  open-end, precedence, and supersession semantics and requires equivalence
  testing before replacement. Set-backed bypass remains gated on setwise
  validation.
- Collapse is treated as an implementation detail, not the architectural
  result. Public API, schema, hash, and run-identity changes are not invented.
- Valuation is the justified next measured lane and is correctly kept outside
  this packet. The style rule targets scale-growing work rather than loop
  syntax.

## Focused verification after the synthesis patch

- **H1 closed.** Section 10 now requires a deterministic merge of all prior
  and finalizing equity rows, forbids missing or duplicate pulses, requires
  successful reopen of resumed `DONE` and `INCOMPLETE` runs, and explicitly
  rejects weakening terminal validation.
- **M1 closed.** Section 4 routes only true provider-build consumers through
  the prepared build. It preserves `ledgr_facts_resolve()` as the direct,
  independent public reference and removes it from the spec-cut question.
- **M2 closed.** Membership headers and flat interval vectors are described
  separately from the CSR status/lifetime/terminal planes, with source ranges
  that resolve through the complete prepared implementation. No unmeasured
  membership cursor design is bound.
- **M3 closed.** The boundary-only frame rule is scoped to the optimized
  provider and diagnostic paths. Existing internal frames remain governed by
  the profile-triggered engineering rule.
- **L1 closed.** The cycle trail records the actual review rounds and pending
  maintainer decisions. Sections 5 and 9 name exactly the three block-parity
  exclusions and correctly distinguish PE's archived-field limitation from
  BC/BE's later comparison.

Focused checks: the synthesis is 355 lines, ASCII, LF-terminated, contains all
sixteen headings, and has no trailing whitespace. Every new source range
exists and supports its sentence. Searches found no residual validation-only
repair, false provider-consumer claim, global frame prohibition, or obsolete
review-stage wording. `git diff --check` is clean; the index remains empty.

## Decision and handoff

The synthesis is ready for the maintainer to resolve Section 14's three
decisions: release placement, sequencing against the reserved v0.2.0.1 crypto
probe, and confirmation that the seal workstream plus resumed-run correctness
prerequisite belong in the same packet. Acceptance may follow those decisions.
Only after acceptance should the RFC index, roadmap, horizon, style article,
and implementation packet advance.

AVAILABILITY_HOT_PATH_SYNTHESIS_FINAL_REVIEW_DISPOSITION: PASS_AFTER_PATCHES
