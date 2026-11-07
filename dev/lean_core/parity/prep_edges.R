# LDG-3215: shows that every listed fixture event sits within one session of
# a tile edge at both registered fixture widths. Events are derived from the
# fixture's own input frames, not from a hand-written table.
#
#   Rscript dev/lean_core/parity/prep_edges.R [--out=<csv>]
#
# A tile edge at width w falls between sessions k*w and k*w + 1. An event at
# session s is within one session of it when s is in k*w - 1 .. k*w + 2.

local({
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])))
  source(file.path(here, "prep_fixture.R"), local = FALSE)
})
x <- lc_prep_fixture_inputs()
p <- lc_prep_fixture_params
n <- length(x$axis)
session_of <- function(t) findInterval(as.numeric(t), as.numeric(x$axis) - 6.5 * 3600 - 1)  # an open belongs to its session
bar_sessions <- split(match(as.numeric(x$bars$ts_utc), as.numeric(x$axis)), x$bars$instrument_id)
events <- list()
add <- function(event, instrument, session, detail) {
  events[[length(events) + 1L]] <<- data.frame(event = event, instrument = instrument, session = session, detail = detail)
}

# Membership: exit, entry, re-entry; an exit while held changes column order.
members <- x$membership$members
starts <- session_of(x$membership$effective_from)
ever <- members[[1L]]
for (i in seq_along(members)[-1L]) {
  for (id in setdiff(members[[i - 1L]], members[[i]])) {
    add("exit", id, starts[[i]], "leaves membership")
    if (id %in% names(x$opening_positions)) add("changed column order", id, starts[[i]], "held former member moves to the end of the decision axis")
  }
  for (id in setdiff(members[[i]], members[[i - 1L]])) {
    if (id %in% ever) {
      add("re-entry", id, starts[[i]], "rejoins membership")
      if (id %in% names(x$opening_positions)) add("changed column order", id, starts[[i]], "returns to its member position")
    } else {
      add("entry", id, starts[[i]], "joins membership")
    }
  }
  ever <- union(ever, members[[i]])
}

# Bars: listing, relisting after a gap, carry expiry inside a gap.
for (id in names(bar_sessions)) {
  s <- sort(bar_sessions[[id]])
  if (s[[1L]] > 1L) add("listing", id, s[[1L]], "first bar")
  # A trailing gap (no later bar) is a gap that resumes after the axis.
  s_end <- c(s, n + 1L)
  gaps <- which(diff(s_end) > 1L)
  for (g in gaps) {
    last <- s_end[[g]]
    resume <- s_end[[g + 1L]]
    if (resume - last - 1L > x$price_carry) add("carry expiry", id, last + x$price_carry + 1L, sprintf("last bar s%d, carry %d", last, x$price_carry))
    if (resume <= n && any(x$lifetime$instrument_id == id & !is.na(x$lifetime$effective_to))) add("relisting", id, resume, "bars resume after the inactive interval")
  }
}

# Lifetime facts: inactive starts (where the off-axis request names CCC),
# and late knowledge.
for (i in seq_len(nrow(x$lifetime))) {
  r <- x$lifetime[i, ]
  eff <- session_of(r$effective_from)
  known <- session_of(r$knowledge_time)
  if (known > eff) {
    add("late-known fact", r$instrument_id, eff, "effective")
    add("late-known fact", r$instrument_id, known, "known")
  } else {
    add("inactive", r$instrument_id, eff, "known_inactive starts")
  }
  if (identical(r$instrument_id, p$off_axis)) add("off-axis request", r$instrument_id, eff, "explicitly named while off the decision axis")
}

# min_observations: first pulse whose short window holds both carried and
# missing sessions for one instrument.
for (id in names(bar_sessions)) {
  have <- seq_len(n) %in% bar_sessions[[id]]
  last_bar <- cummax(ifelse(have, seq_len(n), 0L))
  carried <- !have & last_bar > 0L & seq_len(n) - last_bar <= x$price_carry
  missing <- !have & !carried & last_bar > 0L
  for (s in seq.int(p$short, n)) {
    w <- seq.int(s - p$short + 1L, s)
    if (any(carried[w]) && any(missing[w])) {
      add("min_observations window", id, s, sprintf("lookback %d, min_observations %d: %d carried, %d missing",
                                                     p$short, p$min_obs, sum(carried[w]), sum(missing[w])))
      break
    }
  }
}

near <- function(s, w) {
  e <- w * round(s / w)
  any(s >= c(e, e + w, e - w) - 1L & s <= c(e, e + w, e - w) + 2L)
}
ev <- do.call(rbind, events)
for (w in lc_prep_widths) ev[[paste0("near_edge_w", w)]] <- vapply(ev$session, near, logical(1), w = w)

# Requests that span tiles at every pulse they read.
spans <- function(lookback, w) length(unique((seq.int(n - lookback + 1L, n) - 1L) %/% w))
req <- data.frame(event = c("finite lookback across tiles", "lookback = Inf"), instrument = "all",
                  session = n, detail = c(sprintf("lookback %d at s%d", p$long, n), sprintf("every session to s%d", n)))
for (w in lc_prep_widths) {
  req[[paste0("near_edge_w", w)]] <- c(spans(p$long, w) >= 3L, spans(n, w) == ceiling(n / w))
  req$detail <- paste0(req$detail, sprintf("; %d tiles at width %d", c(spans(p$long, w), spans(n, w)), w))
}
ev <- rbind(ev, req)
print(ev, row.names = FALSE, right = FALSE)
listed <- c("changed column order", "entry", "exit", "re-entry", "relisting", "carry expiry", "late-known fact",
            "off-axis request", "lookback = Inf", "finite lookback across tiles", "min_observations window")
missing_events <- setdiff(listed, ev$event)
bad <- ev[!ev$near_edge_w8 | !ev$near_edge_w12, ]
out <- sub("^--out=", "", grep("^--out=", commandArgs(TRUE), value = TRUE))
if (length(out)) utils::write.csv(ev, out[[1L]], row.names = FALSE)
if (length(missing_events) || nrow(bad)) {
  stop("edge check failed: missing ", paste(missing_events, collapse = ", "), "; far from an edge: ",
       paste(bad$event, collapse = ", "), call. = FALSE)
}
cat(sprintf("PASS: %d events, all %d listed kinds, each within one session of an edge at widths %s\n",
            nrow(ev), length(listed), paste(lc_prep_widths, collapse = " and ")))
