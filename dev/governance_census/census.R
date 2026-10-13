# Governance census for the governance-lifecycle RFC (seed v2).
#
#   Rscript dev/governance_census/census.R [--output=dev/governance_census/records]
#
# Run from the repository root. Reads tracked files only and writes
# deterministic CSV records; every count in seed v2 comes from summary.csv.
#
# Links: inline links and images plus used reference links in tracked .md and
# .qmd files under inst/design, outside fenced and inline code. External URLs
# (any scheme) and root-absolute paths are excluded. Targets resolve against
# the source directory and tracked files or directories; a fragment on a
# Markdown target resolves against GitHub-style heading slugs (duplicates get
# -1, -2, ...) and explicit id attributes or {#id} labels. Scope "governance"
# is the top-level inst/design files plus rfc/, manual/ and the v0.2.2 packet;
# scope "design" is all of inst/design. Counts are occurrences.
#
# Review counts: cut_review_counts.csv transcribes each cut's final recorded
# review count with the tickets.yml line and the phrase that states it; this
# tool checks that each phrase occurs on its line and computes the totals and
# the completed-ticket denominator from tickets.yml itself.
args <- commandArgs(trailingOnly = TRUE)
out <- sub("^--output=", "", grep("^--output=", args, value = TRUE))
if (!length(out)) out <- "dev/governance_census/records"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
here <- "dev/governance_census"

tracked <- system2("git", c("ls-files"), stdout = TRUE)
tracked_dirs <- unique(unlist(lapply(strsplit(tracked, "/", fixed = TRUE), function(p)
  if (length(p) > 1L) vapply(seq_len(length(p) - 1L), function(i) paste(p[seq_len(i)], collapse = "/"), "") else character())))
read <- function(f) readLines(f, warn = FALSE, encoding = "UTF-8")
words <- function(x) sum(lengths(strsplit(trimws(x[nzchar(trimws(x))]), "[[:space:]]+")))
srt <- function(d, by) d[do.call(order, c(unname(as.list(d[by])), method = "radix")), , drop = FALSE]
rows <- list()
add <- function(metric, scope, value) rows[[length(rows) + 1L]] <<- data.frame(metric = metric, scope = scope, value = value)

