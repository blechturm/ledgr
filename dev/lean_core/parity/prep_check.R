# LDG-3216 checker: runs prep_parity.R for each requested capture at each
# hydration chunk width and debug setting, and each registered hydration
# mutation, in parallel child processes (never during a timing window).
# Every parity run must pass and every mutation must fail.
#
#   Rscript dev/lean_core/parity/prep_check.R --lib=<pinned library>
#     --captures=<capture.rds,...> --chunks=<8,12|run> --scratch=<empty dir>
#     [--mutations[=<name,...>]] [--jobs=6] [--private] [--out=<evidence csv>]

here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "(=|$)"), commandArgs(TRUE), value = TRUE)
  if (!length(hit)) return(default %||% stop("--", name, "= is required", call. = FALSE))
  sub(paste0("^--", name, "=?"), "", hit[[1L]])
}
scratch <- arg("scratch")
dir.create(scratch, recursive = TRUE, showWarnings = FALSE)
captures <- strsplit(arg("captures"), ",")[[1L]]
chunks <- strsplit(arg("chunks", "8,12"), ",")[[1L]]
mutations <- c("chunk_edge_bar_dropped", "chunk_edge_bar_fetched_twice", "duplicate_within_chunk_not_refused")
# --mutations runs these three; --mutations=<names> runs the named ones (the
# axis mutation, axis_last_session_dropped, needs a bar-native capture).
if (any(startsWith(commandArgs(TRUE), "--mutations="))) mutations <- strsplit(arg("mutations"), ",")[[1L]]
jobs <- list()
for (cap in captures) for (w in chunks) {
  for (d in c("0", "1")) jobs[[length(jobs) + 1L]] <- list(cap = cap, chunk = w, debug = d, mutation = "none")
  if (any(grepl("^--mutations(=|$)", commandArgs(TRUE)))) {
    for (m in mutations) jobs[[length(jobs) + 1L]] <- list(cap = cap, chunk = w, debug = "0", mutation = m)
  }
}
rscript <- normalizePath(file.path(R.home("bin"), "Rscript.exe"), winslash = "\\")
csv <- function(j) file.path(scratch, sprintf("%s_c%s_d%s_%s.csv", sub("\\.rds$", "", basename(j$cap)), j$chunk, j$debug, j$mutation))
done <- function(j) file.exists(paste0(csv(j), ".exit"))
launch <- function(j) {
  args <- c(file.path(here, "prep_parity.R"), paste0("--lib=", arg("lib")), paste0("--capture=", j$cap),
            paste0("--chunk=", j$chunk), paste0("--debug=", j$debug),
            paste0("--mutation=", j$mutation), paste0("--out=", csv(j)), if ("--private" %in% commandArgs(TRUE)) "--private")
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
  data.frame(capture = basename(j$cap), chunk = j$chunk, debug = j$debug, mutation = j$mutation,
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
