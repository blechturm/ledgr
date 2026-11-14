# Cut 18 (LDG-3234): the actionable worklist of decision (6), derived from
# the committed statement clocks (statement_cost.csv, clock_loops.csv) and
# bounds (bounds.csv). Shares are of the plain lean loop per pulse.
#
#   Rscript dev/lean_core/parity/cut18_worklist.R
#
# A forwarder removal is worked regardless of its size. A rewrite is worked
# when its supported bound reaches 0.02 of the loop on some comparison
# shape; the in-loop statement clock is the supported bound on the two
# clocked shapes (the isolated benchmark understates it 2-3 times there),
# and bounds.csv gives the other two (20 instruments: the 10-instrument row;
# 500x1260: the 500-instrument row).

here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
ev <- file.path(here, "evidence", "cut18")
sc <- utils::read.csv(file.path(ev, "statement_cost.csv"), stringsAsFactors = FALSE)
lp <- utils::read.csv(file.path(ev, "clock_loops.csv"), stringsAsFactors = FALSE)
bd <- utils::read.csv(file.path(ev, "bounds.csv"), stringsAsFactors = FALSE)
plain <- stats::setNames(lp$us_per_pulse[lp$arm == "plain"], lp$shape[lp$arm == "plain"])
net <- function(st, shape) { v <- sc$net_us[sc$statement == st & sc$shape == shape]; if (length(v)) v else NA_real_ }
bound <- function(item, n) bd$us[bd$item == item & bd$instruments == n]
row <- function(id, kind, sites, statement, bounds_item, change) {
  cross <- if (is.na(statement)) bound(bounds_item, 10L) else net(statement, "10x7200")
  s2 <- if (is.na(statement)) bound(bounds_item, 10L) else net(statement, "slice2_10x7200")
  b20 <- if (is.na(bounds_item)) NA_real_ else bound(bounds_item, 10L)
  b500 <- if (is.na(bounds_item)) NA_real_ else bound(bounds_item, 500L)
  shares <- c(cross / plain[["10x7200"]], s2 / plain[["slice2_10x7200"]], b20 / 341, b500 / 571)
  data.frame(id = id, kind = kind, sites = sites, change = change, us_10x7200 = cross, us_slice2 = s2,
             share_10x7200 = shares[[1L]], share_slice2 = shares[[2L]], share_20x23400 = shares[[3L]], share_500x1260 = shares[[4L]],
             worked = kind == "forwarder" || any(shares >= 0.02, na.rm = TRUE), stringsAsFactors = FALSE)
}
wl <- rbind(
  row("F1", "forwarder", "plan.R lean_plan_pulse, statement 9", "plan.R|lean_plan_pulse|9", "F1 plan() closure built per lean_plan_pulse call",
      "define the plan assembly once, outside lean_plan_pulse()"),
  row("F2", "forwarder", "loop.R lean_p3_plan lines 668-669 and 677-678", "loop.R|lean_p3_plan|8@3", "F2 execution packet list",
      "pass exec_ts and the open column directly; pass the run's ctx_pos and a run-long membership vector"),
  row("F3", "forwarder", "loop.R lean_p5_commit line 810", NA, "F3 second gross of the strategy targets when no risk step runs",
      "reuse the strategy targets' gross when no risk step runs"),
  row("W4", "rewrite", "plan.R lean_plan_affordability, statement 2", "plan.R|lean_plan_affordability|2",
      "W4 affordability priority: order(!generator, id_rank)", "the same priority without order(): a run-long radix permutation walked by masks"),
  row("W5", "rewrite", "loop.R lean_state_patch, statement 3", "loop.R|lean_state_patch|3", "W5 state patch name predicate",
      "accept names identical to the declared field names before the full predicate"),
  row("W6", "rewrite", "loop.R lean_p4_apply line 712", "loop.R|lean_p4_apply|8@2", "W6 decode of empty fill reason segments",
      "decode only fills that carry a reason code"))
