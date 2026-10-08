# Proposal: WS3/WS4 History-Wave Decisions

**Status:** Executor proposal, 2026-10-08. Not accepted; under Type 2 review
([review](rfc_history_wave_v0_2_2_review.md)) and maintainer decision
([decision register](rfc_history_wave_v0_2_2_decisions.md)). Binds nothing.
**Author:** Claude, for the maintainer.
**Target:** [synthesis v11](rfc_point_in_time_historical_projection_v0_2_x_synthesis_v11.md)
Section 7 prerequisites (a) and (b), and the joint WS3/WS4 history-start
decision in the [v0.2.2 macro plan](../ledgr_v0_2_2_spec_packet/macro_plan.md).
**Evidence:** [two-clock history spike](../spikes/two_clock_history_spike/closeout.md)
and [recursive-indicator history spike](../spikes/recursive_indicator_history_spike/closeout.md),
including their Sharadar census and vintage diff.

## D1. History representation and size

Accept bitemporal segments as the WS3 point-in-time history representation:
built once before the fold from the existing resolution rules, with adjacent
equal-state runs merged, answering (s, t) by interval lookup. The diagonal
(s = t) must equal the shipped prepared provider (parity test).

Guard the measured worst case instead of measuring it further: the build counts
segments per instrument and refuses with a classed error above a budget
expressed as a multiple of fact rows (the number to be set with the WS3 memory
budget). Evidence: 2.61 segments/fact over all real S&P 500 histories; one real
day of Sharadar revisions showed no overlap-heavy restatement; the n*k shape
exists only in synthetic fixtures.

## D2. Supersession chains

Allow transitive supersession chains within one source: two facts linked through
a chain of supersession are exempt from the conflict check, matching the
resolver, which already drops every superseded fact. Cross-source supersession
stays refused. Replace the pairwise validator with a grouped sweep over chain
components (it is one of the seven named shapes). Pre-release, no
back-compatibility constraint.

## D3. Indicator history class is declared, not detected

Every indicator carries a history class: `bounded` (value depends only on a
fixed trailing window) or `history_dependent`. Built-in window indicators
(SMA, ledgr EMA, rolling) declare `bounded`; TTR adapters and custom indicators
default to `history_dependent` unless the author declares `bounded`.

A history-sensitivity check runs at experiment build as a refutation-only
detector: if an indicator declares `bounded` or `gap_contract = "strict_window"`
and the experiment's own data shows history dependence, refuse with a classed
error. It can refute a declaration; it never certifies one.

## D4. History-dependent indicators

Compute history-dependent indicators from the full available snapshot history
by default, so windowed runs, sweeps and walk-forward see what a dense run sees.
Bounded indicators hydrate from scoring start minus their `stable_after`. This
replaces Cut 9's temporary rule (features restart at every scoring start). A
user-declared finite burn-in is deferred. Decaying versus path-dependent is not
distinguished.

## D5. Correctable facts

Do not add fact corrections to WS3. The segment representation already treats a
correction as a later-known fact, so adding corrections later changes the fact
constructors, not the history representation. Until then:
- document that interval membership cannot express an end known later than its
  start, and that membership snapshot sets are the supported two-clock path;
- document that lifetime facts cannot be corrected (real case: a delisting moved
  five years earlier between two Sharadar downloads 16 hours apart);
- park lifetime and membership corrections as a facts-model ticket.
