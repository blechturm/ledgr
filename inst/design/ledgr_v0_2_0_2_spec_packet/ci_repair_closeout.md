# Workstream 21: Continuous-Integration Repair Closeout

**Status:** Agent-provisional; awaiting independent Type 1 close review.
**Cut:** 14. **Tickets:** LDG-2860, LDG-2861, LDG-2862, LDG-2865
and LDG-2863. **Baseline:** `d34c3b4`.

## Outcome

Continuous integration is green on its declared `ubuntu-latest`, R 4.6.1
runner and now reports the reason when it is not. GitHub Actions run
`36264300852` passed end to end at `cf7f64c`: its ordinary fast record
executed 457 of 457 blocks with no skip or failure, its independent gate
passed, and `R CMD check` passed.

No test moved profile, acquired an installed-context skip, or lost an
assertion to reach green. The workstream changes one production-side effect,
the registered timing evidence and bound, two test-control-plane reports, and
the source and vignette boundaries used by installed checks.

## Reproducible Diagnosis

The failures predate the v0.2.1.0 implementation workstreams:

- run `36234756357` executed commit `ae040e7`; and
- run `36226572400` executed commit `ede5bee`.

Both commits are ancestors of merge `704864d`, `Merge v0.2.1.0
implementation workstreams`, as verified with `git merge-base
--is-ancestor`.

The downloaded ordinary summaries show:

| Run | Clocks, seconds | Census per run |
| --- | --- | --- |
| 36234756357 | 92.792, 92.252, 92.558 | 453 expected, 453 executed, 0 skipped, 1 failed |
| 36226572400 | 113.942, 113.379, 113.279 | 454 expected, 454 executed, 0 skipped, 1 failed |

In both runs the only non-passing ordinary census row was
`test-demo-strategies.R::demo SMA crossover strategy is Tier 1::1`, with
status `warning`. The workflow log records the warning text exactly as
`no DISPLAY variable so Tk is not available`.

The test runner nevertheless printed `LEDGR_TEST_PROFILE_OK` and exited zero.
The checker then reported only that the summaries lacked a passing census,
without naming the warning or block. The green runner step and generic checker
message together hid a consistently red suite.

## Shipped Corrections

- `16b16ed` / LDG-2860 makes strategy preflight consult loaded namespaces
  first and stop at the first match. It no longer loads all priority packages
  merely to classify one symbol.
- `1a3cfb9` / LDG-2862 makes a recorded warning, error or failure produce a
  nonzero runner exit and gives each checker mismatch its own diagnostic and
  affected block or census. The correction after independent review also
  binds every checker failure to a nonzero exit without a false success line.
- `235848d` / LDG-2861 records the ordinary bound against its declared runner
  rather than a local Windows host.
- `cf7f64c` / LDG-2865 adds portable source discovery and vignette support.
  The correction after independent review makes discovery prefer the nearest
  staged `00_pkg_src` package over an enclosing checkout. It also makes the
  adapter vignette load the installed package and carry its vignette-local
  support file through R's documented `.install_extras` mechanism.

The first registered run after calibration, `36257746909`, passed 456 of 456
ordinary blocks in 101.464 seconds and passed the independent gate, then
failed `R CMD check`. That failure exposed the copied-test source-root defect
and the adapter-vignette execution defect owned by LDG-2865. They were not
hidden with skips: the final local source build rendered every vignette, the
tarball contained the adapter under both `vignettes` and `inst/doc`, and the
exact installed-package check returned `Status: OK` with all vignette code
replays passing.

## Bound Correction And Final Record

Calibration run `36256894206`, after LDG-2860, recorded 104.548, 102.755 and
103.129 seconds. Every run executed and passed all 456 selected blocks with
zero skips and zero failure statuses. The registered-runner median is 103.129
seconds. These repetitions came from one job, so their 1.793-second range
measures within-instance repeatability, not runner-to-runner variance. Later
registered jobs ranged from 101.464 to 107.113 seconds, a 5.649-second
between-job span.

