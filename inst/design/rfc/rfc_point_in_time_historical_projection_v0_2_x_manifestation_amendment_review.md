# Type 2 Review: Ordinary History Manifestation Amendment

**Mode:** Type 2 design review  
**Date:** 2026-10-24  
**Artifact reviewed:**
`rfc_point_in_time_historical_projection_v0_2_x_manifestation_amendment.md`  
**Verdict:** **REVISE**

## Necessity judgment

The correction is necessary, and the amendment has the right small center:
ordinary matrix and wide-frame reads should be sibling manifestations from the
prepared causal substrate, should not rebuild cell-aligned evidence, and should
not seal a transient numeric value. The GREEN spike supports that center for
the bar fixture it ran.

The draft is not yet safe to accept. It makes one integrity promise that cannot
hold without the hash it removes, its supposedly complete compact metadata
omits shipped disclosure and the time axis needed by its own checks, and its
counting and resource gates do not yet select a failure-sensitive,
least-machinery boundary. These are focused corrections; they do not require a
different history architecture.

## Findings

### F1 - High: the no-hash result cannot also promise that ordinary transformations lose identity

**Draft sections:** 2 (especially paragraphs 3-5), 4, 7 mutation detector,
and 8's Section 3 supersession.

**Failure or ambiguity.** The draft correctly says that ledgr does not
authenticate an ephemeral object after caller mutation, but then says ordinary
arithmetic, replacement and subsetting continue to drop ledgr identity and
limits the excluded case to manually restoring or forging attributes. That is
not the actual boundary. Base R operations can change values while preserving
custom class and attributes without manual forgery. With the value hash
removed, a structurally unchanged result can therefore still be accepted by
`ledgr_history_info()`, `ledgr_passed_warmup()` and
`ledgr_align_weights()` with metadata describing the original read.

**Evidence.** LDG-3099 expressly required refusal of an attribute-preserving
value transformation, and its evidence says the value seal was added for that
case. `tests/testthat/test-history-api-cleanup.R` lines 71-89 use `pmax()` as
that witness. `R/history-frame.R` currently computes and checks
`matrix_value_sha256` in `ledgr_history_matrix_result()` and
`ledgr_history_require_consistent()`. Once those checks are removed, the same
shape and dimnames pass. Wide frames are already more revealing:
`ledgr_history_require_consistent()` checks their names, row count and
timestamps but not their numeric columns, and there is no
`[<-.ledgr_history`, `[[<-.ledgr_history` or `$<-.ledgr_history` method;
ordinary column replacement can preserve the history attribute. The draft's
claim is therefore neither implementable by the proposed structural checks nor
true of both sibling forms.

**Minimal correction.** Keep the no-hash choice, but state the boundary
accurately:

- the result is isolated from the substrate and later reads;
- ledgr's registered S3 arithmetic, math, replacement and subsetting methods
  drop identity where they dispatch, but ledgr does not claim to intercept
  every attribute-preserving base or third-party transformation;
- metadata helpers validate class, shape, ordered axis, included IDs and
  request metadata only; they do not attest that current numeric cells equal
  the original read; and
- recorded admission, carry disclosure and readiness describe the originating
  read and are stale if a caller preserves the attributes while changing
  values.

Add a contract/test witness for an attribute-preserving transform so this
limitation cannot drift back into an "intact value" claim. Alternatively,
retaining authenticated transformed-result refusal requires retaining a value
hash or choosing another authenticated wrapper, which would reopen the design.

**Maintainer judgment required.** Confirm that provenance-only structural
identity, including the stated attribute-preservation limitation, is the
intended public contract. The draft must not silently present it as the old
transformed-result refusal.

### F2 - High: the exhaustive compact-metadata list is insufficient for shipped disclosure and for structural validation

**Draft sections:** 4, 5, 6 and 8.

**Failure or ambiguity.** Section 4 says an ordinary result records *only* the
listed metadata. That list omits two kinds of data that the amendment otherwise
requires:

1. It omits the ordered returned time axis. Start, cutoff, lookback and row
   count do not determine interior expected-session timestamps across venue
   holidays. Without an O(sessions) stored axis (or equivalent expected
   dimnames), a detached matrix cannot validate its dimnames as Section 2
   promises without reading the substrate again or trusting the dimnames it is
   meant to check.
2. It narrows the selection record to requested IDs, inclusion, finite count
   and one exclusion reason. The shipped selection table also discloses cutoff
   decision-axis/admissibility state and
   `required_input_count`, `carried_input_count` and
   `carried_input_share`. The causal-history teaching contract specifically
   requires carried-input-share disclosure and a consumer proof. Dropping
   those fields is a public disclosure change, not merely removal of aligned
   cell planes.

