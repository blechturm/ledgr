# Missing Data and Session Calendars


Your price file has holes in it. An instrument was halted for a day, a
vendor dropped a session, a listing began halfway through your window, a
venue closed for a holiday your file knows nothing about. What should a
backtester do with a day on which one of your instruments has no price?

The tempting answer is to carry the previous close forward so that every
instrument has a row on every day. That answer quietly invents trades:
once a carried price is in the panel, nothing distinguishes it from a
real one, and your backtest will fill orders at prices no venue ever
printed.

ledgr takes the other path. It never manufactures a price. Instead it
asks you to say which sessions were supposed to exist, and then tells
you, session by session and instrument by instrument, what it knew and
what it did not.

By the end of this article you will have run a backtest over a panel
with a real three-session hole in it, seen why nothing filled during the
hole, and chosen the point at which an old price stops being good enough
to value a position you still hold.

## The Big Picture: Four Questions, Not One

“Missing” feels like one condition. In a backtest it is at least four,
and they have different economic consequences. ledgr keeps them apart,
and each one has its own home in the data you supply.

| The question | Answered by | Consequence when the answer is no |
|----|----|----|
| Was the venue open at all? | the session calendar | there is no pulse; nothing is expected of anyone |
| Did this instrument trade? | whether a bar row exists | the instrument is unpriced; its last mark starts ageing |
| Was it allowed to trade? | trading-status facts | you may hold or exit it, but not resize it |
| Was it listed at all? | lifetime facts | it is not on the decision axis |

The first two questions cannot be told apart from a price file alone. A
closed market and a vendor omission both look like “no row”. That is why
the session calendar comes first: it is the clock that says what
*should* have happened, independent of what your data happens to
contain.

A fifth case, a row that is present but wrong, is handled at the end.

> [!WARNING]
>
> ### Do not pad your panel before sealing it
>
> If you fill the holes with the previous close so that every instrument
> has a row on every session, ledgr accepts it. It cannot tell your
> invented rows from real ones, and it will execute against them. Supply
> the panel with its holes intact and declare a session calendar instead.
> The rest of this article is about what that buys you.


## Prerequisites

``` r
library(ledgr)
library(dplyr)
library(tibble)
library(qlcal)
```

## Step 1: Declare What Sessions Existed

The expected-session clock has to come from somewhere other than your
prices. If you derive sessions from the data you happen to have, a day
on which your whole universe is missing becomes invisible, and that is
exactly the day you most need to see.

`qlcal`, a suggested dependency, ships exchange calendars, and
`ledgr_facts_sessions_qlcal()` turns one into a ledgr fact family: a set
of assertions about a venue that become part of the snapshot’s identity.
The window below is two weeks of NYSE trading in January 2020.

``` r
window_start <- as.Date("2020-01-13")
window_end <- as.Date("2020-01-24")

sessions <- ledgr_facts_sessions_qlcal(
  calendar = getCalendar("UnitedStates/NYSE"),
  from = window_start,
  to = window_end,
  venue_id = "XNYS",
  timezone = "America/New_York",
  session_open = "09:30:00",
  session_close = "16:00:00"
)
```

Read any fact family back with `ledgr_facts_history()`. Here the
`status` column is the lesson, not the row count.

``` r
session_rows <- ledgr_facts_history(
  ledgr_facts(sessions),
  family = "sessions",
  scope_id = "XNYS",
  from = window_start,
  to = window_end
)$rows

session_rows |>
  as_tibble() |>
  select(session_date, status) |>
  print(n = 12)
#> # A tibble: 12 x 2
#>    session_date status
#>    <date>       <chr>
#>  1 2020-01-13   open
#>  2 2020-01-14   open
#>  3 2020-01-15   open
#>  4 2020-01-16   open
#>  5 2020-01-17   open
#>  6 2020-01-18   closed
#>  7 2020-01-19   closed
#>  8 2020-01-20   closed
#>  9 2020-01-21   open
#> 10 2020-01-22   open
#> 11 2020-01-23   open
#> 12 2020-01-24   open
```

Twelve calendar days, nine of them open. The weekend is there, and so is
Martin Luther King Jr. Day on 2020-01-20, each marked `closed` rather
than left out. Stating the closures is what lets ledgr distinguish “the
market was shut” from “this instrument has no row today”.

> [!NOTE]
>
> ### No calendar package required
>
> `ledgr_facts_sessions()` takes a plain data frame with `session_date`,
> `status`, `session_open`, and `session_close`. Reach for `qlcal` when it
> covers your venue, and build the frame yourself when it does not, or
> when your venue’s history needs corrections the package does not carry.