wl <- wl[order(-pmax(wl$share_10x7200, wl$share_slice2, na.rm = TRUE)), ]
utils::write.csv(wl, file.path(ev, "worklist.csv"), row.names = FALSE)
# Package-owned costs for routing (out of scope, decision 2).
pk <- data.frame(site = c("target validator on helper returns (P2)", "sizing-evidence validator (P2)", "risk plan and post-risk checks (P2)",
                          "cost resolver (P3)", "declared-state field validator (P5)", "FIFO kernel (P4, lean fifo.R)", "position facts (P4)"),
                 statement = c("loop.R|lean_p2_decide|21", "loop.R|lean_p2_decide|26", "loop.R|lean_p2_decide|32", "plan.R|lean_plan_pulse|18",
                               "loop.R|lean_state_patch|5", "loop.R|lean_p4_apply|8@8", "loop.R|lean_p4_apply|8@11"),
                 routing = c("WS14a or a focused package cut", "WS14a or a focused package cut", "WS14a or a focused package cut",
                             "WS14a or a focused package cut", "WS14a or a focused package cut", "a later FIFO cut (compiled FIFO: WS14)",
                             "WS14a or a focused package cut"), stringsAsFactors = FALSE)
pk$us_10x7200 <- vapply(pk$statement, net, 0, shape = "10x7200")
pk$us_slice2 <- vapply(pk$statement, net, 0, shape = "slice2_10x7200")
utils::write.csv(pk, file.path(ev, "package_costs.csv"), row.names = FALSE)
print(wl[c("id", "kind", "us_10x7200", "us_slice2", "share_10x7200", "share_slice2", "share_20x23400", "share_500x1260", "worked")], digits = 2, row.names = FALSE)
print(pk[c("site", "us_10x7200", "us_slice2")], digits = 3, row.names = FALSE)

# Amendment lean_owned, item (e): the lean-owned replacements join the
# worklist (worklist_amended.csv), in-loop cost from package_costs.csv; W5
# folds into R5 (the state patch path replaces the name predicate with it).
rep_row <- function(id, sites, statement, change) {
  cross <- net(statement, "10x7200"); s2 <- net(statement, "slice2_10x7200")
  data.frame(id = id, kind = "replacement", sites = sites, change = change, us_10x7200 = cross, us_slice2 = s2,
             share_10x7200 = cross / plain[["10x7200"]], share_slice2 = s2 / plain[["slice2_10x7200"]],
             share_20x23400 = NA_real_, share_500x1260 = NA_real_, worked = TRUE, stringsAsFactors = FALSE)
}
am <- rbind(wl[wl$id != "W5", ],
  rep_row("R1", "risk plan, post-risk and short checks (P2)", "loop.R|lean_p2_decide|32",
          "lean risk steps on plain equity and close; refusals through the pin's functions"),
  rep_row("R2", "cost resolver call (P3)", "plan.R|lean_plan_pulse|18",
          "the compiled steps evaluated in their order from run constants; no output-shape re-check"),
  rep_row("R3", "target validator on non-plain returns (P2)", "loop.R|lean_p2_decide|21",
          "match-based checks, the universe predicate once per run; refusals through the pin's validator"),
  rep_row("R4", "sizing-evidence validator (P2)", "loop.R|lean_p2_decide|26",
          "fused checks; anything not clearly valid goes to the pin's validator"),
  rep_row("R5", "state patch path (P5), with W5", "loop.R|lean_p5_commit|16",
          "declared-name fast accept and per-field checks; anything else to the pin's apply_values"))
am <- am[order(-pmax(am$share_10x7200, am$share_slice2, na.rm = TRUE)), ]
utils::write.csv(am, file.path(ev, "worklist_amended.csv"), row.names = FALSE)
cat("\namended worklist:\n")
print(am[c("id", "kind", "us_10x7200", "us_slice2", "share_10x7200", "share_slice2", "worked")], digits = 2, row.names = FALSE)
