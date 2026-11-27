# LDG-3280: reconciles a suite_driver.R run on the candidate with the
# inventory. Every block that fails or errors must have an inventory row
# (by file and title, or through a helper row's listed users); inventory
# rows whose blocks pass are listed with their handling (an affected block
# may pass today and fail, or pass vacuously, after Cut 28).
#   Rscript suite_reconcile.R --tests=<suite_driver tests.csv> --out=<csv>
local({
  argv <- commandArgs(TRUE)
  arg <- function(n) sub(paste0("^--", n, "="), "", grep(paste0("^--", n, "="), argv, value = TRUE)[[1L]])
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
  assign("rc", list(tests = arg("tests"), out = arg("out"), inv = file.path(here, "census", "inventory.csv")), globalenv())
})
t <- utils::read.csv(rc$tests, stringsAsFactors = FALSE)
inv <- utils::read.csv(rc$inv, stringsAsFactors = FALSE, encoding = "UTF-8")
t$bad <- t$failed > 0 | t$error
key <- function(f, x) paste(f, x, sep = " :: ")
inv_keys <- key(inv$file, inv$test)
# Blocks covered through a helper row: census_hits.csv records each block's
# helper reach (via_helpers); a failing block whose helper has a row counts.
hits <- utils::read.csv(file.path(dirname(rc$inv), "census_hits.csv"), stringsAsFactors = FALSE)
helper_rows <- inv[grepl("^<helper>|^helper-|[.]R ", inv$test), ]
helper_names <- unique(unlist(regmatches(helper_rows$test, gregexpr("[A-Za-z0-9_.]+$", helper_rows$test))))
via <- if ("via_helpers" %in% names(hits)) hits$via_helpers else rep("", nrow(hits))
hits$helper_row <- vapply(strsplit(ifelse(is.na(via), "", via), "[ ;,]+"), function(h) any(h %in% helper_names), logical(1))
helper_keys <- key(hits$file[hits$helper_row], hits$test[hits$helper_row])
t$row <- ifelse(key(t$file, t$test) %in% inv_keys, inv$row_id[match(key(t$file, t$test), inv_keys)], "")
t$via_helper <- key(t$file, t$test) %in% helper_keys
bad <- t[t$bad, ]
unrowed <- bad[!nzchar(bad$row) & !bad$via_helper, ]
out <- data.frame(file = bad$file, test = bad$test, row = bad$row, via_helper = bad$via_helper,
                  problem = substr(bad$problem, 1L, 200L), stringsAsFactors = FALSE)
utils::write.csv(out, rc$out, row.names = FALSE)
passing_rows <- inv[inv_keys %in% key(t$file[!t$bad], t$test[!t$bad]), ]
cat(sprintf("%d tests; %d fail or error; %d with an inventory row, %d through a helper row, %d with neither\n",
            nrow(t), nrow(bad), sum(nzchar(bad$row)), sum(!nzchar(bad$row) & bad$via_helper), nrow(unrowed)))
cat(sprintf("inventory block rows whose block passes on the candidate today: %d (%s)\n", nrow(passing_rows),
            paste(names(table(passing_rows$handling)), table(passing_rows$handling), sep = " ", collapse = ", ")))
if (nrow(unrowed)) {
  cat("failing blocks with no inventory row:\n")
  print(unrowed[, c("file", "test", "problem")], row.names = FALSE)
}
quit(save = "no", status = if (nrow(unrowed)) 1L else 0L)