**Evidence.** The accepted synthesis Section 3 retains ordered time and
instrument identity; Section 5 binds count and share of carried required
inputs. `contracts.md`, Pulse Data And Axis-Aligned Accessors, records the
selection and cell-evidence fields separately and makes
`ledgr_history_info()` return the selection table. Strategy Context Teaching
requires `carried_input_share`. In the implementation,
`ledgr_history_require_consistent()` relies on `meta$axis`, while
`ledgr_history_selection_table()` constructs the decision-axis,
admissibility, required-input and carried-input fields. The spike's
`compact_meta()` retained `axis` but did not implement the full shipped
selection/disclosure record, so it is not evidence that the draft's shorter
list is sufficient.

**Minimal correction.** Make the compact boundary explicit as O(sessions) plus
O(requested/decision-axis instruments), not O(cells): retain the ordered
returned axis; exact requested and included ID order; and the current selection
table columns, including cutoff admissibility and required/carried input counts
and share. Remove only the session-by-instrument evidence matrices and duplicate
numeric payload. If any existing selection column is intentionally removed,
name that public break in the amendment and obtain a maintainer decision rather
than placing it under "selection and disclosure unchanged."

### F3 - High: the count/reason design prohibits the measured simple solution while leaving its replacement undefined

**Draft sections:** 4 paragraphs 4-5, 7 items 3 and 6 plus the dense-plane
mutation, 9 item 3, and 10.

**Failure or ambiguity.** The v2 spike did not produce counts from a production
representation; it received counts computed ahead of the timed candidate. The
draft nevertheless forbids a second completed-result scan, leaves either an
unspecified "memory-bounded summary" or a fused pass as the implementation
choice, and refers to an "explicit memory gate" that it never defines. Exact
exclusion reasons need more than finite counts: the shipped priority also
depends on structural and carry-expiry evidence. `used_before_window` similarly
needs carry source and feature dependency facts. A finite-count summary alone
does not satisfy the claimed compact result.

This is also contrary to the least-machinery gate. The retained spike inventory
reports the v1 bounded value scan at about 0.490 ms for matrix and 0.619 ms for
frame. Both are inside the amendment's later 0.75 ms implementation gate. The
draft would reject that straightforward semantic scan and may force a prepared
index or compiled fused copier before showing either is necessary.

**Evidence.** `charter_v2.md` says the candidate *receives* exact counts and
that the dense prefix plane is only a cost oracle. `spike_runner.R` lines
143-170 computes `finite_count` during untimed case preparation, and its
candidate merely reads that vector. `spike_inventory.md` and
`spike_closeout.md` both leave the production representation, compact reasons
and `used_before_window` open. Current
`ledgr_history_estimator_admission()` scans values, barrier reasons and missing
reasons to derive counts and the reason priority.

**Minimal correction.** Use the bounded requested-cell semantic scan as the
least-machinery baseline. Permit one scan of the requested treated slice to
derive finite counts, carried-input disclosure, exclusion-reason predicates and
`used_before_window`; continue to forbid a post-construction scan whose only
purpose is transient integrity. Prohibit a dense per-field prefix plane in this
correction cut. Introduce a prepared sparse/cumulative summary only if the
bounded scan misses a binding gate, with its retained bytes and cutoff-overlay
correctness measured before acceptance. Delete the undefined dense-plane
"memory gate" detector, or define an actual byte baseline and threshold.

**Maintainer judgment required.** Confirm whether "no second completed-result
scan" was intended to prohibit even the measured bounded semantic scan. If it
was, a bounded prototype of the chosen count/reason representation is required
before this amendment can bind it.

### F4 - Medium: diagnostic replay is not identified precisely enough to support the claimed reproducibility

**Draft sections:** 4 compact coordinates, 5, 7 final mutation, and 9 items 4
and 6.

**Failure or ambiguity.** "Same snapshot, policy, source, cutoff, lookback and
instrument selector" does not by itself recreate a run or walk-forward pulse
context. A selector such as `decision_axis` can depend on holdings and target
restrictions at that pulse. The public long reader requires a supported pulse
context, not just the listed coordinates. The narrower, implementable claim is
that the same experiment/owner context plus the recorded concrete requested IDs
can reproduce the returned cells and their cell evidence; the retained
selection table discloses the original cutoff admissibility. The draft does not
say whether it promises that cell replay or full result/selection replay.

**Evidence.** `contracts.md`, Pulse Data And Axis-Aligned Accessors, defines
history selection from `ctx$universe` and `ctx$vec$admissible`, and permits
explicit known IDs independently of current inadmissibility. Current
`ledgr_history_frame(..., layout = "long")` runs the same context plan; there
is no detached public reader taking only a snapshot hash and metadata. The
GREEN spike ran bar values only and did not run diagnostic replay.

