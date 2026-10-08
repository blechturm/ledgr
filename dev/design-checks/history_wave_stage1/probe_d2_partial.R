suppressMessages(pkgload::load_all("C:/Users/maxth/Documents/GitHub/ledgr", quiet = TRUE, compile = FALSE))
day <- function(d, h = 0) as.POSIXct(as.Date("2020-01-01") + d - 1L, tz = "UTC") + h * 3600
noon <- function(d) day(d, 12)
rows <- data.frame(
  fact_id = c("f1", "f2"), instrument_id = "AAA",
  effective_from = c(day(3), day(5)), effective_to = c(day(9), day(7)), knowledge_time = c(day(3), day(5)),
  status = c("halted", "active"), source = "s", precedence = 1L,
  revision_id = NA_character_, supersedes_fact_id = c(NA, "f1"), provenance_json = "{}", stringsAsFactors = FALSE)
cat("f1 halted [3,9) known 3; f2 active [5,7) known 5, supersedes f1\n")
cat("constructor:", tryCatch({ ledgr_facts_trading_status(rows[, c("instrument_id","effective_from","effective_to","knowledge_time","status","source","precedence","fact_id","supersedes_fact_id")]); "accepted" }, error = function(e) class(e)[[1L]]), "\n")
data <- list(families = data.frame(family = "trading_status", scope_id = "instrument", stringsAsFactors = FALSE),
             status = rows, lifetime = data.frame(), membership = data.frame(), membership_sets = data.frame(), sessions = NULL)
p <- ledgr:::ledgr_availability_provider_build_prepared(data, list(universe = list(instrument_ids = "AAA"), availability = list(universe_rule = NULL)), "probe", function(...) NULL)
for (d in c(4, 6, 8)) cat(sprintf("  prepared provider (resolve_status) day %d: %s\n", d, unname(p$facts(noon(d), ids = "AAA")$status)))
cat("  ingest helper ledgr_status_runtime_conflicts truncates f1 at f2's start: f1 end becomes day 5, so on day 8 f1 is not 'usable' there.\n")
# Show the public inspection view too.
facts <- ledgr_facts(ledgr_facts_trading_status(rows[, c("instrument_id","effective_from","effective_to","knowledge_time","status","source","precedence","fact_id","supersedes_fact_id")]))
for (d in c(4, 6, 8)) {
  r <- ledgr_facts_resolve(facts, "trading_status", "instrument", at = noon(d), instruments = "AAA")$rows
  cat(sprintf("  ledgr_facts_resolve day %d: %s\n", d, paste(names(r), unlist(lapply(r, as.character)), sep = "=", collapse = " ")))
}
