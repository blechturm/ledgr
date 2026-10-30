Verdict: PASS_AFTER_PATCHES
Role: record; independent clean-context Type 1 close review of cut 2 workstream 3.
Status: review recorded 2026-10-30; awaiting maintainer acceptance.
Authority: review evidence against the accepted cut; this file grants no new implementation scope.

Reviewed `fed29c59..fe358783` on `codex/ws3-amendment-v0.2.3` (runner
`5002f8d8`, protocol freeze `f99e387d`, record `0d774481`, request
`fe358783`). Authority: cut 2 revision 3.2 with the 2026-10-30 amendment,
workstream 3's review claim and LDG-3136/3137 in [tickets.yml](tickets.yml).

The claim holds. The record at `records/20261030-current-tree/` is a complete,
reproducible descriptive baseline. It uses real public execution, and both
clocks include the required results. Every patch below is wording only. None
touches clocks, record bytes, timing code or the checker.

## Findings, ranked by severity

**F1 (required, record). The child clock's 10 ms quantum is not disclosed.**
Every child-side phase in `raw.csv` is a multiple of 0.01 s. That is
`proc.time()` elapsed on this Windows host. Only the parent-to-child startup
term has sub-millisecond digits. So each warm clock is a whole number of 10 ms
ticks: the small warm row is 0.45-0.47 s, a spread of two ticks. The record
README and LDG-3137 evidence print it as `0.470000`, which reads like
microsecond precision. timing_protocol.md:46 says only "R elapsed-clock
resolution". Patch: add one sentence to the protocol clock section and the
record README. For example: "On this host the child elapsed clock ticks in
10 ms. Warm clocks and all child phases are multiples of 0.01 s, so the
12 x 90 warm spread is not resolved." No re-measurement is needed. The
descriptive claim stands, and on the 500 x 1260 rows the quantum is below
0.05%.

**F2 (required, wording). The old peer driver is not marked legacy.**
LDG-3137 scope (tickets.yml:623-624) says: "mark it legacy during construction
without removing supported commands". The peer README still opens with "This
is the current ledgr peer benchmark" (README.md:3). The new section sits
beside it and does not mark `peer_benchmark.R` as legacy. Delayed retirement
is respected: commands, A0 and the release-gate obligation are untouched.
Patch: one header sentence saying `peer_benchmark.R` is the legacy peer
driver, still supported until the `WS3-legacy-peer-harness-retirement` gate,
and pointing to the fresh dense harness. Alternatively, the maintainer can
rule at acceptance that "during construction" means the later replacement
cut.

**F3 (required, trivial). The inventory calls the record accepted before
acceptance.** inventory.md:78 says "The accepted descriptive record is ...".
Patch: "The recorded descriptive record is ...". Or leave it and let
acceptance make it true. Either way, do not rewrite the line after the review.

Optional, not conditioning the verdict:
- Child-side probe placement is not detected. `timing_validate_source`
  (timing_check.R:138-156) checks that the three shared-probe lines are present
  in timing.R. It only checks probe position in the runner. A copy of the
  probe call pasted into `run_arm` would still pass the structural check.
  Moving the probe there instead of copying it breaks the host mode, so the
  run would fail anyway. The ticket's four demonstrations are met, and the
  runner-side check brackets the whole child lifetime.
- The `reuse`, `precomputed_features`, `required_outputs` and
  `configured_jit` columns, and the warm `residual_sec = 0`, are literals the
  worker writes unconditionally. Checking them is self-attestation. The real
  evidence is the code and the identical snapshot hash. The cold residual is
  also a computed plug, so the 1 µs check proves nonnegativity, not
  reconciliation. This is harmless but adds no information.
- The warm run writes into the same DuckDB store and open connection that
  hold the cold run's rows. This is consistent with "reuse the unchanged
  sealed snapshot" and with ledgr's one-store model, but the protocol does
  not say it.
- The large row's `warning_count = 54` is undocumented. The reviewer probe
  shows all 54 are `LEDGR_LAST_BAR_NO_FILL` (a target changed on the final
  bar), which is benign and matches the shape. The checker does not compare
  warning counts across arms; the record has 54 in all ten large arms.
- The installed package reports version `0.2.2`, the DESCRIPTION version on
  the release branch. Source identity is the commit, so this is only a reading
  hazard.
- `git diff --check` flags trailing whitespace. It is only in the captured
  `sessionInfo()` and stdout record bytes. Leave those bytes as they are.

## Reruns (reviewer, this host, HEAD `fe358783`, R 4.6.1)

- `timing_check.R --records=<record> --gut`: PASS. The summary reproduces the
  committed medians/min/max exactly. All eight corruptions fail for their
  intended reasons:
  - missing cell: `nrow(r) == 20L`
  - invalid host: `child_affinity == 65535`
  - censored attempt: `status == "complete"`
  - keyed quantity (`12x90/1/warm`, P01, 0 -> 1, clocks and equity
    unchanged): exact diff
  - shared call removed, host.R load repointed locally and harness_dir
    repointed locally: required live lines absent
  - probe inside the timer: runner position check
