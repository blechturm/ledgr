# Selection Integrity


Sweeps let you compare many candidate parameterizations. That is useful,
and it is dangerous. The more candidates you inspect, the easier it is
to mistake a lucky in-sample winner for a robust strategy.
Selection-integrity diagnostics make that risk visible; they do not
choose the winner for you.

This article groups the shipped v0.1.9.6 diagnostics as one method
family: PBO/CSCV, minimum track record length, and DSR with
effective-trial clustering.

## Question

`ledgr_pbo()` asks one question: when the retained candidate
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

pbo <- ledgr_pbo(sweep, S = 4)
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

The retained sweeps below are intentionally small, but the contrast is a
real research situation: a parameter search where each setting wins in a
different market segment versus a search where the candidate ranking is
stable across segments. The first can look attractive if you inspect
only the best in-sample candidate; PBO flags the rotation.

``` r
pbo_segment_means <- do.call(
  rbind,
  lapply(
    list("rotating winner" = overfit_returns, "stable ranking" = stable_returns),
    function(returns) {
      out <- expand.grid(
        segment = seq_len(4),
        candidate = colnames(returns),
        KEEP.OUT.ATTRS = FALSE,
        stringsAsFactors = FALSE
      )
      out$mean_return <- mapply(
        function(segment, candidate) {
          mean(returns[subset_id == segment, candidate])
        },
        out$segment,
        out$candidate
      )
      out
    }
  )
)
pbo_segment_means$scenario <- rep(
  names(list("rotating winner" = overfit_returns, "stable ranking" = stable_returns)),
  each = 16
)
pbo_segment_means$candidate <- factor(
  pbo_segment_means$candidate,
  levels = rev(colnames(overfit_returns))
)

ggplot2::ggplot(
  pbo_segment_means,
  ggplot2::aes(x = factor(segment), y = candidate, fill = mean_return)
) +
  ggplot2::geom_tile(color = "white", linewidth = 0.6) +
  ggplot2::facet_wrap(~ scenario) +
  ggplot2::scale_fill_viridis_c(option = "C") +
  ggplot2::labs(
    x = "Segment",
    y = "Candidate",
    fill = "Mean return"
  ) +
  ggplot2::theme_minimal(base_size = 13)
```

<img
src="selection-integrity_files/figure-commonmark/pbo-segment-heatmap-1.png"
data-fig-alt="Heatmap with a bright diagonal for the rotating-winner scenario and horizontal bands for the stable-ranking scenario."
alt="Rotating winner rotates out of sample (high PBO) vs one candidate leads every segment (low PBO)." />

``` r
pbo_overfit <- ledgr_pbo(overfit_sweep, S = 4)
pbo_stable <- ledgr_pbo(stable_sweep, S = 4)
tibble::tibble(
  scenario = c("rotating winner", "stable ranking"),
  pbo = c(
    tibble::as_tibble(pbo_overfit)$pbo,
    tibble::as_tibble(pbo_stable)$pbo
  )
)
#> # A tibble: 2 x 2
#>   scenario          pbo
#>   <chr>           <dbl>
#> 1 rotating winner     1
#> 2 stable ranking      0
```

The degradation table for the rotating-winner sweep shows why the PBO
summary is high: the in-sample winner is often not the out-of-sample
winner.

