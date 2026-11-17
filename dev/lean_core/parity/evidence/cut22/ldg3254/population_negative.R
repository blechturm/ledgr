# LDG-3254: the population comparison must refuse an omitted deterministic
# call and a changed key even when the totals agree. Builds two corrupted
# copies of capture B (one lot call replaced by a copy of the next; one lot call's digest changed,
# so the totals still agree), runs fifo_population.R on capture A against
# each and requires exit status 1 from both.
#
#   Rscript population_negative.R --a=<capture A> --b=<capture B> --scratch=<dir>
local({
  arg <- function(n) sub(paste0("^--", n, "="), "", grep(paste0("^--", n, "="), commandArgs(TRUE), value = TRUE)[[1L]])
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
  tool <- normalizePath(file.path(here, "..", "..", "..", "fifo_population.R"), winslash = "/")
  scratch <- arg("scratch")
  chunks <- sort(list.files(arg("b"), "^tests_[0-9]+[.]rds$", full.names = TRUE))
  first <- readRDS(chunks[[1L]])
  lot <- which(vapply(first, function(k) is.null(k$input_args), logical(1)))
  corrupt <- function(name, f) {
    dir <- file.path(scratch, name)
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    file.copy(chunks[-1L], dir, overwrite = TRUE)
    saveRDS(f(first), file.path(dir, basename(chunks[[1L]])))
    out <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"),
      c(tool, paste0("--a=", arg("a")), paste0("--b=", dir), paste0("--out=", file.path(scratch, paste0(name, ".csv")))),
      stdout = TRUE, stderr = TRUE))
    status <- attr(out, "status") %||% 0L
    cat(name, ": exit", status, "\n", paste0("  ", out, "\n"), sep = "")
    status
  }
  `%||%` <- function(a, b) if (is.null(a)) b else a
  # Call 10 omitted and call 11 repeated in its place: the totals agree.
  dropped <- corrupt("omitted_call", function(x) { x[[lot[[10L]]]] <- x[[lot[[11L]]]]; x })
  changed <- corrupt("changed_key", function(x) { x[[lot[[10L]]]]$digest <- "0000000000000000"; x })
  if (!identical(as.integer(dropped), 1L) || !identical(as.integer(changed), 1L)) {
    cat("NEGATIVE CONTROLS FAIL\n")
    quit(status = 1L)
  }
  cat("NEGATIVE CONTROLS PASS: both corrupted populations refuse\n")
})
