# Cut 22 decision 9: R/ production lines before and after. A production line
# is a non-blank line that is not a comment (roxygen included). The engine
# version's bind list (the `bound <- c(...)` statement of
# ledgr_feature_engine_version()) is reported separately, as decision 9
# allows it to grow.
#
#   Rscript lines.R --repo=<git tree> --base=<commit> --final=<commit> --out=<csv>
local({
  argv <- commandArgs(TRUE)
  arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), argv, value = TRUE)[[1L]])
  repo <- arg("repo")
  git <- function(...) system2("git", c("-C", shQuote(repo), ...), stdout = TRUE)
  count <- function(commit) {
    files <- git("ls-tree", "-r", "--name-only", commit, "--", "R")
    files <- files[grepl("[.]R$", files)]
    do.call(rbind, lapply(files, function(f) {
      lines <- git("show", paste0(commit, ":", f))
      code <- lines[nzchar(trimws(lines)) & !grepl("^\\s*#", lines)]
      bind <- 0L
      if (basename(f) == "features-engine.R") {
        start <- grep("^\\s*bound <- c\\($", lines)
        if (length(start)) {
          end <- start + which(grepl("^\\s*\\)$", lines[-seq_len(start)]))[[1L]]
          block <- lines[start:end]
          bind <- sum(nzchar(trimws(block)) & !grepl("^\\s*#", block))
        }
      }
      data.frame(file = f, production = length(code), bind_list = bind, stringsAsFactors = FALSE)
    }))
  }
  a <- count(arg("base"))
  b <- count(arg("final"))
  m <- merge(a, b, by = "file", all = TRUE, suffixes = c("_base", "_final"))
  m[is.na(m)] <- 0L
  m$change <- m$production_final - m$production_base
  m <- m[m$change != 0L | m$bind_list_final != 0L | m$bind_list_base != 0L, ]
  total <- data.frame(file = "<total R/>", production_base = sum(a$production), bind_list_base = sum(a$bind_list),
                      production_final = sum(b$production), bind_list_final = sum(b$bind_list),
                      change = sum(b$production) - sum(a$production))
  out <- rbind(m, total)
  out$change_without_bind_list <- out$change - (out$bind_list_final - out$bind_list_base)
  utils::write.csv(out, arg("out"), row.names = FALSE)
  print(out, row.names = FALSE)
})
