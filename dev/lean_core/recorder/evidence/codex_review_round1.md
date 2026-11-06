CHANGES_REQUIRED

Type 1 review of LDG-3212 against HEAD 974b1adf20d54b0884b20ef9a00ebb7cd836db77
and the supplied untracked dev/lean_core/. No worktree file was edited.
Paths below are repository-relative unless explicitly identified as review outputs.
Authority: ticket acceptance 1-4; interface Sections 8, 9, 14, 17;
skeleton Section 5.3; pulse-plumbing R13; lean-fold amendments A1 and A4.
Preserved contract groups: contracts.md#contract-execution-fold-core and
contracts.md#contract-execution-fold-carrier.

Findings, most severe first

1. P1: Replay is not restricted to the declared inputs.
   dev/lean_core/recorder/replay.R:14-23,117,130;
   dev/lean_core/recorder/capture.R:119-137;
   dev/lean_core/recorder/compare.R:11-20.
   Verified: adding an otherwise inert global read to the in-memory P1
   reference still passes replay; it actually reads 42. An extra
   services['not_in_table'] read also passes, because only $ and [[ are
   guarded. These are injected negative witnesses, not claims that pinned
   P1 currently contains those reads. Separately, a captured closure whose
   parent is globalenv() reads a subsequently changed global: capture 1,
   mutate to 2, thaw, call => 2. R serialization preserves special environments
   by reference, bypassing the recorder's environment hook; comparison accepts
   the same special environment without examining its contents. Namespace
   state and attached environments have the same unclosed escape route
   (namespace-specific mutation witness unverified).
   Fix: close over captured data dependencies, restore them in an isolated
   replay environment/process, and distinguish pinned immutable code/constants
   from ambient mutable namespace/global state. Guard all supported field
   access forms, including [, and add witnesses through closure parents and
   aliases. A successful replay must not certify an unobserved extra read.

2. P1: Address caching can record stale values; thaws share writable leaves.
   dev/lean_core/recorder/capture.R:62-75,176-181,225-235.
   Verified with a double vector of length 2,048 under an environment binding:
   freeze; collapse::setv(x,1,99); freeze again => the second capture restores
   1, without refusal. The global every-25th-hit sample misses this reuse.
   Mutating one thaw to 77 also makes a later thaw of the original capture
   return 77, because store$thawed is shared between thaws. Thus replay can
   corrupt its own expected values or later records. The blobs themselves
   are serialized copies; the defect is reuse of stale keys and thawed buffers.
   Fix: cache by address only for proven immutable prepared leaves, never
   arbitrary reachable environment bindings. Serialize mutable bindings at
   each boundary; retain content deduplication. Scope thaw sharing to one
   reconstruction, or copy before any in-place write. Keep the per-binding
   store and large-leaf deduplication needed for fill-heavy captures. The
   small witness proves the mechanism; occurrence on the large workload is
   unverified and that workload was not run.

3. P1: Replay drops captured outputs instead of checking that they stayed equal.
   dev/lean_core/recorder/replay.R:138-150.
   Verified: changing state:status to 'CORRUPTED' in a real P1 output capture
   still passes. Actual contains only named state/mutable-service fields;
   expected is then restricted to names(actual). This cannot prove complete
   output equality or detect mutation through an alias to an undeclared slot.
   Fix: verify named outputs and independently prove every other captured
   slot/service unchanged from input, or refuse any undeclared write. Do not
   derive the expected output field set from the actual output field set.

4. P1: Manifest digests omit semantic inputs and over-normalize others.
   dev/lean_core/recorder/run.R:120-134;
   dev/lean_core/recorder/capture.R:98-108,166-172.
   Verified: replacing fold 1's frozen fixed-services run_id leaves every
   manifest row unchanged. lc_manifest never incorporates fold$fixed or the
   handler/writer shapes. Fixed inputs are therefore outside its advertised
   complete-input digest. Handler condition messages are also omitted at
   run.R:122-123 (unverified by mutation).
   Verified: user=list(created_at=1) and user=list(created_at=2) have equal
   canonical digests. created_at is removed everywhere, not just snapshot
   metadata. This can hide strategy state or result changes.
   Fix: incorporate the referenced fold inputs/shapes and complete handler
   conditions; scope normalization by semantic path. Snapshot creation time
   and opaque pointer addresses can reasonably be excluded from reproducibility
   digests, while retaining their captured values for comparison. Replacing
   every DBI object by its class is broader: connection configuration and
   database identity can affect reads. Preserve a stable descriptor of those
   inputs rather than assuming all slots are incidental. A DBI configuration
   change witness is unverified. No opaque C pointer can serve as a replayable
   snapshot authority; continue reopening through the sealed handle.

5. P2: The supplied manifests do not reproduce in this review environment.
   dev/lean_core/recorder/manifests/dense_cost.csv:2;
   manifests/failures.csv:2; manifests/history_fixture.csv:2 (same directory).
   Verified: all 41 boundary digests across these three manifests differ;
   counts and condition counts agree. For dense_cost E, supplied digest starts
   3b3bc2f9; regenerated digest starts fedf0915. Two independent fresh runs
   reproduce each other exactly for all three workloads, so this is not a
   claim of random drift between local regenerations. The cause of the
   supplied-versus-review difference is unverified; paths/toolchain/locale
   dependence must be diagnosed before replacing any baseline.
   Fix: establish and record the supported regeneration environment, explain
   the first semantic/canonical difference, then regenerate reviewed manifests
   after the recorder fixes. Do not broaden exclusions merely to match them.

6. P2: Installed-library origin checking accepts a sibling prefix.
   dev/lean_core/load.R:40-44; reused
   dev/bench/v0_2_3_ws16_entry/common.R:43-46.
   Verified: load a copied package from review-out/pin-other/ledgr, then ask
   lean_core_load(review-out/pin), where pin contains only the accepted marker.
   It succeeds although the requested library contains no ledgr package.
   Changing that marker to 'wrong' does refuse: the marker check is real,
   but the marker is not reliably tied to the loaded package.
   Fix in load.R: require normalized namespace path to equal
   file.path(lib,'ledgr'), with appropriate Windows path normalization;
   check the actual namespace origin after loading as well as before it.
   Source-archive equality is already exact; wrong-source-marker execution
   was not probed. A marker is a provenance assertion, not content verification.

7. P2: Comparison discards values merely because their names resemble clocks.
   dev/lean_core/recorder/compare.R:24-25,55-56.
   Verified: list(user=list(t_fill=1)) compares equal to the version with 2.
   The table allows particular clock fields; it does not authorize dropping
   arbitrary user state with the same spelling. Fix: use path/owner-aware
   clock exclusions, retaining counters and user values. Closure srcref
   normalization is discussed under the design concern below.

8. P2: The checker can accept replay that requires unaccepted table additions.
   dev/lean_core/recorder/check.R:47-51; run.R:151-155.
   Static, unverified by running the full checker: its failure gate uses
   passed_with_findings instead of passed. An open findings.csv row can
   turn a table-field failure into its accepted success criterion if recorded
   evidence is updated to match. Fix: gate on passed == calls; retain findings
   as explanations, never as extra execution permissions. Also check Git
   subprocess exit status at check.R:60-62: inability to inspect scope must
   fail explicitly. This session initially encountered Git's unsafe-repository
   refusal; scope was subsequently inspected using a review-local config.

Acceptance and execution evidence

- A1: small positive replay passes: dense_cost 620/620, failures 129/129,
  history_fixture 180/180, twice. The isolation/output witnesses above fail
  the claimed completeness proof. Remaining eight registered workloads,
  including both prohibited large workloads, are unverified by this review.
- A2: independent small reruns agree with each other, but fail the supplied
  manifest diff. Digests also have the coverage defects in finding 4.
- A3: omissions.R ran successfully; its entire CSV matches the supplied CSV.
  Both controls pass. Cash omission: 72/72 fail with lc_unnamed_field;
  by-reference valuation cursor: 63/72 with nondecreasing-pulse refusal;
  ignored calls: 189/189 with lc_replay_divergence; return-only capture:
  72/72 with missing state names; one ULP: 1/1 at state:cash; swapped rows:
  1/1 at calls[[1]]$args$i; condition reclassification: 1/1 at cond$class.
  These are the stated mechanisms, not unrelated baseline failures. The
  return-only witness deletes captured state; it demonstrates that omission,
  but does not test a comparator changed to ignore state entirely.
- A4: physical lines are capture.R 429 + compare.R 96 + replay.R 170 = 695;
  fields.R adds 94. The brief authorizes trim first, then recording the cap;
  the current implementation has not completed that trim.
- Runner/checker/gut exist and evidence comes from execution, satisfying the
  runnable shape of spike_protocol.md Sections 3/6/7. The order of initial
  implementation, witness discovery, and baseline freezing is unverified;
  these files are untracked, so reviewer-named freeze commits do not yet exist.
- history_fixture's child process executed. Its overrides change fixture
  inputs (database path and snapshot_id), while still calling the pinned
  public snapshot constructor and its sealing path. The exercised helper
  uses tempfile for that database. No stage/history function is replaced by
  those overrides. Unwrapped-versus-wrapped fixture equivalence is unverified;
  the passing feature-engine-version assertion checks the separate namespace
  wrapper's fingerprint effect, not arbitrary wrapper transparency.
- Package content scope passes: normalized git diff against HEAD is empty
  for R/, src/, tests/, NAMESPACE, DESCRIPTION, man/, inst/design; rg finds no
  dev/lean_core reference in the forbidden product paths. Git status lists
  R/cpp11.R and src/cpp11.cpp as modified, but normalized content diff is empty.
  dev/ remains excluded by .Rbuildignore. Full check.R was deliberately not run.

Concrete trim proposal (not applied; replacement implementations unverified)

Counts below use current physical lines, disjoint ranges, and no movement of
code into an uncounted helper file. Preserve every boundary, seven omissions,
promise guard, handler ordering/refusal capture, and the content-addressed store.
These cuts preserve the existing checks; findings above still require fixes.

| File and current lines | Replacement | Saved |
| --- | --- | ---: |
| capture.R:1-19 | Four comment lines: authority, binding store, immutable-only address cache, ordered handler tape | 15 |
| capture.R:37-39,41-42,60-61,94-97,112-113,131-132,154-155,198,206-207,215-216,223-224,246-247,277-278,287-288,306,337,366-368,378-379,404-405 | Respectively 1,0,1,2,1,0,1,0,0,1,1,0,0,0,0,0,1,1,1 comment lines; keep non-obvious cache/promise/fingerprint rationale, delete repeated descriptions | 28 |
| capture.R:1-429, blank lines only | Delete all blank lines except 24,111,245,334; retain section separation | 21 |
| capture.R:45-52 | Four-line list2env(list(blob=...,seen=...,thawed=...,hits=0L), parent=emptyenv()) constructor, with three separately created child environments | 4 |
| capture.R:79-92,176-196 | One nine-line attribute-preserving list walker, a three-line split adapter, a nine-line join adapter retaining the leaf branches; return original scalar when the adapter has no replacement | 14 |
| compare.R:1-9,41-43 | Two-line contract comment plus one-line source-reference rationale | 9 |
| compare.R:76-79 | Delete the optional first-scalar-value formatting; retain identical() decision and path/type/length difference at 80 | 4 |
| compare.R:83-96 | Ten-line attribute helper: retain sorted attribute-name check and loop; call lc_compare directly for each attribute, including names; remove its redundant special names branch | 4 |
| replay.R:1-8,25-26,90,97,146-147,156 | Respectively 2,1,0,0,1,0 comment lines; link the authority instead of repeating the algorithm | 11 |
| replay.R:1-170, blank lines only | Delete all blank lines except 13,24,51,82,96,155 | 6 |
| replay.R:43-50,105 | Delete the one-use lc_player helper; replace 105 by one list2env(list(calls=rec$calls,pos=0L,log=list(),store=store),parent=emptyenv()) expression | 8 |

Core total saved: 124; projected current-code total: 571
(capture 347 + comparison 79 + replay 145). Including fields.R: 665.
This is a concrete subtraction projection, not an implemented or newly accepted
cap. Apply the correctness repairs and trim, rerun, then record the actual cap
as the brief directs. Do not force 500 by removing capture coverage or storage.
Constructor/dispatch cuts remove scaffolding, not edge validation. Walker and
attribute-helper cuts share existing mechanics; they must preserve attributes,
types, empty/NULL positions and all omission outcomes when implemented.

Additional cuts outside that total:

| File and current lines | Replacement | Saved |
| --- | --- | ---: |
| recorder/run.R:136-143,151-156 | Delete the resolved finding's runtime field-expansion machinery; omissions.R:14 uses lc_table_fields() directly, a same-length replacement; keep findings.csv as historical evidence | 14 R |
| README.md:36-80,84-98,129-138 | Five lines linking boundary/freezing/comparison implementation and retaining fingerprint rationale; three lines explaining manifests and environment limits; two lines linking the resolved finding | 60 prose |

Design concern: NEEDS_TYPE_2

Interface Section 14's literal 'only' clock exception does not define closure
identity by source-stripped executable code. compare.R:44-49 makes that extra
choice. Comparing formals/body and closure data is sensible; excluding copied
srcfile/srcref bookkeeping may be justified for installed/source parity, but
that requires an explicit narrow representation rule. Route that decision to
Type 2 instead of silently enlarging the allowlist. Likewise, clarify clock
owners/paths and reproducibility-only normalization separately from semantic
comparison. No new execution semantics or frozen-test changes are authorized.

Reproduction artifacts in review-out: probe.R (negative witnesses),
pin-probe.R (origin refusal), diff-probe.R (manifest/omission diffs and counts),
graph-probe.R (reachable-binding inspection); small-* and repeat-* are the two
runner outputs; omission-* holds the seven-omission rerun. Use the Rscript
path and pinned library/source paths from brief.md. No large workload was run.
