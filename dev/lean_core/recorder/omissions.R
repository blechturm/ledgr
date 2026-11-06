# LDG-3212 omission demonstration: each registered omission is a recorder
# gutted one way, and the replay check or the comparison must fail on it.
# Further witnesses probe the review's escape routes (R1): an unguarded `[`
# read, a global read, an undeclared write, same-named user values, in-place
# writes to cached or thawed buffers, and digest coverage. This process holds
# only the pinned build, the recorder and run.R's captures (dense_cost and
# failures; it asks run.R for the by-reference capture).
#
#   Rscript dev/lean_core/recorder/omissions.R --lib=<pinned library> --captures=<run.R's dir> [--out=<dir>]

local({
  arg <- function(n, default = NULL) {
    hit <- grep(paste0("^--", n, "="), commandArgs(TRUE), value = TRUE)
    if (length(hit)) sub(paste0("^--", n, "="), "", hit[[1L]]) else default
  }
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
  captures <- arg("captures")
  out <- arg("out", file.path(here, "evidence"))
  source(file.path(here, "..", "load.R"), local = TRUE)
  lean <- lean_core_load(arg("lib"))
  lean_core_source(lean, c(file.path(lean_core_home, "..", "bench", "v0_2_3_ws16_entry", "common.R"),
                           file.path(here, c("fields.R", "capture.R", "compare.R", "replay.R"))))
  status <- system2(file.path(R.home("bin"), "Rscript"), c(file.path(here, "run.R"), paste0("--lib=", arg("lib")),
    paste0("--captures=", captures), "--workloads=dense_cost", "--by-reference=valuation_state"))
  stopifnot(identical(status, 0L))
  read <- function(id) lean$lc_read_capture(file.path(captures, paste0(id, ".rds")))
  base <- read("dense_cost")
  fail <- read("failures")
  byref <- read("dense_cost_byref")
  fields <- lean$lc_table_fields()
  lean$lc_install()
  list2env(list(clock = base$clock, verify_every = 25L), envir = lean$lc_rec)
  of <- function(cap, b) which(vapply(cap$records, `[[`, character(1), "boundary") == b)
  refreeze <- function(cap, values) lean$lc_freeze(values, cap$store)
  p1 <- of(base, "P1")
  p4 <- of(base, "P4")

  rows <- list()
  row <- function(omission, workload, records, failed, difference, outcome) {
    rows[[length(rows) + 1L]] <<- data.frame(omission = omission, workload = workload, records = records,
                                             failed = failed, first_difference = difference, outcome = outcome)
  }
  demo <- function(omission, workload, cap, idx, omit = NULL, control = FALSE) {
    res <- lean$lc_replay(cap, fields, omit = omit, only = idx)
    failed <- sum(!res$pass)
    outcome <- if (control) {
      if (failed == 0L) "control passes" else "CONTROL FAILED"
    } else if (failed > 0L) "fails as required" else "NOT DETECTED"
    row(omission, workload, nrow(res), failed, c(res$difference[!res$pass], "")[[1L]], outcome)
  }
  # A witness that must come out as `want`.
  unit <- function(omission, got, want) {
    row(omission, "unit", 1L, as.integer(!identical(got, want)), paste(format(got), collapse = " "),
        if (identical(got, want)) "recorded correctly" else "NOT DETECTED")
  }
  # Replays P1 through `stage` in place of the pinned function.
  with_p1 <- function(stage, expr) {
    orig <- lean$lc_rec$orig$P1
    lean$lc_rec$orig$P1 <- stage(orig)
    on.exit(lean$lc_rec$orig$P1 <- orig)
    force(expr)
  }

  demo("none (control)", "dense_cost", base, seq_along(base$records), control = TRUE)
  demo("none (control)", "failures", fail, seq_along(fail$records), control = TRUE)

  # The seven registered omissions.
  demo("one fold-state slot left out (P1 cash)", "dense_cost", base, p1, omit = list(boundary = "P1", slot = "cash"))
  demo("mutable services field by reference (valuation_state)", "dense_cost", byref, of(byref, "P1"))
  calls <- which(vapply(base$records, function(r) length(r$calls) > 0L, logical(1)))
  ignored <- base
  ignored$records[calls] <- lapply(base$records[calls], function(r) { r$calls <- list(); r })
  demo("handler calls ignored", "dense_cost", ignored, calls)
  returns <- base
  returns$records[p4] <- lapply(base$records[p4], function(r) {
    r$output <- refreeze(base, list(value = lean$lc_thaw(r$output, base$store)$value))
    r
  })
  demo("only the return compared (P4)", "dense_cost", returns, p4)
  ulp <- base
  r <- base$records[[p4[[1L]]]]
  value <- lean$lc_thaw(r$output, base$store)
  cash <- value[["state:cash"]]
  value[["state:cash"]] <- cash + 2^(floor(log2(abs(cash))) - 52)
  stopifnot(value[["state:cash"]] != cash)
  r$output <- refreeze(base, value)
  ulp$records[[p4[[1L]]]] <- r
  demo("one-ulp change in one double (P4 cash)", "dense_cost", ulp, p4[[1L]])
  publishes <- function(r) any(vapply(r$calls, function(k) identical(k$method, "write_fill_events") &&
    length(lean$lc_thaw(k$args, base$store)$i) >= 2L, logical(1)))
  target <- p4[vapply(base$records[p4], publishes, logical(1))][[1L]]
  swapped <- base
  r <- base$records[[target]]
  k <- which(vapply(r$calls, function(k) identical(k$method, "write_fill_events"), logical(1)))[[1L]]
  a <- lean$lc_thaw(r$calls[[k]]$args, base$store)
  a$i[1:2] <- a$i[2:1]
  a$instrument_id[1:2] <- a$instrument_id[2:1]
  r$calls[[k]]$args <- refreeze(base, a)
  swapped$records[[target]] <- r
  demo("two event rows swapped (P4 publication)", "dense_cost", swapped, target)
  raised <- which(vapply(fail$records, function(r) !is.null(r$cond) && r$boundary == "P2", logical(1)))[[1L]]
  reclassed <- fail
  reclassed$records[[raised]]$cond$class[[1L]] <- "lc_other_condition"
  demo("changed condition class (P2)", "failures", reclassed, raised)

  # Review witnesses (CHANGES_REQUIRED round 1).
  with_p1(function(orig) function(fold_state, services, ...) {
    services["not_in_table"]
    orig(fold_state, services, ...)
  }, demo("P1 reads an unnamed services field with [", "dense_cost", base, p1))
  with_p1(function(orig) function(...) {
    lc_witness_global
    orig(...)
  }, demo("P1 reads a global variable", "dense_cost", base, p1))
  corrupted <- base
  r <- base$records[[p1[[1L]]]]
  value <- lean$lc_thaw(r$output, base$store)
  value[["state:status"]] <- "CORRUPTED"
  r$output <- refreeze(base, value)
  corrupted$records[[p1[[1L]]]] <- r
  demo("unnamed slot changed in the captured output (P1 status)", "dense_cost", corrupted, p1[[1L]])
  unit("a user value named like a clock field is compared",
       is.null(lean$lc_compare(list(value = list(user = list(t_fill = 1))), list(value = list(user = list(t_fill = 2))),
                               base$clock, lean$lc_clock_paths("P1"))), FALSE)
  s <- lean$lc_store_new()
  e <- new.env(parent = baseenv())
  e$x <- as.double(seq_len(2048L))
  z1 <- lean$lc_freeze(list(e = e), s)
  invisible(collapse::setv(e$x, 1L, 99))
  z2 <- lean$lc_freeze(list(e = e), s)
  unit("an in-place write between two captures is recorded", lean$lc_thaw(z2, s)$e$x[[1L]], 99)
  invisible(collapse::setv(lean$lc_thaw(z1, s)$e$x, 1L, 77))
  unit("an in-place write to one thaw leaves the next thaw unchanged", lean$lc_thaw(z1, s)$e$x[[1L]], 1)
  fixed <- base
  v <- lean$lc_thaw(base$folds[[1L]]$fixed, base$store)
  v$run_id <- "changed-run-id"
  fixed$folds[[1L]]$fixed <- refreeze(base, v)
  unit("a changed fixed services field changes the manifest", identical(lean$lc_manifest(base), lean$lc_manifest(fixed)), FALSE)
  unit("a user field named created_at is digested",
       identical(lean$lc_freeze(list(user = list(created_at = 1)), s)$canon, lean$lc_freeze(list(user = list(created_at = 2)), s)$canon), FALSE)

  res <- do.call(rbind, rows)
  utils::write.csv(res, file.path(out, "omissions.csv"), row.names = FALSE)
  print(res[c("omission", "records", "failed", "outcome")], right = FALSE)
  if (any(res$outcome %in% c("NOT DETECTED", "CONTROL FAILED"))) quit(status = 1L)
})
