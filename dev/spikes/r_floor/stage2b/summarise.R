# R-floor stage 2b: evidence tables from runs_raw.csv and the round-1 records.
#   summary.csv      median us per pulse for every arm and configuration, per clock
#   attribution.csv  per guarantee: reference standalone and accumulated prices, the
#                    lean loop's matching cells; then the lean stage hand-off residuals
#   parity.csv       economic and observable parity of the full reference
#   ratio.csv        the implementation overhead ratio per workload and clock

s2b_summarise <- function(out, raw, configs, cell_map, guarantees) {
  med <- function(x) stats::median(x, na.rm = TRUE)
  pulses <- 7200
  us <- function(v) 1e6 * v / pulses
  summ <- do.call(rbind, lapply(split(raw, list(raw$shape, raw$config), drop = TRUE), function(x)
    data.frame(shape = x$shape[[1L]], config = x$config[[1L]], rounds = nrow(x), loop_us = us(med(x$loop_s)),
               after_us = us(med(x$write_s)), fold_us = us(med(x$fold_s)), loop_min_us = us(min(x$loop_s)),
               loop_max_us = us(max(x$loop_s)))))
  summ <- summ[order(summ$shape, match(summ$config, c("lean", "clocked", names(configs)))), ]
  utils::write.csv(summ, file.path(out, "summary.csv"), row.names = FALSE)
  at <- function(s, cf, col = "loop_us") summ[[col]][summ$shape == s & summ$config == cf]
  attr_rows <- list(); ratio_rows <- list(); parity_rows <- list()
  for (s in unique(summ$shape)) {
    clk <- raw[raw$shape == s & raw$config == "clocked", ]
    cell <- function(names) if (length(names)) sum(vapply(names, function(n) us(med(clk[[n]])), 0)) else NA_real_
    floor_us <- at(s, "floor")
    for (j in seq_along(guarantees)) {
      gname <- guarantees[[j]]
      prev <- if (j == 1L) floor_us else at(s, paste0("acc_", j - 1L))
      attr_rows[[length(attr_rows) + 1L]] <- data.frame(shape = s, part = gname,
        reference_standalone_us = at(s, paste0("alone_", gname)) - floor_us,
        reference_accumulated_us = at(s, paste0("acc_", j)) - prev,
        lean_cells = paste(cell_map[[gname]], collapse = "+"), lean_us = cell(cell_map[[gname]]))
    }
    hand <- c(p2_residual = cell("p2") - cell(c("p2_context", "p2_strategy", "p2_sizing", "p2_risk")),
              p3_residual = cell("p3") - cell("p3_plan"), p4_residual = cell("p4") - cell(c("p4_fifo", "p4_facts")),
              p5_residual = cell("p5") - cell("p5_state"), p2_context = cell("p2_context"), p2_strategy = cell("p2_strategy"),
              helper = cell("helper"), p1 = cell("p1"), e = cell("e"))
    for (h in names(hand)) attr_rows[[length(attr_rows) + 1L]] <- data.frame(shape = s, part = h,
      reference_standalone_us = NA_real_, reference_accumulated_us = NA_real_, lean_cells = h, lean_us = hand[[h]])
    ratio_rows[[length(ratio_rows) + 1L]] <- data.frame(shape = s, lean_loop_us = at(s, "lean"), reference_loop_us = at(s, "acc_6"),
      floor_us = floor_us, ratio_loop = at(s, "lean") / at(s, "acc_6"),
      lean_loop_publish_us = at(s, "lean") + at(s, "lean", "after_us"), reference_loop_write_us = at(s, "acc_6") + at(s, "acc_6", "after_us"),
      ratio_loop_after = (at(s, "lean") + at(s, "lean", "after_us")) / (at(s, "acc_6") + at(s, "acc_6", "after_us")),
      lean_fold_us = at(s, "lean", "fold_us"), clock_cost_us = at(s, "clocked") - at(s, "lean"))
    a <- readRDS(file.path(out, sprintf("records_%s_ref.rds", s))); b <- readRDS(file.path(out, sprintf("records_%s_lean.rds", s)))
    same <- function(x, y) identical(unname(x), unname(y))
    fields <- function(part) all(vapply(names(a[[part]]), function(f) same(a[[part]][[f]], b[[part]][[f]]), TRUE))
    rf <- b$results$fills; re <- b$results$equity
    parity_rows[[length(parity_rows) + 1L]] <- data.frame(shape = s,
      economic_fills = fields("fills"), economic_equity = fields("equity"),
      economic_cash_positions_book = same(a$cash, b$cash) && same(a$pos, b$pos) && identical(a$book, b$book),
      results_fills = nrow(rf) == length(a$fills$qty) && same(rf$qty, a$fills$qty) && same(rf$price, a$fills$price) &&
        same(rf$fee, a$fills$fee) && same(rf$side, ifelse(a$fills$side > 0L, "BUY", "SELL")) &&
        same(rf$instrument_id, sprintf("P%02d", a$fills$k)),
      results_equity = same(re$cash, a$equity$cash) && same(re$positions_value, a$equity$positions_value),
      observable_decisions = fields("decisions"), observable_sizing = fields("sizing"),
      observable_rejections = fields("rejections"),
      observable_recon_notice_state = same(a$recon, b$recon) && same(a$pre, b$pre) && same(a$sizing_notice, b$sizing_notice) &&
        identical(a$strategy_state, b$strategy_state) && identical(a$status, b$status),
      fills = length(a$fills$qty), decisions = length(a$decisions$k), sizing = length(a$sizing$id))
  }
  attribution <- do.call(rbind, attr_rows); ratio <- do.call(rbind, ratio_rows); parity <- do.call(rbind, parity_rows)
  utils::write.csv(attribution, file.path(out, "attribution.csv"), row.names = FALSE)
  utils::write.csv(ratio, file.path(out, "ratio.csv"), row.names = FALSE)
  utils::write.csv(parity, file.path(out, "parity.csv"), row.names = FALSE)
  writeLines(c(paste("power plan:", paste(system2("powercfg", "/getactivescheme", stdout = TRUE), collapse = " ")),
               paste("R:", R.version.string), paste("collapse:", as.character(utils::packageVersion("collapse")))),
             file.path(out, "host.txt"))
  print(summ, row.names = FALSE, digits = 4); print(attribution, row.names = FALSE, digits = 3)
  print(ratio, row.names = FALSE, digits = 3); print(parity, row.names = FALSE)
  invisible(all(unlist(parity[vapply(parity, is.logical, TRUE)])))
}
