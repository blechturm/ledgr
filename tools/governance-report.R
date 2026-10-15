#!/usr/bin/env Rscript

# Report structural drift in the design-memory governance surface.
#
# This tool is intentionally report-only. Structural findings are printed and
# never affect its exit status. Missing or malformed inputs are invocation
# errors and do return a non-zero status.

governance_abort <- function(message) {
  stop(structure(
    list(message = message, call = NULL),
    class = c("ledgr_governance_report_input", "error", "condition")
  ))
}

governance_read_lines <- function(path) {
  if (!file.exists(path)) {
    governance_abort(sprintf("required input does not exist: %s", path))
  }
  out <- tryCatch(
    readLines(path, warn = FALSE, encoding = "UTF-8"),
    error = function(e) governance_abort(sprintf(
      "cannot read required input '%s': %s",
      path,
      conditionMessage(e)
    ))
  )
  out
}

governance_read_yaml <- function(path) {
  governance_read_lines(path)
  tryCatch(
    yaml::read_yaml(path),
    error = function(e) governance_abort(sprintf(
      "malformed YAML input '%s': %s",
      path,
      conditionMessage(e)
    ))
  )
}

governance_rel_path <- function(path) {
  path <- gsub("\\\\", "/", path)
  parts <- strsplit(path, "/", fixed = TRUE)[[1L]]
  kept <- character()
  for (part in parts) {
    if (!nzchar(part) || identical(part, ".")) {
      next
    }
    if (identical(part, "..")) {
      if (!length(kept)) {
        return(NA_character_)
      }
      kept <- head(kept, -1L)
    } else {
      kept <- c(kept, part)
    }
  }
  paste(kept, collapse = "/")
}

governance_code_free <- function(lines) {
  fence <- grepl("^[[:space:]]*(```|~~~)", lines)
  inside <- (cumsum(fence) %% 2L == 1L) | fence
  lines[inside] <- ""
  gsub("`[^`]*`", "", lines)
}

governance_slug <- function(text) {
  text <- gsub("\\[([^]]*)\\]\\([^)]*\\)", "\\1", text)
  text <- gsub("[*`]", "", text)
  text <- tolower(trimws(text))
  text <- gsub("[^a-z0-9 _-]", "", text)
  gsub(" ", "-", text, fixed = TRUE)
}

governance_empty_findings <- function() {
  data.frame(
    severity = character(),
    kind = character(),
    source = character(),
    line = integer(),
    target = character(),
    message = character(),
    stringsAsFactors = FALSE
  )
}

governance_finding <- function(severity, kind, source, line, target, message) {
  data.frame(
    severity = severity,
    kind = kind,
    source = source,
    line = as.integer(line),
    target = target,
    message = message,
    stringsAsFactors = FALSE
  )
}

governance_bind_findings <- function(rows) {
  rows <- rows[!vapply(rows, is.null, logical(1L))]
  rows <- rows[vapply(rows, nrow, integer(1L)) > 0L]
  if (!length(rows)) {
    return(governance_empty_findings())
  }
  do.call(rbind, rows)
}

governance_links <- function(source, lines) {
  text <- governance_code_free(lines)
  definitions <- list()
  definition_re <- "^[[:space:]]{0,3}\\[([^]]+)\\]:[[:space:]]*<?([^[:space:]>]+)>?"
  for (i in seq_along(text)) {
    match <- regmatches(text[[i]], regexec(definition_re, text[[i]], perl = TRUE))[[1L]]
    if (length(match) == 3L) {
      definitions[[tolower(match[[2L]])]] <- match[[3L]]
    }
  }

  rows <- list()
  add_target <- function(line, column, target) {
    if (!nzchar(target)) {
      return(invisible(NULL))
    }
    rows[[length(rows) + 1L]] <<- data.frame(
      source = source,
      line = as.integer(line),
      column = as.integer(column),
      target = target,
      stringsAsFactors = FALSE
    )
    invisible(NULL)
  }

  inline_re <- "!?\\[(?:[^][]|\\[[^]]*\\])*\\]\\([[:space:]]*<?([^)[:space:]>]+)>?(?:[[:space:]]+[\"'(][^)]*)?\\)"
  reference_re <- "\\[([^]]+)\\]\\[([^]]*)\\]"
  for (i in seq_along(text)) {
    inline <- gregexpr(inline_re, text[[i]], perl = TRUE)[[1L]]
    if (!identical(inline[[1L]], -1L)) {
      matches <- regmatches(text[[i]], list(inline))[[1L]]
      for (j in seq_along(matches)) {
        target <- sub(inline_re, "\\1", matches[[j]], perl = TRUE)
        add_target(i, inline[[j]], target)
      }
    }
    references <- gregexpr(reference_re, text[[i]], perl = TRUE)[[1L]]
    if (!identical(references[[1L]], -1L)) {
      matches <- regmatches(text[[i]], list(references))[[1L]]
      for (j in seq_along(matches)) {
        parts <- regmatches(matches[[j]], regexec(reference_re, matches[[j]], perl = TRUE))[[1L]]
        id <- tolower(if (nzchar(parts[[3L]])) parts[[3L]] else parts[[2L]])
        if (!is.null(definitions[[id]])) {
          add_target(i, references[[j]], definitions[[id]])
        }
      }
    }
  }
  if (!length(rows)) {
    return(data.frame(
      source = character(), line = integer(), column = integer(),
      target = character(), stringsAsFactors = FALSE
    ))
  }
  out <- do.call(rbind, rows)
  out <- out[order(out$line, out$column, method = "radix"), , drop = FALSE]
  out$occurrence <- ave(
    seq_len(nrow(out)),
    interaction(out$source, out$target, drop = TRUE),
    FUN = seq_along
  )
  rownames(out) <- NULL
  out
}

