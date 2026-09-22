# Cut Reviews 3 And 4

**Reviewed commit:** `8747c64`.
**Modes:** Type 1 fidelity and detector review, then Type 2 workstream review.
**Reviewer/date:** Codex, 2026-09-22.

## Cut 3: Ingestion Consolidation

### Type 1

LDG-2786 is the intended owner for every test that currently calls the old
importers, and its acceptance requires both a detecting mutation for every
migrated block and a contract plus deletion reason for every deleted block.
LDG-2788 owns the one capability that must move to the kept file surface:
instrument metadata from a second CSV. That ownership model is sound, but its
input census and sequencing are not yet executable as written.

#### C3-F1 - The migration census is inaccurate

`rg` finds 27 importer calls in eight test files, not 26. The distribution is
9 in `test-acceptance-v0.1.1.R`, 9 in `test-snapshots-import-csv.R`, and 9
across the six other files. The latter are not all fixture builders:
`test-snapshots-seal.R:262-292` independently asserts the post-seal mutability
guard.

The two named contract files do not test all the cases LDG-2786 attributes to
them. They test required bars columns, rounding, the strict ISO-Z rejection,
OHLC bounds, BOM handling, auto-generation and its disabled branch, instrument
CSV success, and CREATED/SEALED mutability. They do not test duplicate bar
keys, arbitrary encoding, or extra-column tolerance. Those may be useful new
kept-surface cases, but they are not migrated witnesses.

Smallest correction: state 27 calls and list the observed cases accurately.
Name the strict no-Z rejection, `auto_generate_instruments = FALSE`, and the
CREATED/NOT_MUTABLE lifecycle as removed or changed contracts with explicit
reasons. Label any duplicate-key or extra-column case as newly added evidence,
not preserved evidence.

#### C3-F2 - The 2786 -> 2787 -> 2788 order cannot stay green honestly

LDG-2786 requires every test reference to both old importers to be gone.
Current `ledgr_snapshot_from_csv()` accepts only bars, `db_path`, and
`snapshot_id`; the `instruments_csv_path` kept-surface replacement does not
exist until LDG-2788. LDG-2787 then deletes the old instrument-file capability
before LDG-2788 restores it. Porting the test through an internal reader plus
`from_df()` would keep tests green but would not test the public file contract
that is being moved.

Smallest correction: implement LDG-2788 first, then migrate all tests in
LDG-2786, then delete the old surface in LDG-2787. Express that as dependencies
`2788 -> 2786 -> 2787`, and make closeout depend on 2787. Each commit can then
be green and no intermediate commit drops the capability.

#### C3-F3 - The timestamp witnesses have one shared-helper blind spot

The seven-branch matrix and one literal snapshot hash are complementary and
adequate for the local branch rewrite: the matrix sees normalized character
and POSIXct output that the persisted hash does not, while the hash sees the
persisted wiring on a real snapshot. They do not independently freeze the
fallback if the copied reference body and production both call
`ledgr_iso_utc()`. A one-line change to that shared helper can alter fallback
semantics while both sides remain identical and a normal ISO-Z hash fixture
stays unchanged. The current wording also asks an invalid/mixed case to assert
output identity even though it has no output.

Smallest correction: give the fallback case literal expected outputs or a
self-contained frozen parser, and require invalid and mixed inputs to preserve
their rejection class and message/order. The hash fixture need not multiply.

### Type 2

One workstream of six tickets is the honest grain after the dependency fix.
The product decision, test migration, removal, replacement capability,
timestamp optimization, and harness boundary change all converge on one
observable outcome: one tested CSV surface with an unchanged snapshot
identity. A separate review before deletion would duplicate the final review;
the corrected test-first dependency chain supplies the safer boundary.

### Cut 3 Verdict

**PASS_AFTER_PATCHES.** Apply C3-F1 through C3-F3 before opening Workstream 7.

## Cut 4: Sweep-Side Exact-Parity Optimizations

### Type 1

LDG-2794 and LDG-2798 already name explicit mutations. LDG-2795's old abort
inputs detect changed class, message, ordering, or result, although its design
has the separate scope defect below. Once bound to rejection, LDG-2797's
public constructor/run pair detects either comparator drifting. LDG-2792,
LDG-2793, and LDG-2796 name parity outputs but do not yet name the smallest
breaking changes requested by the workstream review.

#### C4-F1 - Three detector descriptions are incomplete

For LDG-2792, bind one minimal semantic mutation per subchange: bypass alias
normalization, alter one schema column type/order, and accept a third
`feature_table` value. For LDG-2793, add duplicate
`(instrument_id, feature_name)` rows with distinct values so the vector write
proves the current last-write result, in addition to NA and shape coverage.
For LDG-2796, require a cutoff-boundary mutation such as `<` in place of
`<=`, or skipping one forward advance, to fail the point-in-time witness.

