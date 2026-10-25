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

ledgr takes the other path. It never manufactures an execution price: a
carried close may value a holding, but it never becomes a bar to trade
on. Instead it asks you to say which sessions were supposed to exist,
and then tells you, session by session and instrument by instrument,
what it knew and what it did not.

By the end of this article you will have run a backtest over a panel
with a real three-session hole in it, seen why nothing filled during the
hole, and chosen the point at which an old price stops being good enough
to value a position you still hold. A complete panel with no gaps runs
without any of this.

## The Big Picture: Four Questions, Not One

“Missing” feels like one condition. In a backtest it is at least four,
and they have different economic consequences. ledgr keeps them apart,
and each one has its own home in the data you supply.

| The question | Answered by | Consequence when the answer is no |
|----|----|----|
| Was the venue open at all? | the session calendar | there is no pulse; nothing is expected of anyone |
| Was a bar supplied for this instrument? | whether a bar row exists | nothing can fill on that session; its last mark starts ageing and may still value a holding |
| Was it allowed to trade? | trading-status facts | you may hold it or target an exit, but not resize it; while it is halted, an exit target is not executed or queued (Step 5) |
| Was its declared lifetime active? | lifetime facts | it stays on the decision axis when membership or holdings put it there, but target changes are restricted and terminal rules may apply |

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

## What The Calendar Means For Indicators

Dense mode has an implicit clock: the dates present in the rectangular
bar panel. If every instrument is absent on one date, that date is
indistinguishable from a market closure and there is no pulse.
Availability mode instead advances on the independently declared
expected-session calendar. A declared open session remains a pulse even
when one or every instrument lacks an observation.

The small matrix below is an illustrative calendar, separate from the
NYSE window above. It has one closed date, one missing open-session
observation for `AAA`, and a `BBB` series that starts late. Both moving
averages use a two-session window, and price carry is disabled with
`ledgr_history_policy(price_carry = NULL)`. Under the default policy,
`AAA`’s 4 January close would be carried from 2 January for up to five
expected sessions, giving 12 on 4 January and 13 on 5 January.

<!-- strict-gap-table:start -->

| Date | Session | AAA bar | AAA SMA(2) | BBB bar | BBB SMA(2) | Interpretation |
|----|----|---:|---:|---:|---:|----|
| 2020-01-01 | open | 10 | NA | absent | NA | AAA warmup; BBB not yet observed |
| 2020-01-02 | open | 12 | 11 | absent | NA | AAA ready; BBB not yet observed |
| 2020-01-03 | closed | no pulse | no pulse | no pulse | no pulse | venue closure |
| 2020-01-04 | open | missing | NA | absent | NA | expected observation missing; BBB still unseen |
| 2020-01-05 | open | 14 | NA | 20 | NA | AAA window still contains the gap; BBB warmup |
| 2020-01-06 | open | 16 | 15 | 22 | 21 | both windows recover |
| 2020-01-07 | open | 18 | 17 | 24 | 23 | both windows remain available |

<!-- strict-gap-table:end -->

These unavailable windows overlap on 5 January, but for different
reasons. `AAA` has enough historical observations in total and is
unavailable because its current window includes the missing open
session. `BBB` is unavailable because its late-start series has not
completed warmup. A scalar `NA` alone does not distinguish those
histories; the calendar and source observations do.

ledgr never substitutes a stale valuation mark into this feature window.
If a strategy already owns `AAA`, `ledgr_valuation_stale(1)` may use the
2 January close to value that holding at the 4 January pulse. The `AAA`
SMA remains `NA`, because valuation continuity is not feature evidence.
On 6 January the window contains two real observations again and the SMA
recovers to 15.

A strategy therefore guards the value it intends to use as well as the
instrument’s current trading permission:

``` r
signal <- ctx$vec$feature("sma_2")
ready <- !is.na(signal) & ctx$vec$admissible
targets <- ctx$hold()
targets[ready] <- 1
```