governance_anchor_info <- function(lines) {
  text <- governance_code_free(lines)
  headings <- list()
  for (i in seq_along(text)) {
    match <- regmatches(
      text[[i]],
      regexec("^#{1,6}[[:space:]]+(.+?)[[:space:]]*#*[[:space:]]*$", text[[i]], perl = TRUE)
    )[[1L]]
    if (length(match) != 2L) {
      next
    }
    label <- match[[2L]]
    explicit <- regmatches(label, regexpr("\\{#[A-Za-z0-9_:.-]+", label, perl = TRUE))
    label <- sub("[[:space:]]*\\{#[^}]*\\}[[:space:]]*$", "", label)
    headings[[length(headings) + 1L]] <- data.frame(
      line = i,
      base_slug = governance_slug(label),
      explicit_id = if (length(explicit) && nzchar(explicit)) sub("^\\{#", "", explicit) else "",
      stringsAsFactors = FALSE
    )
  }
  heading_frame <- if (length(headings)) do.call(rbind, headings) else data.frame(
    line = integer(), base_slug = character(), explicit_id = character(),
    stringsAsFactors = FALSE
  )
  seen <- integer()
  names(seen) <- character()
  rendered <- character(nrow(heading_frame))
  for (i in seq_len(nrow(heading_frame))) {
    base <- heading_frame$base_slug[[i]]
    count <- if (base %in% names(seen)) seen[[base]] else 0L
    rendered[[i]] <- if (count == 0L) base else paste0(base, "-", count)
    seen[[base]] <- count + 1L
  }
  heading_frame$slug <- rendered

  explicit_rows <- list()
  explicit_re <- "(?:id=[\"']([^\"']+)[\"']|\\{#([A-Za-z0-9_:.-]+))"
  for (i in seq_along(text)) {
    positions <- gregexpr(explicit_re, text[[i]], perl = TRUE)[[1L]]
    if (identical(positions[[1L]], -1L)) {
      next
    }
    matches <- regmatches(text[[i]], list(positions))[[1L]]
    for (value in matches) {
      id <- sub("^.*id=[\"']([^\"']+)[\"'].*$", "\\1", value, perl = TRUE)
      if (identical(id, value)) {
        id <- sub("^\\{#", "", value)
        id <- sub("\\}$", "", id)
      }
      explicit_rows[[length(explicit_rows) + 1L]] <- data.frame(
        line = i,
        id = tolower(id),
        stringsAsFactors = FALSE
      )
    }
  }
  explicit_frame <- if (length(explicit_rows)) do.call(rbind, explicit_rows) else data.frame(
    line = integer(), id = character(), stringsAsFactors = FALSE
  )
  list(
    headings = heading_frame,
    explicit = explicit_frame,
    anchors = unique(tolower(c(
      heading_frame$slug,
      heading_frame$explicit_id[nzchar(heading_frame$explicit_id)],
      explicit_frame$id
    )))
  )
}

governance_resolve_target <- function(source, target) {
  decoded <- utils::URLdecode(target)
  decoded <- sub("[?].*$", "", decoded)
  path <- sub("#.*$", "", decoded)
  fragment <- if (grepl("#", decoded, fixed = TRUE)) {
    sub("^[^#]*#", "", decoded)
  } else {
    ""
  }
  resolved <- if (!nzchar(path)) {
    source
  } else if (startsWith(path, "/")) {
    governance_rel_path(sub("^/+", "", path))
  } else {
    governance_rel_path(file.path(dirname(source), path))
  }
  list(path = resolved, fragment = tolower(fragment))
}

governance_is_external <- function(target) {
  grepl("^[[:alpha:]][[:alnum:]+.-]*:", target) ||
    startsWith(target, "//")
}

governance_scan_links <- function(root, sources, tracked) {
  tracked_dirs <- unique(unlist(lapply(strsplit(tracked, "/", fixed = TRUE), function(parts) {
    if (length(parts) < 2L) {
      return(character())
    }
    vapply(seq_len(length(parts) - 1L), function(i) {
      paste(parts[seq_len(i)], collapse = "/")
    }, character(1L))
  })))
  all_links <- list()
  anchors <- new.env(parent = emptyenv())
  lines_cache <- new.env(parent = emptyenv())
  read_rel <- function(path) {
    cached <- lines_cache[[path]]
    if (!is.null(cached)) {
      return(cached)
    }
    value <- governance_read_lines(file.path(root, path))
    assign(path, value, envir = lines_cache)
    value
  }
  anchor_rel <- function(path) {
    cached <- anchors[[path]]
    if (!is.null(cached)) {
      return(cached)
    }
    value <- governance_anchor_info(read_rel(path))
    assign(path, value, envir = anchors)
    value
  }
  for (source in sources) {
    all_links[[source]] <- governance_links(source, read_rel(source))
  }
  link_frame <- do.call(rbind, all_links)
  if (is.null(link_frame)) {
    link_frame <- governance_links("", character())
  }
  rownames(link_frame) <- NULL
  findings <- list()
  for (i in seq_len(nrow(link_frame))) {
    link <- link_frame[i, , drop = FALSE]
    if (governance_is_external(link$target)) {
      next
    }
    resolved <- governance_resolve_target(link$source, link$target)
    if (is.na(resolved$path)) {
      findings[[length(findings) + 1L]] <- governance_finding(
        "structural", "broken_local_target", link$source, link$line,
        link$target, "local target escapes the repository root"
      )
      next
    }
    absolute <- file.path(root, resolved$path)
    exists <- file.exists(absolute) || dir.exists(absolute)
    is_tracked <- resolved$path %in% tracked || resolved$path %in% tracked_dirs
    if (!exists) {
      findings[[length(findings) + 1L]] <- governance_finding(
        "structural", "broken_local_target", link$source, link$line,
        link$target, "local target does not exist in the working tree"
      )
      next
    }
    if (!is_tracked) {
      findings[[length(findings) + 1L]] <- governance_finding(
        "advisory", "untracked_local_target", link$source, link$line,
        link$target, "local target exists but is untracked"
      )
    }
    if (!nzchar(resolved$fragment) ||
        !grepl("[.](md|qmd)$", resolved$path, ignore.case = TRUE)) {
      next
    }
    info <- anchor_rel(resolved$path)
    if (!(resolved$fragment %in% info$anchors)) {
      findings[[length(findings) + 1L]] <- governance_finding(
        "structural", "broken_local_anchor", link$source, link$line,
        link$target, "fragment does not resolve in the working-tree target"
      )
      next
    }
    base_count <- sum(info$headings$base_slug == resolved$fragment)
    if (base_count > 1L) {
      findings[[length(findings) + 1L]] <- governance_finding(
        "structural", "ambiguous_heading_slug", link$source, link$line,
        link$target, "used heading slug is ambiguous before renderer suffixing"
      )
    }
  }

  for (source in sources) {
    info <- anchor_rel(source)
    duplicated <- unique(info$explicit$id[duplicated(info$explicit$id)])
    for (id in duplicated) {
      row <- info$explicit[info$explicit$id == id, , drop = FALSE][2L, ]
      findings[[length(findings) + 1L]] <- governance_finding(
        "structural", "duplicate_explicit_id", source, row$line,
        paste0("#", id), "explicit ID is duplicated in one document"
      )
    }
  }
  list(
    findings = governance_bind_findings(findings),
    links = link_frame,
    read_rel = read_rel,
    anchor_rel = anchor_rel
  )
}

governance_header_end <- function(lines) {
  first_section <- grep("^##[[:space:]]+", lines)[1L]
  if (is.na(first_section)) {
    return(min(25L, length(lines)))
  }
  max(0L, min(25L, first_section - 1L))
}

governance_header_value <- function(lines, field) {
  pattern <- sprintf(
    "^[[:space:]]*(?:[*][*])?%s:(?:[*][*])?[[:space:]]*(.*)$",
    field
  )
  matches <- grep(
    pattern,
    head(lines, governance_header_end(lines)),
    value = TRUE,
    ignore.case = TRUE
  )
  if (!length(matches)) {
    return("")
  }
  trimws(sub(pattern, "\\1", matches[[1L]], ignore.case = TRUE))
}

