# LDG-3216 checker: runs prep_parity.R for each requested capture at each
# width and debug setting, and each registered mutation, in parallel child
# processes (never during a timing window). Every parity run must pass and
# every mutation must fail.
#
#   Rscript dev/lean_core/parity/prep_check.R --lib=<pinned library>
#     --captures=<capture.rds,...> --widths=<8,12|run> --scratch=<empty dir>
#     [--mutations] [--jobs=6] [--orient=time] [--private] [--out=<evidence csv>]

here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "(=|$)"), commandArgs(TRUE), value = TRUE)
  if (!length(hit)) return(default %||% stop("--", name, "= is required", call. = FALSE))
  sub(paste0("^--", name, "=?"), "", hit[[1L]])
}
scratch <- arg("scratch")
dir.create(scratch, recursive = TRUE, showWarnings = FALSE)
captures <- strsplit(arg("captures"), ",")[[1L]]
widths <- strsplit(arg("widths", "8,12"), ",")[[1L]]
orient <- arg("orient", "time")
mutations <- c("features_restarted_at_edge", "admission_from_current_membership", "cutoff_overlay_dropped",
               "retained_view_aliasing_recycled_tile", "finite_request_truncated_at_edge")
jobs <- list()
for (cap in captures) for (w in widths) {
  for (d in c("0", "1")) jobs[[length(jobs) + 1L]] <- list(cap = cap, width = w, debug = d, mutation = "none")
  if ("--mutations" %in% commandArgs(TRUE)) {
    for (m in mutations) jobs[[length(jobs) + 1L]] <- list(cap = cap, width = w, debug = "0", mutation = m)
  }
}
rscript <- normalizePath(file.path(R.home("bin"), "Rscript.exe"), winslash = "\\")
csv <- function(j) file.path(scratch, sprintf("%s_w%s_d%s_%s.csv", sub("\\.rds$", "", basename(j$cap)), j$width, j$debug, j$mutation))
done <- function(j) file.exists(paste0(csv(j), ".exit"))
launch <- function(j) {
  args <- c(file.path(here, "prep_parity.R"), paste0("--lib=", arg("lib")), paste0("--capture=", j$cap),
            paste0("--width=", j$width), paste0("--orient=", orient), paste0("--debug=", j$debug),
            paste0("--mutation=", j$mutation), paste0("--plain=", arg("plain", "")), paste0("--out=", csv(j)), if ("--private" %in% commandArgs(TRUE)) "--private")
  # The child's exit status lands in a marker file; output goes to a log.
  f <- csv(j)
  cmd <- sprintf("\"%s\" %s > \"%s.log\" 2>&1 && echo 0 > \"%s.exit\" || echo 1 > \"%s.exit\"", rscript,
                 paste(sprintf("\"%s\"", args), collapse = " "), f, f, f)
  system2("cmd", c("/s", "/c", paste0("\"", cmd, "\"")), wait = FALSE)
}
max_jobs <- as.integer(arg("jobs", "6"))
pending <- jobs
running <- list()
t0 <- proc.time()[["elapsed"]]
while (length(pending) || length(running)) {
  running <- Filter(Negate(done), running)
  while (length(pending) && length(running) < max_jobs) {
    launch(pending[[1L]])
    running[[length(running) + 1L]] <- pending[[1L]]
    pending <- pending[-1L]
  }
  Sys.sleep(1)
}
rows <- lapply(jobs, function(j) {
  status <- suppressWarnings(as.integer(trimws(readLines(paste0(csv(j), ".exit"), warn = FALSE)[[1L]])))
  res <- if (file.exists(csv(j))) utils::read.csv(csv(j), colClasses = c(first_difference = "character")) else NULL
  failed <- if (is.null(res)) NA_character_ else paste(res$check[res$pass < res$n], collapse = ";")
  data.frame(capture = basename(j$cap), width = j$width, debug = j$debug, mutation = j$mutation,
             exit = status, checks = if (is.null(res)) NA_integer_ else nrow(res),
             calls = if (is.null(res)) NA_integer_ else sum(res$n), failing_checks = failed,
             verdict = if (j$mutation == "none") {
               if (identical(status, 0L) && !is.null(res) && !nzchar(failed)) "pass" else "FAIL"
             } else if (!is.null(res) && nzchar(failed)) "caught" else if (is.null(res)) "caught (error)" else "MISSED")
})
out <- do.call(rbind, rows)
print(out, right = FALSE, row.names = FALSE)
cat(sprintf("%d runs in %.0fs\n", nrow(out), proc.time()[["elapsed"]] - t0))
if (any(startsWith(commandArgs(TRUE), "--out="))) utils::write.csv(out, arg("out"), row.names = FALSE)
if (any(out$verdict %in% c("FAIL", "MISSED"))) quit(save = "no", status = 1L)
