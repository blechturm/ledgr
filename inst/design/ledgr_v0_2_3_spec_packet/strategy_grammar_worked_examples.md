# Worked Examples: Sixteen Strategies In The Grammar

Appendix to [`strategy_grammar_ux_brief.md`](strategy_grammar_ux_brief.md).
Non-binding spike output (stage 3 of the strategy-grammar spike).

Each of the nine designed strategies has three parts. **Economics** says what
the strategy bets on, why it might work, when it fails, what each parameter
means, how sensitive it is to turnover and costs, and why point-in-time data
matters. Sources are cited by name; no performance number appears, from
simulation or from the literature. **What ledgr does today** points at the
stage 1 translation in `../strategies/` and the code that fights the idea; it
is unchanged from stage 2. **With the grammar** shows the stage 3 rewrite in
this directory and what changed. The three held-out strategies and the four
review probes follow in shorter sections.

All sixteen run on the same simulated snapshot (`../snapshot.R`). Simulated
data says nothing about whether a strategy works; it only exercises the code.
The prototype spells the rebalance verb `ledgr_target_rebalance2()` because
today's `ledgr_target_rebalance()` is the stage 1 baseline (brief, Section 2).

## 01 12-1 cross-sectional momentum

### Economics

- **Bet.** Stocks that rose most over the past year, skipping the latest
  month, keep outperforming stocks that rose least for the next few months.
  The long-only leg holds the top decile in equal weight and re-ranks monthly
  (Jegadeesh & Titman 1993, "Returns to Buying Winners and Selling Losers",
  Journal of Finance).