Starting from `ctx$hold()` keeps an instrument whose signal is
unavailable at its current quantity. Starting from `ctx$flat()` would
sell it at the next open as soon as its signal went missing, which a
feed gap or warmup rarely justifies.

This uses one singular feature name over the full decision axis. That
name may be a concrete engine ID or an active feature-map alias. In a
sweep, the alias stays fixed while each candidate resolves it to its
concrete feature. Read each required alias once through
`ctx$vec$feature()`; there is no plural whole-universe accessor.

This is stricter than a generic warmup check in one useful way: it says
what the strategy actually needs at this pulse. See
`vignette("indicators", package = "ledgr")` for how bounded and
history-dependent built-in, TTR and custom indicators treat gaps.

## Step 3: Say Which Instruments Were Tradable

A missing row says no observation was supplied. It does not say whether
the instrument traded, or why it did not. Trading status is where you
record what you know, and it changes what a strategy is allowed to ask
for.

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

`knowledge = "assume_effective"` assumes each assertion was known the
moment it took effect. That is acceptable for this synthetic example.
For real data it is an assumption that can hide delayed reporting and
later corrections. When your source records when you *learned*
something, use `knowledge = "evidenced"` with a `knowledge_time` column
instead, so that a late correction cannot leak backwards into earlier
decisions.

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
rest of this article uses. An availability-aware snapshot also declares
its price basis. ledgr counts shares in split-adjusted units (no split
event acts on a position), so `price_basis = "split_adjusted"` states
that the bars are back-adjusted for splits. A snapshot that declares no
basis still runs on that model, and the plan and results label the basis
as an assumed default, so declare it when you know it.

``` r
snapshot <- ledgr_snapshot_from_df(
  bars,
  instruments_df = tibble(instrument_id = c("AAA", "BBB")),
  facts = ledgr_facts(sessions, status),
  price_basis = "split_adjusted",
  db_path = tempfile(fileext = ".duckdb"),
  snapshot_id = "missing_data_demo"
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
  when you are carrying an older one within your tolerance,
  `frozen_close` once you hold it beyond that tolerance and its last
  close is carried as an assumption, `expired_close` when an unheld
  instrument’s close is too old.
- `target_restricted`, with `target_restriction_reason` — may you resize
  it?

The strategy below buys ten units of everything it is allowed to buy.
`ctx$hold()` starts from the positions already held, while
`ctx$tradable()` returns the current members that are admissible and
priced. Anything halted, unlisted, frozen or unpriced therefore stays at
its current quantity without a strategy-side eligibility reconstruction.

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

Selling a halted holding follows the same rule of no queued orders. A
zero target for a halted holding is recorded as not executed and
dropped, not queued. A rule starting from `ctx$flat()` states zero again
on every pulse and so sells at the first open after the halt, while a
zero stated once during the halt never sells. The strategy helpers keep
halted holdings. What ledgr should do by default here is open design
work.

## Step 6: Choose How Stale Is Too Stale

When an instrument has no price today and you still hold it, something
has to decide whether yesterday’s close is good enough to value the
position. `ledgr_valuation_stale(max_sessions)` is the only place that
decision lives. Its default is 5 sessions, chosen from real vendor data
(S&P 500 members over 1998 to 2026): an experiment that names no policy
uses it, and the plan and results mark it as the default. There is no
universal answer, so choose the horizon your data and question need. The
second argument, `exhausted`, says what happens when a held mark grows
older than that.

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
```

The call returns without an error, so look at what the run actually
claims.