The nine open sessions also give you the timestamps your bars should
carry. Take them from the calendar rather than typing them out, so that
the panel and the clock cannot drift apart.

``` r
trading_sessions <- session_rows |>
  as_tibble() |>
  filter(status == "open") |>
  pull(session_close)

length(trading_sessions)
#> [1] 9
```

## Step 2: Build a Panel With a Real Hole

Two instruments over those nine sessions. `AAA` trades on all of them.
`BBB` is absent for three sessions in the middle: no row at all, not a
zero-volume row and not a carried price.

``` r
prices <- tibble(instrument_id = c("AAA", "BBB"), base_price = c(100, 50)) |>
  cross_join(tibble(ts_utc = trading_sessions)) |>
  group_by(instrument_id) |>
  mutate(close = base_price + row_number()) |>
  ungroup() |>
  mutate(open = close, high = close, low = close, volume = 1000)

hole_dates <- as.Date(c("2020-01-16", "2020-01-17", "2020-01-21"))
missing_sessions <- trading_sessions[as.Date(trading_sessions) %in% hole_dates]

bars <- prices |>
  filter(!(instrument_id == "BBB" & ts_utc %in% missing_sessions)) |>
  select(instrument_id, ts_utc, open, high, low, close, volume)

bars |> count(instrument_id)
#> # A tibble: 2 x 2
#>   instrument_id     n
#>   <chr>         <int>
#> 1 AAA               9
#> 2 BBB               6
```

`BBB` is missing on 16, 17 and 21 January. Nine rows for `AAA` and six
for `BBB`: that asymmetry is the point, because you are handing ledgr an
honest panel rather than a rectangular one.

## Step 3: Say Which Instruments Were Tradable

A missing row says an instrument did not trade. It does not say why.
Trading status is where you record the reason when you know it, and it
changes what a strategy is allowed to ask for.

Each row below asserts a status from `effective_from` until
`effective_to`, with the higher `precedence` winning where two rows
overlap. Both instruments are active for the whole window, and `AAA` is
additionally halted for the whole of 23 January. An open-ended assertion
leaves `effective_to` empty.

``` r
window_open <- as.POSIXct(window_start, tz = "UTC")
halt_from <- as.POSIXct("2020-01-23", tz = "UTC")
halt_to <- as.POSIXct("2020-01-24", tz = "UTC")

status <- tribble(
  ~instrument_id, ~effective_from, ~effective_to, ~status,  ~precedence,
  "AAA",          window_open,     NA,            "active", 0L,
  "BBB",          window_open,     NA,            "active", 0L,
  "AAA",          halt_from,       halt_to,       "halted", 1L
) |>
  mutate(source = "vignette-example") |>
  ledgr_facts_trading_status(knowledge = "assume_effective")
```

`knowledge = "assume_effective"` says each assertion is known from the
moment it takes effect, which is the right reading for a reference file
you treat as settled history. When your source records when you
*learned* something, use `knowledge = "evidenced"` with a
`knowledge_time` column instead, so that a late correction cannot leak
backwards into earlier decisions.

> [!WARNING]
>
> ### Declaring status is all or nothing
>
> Once any trading-status fact exists, an instrument with no applicable
> assertion resolves to `unknown` and is restricted, not assumed active.
> Silence about a halt is not evidence that there was none. Declare the
> ordinary `active` intervals as well as the exceptions, as the three rows
> above do.


## Step 4: Seal the Snapshot

Sealing binds bars and facts together under one hash. Declaring sessions
also moves the run out of the dense mode, which requires every
instrument on every session, and into the availability-aware mode the
rest of this article uses.

``` r
snapshot <- ledgr_snapshot_from_df(
  bars,
  instruments_df = tibble(instrument_id = c("AAA", "BBB")),
  facts = ledgr_facts(sessions, status),
  db_path = tempfile(fileext = ".duckdb")
)
```

For sealing in general, see
`vignette("data-input-and-snapshots", package = "ledgr")`.

## Step 5: Write a Strategy That Reads Availability

An availability-aware strategy receives universe-aligned planes on
`ctx$vec`. Four of them carry everything this article is about:

- `priced` — does this instrument have a mark your valuation policy
  accepts?
- `mark_age` — how many sessions old is that mark?
- `mark_source` — `current_close` when it traded today, `stale_close`
  when you are carrying an older one, `expired_close` once it is too old
  to use.
- `target_restricted`, with `target_restriction_reason` — may you resize
  it?

