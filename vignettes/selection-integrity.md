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

## Minimum Track Record Length

### Question

`ledgr_sweep_min_track_record()` asks a narrower single-series question
for each retained candidate: how many return observations would this
observed Sharpe ratio need before it is statistically distinguishable
from a reference Sharpe threshold at the requested confidence level?

The answer is MinTRL. A candidate can have a positive observed Sharpe
and still need more observations before the track record clears the
reference threshold.

### Evidence

The diagnostic consumes the same retained sweep return panel as PBO:

``` r
min_trl <- ledgr_sweep_min_track_record(
  sweep,
  reference_sharpe = 0,
  confidence = 0.95
)
```

The retained `period_return` columns are the evidence. The structural
first `NA_real_` row is verified and dropped by the panel layer before
the per-series Sharpe, skewness, and kurtosis are computed.

### Method Shape

For each candidate, ledgr computes:

1.  per-period excess returns, using `risk_free_return` when supplied;
2.  observed per-period Sharpe ratio;
3.  return skewness and kurtosis;
4.  the Bailey/Lopez de Prado minimum track record length formula
    against `reference_sharpe` and `confidence`.

The output is measured in return observations, not calendar years. If
the observed Sharpe is not above the reference Sharpe, ledgr keeps the
candidate in the table and marks the required length as infinite instead
of silently dropping it.

### Interpretation

Read MinTRL as sample-size evidence. It answers whether the observed
track record is long enough for the selected reference Sharpe threshold.
It does not say the strategy is robust, causal, or deployable.

Use it when a candidate looks promising but short-lived. A large extra
observation count says the apparent Sharpe may mostly be a short-sample
story.

### Limits

MinTRL inherits the quality of the retained return series. It does not
fix candidate mining, leakage, non-stationarity, changing market
regimes, or survivorship-biased universes. It also does not compare many
candidates at once; that broader selection-process question belongs to
PBO and later DSR/effective trial diagnostics.

### Failure Modes

The function fails closed when:

- retained returns were not requested;
- the completed candidates do not form one complete timestamp grid;
- there are fewer than four post-first-row observations;
- a return series is constant or non-finite;
- `reference_sharpe`, `confidence`, or `risk_free_return` is invalid.

These failures mean the evidence cannot support the diagnostic. They are
not strategy judgments.

### References

The MinTRL formula follows the Sharpe-ratio track-record-length
expression used by Bailey and Lopez de Prado and exposed by
PerformanceAnalytics as `MinTrackRecord()`. ledgr implements it
natively; PerformanceAnalytics remains optional reference evidence, not
a runtime dependency.

### Worked Example

The first candidate below has smoother positive returns than the second.
The second candidate’s Sharpe is positive, but the required track record
length shows that the evidence is still much too short at 95 percent
confidence.

``` r
min_trl_returns <- cbind(
  promising = c(0.012, 0.016, 0.010, 0.018, 0.013, 0.017, 0.011, 0.015),
  noisy = c(0.040, -0.030, 0.035, -0.025, 0.030, -0.020, 0.025, -0.015)
)
min_trl_sweep <- make_retained_sweep(min_trl_returns)
min_trl <- ledgr_sweep_min_track_record(min_trl_sweep, reference_sharpe = 0)
min_trl
#> # ledgr sweep minimum track record length
#> # i candidates: 2
#> # i confidence: 0.950
#> # i reference Sharpe: 0.0000
#> 
#> # A tibble: 2 x 7
#>   candidate_id observed_sharpe reference_sharpe min_track_record_length observations
#>   <chr>                  <dbl>            <dbl>                   <dbl>        <int>
#> 1 promising            4.7819                 0                  1.5061            8
#> 2 noisy                0.16667                0                 98.503             8
#> # i 2 more variables: extra_observations_needed <dbl>, track_record_significant <lgl>
```

The diagnostic keeps both candidates in the table. It does not select
the candidate with the shorter required track record.

## Deflated Sharpe Ratio And Effective Trials

### Question

`ledgr_sweep_dsr()` asks whether an observed Sharpe ratio still looks
statistically meaningful after accounting for non-normal returns and the
number of effectively independent candidates tried in the sweep.

The answer is the Deflated Sharpe Ratio (DSR) probability. A high
probability says the candidate Sharpe clears the sweep-level
multiple-testing adjustment under the supplied evidence. It is not a
live-performance guarantee.

### Evidence

DSR consumes the same retained sweep return panel as PBO and MinTRL:

``` r
dsr <- ledgr_sweep_dsr(sweep)
```

When `effective_trials` is not supplied, ledgr derives it with
`ledgr_sweep_cluster()`: deterministic hierarchical clustering over
`1 - correlation` distance on the retained return columns. The
clustering output reports membership and the effective independent trial
count. It does not inspect fills, positions, promotion records, or
walk-forward folds.

### Method Shape

For each candidate, ledgr computes:

1.  per-period excess returns, using `risk_free_return` when supplied;
2.  observed per-period Sharpe ratio;
3.  return skewness and kurtosis;
4.  variance of observed Sharpe ratios across the candidate family;
5.  an expected maximum Sharpe from the effective independent trial
    count;
