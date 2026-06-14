# Selection Integrity


Sweeps let you compare many candidate parameterizations. That is useful,
and it is dangerous. The more candidates you inspect, the easier it is
to mistake a lucky in-sample winner for a robust strategy.
Selection-integrity diagnostics make that risk visible; they do not
choose the winner for you.

## Question

`ledgr_sweep_pbo()` asks one question: when the retained candidate
return panel is recombined into symmetric in-sample and out-of-sample
splits, how often does the in-sample winner rank poorly out of sample?

The answer is the Probability of Backtest Overfitting (PBO). Higher
values are warning signs about the candidate family and the selection
process. They are not proof that a strategy will lose money, and low
values are not proof that a strategy will make money.

## Evidence

The diagnostic consumes retained sweep returns:

``` r
sweep <- ledgr_sweep(
  experiment,
  grid,
  retain = ledgr_sweep_retention("completed")
)

pbo <- ledgr_sweep_pbo(sweep, S = 4)
```

The input is the same retained completed-candidate evidence exposed by
`ledgr_sweep_returns_panel()`: one UTC-ordered return column per
completed candidate, with the structural first `NA_real_` row verified
and dropped before the CSCV matrix is formed. It does not inspect fills,
positions, promotion records, or walk-forward folds.

## Method Shape

PBO uses Combinatorially Symmetric Cross Validation (CSCV):

1.  Split the return panel into `S` contiguous subsets.
2.  Choose half the subsets as in sample and the other half as out of
    sample.
3.  Score every candidate in sample.
4.  Take the in-sample winner and rank that same candidate out of
    sample.
5.  Convert the out-of-sample rank to `lambda`.
6.  Report PBO as the share of cases where `lambda <= threshold`.

The default score is mean period return. A custom metric can be
supplied, but it must return one finite numeric value per candidate
column, and larger values are treated as better.

## Interpretation

Read PBO as selection-process evidence. A high value says the candidate
that looks best in sample often fails to hold its rank out of sample
under CSCV recombination. That is a reason to distrust the apparent
sweep winner, reduce the candidate search space, gather more evidence,
or add a separate walk-forward evaluation.

The result object keeps three public tables:

- `as_tibble(pbo)` gives the one-row summary.
- `as_tibble(pbo, what = "cases")` gives each CSCV split and logit.
- `as_tibble(pbo, what = "degradation")` gives the winner in-sample
  versus out-of-sample score by split.

## Limits

PBO is not a profitability proof. It does not fix bad data, survivorship
bias, point-in-time universe mistakes, revised-data leakage, or
preprocessing that used future information before ledgr saw the inputs.
It also depends on a meaningful candidate family. If the sweep has too
few candidates, too few observations, or candidates that were already
mined before the declared sweep, interpretation weakens.

PBO is sweep-level in this release. It does not add per-fold train-sweep
PBO to walk-forward degradation tables.

## Failure Modes

The function fails closed when the evidence is not suitable:

- retained returns were not requested;
- a selected candidate failed or has no retained return rows;
- the completed candidates do not form one complete timestamp grid;
- the structural first return row is not `NA_real_`;
- `S` is odd, too large, or does not divide the post-first-row return
  count;
- the metric does not return one finite numeric score per candidate.

These are setup or evidence problems, not weak strategy results. Fix the
panel before interpreting the diagnostic.

## References

The method follows the CSCV/PBO shape described by Bailey, Borwein,
Lopez de Prado, and Zhu. ledgr implements the diagnostic natively over
retained return panels; the CRAN `pbo` package remains optional
reference evidence, not a runtime dependency.

## Worked Example

The synthetic retained sweep below is intentionally cautionary. Each
candidate looks good in one segment and weak elsewhere. That creates an
attractive-looking search space, but PBO flags that the in-sample winner
does not usually remain strong out of sample.

``` r
pbo <- ledgr_sweep_pbo(example_sweep, S = 4)
tibble::as_tibble(pbo)
#> # A tibble: 1 x 17
#>   diagnostic schema_version sweep_id    pbo probability_not_over~1 threshold     S n_cases
#>   <chr>               <int> <chr>     <dbl>                  <dbl>     <dbl> <int>   <int>
#> 1 pbo_cscv                1 selectio~     1                      0         0     4       6
#> # i abbreviated name: 1: probability_not_overfit
#> # i 9 more variables: n_observations <int>, n_candidates <int>, metric_name <chr>,
#> #   value <chr>, first_row_dropped <lgl>, complete_panel <lgl>, candidate_ids <list>,
#> #   completed_candidate_ids <list>, excluded_candidate_ids <list>
```

The case table shows why the summary is high: the in-sample winner is
often not the out-of-sample winner.

``` r
tibble::as_tibble(pbo, what = "degradation")
#> # A tibble: 6 x 8
#>    case winner_candidate_id oos_best_candidate_id in_sample_metric out_of_sample_metric
#>   <int> <chr>               <chr>                            <dbl>                <dbl>
#> 1     1 candidate_1         candidate_3                       0.02                -0.01
#> 2     2 candidate_1         candidate_2                       0.02                -0.01
#> 3     3 candidate_1         candidate_2                       0.02                -0.01
#> 4     4 candidate_2         candidate_1                       0.02                -0.01
#> 5     5 candidate_2         candidate_1                       0.02                -0.01
#> 6     6 candidate_3         candidate_1                       0.02                -0.01
#> # i 3 more variables: metric_degradation <dbl>, lambda <dbl>, below_threshold <lgl>
```

`ledgr_sweep_pbo()` does not select or promote a candidate. Treat it as
one piece of evidence beside the sweep table, the walk-forward
degradation table, and the research judgment that decides what to test
next.

## Where Next

- For retained sweep return panels, read
  `vignette("sweeps", package = "ledgr")`.
- For walk-forward train/test evidence, read
  `vignette("walk-forward", package = "ledgr")`.
- For lookahead leakage examples, read
  `vignette("leakage", package = "ledgr")`.