- **Why it might work.** Behavioural accounts say investors underreact to
  news that arrives gradually (Barberis, Shleifer & Vishny 1998, "A Model of
  Investor Sentiment", Journal of Financial Economics; Hong & Stein 1999, "A
  Unified Theory of Underreaction, Momentum Trading, and Overreaction in Asset
  Markets", Journal of Finance). Whether it is compensation for risk is
  disputed.
- **Why skip a month.** The most recent month tends to reverse (Jegadeesh
  1990, "Evidence of Predictable Behavior of Security Returns", Journal of
  Finance; Lehmann 1990, "Fads, Martingales, and Market Efficiency",
  Quarterly Journal of Economics). Including it mixes two opposite effects.
- **When it fails.** Momentum crashes: after a market fall, the losers
  rebound sharply and the winners lag (Daniel & Moskowitz 2016, "Momentum
  Crashes", Journal of Financial Economics). A long-only top decile also
  carries the market's own drawdowns.
- **Parameters.** The 12-month formation window sets how slow the signal
  is; the 1-month skip removes reversal; the decile trades concentration
  against diversification; monthly holding sets turnover.
- **Turnover and costs.** The winner list changes every month, so a large
  part of the book trades at each rebalance. Whether the effect survives
  trading costs is studied in Lesmond, Schill & Zhou (2004, "The Illusory
  Nature of Momentum Profits", Journal of Financial Economics) and Korajczyk &
  Sadka (2004, "Are Momentum Profits Robust to Trading Costs?", Journal of
  Finance).
- **Point-in-time.** Ranking today's index members over their past selects
  survivors; stocks that left or were delisted vanish from the test. The rule
  must rank the members at each decision date and sell a holding that leaves
  the index. Delisting returns matter too (Shumway 1997, "The Delisting Bias
  in CRSP Data", Journal of Finance).

### What ledgr does today

- `strategies/01_momentum_12_1.R:12-15` rebuilds the skip return from two
  trailing returns: `(1 + r12) / (1 + r1) - 1`.
- `:16` derives the decile count from `length(ctx$members)`.
- `:21` holds back 2% (`equity_fraction = 0.98`) so the next open does not
  reject the buys.
- `:23` zeroes departed members by hand after `ledgr_target_rebalance()` has
  kept them and reserved their value, which then sits in cash for a month.

### With the grammar

`01_momentum_12_1.R`:

```r
eleven_month_return <- ledgr_ind_returns(231)
skip_month_return <- ledgr_ind_lag(eleven_month_return, 21)
features <- ledgr_feature_map(skip_month_return = skip_month_return)

momentum_12_1 <- function(ctx, params) {
  ledgr_signal_feature(ctx, "skip_month_return") |>
    ledgr_select_top(fraction = params$decile, partial = "allow") |>
    ledgr_weight_equal() |>
    ledgr_target_rebalance2(ctx, exit = !ctx$vec$member, invest_fraction = params$invest)
}
```

The skip is a named feature (the 231-session return as of 21 sessions ago),
the decile is `fraction`, and index leavers are an explicit `exit` set
(maintainer decision 2). No capital base is named: once leavers are exited,
nothing is preserved, so total equity is unambiguous and is disclosed as the
default in the target's origin. Strategy lines: 15 to 6. **Deliberate
difference:** the departed member's value is redeployed in the same
decision. Fills equal stage 1's until the decision of 2021-02-26, where the
stage 1 book held a departed member (`evidence/parity.csv`; STK04 left the
index on 2021-02-01), and equal stage 2's 90 fills. Without the `exit` the
rewrite now fails at that decision instead of silently keeping the leaver
(`gut_stage3.R`). The 2% buffer stays (execution-policy RFC).

## 02 momentr funnel

### Economics

- **Bet.** Persistent winners: a stock must rank high on a long lookback,
  then on a medium one among those, then on a short one among those. The
  cascade asks for momentum that holds across horizons. Winners ride while
  they stay in the long-horizon list. Profits above a high-water mark are
  partly skimmed into SPY and BIL sleeves, which are only added to. Source:
  github.com/gladio-analytics/momento, as summarised in the stage 1 brief; the
  repository was not re-read.
- **Why it might work.** The cascade is cross-sectional momentum with a
  persistence filter. Novy-Marx (2012, "Is Momentum Really Momentum?",
  Journal of Financial Economics) finds that the intermediate horizon carries
  most of the effect, which argues for reading the short final stage as a
  timing filter rather than as the core signal. The skim is a risk-budgeting
  rule of the repository, not a published effect.
- **When it fails.** As for 01 (momentum crashes), and faster: a weekly
  short-horizon stage reacts to noise. Letting winners ride concentrates the
  book in the names that crash hardest in a reversal.
- **Parameters.** `n1`, `n2`, `n3` set how strict each stage is (10, 5 and
  3 here); the lookbacks set the horizons; the one-week skip removes the
  shortest reversal; `skim` sets how much of each new high is banked.
- **Turnover and costs.** Weekly decisions with a short final stage trade
  often; riders reduce turnover. Cost sensitivity is high.
- **Point-in-time.** The stock universe is a restricted membership list;
  the sleeves are always eligible. A departed member must be sold, and a
  ranking must never see a nonmember.

### What ledgr does today

- `strategies/02_momentr_funnel.R:20` rebuilds skip scores and strips them
  with `as.numeric()`.
- `:23-28` masks scores with `NA` and re-wraps them with
  `ledgr_signal(ctx, values = )` at every stage.
- `:35-36` rebuilds holding values from `position * close`.
- `:44-45` and `:50-51` are escape hatches: allocatable capital is recomputed
  by hand to fund the skim, and sleeve top-ups are share quantities added
  after the helper.
- `:52` zeroes departed members by hand.
- `snapshot.R:72` declares a third membership universe because a run takes
  one universe.

### With the grammar

`02_momentr_funnel.R`:

```r
momentr_funnel <- function(ctx, params) {
  sleeves <- c("SPY", "BIL")
  stocks <- !ctx$universe %in% sleeves
  pick1 <- ledgr_select_top(ledgr_signal_feature(ctx, "long"), params$n1, within = stocks, partial = "allow")
  pick2 <- ledgr_select_top(ledgr_signal_feature(ctx, "medium"), params$n2, within = pick1, partial = "allow")
  pick3 <- ledgr_select_top(ledgr_signal_feature(ctx, "short"), params$n3, within = pick2, partial = "allow")
  losers <- ledgr_select_held(ctx, where = stocks & !pick1 | !ctx$vec$member)

  stock_book <- ctx$equity - sum(ledgr_holding_value(ctx)[sleeves])
  hwm <- ctx$state_prev$hwm
  if (is.null(hwm)) hwm <- stock_book
  skim <- max(0, params$skim * (stock_book - hwm))
  hwm <- max(hwm, stock_book - skim)

  ledgr_target_adjust(ctx, weights = ledgr_weight_equal(pick3), exit = losers,
                      add_value = c(SPY = skim / 2, BIL = skim / 2),
                      capital_base = "remaining_equity") |>
    ledgr_strategy_result(hwm = hwm)
}
```

Each stage is one `ledgr_select_top(within = )`. The rule is an adjustment:
buy the finalists, sell what fell out of the first cut or left the index, add
the skim to the sleeves, and leave the riders and sleeves alone. The riders
are no longer named; they are what the adjustment does not touch. The
finalists share the remaining equity after those holdings and the skim, so
`capital_base = "remaining_equity"` is the rule's own wording. Strategy
lines: 40 to 19. **Deliberate difference:** as in 01. Fills equal stage 1's
until the decision of 2019-06-03, where the stage 1 book held a departed
member (STK05 left the index that day), and equal stage 2's 649 fills. The
third universe in `snapshot.R` stays (experiment-level composition, brief
Section 6). The high-water mark is portfolio state passed to
`ledgr_strategy_result(hwm = )`.

## 03 Dual momentum, GEM

### Economics

- **Bet.** Two kinds of momentum at once. Relative momentum picks the
  stronger of US and international equity; absolute momentum holds it only
  if it beat T-bills, else holds bonds (Antonacci 2014, "Dual Momentum
  Investing", McGraw-Hill). The absolute leg is time-series momentum
  (Moskowitz, Ooi & Pedersen 2012, "Time Series Momentum", Journal of
  Financial Economics).
- **Why it might work.** Trends in broad asset classes persist over months;
  the absolute filter steps aside in long bear markets.
- **When it fails.** Sharp V-shaped reversals: a monthly 12-month signal
  exits late and re-enters late (whipsaw). Holding one asset gives no
  diversification while invested.
- **Parameters.** The 12-month lookback sets the trend horizon; the T-bill
  hurdle sets when to leave equity; the bond fallback sets the defensive
  asset. (The book applies the T-bill test to US equity; the stage 1 brief's
  form is used.)
- **Turnover and costs.** Low: switches happen only when the signal flips,
  but each switch moves the whole account.
- **Point-in-time.** Four broad ETFs; the main point-in-time questions are
  price adjustments (total return versus price) and the T-bill series, not
  membership.

### What ledgr does today

- `strategies/03_dual_momentum_gem.R:18-21` uses three helpers to hold one
  name and holds back 2%: at 100% the book was rejected at the open and sat in
  cash for months (`probe_findings.md`).

### With the grammar

```r
gem <- function(ctx, params) {
  r12 <- ledgr_signal_return(ctx, lookback = 252)
  if (!ledgr_passed_warmup(ctx, r12)) return(ctx$flat())
  winner <- if (r12[["SPY"]] >= r12[["EFA"]]) "SPY" else "EFA"
  hold <- if (r12[[winner]] > r12[["BIL"]]) winner else "AGG"
  ledgr_target_rebalance2(setNames(1, hold), ctx, invest_fraction = params$invest)
}
```

A plain named weight goes straight into the rebalance verb; the
`ledgr_weights()` wrapper is gone. Fills equal stage 1's exactly. The scalar
comparisons stay ordinary R: with two candidates a ranking verb adds nothing.

## 04 Faber GTAA timing model

### Economics

- **Bet.** Hold each of five asset classes at a fixed 20% only while its
  month-end price is above its 10-month moving average; otherwise hold that
  slice in cash (Faber 2007, "A Quantitative Approach to Tactical Asset
  Allocation", Journal of Wealth Management).
- **Why it might work.** A trend filter sidesteps long drawdowns, which
  tend to be persistent declines rather than single shocks. The broad
  evidence for trend following across assets is in Hurst, Ooi & Pedersen
  (2017, "A Century of Evidence on Trend-Following Investing", Journal of
  Portfolio Management).
- **When it fails.** Range-bound markets that cross the average repeatedly
  (whipsaw), and fast crashes that happen within a month.
- **Parameters.** The 10-month window sets trend speed; month-end sampling
  limits trading to twelve checks a year; the fixed slices keep each asset's
  risk independent of the others' signals.
- **Turnover and costs.** Low: monthly checks, one slice at a time.
- **Point-in-time.** Fixed ETF list; price adjustment matters, and the
  published rule samples month-end closes, which a daily average only
  approximates.

### What ledgr does today

- `strategies/04_faber_gtaa.R:8` approximates the month-end SMA by a
  210-session daily SMA.
- `:13-14` builds a named weight vector by hand, because equal weighting
  would spread the budget over the survivors, and coerces warm-up `NA` with
  `%in% TRUE`.

### With the grammar

```r
gtaa <- function(ctx, params) {
  above <- ledgr_selection(ctx, where = ctx$vec$close > ctx$vec$feature("sma_210"), missing = "exclude")
  ledgr_weight_each(above, params$slice) |>
    ledgr_target_rebalance2(ctx, invest_fraction = params$invest)
}
```

`ledgr_weight_each()` says "20% each, rest cash" directly. Fills equal stage
1's exactly. The month-end SMA stays an approximation: a calendar-sampling
feature transform is reasoned out (brief, friction 16).

## 05 Keller VAA

### Economics

- **Bet.** Breadth momentum: if every offensive asset has positive
  momentum, hold the best offensive asset; if even one is negative, move
  entirely to the best defensive asset (Keller & Keuning 2017, "Breadth
  Momentum and Vigilant Asset Allocation (VAA)", SSRN 3002624). The 13612W
  score weights the 1-, 3-, 6- and 12-month returns 12, 4, 2 and 1, so it
  reacts fast.
- **Why it might work.** Weak breadth among risky assets is treated as an
  early warning of a broad decline; the fast score cuts exposure early.
- **When it fails.** Frequent false alarms: a single weak asset sends the
  whole book defensive, and the fast score flips often in choppy markets.
- **Parameters.** The 13612W weights set how fast the score is; the
  offensive and defensive lists set the pools; top 1 sets concentration.
- **Turnover and costs.** Moderate: monthly, but whole-book switches.
- **Point-in-time.** Fixed ETF lists; the snapshot lacks the paper's EEM,
  LQD, IEF and SHY, so the pools here are substitutes.

### What ledgr does today

- `strategies/05_keller_vaa.R:20-23` strips the score to numeric, sets the
  other pool to `NA` and re-wraps it as a signal to rank one pool.

### With the grammar

```r
vaa <- function(ctx, params) {
  score <- 12 * ledgr_signal_return(ctx, 21) + 4 * ledgr_signal_return(ctx, 63) +
    2 * ledgr_signal_return(ctx, 126) + ledgr_signal_return(ctx, 252)
  if (!ledgr_passed_warmup(ctx, score)) return(ctx$flat())
  offensive <- ctx$universe %in% params$offensive
  pool <- if (all(score[offensive] > 0)) offensive else !offensive
  ledgr_select_top(score, 1, within = pool) |>
    ledgr_weight_equal() |>
    ledgr_target_rebalance2(ctx, invest_fraction = params$invest)
}
```

`within = pool` replaces the mask-and-re-wrap. Fills equal stage 1's exactly.

## 06 Volatility-targeted naive risk parity

### Economics

- **Bet.** Weight assets by the inverse of their volatility, so each
  contributes similar risk, then scale the book so its estimated volatility
  hits a target. Inverse volatility is the equal-risk-contribution portfolio
  when correlations are equal (Maillard, Roncalli & Teiletche 2010, "The
  Properties of Equally Weighted Risk Contribution Portfolios", Journal of
  Portfolio Management). Scaling to a volatility target follows Moreira & Muir
  (2017, "Volatility-Managed Portfolios", Journal of Finance).
- **Why it might work.** Volatility is more predictable than returns, so
  balancing and scaling by it controls risk without forecasting returns.
- **When it fails.** Correlation spikes, when assets that looked
  diversifying fall together; estimation error in short windows; volatility
  targeting cuts exposure after a shock and can miss the rebound.
  Cederburg, O'Doherty, Wang & Yan (2020, "On the Performance of
  Volatility-Managed Portfolios", Journal of Financial Economics) question how
  well volatility management holds up out of sample. Classic risk parity
  levers up low-volatility assets (Asness, Frazzini & Pedersen 2012, "Leverage
  Aversion and Risk Parity", Financial Analysts Journal); this long-only
  version caps exposure at 100% instead.
- **Parameters.** The 63-session window sets how fast volatility estimates
  move; the 10% target sets overall risk; the cap at 100% forbids leverage.
- **Turnover and costs.** Moderate: monthly weight drift from changing
  volatilities.
- **Point-in-time.** The estimator must see only returns up to the decision
  close; ledgr's history read supplies exactly that window.

### What ledgr does today

- `strategies/06_vol_target_risk_parity.R:13-24` reads like the method. Its
  only friction is the 2% buffer at `:24`.

### With the grammar

The estimator is unchanged ordinary R; only the last call becomes
`ledgr_target_rebalance2(ctx, invest_fraction = params$invest)`. Fills equal stage
1's exactly. This is the grammar's boundary: estimators stay outside it and
hand over `ledgr_weights` (research strategy UX brief).

## 07 60/40 with a tolerance band

### Economics

- **Bet.** Not a return bet: a fixed 60/40 risk mix, restored only when a
  weight drifts more than 5 points from target. Threshold rebalancing is
  studied in Daryanani (2008, "Opportunistic Rebalancing", Journal of
  Financial Planning) and Jaconetti, Kinniry & Zilbering (2010, "Best
  Practices for Portfolio Rebalancing", Vanguard).
- **Why it might work.** Rebalancing keeps risk near the chosen mix; a band
  avoids paying costs for small drifts.
- **When it fails.** Long one-way trends, where rebalancing keeps selling
  the winner; very wide bands let risk drift far from the target.
- **Parameters.** The 60/40 split sets the risk mix; the 5-point band
  trades tracking of the mix against trading; daily checks make the band, not
  the calendar, the trigger.
- **Turnover and costs.** Low by design; the band is the cost control.
- **Point-in-time.** Two broad ETFs; adjusted prices matter for the drift
  test.

### What ledgr does today

- `strategies/07_sixty_forty_band.R:11` rebuilds current weights from
  `position * close / equity`, and `:12` hand-codes the band as a drift test
  that returns `ctx$hold()`.

### With the grammar

```r
sixty_forty <- function(ctx, params) {
  target_w <- params$weights[ctx$universe]
  drift <- ledgr_holding_value(ctx) / ctx$equity - target_w
  if (all(abs(drift) <= params$band)) return(ctx$hold())
  ledgr_target_rebalance2(target_w, ctx, invest_fraction = params$invest)
}

params <- list(weights = c(SPY = 0.6, AGG = 0.4), band = 0.05, invest = 0.98)
```

The band stays a guard (P7). `ledgr_holding_value()` names the quantity the
rule talks about. The weights are a named vector param, so `unlist()` and
`ledgr_weights()` are gone. Fills equal stage 1's exactly. A `band` argument on the
target verb, and the full current-weights contract, are left to the
portfolio-construction RFC.

## 08 Connors RSI(2) mean reversion

### Economics

- **Bet.** Short-term pullbacks in an uptrend reverse within days: buy when
  the 2-day RSI is very low and the price is above its 200-day average; sell
  when RSI recovers or the price closes above its 5-day average (Connors &
  Alvarez 2009, "Short Term Trading Strategies That Work", TradingMarkets).
- **Why it might work.** Short-horizon reversal is documented (Jegadeesh
  1990; Lehmann 1990); one explanation is that reversal pays liquidity
  providers, more so when liquidity is scarce (Nagel 2012, "Evaporating
  Liquidity", Review of Financial Studies). The 200-day filter avoids buying
  dips in a downtrend.
- **When it fails.** Trend breaks: a pullback that becomes a crash, with no
  stop in the rule. Crowded or illiquid conditions widen the cost of trading
  at the open.
- **Parameters.** RSI length 2 makes the oscillator very fast; the entry and
  exit thresholds (10 and 70) set how extreme a dip must be; the 200-day SMA
  is the trend filter; slots cap the number of positions and size each at a
  share of equity; "most oversold first" decides among candidates.
- **Turnover and costs.** Very high: daily decisions and holding periods of
  days. This is the most cost-sensitive of the nine.
- **Point-in-time.** Dip-buying in a stock that is about to be delisted is
  the classic survivorship trap; the candidate set must be the members at the
  decision, and a departed holding must still be exitable.

### What ledgr does today

- `strategies/08_connors_rsi2.R:18` and `:22` coerce warm-up `NA` with
  `%in% TRUE`; `:21` applies `ctx$vec$admissible` by hand.
- `:25-28` ranks setups by `NA`-masking `-rsi` and re-wrapping it.
- `:29-30` is an escape hatch: equal slots of total equity are share
  quantities, because `keep` makes rebalance weights apply to the residual.

### With the grammar

```r
connors_rsi2 <- function(ctx, params) {
  rsi <- ledgr_signal_feature(ctx, "rsi_2")
  close <- ctx$vec$close
  exits <- ledgr_select_held(ctx, where = rsi > params$exit_rsi | close > ctx$vec$feature("sma_5"))
  setup <- ledgr_selection(ctx, missing = "exclude",
    where = !ctx$vec$held & rsi < params$entry_rsi & close > ctx$vec$feature("sma_200"))
  free <- max(0, params$slots - sum(ctx$vec$held & !exits))

  entries <- ledgr_select_lowest(rsi, free, within = setup, partial = "allow")
  ledgr_target_adjust(ctx, weights = ledgr_weight_each(entries, 1 / params$slots), exit = exits,
                      invest_fraction = params$invest, capital_base = "total_equity")
}
```

Exits are a holding set, entries a buy set ranked by
`ledgr_select_lowest()`, and slots are fixed weights of total equity. The rule
is an adjustment, so `keep = ctx$vec$held` is gone: the adjustment touches
only the exits and the entries. Strategy lines: 22 to 12. Fills equal stage
1's exactly, all 2,031 of them. Swapping the base to `"remaining_equity"`
changes the fills (`gut_stage3.R`).

## 09 Turtle / Donchian breakout

### Economics

- **Bet.** Long trends start with breakouts: buy when the price closes
  above its previous 20-day high; exit on a close below the previous 10-day
  low or 2 ATR below entry. Size each unit so a one-ATR move costs 1% of
  equity (Faith 2007, "Way of the Turtle", McGraw-Hill). It is time-series
  momentum with a channel trigger (Moskowitz, Ooi & Pedersen 2012; Hurst,
  Ooi & Pedersen 2017).
- **Why it might work.** A few large trends pay for many small losses;
  volatility-scaled units make each bet risk the same amount.
- **When it fails.** Range-bound markets produce repeated false breakouts.
  Win rates are low, so a run of losses is normal and long. The original
  traded futures with leverage; long-only unlevered stocks cannot take the
  full unit size, so the rule here scales units down to fit cash, which
  changes its risk.
- **Parameters.** The 20-day entry and 10-day exit channels set trend
  sensitivity; ATR(20) sets the volatility unit; 1% risk per ATR sets
  position size; the 2N stop sets the loss limit per trade.
- **Turnover and costs.** Moderate: many entries are stopped out quickly.
  Costs bite on the false breakouts.
- **Point-in-time.** A breakout in a stock that leaves the index must not
  open a position, and a held one must still be stopped out. Delisting during
  an open trade is a real loss path (Shumway 1997).

### What ledgr does today

- `strategies/09_turtle_donchian.R:10-19` defines custom indicators for the
  previous-N-day high and low.
- `:29-32` reads stops with `vapply` over IDs; `:48-51` writes and clears
  them in loops; `:49` stores the decision close as the entry price.
- `:40-46` is an escape hatch: ATR units as share quantities plus a
  hand-rolled cash-budget scale-down.

### With the grammar

The full rewrite is the worked flow in Section 3 of the brief. The lagged
Donchian channel replaces the custom indicators; the stop is an ordinary
vector from `ledgr_asset_state(ctx, stop = NA_real_)`, set for entries and
set to `NA` (forgotten) for exits, which replaces the author's loops;
`ledgr_target_adjust()` with `capital_base = "total_equity"` and
`fit_to_remaining` replaces the escape hatch. Strategy lines: 30 to 14.
Fills equal stage 1's exactly, all 741 of them, so `fit_to_remaining`
reproduces the hand-rolled scale-down (floor the units, then scale the
whole-share quantities). The entry price is still the decision close, and
the leverage the original assumes is still outside the contract.

## Held-out strategies

Written in stage 2 phase B by an author who saw only the brief; rewritten
here with the stage 3 names. The fidelity assertion of each is the stage 2
file's, evaluated unchanged against the rewrite (`heldout/`), and all three
pass (`evidence/heldout.csv`).

- **H1 52-week high** (George & Hwang 2004). `ledgr_select_top(score,
  fraction = 0.2)` and `ledgr_target_rebalance2(exit = !ctx$vec$member,
  invest_fraction = )`. Same 261 fills, 0 oracle mismatches.
- **H2 reversal with a trend filter.** The worst five-day returns are
  `ledgr_select_lowest(ret_5, 5, within = uptrend)`, which reads as the rule;
  stage 2 needed `ledgr_select_top(-ret_5, ...)`. 1,340 fills, 0 mismatches.
- **H3 permanent portfolio.** The 25% weights are a named vector param going
  straight into `ledgr_target_rebalance2()`; the band stays a guard. Three
  rebalances, at exactly the breach days.

## Review probes

The four probes of the Type 2 review (`../stage2/review/probes.R`), each
written once as the rule it states (`probes.R`). The review ran each in a
"misleading" and a "working" variant; stage 3 has one version, and its fill
count equals the review's working variant (`evidence/probes.csv`).

- **A. Partial sleeves.** SPY and AGG at 20% of the account beside untouched
  gold: `ledgr_target_rebalance2(c(SPY = 0.2, AGG = 0.2), ctx, keep = "GLD",
  capital_base = "total_equity")`. At the first session it targets 459 SPY
  shares, not the 358 that residual sizing gave. The same call without a base
  fails with `ledgr_capital_base_required`, because the kept gold makes the
  two bases differ. 91 fills.
- **B. Unknown signal.** `keep = is.na(average)` leaves a holding with an
  unknown average alone. The kept holdings make the base ambiguous, so the
  probe names it. 1,024 fills.
- **C. Conditional accumulator.** `ledgr_target_adjust(ctx, add_value =
  c(SPY = addition))`. With `addition = 0` every holding is preserved,
  including the inherited AGG: no `keep`, no empty weights, no sale.
  29 fills, 0 AGG sales.
- **D. Trailing stop with a cooldown.**

  ```r
  memory <- ledgr_asset_state(ctx, peak = NA_real_, cooldown = 0)
  peak <- pmax(memory$peak, price, na.rm = TRUE)
  exits <- ledgr_select_held(ctx, where = price < 0.95 * peak)
  entries <- ledgr_selection(ctx, where = !ctx$vec$held & memory$cooldown == 0)
  memory$peak <- peak
  memory$peak[exits | !(ctx$vec$held | entries)] <- NA   # forget the peak when flat
  memory$cooldown <- ifelse(exits, params$wait, pmax(0, memory$cooldown - 1))
  ```

  Forgetting the peak is `NA` in one field; the cooldown survives in the
  other. No sentinel, no per-field branching, no `clear`. 58 fills; the
  shortest exit-to-re-entry gap is six sessions.
