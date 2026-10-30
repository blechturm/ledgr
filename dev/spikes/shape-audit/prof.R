dir <- "C:/Users/maxth/Documents/GitHub/ledgr/dev/spikes/pmwr-performance"
files <- list.files(dir, pattern = "^profile_.*_total\\.csv$", full.names = TRUE)
pat <- commandArgs(TRUE)[[1]]
out <- do.call(rbind, lapply(files, function(f) {
  d <- read.csv(f, stringsAsFactors = FALSE)
  d$fn <- gsub('"', "", d$fn)
  d <- d[grepl(pat, d$fn), , drop = FALSE]
  if (!nrow(d)) return(NULL)
  data.frame(profile = sub("profile_(.*)_total.csv", "\\1", basename(f)), d, row.names = NULL)
}))
options(width = 200)
print(out[order(out$fn, out$profile), c("profile", "fn", "total.pct", "self.pct")], row.names = FALSE)