The Workstream 19-era tree cited by LDG-2861 recorded a 92.558-second median
on the same runner, so the calibrated tree is 10.571 seconds slower. The
per-block census attributes about 3.29 seconds to new blocks and removes about
0.89 seconds with one retired block; common blocks add about 8.35 seconds
broadly rather than through one new hot block. That decomposition and the
unchanged-file variation support runner-instance variance, not a hidden
single-test regression. LDG-2848's rule remains controlling: an established
bound is not raised merely to make a regression green.

The corrected ordinary bound is 112 seconds. Its headroom is 8.871 seconds,
or 8.60 percent. That is tighter than the isolated CRAN bound's 19.700 seconds
over 85.300, or 23.09 percent. The Workstream 19 local clocks remain in
`tests/test-gates.yml` as non-gating history.

This is a correction of a bound that had never been measured on its declared
runner. It is not the prohibited practice of raising a previously calibrated
bound until a regression passes. No other threshold, timeout or membership
changed.

Final GitHub Actions run `36264300852` recorded 107.113 seconds, 457 expected
and executed blocks, zero skips, zero failures, and `gate_passed = TRUE`
against 112 seconds. Its remaining margin is 4.887 seconds, or 4.36 percent.
Confirmation runs two and three were correctly skipped under the one-run rule.
The same workflow completed `R CMD check` and ended successfully.

At reachable commit `cf7f64c`, package and test content is identical to the
amended local-build predecessor `f64cb0f`; only the LDG-2865 status and
evidence in `tickets.yml` differ. The exact local ordinary record retained at
`C:/tmp/ledgr-ws21-final-fast-f64cb0f` passed 457 of 457 in 84.900 seconds;
the independent checker returned `LEDGR_TEST_GATE_OK`.

## Failure Sensitivity

- LTB-0081 observed seventeen extra namespaces under the old eager preflight.
  Restoring eager evaluation fails the namespace-set and exact-call trace.
- LTB-0082 runs the real profile runner over an injected warning and the real
  checker over four separately malformed records. Removing either tool's
  fail-closed behavior fails its exit or false-success assertion as well as
  the relevant diagnostic assertion.
- LTB-0083 resolves a live ancestor checkout and chooses a scratch
  `ledgr.Rcheck/00_pkg_src/ledgr` tree even when it is nested inside a valid
  but conflicting checkout. Reversing that precedence fails the detector.
- LTB-0057 binds the installed package load, active-input fallback and
  vignette-extra rule. Restoring a package-root fallback or replacing the
  extra pattern fails the detector.
- The bound is empirical rather than a source-shape oracle: the three
  calibration records and final registered record are its detecting evidence.

## Antipattern Audit

The production defect was an eager package loop: `vapply()` evaluated every
priority candidate and loaded namespaces after an answer was already known.
The replacement short-circuits and leaves the priority set and verdicts
unchanged.

The remaining loops are bounded control-plane work. Source-root resolution
walks filesystem ancestors once; the gate checker reads one census; and the
vignette resolves one support path. None grows with bars, fact rows,
instruments by pulses, events, diagnostics or candidates. The work adds no
one-row frame append, repeated timestamp formatting, JSON encoding, or
per-pulse validation.

## Declined Alternatives

- Moving the warning block to review was rejected because package preflight is
  an ordinary-edit invariant and the warning exposed a real read-side effect.
- Treating warnings as passing was rejected because it would make the runner
  green by weakening the existing failure-status policy.
- Making the CI gate advisory was rejected because it would preserve the
  misleading signal rather than repair it.
- Skipping source-dependent blocks or vignette execution under R CMD check was
  rejected because installed checks must execute the same evidence, not a
  smaller substitute.

## Governance

The cut review is compressed into this close review. The first review plus its
focused correction round are two invocations over five completed tickets:
2/5 = 0.400 against the 0.5 gate. This draft is agent-provisional; only the
maintainer may accept and close Workstream 21 and Cut 14.
