# Growth-shape matrix checker (spike_protocol.md). Binds nothing.
#
# Recomputes growth exponents from recorded timings and flags superlinear
# cells; then guards package scope (no edits under R/, src/, tests/, ...).
#
#   Rscript check.R <repo> <timings.csv> [<timings.csv> ...] [out=<exponents.csv>]
#
# exponent = log(t_axis / t_base) / log(size_axis / size_base) on medians over
# repetitions. Verdicts: SUPERLINEAR when > 1 + TOL and the larger median is
# at least FLOOR_S (smaller phases are timer noise); CAP when any repetition
# hit the per-entry cap; otherwise linear / sublinear / below_floor.

TOL <- 0.15
FLOOR_S <- 0.30
CAP_S <- 60  # matrix.R GSM_CAP_S; setTimeLimit fires only at R interrupt checks
AXES <- c(T = "T", N = "N", C = "C")

gsc_read <- function(paths) {
  x <- do.call(rbind, lapply(paths, utils::read.csv, stringsAsFactors = FALSE))
  x <- x[!x$entry %in% c("child", "experiment"), , drop = FALSE]
  # Derived phase: run time outside t_pre, t_loop and t_post.
  key <- c("rep", "feature", "mode", "point")
  run <- x[x$entry == "run" & x$status == "ok", , drop = FALSE]
  if (nrow(run)) {
    w <- stats::reshape(run[c(key, "phase", "seconds")], idvar = key, timevar = "phase", direction = "wide")
    other <- w[key]
    other$seconds <- w$seconds.total - rowSums(w[c("seconds.t_pre", "seconds.t_loop", "seconds.t_post")])
    base <- x[x$entry == "run" & x$phase == "total", , drop = FALSE]
    base <- base[match(interaction(other[key]), interaction(base[key])), , drop = FALSE]
    base$phase <- "other"
    base$seconds <- other$seconds
    x <- rbind(x, base)
  }
  x
}

gsc_median_ok <- function(rows) {
  ok <- rows$seconds[rows$status == "ok"]
  if (length(ok)) stats::median(ok) else NA_real_
}

# One exponent per consecutive size pair along an axis, holding the other
# two sizes at the base point's values.
gsc_exponents <- function(x) {
  base_size <- c(T = 250L, N = 20L, C = 2L)
  cell <- unique(x[c("feature", "mode", "entry", "phase")])
  out <- list()
  for (i in seq_len(nrow(cell))) {
    c <- cell[i, ]
    rows <- x[x$feature == c$feature & x$mode == c$mode & x$entry == c$entry & x$phase == c$phase, , drop = FALSE]
    for (axis in AXES) {
      if (identical(axis, "C") && !identical(c$entry, "sweep")) next
      others <- setdiff(AXES, axis)
      on_axis <- rows[rows[[others[[1L]]]] == base_size[[others[[1L]]]] &
                      rows[[others[[2L]]]] == base_size[[others[[2L]]]], , drop = FALSE]
      sizes <- sort(unique(on_axis[[axis]]))
      if (length(sizes) < 2L) next
      for (k in seq_len(length(sizes) - 1L)) {
        b <- on_axis[on_axis[[axis]] == sizes[[k]], , drop = FALSE]
        a <- on_axis[on_axis[[axis]] == sizes[[k + 1L]], , drop = FALSE]
        ratio <- sizes[[k + 1L]] / sizes[[k]]
        cap <- any(c(a$status, b$status) == "CAP") || any(c(a$seconds, b$seconds) > CAP_S, na.rm = TRUE)
        err <- any(c(a$status, b$status) == "ERROR")
        med_a <- gsc_median_ok(a)
        med_b <- gsc_median_ok(b)
        # Per-repetition exponents (same repetition paired) show the spread.
        reps <- intersect(a$rep[a$status == "ok"], b$rep[b$status == "ok"])
        per_rep <- vapply(reps, function(r) {
          log(a$seconds[a$rep == r & a$status == "ok"][[1L]] / b$seconds[b$rep == r & b$status == "ok"][[1L]]) / log(ratio)
        }, numeric(1))
        e <- log(med_a / med_b) / log(ratio)
        verdict <- if (cap) "CAP" else if (err) "ERROR" else if (!is.finite(e)) "no_data" else
          if (max(med_a, med_b) < FLOOR_S) "below_floor" else
          if (e > 1 + TOL) "SUPERLINEAR" else if (e < 1 - TOL) "sublinear" else "linear"
        out[[length(out) + 1L]] <- data.frame(
          feature = c$feature, mode = c$mode, entry = c$entry, phase = c$phase,
          axis = sprintf("%s:%d-%d", axis, sizes[[k]], sizes[[k + 1L]]),
          small_s = round(med_b, 3), large_s = round(med_a, 3), exponent = round(e, 2),
          rep_min = if (length(per_rep)) round(min(per_rep), 2) else NA_real_,
          rep_max = if (length(per_rep)) round(max(per_rep), 2) else NA_real_,
          n_reps = length(reps), verdict = verdict, stringsAsFactors = FALSE)
      }
    }
  }
  out <- do.call(rbind, out)
  # Constant-factor view: availability over dense at the same size point.
  key <- paste(out$feature, out$entry, out$phase, out$axis)
  dense <- out[out$mode == "dense", , drop = FALSE]
  hit <- match(key, paste(dense$feature, dense$entry, dense$phase, dense$axis))
  out$avail_over_dense_large <- ifelse(out$mode == "availability",
                                       round(out$large_s / dense$large_s[hit], 1), NA_real_)
  out[order(out$entry, out$feature, out$mode, out$phase, out$axis), , drop = FALSE]
}

