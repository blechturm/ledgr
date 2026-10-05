# Gap census: how often does a US equity go without a price?

**2026-10-04 / Claude, for the maintainer.** Stage-1 evidence for terminal-outcome
seed v2. Binds no design.

**Question:** How often does a stock have no price for more than five NYSE
sessions, inside its history and before delisting, for the S&P 500 and for the
market at large?

**Data and method:**
- Private Sharadar lake, canonical build
  `canonical-20260906T055922734354Z-78941588416a97c6`: 45,350,378 split-adjusted
  daily bars, 20,961 instruments, 1994-08-11 to 2026-09-04.
- NYSE sessions from `qlcal` (`UnitedStates/NYSE`).
- Point-in-time S&P 500 intervals from the lake (1,180 instruments, 3.62 million
  member-sessions). The lake holds no other index membership; other groups use
  the vendor's category.
- Script: `gap_census.R`, read-only, aggregate output only.

## Finding 1: the vendor never leaves a price missing

Every instrument has exactly one bar for every NYSE session between its first
and last price: 45,350,379 instrument-sessions, 45,350,378 bars, zero missing
interior sessions. Sessions without a trade are filled. 2,216,401 bars (4.9%)
have zero volume; of these, 97.7% repeat the previous close and 98.6% are flat
(open = high = low = close).

So **"no price" in Sharadar appears as a run of zero-volume carried prices, not
as missing bars.** ledgr's staleness horizon, which reacts to missing bars,
never fires on this data. A halted stock keeps a vendor-carried mark, and a fill
at the next open would execute at a price nobody traded.

**Confirmed on ledgr (`carried_price_probe.R`, vendor-neutral).** In a
synthetic snapshot, AAA trades at 100, then shows six flat zero-volume sessions
carried at 100, then resumes at 1. A strategy that targets AAA to zero during
the carried stretch is filled at 100 on a zero-volume session, and the run
finishes `DONE` with no loss. ledgr reads every snapshot bar with
`gap_type = 'NONE'` and `is_synthetic = FALSE` (`R/snapshot-source.R:116`).
Valuation and fills never consult volume or those flags.

## Finding 2: halts longer than five sessions (zero-volume runs that later resume)

| Universe | Runs > 5 sessions | Instruments affected | Exposure |
| --- | ---: | ---: | --- |
| S&P 500, point in time | **3** | 3 | ~14,400 member-years |
| All instruments | 57,643 | 4,448 of 20,961 | ~180,000 instrument-years |
| Domestic common stock | 50,116 | 3,768 | |
| ADRs | 5,820 | 517 | |
| Preferred | 916 | 90 | |
| Canadian | 791 | 73 | |

Market-wide run lengths: 6–10 sessions 39,665; 11–20 13,222; 21–60 4,214;
61–250 488; over 250, 54. The median is 8. Runs cluster in 1998–2003 and
2022–2023. They are dominated by thinly traded small names, where zero volume
mostly means "no trade", not a formal halt.

**All three S&P 500 cases are bank failures, and the carried price was badly
wrong:**

| Company | Carried price during the halt | First traded price after | Change |
| --- | ---: | ---: | ---: |
| Washington Mutual (2008-09-30 to 10-15, 12 sessions) | 0.16 | 0.10 | -37% |
| Signature Bank (2023-03-13 to 03-27, 11 sessions) | 70.00 | 0.13 | -99.8% |
| SVB Financial (2023-03-13 to 03-27, 11 sessions) | 106.04 | 0.40 | -99.6% |

## Finding 3: delisting dates line up with the last price

- 14,637 delisted instruments have a vendor delisting date; for 14,636 it falls
  on the last price date. A terminal fact dated at the delisting date therefore
  takes effect at the last bar, so the terminal trigger is not pre-empted by a
  staleness stop.
- 118 delisted instruments (0.8%) end with more than five zero-volume carried
  sessions before their last bar. None was an S&P 500 member at the time.
- Five instruments not flagged delisted stop trading before the dataset end.

**Who freezes before delisting (`frozen_terminal_reasons.R`, 2026-10-05).** 118
of 14,636 delisted instruments have more than five untraded sessions before
their last price. Grouped by vendor reason:

| Reason | Frozen | Share of the group | Median untraded sessions |
| --- | ---: | ---: | ---: |
| Bankruptcy or liquidation | 74 | 2.2% | 17.5 |
| Regulatory delisting | 15 | 1.7% | 91 |
| No reason action | 15 | 0.6% | 15 |
| Acquisition or merger | 10 | 0.13% | 9 |
| Voluntary delisting | 4 | 1.1% | 9 |

At least 76% are distress cases. The cases where `write_off` is too pessimistic
(acquisitions and voluntary delistings) are about 12% of this rare event. They
become separable by exact-label overrides once the adapter passes the reason
through. The maintainer accepted `frozen_terminal_position = "write_off"`
(research) and `"refuse"` (strict) on 2026-10-05.

## Finding 4: the terminal reason is lost in the adapter

The ledgr.sharadar adapter labels every lifetime terminal `"delisting"`. The
vendor's reason is available in the corporate actions:

| Reason | Delisted instruments |
| --- | ---: |
| Cash acquisition | 4,726 |
| Bankruptcy or liquidation | 3,209 |
| No reason action | 2,354 |
| Stock acquisition | 1,307 |
| Regulatory delisting | 824 |
| Voluntary delisting | 369 |

Per-reason overrides keyed on exact labels (response F3) can only distinguish
these if the adapter passes the reason through.

## What seed v2 may consume

- **For index-scale research, a long halt of a held name is rare:** three
  occurrences in about 28 years of S&P 500 history. When it happens, it is
  catastrophic, and a last-price sale would book a 99% fictional value. This
  supports the response's F1: never convert a halt into a sale.
- **For broad-market research, gaps of more than five sessions are common**
  (about one run per three instrument-years, in a fifth of all instruments), but
  they are mostly illiquidity rather than halts.
- **The more urgent problem is upstream.** Vendor-carried zero-volume prices
  hide halts from ledgr entirely. Whether the adapter should present them as
  missing, or as `is_synthetic`, is an adapter and data-contract question. It
  should be routed alongside this RFC, not inside it.

## Open

- Zero volume is not the same as a formal halt; the lake has no halt or status
  feed to separate them.
- Market-cap scale is not point in time and was not used.
- Price behavior during non-terminal runs was not measured beyond the three
  S&P 500 cases.
