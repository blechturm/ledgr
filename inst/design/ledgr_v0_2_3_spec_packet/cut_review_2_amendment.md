# Cut 2 revision 3.2 amendment review

Role: independent focused Type 1 review record.
Status: `PASS_AFTER_PATCHES`; focused confirmation pending.
Authority: none. This review accepts no cut or implementation.

Reviewed by a clean-context Codex agent on 2026-10-30 against
`release/v0.2.3` at `145cc93b`. Scope was the revision 3.2 draft amendment in
`tickets.yml` and the packet README, checked against Cut 2, Cut 4's amendment
and LDG-3155, the benchmark manual, macro-plan rules 10-13, the shared timing
harness and `cut_review_2_fresh_harness.md`.

## Verdict

**PASS_AFTER_PATCHES.** The amendment is necessary and feasible. The accepted
five-process baseline remains descriptive: each process performs one cold
public run and one reset warm run, with no base/candidate ratio. A separate
narrow driver is necessary because `dev/bench/timing/measure.R` probes the host
and loads ledgr before invoking a protocol workload, so it cannot include
external process launch and package import in its measured clock. Later
same-engine gates are correctly routed to one proportional shared-harness
protocol in their receiving cuts. The descriptive record is correctly excluded
as a ratio arm, and no current authority is taken from the old
`codex/ws3-peer-oracle` branch.

## Required patches

### F1. Bind the live shared-host call outside both clocks

The draft named the shared files and a structural detector, but did not bind
the actual call chain or state that the PowerShell/CIM probe stays outside both
timed intervals. A dead shared-path call could coexist with a local parser, or
the host probe could contaminate the cold clock.

Patch the amendment and LDG-3136 to require the WS3 driver to load
`dev/bench/timing/host.R` by repository-relative path and call that file's
`timing_host_probe()` with `dev/bench/timing/` as `harness_dir`. That shared
function is the route to `host.ps1`. Host probing and verification of the
harness commit and actual `host.R`/`host.ps1` byte identities stay outside both
clocks. Acceptance must detect removal of the live call, redirection of either
file to a dense-local copy, and movement of the probe inside either clock.

### F2. Preserve the separate WS9 memory owner

The draft's broad statement that peak-memory evidence remains with the peer
suite conflicts with macro WS9. Narrow it everywhere: peer synthesis D8 owns
per-peer-row child-tree peaks; macro WS9 retains ledgr phase-level memory and
worker baselines, budgets and final memory evidence. The amendment changes
neither owner.

## Clean findings

- Shared host reuse is executable through
  `host.R::timing_host_probe(harness_dir)` and its call to `host.ps1`.
- The paired harness's two-arm plan, threshold checker and minimum eight pairs
  remain outside the descriptive baseline.
- Macro rules 10-13 and the receiving-cut protocol ownership are preserved.
- Cross-engine timing remains peer-suite work.
- The YAML parsed successfully; no product, schema or identity change is
  introduced.

After F1 and F2, the review found no hidden product decision, impossible
implementation, missing receiving-cut route or duplicated paired-gate
machinery.

## Focused confirmation

**PASS**, 2026-10-30, by the same independent clean-context reviewer. F1 now
binds the live repository-relative `host.R` load, its
`timing_host_probe()` call with the shared timing directory, the resulting
shared `host.ps1` execution, actual file identities and exclusion of all probe
and identity work from both clocks. The acceptance demonstrations fail for a
removed call, local `host.R`, local `host.ps1` or a probe moved inside either
clock. F2 now preserves peer synthesis D8 ownership of per-peer-row child-tree
peaks and macro WS9 ownership of ledgr phase-level memory, worker baselines,
budgets and final memory evidence everywhere reviewed. LDG-3137 routes later
same-engine gates to receiving-cut protocol folders and excludes this
descriptive baseline as a ratio arm. YAML parses; no patch remains.
