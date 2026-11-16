grab <- function(file, want) for (e in parse(file, keep.source = FALSE))
  if (is.call(e) && identical(e[[1L]], as.name("<-")) && is.symbol(e[[2L]]) && as.character(e[[2L]]) %in% want) eval(e, globalenv())
args <- commandArgs(TRUE)
grab(args[[1L]], c("forbidden", "call_head", "head_name", "scan_body"))  # the earlier scan
grab(args[[2L]], c("scan_spellings", "scan_controls", "scan_cases"))  # the current cases
scan_cases$as_expected <- scan_cases$hits == scan_cases$expected
cat(sum(scan_cases$as_expected), "of", nrow(scan_cases), "as expected; failing spellings:",
    paste(unique(scan_cases$spelling[!scan_cases$as_expected]), collapse = ", "), "\n")