**Minimal correction.** Define the replay recipe and parity domain: reacquire
the same supported experiment/owner context at the cutoff, request the recorded
resolved source and exact requested IDs explicitly with the recorded lookback
and requirements, and compare long values and cell evidence to the originating
ordinary read. State that original decision-axis/admissibility evidence comes
from the retained selection table unless the same execution context can be
reopened. Register this ordinary-to-long replay for run, sweep, walk-forward,
precompute and supported inspection, including feature vintage, late-known bar
overlay, input carry, output carry and barriers. If exact detached full-result
replay is intended, the draft needs another native context-reacquisition
decision; it should not imply one already exists.

### F5 - Medium: two resource gates are not failure-sensitive as written

**Draft section:** 7 items 4-5 and the full-snapshot mutation detector.

**Failure or ambiguity.** One regression slope fitted across four mixed-aspect
shapes can hide superlinear growth on one axis behind behavior on the other.
For example, a linear-cell cost plus a material quadratic-session term can have
a pooled exponent inside 0.65-1.30 while the 500-instrument session-axis
exponent exceeds 1.30. Also, the spike's 0.1 ms source-length result timed only
the raw slice, whereas the amendment words item 5 as a complete manifestation
latency gate. The stronger complete-read gate is useful, but it is not the gate
the spike ran, and latency alone is a weak detector of a small full-source scan.

**Evidence.** `spike_checker.R` fits one `lm(log(median_us) ~
log(returned_cells))` over all four shapes. `spike_runner.R` lines 340-359 times
`stored[rows, columns]` against a shortened matrix, not matrix/frame
construction, admission, metadata or overlays. `spike_closeout.md` accurately
calls the 0.037 ms result a raw-slice median.

**Minimal correction.** Keep the four shapes, but gate instrument-axis growth
at 252 sessions separately from returned-session growth at 500 instruments.
Run the fixed-window short-source/long-source comparison through the complete
ordinary reader. Add an exact touched-range or mocked-access detector for a
mutation that scans outside the requested columns; do not depend on a 0.1 ms
clock to prove that structural property. State that the 0.75 ms, zero-digest and
2.5-payload-copy gates apply to the completed result including the retained
compact metadata. The reference-host-only clock scope and CI structural split
can remain.

### F6 - Medium: supersession and executable Cut 19 routing do not yet name all public changes

**Draft sections:** 8 and 9.

**Failure or ambiguity.** The supersession map says only that content-integrity
"implications" become isolation and that eager cell evidence becomes compact
metadata. It does not explicitly supersede the shipped transformed-result
refusal/value seal, identify the exact retained selection fields, or distinguish
cell replay from original selection replay. Those are the consequential public
changes found above. In addition, Section 9 permits replacement tickets but
does not require Workstream 58's `tickets.yml` dependency to point at the new
correction owner. A prose block is not sequencing authority.

**Evidence.** Completed LDG-3099 records the value seal and transformed-object
refusal as accepted evidence. Completed LDG-3100 records count, carry,
readiness and `ledgr_history_info()` evidence. Open LDG-3104 currently depends
on LDG-3100, LDG-3101 and LDG-3103. `AGENTS.md` and `rfc_cycle.md` make
`tickets.yml` the sole within-cut sequencing authority.

**Minimal correction.** Expand the Section 8 rows to name the exact shipped
clauses being replaced and the exact compact fields retained. In Section 9,
require the new or reopened correction ticket to become an explicit dependency
of LDG-3104 before Workstream 58 starts. Preserve LDG-3099/3100 evidence as
historical, as the draft already requires.

## Accepted as written

- The correction is limited to transient manifestation and does not reopen
  causal cutoff, bar restatement, feature vintage, carry, barriers, admission
  or execution/economic semantics.
- A sealed verified snapshot plus its owner-validated prepared substrate is the
  correct generation trust boundary. The snapshot hash is provenance for the
  transient result, not a hash of that result.
- Context matrix and wide frame should be direct sibling manifestations with
  one read/selection owner; neither should be built through the other. The
  existing frame-to-matrix adapter remains a detached convenience only.
- No opposite-orientation prepared plane, full-result cache, prepared-frame
  collection, public trust bypass, durable evidence table or new diagnostic API
  is justified.
- Cell-aligned evidence belongs on the explicit long diagnostic request, not in
  every ordinary matrix or wide frame. Preserving the current long layout is
  the right least-machinery direction.
- Fresh-result mutation isolation, the accepted empty shapes, and parity across
  run, sweep, walk-forward, explicit precompute and supported inspection remain
  mandatory.
