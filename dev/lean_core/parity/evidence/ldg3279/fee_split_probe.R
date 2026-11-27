# The fee split's two implementations in the shipped package (found by the
# LDG-3279 audit; maintainer decision 2026-11-27: fix in Cut 28). The fold
# splits a fill's fee with ledgr_fill_leg_fees(): fee * close_qty / total.
# The stored-run fills reader (R/accounting-replay.R, ledgr fills replay)
# computes fee * (close_qty / total), and takes the whole fee for a pure
# close. This probe compares the two on a grid of realistic fills and counts
# the rows whose closing-leg fee differs, and the pure closes whose fold
# split is not the fee exactly.
#   Rscript fee_split_probe.R --lib=<pin library>
lib <- sub("^--lib=", "", grep("^--lib=", commandArgs(TRUE), value = TRUE)[[1L]])
.libPaths(unique(c(lib, "C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths())))
suppressPackageStartupMessages(library(ledgr))
legs <- get("ledgr_fill_leg_fees", envir = asNamespace("ledgr"))
set.seed(20261127)
n <- 100000L
fee <- round(runif(n, 0.01, 50), 2)
close <- sample(1:500, n, replace = TRUE)
open <- sample(0:500, n, replace = TRUE)
fold <- legs(fee, close, open)$close
total <- close + open
reader <- ifelse(open <= 0, fee, ifelse(close <= 0, 0, fee * (close / total)))
split <- open > 0
cat(sprintf("fills with both legs: %d; closing-leg fee differs: %d (%.2f%%); largest difference %.3g\n",
            sum(split), sum(fold[split] != reader[split]), 100 * mean(fold[split] != reader[split]),
            max(abs(fold[split] - reader[split]))))
cat(sprintf("pure closes: %d; fold split differs from the fee: %d\n", sum(!split), sum(fold[!split] != fee[!split])))
k <- which(split & fold != reader)[[1L]]
cat(sprintf("example: fee %.2f, close %d, open %d: fold %.17g, reader %.17g\n", fee[[k]], close[[k]], open[[k]],
            fold[[k]], reader[[k]]))
