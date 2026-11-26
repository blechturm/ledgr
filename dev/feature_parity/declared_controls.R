# Cut 25 (LDG-3269, cut review 25 R3): controls on the declared comparison.
# With declared_expected.csv frozen (never regenerated here), each control
# edits a copy of the candidate's observations or of the declared file and
# runs check.R:
#   one declared case's values, na, planes or handoffs changed -> exit 1 with
#     that component's signal;
#   one undeclared case's values changed (an undeclared flip) -> exit 1;
#   the pin's observations as the candidate (the old NA refusal restored)
#     -> exit 1;
#   the declared file with one case missing, one row duplicated, or an
#     undeclared case added -> exit 2.
# Writes one transcript per control and declared_controls.csv into --evidence.
#
#   Rscript declared_controls.R --pin=<pin out> --candidate=<candidate out> --scratch=<dir> --evidence=<dir>
local({
  argv <- commandArgs(TRUE)
  arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), argv, value = TRUE)[[1L]])
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
                                winslash = "/"))
  rscript <- file.path(R.home("bin"), "Rscript.exe")
  pin <- arg("pin")
  cand <- arg("candidate")
  scratch <- arg("scratch")
  evidence <- arg("evidence")
  dir.create(scratch, recursive = TRUE, showWarnings = FALSE)
  dir.create(evidence, recursive = TRUE, showWarnings = FALSE)
  declared_file <- file.path(here, "declared_expected.csv")
  frozen <- unname(tools::md5sum(declared_file))
  check <- function(name, candidate, declared = declared_file) {
    out <- suppressWarnings(system2(rscript, c(file.path(here, "check.R"), paste0("--pin=", pin),
      paste0("--candidate=", candidate), paste0("--declared=", declared)), stdout = TRUE, stderr = TRUE))
    status <- attr(out, "status") %||% 0L
    writeLines(c(sprintf("check.R --candidate=<%s> --declared=<%s>: exit %d", name, basename(declared), status), out),
               file.path(evidence, paste0(name, ".txt")))
    list(status = as.integer(status), signals = sub("^SIGNAL ([^ ]+) .*$", "\\1", grep("^SIGNAL ", out, value = TRUE)),
         lines = out)
  }
  read_obs <- function(dir) utils::read.csv(file.path(dir, "observations.csv"), stringsAsFactors = FALSE,
                                            na.strings = character(), colClasses = "character")
  obs <- read_obs(cand)
  write_arm <- function(name, x) {
    dir <- file.path(scratch, name)
    dir.create(dir, showWarnings = FALSE)
    utils::write.csv(x, file.path(dir, "observations.csv"), row.names = FALSE)
    file.copy(file.path(cand, "provenance.csv"), dir, overwrite = TRUE)
    dir
  }
  keys <- utils::read.csv(file.path(here, "declared_cases.csv"), comment.char = "#", stringsAsFactors = FALSE)
  target <- keys$case[keys$case == "hostile_carry2|data_start|custom_volume_strict"]
  stopifnot(length(target) == 1L)
  rows <- list()
  # One declared case, one component at a time.
  for (cmp in c("values", "na", "planes", "handoffs")) {
    x <- obs
    hit <- x$family == "compute" & x$case == target & x$component == cmp
    stopifnot(sum(hit) == 1L)
    x$value[hit] <- if (cmp == "handoffs") sub("prep_reached=([0-9]+)", "prep_reached=99", x$value[hit]) else
      paste0(x$value[hit], "0")
    r <- check(paste0("declared_", cmp), write_arm(paste0("declared_", cmp), x))
    rows[[cmp]] <- data.frame(control = paste0("declared case ", cmp, " changed"), expected_exit = 1L, exit = r$status,
      expected_signal = cmp, signals = paste(sort(unique(r$signals)), collapse = ","),
      ok = r$status == 1L && cmp %in% r$signals &&
        any(grepl("candidate differs from the declared expectation", r$lines, fixed = TRUE)))
  }
  # An undeclared case changed: compared with the pin, so it fails.
  x <- obs
  hit <- which(x$family == "compute" & x$component == "values" & !(x$case %in% keys$case))[[1L]]
  x$value[[hit]] <- paste0(x$value[[hit]], "0")
  r <- check("undeclared_flip", write_arm("undeclared_flip", x))
  rows$undeclared <- data.frame(control = paste("undeclared case values changed:", x$case[[hit]]), expected_exit = 1L,
    exit = r$status, expected_signal = "values", signals = paste(sort(unique(r$signals)), collapse = ","),
    ok = r$status == 1L && "values" %in% r$signals && any(grepl("candidate differs from pin", r$lines, fixed = TRUE)))
  # The old NA refusal restored: the pin's own observations as the candidate.
  r <- check("restored_refusal", pin)
  rows$restored <- data.frame(control = "pin observations as candidate (NA refusal restored)", expected_exit = 1L,
    exit = r$status, expected_signal = "refusal_class", signals = paste(sort(unique(r$signals)), collapse = ","),
    ok = r$status == 1L && "refusal_class" %in% r$signals)
  # Malformed declarations.
  d_lines <- readLines(declared_file, warn = FALSE)
  header <- d_lines[startsWith(d_lines, "#")]
  d <- utils::read.csv(declared_file, comment.char = "#", colClasses = "character")
  write_declared <- function(name, x) {
    f <- file.path(scratch, paste0(name, ".csv"))
    con <- file(f, "wb"); writeLines(header, con, sep = "\n"); close(con)
    suppressWarnings(utils::write.table(x, f, sep = ",", row.names = FALSE, append = TRUE, qmethod = "double"))
    f
  }
  extra_case <- obs[obs$family == "compute" & obs$case == "hostile_carry2|data_start|close" &
                      obs$component %in% unique(d$component), c("family", "case", "component", "value")]
  malformed <- list(
    missing_case = d[d$case != target, ],
    duplicate_row = rbind(d, d[1L, ]),
    extra_case = rbind(d, extra_case))
  for (name in names(malformed)) {
    r <- check(paste0("declared_", name), cand, declared = write_declared(paste0("declared_", name), malformed[[name]]))
    rows[[name]] <- data.frame(control = paste("declared file:", name), expected_exit = 2L, exit = r$status,
      expected_signal = "", signals = paste(grep("^REFUSED", r$lines, value = TRUE), collapse = " "), ok = r$status == 2L)
  }
  r <- check("unchanged", cand)
  rows$unchanged <- data.frame(control = "candidate unchanged", expected_exit = 0L, exit = r$status, expected_signal = "",
    signals = "", ok = r$status == 0L)
  table <- do.call(rbind, rows)
  utils::write.csv(table, file.path(evidence, "declared_controls.csv"), row.names = FALSE)
  print(table, row.names = FALSE)
  unchanged_file <- identical(unname(tools::md5sum(declared_file)), frozen)
  cat("declared_expected.csv unchanged by the controls:", unchanged_file, "\n")
  if (!all(table$ok) || !unchanged_file) {
    cat("DECLARED CONTROLS FAIL\n")
    quit(save = "no", status = 1L)
  }
  cat("DECLARED CONTROLS PASS\n")
})