governance_header_line <- function(lines, field) {
  pattern <- sprintf(
    "^[[:space:]]*(?:[*][*])?%s:(?:[*][*])?",
    field
  )
  match <- grep(
    pattern,
    head(lines, governance_header_end(lines)),
    ignore.case = TRUE
  )
  if (length(match)) match[[1L]] else 1L
}

governance_scan_headers <- function(root, sources) {
  roles <- c("record", "living", "mixed")
  statuses <- c(
    "draft", "under review", "accepted", "working", "consolidated",
    "superseded", "superseded in part", "rejected"
  )
  findings <- list()
  for (source in sources) {
    lines <- governance_read_lines(file.path(root, source))
    role <- governance_header_value(lines, "Role")
    status <- governance_header_value(lines, "Status")
    authority <- governance_header_value(lines, "Authority")
    role_token <- tolower(trimws(sub("[;.,].*$", "", role)))
    role_has_authority <- grepl(
      "\\b(non[- ]binding|binds|binding|authority)\\b",
      role,
      ignore.case = TRUE,
      perl = TRUE
    )
    status_lower <- tolower(status)
    status_token <- if (grepl("^amended[[:space:]]+[0-9]{4}-[0-9]{2}-[0-9]{2}", status_lower)) {
      "amended"
    } else {
      matched <- statuses[vapply(statuses, function(token) {
        startsWith(status_lower, token)
      }, logical(1L))]
      if (length(matched)) matched[[which.max(nchar(matched))]] else ""
    }
    if (!nzchar(role)) {
      findings[[length(findings) + 1L]] <- governance_finding(
        "structural", "missing_role", source, 1L, "metadata:role",
        "governance source has no Role header"
      )
    } else if (!(role_token %in% roles)) {
      findings[[length(findings) + 1L]] <- governance_finding(
        "structural", "invalid_role", source,
        governance_header_line(lines, "Role"), "metadata:role",
        sprintf("invalid Role token '%s'", role_token)
      )
    }
    if (!nzchar(status)) {
      findings[[length(findings) + 1L]] <- governance_finding(
        "structural", "missing_status", source, 1L, "metadata:status",
        "governance source has no Status header"
      )
    } else if (!nzchar(status_token)) {
      findings[[length(findings) + 1L]] <- governance_finding(
        "structural", "invalid_status", source,
        governance_header_line(lines, "Status"), "metadata:status",
        sprintf("invalid Status token '%s'", status)
      )
    }
    if (!nzchar(authority) && !role_has_authority) {
      findings[[length(findings) + 1L]] <- governance_finding(
        "structural", "missing_authority", source, 1L, "metadata:authority",
        "governance source has no Authority header or non-binding declaration"
      )
    }
    if (identical(status_token, "amended") &&
        !any(grepl("^[[:space:]]*(?:[*][*])?Amendments:(?:[*][*])?.*\\[[^]]+\\]\\(", head(lines, governance_header_end(lines)), perl = TRUE))) {
      findings[[length(findings) + 1L]] <- governance_finding(
        "structural", "missing_amendment_provenance", source,
        governance_header_line(lines, "Status"), "metadata:amendments",
        "amended status lacks a dated linked amendment header"
      )
    }
    if (identical(status_token, "consolidated") &&
        !any(grepl("^[[:space:]]*(?:[*][*])?Receiver:(?:[*][*])?.*\\[[^]]+\\]\\(", head(lines, governance_header_end(lines)), perl = TRUE))) {
      findings[[length(findings) + 1L]] <- governance_finding(
        "structural", "missing_receiver_provenance", source,
        governance_header_line(lines, "Status"), "metadata:receiver",
        "consolidated status lacks a linked receiving address"
      )
    }
    if (status_token %in% c("superseded", "superseded in part") &&
        !any(grepl("^[[:space:]]*(?:[*][*])?Replacement:(?:[*][*])?.*20[0-9]{2}-[0-9]{2}-[0-9]{2}.*\\[[^]]+\\]\\(", head(lines, governance_header_end(lines)), perl = TRUE))) {
      findings[[length(findings) + 1L]] <- governance_finding(
        "structural", "missing_replacement_provenance", source,
        governance_header_line(lines, "Status"), "metadata:replacement",
        "superseded status lacks a dated linked replacement"
      )
    }
    if (identical(status_token, "superseded in part") &&
        !any(grepl("^[[:space:]]*(?:[*][*])?Operative remainder:(?:[*][*])?.+", head(lines, governance_header_end(lines)), perl = TRUE))) {
      findings[[length(findings) + 1L]] <- governance_finding(
        "structural", "missing_remainder_provenance", source,
        governance_header_line(lines, "Status"), "metadata:remainder",
        "partial supersession lacks an operative-remainder declaration"
      )
    }
    if (identical(status_token, "rejected") &&
        !any(grepl("^[[:space:]]*(?:[*][*])?Reason:(?:[*][*])?.+", head(lines, governance_header_end(lines)), perl = TRUE))) {
      findings[[length(findings) + 1L]] <- governance_finding(
        "structural", "missing_rejection_reason", source,
        governance_header_line(lines, "Status"), "metadata:reason",
        "rejected status lacks a concise durable reason"
      )
    }
  }
  governance_bind_findings(findings)
}

governance_table_cells <- function(line) {
  value <- trimws(line)
  if (!startsWith(value, "|") || !endsWith(value, "|")) {
    return(character())
  }
  trimws(strsplit(sub("[|]$", "", sub("^[|]", "", value)), "|", fixed = TRUE)[[1L]])
}

governance_first_link <- function(cell) {
  match <- regmatches(
    cell,
    regexec("\\[[^]]+\\]\\(<?([^)[:space:]>]+)>?", cell, perl = TRUE)
  )[[1L]]
  if (length(match) == 2L) match[[2L]] else ""
}

governance_tables <- function(lines) {
  out <- list()
  i <- 1L
  while (i <= length(lines) - 2L) {
    header <- governance_table_cells(lines[[i]])
    delimiter <- governance_table_cells(lines[[i + 1L]])
    if (length(header) && length(delimiter) == length(header) &&
        all(grepl("^:?-{3,}:?$", delimiter))) {
      rows <- list()
      j <- i + 2L
      while (j <= length(lines)) {
        cells <- governance_table_cells(lines[[j]])
        if (length(cells) != length(header)) {
          break
        }
        names(cells) <- header
        rows[[length(rows) + 1L]] <- list(line = j, cells = cells)
        j <- j + 1L
      }
      out[[length(out) + 1L]] <- list(line = i, header = header, rows = rows)
      i <- j
    } else {
      i <- i + 1L
    }
  }
  out
}

