# Set seed FIRST (before any randomness)
base::set.seed(12345)

# Define date range
dates <- seq.Date(as.Date("2020-01-01"), as.Date("2020-12-31"), by = "day")
n_days <- length(dates)  # 366 (2020 is leap year)

# Define instruments
instruments <- c("TEST_A", "TEST_B")

# Create panel structure (cartesian product: 732 rows total)
test_bars <- expand.grid(
  date = dates,
  instrument_id = instruments,
  stringsAsFactors = FALSE
)

# Sort by instrument, then date
test_bars <- test_bars[order(test_bars$instrument_id, test_bars$date), ]

# Generate per-instrument random walks
test_bars$open <- NA
test_bars$high <- NA
test_bars$low <- NA
test_bars$close <- NA
test_bars$volume <- NA

for (inst in instruments) {
  idx <- test_bars$instrument_id == inst
  n <- sum(idx)

  # Random walk for prices
  returns <- stats::rnorm(n, mean = 0.0005, sd = 0.02)
  prices <- 100 * cumprod(1 + returns)

  test_bars$open[idx] <- prices
  test_bars$close[idx] <- prices * (1 + stats::rnorm(n, 0, 0.005))
  test_bars$high[idx] <- pmax(test_bars$open[idx], test_bars$close[idx]) * (1 + abs(stats::rnorm(n, 0, 0.01)))
  test_bars$low[idx] <- pmin(test_bars$open[idx], test_bars$close[idx]) * (1 - abs(stats::rnorm(n, 0, 0.01)))
  test_bars$volume[idx] <- round(stats::rnorm(n, 1000000, 200000))
}

# Add ISO timestamps
test_bars$ts_utc <- sprintf("%sT00:00:00Z", test_bars$date)

# Final structure (732 rows: 366 days x 2 instruments)
test_bars <- test_bars[, c("ts_utc", "instrument_id", "open", "high", "low", "close", "volume")]

# Verify structure
stopifnot(nrow(test_bars) == 732)
stopifnot(length(unique(test_bars$instrument_id)) == 2)
stopifnot(all(table(test_bars$instrument_id) == 366))