6.  the Bailey/Lopez de Prado DSR probability.

The effective-trial helper is intentionally narrow in v1: one
deterministic hierarchical method, no RNG, no seed argument, and no
method menu. The method parameters are stored on the result.

### Interpretation

Read DSR as a multiple-testing adjustment for Sharpe evidence. It is
stricter than looking at the best observed Sharpe in the sweep because
it asks how many effectively independent attempts contributed to that
best result.

Use `ledgr_sweep_cluster()` when you want to inspect the effective-trial
count directly:

``` r
clusters <- ledgr_sweep_cluster(sweep)
as_tibble(clusters, what = "membership")
```

Use `as_tibble(dsr)` for the candidate-level DSR table. The
`significant` column is a reporting flag at the requested confidence
level; it is not a promotion rule.

### Limits

DSR depends on the declared candidate family and the retained return
panel. It does not fix leakage in upstream features, data revisions,
survivorship bias, poor candidate design, non-stationarity, or too-short
samples. The clustering count is an effective-trial estimate from return
similarity, not proof of the true research path that produced the
candidates.

DSR is sweep-level in this release. It does not add per-fold train-sweep
DSR to walk-forward degradation tables, and it does not replace PBO or
MinTRL.

### Failure Modes

The functions fail closed when:

- retained returns were not requested;
- the completed candidates do not form one complete timestamp grid;
- there are fewer than two candidates or too few observations;
- a return series is constant or non-finite;
- clustering collapses to fewer than two effective trials for DSR;
- `effective_trials`, `distance_threshold`, `confidence`, or
  `risk_free_return` is invalid.

These failures mean the evidence cannot support the diagnostic. They are
not strategy judgments.

### References

The DSR formula follows the Deflated Sharpe Ratio shape described by
Bailey and Lopez de Prado. ledgr implements it natively over retained
return panels; quantstrat is used only as optional reference evidence in
tests, not as a runtime dependency.

### Worked Example

The synthetic sweep below has four candidates but only two effective
clusters: two candidates are near-duplicates of one return shape, and
two are near-duplicates of another. DSR uses that effective-trial count
instead of treating all four columns as independent discoveries.

``` r
shape_a <- c(-0.020, -0.010, 0.000, 0.010, 0.020, 0.030, 0.010, -0.020, 0.000, 0.020, 0.015, -0.005)
shape_b <- c(0.030, -0.020, 0.025, -0.015, 0.020, -0.010, 0.015, -0.005, 0.010, 0.000, 0.005, -0.005)
dsr_returns <- cbind(
  shape_a = shape_a,
  shape_a_variant = shape_a + c(0.001, -0.001, 0.001, -0.001, 0.001, -0.001, 0.001, -0.001, 0.001, -0.001, 0.001, -0.001),
  shape_b = shape_b,
  shape_b_variant = shape_b + c(-0.001, 0.001, -0.001, 0.001, -0.001, 0.001, -0.001, 0.001, -0.001, 0.001, -0.001, 0.001)
)
dsr_sweep <- make_retained_sweep(dsr_returns)

ledgr_sweep_cluster(dsr_sweep)
#> # ledgr sweep effective-trial clustering
#> # i effective trials: 2
#> # i raw trials: 4
#> # i distance threshold: 0.5000
#> 
#> # A tibble: 4 x 3
#>   candidate_id    cluster_index cluster_id 
#>   <chr>                   <int> <chr>      
#> 1 shape_a                     1 cluster_001
#> 2 shape_a_variant             1 cluster_001
#> 3 shape_b                     2 cluster_002
#> 4 shape_b_variant             2 cluster_002
```

``` r
dsr <- ledgr_sweep_dsr(dsr_sweep)
dsr
#> # ledgr sweep deflated Sharpe ratio
#> # i candidates: 4
#> # i effective trials: 2
#> # i confidence: 0.950
#> 
#> # A tibble: 4 x 6
#>   candidate_id    observed_sharpe expected_max_sharpe dsr_probability p_value significant
#>   <chr>                     <dbl>               <dbl>           <dbl>   <dbl> <lgl>      
#> 1 shape_a                 0.25924           0.0040269         0.79599 0.20401 FALSE      
#> 2 shape_a_variant         0.25869           0.0040269         0.79408 0.20592 FALSE      
#> 3 shape_b                 0.25924           0.0040269         0.80398 0.19602 FALSE      
#> 4 shape_b_variant         0.27454           0.0040269         0.81816 0.18184 FALSE
```

The table is deliberately not a winner picker. It shows how much Sharpe
evidence survives after the effective-trial adjustment, then leaves
selection and promotion outside the diagnostic.

## Where Next

- For retained sweep return panels, read
  `vignette("sweeps", package = "ledgr")`.
- For walk-forward train/test evidence, read
  `vignette("walk-forward", package = "ledgr")`.
- For lookahead leakage examples, read
  `vignette("leakage", package = "ledgr")`.
