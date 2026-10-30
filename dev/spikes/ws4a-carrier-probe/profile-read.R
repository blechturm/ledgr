# Stream the recorded Rprofmem facts; unpriced page records stay separate.
read_allocation_profile <- function(directory) {
    con <- file(file.path(directory, 'allocations.log'), open = 'r')
    accumulated <- page_counts <- numeric()
    add <- function(acc, values) {
      missing <- setdiff(names(values), names(acc))
      if (length(missing)) acc[missing] <- 0
      acc[names(values)] <- acc[names(values)] + values
      acc
    }
    repeat {
      lines <- readLines(con, n = 5000L, warn = FALSE)
      if (!length(lines)) break
      size <- suppressWarnings(as.numeric(substr(lines, 1L, pmax(0L, regexpr(' ', lines, fixed = TRUE) - 1L))))
      component <- rep('other_setup_results', length(lines))
      component[grepl('ledgr_fold_stage_commit', lines, fixed = TRUE)] <- 'commit'
      component[grepl('ledgr_fold_stage_decide', lines, fixed = TRUE)] <- 'decide'
      component[grepl('ledgr_fold_stage_observe_settle', lines, fixed = TRUE)] <- 'observe'
      component[grepl('ledgr_fold_stage_apply', lines, fixed = TRUE)] <- 'apply_other'
      component[grepl('ledgr_fold_stage_plan', lines, fixed = TRUE)] <- 'plan'
      event <- grepl('carrier_events|ledgr_event_buffer_|ledgr_fill_row_buffer_|stage_fill_event|flush_pulse_events|record_accounting_fact|write_fill_events', lines, perl = TRUE)
      inside_fold <- grepl('ledgr_fold_stage_apply|ledgr_fold_stage_commit', lines, perl = TRUE)
      component[event & inside_fold] <- 'event_batch'
      component[grepl('carrier_lots|ledgr_lot_apply_fill', lines, perl = TRUE)] <- 'lot_kernel'
      component[grepl('carrier_lots_typed', lines, fixed = TRUE)] <- 'lot_boundary'
      component[grepl('typed_lot_kernel', lines, fixed = TRUE)] <- 'lot_kernel'
      component[grepl('carrier_payload|ledgr_fill_event_payload', lines, perl = TRUE)] <- 'fill_payload'
      valid <- is.finite(size)
      if (any(valid)) accumulated <- add(accumulated, tapply(size[valid], component[valid], sum))
      page_counts <- add(page_counts, tapply(as.integer(startsWith(lines, 'new page')), component, sum))
    }
    close(con)
    keys <- sort(union(names(accumulated), names(page_counts)))
    totals <- accumulated[keys]; totals[is.na(totals)] <- 0
    names(totals) <- keys
    pages <- page_counts[keys]; pages[is.na(pages)] <- 0
    totals <- c(totals, total = sum(totals)); pages <- c(pages, total = sum(pages))
  data.frame(component = names(totals), bytes = as.numeric(totals),
    unpriced_new_pages = as.integer(pages))
}