The strategy below buys ten units of everything it is allowed to buy.
`ctx$hold()` starts from the positions already held, while
`ctx$tradable()` returns the current members that are admissible and
priced. Anything halted, unlisted, or unpriced therefore stays at its
current quantity without a strategy-side eligibility reconstruction.

``` r
buy_what_is_tradable <- function(ctx, params) {
  targets <- ctx$hold()
  targets[ctx$tradable()] <- 10
  targets
}
```

Asking for a new size on a restricted instrument fails the pulse rather
than trading silently. That is the engine refusing to do what the venue
would not have allowed.

## Step 6: Choose How Stale Is Too Stale

When an instrument has no price today and you still hold it, something
has to decide whether yesterday’s close is good enough to value the
position. `ledgr_valuation_stale(max_sessions)` is the only place that
decision lives, and ledgr ships no default, because there is no
defensible universal answer.

Start strict: a mark may be at most one session old.

``` r
tight <- ledgr_experiment(
  snapshot,
  buy_what_is_tradable,
  opening = ledgr_opening(cash = 100000),
  cost_model = ledgr_cost_zero(),
  valuation_policy = ledgr_valuation_stale(max_sessions = 1)
)

tight_run <- ledgr_run(tight, run_id = "tolerance-one")
tight_completion <- ledgr_run_completion(tight_run)
close(tight_run)
```

The call returns without an error, so look at what the run actually
claims.

``` r
tight_completion
#> Completion Evidence:
#>   Status:           INCOMPLETE
#>   Requested Window: 2020-01-13T21:00:00Z to 2020-01-24T21:00:00Z
#>   Achieved Window:  2020-01-13T21:00:00Z to 2020-01-16T21:00:00Z
#>   Stop Reason:      valuation_horizon_exhausted
#>   Last Fully Valued: 2020-01-16T21:00:00Z
#>   Last Executed:    2020-01-14T14:30:00Z
#>   Performance:       incomplete
#>   Affected IDs:      BBB
#>
#>   Affected Exposure: 530
#>   Exposure Basis:    last_accepted_close_gross
```

The run is `INCOMPLETE`, and it says why: `valuation_horizon_exhausted`.
On the second session of the hole, `BBB`’s last close became older than
the one session you allowed, the portfolio could no longer be valued,
and the run stopped. It did not truncate silently and it did not carry
the price forward to keep going. An incomplete result with a named stop
reason is usable evidence about a shorter window; a complete-looking
result built on invented prices is not.

Now allow a mark to be up to five sessions old, and run the same panel
again.

``` r
loose <- ledgr_experiment(
  snapshot,
  buy_what_is_tradable,
  opening = ledgr_opening(cash = 100000),
  cost_model = ledgr_cost_zero(),
  valuation_policy = ledgr_valuation_stale(max_sessions = 5)
)

loose_run <- ledgr_run(loose, run_id = "tolerance-five")

ledgr_run_completion(loose_run)
#> Completion Evidence:
#>   Status:           DONE
#>   Requested Window: 2020-01-13T21:00:00Z to 2020-01-24T21:00:00Z
#>   Achieved Window:  2020-01-13T21:00:00Z to 2020-01-24T21:00:00Z
#>   Stop Reason:      none
#>   Last Fully Valued: 2020-01-24T21:00:00Z
#>   Last Executed:    2020-01-14T14:30:00Z
#>   Performance:       complete
#>   Affected IDs:      none recorded
#>
#>   Affected Exposure: unknown
#>   Exposure Basis:    unknown
```

Same data, same strategy, a different answer about whether the result
covers the window you asked for. The valuation policy is part of run
identity, so a reader can always see which tolerance produced which
result.

## Reading Back What Happened to One Instrument

After a run, `ledgr_run_explain()` answers “what did you know about this
instrument across the run, and what did you do about it?”. Omit the
timestamp to see the full pulse history for `BBB`:

``` r
ledgr_run_explain(loose_run, "BBB") |>
  select(mark_source, mark_age, execution_outcome, execution_reason)
#> # A tibble: 9 x 4
#>   mark_source   mark_age execution_outcome execution_reason
#>   <chr>            <int> <chr>             <chr>
#> 1 current_close        0 filled            ""
#> 2 current_close        0 no_action         "no_target_change"
#> 3 current_close        0 no_action         "no_target_change"
#> 4 stale_close          1 no_action         "no_target_change"
#> 5 stale_close          2 no_action         "no_target_change"
#> 6 stale_close          3 no_action         "no_target_change"
#> 7 current_close        0 no_action         "no_target_change"
#> 8 current_close        0 no_action         "no_target_change"
#> 9 current_close        0 no_action         "no_target_change"
```

