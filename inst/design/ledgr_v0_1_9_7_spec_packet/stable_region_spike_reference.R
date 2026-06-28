stable_region_reference <- function(grid, metric, param_cols, min_neighbors = 1,
                                    higher_is_better = TRUE) {
  stopifnot(is.data.frame(grid))
  stopifnot(is.numeric(metric), length(metric) == nrow(grid))
  stopifnot(is.character(param_cols), length(param_cols) > 0)
  stopifnot(all(param_cols %in% names(grid)))
  stopifnot(is.numeric(min_neighbors), length(min_neighbors) == 1L)
  if (!is.finite(min_neighbors) || min_neighbors < 1 || min_neighbors != as.integer(min_neighbors)) {
    stop("invalid min_neighbors", call. = FALSE)
  }
  if (any(!is.finite(metric))) {
    stop("invalid metric", call. = FALSE)
  }

  levels <- lapply(param_cols, function(col) stable_region_levels(grid[[col]], col))
  names(levels) <- param_cols
  if (any(vapply(levels, length, integer(1)) < 2L)) {
    stop("collapsed axis", call. = FALSE)
  }

  index <- Map(stable_region_level_index, grid[param_cols], levels, param_cols)
  index_df <- as.data.frame(index, stringsAsFactors = FALSE)
  names(index_df) <- param_cols
  keys <- do.call(paste, c(index_df, sep = "\r"))
  if (anyDuplicated(keys)) {
    stop("duplicate grid point", call. = FALSE)
  }

  expected_n <- prod(vapply(levels, length, integer(1)))
  if (nrow(grid) != expected_n) {
    stop("sparse or non-factorial grid", call. = FALSE)
  }

  full <- expand.grid(
    lapply(levels, seq_along),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  names(full) <- param_cols
  full_keys <- do.call(paste, c(full, sep = "\r"))
  if (!setequal(keys, full_keys)) {
    stop("non-factorial grid", call. = FALSE)
  }

  row_by_key <- setNames(seq_len(nrow(grid)), keys)
  score <- if (higher_is_better) metric else -metric
  neighbors <- vector("list", nrow(grid))
  adjacent_diffs <- numeric()

  for (i in seq_len(nrow(grid))) {
    local <- integer()
    for (axis in param_cols) {
      for (delta in c(-1L, 1L)) {
        neighbor_index <- index_df[i, , drop = FALSE]
        neighbor_index[[axis]] <- neighbor_index[[axis]] + delta
        if (neighbor_index[[axis]] < 1L || neighbor_index[[axis]] > length(levels[[axis]])) {
          next
        }
        key <- do.call(paste, c(neighbor_index, sep = "\r"))
        j <- unname(row_by_key[[key]])
        local <- c(local, j)
        if (i < j) {
          adjacent_diffs <- c(adjacent_diffs, abs(score[i] - score[j]))
        }
      }
    }
    neighbors[[i]] <- sort(unique(local))
  }

  if (!length(adjacent_diffs)) {
    stop("no adjacent pairs", call. = FALSE)
  }
  tau <- stats::median(adjacent_diffs)

  out <- data.frame(
    row = seq_len(nrow(grid)),
    available_neighbors = integer(nrow(grid)),
    good_neighbors = integer(nrow(grid)),
    support_ratio = numeric(nrow(grid)),
    local_smoothness_range = numeric(nrow(grid)),
    eligible = logical(nrow(grid))
  )
  for (i in seq_len(nrow(grid))) {
    local <- neighbors[[i]]
    local_scores <- score[local]
    good <- local_scores >= score[i] - tau
    out$available_neighbors[i] <- length(local)
    out$good_neighbors[i] <- sum(good)
    out$support_ratio[i] <- if (length(local)) sum(good) / length(local) else NA_real_
    out$local_smoothness_range[i] <- if (length(local)) {
      max(local_scores) - min(local_scores)
    } else {
      NA_real_
    }
    out$eligible[i] <- out$good_neighbors[i] >= min_neighbors
  }

  list(
    tau = tau,
    result = cbind(grid, metric = metric, out),
    level_sets = levels,
    adjacency_rule = "Manhattan distance 1 in level-index space"
  )
}

stable_region_levels <- function(x, col) {
  if (is.factor(x) && !is.ordered(x)) {
    stop(sprintf("unordered factor axis: %s", col), call. = FALSE)
  }
  if (is.ordered(x)) {
    return(levels(x))
  }
  if (is.logical(x)) {
    return(c(FALSE, TRUE)[c(FALSE, TRUE) %in% unique(x)])
  }
  if (inherits(x, "Date") || inherits(x, "POSIXt")) {
    return(sort(unique(x)))
  }
  if (is.numeric(x) || is.integer(x)) {
    return(sort(unique(x)))
  }
  stop(sprintf("unsupported axis: %s", col), call. = FALSE)
}

stable_region_level_index <- function(x, levels, col) {
  idx <- match(as.character(x), as.character(levels))
  if (anyNA(idx)) {
    stop(sprintf("unmatched axis level: %s", col), call. = FALSE)
  }
  idx
}

expect_error <- function(expr, pattern) {
  err <- tryCatch(
    {
      force(expr)
      NULL
    },
    error = identity
  )
  if (is.null(err)) {
    stop(sprintf("expected error matching %s", pattern), call. = FALSE)
  }
  if (!grepl(pattern, conditionMessage(err), fixed = TRUE)) {
    stop(sprintf("wrong error: %s", conditionMessage(err)), call. = FALSE)
  }
  invisible(err)
}

grid <- expand.grid(x = 1:3, y = 1:3, KEEP.OUT.ATTRS = FALSE)
plateau_metric <- 1 - 0.01 * (abs(grid$x - 2) + abs(grid$y - 2))
plateau <- stable_region_reference(grid, plateau_metric, c("x", "y"), min_neighbors = 4)
center <- which(grid$x == 2 & grid$y == 2)
stopifnot(isTRUE(all.equal(unname(plateau$tau), 0.01, tolerance = 1e-15)))
stopifnot(plateau$result$good_neighbors[center] == 4L)
stopifnot(isTRUE(plateau$result$eligible[center]))

spike_metric <- ifelse(grid$x == 2 & grid$y == 2, 1, 0)
spike <- stable_region_reference(grid, spike_metric, c("x", "y"), min_neighbors = 1)
stopifnot(isTRUE(all.equal(unname(spike$tau), 0, tolerance = 1e-15)))
stopifnot(spike$result$good_neighbors[center] == 0L)
stopifnot(!isTRUE(spike$result$eligible[center]))

expect_error(
  stable_region_reference(grid[-1L, ], plateau_metric[-1L], c("x", "y")),
  "sparse or non-factorial grid"
)

unordered <- data.frame(x = factor(rep(c("low", "high"), each = 2)), y = rep(1:2, 2))
expect_error(
  stable_region_reference(unordered, c(1, 2, 3, 4), c("x", "y")),
  "unordered factor axis"
)

duplicate <- rbind(grid, grid[1L, ])
expect_error(
  stable_region_reference(duplicate, c(plateau_metric, plateau_metric[1L]), c("x", "y")),
  "duplicate grid point"
)

collapsed <- data.frame(x = rep(1, 3), y = 1:3)
expect_error(
  stable_region_reference(collapsed, c(1, 2, 3), c("x", "y")),
  "collapsed axis"
)

cat("stable_region spike reference checks passed\n")
cat("plateau_tau:", plateau$tau, "\n")
cat("plateau_center_good_neighbors:", plateau$result$good_neighbors[center], "\n")
cat("spike_tau:", spike$tau, "\n")
cat("spike_center_good_neighbors:", spike$result$good_neighbors[center], "\n")
