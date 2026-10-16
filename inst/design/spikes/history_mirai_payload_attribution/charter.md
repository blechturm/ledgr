# History worker payload attribution spike

**Status:** Closed GREEN. No product change.

## Question

How much of the observed memory and transport cost of ledgr's current
two-worker sweep is attributable to sending candidate-invariant prepared
inputs with every task, and does staging those immutable inputs once per
persistent daemon reduce that cost without changing candidate results or
identity?

The cheaper prerequisite is already answered by the public-path probe in
`dev/spikes/history_mirai_payload_attribution/probe.R`: current sweep tasks
contain a large repeated invariant part. This spike measures that part before
the later mori spike chooses any representation.

## Fork

Use one availability-active, vendor-neutral synthetic experiment and the
production task builder and worker evaluator. Compare:

- A, sequential evaluation, as the result and resource reference;
- B, current mirai task dispatch; and
- C, the same mirai evaluator after staging the task's exact invariant fields
  once on each persistent daemon and sending only candidate-varying fields.

B and C are the two alternatives. A is the equivalence reference, not a third
executor proposal. All hooks are private to the harness. Nothing is added to
the package API, executor, tests or dependencies.

## Evidence

The runner records the task-field inventory, R object size and base-R XDR
serialization proxies; dispatch, collection and staging clocks; parent,
daemon and sampled process-tree working set and private committed bytes; and
parent-side task-list, promise-handle and collected-result-list object sizes.
Those object sizes do not measure promise retention or result-transfer bytes.
Working-set sums may double-count shared pages, and Windows private commit is
not PSS or unique RSS.

Candidate result rows and normalized reproduction-key hashes must be identical
in A, B and C. The checker reruns the smoke fixture, diffs deterministic CSVs,
checks the observed task inventory and guards repository scope. The gut demo
removes `runtime_projection` from C's staged payload and requires the exact
task-reconstruction assertion and result-identity check to fail.

The binding local record uses the larger `record` fixture only while no other
measurement agent is active. The small smoke record proves the harness, not a
performance ranking.

## Kill condition

Stop and recharter if the current task cannot be reconstructed exactly from
one invariant list plus one per-candidate list, if the staging seam requires a
product/API change, or if the sampler cannot distinguish the parent and mirai
daemon processes. A failure to reduce memory is a valid result, not a reason
to add machinery.

## Deliverables

- runner and raw/derived CSV evidence under the matching `dev/spikes` path;
- diff-based checker and one gutted-path demonstration;
- one-page closeout with an attributable payload map and the narrower question
  the mori spike may consume.

No representation, worker budget or public behavior is decided here.
