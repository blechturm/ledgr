# Reference cost table: median wall time per call of common R operations at
# ledgr's hot-path scale (n = 500 instruments, 1,260 pulses).
# Usage: Rscript costs.R <ledgr lib> <out.csv>
# <ledgr lib> is a library holding an installed ledgr build (R CMD INSTALL);
# the ledgr rows (ledgr_utc, ledgr_iso_utc, ...) measure that build.
args <- commandArgs(TRUE)
suppressPackageStartupMessages({
  library(ledgr, lib.loc = args[[1]])
  library(microbenchmark)
})
set.seed(1)
n <- 500L
ids <- sprintf("P%04d", seq_len(n))
ids_shuf <- sample(ids)
ids_half <- sample(ids, n / 2)
num <- runif(n); num2 <- runif(n)
lgl <- num > 0.5
num_copy <- num + 0
ids_copy <- paste0(ids)
idx <- sample.int(n)
nv <- stats::setNames(num, ids)
lst <- as.list(num)
named_lst <- stats::setNames(as.list(num), ids)
env <- list2env(stats::setNames(as.list(rep(TRUE, n)), ids), hash = TRUE)
mat <- matrix(runif(n * 1260), n, 1260)
cols8 <- stats::setNames(replicate(8, runif(n), simplify = FALSE),
                         c("open", "high", "low", "close", "volume", "a", "b", "c"))