``` r
tight_run
#> ledgr Backtest Results
#> ======================
#>
#> WARNING: this result relies on declared valuation or terminal assumptions.
#>   Frozen valuation: 1 holding carried at the last close beyond max_sessions = 1 for 2 instrument-sessions (exhausted = "freeze", the default).
#>
#> Run ID:                            tolerance-one
#> Period:                            2020-01-13T21:00:00Z to 2020-01-24T21:00:00Z
#> Opening Cash:                      $100000.00
#> Final Equity:                      $100140.00
#> Total Return:                      0.14%
#> Max Drawdown:                      0.00%
#> Closed Trades:                     0
#> Metric Calendar:                   US equity daily (default) (252 days/year * 1 bars/day = 252 bars/year)
#>
#> Economic events: NOT SUPPLIED - returns may omit distributions
#> Price basis: split_adjusted (declared)
#> Valuation: FROZEN - 1 holding frozen (longest 2 sessions, max 530 or 0.53% of equity)
#> Point in time: fixed basket; valuation stale-mark horizon 1 session (declared); assumption-backed facts: sessions (knowledge assumed effective, generated schedule); trading_status (knowledge assumed effective)
#> History policy: price carry 5 sessions (default); output carry off (default); segment limit 4 per fact, at least 16 (default)
#>
#> Use summary(bt) for metrics and evidence
```

The run completes, but it opens with a warning. On the second session of
the hole, `BBB`’s last close became older than the one session you
allowed. Under the default `exhausted = "freeze"`, ledgr **froze** the
holding: it kept the quantity and the cash, carried the last close,
stopped `BBB` from being resized, and kept going. When `BBB` traded
again it was valued at its real close and the freeze ended, which is why
nothing is still frozen at the end. The equity on the frozen sessions is
an estimate, and the warning says so before any metric.

The `Point in time:` line says what the run rested on: the universe
(here the fixed basket you passed), the stale-mark horizon, and the
facts ledgr took on assumption rather than on evidence. This calendar
was generated rather than taken from a venue’s record, and neither the
calendar nor the halt records say when they became known, so ledgr
assumed they were known as soon as they took effect. Facts that carry
their own knowledge times drop off that list. The `History policy:` line
below it is a separate setting: how many sessions a price may carry
forward in the strategy’s history reads and features
(`ledgr_history_policy()`), not how long a holding may be valued at a
stale close.

``` r
ledgr_run_explain(tight_run, "BBB") |>
  select(ts_utc, mark_source, mark_age, target_restriction_reason)
#> # A tibble: 9 x 4
#>   ts_utc              mark_source   mark_age target_restriction_reason
#>   <dttm>              <chr>            <int> <chr>
#> 1 2020-01-13 21:00:00 current_close        0 ""
#> 2 2020-01-14 21:00:00 current_close        0 ""
#> 3 2020-01-15 21:00:00 current_close        0 ""
#> 4 2020-01-16 21:00:00 stale_close          1 ""
#> 5 2020-01-17 21:00:00 frozen_close         2 "valuation_frozen"
#> 6 2020-01-21 21:00:00 frozen_close         3 "valuation_frozen"
#> 7 2020-01-22 21:00:00 current_close        0 ""
#> 8 2020-01-23 21:00:00 current_close        0 ""
#> 9 2020-01-24 21:00:00 current_close        0 ""
```

If you would rather stop than estimate, say so:

``` r
refuse_run <- ledgr_run(
  ledgr_experiment(
    snapshot,
    buy_what_is_tradable,
    opening = ledgr_opening(cash = 100000),
    cost_model = ledgr_cost_zero(),
    valuation_policy = ledgr_valuation_stale(max_sessions = 1, exhausted = "refuse")
  ),
  run_id = "tolerance-one-refuse"
)
ledgr_run_completion(refuse_run)
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

Now the run is `INCOMPLETE`, and it says why:
`valuation_horizon_exhausted`. It did not truncate silently and it did
not carry the price forward to keep going. An incomplete result with a
named stop reason is usable evidence about a shorter window; a
complete-looking result built on invented prices is not. Freezing is the
middle ground: complete, but with the assumption named.

`summary()` keeps the incomplete run honest too. It labels the metrics
as covering the achieved prefix only and withholds the annualized ones:

``` r
# Print only the metric lines of summary(refuse_run).
summary_lines <- capture.output(summary(refuse_run))
cat(summary_lines[grepl("prefix|withheld", summary_lines, ignore.case = TRUE)],
    sep = "\n")