# ---- Markdown text without code ----
code_free <- function(x) {
  fence <- grepl("^[[:space:]]*(```|~~~)", x)
  inside <- (cumsum(fence) %% 2L == 1L) | fence
  x[inside] <- ""
  gsub("`[^`]*`", "", x)
}
slug <- function(h) {
  h <- gsub("\\[([^]]*)\\]\\([^)]*\\)", "\\1", h)
  h <- gsub("[*`]", "", h)
  h <- tolower(trimws(h))
  h <- gsub("[^a-z0-9 _-]", "", h)
  gsub(" ", "-", h, fixed = TRUE)
}
anchor_cache <- new.env()
anchors_of <- function(f) {
  if (!is.null(anchor_cache[[f]])) return(anchor_cache[[f]])
  x <- code_free(read(f))
  hd <- regmatches(x, regexec("^#{1,6}[[:space:]]+(.+?)[[:space:]]*#*[[:space:]]*$", x, perl = TRUE))
  hd <- vapply(hd[lengths(hd) == 2L], `[`, "", 2L)
  labels <- regmatches(hd, regexpr("\\{#[A-Za-z0-9_:.-]+", hd))
  hd <- sub("[[:space:]]*\\{#[^}]*\\}[[:space:]]*$", "", hd)
  s <- slug(hd)
  seen <- list(); out_s <- character(length(s))
  for (i in seq_along(s)) {
    n <- if (is.null(seen[[s[i]]])) 0L else seen[[s[i]]]
    out_s[i] <- if (n == 0L) s[i] else paste0(s[i], "-", n)
    seen[[s[i]]] <- n + 1L
  }
  ids <- unlist(regmatches(x, gregexpr("id=[\"'][^\"']+[\"']", x)))
  ids <- gsub("^id=[\"']|[\"']$", "", ids)
  a <- tolower(c(out_s, sub("^\\{#", "", labels), ids))
  assign(f, a, envir = anchor_cache)
  a
}
norm_path <- function(p) {
  parts <- strsplit(p, "/", fixed = TRUE)[[1]]
  keep <- character()
  for (q in parts) {
    if (q == "" || q == ".") next
    if (q == "..") keep <- head(keep, -1L) else keep <- c(keep, q)
  }
  paste(keep, collapse = "/")
}
links_in <- function(f) {
  x <- code_free(read(f))
  res <- list()
  inl <- gregexpr("!?\\[(?:[^][]|\\[[^]]*\\])*\\]\\(\\s*<?([^)\\s>]+)>?(?:\\s+[\"'(][^)]*)?\\)", x, perl = TRUE)
  for (i in seq_along(x)) {
    m <- regmatches(x[i], inl[i])[[1]]
    if (!length(m)) next
    t <- sub("^!?\\[(?:[^][]|\\[[^]]*\\])*\\]\\(\\s*<?([^)\\s>]+)>?.*$", "\\1", m, perl = TRUE)
    res[[length(res) + 1L]] <- data.frame(line = i, target = t)
  }
  defs <- regmatches(x, regexec("^[[:space:]]{0,3}\\[([^]]+)\\]:[[:space:]]*<?([^[:space:]>]*)", x))
  def_id <- character(); def_t <- character()
  for (i in which(lengths(defs) == 3L)) {
    t <- defs[[i]][3]
    if (!nzchar(t) && i < length(x)) t <- strsplit(trimws(x[i + 1L]), "[[:space:]]+")[[1]][1]
    def_id <- c(def_id, tolower(defs[[i]][2])); def_t <- c(def_t, t)
  }
  if (length(def_id)) {
    use <- gregexpr("\\[([^]]+)\\]\\[([^]]*)\\]", x, perl = TRUE)
    for (i in seq_along(x)) {
      m <- regmatches(x[i], use[i])[[1]]
      for (u in m) {
        p <- regmatches(u, regexec("^\\[([^]]+)\\]\\[([^]]*)\\]$", u))[[1]]
        id <- tolower(if (nzchar(p[3])) p[3] else p[2])
        k <- match(id, def_id)
        if (!is.na(k)) res[[length(res) + 1L]] <- data.frame(line = i, target = def_t[k])
      }
    }
  }
  if (!length(res)) return(NULL)
  d <- do.call(rbind, res)
  d$source <- f
  d
}
design <- tracked[startsWith(tracked, "inst/design/") & grepl("\\.(md|qmd)$", tracked)]
gov <- design[!grepl("/", sub("^inst/design/", "", design)) |
  grepl("^inst/design/(rfc|manual|ledgr_v0_2_2_spec_packet)/", design)]
L <- do.call(rbind, lapply(design, links_in))
L <- L[!grepl("^[A-Za-z][A-Za-z0-9+.-]*:", L$target) & !startsWith(L$target, "/"), ]
L$path <- utils::URLdecode(sub("#.*$", "", L$target))
L$frag <- ifelse(grepl("#", L$target, fixed = TRUE), sub("^[^#]*#", "", L$target), "")
L$resolved <- ifelse(L$path == "", L$source, vapply(file.path(dirname(L$source), L$path), norm_path, ""))
L$resolved <- sub("/$", "", L$resolved)
L$missing_file <- !(L$resolved %in% tracked | L$resolved %in% tracked_dirs)
md_target <- !L$missing_file & grepl("\\.(md|qmd)$", L$resolved) & nzchar(L$frag)
L$broken_anchor <- FALSE
L$broken_anchor[md_target] <- mapply(function(f, a) !(tolower(utils::URLdecode(a)) %in% anchors_of(f)),
                                     L$resolved[md_target], L$frag[md_target])
L$scope <- ifelse(L$source %in% gov, "governance", "design_only")
for (sc in c("governance", "design")) {
  d <- if (sc == "governance") L[L$scope == "governance", ] else L
  add("link_occurrences", sc, nrow(d))
  add("missing_file_occurrences", sc, sum(d$missing_file))
  add("missing_file_distinct_targets", sc, length(unique(d$resolved[d$missing_file])))
  add("broken_anchor_occurrences", sc, sum(d$broken_anchor))
  add("files_scanned", sc, length(if (sc == "governance") gov else design))
}
bad <- srt(L[L$missing_file | L$broken_anchor, c("source", "line", "target", "missing_file", "broken_anchor", "scope")], c("source", "line", "target"))
write.csv(bad, file.path(out, "links_broken.csv"), row.names = FALSE)

