# Cash Distributions


ledgr can post a fully evidenced ordinary cash distribution without
enabling the broader availability model. The research preset uses the
vendor-normalized gross amount and credits it at the ex-dividend session
close.

That timing is a model assumption. It prevents a missing-asset dip on
the ex-date, but makes cash spendable before a broker might actually pay
it.

## A Minimal Evidenced Dividend

``` r
times <- as.POSIXct("2020-01-01 16:00:00", tz = "UTC") + 86400 * 0:3
bars <- data.frame(
  instrument_id = "AAA",
  ts_utc = times,
  open = c(100, 90, 45, 46),
  high = c(100, 90, 45, 46),
  low = c(100, 90, 45, 46),
  close = c(100, 90, 45, 46),
  volume = 1000
)
terms <- data.frame(
  fact_id = "example-dividend",
  subtype = "ordinary_cash_dividend",
  parent_instrument_id = "AAA",
  entitlement_time = times[[2]],
  effective_time = times[[4]],
  knowledge_time = times[[1]],
  complete = TRUE,
  provenance_tier = "snapshot_bound",
  gross_cash_per_parent_unit = 1.25,
  gross_cash_validated = TRUE,
  recipient_identity_validated = FALSE,
  recipient_quantity_validated = FALSE,
  source = "vignette-example"
)

store <- tempfile(fileext = ".duckdb")
snapshot <- ledgr_snapshot_from_df(
  bars,
  facts = ledgr_facts(ledgr_facts_equity_corporate_actions(terms)),
  price_basis = "split_adjusted",
  db_path = store
)
opening <- ledgr_opening(
  cash = 1000,
  positions = c(AAA = 2),
  cost_basis = c(AAA = 100)
)
hold <- function(ctx, params) ctx$positions
```

The later halving of the price is deliberately present. The canonical
cash term is already normalized to the sealed snapshot’s unit basis;
ledgr does not reapply a vendor adjustment.

``` r
research <- ledgr_experiment(
  snapshot,
  hold,
  opening = opening,
  corporate_action_policy = ledgr_corporate_actions_research(),
  cost_model = ledgr_cost_zero()
)
research_run <- ledgr_run(research, run_id = "dividend-research")
summary(research_run)
#> ledgr Backtest Summary
#> ======================
#>
#> Execution Evidence:
#>   Fill Timing:         dense_bar_timestamp
#>   Timing Version:      N/A
#>
#>
#> Corporate-Action Evidence:
#> Corporate actions: MODELED - configured settlement conventions were exercised
#> Price basis: split_adjusted
#>   Setting cash_amount:              gross
#>   Identity cash_amount:             ledgr.corporate_action.cash_amount.gross.v001
#>   Setting cash_posting:             effective_close
#>   Identity cash_posting:            ledgr.corporate_action.cash_posting.effective_close.v001
#>   Setting held_terminal_position:   last_permissible
#>   Identity held_terminal_position:  ledgr.corporate_action.held_terminal_position.last_permissible.v001
#>   Setting unsupported_quantity:     report_only
#>   Identity unsupported_quantity:    ledgr.corporate_action.unsupported_quantity.report_only.v001
#>   Exercised choices:
#>     cash_amount.gross: 1
#>     cash_amount.refuse: 0
#>     cash_posting.effective_close: 1
#>     cash_posting.next_open: 0
#>     cash_posting.refuse: 0
#>     held_terminal_position.last_permissible: 0
#>     held_terminal_position.last_mark: 0
#>     held_terminal_position.refuse: 0
#>     unsupported_quantity.report_only: 0
#>     unsupported_quantity.refuse: 0
#>   Refusal reasons:
#>     none declared: 0
#>   Late arrivals:               0
#>   Affected marked exposure:    180
#>   Gross cash posted:           2.5
#>   Modeled terminal proceeds:   0
#>   Positions disposed:          0
#>   Realized model P&L:          0
#>   Unsupported facts:           0
#> Performance Metrics:
#>   Total Return:        -8.79%
#>   Annualized Return:   -99.96%
#>   Max Drawdown:        -8.96%
#>
#> Risk Metrics:
#>   Risk-Free Rate:      0.00% annual
#>   Annualization:       252 periods/year (US equity daily)
#>   Volatility (annual): 65.23%
#>   Sharpe Ratio:        -11.444
#>
#> Trade Statistics:
#>   Closed Trades:       0
#>   Win Rate:            N/A (no trades)
#>   Avg Trade:           N/A (no trades)
#>
#> Exposure:
#>   Time in Market:      100.00%
```

The modeled result reports one `cash_amount.gross` choice, one
`cash_posting.effective_close` choice and gross cash posted of 2.5. It
does not claim a payment date, withholding, investor tax or broker-net
amount.

## Strict Refusal

The strict preset uses the same facts and refuses to model the cash
effect.

``` r
strict <- ledgr_experiment(
  snapshot,
  hold,
  opening = opening,
  corporate_action_policy = ledgr_corporate_actions_strict(),
  cost_model = ledgr_cost_zero()
)
strict_result <- tryCatch(
  ledgr_run(strict, run_id = "dividend-strict"),
  ledgr_corporate_action_unsupported = function(error) {
    paste("Strict policy refused:", conditionMessage(error))
  }
)
strict_result
#> [1] "Strict policy refused: Corporate-action cash settlement is refused by the selected policy."
```