- The reference-host 0.75 ms median, zero-digest and 2.5-payload-copy gates are
  reasonable implementation stop signals and make no cross-host performance
  claim.
- Feature vintage, late-known overlays, input carry, output carry and barrier
  cases need independent witnesses; the bar-only GREEN spike does not prove
  them.
- No transient result hash should enter config, run, sweep, candidate,
  promotion or durable result identity, and no schema or stored-format change
  is authorized.

## Next review

A focused confirmation is sufficient after the textual patches if the
maintainer chooses provenance-only structural identity for F1 and permits the
bounded semantic scan baseline for F3. The confirmation should check the exact
compact field list, replay recipe, per-axis/resource detectors, supersession
rows and `tickets.yml` dependency rule.

Another Type 2 design round is needed if the maintainer instead requires
authenticated transformed-result refusal without a transient hash, chooses a
new prepared finite-count/reason index, or requires detached full diagnostic
replay without the owning context. Each would introduce architecture not
supported by the present spike.

## Focused confirmation

**Date:** 2026-10-24  
**Verdict:** **PASS_AFTER_PATCHES**

- **F1 resolved:** Section 2 now binds provenance-only structural validation,
  identifies attribute-preserving transformations, and states that recorded
  admission, carry and readiness can become stale after caller value changes.
- **F2 resolved:** Section 4 retains the ordered axis, exact ID order and all
  current selection-table disclosure, including finite, required-input and
  carried-input counts and share, while removing only cell-aligned planes.
- **F3 resolved:** Sections 4 and 9 choose one bounded semantic scan as the
  least-machinery baseline, forbid a dense prefix plane and prepared count
  index in this cut, and reserve a new summary for evidence-backed redesign.
- **F4 resolved:** Section 5 limits reproducibility to context-backed cell
  replay with exact requested IDs and retains original decision-axis and
  admissibility evidence in the compact selection table.
- **F5 resolved:** Section 7 separates instrument- and session-axis growth,
  upgrades fixed-window sensitivity to a complete-read gate, and adds an exact
  access detector for touching unrequested source columns.
- **F6 resolved:** Sections 8-9 name the transformed-result, selection and
  replay supersessions and require the correction ticket to become an explicit
  LDG-3104 dependency; the RFC pipeline row carries the same route.

The patches introduce no contradictory trust, causal, diagnostic, resource or
sequencing promise. A further Type 2 round is not needed.

## Cut-fidelity addendum

**Mode:** Focused Type 1 cut-fidelity review  
**Date:** 2026-10-24  
**Verdict:** **CHANGES_REQUIRED**

The Cut 19 amendment is faithful in architecture, public-behavior scope,
resource gates, provenance-only disclosure, bounded-scan baseline, LDG-3104
dependency and single-ticket landing shape. Two bounded record/detector patches
remain.

### C1 - LDG-3105 does not explicitly own two accepted mutation gates

The accepted amendment Section 7 requires registered detectors to fail when
frame and matrix diverge in either selection **or `used_before_window`**, and
when the diagnostic long view disagrees with ordinary values and compact
request coordinates. LDG-3105 acceptance item 4 names only divergent sibling
selection; item 5 requires replay agreement but does not require the accepted
mutation. A positive parity oracle is not the exact mutation-sensitive gate
that the accepted amendment binds.

**Minimal patch:** in LDG-3105 acceptance item 4, change `divergent sibling
selection fail` to `divergent sibling selection or used_before_window fail`.
In acceptance item 5, add that a mutation making long values or evidence
disagree with ordinary values or recorded request coordinates fails. No new
fixture or representation is authorized.

### C2 - the prior Workstream 55 review was summarized rather than retained as a historical record

The Cut 19 diff replaces the old Workstream 55 `review` mapping, including its
mode, point, verdict, artifact, detailed result and reason, with a short
`prior_review` string and a fresh empty `review` mapping. LDG-3099 and LDG-3100
themselves remain unchanged, but the prior workstream review does not remain as
the past field/record required by `rfc_cycle.md`; its detailed result and reason
are lost from `tickets.yml`. This conflicts with the cut's own `scope_change`
claim that the prior review remains historical evidence.

**Minimal patch:** retain the former Workstream 55 review verbatim under a
structured `prior_review` (or equivalently named historical-review field), with
all six original fields and values: mode, point, verdict, artifact, result and
reason. Keep the new empty `review` mapping solely for the amended Workstream 55
close. Do not alter LDG-3099/LDG-3100 scope, acceptance or evidence.

After these two textual patches, a focused confirmation is sufficient; no new
Type 2 round or implementation redesign is needed.