``` r
tibble::as_tibble(pbo_overfit, what = "degradation")
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

`ledgr_pbo()` does not select or promote a candidate. Treat it as
one piece of evidence beside the sweep table, the walk-forward
degradation table, and the research judgment that decides what to test
next.

## Minimum Track Record Length

### Question

`ledgr_min_track_record()` asks a narrower single-series question
for each retained candidate: how many return observations would this
observed Sharpe ratio need before it is statistically distinguishable
from a reference Sharpe threshold at the requested confidence level?

The answer is MinTRL. A candidate can have a positive observed Sharpe
and still need more observations before the track record clears the
reference threshold.

### Evidence

The diagnostic consumes the same retained sweep return panel as PBO:

``` r
min_trl <- ledgr_min_track_record(
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

The contrast below uses the same choppy positive return pattern twice:
once as a short sample and once as a longer sample. The average return
story is similar, but MinTRL changes the interpretation because the
longer track record carries more evidence.

``` r
short_pattern <- c(0.015, -0.010, 0.012, -0.006, 0.014, -0.008, 0.011, -0.004)
short_sample <- cbind(
  candidate = short_pattern,
  peer = rev(short_pattern)
)
longer_sample <- do.call(rbind, rep(list(short_sample), 8))

min_trl_short <- ledgr_min_track_record(
  make_retained_sweep(short_sample),
  reference_sharpe = 0
)
min_trl_longer <- ledgr_min_track_record(
  make_retained_sweep(longer_sample),
  reference_sharpe = 0
)

short_row <- tibble::as_tibble(min_trl_short)[1, ]
longer_row <- tibble::as_tibble(min_trl_longer)[1, ]
tibble::tibble(
  scenario = c("short sample", "longer same pattern"),
  observations = c(short_row$observations, longer_row$observations),
  observed_sharpe = round(c(short_row$observed_sharpe, longer_row$observed_sharpe), 3),
  min_track_record_length = round(
    c(short_row$min_track_record_length, longer_row$min_track_record_length),
    1
  ),
  extra_observations_needed = c(
    short_row$extra_observations_needed,
    longer_row$extra_observations_needed
  ),
  status = c(short_row$status, longer_row$status)
)
#> # A tibble: 2 x 6
#>   scenario      observations observed_sharpe min_track_record_len~1 extra_observations_n~2
#>   <chr>                <int>           <dbl>                  <dbl>                  <dbl>
#> 1 short sample             8           0.276                   37.1                     30
#> 2 longer same ~           64           0.292                   33.1                      0
#> # i abbreviated names: 1: min_track_record_length, 2: extra_observations_needed
#> # i 1 more variable: status <chr>
```

``` r
min_trl_gap <- tibble::tibble(
  scenario = c("short sample", "longer same pattern"),
  observations = c(short_row$observations, longer_row$observations),
  required = c(short_row$min_track_record_length, longer_row$min_track_record_length)
)

ggplot2::ggplot(min_trl_gap, ggplot2::aes(x = scenario)) +
  ggplot2::geom_col(
    ggplot2::aes(y = observations),
    fill = "#4F7FC8",
    width = 0.62
  ) +
  ggplot2::geom_point(
    ggplot2::aes(y = required),
    color = "#B2182B",
    size = 3.5
  ) +
  ggplot2::geom_text(
    ggplot2::aes(y = observations, label = paste0("available: ", observations)),
    vjust = -0.55,
    size = 3.5
  ) +
  ggplot2::geom_text(
    ggplot2::aes(y = required, label = paste0("required: ", round(required, 1))),
    vjust = 1.6,
    color = "#B2182B",
    size = 3.5
  ) +
  ggplot2::labs(
    x = NULL,
    y = "Return observations"
  ) +
  ggplot2::theme_minimal(base_size = 13)
```

<img
src="selection-integrity_files/figure-commonmark/min-trl-gap-plot-1.png"
data-fig-alt="Bar chart comparing available observations with required MinTRL for the short and longer samples."
alt="The short sample has less evidence than its required MinTRL; the longer same-pattern sample clears it." />

The diagnostic keeps both candidates in the underlying table. It does
not select the candidate or convert a longer sample into a deployment
decision.

## Deflated Sharpe Ratio And Effective Trials

### Question

`ledgr_dsr()` asks whether an observed Sharpe ratio still looks
statistically meaningful after accounting for non-normal returns and the
number of effectively independent candidates tried in the sweep.

The answer is the Deflated Sharpe Ratio (DSR) probability. A high
probability says the candidate Sharpe clears the sweep-level
multiple-testing adjustment under the supplied evidence. It is not a
live-performance guarantee.

### Evidence

DSR consumes the same retained sweep return panel as PBO and MinTRL:

``` r
dsr <- ledgr_dsr(sweep)
```

When `effective_trials` is not supplied, ledgr derives it with
`ledgr_effective_trials()`: deterministic hierarchical clustering over
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

Use `ledgr_effective_trials()` when you want to inspect the effective-trial
count directly:

``` r
clusters <- ledgr_effective_trials(sweep)
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

The sweep below has eight candidates but only two effective clusters:
four parameter settings are near-duplicates of one return shape, and
four are near-duplicates of another. The contrast shows why DSR cares
about effective trials rather than raw column count.

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
dsr_sweep <- make_retained_sweep(dsr_returns)

ledgr_effective_trials(dsr_sweep)
#> # ledgr effective-trial clustering
#> # i effective trials: 2
#> # i raw trials: 8
#> # i distance threshold: 0.5000
#>
#> # A tibble: 8 x 3
#>   candidate_id cluster_index cluster_id
#>   <chr>                <int> <chr>
#> 1 shape_a_1                1 cluster_001
#> 2 shape_a_2                1 cluster_001
#> 3 shape_a_3                1 cluster_001
#> 4 shape_a_4                1 cluster_001
#> 5 shape_b_1                2 cluster_002
#> 6 shape_b_2                2 cluster_002
#> 7 shape_b_3                2 cluster_002
#> 8 shape_b_4                2 cluster_002
```

``` r
dsr_correlation <- cor(dsr_returns)
candidate_order <- colnames(dsr_correlation)
dsr_correlation_long <- expand.grid(
  candidate_x = candidate_order,
  candidate_y = candidate_order,
  KEEP.OUT.ATTRS = FALSE,
  stringsAsFactors = FALSE
)
dsr_correlation_long$correlation <- as.vector(dsr_correlation)
dsr_correlation_long$candidate_x <- factor(
  dsr_correlation_long$candidate_x,
  levels = candidate_order
)
dsr_correlation_long$candidate_y <- factor(
  dsr_correlation_long$candidate_y,
  levels = rev(candidate_order)
)

ggplot2::ggplot(
  dsr_correlation_long,
  ggplot2::aes(x = candidate_x, y = candidate_y, fill = correlation)
) +
  ggplot2::geom_tile(color = "white", linewidth = 0.35) +
  ggplot2::scale_fill_gradient2(
    low = "#B2182B",
    mid = "#F7F7F7",
    high = "#2166AC",
    midpoint = 0,
    limits = c(-1, 1)
  ) +
  ggplot2::labs(
    x = NULL,
    y = NULL,
    fill = "Correlation"
  ) +
  ggplot2::theme_minimal(base_size = 13) +
  ggplot2::theme(
    axis.text.x = ggplot2::element_text(angle = 45, hjust = 1)
  )
```

<img
src="selection-integrity_files/figure-commonmark/dsr-correlation-heatmap-1.png"
data-fig-alt="Correlation heatmap with two bright square blocks for shape_a and shape_b candidates."
alt="The return-correlation matrix shows two high-correlation blocks, so the sweep has two effective trial families rather than eight independent trials." />

``` r
dsr <- ledgr_dsr(dsr_sweep)
dsr
#> # ledgr deflated Sharpe ratio
#> # i candidates: 8
#> # i effective trials: 2
#> # i confidence: 0.950
#>
#> # A tibble: 8 x 6
#>   candidate_id observed_sharpe expected_max_sharpe dsr_probability p_value significant
#>   <chr>                  <dbl>               <dbl>           <dbl>   <dbl> <lgl>
#> 1 shape_a_1            0.25869            0.015223         0.78365 0.21635 FALSE
#> 2 shape_a_2            0.25708            0.015223         0.78086 0.21914 FALSE
#> 3 shape_a_3            0.25445            0.015223         0.77728 0.22272 FALSE
#> 4 shape_a_4            0.25090            0.015223         0.77303 0.22697 FALSE
#> 5 shape_b_1            0.27454            0.015223         0.80806 0.19194 FALSE
#> 6 shape_b_2            0.29136            0.015223         0.82341 0.17659 FALSE
#> 7 shape_b_3            0.30981            0.015223         0.83934 0.16066 FALSE
#> 8 shape_b_4            0.33000            0.015223         0.85565 0.14435 FALSE
```

``` r
two_effective_trials <- tibble::as_tibble(
  ledgr_dsr(dsr_sweep, effective_trials = 2)
)
eight_effective_trials <- tibble::as_tibble(
  ledgr_dsr(dsr_sweep, effective_trials = 8)
)
tibble::tibble(
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
#> # A tibble: 2 x 3
#>   assumption                       effective_trials first_candidate_dsr
#>   <chr>                                       <int>               <dbl>
#> 1 clustered candidates                            2               0.784
#> 2 treat all columns as independent                8               0.757
```

``` r
dsr_trial_curve <- tibble::tibble(
  effective_trials = 2:8,
  first_candidate_dsr = vapply(
    2:8,
    function(k) {
      tibble::as_tibble(ledgr_dsr(dsr_sweep, effective_trials = k))$dsr_probability[[1]]
    },
    numeric(1)
  )
)
dsr_trial_labels <- dsr_trial_curve[
  dsr_trial_curve$effective_trials %in% c(2L, 8L),
]

ggplot2::ggplot(
  dsr_trial_curve,
  ggplot2::aes(x = effective_trials, y = first_candidate_dsr)
) +
  ggplot2::geom_line(color = "#4F7FC8", linewidth = 0.8) +
  ggplot2::geom_point(color = "#4F7FC8", size = 2.6) +
  ggplot2::geom_text(
    data = dsr_trial_labels,
    ggplot2::aes(label = round(first_candidate_dsr, 3)),
    vjust = -0.8,
    size = 3.6
  ) +
  ggplot2::scale_x_continuous(breaks = 2:8) +
  ggplot2::labs(
    x = "Assumed effective trials",
    y = "First-candidate DSR"
  ) +
  ggplot2::theme_minimal(base_size = 13)
```

<img
src="selection-integrity_files/figure-commonmark/dsr-effective-trials-curve-1.png"
data-fig-alt="Line chart of first-candidate DSR decreasing from effective trials 2 through 8."
alt="The first-candidate DSR falls as the assumed number of independent trials rises." />

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
