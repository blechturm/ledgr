#include <Rcpp.h>
#include <cmath>

// [[Rcpp::export]]
Rcpp::NumericMatrix rolling_variance_rcpp(
    const Rcpp::NumericMatrix& x,
    const int window) {
  const int nr = x.nrow();
  const int nc = x.ncol();
  Rcpp::NumericMatrix out(nr, nc);
  for (int j = 0; j < nc; ++j) {
    double running_sum = 0.0;
    double running_sum2 = 0.0;
    for (int i = 0; i < nr; ++i) {
      const double value = x(i, j);
      running_sum += value;
      running_sum2 += value * value;
      if (i + 1 > window) {
        const double old = x(i - window, j);
        running_sum -= old;
        running_sum2 -= old * old;
      }
      if (i + 1 >= window && window > 1) {
        double variance =
          (running_sum2 - running_sum * running_sum / window) / (window - 1);
        if (variance < 0.0 && variance > -1e-14) {
          variance = 0.0;
        }
        out(i, j) = variance;
      }
    }
  }
  return out;
}

// [[Rcpp::export]]
Rcpp::NumericVector stateful_rcpp(
    const Rcpp::NumericVector& prices,
    const Rcpp::NumericVector& signals,
    const double initial_cash,
    const double cost_rate,
    const double equity_fraction) {
  const int n = prices.size();
  Rcpp::NumericVector out(n + 3);
  double cash = initial_cash;
  double holdings = 0.0;
  double total_cost = 0.0;
  for (int i = 0; i < n; ++i) {
    const double equity_before = cash + holdings * prices[i];
    double target = 0.0;
    if (signals[i] > 0.5) {
      target = std::floor(equity_before * equity_fraction / prices[i]);
    }
    const double quantity = target - holdings;
    const double cost = std::abs(quantity) * prices[i] * cost_rate;
    cash = cash - quantity * prices[i] - cost;
    holdings = target;
    total_cost += cost;
    out[i] = cash + holdings * prices[i];
  }
  out[n] = cash;
  out[n + 1] = holdings;
  out[n + 2] = total_cost;
  return out;
}

// [[Rcpp::export]]
Rcpp::NumericMatrix batch_rcpp(
    const Rcpp::NumericVector& prices,
    const Rcpp::NumericMatrix& signals,
    const double initial_cash,
    const double cost_rate,
    const Rcpp::NumericVector& equity_fractions) {
  const int nr = signals.nrow();
  const int nc = signals.ncol();
  Rcpp::NumericMatrix out(nr, nc);
  for (int j = 0; j < nc; ++j) {
    double cash = initial_cash;
    double holdings = 0.0;
    for (int i = 0; i < nr; ++i) {
      const double equity_before = cash + holdings * prices[i];
      double target = 0.0;
      if (signals(i, j) > 0.5) {
        target = std::floor(equity_before * equity_fractions[j] / prices[i]);
      }
      const double quantity = target - holdings;
      const double cost = std::abs(quantity) * prices[i] * cost_rate;
      cash = cash - quantity * prices[i] - cost;
      holdings = target;
      out(i, j) = cash + holdings * prices[i];
    }
  }
  return out;
}

// [[Rcpp::export]]
Rcpp::NumericMatrix masked_row_mean_rcpp(
    const Rcpp::NumericMatrix& x,
    const Rcpp::IntegerMatrix& valid) {
  const int nr = x.nrow();
  const int nc = x.ncol();
  Rcpp::NumericMatrix out(nr, 2);
  for (int i = 0; i < nr; ++i) {
    double total = 0.0;
    int count = 0;
    for (int j = 0; j < nc; ++j) {
      if (valid(i, j) != 0) {
        total += x(i, j);
        ++count;
      }
    }
    if (count > 0) {
      out(i, 0) = total / count;
    }
    out(i, 1) = count;
  }
  return out;
}

// [[Rcpp::export]]
Rcpp::NumericVector special_values_rcpp(const Rcpp::NumericVector& x) {
  return Rcpp::clone(x);
}
