# Cut 17 (LDG-3232): the differential oracle's comparator.
#
#   Rscript dev/bench/v0_2_3_helper/oracle_compare.R --pin=<pin.rds> --candidate=<cand.rds>
#     [--out=<diffs.csv>] [--demo-drop-surface=<field>]
#
# Refuses (exit 2) when a manifest case (manifest.csv) is missing from either
# arm, a site of sites.csv has no manifest case, a record lacks a comparison
# surface, the pin does not reach a case's expected outcome or branch, or
# the two arms' captured views were built from different inputs. Then
# compares every case and exits 1 when any difference is found, printing
# one line per difference with its signal:
#   numeric      a double/integer/logical leaf differs (bitwise: signed zero, NaN)
#   character    a string differs
#   encoding     the same strings carry different Encoding() marks
#   names        a names attribute differs anywhere (values, nested evidence)
#   evidence     a difference below the sizing, sizing_evidence or origin attributes
#   attr_order   the same attributes in a different order
#   attributes   an attribute present on one side only
#   type         typeof or length differ
#   outcome      value on one side, error on the other
#   cond_class, message, call, parent, field   the terminal condition
#   precedence   a condition difference on a multi-invalid ("precedence") case
#   warning      the ordered warnings and messages differ
#   notes        the .notes bindings before or after differ
# --demo-drop-surface removes one surface from the candidate records first
# (a refusal demonstration).

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
}
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
pin <- readRDS(opt("pin"))
cand <- readRDS(opt("candidate"))
manifest <- utils::read.csv(file.path(here, "manifest.csv"), colClasses = "character", na.strings = character())
# Frozen outcomes: the refusal message in ASCII (non-ASCII as <U+XXXX>) and a
# digest of the notes bindings after the call ("" when the case has no notes).
msg_key <- function(m) iconv(enc2utf8(m), "UTF-8", "ASCII", sub = "Unicode")
notes_digest <- function(x) if (is.null(x)) "" else digest::digest(x)
sites <- utils::read.csv(file.path(here, "sites.csv"), stringsAsFactors = FALSE)
drop_surface <- opt("demo-drop-surface", "")
surfaces <- c("outcome", "value", "error", "signals", "notes_before", "notes_after", "notes_present", "reach")
if (nzchar(drop_surface)) cand$results <- lapply(cand$results, function(r) { r[[drop_surface]] <- NULL; r })

refuse <- character()
for (arm in c("pin", "candidate")) {
  r <- if (arm == "pin") pin$results else cand$results
  gone <- setdiff(manifest$case, names(r))
  if (length(gone)) refuse <- c(refuse, sprintf("missing_case: %s lacks %s", arm, paste(gone, collapse = ", ")))
  extra <- setdiff(names(r), manifest$case)
  if (length(extra)) refuse <- c(refuse, sprintf("unregistered_case: %s has %s", arm, paste(extra, collapse = ", ")))
  for (id in intersect(manifest$case, names(r))) {
    absent <- setdiff(surfaces, names(r[[id]]))
    if (length(absent)) refuse <- c(refuse, sprintf("missing_surface: %s %s lacks %s", arm, id, paste(absent, collapse = ", ")))
  }
}
covered <- unique(unlist(strsplit(manifest$sites[nzchar(manifest$sites)], ";", fixed = TRUE)))
uncovered <- setdiff(sites$site, covered)
if (length(uncovered)) refuse <- c(refuse, sprintf("uncovered_site: %s", paste(uncovered, collapse = ", ")))
unknown_sites <- setdiff(covered, sites$site)
if (length(unknown_sites)) refuse <- c(refuse, sprintf("unknown_site: %s", paste(unknown_sites, collapse = ", ")))
for (i in seq_len(nrow(manifest))) {
  id <- manifest$case[[i]]; r <- pin$results[[id]]
  if (is.null(r) || is.null(r$outcome)) next
  if (manifest$expect[[i]] == "value" && r$outcome != "value") {
    refuse <- c(refuse, sprintf("pin_reach: %s expected a value, pin refused with %s", id, paste(r$error$class, collapse = "/")))
  } else if (startsWith(manifest$expect[[i]], "error:")) {
    want <- sub("^error:", "", manifest$expect[[i]])
    if (r$outcome != "error" || !want %in% r$error$class) refuse <- c(refuse, sprintf("pin_reach: %s expected %s, pin gave %s", id, want,
      if (r$outcome == "error") paste(r$error$class, collapse = "/") else "a value"))
  }
  if (isFALSE(r$reach)) refuse <- c(refuse, sprintf("pin_reach: %s does not reach its named branch on the pin", id))
  # the frozen outcome: the pin's refusal message and its notes after the call
  got_message <- if (r$outcome == "error") msg_key(r$error$message) else ""
  if (!identical(got_message, manifest$expect_message[[i]])) {
    refuse <- c(refuse, sprintf("pin_reach: %s refusal message is not the frozen one", id))
  }
  if (!identical(notes_digest(r$notes_after), manifest$expect_notes[[i]])) {
    refuse <- c(refuse, sprintf("pin_reach: %s notes after the call are not the frozen ones", id))
  }
}
pv <- pin$meta$provenance; cv <- cand$meta$provenance
if (!identical(pv$inputs_digest, cv$inputs_digest)) refuse <- c(refuse, "view_inputs: the arms captured views from different inputs")
if (length(refuse)) {
  cat("ORACLE REFUSED\n", paste0("  ", refuse, collapse = "\n"), "\n", sep = "")
  quit(status = 2L)
}