cols8$instrument_id <- ids
df8 <- as.data.frame(cols8, stringsAsFactors = FALSE)
df54 <- df8[1:54, ]
pct <- as.POSIXct("2021-03-04 21:00:00", tz = "UTC")
pct_v <- pct + 86400 * (seq_len(n) - 1)
epoch <- as.numeric(pct)
epoch_v <- as.numeric(pct_v)
lt <- as.POSIXlt(pct)
iso <- "2021-03-04T21:00:00Z"
iso_v <- format(pct_v, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
day <- as.Date("2021-03-04")
state <- list(above = lgl, usable = !lgl)
fill_meta <- list(lot_id = 12L, side = "BUY", qty = 100, price = 101.25,
                  fee = 0, reason = "rebalance")
fill_json <- yyjsonr::write_json_str(fill_meta, auto_unbox = TRUE)
state_json <- yyjsonr::write_json_str(state)
big_env <- new.env()
ctx_list <- list(ts_utc = iso, universe = ids, cash = 1e7, equity = 1e7, close = nv)
ctx_env <- list2env(ctx_list)
s3_obj <- structure(list(x = 1), class = "ledgr_bench_thing")
print.ledgr_bench_thing <- function(x, ...) invisible(x)
ledgr_bench_generic <- function(x) UseMethod("ledgr_bench_generic")
ledgr_bench_generic.ledgr_bench_thing <- function(x) 1
ledgr_bench_generic.default <- function(x) 0
noop <- function() NULL
factory <- function(v) { force(v); function(i) v[i] }
with_exit <- function() { on.exit(NULL); 1 }
noop_args <- function(a, b, c) a
choice_fn <- function(type = c("market", "limit", "stop")) match.arg(type)
con <- DBI::dbConnect(duckdb::duckdb())
DBI::dbWriteTable(con, "fills", df54[0, ])
DBI::dbWriteTable(con, "bars", df8[0, ])
DBI::dbExecute(con, "CREATE TABLE one (ts DOUBLE, id VARCHAR, qty DOUBLE)")

# group, case, scale note, expression
cases <- list(
  # --- baseline
  list("baseline", "empty closure call `f()`", "scalar", quote(noop())),
  list("baseline", "closure call with 3 args", "scalar", quote(noop_args(1, 2, 3))),
  list("baseline", "`do.call(f, list(1, 2, 3))`", "scalar", quote(do.call(noop_args, list(1, 2, 3)))),
  list("baseline", "S3 dispatch via `UseMethod`", "scalar", quote(ledgr_bench_generic(s3_obj))),
  list("baseline", "`inherits(x, \"cls\")`", "scalar", quote(inherits(s3_obj, "ledgr_bench_thing"))),
  list("baseline", "`match.arg()` on 3 choices", "scalar", quote(choice_fn("limit"))),
  list("baseline", "`stopifnot(is.numeric(x))`", "scalar", quote(stopifnot(is.numeric(epoch)))),
  list("baseline", "`if (!is.numeric(x)) stop()`", "scalar", quote(if (!is.numeric(epoch)) stop("no"))),
  list("baseline", "`tryCatch(1, error = )`", "scalar", quote(tryCatch(1, error = function(e) 2))),
  list("baseline", "`withCallingHandlers(1, warning = )`", "scalar", quote(withCallingHandlers(1, warning = function(w) NULL))),
  list("baseline", "`suppressWarnings(1)`", "scalar", quote(suppressWarnings(1))),
  list("baseline", "`new.env()`", "scalar", quote(new.env(parent = emptyenv()))),
  list("baseline", "`Sys.time()`", "scalar", quote(Sys.time())),
  list("baseline", "create a closure `function(x) x`", "scalar", quote(function(x) x)),
  list("baseline", "closure factory call with `force()`", "scalar", quote(factory(num))),
  list("baseline", "`on.exit()` in a called function", "scalar", quote(with_exit())),
  list("baseline", "`env[[k]] <- v` assign", "scalar", quote(big_env[["k"]] <- 1)),
  list("baseline", "`assign(k, v, envir = env)`", "scalar", quote(assign("k", 1, envir = big_env))),
  list("baseline", "`x %||% y`", "scalar", quote(NULL %||% 1)),
  list("baseline", "`isTRUE(x)`", "scalar", quote(isTRUE(TRUE))),
  list("string", "`grepl(regex, s)` scalar", "scalar", quote(grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}T", iso))),
  list("string", "`grepl(s, fixed = TRUE)` scalar", "scalar", quote(grepl("T", iso, fixed = TRUE))),
  list("string", "`startsWith(s, p)` scalar", "scalar", quote(startsWith(iso, "2021"))),
  list("string", "`sub(regex, r, s)` scalar", "scalar", quote(sub("Z$", "", iso))),
  list("string", "`paste0(a, b)` scalar", "scalar", quote(paste0("P", "0001"))),
  list("string", "`sprintf(\"%s_%d\", a, i)` scalar", "scalar", quote(sprintf("%s_%d", "P", 1L))),
  list("string", "`nchar(s)` scalar", "scalar", quote(nchar(iso))),
  list("string", "`as.character(1.5)` scalar", "scalar", quote(as.character(1.5))),
  list("string", "`format(1.5, nsmall = 2)` scalar", "scalar", quote(format(1.5, nsmall = 2))),
  list("string", "`deparse(quote(f(x)))`", "scalar", quote(deparse(quote(f(x))))),

  # --- time
  list("time", "`as.numeric(<POSIXct>)`", "scalar", quote(as.numeric(pct))),
  list("time", "`unclass(<POSIXct>)`", "scalar", quote(unclass(pct))),
  list("time", "`.POSIXct(epoch, tz = \"UTC\")`", "scalar", quote(.POSIXct(epoch, tz = "UTC"))),
  list("time", "`as.POSIXct(<POSIXct>, tz = \"UTC\")`", "scalar", quote(as.POSIXct(pct, tz = "UTC"))),
  list("time", "`as.POSIXct(epoch, tz = \"UTC\")`", "scalar", quote(as.POSIXct(epoch, tz = "UTC"))),
  list("time", "`as.POSIXct(<ISO chr>, format = )`", "scalar", quote(as.POSIXct(iso, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"))),
  list("time", "`as.POSIXct(<chr>)` without format", "scalar", quote(as.POSIXct("2021-03-04 21:00:00", tz = "UTC"))),
  list("time", "`as.POSIXlt(<POSIXct>)`", "scalar", quote(as.POSIXlt(pct))),
  list("time", "`as.numeric(<POSIXlt>)`", "scalar", quote(as.numeric(lt))),
  list("time", "`format(<POSIXct>, ISO)`", "scalar", quote(format(pct, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))),
  list("time", "`as.Date(<POSIXct>)`", "scalar", quote(as.Date(pct))),
  list("time", "`as.POSIXct(<Date>)`", "scalar", quote(as.POSIXct(day))),
  list("time", "`ledgr_utc(<POSIXct>)`", "scalar", quote(ledgr:::ledgr_utc(pct))),
  list("time", "`ledgr_utc(<ISO chr>)`", "scalar", quote(ledgr:::ledgr_utc(iso))),
  list("time", "`ledgr_iso_utc(<POSIXct>)`", "scalar", quote(ledgr:::ledgr_iso_utc(pct))),
  list("time", "`ledgr_normalize_ts_utc(<ISO chr>)`", "scalar", quote(ledgr:::ledgr_normalize_ts_utc(iso))),
  list("time", "epoch compare `e1 <= e2`", "scalar", quote(epoch <= epoch)),
  list("time", "POSIXct compare `t1 <= t2`", "scalar", quote(pct <= pct)),
  list("time", "`as.numeric(<POSIXct>)` x500", "500", quote(as.numeric(pct_v))),
  list("time", "`format(<POSIXct>)` x500 (vectorised)", "500", quote(format(pct_v, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))),
  list("time", "`as.POSIXct(<ISO chr>, format = )` x500", "500", quote(as.POSIXct(iso_v, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"))),
  list("time", "`ledgr_utc(<ISO chr>)` x500 (vectorised)", "500", quote(ledgr:::ledgr_utc(iso_v))),
  list("time", "`findInterval(epoch, epochs)` over 500", "500", quote(findInterval(epoch, epoch_v))),

  # --- construction
  list("construction", "`data.frame()` 500 x 9", "500", quote(data.frame(cols8, stringsAsFactors = FALSE))),
  list("construction", "`as.data.frame(<list>)` 500 x 9", "500", quote(as.data.frame(cols8, stringsAsFactors = FALSE))),
  list("construction", "`list2DF(<list>)` 500 x 9", "500", quote(list2DF(cols8))),
  list("construction", "`structure(<list>, class = \"data.frame\")` 500 x 9", "500",
       quote(structure(cols8, class = "data.frame", row.names = c(NA_integer_, -500L)))),
  list("construction", "`tibble::tibble()` 500 x 9", "500", quote(tibble::tibble(!!!cols8))),
  list("construction", "`tibble::new_tibble()` 500 x 9", "500", quote(tibble::new_tibble(cols8, nrow = 500L))),
  list("construction", "`collapse::qDF(<list>)` 500 x 9", "500", quote(collapse::qDF(cols8))),
  list("construction", "`rbind()` two 54-row frames", "54", quote(rbind(df54, df54))),
  list("construction", "`df[rows, ]` 54 of 500 rows", "54", quote(df8[1:54, , drop = FALSE])),
  list("construction", "`df[lgl, ]` logical filter of 500 rows", "500", quote(df8[lgl, , drop = FALSE])),
  list("construction", "`df$col` read", "scalar", quote(df8$close)),
  list("construction", "`df[[\"col\"]]` read", "scalar", quote(df8[["close"]])),
  list("construction", "`df$col <- x` write (shallow copy)", "500", quote({d <- df8; d$close <- num; d})),
  list("construction", "`list(...)` of 8 vectors", "scalar", quote(list(num, num, num, num, num, num, num, num))),
  list("construction", "`matrix(x, 500, 8)`", "500", quote(matrix(num, n, 8L))),
  list("construction", "`numeric(500)`", "500", quote(numeric(n))),
  list("construction", "`rep(NA_real_, 500)`", "500", quote(rep(NA_real_, n))),
  list("construction", "`setNames(x, ids)` 500", "500", quote(stats::setNames(num, ids))),
  list("construction", "`names(x) <- ids` 500", "500", quote({x <- num; names(x) <- ids; x})),
  list("construction", "`unname(x)` 500", "500", quote(unname(nv))),
  list("construction", "`as.list(x)` 500", "500", quote(as.list(num))),
  list("construction", "`unlist(<list of 500>)`", "500", quote(unlist(named_lst))),
  list("construction", "`list2env()` 500 names", "500", quote(list2env(named_lst, hash = TRUE))),
  list("construction", "`c(x, y)` 500 + 500", "500", quote(c(num, num2))),
  list("construction", "`x[length(x) + 1] <- v` grow by one", "scalar", quote({x <- num; x[length(x) + 1L] <- 1; x})),

  # --- lookup and matching
  list("lookup", "`match(ids, ids)` 500 in 500", "500", quote(match(ids_shuf, ids))),
  list("lookup", "`ids %in% ids` 500 in 500", "500", quote(ids_shuf %in% ids)),
  list("lookup", "`collapse::fmatch()` 500 in 500", "500", quote(collapse::fmatch(ids_shuf, ids))),
  list("lookup", "`match(id, ids)` 1 in 500", "scalar", quote(match("P0250", ids))),
  list("lookup", "`id %in% ids` 1 in 500", "scalar", quote("P0250" %in% ids)),
  list("lookup", "`setdiff(ids, half)` 500", "500", quote(setdiff(ids, ids_half))),
  list("lookup", "`intersect(ids, half)` 500", "500", quote(intersect(ids, ids_half))),
  list("lookup", "`unique(ids)` 500", "500", quote(unique(ids))),
  list("lookup", "`duplicated(ids)` 500", "500", quote(duplicated(ids))),
  list("lookup", "`identical()` 500 chr, differ at first", "500", quote(identical(ids, ids_shuf))),
  list("lookup", "`identical()` 500 chr, equal copies", "500", quote(identical(ids, ids_copy))),
  list("lookup", "`identical()` 500 num, equal copies", "500", quote(identical(num, num_copy))),
  list("lookup", "`all.equal(x, y)` 500 num", "500", quote(all.equal(num, num))),
  list("lookup", "`nv[\"id\"]` by name, 500 names", "scalar", quote(nv["P0250"])),
  list("lookup", "`nv[[\"id\"]]` by name, 500 names", "scalar", quote(nv[["P0250"]])),
  list("lookup", "`nv[[i]]` by position", "scalar", quote(nv[[250L]])),
  list("lookup", "`named_list$id` 500 names", "scalar", quote(named_lst$P0250)),
  list("lookup", "`exists(id, env)` hashed env", "scalar", quote(exists("P0250", envir = env, inherits = FALSE))),
  list("lookup", "`env[[id]]` hashed env", "scalar", quote(env[["P0250"]])),
  list("lookup", "`get0(id, env)` hashed env", "scalar", quote(get0("P0250", envir = env, inherits = FALSE))),
  list("lookup", "`ctx$field` on a list", "scalar", quote(ctx_list$cash)),
  list("lookup", "`ctx$field` on an environment", "scalar", quote(ctx_env$cash)),
  list("lookup", "`which(lgl)` 500", "500", quote(which(lgl))),

  # --- vector work on 500
  list("vector", "`x + y` 500", "500", quote(num + num2)),
  list("vector", "`x[idx]` gather 500", "500", quote(num[idx])),
  list("vector", "`x[idx] <- y` scatter 500 (copy)", "500", quote({x <- num; x[idx] <- num2; x})),
  list("vector", "`collapse::setv(x, idx, y)` in place", "500", quote(collapse::setv(num, idx, num2, vind1 = TRUE))),
  list("vector", "`mat[, j]` column of 500 x 1260", "500", quote(mat[, 630L])),
  list("vector", "`mat[i, j]` single cell", "scalar", quote(mat[250L, 630L])),
  list("vector", "`sum(x)` 500", "500", quote(sum(num))),
  list("vector", "`is.finite(x)` 500", "500", quote(is.finite(num))),
  list("vector", "`ifelse(lgl, x, y)` 500", "500", quote(ifelse(lgl, num, num2))),
  list("vector", "`pmax(x, y)` 500", "500", quote(pmax(num, num2))),
  list("vector", "`order(x)` 500 num", "500", quote(order(num))),
  list("vector", "`order(ids)` 500 chr, radix", "500", quote(order(ids_shuf, method = "radix"))),
  list("vector", "`sort(ids)` 500 chr, default", "500", quote(sort(ids_shuf))),
  list("vector", "`paste0(\"x_\", ids)` 500", "500", quote(paste0("x_", ids))),
  list("vector", "`sprintf(\"%.4f\", x)` 500", "500", quote(sprintf("%.4f", num))),
  list("vector", "`as.character(x)` 500 num", "500", quote(as.character(num))),
  list("vector", "`vapply(x, f, numeric(1))` 500", "500", quote(vapply(num, function(v) v * 2, numeric(1)))),
  list("vector", "`lapply(x, f)` 500", "500", quote(lapply(num, function(v) v * 2))),
  list("vector", "`for` loop 500 scalar writes", "500", quote({x <- numeric(n); for (i in seq_len(n)) x[i] <- num[i] * 2; x})),
  list("vector", "`Map(f, x, y)` 500", "500", quote(Map(function(a, b) a + b, num, num2))),
  list("vector", "`split(x, g)` 500 into 10", "500", quote(split(num, rep_len(1:10, n)))),
  list("vector", "`tabulate(g)` 500", "500", quote(tabulate(rep_len(1:10, n)))),
  list("vector", "`table(g)` 500", "500", quote(table(rep_len(1:10, n)))),

  # --- serialisation and hashing
  list("serialise", "yyjsonr encode small fill record", "scalar", quote(yyjsonr::write_json_str(fill_meta, auto_unbox = TRUE))),
  list("serialise", "yyjsonr parse small fill record", "scalar", quote(yyjsonr::read_json_str(fill_json))),
  list("serialise", "yyjsonr encode state (2 x 500 lgl)", "500", quote(yyjsonr::write_json_str(state))),
  list("serialise", "yyjsonr parse state (2 x 500 lgl)", "500", quote(yyjsonr::read_json_str(state_json))),
  list("serialise", "jsonlite encode small fill record", "scalar", quote(jsonlite::toJSON(fill_meta, auto_unbox = TRUE))),
  list("serialise", "`ledgr_canonical_json_encode()` small fill record", "scalar", quote(ledgr:::ledgr_canonical_json_encode(fill_meta))),
  list("serialise", "`digest(sha256)` of short string", "scalar", quote(digest::digest(fill_json, algo = "sha256", serialize = FALSE))),
  list("serialise", "`openssl::sha256()` of short string", "scalar", quote(openssl::sha256(fill_json))),
  list("serialise", "`serialize(x, NULL)` 500 num", "500", quote(serialize(num, NULL))),

  # --- DuckDB
  list("duckdb", "`dbGetQuery(\"SELECT 1\")`", "scalar", quote(DBI::dbGetQuery(con, "SELECT 1"))),
  list("duckdb", "`dbExecute()` insert 1 row, parameterised", "scalar",
       quote(DBI::dbExecute(con, "INSERT INTO one VALUES (?, ?, ?)", params = list(epoch, "P0001", 1)))),
  list("duckdb", "`dbAppendTable()` 54 rows x 9", "54", quote(DBI::dbAppendTable(con, "fills", df54))),
  list("duckdb", "`dbAppendTable()` 500 rows x 9", "500", quote(DBI::dbAppendTable(con, "bars", df8))),
  list("duckdb", "`duckdb_register()` + unregister 500 x 9", "500",
       quote({duckdb::duckdb_register(con, "tmp_view", df8); duckdb::duckdb_unregister(con, "tmp_view")}))
)

# Each case becomes a byte-compiled closure so it is measured as package
# code runs; the closure call itself is the "empty closure call" floor.
bench_env <- environment()
run_case <- function(case) {
  f <- compiler::cmpfun(eval(call("function", as.pairlist(alist()), case[[4]]), bench_env))
  for (i in 1:20) f()
  probe <- system.time(for (i in 1:200) f())[["elapsed"]] / 200
  # Fast cases run 100 times per measurement so the timer floor (about
  # 0.1 us on Windows) does not dominate; the result is divided back.
  inner <- if (probe < 20e-6 && case[[1]] != "duckdb") 100L else 1L
  if (inner > 1L) {
    body <- call("for", as.name(".k"), quote(seq_len(100L)), case[[4]])
    f <- compiler::cmpfun(eval(call("function", as.pairlist(alist()), body), bench_env))
    probe <- probe * inner
  }
  times <- as.integer(min(5000, max(100, 0.4 / max(probe, 1e-7))))
  if (case[[1]] == "duckdb") times <- min(times, 300L)
  m <- microbenchmark::microbenchmark(f(), times = times, unit = "ns")$time
  data.frame(group = case[[1]], case = case[[2]], scale = case[[3]],
             median_us = stats::median(m) / 1e3 / inner,
             p10_us = unname(stats::quantile(m, 0.1)) / 1e3 / inner,
             p90_us = unname(stats::quantile(m, 0.9)) / 1e3 / inner,
             reps = times, inner = inner)
}
out <- do.call(rbind, lapply(cases, run_case))
out$ms_per_run_1260 <- out$median_us * 1260 / 1e3
DBI::dbDisconnect(con, shutdown = TRUE)
write.csv(out, args[[2]], row.names = FALSE)
cat(sprintf("%d cases written\n", nrow(out)))
