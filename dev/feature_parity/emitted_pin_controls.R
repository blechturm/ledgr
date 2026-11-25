# Controls for emitted_pin.R (LDG-3258): the unedited record must pass; one
# altered emitted fn body, one altered param, one altered declaration, a form
# removed from the record and the pin alike (population), and a duplicated
# component must each fail. Edited copies are written into --scratch.
#
#   Rscript emitted_pin_controls.R --record=<identity.R out dir> --scratch=<dir>
local({
  argv <- commandArgs(TRUE)
  arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), argv, value = TRUE)[[1L]])
  `%||%` <- function(x, y) if (is.null(x)) y else x
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
                                winslash = "/"))
  rscript <- file.path(R.home("bin"), "Rscript")
  rec <- utils::read.csv(file.path(arg("record"), "identities.csv"), stringsAsFactors = FALSE, colClasses = "character")
  pin <- utils::read.csv(file.path(here, "emitted_pin_expected.csv"), stringsAsFactors = FALSE, colClasses = "character")
  alter <- function(name) function(x) { x$value[x$name == name] <- paste0(x$value[x$name == name], "0"); x }
  drop_form <- function(x) x[!grepl(":ttr_mfi$", x$name), ]
  edits <- list(
    fn_body = list(record = alter("fn_body:ttr_rsi")),
    params = list(record = alter("params:ema_5")),
    declarations = list(record = alter("declarations:macd_histogram")),
    form_removed_both = list(record = drop_form, pin = drop_form),
    duplicate = list(record = function(x) rbind(x, x[x$name == "id:sma_20", ])))
  run <- function(record_dir, pin_csv) {
    args <- c(file.path(here, "emitted_pin.R"), paste0("--record=", record_dir))
    if (!is.null(pin_csv)) args <- c(args, paste0("--pin=", pin_csv))
    out <- suppressWarnings(system2(rscript, shQuote(args), stdout = TRUE, stderr = TRUE))
    list(status = attr(out, "status") %||% 0L, last = tail(out, 1L))
  }
  ok <- TRUE
  r <- run(arg("record"), NULL)
  cat(sprintf("%-18s exit %d  %s\n", "none", r$status, r$last))
  ok <- ok && r$status == 0L
  for (k in names(edits)) {
    d <- file.path(arg("scratch"), k)
    dir.create(d, recursive = TRUE, showWarnings = FALSE)
    utils::write.csv((edits[[k]]$record %||% identity)(rec), file.path(d, "identities.csv"), row.names = FALSE)
    pin_csv <- NULL
    if (!is.null(edits[[k]]$pin)) {
      pin_csv <- file.path(d, "pin.csv")
      utils::write.csv(edits[[k]]$pin(pin), pin_csv, row.names = FALSE)
    }
    r <- run(d, pin_csv)
    cat(sprintf("%-18s exit %d  %s\n", k, r$status, r$last))
    ok <- ok && r$status == 1L
  }
  cat(if (ok) "CONTROLS PASS\n" else "CONTROLS FAIL\n")
  if (!ok) quit(save = "no", status = 1L)
})
