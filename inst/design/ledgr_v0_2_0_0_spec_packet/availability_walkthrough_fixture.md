# Availability Walkthrough Fixture Draft

Status: Implemented by the executed public workflow in
`vignettes/survivorship-bias.qmd`. This file remains the design-time input
shape, not an expected-output ledger or a separate test harness.

## Purpose

The future survivorship-bias article needs one small, redistributable example
that starts from vendor-shaped tables. The fixture is synthetic. Venue `DEMO`
is illustrative and describes no real exchange or redistributed vendor data.

## Sessions

Coverage is 2020-01-06 through 2020-01-17 in UTC. Every civil date appears.
Weekdays are open from 14:30:00 to 21:00:00; weekends are explicit closures.
The complete calendar is known at 2020-01-01T00:00:00Z.

| session | date | status | open UTC | close UTC |
| ---: | --- | --- | --- | --- |
| 1 | 2020-01-06 | open | 14:30:00 | 21:00:00 |
| 2 | 2020-01-07 | open | 14:30:00 | 21:00:00 |
| 3 | 2020-01-08 | open | 14:30:00 | 21:00:00 |
| 4 | 2020-01-09 | open | 14:30:00 | 21:00:00 |
| 5 | 2020-01-10 | open | 14:30:00 | 21:00:00 |
| - | 2020-01-11 | closed | NA | NA |
| - | 2020-01-12 | closed | NA | NA |
| 6 | 2020-01-13 | open | 14:30:00 | 21:00:00 |
| 7 | 2020-01-14 | open | 14:30:00 | 21:00:00 |
| 8 | 2020-01-15 | open | 14:30:00 | 21:00:00 |
| 9 | 2020-01-16 | open | 14:30:00 | 21:00:00 |
| 10 | 2020-01-17 | open | 14:30:00 | 21:00:00 |

## Membership

Membership uses dated complete snapshots for universe `demo_members`.
Knowledge time is 2020-01-01T00:00:00Z for both states.

| effective from | listed member | meaning of omission |
| --- | --- | --- |
| 2020-01-06T00:00:00Z | AAA | all other IDs are non-members |
| 2020-01-08T00:00:00Z | BBB | AAA is removed; all other IDs are non-members |

The instrument master contains stable IDs `AAA` and `BBB`. Removal never
liquidates AAA. A non-zero AAA holding therefore keeps AAA on the public axis
after the second membership state becomes knowable and effective.

## Observations

Bars use daily vendor date labels that the dataframe adapter must map to the
declared session closes. AAA has a bar for every open session except session 4,
2020-01-09. BBB starts on its entry date, 2020-01-08. Prices may be simple
deterministic integers; the teaching point is presence and absence, not return
performance.

Small validation variants derive from this same shape:

- remove one civil session row to demonstrate incomplete-calendar rejection;
- add an invalid AAA OHLC row to contrast strict rejection with acknowledged
  quarantine;
- provide an empty complete membership state through an explicit set header;
- add tied, conflicting status assertions from two sources;
- extend the AAA gap beyond the declared two-session valuation horizon.

## Strategy Story

The ordinary target-vector strategy first holds AAA. On decision 3 it requests
AAA quantity zero, but session 4 has no AAA execution observation, so the exit
cannot fill. On decision 4 it returns AAA's current quantity; the missing fill
does not become a standing exit. On decision 5 it explicitly returns zero
again, allowing execution at session 6 when evidence is present.

The connected article uses public constructors and accessors only:
ingest, validate, seal, run, explain the retained holding and both exit
attempts, close, reopen, and recover the same explanation. Runtime truth stays
in the package and its detecting tests; this file remains narrative input.
