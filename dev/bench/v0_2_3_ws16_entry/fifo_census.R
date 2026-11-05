# FIFO row-kind census at the pin: every call into the one lot kernel,
# ledgr_lot_apply(book, input), classified by caller, operation and row kind,
# with every refusal it raises. Input to the WS16 FIFO family's coverage.
#
#   Rscript fifo_census.R --pkg=<ledgr source at the pin> --out=<dir> --source=<a0|fill_heavy|tests>
#
# a0:         every A0 workload (committed runs, in-process sweeps, readers).
# fill_heavy: the registered 500 x 1,260 SMA 5/10 run plus its fills and
#             equity reads.
# tests:      the pinned test suite, run in this process with the kernel
#             wrapped (tests that start other R processes are not observed).

local({
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])))
  source(file.path(here, "common.R"))
  source(file.path(here, "workloads.R"))
  assign("ws16_dir", here, envir = globalenv())
})
pkg <- normalizePath(ws16_need("pkg"), winslash = "/")
out <- ws16_out(ws16_need("out"))
src <- ws16_need("source")
stopifnot(src %in% c("a0", "fill_heavy", "tests"))
ws16_load_source(pkg)
ns <- asNamespace("ledgr")
op_fill <- get(".ledgr_lot_fill", envir = ns)
op_opening <- get(".ledgr_lot_opening", envir = ns)
op_disposition <- get(".ledgr_lot_disposition", envir = ns)
live_count <- get("ledgr_lot_book_live_count", envir = ns)

counts <- new.env()
bump <- function(key, by = 1) counts[[key]] <- (counts[[key]] %||% 0) + by
skip <- c("ledgr_lot_apply", "ledgr_lot_fill", "ledgr_lot_opening", "ledgr_lot_disposition",
          "ledgr_lot_apply_blocks")

row_kinds <- function(book, input, applied, book_after) {
  op <- input$operation
  m <- length(op)
  kind <- character(m)
  opening <- op == op_opening
  kind[opening] <- paste0("opening_", ifelse(input$qty[opening] > 0, "long", "short"),
                          "_basis_", ifelse(input$price[opening] > 0, "pos",
                                            ifelse(input$price[opening] < 0, "neg", "zero")))
  cons <- !opening
  if (any(cons)) {
    j <- which(cons)
    before <- applied$position_before[j]
    after <- applied$position_after[j]
    side <- input$side[j]
    close <- applied$close_qty[j] > 0
    open <- applied$open_qty[j] > 0
    lots_before <- live_count(book, input$pos[j])
    lots_after <- live_count(book_after, input$pos[j])
    consumed <- lots_before - lots_after + as.integer(open)
    base <- ifelse(before == 0, "from_flat",
            ifelse(!close, "add_same_side",
            ifelse(open, "reversal",
            ifelse(after == 0, "close_full", "close_partial"))))
    multi <- close & consumed >= 2L
    dust <- after == 0 & (before + side * input$qty[j]) != 0
    tag <- paste0(base, ifelse(multi, "+multi_lot", ""), ifelse(dust, "+dust_snap", ""))
    is_fill <- op[j] == op_fill
    tag[is_fill & input$fee[j] > 0] <- paste0(tag[is_fill & input$fee[j] > 0],
                                             ifelse(close[is_fill & input$fee[j] > 0] & open[is_fill & input$fee[j] > 0],
                                                    "+fee_split", "+fee"))
    disp <- op[j] == op_disposition
    tag[disp & input$price[j] == 0] <- paste0(tag[disp & input$price[j] == 0], "+zero_price")
    tag[disp & !is.na(input$realized_model_pnl[j])] <- paste0(tag[disp & !is.na(input$realized_model_pnl[j])], "+witness")
    kind[j] <- paste0(ifelse(is_fill, "fill_", "disposition_"), ifelse(side > 0, "buy_", "sell_"), tag)
  }
  kind
}

ws16_wrap("ledgr_lot_apply", function(orig) {
  force(orig)
  function(book, input) {
    caller <- ws16_caller(skip)
    op <- input$operation
    opname <- if (length(op)) {
      c("fill", "opening", "disposition")[match(op[[1L]], c(op_fill, op_opening, op_disposition))]
    } else {
      "empty"
    }
    res <- withCallingHandlers(orig(book, input), error = function(e) {
      bump(paste("refusal", caller, opname %||% "?", class(e)[[1L]], sep = "\t"))
    })
    m <- length(op)
    bump(paste("block", caller, opname, if (m >= 50) "50+" else if (m >= 10) "10-49" else if (m >= 2) "2-9" else as.character(m), sep = "\t"))
    for (k in row_kinds(book, input, res$applied, res$book)) bump(paste("row", caller, opname, k, sep = "\t"))
    res
  }
})

if (identical(src, "a0")) {
  source(file.path(ws16_dir, "..", "v0_2_3_output_freeze", "lib.R"))
  work <- file.path(tempdir(), "ws16_fifo_a0")
  dir.create(work, showWarnings = FALSE)
  for (id in names(a0_workloads)) cat(id, tryCatch({ a0_run_workload(id, work); "ok" },
                                                   error = function(e) conditionMessage(e)), "\n")
} else if (identical(src, "fill_heavy")) {
  work <- file.path(tempdir(), "ws16_fifo_fill")
  dir.create(work, showWarnings = FALSE)
  snap <- ledgr_snapshot_from_df(ws16_fill_heavy_bars(), db_path = file.path(work, "fill.duckdb"),
                                 snapshot_id = "ws16_fill", price_basis = "split_adjusted")
  bt <- suppressWarnings(ledgr_run(ws16_fill_heavy_experiment(snap), run_id = "ws16-fill", seed = 20260530L))
  invisible(ledgr_results(bt, "fills"))
  invisible(ledgr_results(bt, "equity"))
  close(bt)
  ledgr_snapshot_close(snap)
} else {
  res <- testthat::test_dir(file.path(pkg, "tests", "testthat"), load_package = "none",
                            reporter = "summary", stop_on_failure = FALSE, stop_on_warning = FALSE)
  df <- as.data.frame(res)
  ws16_write(data.frame(files = length(unique(df$file)), tests = nrow(df), failed = sum(df$failed),
                        errors = sum(df$error), skipped = sum(df$skipped)),
             file.path(out, "fifo_tests_outcome.csv"))
}

keys <- ls(counts)
parts <- strsplit(keys, "\t", fixed = TRUE)
pick <- function(kind, cols) {
  sel <- vapply(parts, `[[`, character(1), 1L) == kind
  if (!any(sel)) return(NULL)
  df <- as.data.frame(do.call(rbind, lapply(parts[sel], `[`, -1L)), stringsAsFactors = FALSE)
  names(df) <- cols
  df$n <- vapply(keys[sel], function(k) counts[[k]], numeric(1), USE.NAMES = FALSE)
  cbind(source = src, df[do.call(order, unname(as.list(df[cols]))), , drop = FALSE])
}
ws16_write(pick("row", c("caller", "operation", "kind")), file.path(out, paste0("fifo_rows_", src, ".csv")))
ws16_write(pick("block", c("caller", "operation", "block_rows")), file.path(out, paste0("fifo_blocks_", src, ".csv")))
ws16_write(pick("refusal", c("caller", "operation", "class")) %||% data.frame(source = src),
           file.path(out, paste0("fifo_refusals_", src, ".csv")))
cat("fifo census", src, "written to", out, "\n")