governance_section_lines <- function(lines, fragment) {
  info <- governance_anchor_info(lines)
  hit <- which(tolower(info$headings$slug) == tolower(fragment) |
    tolower(info$headings$explicit_id) == tolower(fragment))
  if (!length(hit)) {
    return(integer())
  }
  start <- info$headings$line[[hit[[1L]]]]
  next_lines <- info$headings$line[info$headings$line > start]
  end <- if (length(next_lines)) min(next_lines) - 1L else length(lines)
  seq.int(start, end)
}

governance_section_fragment_at_line <- function(lines, line) {
  info <- governance_anchor_info(lines)
  hit <- which(info$headings$line <= line)
  if (!length(hit)) {
    return("")
  }
  row <- info$headings[tail(hit, 1L), , drop = FALSE]
  tolower(if (nzchar(row$explicit_id[[1L]])) {
    row$explicit_id[[1L]]
  } else {
    row$slug[[1L]]
  })
}

governance_link_resolves_to <- function(source, target, expected_path, expected_fragment = "") {
  resolved <- governance_resolve_target(source, target)
  if (is.na(resolved$path) || !identical(resolved$path, expected_path)) {
    return(FALSE)
  }
  !nzchar(expected_fragment) || identical(resolved$fragment, tolower(expected_fragment))
}

governance_scan_mappings <- function(root, sources) {
  findings <- list()
  source_maps <- list()
  bridge_rows <- list()
  for (source in sources) {
    lines <- governance_read_lines(file.path(root, source))
    tables <- governance_tables(lines)
    for (table in tables) {
      normalized_header <- tolower(gsub("[*`]", "", table$header))
      if (all(c("target/address", "disposition", "replacement/retained") %in% normalized_header)) {
        target_i <- match("target/address", normalized_header)
        disposition_i <- match("disposition", normalized_header)
        replacement_i <- match("replacement/retained", normalized_header)
        remainder_i <- match("operative remainder", normalized_header)
        for (row in table$rows) {
          target <- governance_first_link(row$cells[[target_i]])
          replacement <- governance_first_link(row$cells[[replacement_i]])
          disposition <- tolower(gsub("[*`]", "", trimws(row$cells[[disposition_i]])))
          remainder <- if (!is.na(remainder_i)) governance_first_link(row$cells[[remainder_i]]) else ""
          map <- list(
            source = source,
            line = row$line,
            target = target,
            replacement = replacement,
            disposition = disposition,
            remainder = remainder,
            table_line = table$line
          )
          source_maps[[length(source_maps) + 1L]] <- map
          if (!(disposition %in% c("superseded", "amended", "unchanged", "superseded in part"))) {
            findings[[length(findings) + 1L]] <- governance_finding(
              "structural", "invalid_disposition", source, row$line,
              "mapping:disposition", sprintf("invalid change-map disposition '%s'", disposition)
            )
            next
          }
          if (!nzchar(target) || !nzchar(replacement)) {
            findings[[length(findings) + 1L]] <- governance_finding(
              "structural", "malformed_change_row", source, row$line,
              "mapping:row", "change-map row lacks a linked target or replacement"
            )
            next
          }
          if (identical(disposition, "superseded in part") && !nzchar(remainder)) {
            findings[[length(findings) + 1L]] <- governance_finding(
              "structural", "missing_declared_remainder", source, row$line,
              target, "partial-supersession row lacks a linked operative remainder"
            )
          }
          if (identical(disposition, "unchanged")) {
            next
          }
          target_resolved <- governance_resolve_target(source, target)
          replacement_resolved <- governance_resolve_target(source, replacement)
          if (is.na(target_resolved$path) || !file.exists(file.path(root, target_resolved$path))) {
            next
          }
          target_lines <- governance_read_lines(file.path(root, target_resolved$path))
          target_links <- governance_links(target_resolved$path, target_lines)
          first_section <- grep("^##[[:space:]]+", target_lines)[1L]
          header_end <- if (is.na(first_section)) {
            min(25L, length(target_lines))
          } else {
            min(25L, first_section - 1L)
          }
          header_links <- target_links[target_links$line <= header_end, , drop = FALSE]
          has_notice <- any(vapply(header_links$target, function(value) {
            governance_link_resolves_to(
              target_resolved$path,
              value,
              source
            )
          }, logical(1L)))
          if (!has_notice) {
            findings[[length(findings) + 1L]] <- governance_finding(
              "structural", "missing_target_notice", target_resolved$path, 1L,
              target, sprintf("changed row at %s:%d lacks a linked target header notice", source, row$line)
            )
          }
          section <- governance_section_lines(target_lines, target_resolved$fragment)
          section_links <- target_links[target_links$line %in% section, , drop = FALSE]
          has_marker <- any(vapply(section_links$target, function(value) {
            governance_link_resolves_to(
              target_resolved$path,
              value,
              replacement_resolved$path,
              replacement_resolved$fragment
            )
          }, logical(1L)))
          if (!has_marker) {
            findings[[length(findings) + 1L]] <- governance_finding(
              "structural", "missing_target_marker", target_resolved$path,
              if (length(section)) min(section) else 1L, target,
              sprintf("changed row at %s:%d lacks a matching section marker", source, row$line)
            )
          }
        }
      }

      state_i <- match("state", normalized_header)
      source_i <- match("exact binding source sections", normalized_header)
      receiver_i <- match("missing consolidation", normalized_header)
      topic_i <- match("topic", normalized_header)
      if (!anyNA(c(state_i, source_i, receiver_i, topic_i))) {
        for (row in table$rows) {
          state <- tolower(gsub("[*`]", "", trimws(row$cells[[state_i]])))
          topic <- governance_first_link(row$cells[[topic_i]])
          binding <- governance_first_link(row$cells[[source_i]])
          receiver <- governance_first_link(row$cells[[receiver_i]])
          bridge_rows[[length(bridge_rows) + 1L]] <- list(
            source = source,
            line = row$line,
            state = state,
            topic = topic,
            binding = binding,
            receiver = receiver
          )
          if (!(state %in% c("pending", "consolidated, awaiting closeout"))) {
            findings[[length(findings) + 1L]] <- governance_finding(
              "structural", "invalid_row_state", source, row$line,
              "row-state", sprintf("invalid bridge row state '%s'", state)
            )
          }
        }
      }
    }
  }

  map_sources <- unique(vapply(source_maps, `[[`, character(1L), "source"))
  if (length(map_sources)) {
    for (source in sources) {
      lines <- governance_read_lines(file.path(root, source))
      links <- governance_links(source, lines)
      if (!nrow(links)) {
        next
      }
      resolved_links <- lapply(seq_len(nrow(links)), function(i) {
        governance_resolve_target(source, links$target[[i]])
      })
      points_to_map <- vapply(
        resolved_links,
        function(value) !is.na(value$path) && value$path %in% map_sources,
        logical(1L)
      )
      if (!any(points_to_map)) {
        next
      }

      header_end <- governance_header_end(lines)
      notice_lines <- grep(
        "^[[:space:]]*(?:[*][*])?(Amendments|Replacement|Receiver):",
        head(lines, header_end),
        ignore.case = TRUE,
        perl = TRUE
      )
      notice_links <- which(points_to_map & links$line %in% notice_lines)
      for (i in notice_links) {
        has_row <- any(vapply(source_maps, function(map) {
          target <- governance_resolve_target(map$source, map$target)
          identical(map$source, resolved_links[[i]]$path) &&
            !is.na(target$path) && identical(target$path, source)
        }, logical(1L)))
        if (!has_row) {
          findings[[length(findings) + 1L]] <- governance_finding(
            "structural", "missing_change_row", source, links$line[[i]],
            links$target[[i]],
            "target header notice points to a change map with no matching row"
          )
        }
      }

      marker_text <- governance_code_free(lines)
      marker_lines <- grep(
        "supersed|amend|replac|accepted change pending",
        marker_text,
        ignore.case = TRUE,
        perl = TRUE
      )
      change_row_lines <- vapply(
        source_maps[vapply(source_maps, function(map) {
          identical(map$source, source)
        }, logical(1L))],
        `[[`,
        integer(1L),
        "line"
      )
      marker_links <- which(
        points_to_map & links$line > header_end &
          links$line %in% marker_lines &
          !(links$line %in% change_row_lines)
      )
      for (i in marker_links) {
        section <- governance_section_fragment_at_line(lines, links$line[[i]])
        has_row <- any(vapply(source_maps, function(map) {
          target <- governance_resolve_target(map$source, map$target)
          replacement <- governance_resolve_target(map$source, map$replacement)
          identical(map$source, resolved_links[[i]]$path) &&
            !is.na(target$path) && identical(target$path, source) &&
            identical(target$fragment, section) &&
            !is.na(replacement$path) &&
            identical(replacement$path, resolved_links[[i]]$path) &&
            identical(replacement$fragment, resolved_links[[i]]$fragment)
        }, logical(1L)))
        if (!has_row) {
          findings[[length(findings) + 1L]] <- governance_finding(
            "structural", "missing_change_row", source, links$line[[i]],
            links$target[[i]],
            "target section marker points to a change map with no matching row"
          )
        }
      }
    }
  }

  map_replacements <- vapply(source_maps, function(map) {
    resolved <- governance_resolve_target(map$source, map$replacement)
    paste(resolved$path, resolved$fragment, sep = "#")
  }, character(1L))
  for (row in bridge_rows) {
    if (!(row$state %in% c("pending", "consolidated, awaiting closeout"))) {
      next
    }
    if (!nzchar(row$topic) || !nzchar(row$binding) || !nzchar(row$receiver)) {
      findings[[length(findings) + 1L]] <- governance_finding(
        "structural", "stage_inconsistent_mapping", row$source, row$line,
        "mapping:bridge", "bridge row lacks topic, binding source, or receiver link"
      )
      next
    }
    binding_resolved <- governance_resolve_target(row$source, row$binding)
    binding_key <- paste(binding_resolved$path, binding_resolved$fragment, sep = "#")
    if (length(map_replacements) && !(binding_key %in% map_replacements)) {
      findings[[length(findings) + 1L]] <- governance_finding(
        "structural", "stage_inconsistent_mapping", row$source, row$line,
        row$binding, "bridge binding does not name a declared replacement section"
      )
    }
    receiver_resolved <- governance_resolve_target(row$source, row$receiver)
    if (is.na(receiver_resolved$path) ||
        !file.exists(file.path(root, receiver_resolved$path))) {
      next
    }
    receiver_lines <- governance_read_lines(file.path(root, receiver_resolved$path))
    receiver_links <- governance_links(receiver_resolved$path, receiver_lines)
    section <- governance_section_lines(receiver_lines, receiver_resolved$fragment)
    section_links <- receiver_links[receiver_links$line %in% section, , drop = FALSE]
    topic_resolved <- governance_resolve_target(row$source, row$topic)
    has_backlink <- any(vapply(section_links$target, function(value) {
      governance_link_resolves_to(
        receiver_resolved$path,
        value,
        row$source,
        topic_resolved$fragment
      )
    }, logical(1L)))
    if (identical(row$state, "pending") && !has_backlink) {
      findings[[length(findings) + 1L]] <- governance_finding(
        "structural", "stage_inconsistent_mapping", receiver_resolved$path,
        if (length(section)) min(section) else 1L, row$receiver,
        "pending bridge row has no receiver Accepted change pending backlink"
      )
    }
    if (identical(row$state, "consolidated, awaiting closeout") && has_backlink) {
      findings[[length(findings) + 1L]] <- governance_finding(
        "structural", "stage_inconsistent_mapping", receiver_resolved$path,
        if (length(section)) min(section) else 1L, row$receiver,
        "consolidated bridge row retains a stale pending backlink"
      )
    }
  }
  governance_bind_findings(findings)
}

