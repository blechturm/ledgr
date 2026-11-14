# Cut 17 (LDG-3232, close-review correction): writes manifest.csv, the
# oracle's required-case list, from the case grid and one pin arm's record.
# For every case it freezes what the pin reaches: the expected outcome
# ("value" or "error:<class>", from the grid), the refusal message (ASCII,
# non-ASCII as <U+XXXX>; "" for a value) and a digest of the notes bindings
# after the call ("" when the case has no notes). oracle_compare.R refuses
# when the pin no longer reaches a frozen outcome. Review the message column
# when committing: it is the named refusal each case asserts.
#
#   Rscript dev/bench/v0_2_3_helper/freeze_manifest.R --pin=<pin.rds from oracle_run.R>

args <- commandArgs(trailingOnly = TRUE)
pin <- readRDS(sub("^--pin=", "", grep("^--pin=", args, value = TRUE)[[1L]]))
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
oracle_views <- list()
sys.source(file.path(here, "oracle_cases.R"), envir = globalenv())
cs <- oracle_cases()
msg_key <- function(m) iconv(enc2utf8(m), "UTF-8", "ASCII", sub = "Unicode")
notes_digest <- function(x) if (is.null(x)) "" else digest::digest(x)
m <- data.frame(case = vapply(cs, `[[`, "", "id"), sites = vapply(cs, `[[`, "", "sites"),
                expect = vapply(cs, `[[`, "", "expect"), tag = vapply(cs, `[[`, "", "tag"), stringsAsFactors = FALSE)
stopifnot(!anyDuplicated(m$case), all(m$case %in% names(pin$results)))
m$expect_message <- vapply(m$case, function(id) { r <- pin$results[[id]]; if (r$outcome == "error") msg_key(r$error$message) else "" }, "")
m$expect_notes <- vapply(m$case, function(id) notes_digest(pin$results[[id]]$notes_after), "")
utils::write.csv(m, file.path(here, "manifest.csv"), row.names = FALSE)
cat(nrow(m), "cases frozen from pin", pin$meta$source, "\n")
