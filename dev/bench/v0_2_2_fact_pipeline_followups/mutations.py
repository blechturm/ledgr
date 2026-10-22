"""WS45 mutation runner.

For each mutation: copy the worktree's tracked files with
`git ls-files -z | tar --null -T - -cf - | tar -xf - -C <copy>`, add the
compiled library, apply one exact replacement, run the named test files
with load_all(compile = FALSE) and record which registered blocks fail.

    python mutations.py <worktree> <scratch_dir> <out_csv> [ids...]
"""
import csv
import os
import shutil
import subprocess
import sys

RSCRIPT = r"C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe"
FA = "R/availability-facts.R"
CA = "R/corporate-action-settlement.R"
NEW = "fact-pipeline-followups"

MUTATIONS = [
    ("L1", "siblings numbered out of preorder", FA,
     "    entry[nodes] <- entry[owner] + 1L + sibling_offset",
     "    entry[nodes] <- entry[owner] + 1L", NEW, "LTB-0351"),
    ("L2", "acyclicity check dropped", FA,
     "  if (!all(reached)) {",
     "  if (FALSE) {", NEW, "LTB-0351"),
    ("L3", "conflict validator rebuilds lineage", FA,
     "    if (is.null(lineage)) lineage <- ledgr_status_lineage(rows)",
     "    lineage <- ledgr_status_lineage(rows)", NEW, "LTB-0351"),
    ("L4", "lineage built without supersession", FA,
     "  if (!any(supplied)) return(invisible(NULL))",
     "  if (!any(supplied)) return(invisible(ledgr_status_lineage(rows)))", NEW, "LTB-0351"),
    ("C1", "related pair counted once", FA,
     "    related <- related + 2 * sum(counted)",
     "    related <- related + sum(counted)", NEW, "LTB-0352"),
    ("C2", "ancestor scope ignored", FA,
     "    counted <- scope[ancestor] == scope[descendant] &",
     "    counted <- TRUE &", NEW, "LTB-0352"),
    ("C3", "touching half-open intervals overlap", FA,
     "    begun <- findInterval(base + end_rank[query] - 0.5, start_key) -",
     "    begun <- findInterval(base + end_rank[query] + 0.5, start_key) -", NEW, "LTB-0352"),
    ("R1", "resolved instants formatted per row", FA,
     "        fragment[row_index] <- sessions$open_evidence[session]",
     "        fragment[row_index] <- sessions$open_evidence[session]\n"
     "        invisible(ledgr_fact_time_token(frame[[field]][row_index]))", NEW, "LTB-0353"),
    ("R2", "evidence key order changed", FA,
     "      timezone = as.character(table$timezone),",
     "      zone = as.character(table$timezone),", NEW, "LTB-0353"),
    ("I1", "every bundle family rehashed", FA,
     "  for (i in which(pending)) {",
     "  for (i in seq_along(families)) {", NEW, "LTB-0354"),
    ("I2", "pending family rehashed unchecked", FA,
     "  if (!all(vapply(families[read], ledgr_fact_family_intact, logical(1)))) {",
     "  if (FALSE) {", NEW, "LTB-0354"),
    ("V1", "clock order checked before resolution", FA,
     "  ledgr_validate_equity_corporate_action_rows(rows, clocks = FALSE)",
     "  ledgr_validate_equity_corporate_action_rows(rows, clocks = TRUE)", NEW, "LTB-0355"),
    ("V2", "intervals not checked after resolution", FA,
     "      family$metadata,\n      intervals = TRUE\n    )",
     "      family$metadata,\n      intervals = FALSE\n    )", NEW, "LTB-0355"),
    ("K1", "supplied knowledge replaced (label mask)", FA,
     "  assume <- is.na(rows$knowledge_time) & !is.na(event)",
     "  assume <- is.na(labels$knowledge_time) & !is.na(event)", NEW, "LTB-0356"),
    ("K2", "entitlement preferred over effective", FA,
     "  event <- rows$effective_time\n  event_label <- labels$effective_time\n"
     "  from_entitlement <- is.na(event) & !is.na(rows$entitlement_time)\n"
     "  event[from_entitlement] <- rows$entitlement_time[from_entitlement]\n"
     "  event_label[from_entitlement] <- labels$entitlement_time[from_entitlement]",
     "  event <- rows$entitlement_time\n  event_label <- labels$entitlement_time\n"
     "  from_entitlement <- is.na(event) & !is.na(rows$effective_time)\n"
     "  event[from_entitlement] <- rows$effective_time[from_entitlement]\n"
     "  event_label[from_entitlement] <- labels$effective_time[from_entitlement]", NEW, "LTB-0356"),
    ("K3", "Date knowledge resolved to close", FA,
     '      if (field %in% c("entitlement_time", "effective_time", "payment_time")) {',
     '      if (field %in% c("entitlement_time", "effective_time", "payment_time", "knowledge_time")) {',
     NEW, "LTB-0356"),
    ("K4", "known-when-effective dropped", FA,
     "  assume <- is.na(rows$knowledge_time) & !is.na(event)",
     "  assume <- rep(FALSE, length(event))", NEW, "LTB-0356"),
    ("D1", "effective-only row passes silently", CA,
     "  entitlement_missing <- rows$complete &",
     "  entitlement_missing <- FALSE & rows$complete &", NEW, "LTB-0357"),
    ("D2", "refusal only in availability runs", CA,
     "  entitlement_missing <- rows$complete &",
     "  entitlement_missing <- isTRUE(dispositions_active) & rows$complete &", NEW, "LTB-0357"),
    ("P1", "supplied knowledge relabelled (BASE assume-effective mask)", FA,
     "    labels$knowledge_time[assume] <- labels$effective_from[assume]",
     "    relabel <- is.na(labels$knowledge_time)\n"
     "    labels$knowledge_time[relabel] <- labels$effective_from[relabel]", NEW, "LTB-0358"),
    ("P2", "assumed knowledge keeps no civil label", FA,
     "    labels$knowledge_time[assume] <- labels$effective_from[assume]",
     "    invisible(NULL)", NEW, "LTB-0358"),
    ("Q1", "cash dividend not refused", CA,
     '    "ordinary_cash_dividend", "cash_acquisition", "stock_acquisition",',
     '    "cash_acquisition", "stock_acquisition",', NEW, "LTB-0359"),
    ("S1", "sessions family not checked before resolution", FA,
     "  if (!all(vapply(families[read], ledgr_fact_family_intact, logical(1)))) {",
     "  if (!all(vapply(families[pending], ledgr_fact_family_intact, logical(1)))) {", NEW, "LTB-0354"),
    ("H1", "snapshot headers not ordered after resolution", FA,
     "        headers <- headers[order(",
     "        headers <- headers[seq_len(nrow(headers)) + 0L * order(", NEW, "LTB-0360"),
    ("D3", "unentitled row not carried", CA,
     "    unentitled <- state$entitlement_missing & !is.na(state$effective_idx) &",
     "    unentitled <- FALSE & state$entitlement_missing & !is.na(state$effective_idx) &",
     NEW, "LTB-0357"),
]