governance_scan_states_and_verdicts <- function(root, sources) {
  pipeline_states <- c("due", "active", "paused", "obligations open", "parked", "closed")
  type_1 <- c("pass", "pass_after_patches", "changes_required", "needs_type_2")
  type_2 <- c("proceed", "revise_seed", "reject")
  findings <- list()
  for (source in sources) {
    lines <- governance_read_lines(file.path(root, source))
    mode <- tolower(gsub("[*`_]", "", governance_header_value(lines, "Mode")))
    for (table in governance_tables(lines)) {
      header <- tolower(gsub("[*`]", "", table$header))
      state_i <- match("state", header)
      pipeline_table <- any(header %in% c("cycle", "cycle or obligation"))
      if (!is.na(state_i) && pipeline_table) {
        for (row in table$rows) {
          state <- tolower(gsub("[*`]", "", trimws(row$cells[[state_i]])))
          if (!(state %in% pipeline_states)) {
            findings[[length(findings) + 1L]] <- governance_finding(
              "structural", "invalid_row_state", source, row$line,
              "row-state", sprintf("invalid pipeline row state '%s'", state)
            )
          }
        }
      }
    }
    header <- head(lines, governance_header_end(lines))
    verdict_lines <- grep(
      "^[[:space:]]*(?:[*][*])?Verdict:(?:[*][*])?",
      header,
      ignore.case = TRUE
    )
    for (line in verdict_lines) {
      verdict <- tolower(trimws(sub(
        "^[[:space:]]*(?:[*][*])?Verdict:(?:[*][*])?[[:space:]]*",
        "",
        lines[[line]],
        ignore.case = TRUE
      )))
      verdict <- gsub("[*`]", "", verdict)
      verdict <- sub("[[:space:].].*$", "", verdict)
      verdict <- gsub("^_+|_+$", "", verdict)
      allowed <- if (grepl("type 2", mode, fixed = TRUE)) type_2 else type_1
      if (!(verdict %in% allowed)) {
        findings[[length(findings) + 1L]] <- governance_finding(
          "structural", "invalid_verdict", source, line,
          "metadata:verdict", sprintf("verdict '%s' is invalid for the declared review mode", verdict)
        )
      }
    }
  }
  governance_bind_findings(findings)
}

