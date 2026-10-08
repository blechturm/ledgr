suppressMessages(pkgload::load_all("C:/Users/maxth/Documents/GitHub/ledgr", quiet = TRUE, compile = FALSE))
day <- function(d) as.POSIXct(as.Date("2020-01-01") + d - 1L, tz = "UTC")
cat("== D3-F2: TTR rules: gap_contract and max cross-start gap (3000-bar walk, restart at 1001, compare after 600 bars)\n")
set.seed(11); n <- 3000; cl <- round(100 + cumsum(rnorm(n)), 4)
bars <- data.frame(instrument_id = "A", ts_utc = day(seq_len(n)), open = cl, high = cl + abs(rnorm(n)), low = cl - abs(rnorm(n)),
                   close = cl, volume = round(1e5 + 1e4 * runif(n)))
rules <- ledgr_ind_ttr_warmup_rules()
args_for <- function(fn) switch(fn, MACD = list(nFast = 12L, nSlow = 26L, nSig = 9L), list(n = 14L))
for (fn in rules$ttr_fn) {
  res <- tryCatch({
    ind <- do.call(ledgr_ind_ttr, c(list(fn, input = rules$input[rules$ttr_fn == fn]), args_for(fn)))
    full <- ledgr:::ledgr_compute_feature_series(bars, ind)
    late <- ledgr:::ledgr_compute_feature_series(bars[1001:n, ], ind)
    idx <- 1601:n
    g <- max(abs(full[idx] - late[idx - 1000]) / pmax(1, abs(full[idx])), na.rm = TRUE)
    sprintf("%-16s gap_contract=%-13s max_rel_gap=%.3g", fn, ind$gap_contract %||% "none", g)
  }, error = function(e) sprintf("%-16s ERROR %s", fn, conditionMessage(e)))
  cat(" ", res, "\n")
}
cat("ledgr_ind_ema(5) gap_contract:", ledgr_ind_ema(5L)$gap_contract %||% "none", "\n")
cat("ledgr_ind_sma(5) gap_contract:", ledgr_ind_sma(5L)$gap_contract %||% "none", "\n")

cat("\n== D5-F2: lifetime: same-assertion restatement vs opposing overlap\n")
lt <- function(assertion, known) tryCatch({ ledgr_facts_lifetime(data.frame(instrument_id = "X",
  effective_from = day(c(1, 1)), knowledge_time = day(known), assertion = assertion, fact_id = c("a", "b"))); "accepted" },
  error = function(e) paste("refused:", class(e)[[1L]]))
cat("  known_inactive then known_inactive (restated later):", lt(c("known_inactive", "known_inactive"), c(2, 9)), "\n")
cat("  known_active then known_inactive (opposing):", lt(c("known_active", "known_inactive"), c(2, 9)), "\n")

cat("\n== D1-F6: a fact known before it takes effect is accepted\n")
cat("  status known day 2, effective day 5:", tryCatch({ ledgr_facts_trading_status(data.frame(instrument_id = "X",
  effective_from = day(5), effective_to = day(7), knowledge_time = day(2), status = "halted", source = "s", precedence = 1L)); "accepted" },
  error = function(e) paste("refused:", class(e)[[1L]])), "\n")
cat("\n== D1-F7: constructors with knowledge_time\n")
for (f in c("ledgr_facts_sessions", "ledgr_facts_corporate_actions", "ledgr_facts_membership_snapshots", "ledgr_facts_lifetime")) {
  if (exists(f)) cat(sprintf("  %-34s formals: %s\n", f, paste(names(formals(get(f))), collapse = ", ")))
}
