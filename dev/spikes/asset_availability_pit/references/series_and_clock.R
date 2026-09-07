# Independent reference calculation for the series, fitted-transform, return,
# and age-clock values used by W06, W08, W12, W14, W15, W19, W25, W27, W28,
# and W29. Base R only. It does not call ledgr, the fold fork, or a provider.
# Run from the repository root:
#   Rscript dev/spikes/asset_availability_pit/references/series_and_clock.R

show <- function(label, value) cat(sprintf("%-46s %s\n", label, paste(format(value, digits = 12), collapse = " ")))

cat("== W08 one-session return ==\n")
show("A01 100/98-1", 100 / 98 - 1)
show("A02 50/49-1", 50 / 49 - 1)

cat("\n== W12 centering means ==\n")
show("members (100+100+50+50)/4", mean(c(100, 100, 50, 50)))
show("broad (100+100+50+50+20+20)/6", mean(c(100, 100, 50, 50, 20, 20)))
show("A01 S3 centered members 100-75", 100 - 75)
show("A01 S3 centered broad", 100 - mean(c(100, 100, 50, 50, 20, 20)))

cat("\n== W14 full-window mean ==\n")
show("mean(100..108)", mean(100:108))
show("S2 transformed 101-104", 101 - mean(100:108))

cat("\n== W15 delayed labels ==\n")
closes <- c(100, 101, 102, 103, 104, 105)
y1 <- closes[3] / closes[1] - 1; y2 <- closes[4] / closes[2] - 1
show("y_S1 102/100-1", y1)
show("y_S2 103/101-1", y2)
show("fitted mean c1", mean(c(y1, y2)))
y2r <- closes[4] / 101.5 - 1
show("y_S2 revised 103/101.5-1", y2r)
show("fitted mean c3", mean(c(y1, y2r)))

cat("\n== W19 returns ==\n")
show("cand_a 100500/100000-1", 100500 / 100000 - 1)
show("cand_b prefix 101000/100000-1", 101000 / 100000 - 1)

cat("\n== W25 graphs over 1, 3, NA, 9 ==\n")
sig <- c(1, 3, NA, 9)
carry <- function(x) { out <- x; for (i in seq_along(x)[-1]) if (is.na(out[i])) out[i] <- out[i - 1]; out }
roll2 <- function(x) c(NA, (x[-length(x)] + x[-1]) / 2)
show("g1 carry then roll", roll2(carry(sig)))
show("g2 roll then carry", carry(roll2(sig)))

cat("\n== W27 and W29 rolling means of two closes ==\n")
cl <- c(100, 101, 102, 103, 104)
show("rm2 S3..S5", roll2(cl)[3:5])

cat("\n== W06 and W28 age clock ==\n")
# age = number of consecutive missing expected sessions since the last fresh mark;
# declared closures are not expected sessions and do not advance the clock.
w06 <- c(fresh = 0, S2_missing = 1, S3_missing = 2, S4_missing = 3)
show("W06 ages S1..S4 (3 stops)", w06)
w28 <- c(S2_fresh = 0, closure = 0, S3_missing = 1, S4_fresh = 0)
show("W28 ages S2, closure, S3, S4", w28)
