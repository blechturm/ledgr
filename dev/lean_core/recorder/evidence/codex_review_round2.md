CHANGES_REQUIRED

Narrow round 2 of LDG-3212. All artifacts below are in review-out/round2/.
Used the specified Rscript and pinned installed library; no worktree edits.

1. Round-1 findings 2 and 3: original witnesses fixed; one write-check gap.
   probe.R repeats the relevant operations from review-out/probe.R:
   freeze 2,048 doubles, setv to 99, freeze again -> 99;
   mutate an earlier thaw to 77, thaw again -> original 1;
   the second capture remains 99. No stale capture or cross-thaw corruption.
   The real P1 control passes; changing its captured state:status to
   CORRUPTED now fails at $state:status. Full-output comparison is repaired.
   An injected P3 cash assignment fails, including when the captured output
   is changed to match: 'captured a write the table does not declare'.

   Remaining demonstrated gap: recorder/replay.R:93-102,142,156.
   byref-write-probe.R uses dense_cost record 9 (P3). In-memory only, it
   injects setv(..., vind1=TRUE) after P3 to change read-only positions[1]
   from 0 to 1, and changes the captured output to match. Replay says TRUE.
   The frozen input remains c(0,0), but read_only_in is taken from the
   executed thaw, now c(1,0), so the guard compares c(1,0) with c(1,0).
   A fresh input thaw detects the violation. Controls: the injected write
   fails against the original output, and the unchanged pinned function
   rejects the altered output. This is an injected negative witness,
   not evidence that unmodified pinned P3 performs that write.
   Compare read-only outputs against an independent thaw of rec$input.

2. Boundary filter: PASS on the requested comparison.
   run.R --workloads=dense_cost,failures produced full-captures/;
   run.R --workloads=dense_cost --boundaries=lot produced lot-captures/.
   Both invocations used explicit round2 capture/evidence/manifest paths.
   filter-probe.R compares every thawed input, output, condition, warning
   and handler-call list of the 20 lot records, in order, without clock
   exclusions. All 20 are identical(), with no comparator differences.
   Results: lot-comparison.csv. Full replay passes dense_cost 620/620 and
   failures 129/129; filtered lot replay passes 20/20.

3. Other demonstrated wrong expected value: recorder/capture.R:85,97-98.
   attribute-probe.R freezes a local strategy closure whose 2,048-double
   vector has an owner environment attribute, also held in a separate
   binding of the same closure. All environments are local, parent baseenv.
   The original closure changes attr(x,'owner')$value and returns
   owner$value -> 2. Its thawed copy performs the same operation -> 1.
   Large leaves serialize/unserialize separately without the shared
   environment hook, splitting the one owner into two independent copies.
   The 10-element control retains sharing and returns 2. Fresh thaws still
   contain the original 1: this is lost aliasing, not a live-global leak.
   A later family receives a strategy with different behavior from the
   captured strategy. Preserve attribute environments in the common node
   graph when splitting large atomic payloads. This is a small synthetic
   witness; no occurrence is claimed in the two registered workloads.
