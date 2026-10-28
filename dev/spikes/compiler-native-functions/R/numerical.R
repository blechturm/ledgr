compiler_spike_make_matrix <- function(n_sessions, n_instruments, seed = 20261028L) {
  stopifnot(
    length(n_sessions) == 1L,
    length(n_instruments) == 1L,
    n_sessions >= 1L,
    n_instruments >= 1L
  )
  set.seed(seed)
  matrix(
    stats::rnorm(n_sessions * n_instruments, sd = 0.012),
    nrow = n_sessions,
    ncol = n_instruments
  )
}

rolling_variance_reference <- function(x, window) {
  stopifnot(is.matrix(x), is.double(x), length(window) == 1L, window >= 1L)
  nr <- nrow(x)
  nc <- ncol(x)
  out <- matrix(0, nr, nc)
  if (nr == 0L || nc == 0L || window > nr) {
    return(out)
  }

  for (j in seq_len(nc)) {
    running_sum <- 0
    running_sum2 <- 0
    for (i in seq_len(nr)) {
      value <- x[i, j]
      running_sum <- running_sum + value
      running_sum2 <- running_sum2 + value * value
      if (i > window) {
        old <- x[i - window, j]
        running_sum <- running_sum - old
        running_sum2 <- running_sum2 - old * old
      }
      if (i >= window && window > 1L) {
        variance <- (running_sum2 - running_sum * running_sum / window) /
          (window - 1L)
        if (variance < 0 && variance > -1e-14) {
          variance <- 0
        }
        out[i, j] <- variance
      }
    }
  }
  out
}

rolling_variance_vectorized <- function(x, window) {
  stopifnot(is.matrix(x), is.double(x), length(window) == 1L, window >= 1L)
  nr <- nrow(x)
  nc <- ncol(x)
  out <- matrix(0, nr, nc)
  if (nr == 0L || nc == 0L || window > nr || window == 1L) {
    return(out)
  }

  cumulative <- apply(x, 2L, cumsum)
  cumulative2 <- apply(x * x, 2L, cumsum)
  if (nc == 1L) {
    cumulative <- matrix(cumulative, ncol = 1L)
    cumulative2 <- matrix(cumulative2, ncol = 1L)
  }
  prior <- rbind(matrix(0, 1L, nc), cumulative[seq_len(nr - window), , drop = FALSE])
  prior2 <- rbind(matrix(0, 1L, nc), cumulative2[seq_len(nr - window), , drop = FALSE])
  sums <- cumulative[window:nr, , drop = FALSE] - prior
  sums2 <- cumulative2[window:nr, , drop = FALSE] - prior2
  values <- (sums2 - sums * sums / window) / (window - 1L)
  values[values < 0 & values > -1e-14] <- 0
  out[window:nr, ] <- values
  out
}

rolling_variance_quickr_source <- function() {
  function(x, window) {
    declare(
      type(x = double(NA, NA)),
      type(window = integer(1))
    )
    nr <- nrow(x)
    nc <- ncol(x)
    out <- matrix(0, nr, nc)
    for (j in seq_len(nc)) {
      running_sum <- 0
      running_sum2 <- 0
      for (i in seq_len(nr)) {
        value <- x[i, j]
        running_sum <- running_sum + value
        running_sum2 <- running_sum2 + value * value
        if (i > window) {
          old <- x[i - window, j]
          running_sum <- running_sum - old
          running_sum2 <- running_sum2 - old * old
        }
        if (i >= window && window > 1L) {
          variance <- (running_sum2 - running_sum * running_sum / window) /
            (window - 1L)
          if (variance < 0 && variance > -1e-14) {
            variance <- 0
          }
          out[i, j] <- variance
        }
      }
    }
    out
  }
}

rolling_variance_ast2ast_source <- function() {
  function(x, window) {
    argtypes(
      x |> type(mat(double)),
      window |> type(int)
    )
    nr <- nrow(x)
    nc <- ncol(x)
    out <- matrix(0.0, nr, nc)
    for (j in 1L:nc) {
      running_sum <- 0.0
      running_sum2 <- 0.0
      for (i in 1L:nr) {
        value <- x[i, j]
        running_sum <- running_sum + value
        running_sum2 <- running_sum2 + value * value
        if (i > window) {
          old <- x[i - window, j]
          running_sum <- running_sum - old
          running_sum2 <- running_sum2 - old * old
        }
        if (i >= window && window > 1L) {
          variance <- (running_sum2 - running_sum * running_sum / window) /
            (window - 1L)
          if (variance < 0.0 && variance > -1e-14) {
            variance <- 0.0
          }
          out[i, j] <- variance
        }
      }
    }
    return(out)
  }
}

masked_row_mean_reference <- function(x, valid) {
  stopifnot(is.matrix(x), is.matrix(valid), identical(dim(x), dim(valid)))
  nr <- nrow(x)
  nc <- ncol(x)
  out <- matrix(0, nr, 2L)
  for (i in seq_len(nr)) {
    total <- 0
    count <- 0L
    for (j in seq_len(nc)) {
      if (valid[i, j] != 0L) {
        total <- total + x[i, j]
        count <- count + 1L
      }
    }
    if (count > 0L) {
      out[i, 1L] <- total / count
    }
    out[i, 2L] <- count
  }
  out
}

masked_row_mean_quickr_source <- function() {
  function(x, valid) {
    declare(
      type(x = double(NA, NA)),
      type(valid = integer(NA, NA))
    )
    nr <- nrow(x)
    nc <- ncol(x)
    out <- matrix(0, nr, 2)
    for (i in seq_len(nr)) {
      total <- 0
      count <- 0
      for (j in seq_len(nc)) {
        if (valid[i, j] != 0) {
          total <- total + x[i, j]
          count <- count + 1
        }
      }
      if (count > 0) {
        out[i, 1] <- total / count
      }
      out[i, 2] <- count
    }
    out
  }
}

masked_row_mean_ast2ast_source <- function() {
  function(x, valid) {
    argtypes(
      x |> type(mat(double)),
      valid |> type(mat(int))
    )
    nr <- nrow(x)
    nc <- ncol(x)
    out <- matrix(0.0, nr, 2L)
    for (i in 1L:nr) {
      total <- 0.0
      count <- 0L
      for (j in 1L:nc) {
        if (valid[i, j] != 0L) {
          total <- total + x[i, j]
          count <- count + 1L
        }
      }
      if (count > 0L) {
        out[i, 1L] <- total / count
      }
      out[i, 2L] <- count
    }
    return(out)
  }
}