governance_validate_baseline <- function(baseline) {
  if (!is.list(baseline) || !identical(as.integer(baseline$version), 1L) ||
      !is.character(baseline$baseline_commit) || length(baseline$baseline_commit) != 1L ||
      !nzchar(baseline$baseline_commit) || !is.list(baseline$population) ||
      is.null(baseline$population$source_count) ||
      !is.character(baseline$population$source_sha256) ||
      !is.list(baseline$entries)) {
    governance_abort("baseline must contain version 1, baseline_commit, population, and entries")
  }
  required <- c("source", "target", "occurrence", "kind", "reason", "owner", "disposition")
  for (i in seq_along(baseline$entries)) {
    entry <- baseline$entries[[i]]
    if (!is.list(entry) || !all(required %in% names(entry)) ||
        any(!vapply(entry[required[-3L]], function(value) {
          is.character(value) && length(value) == 1L && nzchar(value)
        }, logical(1L))) ||
        length(entry$occurrence) != 1L || is.na(as.integer(entry$occurrence))) {
      governance_abort(sprintf("baseline entry %d is malformed", i))
    }
  }
  invisible(TRUE)
}

governance_validate_claims <- function(claims) {
  if (!is.list(claims) || !is.list(claims$claims)) {
    governance_abort("claims input must contain a claims list")
  }
  for (i in seq_along(claims$claims)) {
    claim <- claims$claims[[i]]
    if (!is.list(claim) || !is.character(claim$id) || length(claim$id) != 1L ||
        !nzchar(claim$id) || is.null(claim$source)) {
      governance_abort(sprintf("claims entry %d lacks id or source", i))
    }
  }
  invisible(TRUE)
}

governance_claim_warnings <- function(claims, source = "tests/claims.yml") {
  rows <- list()
  for (claim in claims$claims) {
    claim_source <- paste(unlist(claim$source), collapse = " ")
    has_contract <- grepl("contracts[.]md|[A-Z][A-Za-z]+ Contract", claim_source)
    has_accepted <- grepl("[Ss]ynthesis|rfc_|accepted", claim_source)
    has_ticket <- grepl("LDG-|Cut [0-9]|Workstream|WS[0-9]", claim_source)
    if (has_ticket && !has_contract && !has_accepted) {
      rows[[length(rows) + 1L]] <- governance_finding(
        "advisory", "claim_source_ticket_only", source, 0L,
        claim$id, "claim source names ticket authority without a contract or accepted section"
      )
    }
  }
  governance_bind_findings(rows)
}

governance_horizon_headings <- function(lines, section = NULL) {
  first <- 1L
  last <- length(lines)
  if (!is.null(section)) {
    start <- which(lines == paste0("## ", section))
    if (length(start) != 1L) {
      return(data.frame(
        heading = character(), line = integer(), stringsAsFactors = FALSE
      ))
    }
    first <- start + 1L
    later <- which(seq_along(lines) > start & grepl("^## ", lines))
    last <- if (length(later)) later[[1L]] - 1L else length(lines)
  }
  indexes <- seq.int(first, last)
  keep <- grepl("^### [0-9]{4}-[0-9]{2}-[0-9]{2} ", lines[indexes])
  data.frame(
    heading = sub("^### ", "", lines[indexes[keep]]),
    line = indexes[keep],
    stringsAsFactors = FALSE
  )
}

governance_horizon_archived_bodies <- function(lines) {
  headings <- governance_horizon_headings(lines)
  if (!nrow(headings)) {
    headings$has_body <- logical()
    return(headings)
  }
  headings$has_body <- vapply(seq_len(nrow(headings)), function(i) {
    first <- headings$line[[i]] + 1L
    later <- which(
      seq_along(lines) >= first &
        grepl(
          paste0(
            "^###[[:space:]]+|^##[[:space:]]+|^<a[[:space:]]|",
            "^\\[Back to classification\\]"
          ),
          lines
        )
    )
    last <- if (length(later)) later[[1L]] - 1L else length(lines)
    if (first > last) {
      return(FALSE)
    }
    body <- trimws(lines[seq.int(first, last)])
    body <- body[
      nzchar(body) &
        !grepl("^<a[[:space:]]", body) &
        !grepl("^#{1,6}[[:space:]]+", body) &
        !grepl("^\\*\\*Disposition:\\*\\*", body) &
        !grepl("^\\[Back to classification\\]", body)
    ]
    length(body) > 0L
  }, logical(1L))
  headings
}

governance_horizon_classification <- function(lines) {
  indexes <- grep("^\\| H[0-9]{3} \\|", lines)
  rows <- lapply(indexes, function(i) {
    cells <- trimws(strsplit(lines[[i]], "|", fixed = TRUE)[[1L]])
    if (length(cells) < 6L ||
        !(cells[[4L]] %in% c("shipped", "superseded", "promoted", "genuine"))) {
      return(NULL)
    }
    data.frame(
      id = cells[[2L]],
      heading = cells[[3L]],
      class = cells[[4L]],
      line = i,
      stringsAsFactors = FALSE
    )
  })
  rows <- rows[!vapply(rows, is.null, logical(1L))]
  if (!length(rows)) {
    return(data.frame(
      id = character(), heading = character(), class = character(),
      line = integer(), stringsAsFactors = FALSE
    ))
  }
  do.call(rbind, rows)
}

