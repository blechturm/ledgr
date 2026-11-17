# The oracle's fault controls (Cut 22 decision 2, LDG-3249). Each deliberate
# fault runs the pin with that fault (runner.R --fault=) and must make
# check.R exit 1 with its own signal; the signal sets of the faults must be
# pairwise distinct. A missing arm, a missing case and a missing component
# must make check.R refuse (exit 2), and the pin against itself must pass.
# Writes one checker transcript per control and faults.csv into --evidence.
#
#   Rscript faults.R --lib=<pin library> --pin=<pin runner out dir> --scratch=<dir> --evidence=<dir>
local({
  argv <- commandArgs(TRUE)
  arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), argv, value = TRUE)[[1L]])
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
                                winslash = "/"))
  rscript <- file.path(R.home("bin"), "Rscript.exe")
  pin <- arg("pin")
  scratch <- arg("scratch")
  evidence <- arg("evidence")
  dir.create(scratch, recursive = TRUE, showWarnings = FALSE)
  dir.create(evidence, recursive = TRUE, showWarnings = FALSE)
  check <- function(name, candidate) {
    out <- suppressWarnings(system2(rscript, c(file.path(here, "check.R"), paste0("--pin=", pin),
                                               paste0("--candidate=", candidate)), stdout = TRUE, stderr = TRUE))
    status <- attr(out, "status") %||% 0L
    writeLines(c(sprintf("check.R --pin=<pin> --candidate=<%s>: exit %d", name, status), out),
               file.path(evidence, paste0(name, ".txt")))
    list(status = as.integer(status), signals = sub("^SIGNAL ([^ ]+) .*$", "\\1", grep("^SIGNAL ", out, value = TRUE)))
  }
  faults <- c(changed_value = "values", moved_na = "na", plane_reason = "planes",
              refusal_class = "refusal_class", narrowed_callback = "callback",
              reordered_causality = "causality", wrong_route = "route")
  rows <- list()
  sets <- list()
  for (f in names(faults)) {
    out <- file.path(scratch, f)
    status <- system2(rscript, c(file.path(here, "runner.R"), paste0("--arm=pin_", f), paste0("--lib=", arg("lib")),
                                 paste0("--out=", out), paste0("--fault=", f)))
    if (!identical(as.integer(status), 0L)) stop("runner.R failed for fault ", f)
    r <- check(f, out)
    sets[[f]] <- paste(sort(r$signals), collapse = ",")
    rows[[f]] <- data.frame(control = f, expected_exit = 1L, exit = r$status, expected_signal = faults[[f]],
                            signals = sets[[f]], ok = r$status == 1L && faults[[f]] %in% r$signals)
  }
  distinct <- !anyDuplicated(unlist(sets))
  # Refusals: a missing arm, a dropped case, a dropped component.
  obs <- utils::read.csv(file.path(pin, "observations.csv"), stringsAsFactors = FALSE, na.strings = character(),
                         colClasses = "character")
  mutate <- function(name, keep) {
    dir <- file.path(scratch, name)
    dir.create(dir, showWarnings = FALSE)
    utils::write.csv(obs[keep, ], file.path(dir, "observations.csv"), row.names = FALSE)
    dir
  }
  first_case <- obs$family == obs$family[[1L]] & obs$case == obs$case[[1L]]
  dropped_value <- which(obs$component == "values")[[1L]]
  controls <- list(
    missing_arm = file.path(scratch, "no_such_arm"),
    missing_case = mutate("missing_case", !first_case),
    missing_component = mutate("missing_component", seq_len(nrow(obs)) != dropped_value))
  for (name in names(controls)) {
    r <- check(name, controls[[name]])
    rows[[name]] <- data.frame(control = name, expected_exit = 2L, exit = r$status, expected_signal = "",
                               signals = "", ok = r$status == 2L)
  }
  r <- check("pin_against_pin", pin)
  rows$pin_against_pin <- data.frame(control = "pin_against_pin", expected_exit = 0L, exit = r$status,
                                     expected_signal = "", signals = "", ok = r$status == 0L)
  table <- do.call(rbind, rows)
  utils::write.csv(table, file.path(evidence, "faults.csv"), row.names = FALSE)
  print(table, row.names = FALSE)
  cat("fault signal sets pairwise distinct:", distinct, "\n")
  if (!all(table$ok) || !distinct) {
    cat("FAULTS FAIL\n")
    quit(save = "no", status = 1L)
  }
  cat("FAULTS PASS\n")
})
