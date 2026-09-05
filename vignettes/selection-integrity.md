# Selection Integrity


Comparing many strategy variants is useful, and it is a trap. A sweep
can produce a convincing winner because one candidate happened to fit
the slices of history you inspected. The selection-integrity diagnostics
in ledgr make that trap visible from candidate return evidence; they do
not choose the winner, promote a candidate, or prove future
profitability.

This article teaches the shipped diagnostics as one method family:
Probability of Backtest Overfitting (PBO/CSCV), Minimum Track Record
Length (MinTRL), K-Ratio path consistency, and Deflated Sharpe Ratio
(DSR) with deterministic effective-trial clustering.

## Candidate Returns Are The Evidence

Each diagnostic starts from the same object: a candidate return panel.
The direct path is a small return table with one row per period and one
column per candidate:

``` r
rotating_returns <- data.frame(
  early = c(0.05, 0.05, 0.05, -0.01, -0.01, -0.01, -0.01, -0.01, -0.01, -0.01, -0.01, -0.01),
  middle = c(-0.01, -0.01, -0.01, 0.05, 0.05, 0.05, -0.01, -0.01, -0.01, -0.01, -0.01, -0.01),
  late = c(-0.01, -0.01, -0.01, -0.01, -0.01, -0.01, 0.05, 0.05, 0.05, -0.01, -0.01, -0.01),
  steady = rep(0.012, 12)
)
rotating_returns
#>    early middle  late steady
#> 1   0.05  -0.01 -0.01  0.012
#> 2   0.05  -0.01 -0.01  0.012
#> 3   0.05  -0.01 -0.01  0.012
#> 4  -0.01   0.05 -0.01  0.012
#> 5  -0.01   0.05 -0.01  0.012
#> 6  -0.01   0.05 -0.01  0.012
#> 7  -0.01  -0.01  0.05  0.012
#> 8  -0.01  -0.01  0.05  0.012
#> 9  -0.01  -0.01  0.05  0.012
#> 10 -0.01  -0.01 -0.01  0.012
#> 11 -0.01  -0.01 -0.01  0.012
#> 12 -0.01  -0.01 -0.01  0.012
```

Wrap that evidence once, then reuse the panel across diagnostics:

``` r
rotating_panel <- ledgr_return_panel(rotating_returns)
```

The values are clean period returns. There is no leading structural `NA`
row in user input. If you omit timestamps, ledgr assigns deterministic
ordering labels such as `period_000001`; if your returns are dated, pass
`Date` or `POSIXct` labels through `ts`.

A retained sweep can produce the same evidence object:

``` r
sweep <- ledgr_sweep(
  experiment,
  grid,
  retain = ledgr_sweep_retention("completed")
)

panel <- ledgr_sweep_returns_panel(sweep)
```

For the full retained-sweep contract, see
`vignette("sweeps", package = "ledgr")`.

The diagnostic contract is intentionally narrow: pass a return panel or
a retained sweep. Raw matrices and data frames are wrapped with
`ledgr_return_panel()` first, so validation happens once and the same
`panel_hash` follows the evidence.

## Probability Of Backtest Overfitting

A parameter search can look persuasive when every time segment has a
different winner. If the chosen in-sample winner repeatedly disappoints
out of sample, the search process is telling you more about overfitting
than about a durable edge.

### Question

How often does the in-sample winner rank poorly out of sample when the
same candidate-return panel is recombined into symmetric train/test
splits?

`ledgr_pbo()` reports that frequency as PBO. Larger values are warnings
about the candidate family and the selection process. Smaller values are
reassuring only about this evidence and this recombination scheme.

### Evidence

PBO consumes the validated period-return matrix in the return panel. It
does not inspect fills, positions, promotion records, walk-forward
folds, or strategy source code.

The example compares the rotating panel above with a stable-ranking
panel where the same candidate leads every segment:

``` r
stable_returns <- data.frame(
  candidate_1 = rep(0.012, 12),
  candidate_2 = rep(0.009, 12),
  candidate_3 = rep(0.006, 12),
  candidate_4 = rep(0.003, 12)
)
stable_returns
#>    candidate_1 candidate_2 candidate_3 candidate_4
#> 1        0.012       0.009       0.006       0.003
#> 2        0.012       0.009       0.006       0.003
#> 3        0.012       0.009       0.006       0.003
#> 4        0.012       0.009       0.006       0.003
#> 5        0.012       0.009       0.006       0.003
#> 6        0.012       0.009       0.006       0.003
#> 7        0.012       0.009       0.006       0.003
#> 8        0.012       0.009       0.006       0.003
#> 9        0.012       0.009       0.006       0.003
#> 10       0.012       0.009       0.006       0.003
#> 11       0.012       0.009       0.006       0.003
#> 12       0.012       0.009       0.006       0.003
```