#> Achieved-Prefix Metrics (2020-01-13T21:00:00Z to 2020-01-16T21:00:00Z):
#>   Total Return (prefix):    0.03%
#>   Annualized Return:        withheld (achieved window is shorter than requested)
#>   Max Drawdown (prefix):    0.00%
#>   Volatility (annual): withheld (achieved window is shorter than requested)
#>   Sharpe Ratio:        withheld (achieved window is shorter than requested)
```

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

ledgr_valuation_summary(loose_run)
#>
#> Valuation Evidence:
#> Valuation: STALE - 1 holding valued at a permitted stale close (longest age 3 sessions)
#>   Universe:                    fixed basket
#>   Assumption-backed facts:     sessions (knowledge assumed effective, generated schedule); trading_status (knowledge assumed effective)
#>   Stale-mark horizon:          5 sessions (default)
#>   Exhausted marks:             freeze
#>   Stale instrument-sessions:   3
#>   Frozen instrument-sessions:  0
#>   Longest freeze:              0 sessions
#>   Max frozen value:            0
#>   Max frozen weight:           0.00%
#>   Frozen at end:               0 holdings, 0 (0.00% of equity)
#>   Return if frozen worthless:  not applicable
#>
#> History Policy:
#>   Price carry:                 5 sessions (default)
#>   Output carry:                off (default)
#>   Segment limit:               4 per fact, at least 16 (default)
```

Same data, same strategy, and no warning this time: every carried mark
stayed within five sessions, so nothing was frozen. The valuation policy
is part of run identity, so a reader can always see which tolerance
produced which result.

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

Across the hole `BBB` is carried at a `stale_close` that grows one, two
and three sessions old. Nothing executes, but nothing was requested
either, so this table alone proves little. Ask for a change whose
execution falls inside the hole: halve `BBB` at the January 15 close,
whose next open is January 16.

``` r
trim_in_hole <- function(ctx, params) {
  targets <- ctx$hold()
  targets[ctx$tradable()] <- 10
  if (format(ledgr_utc(ctx$ts_utc), "%Y-%m-%d", tz = "UTC") == "2020-01-15") {
    targets[["BBB"]] <- 5
  }
  targets
}

trim_run <- ledgr_run(
  ledgr_experiment(
    snapshot,
    trim_in_hole,
    opening = ledgr_opening(cash = 100000),
    cost_model = ledgr_cost_zero(),
    valuation_policy = ledgr_valuation_stale(max_sessions = 5)
  ),
  run_id = "trim-in-hole"
)

ledgr_run_explain(trim_run, "BBB") |>
  select(ts_utc, target_before_risk, execution_reason, resulting_position) |>
  head(5)
#> # A tibble: 5 x 4
#>   ts_utc              target_before_risk execution_reason        resulting_position
#>   <dttm>                           <dbl> <chr>                                <dbl>
#> 1 2020-01-13 21:00:00                 10 ""                                      10
#> 2 2020-01-14 21:00:00                 10 "no_target_change"                      10
#> 3 2020-01-15 21:00:00                  5 "execution_bar_missing"                 10
#> 4 2020-01-16 21:00:00                 10 "no_target_change"                      10
#> 5 2020-01-17 21:00:00                 10 "no_target_change"                      10
```

The January 15 request meets no `BBB` bar at the January 16 open, so it
is recorded as `execution_bar_missing` and the position stays at 10. On
January 16 the rule asks for 10 again, the quantity already held, so
there is no change to make and the earlier request is not retried. The
mark is doing valuation work only. It is never an execution price, and
no fill is ever produced on a session where an instrument has no
observation.

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

The example keeps an ordinary `AAA` bar on the halted session on
purpose: a supplied bar does not lift a trading-status restriction. The
bar values the holding, but `trading_halted` blocks a resize, and the
bar is not evidence of executable liquidity. Being priced and being
tradable are separate properties, and this is the case that shows why.