# ---- Synthesis status headers ----
syn <- sort(grep("^inst/design/rfc/.*_synthesis(_v[0-9]+)?\\.md$", tracked, value = TRUE), method = "radix")
H <- do.call(rbind, lapply(syn, function(f) {
  x <- head(read(f), 25L)
  s <- x[grepl("status", x, ignore.case = TRUE)][1]
  st <- if (is.na(s)) "" else trimws(gsub("[*_]", "", sub("^.*?[Ss]tatus[^:]*:", "", s, perl = TRUE)))
  first <- tolower(paste(head(strsplit(st, "[[:space:].,;:(]+")[[1]], 4L), collapse = " "))
  fr <- sub("_synthesis(_v[0-9]+)?\\.md$", "_final_review.md", f)
  data.frame(file = sub("^inst/design/rfc/", "", f), status_start = if (nzchar(first)) first else "(none)",
             pending_final_review = grepl("pending final review", st, ignore.case = TRUE),
             draft = grepl("^draft", st, ignore.case = TRUE),
             superseded = grepl("^superseded", st, ignore.case = TRUE),
             final_review_file = fr %in% tracked)
}))
write.csv(H, file.path(out, "synthesis_headers.csv"), row.names = FALSE)
add("synthesis_files", "rfc", nrow(H))
add("synthesis_status_forms", "rfc", length(unique(H$status_start)))
add("synthesis_pending_final_review_with_review_file", "rfc", sum(H$pending_final_review & H$final_review_file))
add("synthesis_draft", "rfc", sum(H$draft))
add("synthesis_no_status_line", "rfc", sum(H$status_start == "(none)"))
pit <- grepl("^rfc_point_in_time_historical_projection", H$file)
add("pit_projection_versions", "rfc", sum(pit))
add("pit_projection_superseded_headers", "rfc", sum(pit & H$superseded))

# ---- Decision bridge against contracts back-links ----
dec <- read("inst/design/decisions.md")
con <- read("inst/design/contracts.md")
h2 <- grep("^## ", con)
sec_of <- function(sl) {
  i <- h2[slug(sub("^## ", "", con[h2])) == sl]
  if (!length(i)) return(NULL)
  j <- c(h2, length(con) + 1L)[match(i, h2) + 1L] - 1L
  paste(con[i:j], collapse = "\n")
}
B <- list()
for (r in grep("^\\| <a id=", dec, value = TRUE)) {
  id <- sub("^\\| <a id=\"([^\"]+)\".*$", "\\1", r)
  cols <- strsplit(r, " | ", fixed = TRUE)[[1]]
  heads <- unique(regmatches(cols[3], gregexpr("contracts\\.md#[a-z0-9-]+", cols[3]))[[1]])
  for (hh in sub("^contracts\\.md#", "", heads)) {
    s <- sec_of(hh)
    B[[length(B) + 1L]] <- data.frame(row = id, heading = hh,
      backlink = !is.null(s) && grepl(paste0("decisions.md#", id), s, fixed = TRUE))
  }
}
B <- do.call(rbind, B)
write.csv(srt(B, c("row", "heading")), file.path(out, "bridge_backlinks.csv"), row.names = FALSE)
add("bridge_rows", "decisions", length(grep("^\\| <a id=", dec)))
add("bridge_missing_backlinks", "decisions", sum(!B$backlink))
add("bridge_rows_with_missing_backlink", "decisions", length(unique(B$row[!B$backlink])))
add("contracts_h2", "contracts", length(h2))
add("contracts_h3", "contracts", sum(grepl("^### ", code_free(con))))
add("contracts_explicit_anchor_ids", "contracts", sum(grepl("<a id=|\\{#", con)))

