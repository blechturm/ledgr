# Cut 25 measuring step: which feature-oracle cases change when the
# post-warmup NA refusal is removed, and how.
#
#   Rscript dev/bench/v0_2_3_cut25_chores/oracle_flips.R --pin=<runner out> --candidate=<runner out> --out=<csv>
local({
  argv <- commandArgs(TRUE)
  arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), argv, value = TRUE)[[1L]])
  read <- function(dir) utils::read.csv(file.path(dir, "observations.csv"), stringsAsFactors = FALSE,
                                        colClasses = "character", encoding = "UTF-8")
  pin <- read(arg("pin"))
  cand <- read(arg("candidate"))
  key <- function(x) paste(x$family, x$case, x$component, sep = "\r")
  pk <- key(pin)
  ck <- key(cand)
  all_keys <- union(pk, ck)
  pv <- pin$value[match(all_keys, pk)]
  cv <- cand$value[match(all_keys, ck)]
  differs <- !(is.na(pv) & is.na(cv)) & (is.na(pv) | is.na(cv) | pv != cv)
  parts <- do.call(rbind, strsplit(all_keys[differs], "\r", fixed = TRUE))
  cases <- unique(paste(parts[, 1L], parts[, 2L], sep = "\r"))
  rc <- function(obs, fam, case) {
    v <- obs$value[obs$family == fam & obs$case == case & obs$component == "refusal_class"]
    if (length(v) == 0L) "" else v[[1L]]
  }
  rf <- function(obs, fam, case) {
    v <- obs$value[obs$family == fam & obs$case == case & obs$component == "refusal"]
    if (length(v) == 0L) "" else substr(v[[1L]], 1L, 160L)
  }
  res <- do.call(rbind, lapply(cases, function(fc) {
    p <- strsplit(fc, "\r", fixed = TRUE)[[1L]]
    comps <- parts[parts[, 1L] == p[[1L]] & parts[, 2L] == p[[2L]], 3L]
    data.frame(
      family = p[[1L]], case = p[[2L]],
      pin_refusal_class = rc(pin, p[[1L]], p[[2L]]),
      candidate_refusal_class = rc(cand, p[[1L]], p[[2L]]),
      pin_refusal = rf(pin, p[[1L]], p[[2L]]),
      candidate_refusal = rf(cand, p[[1L]], p[[2L]]),
      components = paste(sort(unique(comps)), collapse = ";")
    )
  }))
  utils::write.csv(res, arg("out"), row.names = FALSE)
  cat("differing cases:", nrow(res), "\n")
  print(table(pin = res$pin_refusal_class, candidate = res$candidate_refusal_class))
  defset <- sub("^.*\\|", "", res$case)
  print(table(defset, res$candidate_refusal_class))
})