governance_scan_horizon <- function(root, sources, current_packet) {
  horizon_source <- "inst/design/horizon.md"
  archive_source <- "inst/design/horizon_archive.md"
  classification_source <- paste0(
    current_packet, "/horizon_open_classification.md"
  )
  relevant <- c(horizon_source, archive_source, classification_source)
  if (!any(relevant %in% sources)) {
    return(governance_empty_findings())
  }
  read_if_present <- function(source) {
    if (source %in% sources) governance_read_lines(file.path(root, source)) else character()
  }
  horizon <- read_if_present(horizon_source)
  archive <- read_if_present(archive_source)
  classification_lines <- read_if_present(classification_source)
  open <- governance_horizon_headings(horizon, "Open")
  redirects <- governance_horizon_headings(horizon, "Historical redirects")
  archived <- governance_horizon_archived_bodies(archive)
  classification <- governance_horizon_classification(classification_lines)
  findings <- list()

  if (horizon_source %in% sources && sum(horizon == "## Open") != 1L) {
    findings[[length(findings) + 1L]] <- governance_finding(
      "structural", "missing_horizon_open_section",
      horizon_source, 1L, "## Open",
      "horizon.md must contain exactly one structural Open section"
    )
  }
  classification_header <-
    "| ID | Original heading | Class | Evidence | Destination |"
  classification_delimiter <- "| --- | --- | --- | --- | --- |"
  table_header <- which(classification_lines == classification_header)
  table_ok <- length(table_header) == 1L &&
    table_header[[1L]] < length(classification_lines) &&
    identical(
      classification_lines[[table_header[[1L]] + 1L]],
      classification_delimiter
    )
  if (classification_source %in% sources && !table_ok) {
    findings[[length(findings) + 1L]] <- governance_finding(
      "structural", "missing_horizon_classification_table",
      classification_source, 1L, classification_header,
      "current packet must contain the exact horizon classification table"
    )
  }

  duplicate <- duplicated(classification$heading) |
    duplicated(classification$heading, fromLast = TRUE)
  for (i in which(duplicate)) {
    findings[[length(findings) + 1L]] <- governance_finding(
      "structural", "duplicate_horizon_classification",
      classification_source, classification$line[[i]],
      classification$heading[[i]],
      "classification table contains the same original Open heading more than once"
    )
  }
  for (i in seq_len(nrow(open))) {
    match <- which(classification$heading == open$heading[[i]])
    if (!length(match)) {
      findings[[length(findings) + 1L]] <- governance_finding(
        "structural", "unclassified_horizon_open",
        horizon_source, open$line[[i]], open$heading[[i]],
        "dated Open entry has no row in the current packet classification table"
      )
    } else if (any(classification$class[match] != "genuine") ||
               open$heading[[i]] %in% archived$heading) {
      findings[[length(findings) + 1L]] <- governance_finding(
        "structural", "archived_horizon_body_current",
        horizon_source, open$line[[i]], open$heading[[i]],
        "an archived or non-genuine entry is presented as current Open parking"
      )
    }
  }
  moved <- classification[classification$class != "genuine", , drop = FALSE]
  for (i in seq_len(nrow(moved))) {
    if (!(moved$heading[[i]] %in% redirects$heading)) {
      findings[[length(findings) + 1L]] <- governance_finding(
        "structural", "missing_horizon_redirect",
        classification_source, moved$line[[i]], moved$heading[[i]],
        "non-genuine Open entry has no exact-heading Historical redirects stub"
      )
    }
    archived_match <- which(archived$heading == moved$heading[[i]])
    if (!length(archived_match) ||
        !any(archived$has_body[archived_match])) {
      findings[[length(findings) + 1L]] <- governance_finding(
        "structural", "missing_horizon_archive_body",
        classification_source, moved$line[[i]], moved$heading[[i]],
        "non-genuine Open entry has no preserved nonempty body in horizon_archive.md"
      )
    }
  }
  governance_bind_findings(findings)
}

governance_sha256_lines <- function(lines) {
  bytes <- charToRaw(enc2utf8(paste0(paste(lines, collapse = "\n"), "\n")))
  digest::digest(bytes, algo = "sha256", serialize = FALSE)
}

governance_sha256_file <- function(path) {
  governance_sha256_lines(governance_read_lines(path))
}

governance_root_relative <- function(root, path, label) {
  absolute <- normalizePath(path, winslash = "/", mustWork = TRUE)
  prefix <- paste0(root, "/")
  matches <- if (.Platform$OS.type == "windows") {
    startsWith(tolower(absolute), tolower(prefix))
  } else {
    startsWith(absolute, prefix)
  }
  if (!matches) {
    governance_abort(sprintf("%s input must be inside the repository root", label))
  }
  substring(absolute, nchar(prefix) + 1L)
}

governance_population <- function(tracked, current_packet) {
  top <- grepl("^inst/design/[^/]+[.](md|qmd)$", tracked)
  nested <- grepl("^inst/design/(rfc|manual)/.*[.](md|qmd)$", tracked)
  packet <- startsWith(tracked, paste0(current_packet, "/")) &
    grepl("[.](md|qmd)$", tracked)
  sort(unique(tracked[top | nested | packet]), method = "radix")
}

governance_read_tracked <- function(root, tracked_path = NULL) {
  if (!is.null(tracked_path)) {
    manifest <- governance_read_yaml(tracked_path)
    if (!is.list(manifest) || !is.character(manifest$tracked) ||
        !length(manifest$tracked)) {
      governance_abort("tracked manifest must contain a non-empty tracked list")
    }
    return(sort(unique(gsub("\\\\", "/", manifest$tracked)), method = "radix"))
  }
  dot_git <- file.path(root, ".git")
  if (dir.exists(dot_git)) {
    git_dir <- normalizePath(dot_git, winslash = "/", mustWork = TRUE)
  } else if (file.exists(dot_git)) {
    pointer <- governance_read_lines(dot_git)
    if (length(pointer) != 1L || !startsWith(pointer, "gitdir: ")) {
      governance_abort("the .git worktree pointer is malformed")
    }
    git_dir <- sub("^gitdir: ", "", pointer)
    if (!grepl("^(?:[A-Za-z]:)?/", git_dir)) {
      git_dir <- file.path(root, git_dir)
    }
    git_dir <- normalizePath(git_dir, winslash = "/", mustWork = TRUE)
  } else {
    governance_abort("repository root has no .git directory or worktree pointer")
  }
  output <- suppressWarnings(system2(
    "git",
    c(paste0("--git-dir=", git_dir), paste0("--work-tree=", root), "ls-files"),
    stdout = TRUE,
    stderr = TRUE
  ))
  status <- attr(output, "status")
  if (!is.null(status) && status != 0L) {
    governance_abort(sprintf("git ls-files failed: %s", paste(output, collapse = " ")))
  }
  sort(unique(gsub("\\\\", "/", output)), method = "radix")
}

governance_baseline_key <- function(source, target, occurrence, kind) {
  paste(source, target, as.integer(occurrence), kind, sep = "\r")
}

governance_apply_baseline <- function(findings, baseline) {
  if (!nrow(findings)) {
    findings$occurrence <- integer()
    findings$state <- character()
    return(findings)
  }
  findings <- findings[order(
    findings$source,
    findings$line,
    findings$kind,
    findings$target,
    findings$message,
    method = "radix"
  ), , drop = FALSE]
  findings$occurrence <- ave(
    seq_len(nrow(findings)),
    interaction(findings$source, findings$target, drop = TRUE),
    FUN = seq_along
  )
  baseline_keys <- vapply(baseline$entries, function(entry) {
    governance_baseline_key(
      entry$source,
      entry$target,
      entry$occurrence,
      entry$kind
    )
  }, character(1L))
  keys <- governance_baseline_key(
    findings$source,
    findings$target,
    findings$occurrence,
    findings$kind
  )
  findings$state <- ifelse(keys %in% baseline_keys, "baseline", "new")
  rownames(findings) <- NULL
  findings
}

governance_escape <- function(value) {
  value <- gsub("[[:cntrl:]]+", " ", as.character(value))
  trimws(value)
}

