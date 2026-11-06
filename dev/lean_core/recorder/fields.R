# The replay field lists, parsed from the accepted interface table so that
# they provably come from it. The only hand rules map the table's stage
# words to boundaries: "P1".."P5", "P1-P5", "stages", "every stage" -> the
# stages; "P2 skip", "P3 skip" -> the skip pair; "E stop" -> E_stop; "flush"
# (Section 8 only) -> E_flush. Parentheses and code spans are helper notes.
# A state row's `write` says the boundary is in Section 8's "Written by"
# column. Section 14 adds: stop installation reads the whole "fold state",
# and E's skip row belongs to the "Scheduled skip" boundary (P2 skip's slots).

lc_table_path <- function() {
  file.path(.lean_home, "..", "..", "inst", "design", "ledgr_v0_2_3_spec_packet", "lean_core_interface.md")
}

lc_table_section <- function(lines, heading) {
  start <- grep(paste0("^#+ ", heading), lines)
  stopifnot(length(start) == 1L)
  end <- start + which(grepl("^#", lines[-seq_len(start)]))[1L]
  lines[seq.int(start + 1L, if (is.na(end)) length(lines) else end - 1L)]
}

lc_table_rows <- function(section, first = "`") {
  rows <- grep(paste0("^\\| ", first), section, value = TRUE)
  lapply(strsplit(rows, " | ", fixed = TRUE), function(cells) sub("^\\| |\\s*\\|$", "", cells))
}

lc_stage_tokens <- function(cell, flush = FALSE) {
  text <- gsub("\\([^)]*\\)", " ", gsub("`[^`]*`", " ", cell))
  out <- character()
  for (m in regmatches(text, gregexpr("P[1-5]-P[1-5]", text))[[1L]]) {
    ends <- as.integer(substring(m, c(2L, 5L), c(2L, 5L)))
    out <- c(out, paste0("P", seq(ends[[1L]], ends[[2L]])))
  }
  text <- gsub("P[1-5]-P[1-5]", " ", text)
  skips <- regmatches(text, gregexpr("P[23] skip", text))[[1L]]
  out <- c(out, sub(" skip", "_skip", skips, fixed = TRUE))
  text <- gsub("P[23] skip", " ", text)
  out <- c(out, regmatches(text, gregexpr("\\bP[1-5]\\b", text))[[1L]])
  if (grepl("\\b(stages|every stage)\\b", text)) out <- c(out, paste0("P", 1:5))
  if (grepl("\\bE stop\\b", text)) out <- c(out, "E_stop")
  if (flush && grepl("\\bflush\\b", text)) out <- c(out, "E_flush")
  unique(out)
}

lc_code_names <- function(cell) gsub("`", "", regmatches(cell, gregexpr("`[^`]+`", cell))[[1L]])

lc_table_fields <- function(path = lc_table_path()) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  rows <- list()
  for (cells in lc_table_rows(lc_table_section(lines, "8\\. Fold state slots"))) {
    written <- lc_stage_tokens(cells[[5L]], flush = TRUE)
    stages <- union(written, lc_stage_tokens(cells[[6L]], flush = TRUE))
    rows[[length(rows) + 1L]] <- data.frame(boundary = stages, object = rep("state", length(stages)),
                                            field = rep(lc_code_names(cells[[1L]]), length(stages)),
                                            write = stages %in% written)
  }
  for (cells in lc_table_rows(lc_table_section(lines, "9\\. `services` fields"))) {
    mutable <- startsWith(cells[[3L]], "mutable")
    rows[[length(rows) + 1L]] <- expand.grid(boundary = c(lc_stage_tokens(cells[[4L]]), if (mutable) "services_mutable"),
                                             object = "services", field = lc_code_names(cells[[1L]]), write = NA,
                                             stringsAsFactors = FALSE)
  }
  out <- do.call(rbind, rows)
  out$object[out$boundary == "services_mutable"] <- "class"
  stop_row <- lc_table_rows(lc_table_section(lines, "14\\. Recorded boundaries"), first = "Stop installation")
  stopifnot(length(stop_row) == 1L)
  if (startsWith(stop_row[[1L]][[2L]], "fold state;")) {
    stop_writes <- out$field[out$boundary == "E_stop" & out$object == "state" & out$write]
    slots <- lc_fold_slots(path)
    out <- rbind(out[!(out$boundary == "E_stop" & out$object == "state"), ],
                 data.frame(boundary = "E_stop", object = "state", field = slots, write = slots %in% stop_writes))
  }
  skip <- out[out$boundary == "P2_skip" & out$object == "state", ]
  if (nrow(skip)) out <- rbind(out, transform(skip, boundary = "E_skip_row"))
  out <- unique(out)
  out[order(out$boundary, out$object, out$field, method = "radix"), , drop = FALSE]
}

lc_clock_allowlist <- function(path = lc_table_path()) {
  text <- paste(lc_table_section(readLines(path, warn = FALSE, encoding = "UTF-8"), "14\\. Recorded boundaries"),
                collapse = " ")
  para <- regmatches(text, regexpr("Only these clock fields are dropped:.*?Counters are compared", text, perl = TRUE))
  stopifnot(length(para) == 1L)
  # "the `telemetry` fields t_pulse, ..." names the environment that holds them.
  unique(lc_code_names(gsub("`[^`]+` fields", "", para)))
}

lc_fold_slots <- function(path = lc_table_path()) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  unlist(lapply(lc_table_rows(lc_table_section(lines, "8\\. Fold state slots")), function(cells) lc_code_names(cells[[1L]])))
}
