.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all("C:/Users/maxth/Documents/GitHub/ledgr", quiet = TRUE, compile = FALSE))
axis <- sprintf("I%04d", 1:500); n <- 1000L
st <- list(month = "2000-01")
t0 <- Sys.time()
for (i in seq_len(n)) { st <- ledgr_fold_asset_state_normalize(st, axis, drop_exited = TRUE); st <- ledgr_fold_asset_state_normalize(st, axis) }
t1 <- Sys.time(); cat("normalize x2 per pulse ms", 1000 * as.numeric(difftime(t1, t0, units = "secs")) / n, "\n")
for (i in seq_len(n)) { st$month <- sprintf("m%d", i %% 50); j <- canonical_json(st) }
t2 <- Sys.time(); cat("canonical_json state per pulse ms", 1000 * as.numeric(difftime(t2, t1, units = "secs")) / n, " bytes", nchar(j), "\n")
meta <- list(fee = 0, cash_delta = -1234.5, position_delta = 10, realized_pnl = NULL)
for (i in seq_len(5000)) { meta$cash_delta <- -i * 1.37; j <- canonical_json(meta) }
t3 <- Sys.time(); cat("canonical_json fill meta us", 1e6 * as.numeric(difftime(t3, t2, units = "secs")) / 5000, "\n")
for (i in seq_len(5000)) { meta$cash_delta <- -i * 1.37; j2 <- ledgr:::ledgr_json_write_canonical_v2(meta[order(names(meta))]) }
t4 <- Sys.time(); cat("direct writer us", 1e6 * as.numeric(difftime(t4, t3, units = "secs")) / 5000, identical(as.character(j), as.character(j2)), "\n")
# equity facts growth
f <- function() { ef <- list(); g <- function(k) ef[[length(ef) + 1L]] <<- list(a = k, b = k); for (k in 1:7213) g(k); length(ef) }
t5 <- Sys.time(); f(); cat("equity_facts append 7213", as.numeric(difftime(Sys.time(), t5, units = "secs")), "\n")