### Method Shape

Combinatorially Symmetric Cross Validation (CSCV) gives PBO its shape:

1.  Split the return panel into `S` contiguous subsets.
2.  Treat half the subsets as in sample and the rest as out of sample.
3.  Score every candidate in sample.
4.  Carry the in-sample winner into the out-of-sample side.
5.  Rank that same candidate out of sample.
6.  Count how often the out-of-sample rank implies
    `lambda <= threshold`.

ledgr uses mean period return as the default score. A custom metric can
be supplied, but it must return one finite numeric value per candidate
column, with larger values treated as better.

### Interpretation

Read PBO as a diagnostic of the search, not as a verdict on one
candidate. A high value is a reason to distrust the apparent sweep
winner, narrow the search space, add walk-forward evidence, or demand a
stronger economic explanation.

The result keeps a summary table, a case table, and a degradation table.
The degradation table is often the most useful teaching surface because
it shows which in-sample winner lost rank out of sample.

### Limits

PBO does not fix bad data, survivorship bias, point-in-time universe
mistakes, revised-data leakage, or preprocessing that used future
information before ledgr saw the inputs. It also depends on a meaningful
candidate family. A panel of already-mined finalists understates the
search that actually happened.

### Failure Modes

The diagnostic fails closed when the panel has too few candidates, too
few observations, non-finite returns, an invalid `S`, or a metric that
does not return one finite score per candidate.

### References

This diagnostic follows the CSCV/PBO convention described by Bailey,
Borwein, Lopez de Prado, and Zhu in their Probability of Backtest
Overfitting paper. ledgr implements the diagnostic natively; the CRAN
`pbo` package is used only as optional reference evidence in tests, not
as a runtime dependency.

### Worked Example

``` r
stable_panel <- ledgr_return_panel(stable_returns)

pbo_rotating <- ledgr_pbo(rotating_panel, S = 4)
pbo_stable <- ledgr_pbo(stable_panel, S = 4)

pbo_summary <- tibble::tibble(
  scenario = c("rotating winner", "stable ranking"),
  pbo = c(
    tibble::as_tibble(pbo_rotating)$pbo,
    tibble::as_tibble(pbo_stable)$pbo
  )
)

knitr::kable(pbo_summary)
```

| scenario        | pbo |
|:----------------|----:|
| rotating winner |   1 |
| stable ranking  |   0 |

``` r
tibble::as_tibble(pbo_rotating, what = "degradation")[
  ,
  c("case", "winner_candidate_id", "oos_best_candidate_id", "lambda", "below_threshold")
] |>
  transform(lambda = round(lambda, 3)) |>
  knitr::kable()
```

| case | winner_candidate_id | oos_best_candidate_id | lambda | below_threshold |
|-----:|:--------------------|:----------------------|-------:|:----------------|
|    1 | early               | late                  | -0.511 | TRUE            |
|    2 | early               | middle                | -0.511 | TRUE            |
|    3 | early               | middle                | -1.099 | TRUE            |
|    4 | middle              | early                 | -0.511 | TRUE            |
|    5 | middle              | early                 | -1.099 | TRUE            |
|    6 | late                | early                 | -1.099 | TRUE            |

The rotating panel produces a high PBO because the in-sample winner is
usually not the out-of-sample winner. The stable panel produces a low
PBO because the candidate order survives the recombination. The `steady`
column is a useful warning: it has the highest full-sample mean in the
rotating panel, but it never wins the symmetric in-sample contests shown
above.

## Minimum Track Record Length

A positive Sharpe ratio can still be too short to trust. MinTRL asks how
much return history would be needed before an observed Sharpe clears a
reference Sharpe threshold at the requested confidence level.

### Question

For each candidate, how many period-return observations are needed
before the observed Sharpe is statistically distinguishable from the
reference Sharpe?

### Evidence

MinTRL consumes each candidate column in the same return panel contract.
The reference Sharpe and risk-free return are in the same per-period
units as the input returns; passing an annualized threshold against
period returns will make the evidence look weaker than intended.

### Method Shape

For each candidate, ledgr computes per-period excess returns, observed
Sharpe, skewness and kurtosis, and the Bailey/Lopez de Prado minimum
track record length convention. The output is measured in return
observations, not calendar years.