# Wide view for the findings table: one row per cell and phase, one exponent
# column per axis pair ("below_floor" pairs shown in parentheses), worst verdict.
gsc_wide <- function(ex) {
  ex$cell <- paste(ex$feature, ex$mode, ex$entry, ex$phase, sep = "|")
  ex$shown <- ifelse(ex$verdict == "CAP", "CAP", ifelse(ex$verdict == "below_floor",
                     sprintf("(%.2f)", ex$exponent), sprintf("%.2f", ex$exponent)))
  rank <- c(below_floor = 0, sublinear = 1, linear = 2, no_data = 0, SUPERLINEAR = 4, CAP = 3, ERROR = 3)
  axes <- sort(unique(ex$axis))
  out <- do.call(rbind, lapply(split(ex, ex$cell), function(d) {
    row <- d[1L, c("feature", "mode", "entry", "phase")]
    for (a in axes) row[[a]] <- if (a %in% d$axis) d$shown[d$axis == a][[1L]] else ""
    row$worst <- d$verdict[which.max(rank[d$verdict])]
    row
  }))
  out[order(out$entry, out$feature, out$mode, out$phase), , drop = FALSE]
}

gsc_scope_guard <- function(repo) {
  paths <- c("R", "src", "tests", "NAMESPACE", "DESCRIPTION", "man", "inst/design")
  st <- system2("git", c("-C", shQuote(repo), "status", "--porcelain", "--", paths), stdout = TRUE)
  st <- st[!grepl("\\.(o|dll|so|gcda|gcno)$", st)]
  if (length(st)) {
    cat("SCOPE GUARD: package files changed:\n", paste0("  ", st, "\n"), sep = "")
    return(FALSE)
  }
  cat("SCOPE GUARD: no package files changed\n")
  TRUE
}

gsc_main <- function(args = commandArgs(TRUE)) {
  repo <- args[[1L]]
  out_arg <- grep("^out=", args, value = TRUE)
  paths <- setdiff(args[-1L], out_arg)
  ex <- gsc_exponents(gsc_read(paths))
  raw <- do.call(rbind, lapply(paths, utils::read.csv, stringsAsFactors = FALSE))
  refused <- unique(raw[raw$status %in% c("REFUSED", "CHILD_FAILED"), c("feature", "mode", "status", "note")])
  if (nrow(refused)) {
    cat("Cells not measured:\n")
    print(refused, row.names = FALSE, right = FALSE)
  }
  if (length(out_arg)) {
    out_path <- sub("^out=", "", out_arg[[1L]])
    utils::write.csv(ex, out_path, row.names = FALSE)
    utils::write.csv(gsc_wide(ex), sub("\\.csv$", "_wide.csv", out_path), row.names = FALSE)
  }
  flagged <- ex[ex$verdict %in% c("SUPERLINEAR", "CAP", "ERROR"), , drop = FALSE]
  cat(sprintf("%d cell-axis-phase rows; %d flagged (tolerance +-%.2f, floor %.2f s)\n",
              nrow(ex), nrow(flagged), TOL, FLOOR_S))
  if (nrow(flagged)) print(flagged, row.names = FALSE, right = FALSE)
  guard <- gsc_scope_guard(repo)
  invisible(list(exponents = ex, flagged = flagged, scope_ok = guard))
}

if (sys.nframe() == 0L) gsc_main()
