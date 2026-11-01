# D20 on the final candidate (LDG-3169; design note Sections 3.4 and 6).
# detectors.R certifies base outcomes and binds deleted functions, so it does
# not run on the candidate; this evaluates its own unchanged route
# definitions (calls ... routes) against --base and runs the D20 witness
# cases and controls through check.R. Writes one row per Section 3.4 route
# with both boundary values; R8.01's base value is "absent" by design (the
# adapter arrives at LDG-3165), so a difference there is expected.
#
# Usage: Rscript d20.R --out=<dir> [--base=953338df]
a <- commandArgs(TRUE)
arg <- function(key, default = NULL) {
  z <- grep(paste0("^--", key, "="), a, value = TRUE)
  if (length(z)) sub(paste0("^--", key, "="), "", z[[1L]]) else default
}
here <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])), "../.."), winslash = "/")
root <- normalizePath(file.path(here, "../../.."), winslash = "/")
out <- arg("out"); dir.create(out, recursive = TRUE, showWarnings = FALSE)
want <- c("calls", "head_of", "heads", "txt", "assigns", "inject", "shape", "json_shapes", "defs", "sig", "cl", "routes", "w20")
for (e in parse(file.path(here, "detectors.R"), keep.source = FALSE)) {
  if (is.call(e) && identical(e[[1L]], as.name("<-")) && is.symbol(e[[2L]]) && as.character(e[[2L]]) %in% want) eval(e)
}
bdir <- tempfile("ws4a_base"); dir.create(bdir)
if (system2("git", c("-C", root, "archive", "-o", file.path(bdir, "b.tar"), arg("base", "953338df"), "R", "src"))) stop("git archive failed")
utils::untar(file.path(bdir, "b.tar"), exdir = bdir)
S_now <- defs(root); r_base <- routes(defs(bdir), bdir); r_now <- routes(S_now, root)
flat <- function(v) paste(if (is.null(names(v))) v else paste(names(v), v, sep = " = "), collapse = " || ")
res <- data.frame(route = names(r_base), identical = mapply(identical, r_base, r_now),
  base = vapply(r_base, flat, ""), candidate = vapply(r_now, flat, ""))
utils::write.csv(res, file.path(out, "d20-routes.csv"), row.names = FALSE)
check <- function(...) system2(file.path(R.home("bin"), "Rscript"), c(shQuote(file.path(here, "check.R")), "--base=HEAD",
  paste0("--out=", tempfile("d20", out)), ...), stdout = FALSE, stderr = FALSE)
S_mut <- S_now; S_mut$ledgr_fold_stage_commit <- inject(S_mut$ledgr_fold_stage_commit, "canonical_json(state_update)")
mut <- names(r_base)[!mapply(identical, r_now, routes(S_mut, root))]
ctl <- c(witnesses = check(paste0("--cases=", paste(w20, collapse = ","))), gut_C1_drop_notional = check("--gut=C1_drop_notional"))
cat(sprintf("%-6s %s\n", res$route, ifelse(res$identical, "identical", "DIFFERS")), sep = "")
cat("witness cases", paste(w20, collapse = ","), "check.R exit", ctl[["witnesses"]], "\n")
cat("control: injected P5 state encode changes routes:", mut, "(expected R8.04)\n")
cat("control: gut C1_drop_notional check.R exit", ctl[["gut_C1_drop_notional"]], "(expected 1)\n")
ok <- all(res$identical | res$route == "R8.01") && r_now$R8.01 != "absent" && ctl[["witnesses"]] == 0L &&
  identical(mut, "R8.04") && ctl[["gut_C1_drop_notional"]] == 1L
cat("d20:", if (ok) "PASS" else "FAIL", "\n")
quit(status = as.integer(!ok))