> [!TIP]
>
> ### Try it
>
> Set `max_sessions = 2` and run again under a new `run_id`, since a store
> keeps one run per ID. Does `BBB` still freeze? Then widen the hole to
> four sessions and re-seal. Which of the two knobs, your data or your
> tolerance, decides whether the result rests on an assumed mark?


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
    price_basis = "split_adjusted",
    db_path = tempfile(fileext = ".duckdb"),
    snapshot_id = "missing_data_refused"
  ),
  ledgr_availability_validation_failed = function(error) {
    conditionMessage(error)
  }
)
#> [1] "Availability input cannot be sealed: ohlc_non_positive."
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
  price_basis = "split_adjusted",
  invalid_observations = "quarantine",
  db_path = tempfile(fileext = ".duckdb"),
  snapshot_id = "missing_data_quarantined"
)

ledgr_snapshot_quarantine(quarantined) |>
  select(supplied_instrument_id, supplied_ts_utc, reason)
#> # A tibble: 1 x 3
#>   supplied_instrument_id supplied_ts_utc     reason
#>   <chr>                  <dttm>              <chr>
#> 1 BBB                    2020-01-16 21:00:00 ohlc_non_positive
```

The quarantined row is not in the panel, so that session behaves exactly
like the vendor hole earlier: unpriced, ageing, no fill. The difference
is that the snapshot records why it is missing.

> [!NOTE]
>
> ### Use the public evidence readers
>
> `ledgr_snapshot_quarantine()` returns the rows rejected during sealing,
> as the example above shows. `ledgr_run_explain(run, instrument_id)`
> returns the full retained pulse history when `ts_utc` is omitted; supply
> one timestamp only when you want the focused one-row answer. Neither
> requires direct store access.


## What Stays Your Decision

ledgr represents absence. It does not interpret it. Four judgments
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
- **What happens beyond that.** `exhausted = "freeze"` carries the last
  close as a named assumption and keeps the run going;
  `exhausted = "refuse"` stops it. A frozen result is complete but
  estimated; an `INCOMPLETE` result is a real answer about a shorter
  window. Reporting either as an exact full-window result is the error.
- **Whether a row is really a trade.** Halts and untraded sessions that
  a data source encodes as zero-volume bars carrying the previous close,
  as the reference Sharadar data does, are still read as observed
  prices: they can fill and they bypass valuation ageing and freezing.

What is not yours to decide is whether a missing price may become a
traded price. It may not, and no setting changes that.

## Where This Fits

This article uses a small `AAA`/`BBB` example because a three-session
hole makes mark ageing and the no-fill rule easy to see. For the
complete reusable data model, including sessions, membership, status,
lifetime and corporate actions, continue to
`vignette("point-in-time-inputs", package = "ledgr")`. You do not need
that full model for an ordinary dense-bars experiment.

The identifiers in this article are local to this article; they are not
extra history for the shared `DEMO_*` instruments. When you want to try
this lesson on data that also carries membership, trading status and
lifetime facts, load the shared `ledgr_demo_pit_inputs` bundle. It
contains the same kind of missing observation, and this check finds it:

``` r
data("ledgr_demo_pit_inputs", package = "ledgr")
shared_gap <- subset(
  ledgr_demo_pit_inputs$cases,
  type == "missing_observation"
)
shared_gap_has_bar <- with(
  ledgr_demo_pit_inputs$bars,
  any(
    instrument_id == shared_gap$instrument_id[[1L]] &
      as.Date(ts_utc) == shared_gap$date[[1L]]
  )
)
data.frame(shared_gap, observation_row_present = shared_gap_has_bar)
#>                  type instrument_id       date observation_row_present
#> 2 missing_observation       DEMO_04 2020-01-09                   FALSE
```

## Where Next

- For crediting a cash distribution to a held position, see
  `vignette("corporate-action-cash", package = "ledgr")`.
- For what a universe that changes over time does to your results, see
  `vignette("survivorship-bias", package = "ledgr")`.
- For when orders fill and at which bar, see
  `vignette("execution-semantics", package = "ledgr")`.
- For the valuation and availability policy arguments in detail, see
  `?ledgr_valuation_stale`.
