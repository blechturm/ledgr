# Strategy context surface: response-stage probe

Date: 2026-09-26. Baseline: `39de0bfceab71266c61a6d4fe60f8b8f2069b962`.
Question: do the seed's observed redundancies and helper equivalences justify
its proposed surface? Outcome: partly; the feature and allocation conclusions
fail on small counterexamples. Full-run performance remains unverified.

## What ran

Native R 4.5.2, rlang 1.1.3, Linux. `probe.R` sources unmodified production
modules into an isolated environment; no ledgr function is stubbed. These are
source-level constructor/helper probes, not an installed-package test suite,
sealed-snapshot integration test, fold run, or performance comparison.
Synthetic availability planes exercise the target helper's input contract;
the availability resolver itself is not run. A projection uses an explicit
prototype engine-version label because no artifact identity is under test.

From repository root, with R and rlang available:

```sh
Rscript dev/spikes/strategy-context-surface/probe.R /tmp/context-probe
python dev/spikes/strategy-context-surface/check.py
```

Set `R_BIN` to the R executable for the checker if it is not on PATH.
`observations.csv` is generated output, not a pre-authored expected table.
The checker reruns into temporary directories, compares the recorded CSV and
checks that package/design scope did not change. Eight case groups are used.

## What changed the conclusion

- Dense constructor: 28 public members, 14 functions, eight `vec` members.
  The seed's WS16 branch and its new warning/tradable API were not available.
- Full positions equal `hold()`; a sparse accepted constructor input does not.
  The returned target can be edited without changing the positions snapshot.
- ID subscripting unnamed planes behaves exactly as the seed reports.
- No-alias `features(id)` errors. Configured aliases return named values,
  including warmup NA. A populated projection returns those values even when
  its public long table is empty; the bundle is not vestigial.
- A through D produce equal dense target quantities in the new fixture. This
  does not reproduce the author's six fills or final equity.
- Sparse selection produces complete targets. Full-axis allocation rejects a
  held nonmember; member allocation reserves its value. Manual D differs.
- A member with a usable risk mark can still lack a sizing close. Filtering
  it out produces a zero target, not preservation of its existing holding.
- Empty named `hold()` works; interactive construction with an empty universe,
  the target constructor, and the rebalance helper reject their empty cases.

## Gut demonstration and disposition

The `gut` argument removes only the nonmember reservation in an isolated copy
of the production helper. Member allocation changes from `AAA=6, OLD=2` to
`AAA=10, OLD=2`. The checker detects that numerical diff; repository functions
are not edited. Normal evidence reruns byte-for-byte.

Demoted: original timing, fill counts and universal census to unreproduced
claims tied to the unavailable branch. Rejected: empty table means unused
feature route; sparse intermediate means missing final target; full visible
axis means allocatable membership. Deleted: no production code or contracts.
The response proposes a narrower usability cut, not another execution engine.