These are detector specifications, not a demand for three new proof systems.

#### C4-F2 - LDG-2797 leaves a settled public contract open

The ticket permits either rejecting or accepting zero opening cash. The
accepted v0.1.6 contract requires `initial_cash <= 0` to fail, current config
validation enforces it at `config-validate.R:197-200`, and no supported
zero-cash opening appears in the tree. Allowing zero would widen the public
domain rather than merely align two validators.

Smallest correction: bind `ledgr_opening(cash = 0)` to reject with
`ledgr_invalid_opening`; keep run-side positive-cash validation unchanged.

#### C4-F3 - LDG-2795's proposed parameter set cannot preserve all six bodies

The five stated parameters cover the first five validators, but
`ledgr_return_panel_validate_matrix()` also requires non-empty unique candidate
IDs in matrix column names (`sweep-retention.R:641-650`). A generic validator
with only label, row/column minima, non-constant, and allow-missing flags cannot
reproduce that abort. If the ticket remains, add an explicit candidate-ID
rule (including its position in error ordering) and preserve condition fields
such as `n_candidates`, `n_observations`, and `candidate_ids`.

#### C4-F4 - The packet contradicts its own sequencing authority

Workstream 8 has `depends_on_workstream: 7`, while the README and review reason
say that the relation is staffing only and the maintainer may open it earlier.
The YAML says it is the sole sequencing authority, so the workstream cannot in
fact open earlier. Set the dependency to `null` or remove the independence
claim; the authorities contain no technical Cut-3 dependency.

LDG-2796's marks-only boundary is clean. Marks are computed in
`ledgr_availability_marks_at()` and feed only `priced`, `mark_source`, and
`mark_age`; positions are separately reconstructed by
`ledgr_availability_positions_asof()` and feed the provider view and `held`.
The full availability-result parity test is useful integration evidence, but
the mark-boundary mutation in C4-F1 keeps attribution independent of LDG-2779.

### Type 2

Eight tickets under the label "sweep-side" overstates the cohesion. LDG-2795
is unmeasured code-health consolidation with a broader error-contract surface;
it should move to a later maintenance cut. That also avoids designing its
missing candidate-ID mode under performance-cut time pressure.

LDG-2798 should stay in this release. The horizon explicitly scheduled the
zipline correction for the next implementation packet, the current article
misattributes a harness alignment defect to a peer, and its retention mutation
is self-contained. It is infrastructure rather than sweep code, so rename the
workstream to the honest broader outcome (for example, exact-parity and
workflow corrections) instead of pretending every ticket sits on the sweep
path. With LDG-2795 deferred, one close review over seven tickets remains a
tractable grain; LDG-2796 supplies the only large behavioral proof and the
other tickets are bounded exact-output or boundary corrections.

### Cut 4 Verdict

**PASS_AFTER_PATCHES.** Apply C4-F1 through C4-F4, defer LDG-2795, retain
LDG-2798, and update LDG-2799's dependencies and closeout denominator.

## Verification And Containment

I parsed the ticket YAML; traced the old importer calls and contract blocks;
read the current adapters, validators, availability reader, opening-cash
guards, and benchmark join; and checked the cited authorities. No tests or
benchmarks were run because this is a cut review. Only this review file was
created. The excluded spike directory and coverage artifacts were neither
read nor touched. Nothing was staged, committed, or pushed.

## Patch record

Applied by Claude in place, 2026-09-22, after verifying each finding
against the tree. C3-F1: 27 calls confirmed (26 bars plus one instruments
importer); the keyword scan of the two files confirmed no duplicate-key,
encoding or extra-column case; LDG-2786 lists the observed cases, names the
three removed or changed contracts with reasons, and labels new cases as
new evidence. C3-F2: dependencies are 2788, then 2786, then 2787; closeout
depends on 2787. C3-F3: the fallback case carries literal outputs; the
invalid branch asserts class, message and order. One clarification for the
record: `ledgr_iso_utc()` accepts the same three character forms as the
fast branches, so the fallback is reached only by a mixed-form column, and
the literal case is written that way.

C4-F1: mutations added to LDG-2792, LDG-2793 and LDG-2796 as specified.
C4-F2: LDG-2797 bound to rejection at construction, run-side check
unchanged. C4-F3: the candidate-id rule at `sweep-retention.R:641-650` is
recorded on LDG-2795. C4-F4: workstream 8 `depends_on_workstream: null`.
Type 2: LDG-2795 status `deferred`; LDG-2798 retained; workstream 8 and
cut 4 renamed "Exact-parity and workflow corrections"; LDG-2799 no longer
depends on LDG-2795 and names it as deferred; the README states two
reviews over seven tickets.
