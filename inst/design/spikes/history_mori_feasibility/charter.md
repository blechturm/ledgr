# History worker shared-memory feasibility spike

**Status:** Closed RED. Evidence only; no product change.

## Question

On the vendor-neutral availability-active fixture and actual candidate-task
graph established by the E0 payload-attribution spike, can mori materially
reduce the measured two-worker memory burden relative to corrected staged
mirai without changing candidate results or identity, and should the derived
`bars_mat` and `static_bars_views` structures be shared or rebuilt?

The cheaper prerequisite is E0's GREEN result: staged mirai removes repeated
parent-side payload retention, but the two daemons still hold large copies.
This spike may test only that observed immutable task substrate.

## Fork

Compare corrected E0 arm C with two mori forms:

- D-share maps immutable large fields through mori, rebuilds only the cheap
  `pulses_iso`, and shares `bars_mat` and `static_bars_views`;
- D-rebuild maps their source substrate, then rebuilds `bars_mat`,
  `static_bars_views`, and `pulses_iso` once per daemon.

Both forms use the production task builder and worker evaluator. They are
harness-only. Wall time is observed, not ranked unless host control supports
it. No executor, API, dependency, contract, ticket, or decision changes.

## Evidence

A smoke run must precede one binding run at E0's record shape. Record base-R
XDR proxies; parent and recorded mirai-daemon working set and private commit;
shared-region and materialization facts; promise/result retention checkpoints;
result-transfer proxies; result/identity parity; exact reconstructed task
fields; and cleanup after success, forced process termination, and worker
failure. The dispatcher is not in the sampled population.

Windows working-set sums can double-count shared pages and private commit is
not PSS or unique RSS. Every sampled peak is a lower bound. mori's compact
serialization is a transport proxy, not measured mirai wire telemetry.

## Kill condition

Stop and return RED if mori cannot represent the observed immutable fields,
if exact tasks or candidate outputs cannot be reconstructed, if lifecycle
cleanup is unsafe, or if a product/API change is required. Return AMBER if the
memory signal cannot be separated from sampling or private materialization.
A slower or larger result is valid evidence and must not trigger more
machinery.

## Deliverables

- one public-path probe and findings note;
- runner with raw and derived CSV evidence;
- diff-based checker and one deliberate gutted path;
- one-page closeout separating proved facts from unknowns.