governance_report <- function(root, baseline_path, claims_path,
                              tracked_path = NULL,
                              current_packet = "inst/design/ledgr_v0_2_2_spec_packet") {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  baseline <- governance_read_yaml(baseline_path)
  claims <- governance_read_yaml(claims_path)
  governance_validate_baseline(baseline)
  governance_validate_claims(claims)
  claims_input <- governance_root_relative(root, claims_path, "claims")
  claims_sha256 <- governance_sha256_file(claims_path)
  tracked <- governance_read_tracked(root, tracked_path)
  sources <- governance_population(tracked, current_packet)
  if (!length(sources)) {
    governance_abort("the tracked manifest yields an empty governance scan population")
  }
  missing_sources <- sources[!file.exists(file.path(root, sources))]
  if (length(missing_sources)) {
    governance_abort(sprintf(
      "tracked governance source is unreadable or missing: %s",
      missing_sources[[1L]]
    ))
  }

  link_scan <- governance_scan_links(root, sources, tracked)
  findings <- governance_bind_findings(list(
    link_scan$findings,
    governance_scan_headers(root, sources),
    governance_scan_mappings(root, sources),
    governance_scan_states_and_verdicts(root, sources),
    governance_scan_horizon(root, sources, current_packet),
    governance_claim_warnings(claims, claims_input)
  ))
  findings <- governance_apply_baseline(findings, baseline)
  population_hash <- governance_sha256_lines(sources)
  baseline_population_match <- identical(
    as.integer(baseline$population$source_count),
    as.integer(length(sources))
  ) && identical(baseline$population$source_sha256, population_hash)

  counts <- if (nrow(findings)) {
    aggregate(
      rep.int(1L, nrow(findings)),
      findings[c("severity", "state", "kind")],
      sum
    )
  } else {
    data.frame(
      severity = character(), state = character(), kind = character(),
      x = integer(), stringsAsFactors = FALSE
    )
  }
  counts <- counts[order(counts$severity, counts$state, counts$kind, method = "radix"), , drop = FALSE]
  baseline_keys <- vapply(baseline$entries, function(entry) {
    governance_baseline_key(
      entry$source,
      entry$target,
      entry$occurrence,
      entry$kind
    )
  }, character(1L))
  finding_keys <- governance_baseline_key(
    findings$source,
    findings$target,
    findings$occurrence,
    findings$kind
  )
  resolved_entries <- baseline$entries[!(baseline_keys %in% finding_keys)]
  resolved_baseline <- length(resolved_entries)
  report <- c(
    "GOVERNANCE_REPORT\tversion=1",
    "MODE\treport-only",
    sprintf("BASELINE_COMMIT\t%s", governance_escape(baseline$baseline_commit)),
    sprintf("BASELINE_SOURCE_COUNT\t%d", as.integer(baseline$population$source_count)),
    sprintf("BASELINE_SOURCE_SHA256\t%s", baseline$population$source_sha256),
    sprintf("BASELINE_POPULATION_MATCH\t%s", tolower(as.character(baseline_population_match))),
    sprintf("BASELINE_ENTRY_COUNT\t%d", length(baseline$entries)),
    sprintf("RESOLVED_BASELINE_ENTRY_COUNT\t%d", resolved_baseline),
    sprintf("SCAN_SOURCE_COUNT\t%d", length(sources)),
    sprintf("SCAN_SOURCE_SHA256\t%s", population_hash),
    sprintf("CLAIMS_INPUT\t%s", governance_escape(claims_input)),
    sprintf("CLAIMS_SHA256\t%s", claims_sha256),
    sprintf("CLAIMS_COUNT\t%d", length(claims$claims)),
    sprintf("FINDING_COUNT\t%d", nrow(findings)),
    sprintf("NEW_STRUCTURAL_COUNT\t%d", sum(findings$severity == "structural" & findings$state == "new"))
  )
  if (length(resolved_entries)) {
    report <- c(report, vapply(resolved_entries, function(entry) {
      sprintf(
        paste0(
          "RESOLVED_BASELINE_ENTRY\tkind=%s\tsource=%s\ttarget=%s",
          "\toccurrence=%d"
        ),
        governance_escape(entry$kind),
        governance_escape(entry$source),
        governance_escape(entry$target),
        as.integer(entry$occurrence)
      )
    }, character(1L)))
  }
  if (nrow(counts)) {
    report <- c(report, vapply(seq_len(nrow(counts)), function(i) {
      sprintf(
        "COUNT\tseverity=%s\tstate=%s\tkind=%s\tn=%d",
        counts$severity[[i]], counts$state[[i]], counts$kind[[i]], counts$x[[i]]
      )
    }, character(1L)))
  }
  report <- c(report, sprintf("SCAN_SOURCE\t%s", sources))
  if (nrow(findings)) {
    report <- c(report, vapply(seq_len(nrow(findings)), function(i) {
      finding <- findings[i, , drop = FALSE]
      sprintf(
        paste0(
          "FINDING\tseverity=%s\tstate=%s\tkind=%s\tsource=%s",
          "\tline=%d\ttarget=%s\toccurrence=%d\tmessage=%s"
        ),
        finding$severity,
        finding$state,
        finding$kind,
        governance_escape(finding$source),
        finding$line,
        governance_escape(finding$target),
        finding$occurrence,
        governance_escape(finding$message)
      )
    }, character(1L)))
  }
  report
}

governance_parse_args <- function(args) {
  if (any(args %in% "--check") || any(startsWith(args, "--mode="))) {
    governance_abort("this tool has report mode only; check mode is not implemented")
  }
  values <- list(
    root = ".",
    baseline = "dev/governance_guard/baseline.yml",
    claims = "tests/claims.yml",
    tracked = NULL,
    current_packet = "inst/design/ledgr_v0_2_2_spec_packet"
  )
  for (arg in args) {
    matched <- FALSE
    for (name in names(values)) {
      prefix <- paste0("--", gsub("_", "-", name), "=")
      if (startsWith(arg, prefix)) {
        values[[name]] <- sub(paste0("^", prefix), "", arg)
        matched <- TRUE
        break
      }
    }
    if (!matched) {
      governance_abort(sprintf("unknown argument: %s", arg))
    }
  }
  values$root <- normalizePath(values$root, winslash = "/", mustWork = TRUE)
  for (name in c("baseline", "claims", "tracked")) {
    value <- values[[name]]
    if (!is.null(value) && !grepl("^(?:[A-Za-z]:)?/", gsub("\\\\", "/", value))) {
      values[[name]] <- file.path(values$root, value)
    }
  }
  values
}

governance_main <- function(args = commandArgs(trailingOnly = TRUE)) {
  tryCatch({
    parsed <- governance_parse_args(args)
    report <- governance_report(
      root = parsed$root,
      baseline_path = parsed$baseline,
      claims_path = parsed$claims,
      tracked_path = parsed$tracked,
      current_packet = parsed$current_packet
    )
    cat(report, sep = "\n")
    cat("\n")
    invisible(0L)
  }, ledgr_governance_report_input = function(e) {
    message("GOVERNANCE_REPORT_INPUT_ERROR: ", conditionMessage(e))
    invisible(2L)
  })
}

if (sys.nframe() == 0L) {
  quit(status = governance_main())
}