`BBB` is carried at a `stale_close` two sessions old, and nothing
executes. The mark is doing valuation work only. It is never an
execution price, and no fill is ever produced on a session where an
instrument has no observation.

Supplying one timestamp keeps the focused form. Ask about `AAA` on the
session it was halted:

``` r
halted_day <- as.Date(halt_from)
halt_session <- trading_sessions[as.Date(trading_sessions) == halted_day]

ledgr_run_explain(loose_run, "AAA", ts_utc = halt_session) |>
  select(mark_source, target_restricted, target_restriction_reason)
#> # A tibble: 1 x 3
#>   mark_source   target_restricted target_restriction_reason
#>   <chr>         <lgl>             <chr>
#> 1 current_close TRUE              trading_halted
```

`AAA` has a perfectly good price that session, so it is valued normally,
but `trading_halted` blocks a resize. Being priced and being tradable
are separate properties, and this is the case that shows why.

> [!TIP]
>
> ### Try it
>
> Set `max_sessions = 2` and run again. Does the run complete? Then widen
> the hole to four sessions and re-seal. Which of the two knobs, your data
> or your tolerance, decides whether you get a full-window result?


## Rows That Are Present but Wrong

The last case is a row that exists and is invalid, such as a
non-positive close. By default this fails the seal, which is what you
want while you are still cleaning a source.

``` r
broken <- bars |>
  add_row(
    instrument_id = "BBB",
    ts_utc = missing_sessions[1],
    open = 54, high = 54, low = 54, close = -1, volume = 1000
  ) |>
  arrange(instrument_id, ts_utc)

tryCatch(
  ledgr_snapshot_from_df(
    broken,
    instruments_df = tibble(instrument_id = c("AAA", "BBB")),
    facts = ledgr_facts(sessions, status),
    db_path = tempfile(fileext = ".duckdb")
  ),
  ledgr_availability_validation_failed = function(error) {
    conditionMessage(error)
  }
)
#> [1] "Availability input cannot be sealed: ohlc_invalid."
```

With sessions declared you can instead admit the panel and have the
offending row set aside with a recorded reason. That keeps the exclusion
inspectable inside the snapshot rather than buried in a cleaning script
you ran once.

``` r
quarantined <- ledgr_snapshot_from_df(
  broken,
  instruments_df = tibble(instrument_id = c("AAA", "BBB")),
  facts = ledgr_facts(sessions, status),
  invalid_observations = "quarantine",
  db_path = tempfile(fileext = ".duckdb")
)

ledgr_snapshot_quarantine(quarantined) |>
  select(supplied_instrument_id, supplied_ts_utc, reason)
#> # A tibble: 1 x 3
#>   supplied_instrument_id supplied_ts_utc     reason
#>   <chr>                  <dttm>              <chr>
#> 1 BBB                    2020-01-16 21:00:00 ohlc_invalid
```

The quarantined row is not in the panel, so that session behaves exactly
like the vendor hole earlier: unpriced, ageing, no fill. The difference
is that the snapshot records why it is missing.

> [!IMPORTANT]
>
> ### Two accessors are still missing
>
> Quarantined rows are read from the store directly above because there is
> no accessor for them yet, and `ledgr_run_explain()` answers one
> timestamp per call, so a full per-session history still needs a loop.
> The evidence is persisted and hash-bound in both cases; the convenience
> readers are roadmap items.


## What Stays Your Decision

ledgr represents absence. It does not interpret it. Three judgments
remain yours, and each is expressed as data you supply rather than as a
price you patch.

- **Why an observation is missing.** A vendor omission and a genuine
  no-trade day look identical in a price file. When the difference
  matters to your result, say which it was with trading-status or
  lifetime facts.
- **How stale is acceptable.** `ledgr_valuation_stale(max_sessions)` is
  a claim about your instruments and your holding period. Short-horizon
  work on liquid names tolerates far less than a quarterly rebalance on
  small caps.
- **Whether an incomplete run is good enough.** An `INCOMPLETE` result
  with a named stop reason is a real answer about a shorter window.
  Reporting it as a full-window result is the error.

What is not yours to decide is whether a missing price may become a
traded price. It may not, and no setting changes that.

## Where Next

- For sealing, adapters, and snapshot identity, see
  `vignette("data-input-and-snapshots", package = "ledgr")`.
- For what a universe that changes over time does to your results, see
  `vignette("survivorship-bias", package = "ledgr")`.
- For when orders fill and at which bar, see
  `vignette("execution-semantics", package = "ledgr")`.
- For the valuation and availability policy arguments in detail, see
  `?ledgr_valuation_stale`.