When an observed Sharpe is not above the reference, ledgr keeps the
candidate in the table with an infinite required length and a status
explaining the result.

### Interpretation

Read MinTRL as sample-size evidence. A short track record can have
attractive returns and still need many more observations before it
clears the threshold. The diagnostic does not say the strategy is
robust, causal, or deployable.

### Limits

MinTRL is a single-series diagnostic. It does not adjust for how many
candidates were tried, and it does not discover leakage, regime changes,
or a flawed candidate-generation process.

### Failure Modes

The diagnostic fails closed when the panel has too few observations,
constant or non-finite returns, or invalid `reference_sharpe`,
`confidence`, or `risk_free_return` values.

### References

The computation follows the Sharpe-ratio track-record-length expression
used by Bailey and Lopez de Prado and the
`PerformanceAnalytics::MinTrackRecord()` convention. ledgr implements it
natively; PerformanceAnalytics remains optional reference evidence.

### Worked Example

The same choppy return pattern can tell two different stories depending
on how long it has persisted:

``` r
short_pattern <- c(0.015, -0.010, 0.012, -0.006, 0.014, -0.008, 0.011, -0.004)
short_returns <- data.frame(
  candidate = short_pattern,
  comparison = rev(short_pattern)
)
longer_returns <- do.call(rbind, rep(list(short_returns), 8))

head(short_returns, 4)
#>   candidate comparison
#> 1     0.015     -0.004
#> 2    -0.010      0.011
#> 3     0.012     -0.008
#> 4    -0.006      0.014
head(longer_returns, 4)
#>   candidate comparison
#> 1     0.015     -0.004
#> 2    -0.010      0.011
#> 3     0.012     -0.008
#> 4    -0.006      0.014
```

``` r
min_trl_short <- ledgr_min_track_record(
  ledgr_return_panel(short_returns),
  reference_sharpe = 0
)
min_trl_longer <- ledgr_min_track_record(
  ledgr_return_panel(longer_returns),
  reference_sharpe = 0
)

short_row <- tibble::as_tibble(min_trl_short)[1, ]
longer_row <- tibble::as_tibble(min_trl_longer)[1, ]

min_trl_table <- tibble::tibble(
  scenario = c("short sample", "longer same pattern"),
  observations = c(short_row$observations, longer_row$observations),
  observed_sharpe = round(c(short_row$observed_sharpe, longer_row$observed_sharpe), 3),
  min_track_record_length = round(
    c(short_row$min_track_record_length, longer_row$min_track_record_length),
    1
  ),
  extra_needed = c(
    short_row$extra_observations_needed,
    longer_row$extra_observations_needed
  ),
  status = c(short_row$status, longer_row$status)
)

knitr::kable(min_trl_table)
```

| scenario | observations | observed_sharpe | min_track_record_length | extra_needed | status |
|:---|---:|---:|---:|---:|:---|
| short sample | 8 | 0.276 | 37.1 | 30 | needs_more_observations |
| longer same pattern | 64 | 0.292 | 33.1 | 0 | significant |

The longer sample clears the required track length; the short sample
does not. That is evidence about track-record sufficiency, not a
deployment decision.

## K-Ratio Path Consistency

Two strategies can finish with similar returns while taking very
different paths. K-Ratio asks whether cumulative performance advances
along a stable trend or arrives through an erratic sequence that makes
the fitted trend uncertain.

### Question

How strong is the fitted growth trend relative to the uncertainty in its
slope, after adjusting for sample length and observation frequency?

### Evidence

K-Ratio consumes each candidate’s ordered period returns. ledgr
compounds per-period excess returns into cumulative log wealth before
fitting the trend. The caller supplies `periods_per_year` explicitly;
ledgr does not infer it from timestamps or undated period labels.

### Method Shape

`ledgr_k_ratio()` implements the compounded-return Kestner 2013 variant:

1.  Subtract the per-period risk-free return.
2.  Compound the excess returns and express the path as cumulative log
    wealth.
3.  Fit an ordinary least-squares trend over the retained observation
    index.
4.  Divide the slope by its standard error to obtain the raw K-Ratio.
5.  Scale by the square root of `periods_per_year` and divide by the
    number of observations.

The 1996, 2003, and Zephyr variants use different scaling and are not
computed by this function.

### Interpretation

Larger positive values indicate a more consistently rising path under
this specific convention. Negative values indicate a declining fitted
path. Compare values only when the evidence uses compatible frequencies
and the same `periods_per_year` convention.

### Limits

