# Independent reference calculation for the budget, netting, risk-cap, and
# dense-control arithmetic used by W01, W02, W21, W22, W23, and W31.
# Base R only. It does not call ledgr, the shared fold fork, or any provider.
# Run from the repository root:
#   Rscript dev/spikes/asset_availability_pit/references/budget_arithmetic.R

show <- function(label, value) cat(sprintf("%-46s %s\n", label, format(value, nsmall = 2)))

cat("== W01 residual-NAV sizing ==\n")
nav <- 100000; held_a01 <- 300 * 100
show("reserved exposure (A01 300 * 100)", held_a01)
show("residual sizing base", nav - held_a01)
show("c0 A02 target floor(0.5*100000/50)", floor(0.5 * nav / 50))
show("c0 A03 target floor(0.5*100000/20)", floor(0.5 * nav / 20))
show("c0 cash after 70000-50000-50000", 70000 - 50000 - 50000)
show("c1 A02 target floor(0.5*70000/50)", floor(0.5 * (nav - held_a01) / 50))
show("c1 A03 target floor(0.5*70000/20)", floor(0.5 * (nav - held_a01) / 20))
show("c1 cash after 70000-35000-35000", 70000 - 700 * 50 - 1750 * 20)
show("c2 cash after sale 70000-35000-35000+30000", 70000 - 35000 - 35000 + 30000)
show("c2 S2 A02 target floor(0.5*100000/50)", floor(0.5 * 100000 / 50))
show("c2 S2 A03 target floor(0.5*100000/20)", floor(0.5 * 100000 / 20))
show("c2 S3 cash 30000-300*50-750*20", 30000 - 300 * 50 - 750 * 20)

cat("\n== W02 same-pulse netting and reconciliation (c2 exact boundary) ==\n")
tol <- 1e-8
virtual <- 0
virtual <- virtual + 300 * 100      # A01 sale credited first (stable-ID order)
show("virtual after A01 credit", virtual)
buy <- -600 * 50
virtual_after_buy <- virtual + buy
show("virtual after A02 debit", virtual_after_buy)
show("A02 accepted (virtual >= -tol)", virtual_after_buy >= -tol)
event_cash <- c(0 + buy, 0 + buy + 300 * 100)  # event order A02 then A01
show("event cash after A02 buy", event_cash[1])
show("event cash after A01 sale", event_cash[2])
show("reconciled abs(virtual-event) <= tol", abs(virtual_after_buy - event_cash[2]) <= tol)
cat("\n== W02 c1 unaffordable purchase ==\n")
show("virtual after rejected sale (no credit)", 10000)
show("virtual if A02 buy applied", 10000 - 25000)
show("A02 rejected (below -tol)", (10000 - 25000) < -tol)

cat("\n== W21 dense control ledger (fee 1.00 per fill, max_weight 0.55) ==\n")
cash <- 50000; a01 <- 100; a02 <- 0
eq1 <- cash + a01 * 100; show("S1 equity", eq1)
show("S1 cap A02 0.55*eq/50", 0.55 * eq1 / 50)
show("S1 cap A01 0.55*eq/100", 0.55 * eq1 / 100)
cash <- cash - (660 * 50 + 1); a02 <- 660; show("after buy A02 660 @50", cash)
cash <- cash + (50 * 100 - 1); a01 <- 50;  show("after sell A01 50 @100", cash)
eq2 <- cash + a02 * 49 + a01 * 102; show("S2 equity", eq2)
show("S2 cap A02 0.55*eq/49", 0.55 * eq2 / 49)
cash <- cash + (50 * 102 - 1); a01 <- 0; show("after sell A01 50 @102", cash)
eq3 <- cash + a02 * 48; show("S3 equity", eq3)
show("S3 cap A02 0.55*eq/48", 0.55 * eq3 / 48)
eq4 <- cash + a02 * 52; show("S4 equity", eq4)
show("total return eq4/eq1-1", eq4 / eq1 - 1)

cat("\n== W22 and W23 caps ==\n")
show("W22 cap 0.05*100000/50", 0.05 * 100000 / 50)
show("W22 cap 0.5*100000/50", 0.5 * 100000 / 50)
show("W23 cap 0.08*100000/100", 0.08 * 100000 / 100)
show("W23 short equity 105000-100*50", 105000 - 100 * 50)

cat("\n== W31 ==\n")
show("S2 equity 75000+100*50+200*100", 75000 + 100 * 50 + 200 * 100)
show("cap 0.1*100000/100", 0.1 * 100000 / 100)
show("c1 cash after sell 200 @100", 75000 + 200 * 100)

cat("\n== W21 lot accounting (fee reduces realized P&L; basis = fill price) ==\n")
show("fill 1 buy A02 realized delta 0-1", 0 - 1)
show("fill 2 sell A01 50 @100 basis 100: (100-100)*50-1", (100 - 100) * 50 - 1)
show("fill 3 sell A01 50 @102 basis 100: (102-100)*50-1", (102 - 100) * 50 - 1)
show("realized cumulative -1-1+99", -1 - 1 + 99)
show("fees total", 3)
show("unrealized A02 at S4 (52-50)*660", (52 - 50) * 660)