- `check.R --pkg=. --records=oracles/20261030-pre-ws4 --out=<fresh>`: PASS.
  All nine native arms are identical, A0 pointers resolve and scope is
  unchanged.
- `git diff 5002f8d8 HEAD -- R src DESCRIPTION NAMESPACE dev/bench/timing` is
  empty, so the measured product and shared host bytes match HEAD.
  `git diff f99e387d HEAD -- dev/bench/peer_benchmark/dense` touches only
  inventory.md, so the frozen timing source is the source that ran.
- Warning probe (scratch, `pkgload` on the identical tree, 500 x 1260 public
  run): 54 warnings, all `LEDGR_LAST_BAR_NO_FILL`.

## Claim checks

- **Timer boundaries.** Cold starts when the parent records UTC milliseconds
  just before `Process.Start` (run_timing.ps1:131-134). It adds child
  `proc.time` elapsed through `ledgr_state_reconstruct` (timing.R:95, 130).
  It includes startup, import, input read, snapshot creation and sealing,
  setup, run and results. Warm runs from just before the feature-map and
  experiment construction to the same endpoint. Validation SQL, record
  writing, `close(bt)`, disconnect and `gc()` all fall after `finish` or
  between arms.
- **Required results and public API.** Fills, equity and
  `ledgr_state_reconstruct` cash and keyed positions are materialized inside
  both clocks. Every call is exported: `ledgr_run`, `ledgr_results`,
  `ledgr_db_init`, `ledgr_state_reconstruct`, `ledgr_snapshot_from_df` and
  `ledgr_snapshot_info`. No private engine or output-handler call is made.
- **Reuse and JIT.** The feature map and experiment are rebuilt inside each
  arm. A grep of `R/` finds no snapshot- or feature-level cache. The
  process-level caches (canonical JSON, schema catalogue and validation,
  indicator catalogue, store fingerprint) are completed first-use work, as
  declared. JIT is 3, both configured and observed. Installation byte-compiles
  the package outside the clocks (installation.txt).
- **Installed source identity.** The runner installs the pinned archive into
  a fresh TEMP library. Each child asserts its namespace path
  (timing.R:36-37). The checker matches `installed_path` to the attempt
  library.
- **Shared host probe.** timing.R host mode sources
  `dev/bench/timing/host.R` and calls
  `timing_host_probe(harness_dir = <repo>/dev/bench/timing)`. All 21 probes run
  in separate processes outside both clocks. The record binds harness commit
  `f99e387d` and the host.R and host.ps1 blobs, and the checker re-derives
  them from git. No copied parser, host.ps1 or paired-gate runner/checker
  exists.
- **Economic controls.** Each worker asserts that its cold and warm controls
  are identical. The checker compares all 20 arms exactly with each shape's
  first cold arm, and the 12 x 90 controls with the frozen transition oracle.
- **Host and censoring.** Plan GUID and 0xFFFF affinity hold for every
  attempt. Shape order alternates. There are ten unique PIDs, no retry and
  no censored or failed row. The attempts take 276 s in total, within the
  5400 s window. CPU (0-16%) and foreign R processes are observations only.
  The foreign R list includes the probe's own Rscript and two long-running
  Rscript processes; that is shared-harness behavior, not WS3's.
- **Descriptive-versus-paired boundary.** The peer README, the manual
  (.qmd and .md agree), the record README and NEWS all say: not a ratio arm,
  later same-engine gates get their own folder under
  `dev/bench/timing/protocols/`, and the peer, memory and WS9 owners are
  unchanged. No speed, scaling or peer claim is made.
- **Identity impact.** Snapshot content, run configuration and store
  fingerprint are unaffected. No product, schema, dependency, API or example
  change.
- **Budgets and necessity.** 1,064 maintained dense lines (timing adds 545),
  below 1,500. The cut requires a baseline for C1, and this harness is the
  smallest that measures it: public calls, the shared probe by reference, and
  no manifest or registry. The checker is the heaviest piece. Its size follows
  from the ticket's enumerated detectors.

Count: one independent verdict for workstream 3 (PASS_AFTER_PATCHES), recorded, not gated.

## Focused confirmation (2026-10-30)

**PASS.** A fresh Claude Opus session reviewed correction range
`fe358783..2121eee3`. F1 is resolved by the matching 10 ms disclosure in the
protocol, record README and LDG-3137 evidence; the raw record and displayed
values are unchanged. F2 is resolved by labelling `peer_benchmark.R` the
legacy active driver whose commands remain supported until the named open
retirement gate. F3 is resolved by calling the baseline a recorded review
candidate rather than accepted.

Codex completed the reviewer's unavailable mechanical checks: `git diff
--check fe358783..2121eee3` passes; `tickets.yml` parses; product, shared timing
harness and dense timing code are byte-unchanged across the correction; and
the only changed file under the committed record is its README. No new finding.