K-Ratio penalizes deviations on both sides of the fitted trend. It does
not separate welcome upside variation from drawdowns, establish
causality, correct selection bias, or prove that a strategy is robust or
will remain profitable. It is independent of the future
`positive_trajectory` criterion, which is a separate eligibility test
rather than this diagnostic.

### Failure Modes

The diagnostic fails closed when fewer than three observations are
available, returns or arguments are non-finite, an excess return is at
or below `-1`, or the cumulative log-wealth path has a zero or
non-finite slope standard error.

### References

The implementation follows Lars Kestner’s 2013 paper, *(Re)Introducing
the K-Ratio*, DOI 10.2139/ssrn.2230949. That paper names the
sample-length and periodicity adjustments explicitly. ledgr fixes the
compounded-return variant and leaves other published K-Ratio variants
outside this function.

### Worked Example

The first path grows with moderate variation. The second alternates
large gains and losses and ends slightly down:

``` r
k_ratio_returns <- data.frame(
  smooth_growth = c(
    0.015, -0.002, 0.012, 0.004, 0.011, 0.003,
    0.013, 0.005, 0.010, 0.004, 0.012, 0.006
  ),
  noisy_flat = c(
    0.080, -0.075, 0.060, -0.065, 0.050, -0.055,
    0.040, -0.045, 0.030, -0.035, 0.020, -0.025
  )
)

k_ratio_result <- ledgr_k_ratio(
  ledgr_return_panel(k_ratio_returns),
  periods_per_year = 252
)
k_ratio_rows <- tibble::as_tibble(k_ratio_result)

k_ratio_table <- tibble::tibble(
  scenario = c("smooth growth", "noisy flat"),
  observations = k_ratio_rows$observations,
  cumulative_log_return = round(k_ratio_rows$cumulative_log_return, 3),
  k_ratio = round(k_ratio_rows$k_ratio, 3)
)

knitr::kable(k_ratio_table)
```

| scenario      | observations | cumulative_log_return | k_ratio |
|:--------------|-------------:|----------------------:|--------:|
| smooth growth |           12 |                 0.092 |  40.272 |
| noisy flat    |           12 |                -0.036 |  -4.224 |

The smoother rising path has the larger K-Ratio. That contrast is
path-quality evidence under one pinned definition, not a ranking or
promotion instruction.

## Deflated Sharpe Ratio And Effective Trials

A high Sharpe is less surprising after a large search. DSR asks whether
the observed Sharpe still clears a multiple-testing adjustment after
accounting for non-normal returns and the number of effectively
independent candidates.

### Question

For each candidate, how much Sharpe evidence remains after ledgr
accounts for the effective number of independent trials in the candidate
family?

The answer is the DSR probability. The related effective-trial count is
estimated from return similarity when you do not supply it explicitly.

### Evidence

DSR consumes the same return panel as PBO and MinTRL. The
effective-trial helper uses deterministic hierarchical clustering over
`1 - correlation` distance on the candidate return columns. It does not
use random starts, a seed argument, or a method menu.

### Method Shape

For each candidate, ledgr computes per-period excess returns, observed
Sharpe, skewness and kurtosis, a family-level expected maximum Sharpe,
and the DSR probability. If `effective_trials` is omitted,
`ledgr_effective_trials()` derives a deterministic count from the return
panel.

### Interpretation

Read DSR as a multiple-testing adjustment for Sharpe evidence. It is
stricter than looking at the best Sharpe in the table because it asks
how many effectively independent attempts contributed to that result.
The `significant` column is a reporting flag at the requested confidence
level, not a promotion rule.

### Limits

DSR does not replace PBO or MinTRL. It does not prove a strategy will
make money, and the clustering estimate is not proof of the true
research path that created the candidates.

### Failure Modes

The DSR family fails closed when the panel has too few candidates, too
few observations, constant or non-finite returns, an invalid
effective-trial count, or a clustering result that collapses to fewer
than two effective trials.

### References

The DSR follows the Deflated Sharpe Ratio convention in Bailey and Lopez
de Prado, with clustering used only to estimate the effective number of
trials. The optional quantstrat cross-check is test evidence, not a
runtime dependency.

### Worked Example

This panel has eight candidates, but they fall into two highly similar
return families:

``` r
shape_a <- c(-0.020, -0.010, 0.000, 0.010, 0.020, 0.030, 0.010, -0.020, 0.000, 0.020, 0.015, -0.005)
shape_b <- c(0.030, -0.020, 0.025, -0.015, 0.020, -0.010, 0.015, -0.005, 0.010, 0.000, 0.005, -0.005)
dsr_returns <- do.call(
  cbind,
  c(
    lapply(1:4, function(i) shape_a + rep(c(0.001 * i, -0.001 * i), 6)),
    lapply(1:4, function(i) shape_b + rep(c(-0.001 * i, 0.001 * i), 6))
  )
)
colnames(dsr_returns) <- c(paste0("shape_a_", 1:4), paste0("shape_b_", 1:4))
dsr_panel <- ledgr_return_panel(dsr_returns)

head(as.data.frame(dsr_returns), 4)
#>   shape_a_1 shape_a_2 shape_a_3 shape_a_4 shape_b_1 shape_b_2 shape_b_3 shape_b_4
#> 1    -0.019    -0.018    -0.017    -0.016     0.029     0.028     0.027     0.026
#> 2    -0.011    -0.012    -0.013    -0.014    -0.019    -0.018    -0.017    -0.016
#> 3     0.001     0.002     0.003     0.004     0.024     0.023     0.022     0.021
#> 4     0.009     0.008     0.007     0.006    -0.014    -0.013    -0.012    -0.011
```

``` r
effective <- ledgr_effective_trials(dsr_panel, distance_threshold = 0.15)
effective_summary <- tibble::as_tibble(effective)

knitr::kable(tibble::tibble(
  statistic = c("effective trials", "raw trials"),
  value = c(effective_summary$effective_trials, effective_summary$raw_trials)
))
```

| statistic        | value |
|:-----------------|------:|
| effective trials |     2 |
| raw trials       |     8 |

``` r
knitr::kable(effective$membership)
```

| candidate_id | cluster_index | cluster_id  |
|:-------------|--------------:|:------------|
| shape_a_1    |             1 | cluster_001 |
| shape_a_2    |             1 | cluster_001 |
| shape_a_3    |             1 | cluster_001 |
| shape_a_4    |             1 | cluster_001 |
| shape_b_1    |             2 | cluster_002 |
| shape_b_2    |             2 | cluster_002 |
| shape_b_3    |             2 | cluster_002 |
| shape_b_4    |             2 | cluster_002 |

``` r
dsr <- ledgr_dsr(dsr_panel, distance_threshold = 0.15)
dsr_table <- tibble::as_tibble(dsr)[
  ,
  c("candidate_id", "observed_sharpe", "dsr_probability", "significant")
]
dsr_table$observed_sharpe <- round(dsr_table$observed_sharpe, 3)
dsr_table$dsr_probability <- round(dsr_table$dsr_probability, 3)

knitr::kable(dsr_table)
```

| candidate_id | observed_sharpe | dsr_probability | significant |
|:-------------|----------------:|----------------:|:------------|
| shape_a_1    |           0.259 |           0.784 | FALSE       |
| shape_a_2    |           0.257 |           0.781 | FALSE       |
| shape_a_3    |           0.254 |           0.777 | FALSE       |
| shape_a_4    |           0.251 |           0.773 | FALSE       |
| shape_b_1    |           0.275 |           0.808 | FALSE       |
| shape_b_2    |           0.291 |           0.823 | FALSE       |
| shape_b_3    |           0.310 |           0.839 | FALSE       |
| shape_b_4    |           0.330 |           0.856 | FALSE       |

``` r
two_effective_trials <- tibble::as_tibble(
  ledgr_dsr(dsr_panel, effective_trials = 2)
)
eight_effective_trials <- tibble::as_tibble(
  ledgr_dsr(dsr_panel, effective_trials = 8)
)

dsr_contrast <- tibble::tibble(
  assumption = c("clustered candidates", "treat all columns as independent"),
  effective_trials = c(2L, 8L),
  first_candidate_dsr = round(
    c(
      two_effective_trials$dsr_probability[1],
      eight_effective_trials$dsr_probability[1]
    ),
    3
  )
)

knitr::kable(dsr_contrast)
```

| assumption                       | effective_trials | first_candidate_dsr |
|:---------------------------------|-----------------:|--------------------:|
| clustered candidates             |                2 |               0.784 |
| treat all columns as independent |                8 |               0.757 |

The DSR value drops as the effective-trial assumption gets larger. That
is the point of the diagnostic: it makes the cost of searching visible
without turning the table into a winner picker.

## Where Next

- For retained sweep return panels, read
  `vignette("sweeps", package = "ledgr")`.
- For walk-forward train/test evidence, read
  `vignette("walk-forward", package = "ledgr")`.
- For lookahead leakage examples, read
  `vignette("leakage", package = "ledgr")`.
