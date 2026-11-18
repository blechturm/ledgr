# The oracle's fault controls (Cut 22 decision 2, LDG-3249). Each deliberate
# fault runs the --lib arm with that fault (runner.R --fault=) and must make
# check.R exit 1 with its own signal; the signal sets of the faults must be
# pairwise distinct; a runner failure fails the driver. all_fields (close
# review round 1, F3: the field selector returns all five fields, values
# unchanged) needs a library with the selector; whether --lib has it is
# checked before running, and on one without it the fault is recorded as not
# run. A missing arm, a missing case and a missing component must make
# check.R refuse (exit 2); the pin's observations with one reached
# treated-fields observation cleared, with the causality phase dropped, or
# with both outputs of the preparation observer lost on every refusing case
# in both arms (re-review 2, H1) must fail with treated_fields (exit 1); the
# pin against itself must pass.
# Writes one checker transcript per control and faults.csv into --evidence.
#
#   Rscript faults.R --lib=<arm library> --pin=<pin runner out dir> --scratch=<dir> --evidence=<dir>
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
  check <- function(name, candidate, pin_dir = pin) {
    out <- suppressWarnings(system2(rscript, c(file.path(here, "check.R"), paste0("--pin=", pin_dir),
                                               paste0("--candidate=", candidate)), stdout = TRUE, stderr = TRUE))
    status <- attr(out, "status") %||% 0L
    writeLines(c(sprintf("check.R --pin=<pin> --candidate=<%s>: exit %d", name, status), out),
               file.path(evidence, paste0(name, ".txt")))
    list(status = as.integer(status), signals = sub("^SIGNAL ([^ ]+) .*$", "\\1", grep("^SIGNAL ", out, value = TRUE)))
  }
  faults <- c(changed_value = "values", moved_na = "na", plane_reason = "planes",
              refusal_class = "refusal_class", narrowed_callback = "callback",
              reordered_causality = "causality", wrong_route = "route", all_fields = "treated_fields")
  # all_fields needs the field selector (candidate 2). Whether the library has
  # it is established before any run (re-review 1, G2): without it (the pin)
  # the fault is not run and is recorded as such; with it the fault must run
  # and be caught like every other. A runner failure fails the driver.
  has_selector <- local({
    ns <- loadNamespace("ledgr", lib.loc = normalizePath(arg("lib"), winslash = "/"))
    exists("ledgr_history_feature_fields", envir = ns, inherits = FALSE)
  })
  rows <- list()
  sets <- list()
  for (f in names(faults)) {
    if (identical(f, "all_fields") && !has_selector) {
      rows[[f]] <- data.frame(control = f, expected_exit = NA_integer_, exit = NA_integer_,
                              expected_signal = faults[[f]],
                              signals = "not run: the library has no field selector (checked before running)", ok = TRUE)
      next
    }
    out <- file.path(scratch, f)
    status <- system2(rscript, c(file.path(here, "runner.R"), paste0("--arm=pin_", f), paste0("--lib=", arg("lib")),
                                 paste0("--out=", out), paste0("--fault=", f)))
    if (!identical(as.integer(status), 0L)) {
      rows[[f]] <- data.frame(control = f, expected_exit = 1L, exit = NA_integer_, expected_signal = faults[[f]],
                              signals = paste("runner.R failed with exit", status), ok = FALSE)
      next
    }
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
  # Absent treated-fields evidence (re-review 1, G1): the pin's observations
  # with one reached observation cleared, or with only the causality phase
  # dropped everywhere, must each fail with the treated_fields signal.
  edited <- function(name, value) {
    dir <- file.path(scratch, name)
    dir.create(dir, showWarnings = FALSE)
    x <- obs
    x$value <- value
    utils::write.csv(x, file.path(dir, "observations.csv"), row.names = FALSE)
    file.copy(file.path(pin, "provenance.csv"), dir, overwrite = TRUE)
    dir
  }
  treated <- obs$component == "treated_fields"
  cleared <- which(treated & grepl("prep:", obs$value, fixed = TRUE))[[1L]]
  absent <- list(
    cleared_treated = edited("cleared_treated", replace(obs$value, cleared, "")),
    causality_dropped = edited("causality_dropped", ifelse(treated,
      gsub("^;|;$", "", gsub("(^|;)causality:[^;]*", "", obs$value)), obs$value)))
  for (name in names(absent)) {
    r <- check(name, absent[[name]])
    rows[[name]] <- data.frame(control = name, expected_exit = 1L, exit = r$status, expected_signal = "treated_fields",
                               signals = paste(sort(r$signals), collapse = ","),
                               ok = r$status == 1L && identical(unique(r$signals), "treated_fields"))
  }
  # Shared observer loss (re-review 2, H1): both outputs of the treated-fields
  # observer (the prep entries and prep_seen) removed on every refusing case,
  # in both arms alike, the independent reach kept. It must fail.
  case_key <- paste(obs$family, obs$case, sep = " | ")
  refusing <- case_key %in% case_key[obs$component == "refusal" & obs$value != "none"]
  lost <- obs$value
  hit <- refusing & treated
  lost[hit] <- gsub("^;|;$", "", gsub("(^|;)prep:[^;]*", "", lost[hit]))
  hit <- refusing & obs$component == "handoffs"
  lost[hit] <- sub("prep_seen=[0-9]+", "prep_seen=0", lost[hit])
  shared <- edited("shared_observer_loss", lost)
  r <- check("shared_observer_loss", shared, pin_dir = shared)
  rows$shared_observer_loss <- data.frame(control = "shared_observer_loss", expected_exit = 1L, exit = r$status,
                                          expected_signal = "treated_fields", signals = paste(sort(r$signals), collapse = ","),
                                          ok = r$status == 1L && identical(unique(r$signals), "treated_fields"))
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