diffs <- list()
note <- function(case, signal, path, detail) diffs[[length(diffs) + 1L]] <<- data.frame(case = case, signal = signal, path = path,
  detail = substr(detail, 1L, 200L), stringsAsFactors = FALSE)
in_evidence <- function(path) grepl("@(sizing|sizing_evidence|origin|sizing_skipped)", path)
leaf_eq <- function(a, b) {
  if (is.double(a)) return(identical(writeBin(a, raw()), writeBin(b, raw())))
  identical(a, b)
}
cmp <- function(case, a, b, path) {
  if (!identical(typeof(a), typeof(b)) || length(a) != length(b)) {
    note(case, if (in_evidence(path)) "evidence" else "type", path, sprintf("%s[%d] vs %s[%d]", typeof(a), length(a), typeof(b), length(b)))
    return(invisible())
  }
  aa <- attributes(a); ba <- attributes(b)
  an <- names(aa) %||% character(); bn <- names(ba) %||% character()
  if (!setequal(an, bn)) {
    lost <- c(setdiff(an, bn), setdiff(bn, an))
    detail <- sprintf("attributes {%s} vs {%s}", paste(an, collapse = ","), paste(bn, collapse = ","))
    note(case, if (in_evidence(path)) "evidence" else if ("names" %in% lost) "names" else "attributes", path, detail)
    # an added or removed names attribute is a names difference wherever it is
    if (in_evidence(path) && "names" %in% lost) note(case, "names", path, detail)
  } else if (!identical(an, bn)) note(case, "attr_order", path, sprintf("{%s} vs {%s}", paste(an, collapse = ","), paste(bn, collapse = ",")))
  for (n in intersect(an, bn)) {
    p <- paste0(path, "@", n)
    before <- length(diffs)
    cmp(case, aa[[n]], ba[[n]], p)
    if (n == "names" && length(diffs) > before) note(case, "names", p, "names attribute differs")
  }
  if (is.list(a) || is.environment(a)) {
    if (is.environment(a)) { note(case, "type", path, "environment in a record"); return(invisible()) }
    for (i in seq_along(a)) cmp(case, a[[i]], b[[i]], paste0(path, "[[", i, "]]"))
  } else if (is.character(a)) {
    if (!identical(a, b)) note(case, if (in_evidence(path)) "evidence" else "character", path, "strings differ")
    else if (!identical(Encoding(a), Encoding(b))) note(case, "encoding", path, sprintf("%s vs %s", paste(Encoding(a), collapse = ","),
                                                                                           paste(Encoding(b), collapse = ",")))
  } else if (is.language(a) || is.function(a)) {
    if (!identical(a, b)) note(case, "type", path, "language differs")
  } else if (!is.null(a) && !leaf_eq(strip(a), strip(b))) {
    note(case, if (in_evidence(path)) "evidence" else "numeric", path, "values differ")
  }
  invisible()
}
`%||%` <- function(a, b) if (is.null(a)) b else a
strip <- function(x) { if (!is.null(x)) attributes(x) <- NULL; x }
for (id in manifest$case) {
  p <- pin$results[[id]]; c <- cand$results[[id]]
  prec <- identical(p$tag, "precedence")
  if (!identical(p$outcome, c$outcome)) { note(id, "outcome", "", sprintf("%s vs %s", p$outcome, c$outcome)); next }
  if (p$outcome == "value") cmp(id, p$value, c$value, "value")
  else {
    pe <- p$error; ce <- c$error
    ck <- function(sig, a, b, path) if (!identical(a, b)) note(id, if (prec) "precedence" else sig, path, "condition differs")
    ck("cond_class", pe$class, ce$class, "error$class")
    ck("message", pe$message, ce$message, "error$message")
    ck("call", pe$call, ce$call, "error$call")
    ck("parent", pe$parent, ce$parent, "error$parent")
    ck("field", pe$field_names, ce$field_names, "error$field_names")
    ck("field", pe$fields, ce$fields, "error$fields")
    if (!prec && identical(pe$class, ce$class) && identical(pe$message, ce$message)) {
      cmp(id, pe[c("class", "message", "fields")], ce[c("class", "message", "fields")], "error")
    }
  }
  if (!identical(p$signals, c$signals)) note(id, "warning", "signals", sprintf("%d vs %d signals", length(p$signals), length(c$signals)))
  if (!identical(p$notes_present, c$notes_present)) note(id, "notes", "notes_present", "notes presence differs")
  for (s in c("notes_before", "notes_after")) {
    before <- length(diffs)
    if (!identical(p[[s]], c[[s]])) note(id, "notes", s, "notes bindings differ")
    if (!is.null(p[[s]]) && !is.null(c[[s]]) && identical(names(p[[s]]), names(c[[s]]))) cmp(id, p[[s]], c[[s]], s)
  }
}
d <- if (length(diffs)) do.call(rbind, diffs) else data.frame(case = character(), signal = character(), path = character(), detail = character())
out <- opt("out", "")
if (nzchar(out)) utils::write.csv(d, out, row.names = FALSE)
cat(sprintf("oracle: %d cases, %d sites; pin %s (%s), candidate %s (%s), mutation '%s'; %d differences%s\n",
            nrow(manifest), nrow(sites), pin$meta$source, pin$meta$installed_from, cand$meta$source, cand$meta$installed_from,
            cand$meta$mutation, nrow(d), if (nrow(d)) paste0(": signals ", paste(sort(unique(d$signal)), collapse = ", ")) else ""))
if (nrow(d)) {
  print(utils::head(d, 12L), row.names = FALSE)
  quit(status = 1L)
}
