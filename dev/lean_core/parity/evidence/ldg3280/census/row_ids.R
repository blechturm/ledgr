# LDG-3280: gives every inventory row a stable id (R001 ...) in file order,
# and writes the remap batches: the b rows whose target names no Cut 28 gate,
# split into test-ws4a-carrier.R (batch A) and the rest (batch B).
#   Rscript row_ids.R
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
p <- file.path(here, "inventory.csv")
x <- utils::read.csv(p, stringsAsFactors = FALSE, encoding = "UTF-8")
if (!"row_id" %in% names(x)) x <- cbind(row_id = sprintf("R%03d", seq_len(nrow(x))), x, stringsAsFactors = FALSE)
utils::write.csv(x, p, row.names = FALSE, fileEncoding = "UTF-8")
b <- x[grepl("b", x$handling) & !grepl("Cut 28", x$target_or_authority), ]
dir.create(file.path(here, "..", "remaps"), showWarnings = FALSE)
cols <- c("row_id", "file", "test", "handling", "target_or_authority", "justification")
utils::write.csv(b[b$file == "test-ws4a-carrier.R", cols], file.path(here, "..", "remaps", "batch_A.csv"), row.names = FALSE)
utils::write.csv(b[b$file != "test-ws4a-carrier.R", cols], file.path(here, "..", "remaps", "batch_B.csv"), row.names = FALSE)
cat("rows", nrow(x), "; b rows without a Cut 28 gate:", nrow(b), "(A", sum(b$file == "test-ws4a-carrier.R"),
    ", B", sum(b$file != "test-ws4a-carrier.R"), ")\n")