# ---- tickets.yml fields and review arithmetic ----
tf <- "inst/design/ledgr_v0_2_2_spec_packet/tickets.yml"
ty <- yaml::read_yaml(tf)
tx <- read(tf)
add("tickets_yml_words", "v0.2.2", words(tx))
field_words <- function(items, field) sum(vapply(items, function(i) if (is.null(i[[field]])) 0L else words(unlist(i[[field]])), 0L))
for (fld in c("scope", "acceptance", "evidence")) add(paste0("ticket_field_words_", fld), "v0.2.2", field_words(ty$tickets, fld))
rev_fields <- c("cut_review", "close_review", "spike_close_review")
add("review_field_words", "v0.2.2", sum(vapply(rev_fields, function(f) field_words(ty$cuts, f) + field_words(ty$workstreams, f), 0L)))
ratio_re <- "[0-9]+/[0-9]+ = [0-9]*\\.[0-9]+"
add("ratio_expression_occurrences", "tickets.yml", sum(lengths(regmatches(tx, gregexpr(ratio_re, tx)))))
add("ratio_expression_lines", "tickets.yml", sum(grepl(ratio_re, tx)))
add("breach_word_occurrences", "tickets.yml", sum(lengths(regmatches(tx, gregexpr("\\bbreach\\b", tx, perl = TRUE)))))
mp <- read("inst/design/ledgr_v0_2_2_spec_packet/macro_plan.md")
add("macro_plan_words", "v0.2.2", words(mp))
add("macro_plan_dated_amendments", "v0.2.2", sum(grepl("^20[0-9]{2}-[0-9]{2}-[0-9]{2} maintainer amendment", mp)))

# ---- Review counts per cut ----
cr <- read.csv(file.path(here, "cut_review_counts.csv"), stringsAsFactors = FALSE)
cr$phrase_on_line <- mapply(function(l, p) grepl(p, tx[l], fixed = TRUE), cr$line, cr$phrase)
ws_cut <- vapply(ty$workstreams, function(w) as.integer(w$cut), 0L)
names(ws_cut) <- vapply(ty$workstreams, function(w) as.character(w$id), "")
tk_cut <- vapply(ty$tickets, function(t) { w <- as.character(t$workstream); if (is.null(t$workstream) || is.na(ws_cut[w])) NA_integer_ else ws_cut[[w]] }, 0L)
tk_done <- vapply(ty$tickets, function(t) identical(t$status, "complete"), TRUE)
cr$completed_tickets <- vapply(cr$cut, function(k) sum(tk_done & tk_cut %in% k), 0L)
cr$dropped_tickets <- vapply(cr$cut, function(k) sum(vapply(ty$tickets, function(t) identical(t$status, "dropped"), TRUE) & tk_cut %in% k), 0L)
write.csv(cr, file.path(out, "cut_reviews.csv"), row.names = FALSE)
add("cuts_counted", "v0.2.2", nrow(cr))
add("cut_phrases_verified", "v0.2.2", sum(cr$phrase_on_line))
add("review_invocations_total", "v0.2.2", sum(cr$invocations))
add("recorded_denominator_total", "v0.2.2", sum(cr$recorded_tickets))
add("completed_tickets_total", "v0.2.2", sum(cr$completed_tickets))
add("cuts_recorded_ratio_above_0.5", "v0.2.2", sum(cr$invocations / cr$recorded_tickets > 0.5))

# ---- Claim sources ----
cl <- yaml::read_yaml("tests/claims.yml")$claims
src <- vapply(cl, function(c) paste(unlist(c$source), collapse = " "), "")
has_rfc <- grepl("RFC|[Ss]ynthesis|rfc_", src)
has_con <- grepl("contracts\\.md|[A-Z][a-z]+ Contract", src)
has_tk <- grepl("LDG-|Cut [0-9]|[Bb]atch|WS[0-9]|Workstream", src)
cls <- ifelse(has_rfc, "rfc_or_synthesis", ifelse(has_con & has_tk, "contract_and_ticket",
  ifelse(has_con, "contract_only", ifelse(has_tk, "ticket_only", "other"))))
for (k in sort(unique(cls), method = "radix")) add(paste0("claims_", k), "claims.yml", sum(cls == k))
add("claims_total", "claims.yml", length(cl))

S <- srt(do.call(rbind, rows), c("metric", "scope"))
write.csv(S, file.path(out, "summary.csv"), row.names = FALSE)
print(S, row.names = FALSE)