RUNNER = r'''
args <- commandArgs(trailingOnly = TRUE)
suppressMessages(pkgload::load_all(args[[1L]], quiet = TRUE, compile = FALSE))
res <- testthat::test_dir(file.path(args[[1L]], "tests", "testthat"), filter = args[[2L]],
  reporter = testthat::SilentReporter$new(), stop_on_failure = FALSE, load_package = "none")
df <- as.data.frame(res)
bad <- df$test[df$failed > 0 | df$error]
cat("FAILED_BLOCKS=", paste(unique(regmatches(bad, regexpr("LTB-[0-9]{4}", bad))), collapse = ";"), "\n", sep = "")
'''


def main():
    worktree, scratch, out_csv = sys.argv[1:4]
    wanted = set(sys.argv[4:])
    runner = os.path.join(scratch, "mutation_runner.R")
    with open(runner, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(RUNNER)
    rows = []
    for mid, label, path, old, new, filt, expected in MUTATIONS:
        if wanted and mid not in wanted:
            continue
        copy = os.path.join(scratch, "mut_" + mid)
        if os.path.exists(copy):
            shutil.rmtree(copy)
        os.makedirs(copy)
        # The tracked files at their working-tree state, as
        # `git ls-files -z | tar --null -T - -cf - | tar -xf - -C <copy>`
        # would copy them, with an explicit root.
        listed = subprocess.run(["git", "-C", worktree, "ls-files", "-z"],
                                capture_output=True, check=True).stdout.decode("utf-8")
        for rel in filter(None, listed.split("\0")):
            source = os.path.join(worktree, rel)
            if not os.path.isfile(source):
                continue
            dest = os.path.join(copy, rel)
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            shutil.copy2(source, dest)
        os.makedirs(os.path.join(copy, "src"), exist_ok=True)
        for name in os.listdir(os.path.join(worktree, "src")):
            if name.endswith((".dll", ".o", ".so")):
                shutil.copy2(os.path.join(worktree, "src", name), os.path.join(copy, "src", name))
        target = os.path.join(copy, path)
        with open(target, encoding="utf-8", newline="") as fh:
            text = fh.read()
        crlf = "\r\n" in text
        o, n = (old, new) if not crlf else (old.replace("\n", "\r\n"), new.replace("\n", "\r\n"))
        count = text.count(o)
        if count != 1:
            rows.append([mid, label, expected, "ANCHOR_COUNT_%d" % count, "", "INVALID"])
            continue
        with open(target, "w", encoding="utf-8", newline="") as fh:
            fh.write(text.replace(o, n))
        result = subprocess.run([RSCRIPT, runner, copy, filt], capture_output=True, text=True)
        line = [l for l in result.stdout.splitlines() if l.startswith("FAILED_BLOCKS=")]
        failed = line[0].split("=", 1)[1] if line else "RUNNER_ERROR"
        detected = expected in failed.split(";")
        rows.append([mid, label, expected, failed, filt, "DETECTED" if detected else "MISSED"])
        print(mid, failed, "DETECTED" if detected else "MISSED", flush=True)
        shutil.rmtree(copy, ignore_errors=True)
    new_file = not os.path.exists(out_csv)
    with open(out_csv, "a", newline="", encoding="utf-8") as fh:
        writer = csv.writer(fh)
        if new_file:
            writer.writerow(["mutation", "change", "expected_block", "failed_blocks", "test_filter", "result"])
        writer.writerows(rows)


if __name__ == "__main__":
    main()
