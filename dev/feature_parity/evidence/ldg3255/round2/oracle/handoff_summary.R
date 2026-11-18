# Summarise the handoffs component of an oracle run, by family.
d <- commandArgs(TRUE)[[1L]]
x <- read.csv(file.path(d, "observations.csv"), na.strings = character(), colClasses = "character")
h <- x[x$component == "handoffs", ]
ref <- x$value[match(paste(h$family, h$case, "refusal"), paste(x$family, x$case, x$component))] != "none"
v <- do.call(rbind, lapply(strsplit(h$value, ";", fixed = TRUE), function(p) {
  kv <- strsplit(p, "=", fixed = TRUE)
  stats::setNames(as.integer(vapply(kv, `[`, "", 2L)), vapply(kv, `[`, "", 1L))
}))
v <- as.data.frame(v)
s <- do.call(rbind, lapply(split(seq_len(nrow(h)), h$family), function(i) data.frame(
  family = h$family[i[1]], cases = length(i), refused = sum(ref[i]),
  prep_reached_zero = sum(v$prep_reached[i] == 0L),
  prep_reached = sum(v$prep_reached[i] > 0L),
  prep_short_on_refusal = sum(v$prep_seen[i] < v$prep_reached[i]),
  causality_reached = sum(v$causality_reached[i] > 0L),
  causality_checks = sum(v$causality_checks[i]),
  handoffs_prep = sum(v$prep_seen[i]), handoffs_causality = sum(v$causality_seen[i]))))
print(s, row.names = FALSE)
