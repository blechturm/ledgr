# Spike: event-buffer FACTORIAL -- isolate the three bundled factors.
#
# The base-R structural fix in spike-event-buffer-rewrite.R changes three things
# at once (Codex review): capacity policy (worst-case prealloc -> grow-by-
# doubling), storage topology (nested list-in-env -> direct env columns), and the
# write op (base assign -> collapse::setv). This factorial attributes the 27-101x
# to each factor. Five cells (Codex's list):
#   V1 nested  + worstcase + base   (= current anti-pattern)
#   V2 nested  + doubling  + base
#   V3 direct  + worstcase + base
#   V4 direct  + doubling  + base   (= base_r "structural fix")
#   V5 direct  + doubling  + setv   (= collapse)
#
# Contrasts: capacity = V1->V2 (nested) and V3->V4 (direct); topology = V1->V3
# (worstcase) and V2->V4 (doubling); write op = V4->V5.
#
# Same faithful replica as spike-event-buffer-rewrite.R (cross-frame closure
# mutating a state env; 11 mixed-type cols; fixed VALS so only the write is
# timed). Same ~3x absolute-cost overestimate caveat applies; trust the ratios.
# Usage: Rscript dev/spikes/spike-event-buffer-factorial.R

suppressWarnings(suppressMessages(library(collapse)))

COLS <- c("event_id","run_id","ts_utc","event_type","instrument_id","side","qty","price","fee","meta_json","event_seq")
VALS <- list(event_id="run_00000001", run_id="run", ts_utc=as.POSIXct(1e9, origin="1970-01-01", tz="UTC"),
             event_type="FILL", instrument_id="DEMO_01", side="BUY", qty=1, price=100, fee=0,
             meta_json='{"cash_delta":-100,"position_delta":1}', event_seq=1L)
new_cols <- function(n) list(
  event_id=character(n), run_id=character(n),
  ts_utc=as.POSIXct(rep(NA_real_,n), origin="1970-01-01", tz="UTC"),
  event_type=character(n), instrument_id=character(n), side=character(n),
  qty=numeric(n), price=numeric(n), fee=numeric(n), meta_json=character(n), event_seq=integer(n))

# V1 nested + worstcase + base
make_v1 <- function(max_events) {
  s <- new.env(parent=emptyenv()); s$cols <- new_cols(max_events); s$n <- 0L
  function(v) { s$n <- s$n+1L; i <- s$n
    s$cols$event_id[[i]]<-v$event_id; s$cols$run_id[[i]]<-v$run_id; s$cols$ts_utc[[i]]<-v$ts_utc
    s$cols$event_type[[i]]<-v$event_type; s$cols$instrument_id[[i]]<-v$instrument_id; s$cols$side[[i]]<-v$side
    s$cols$qty[[i]]<-v$qty; s$cols$price[[i]]<-v$price; s$cols$fee[[i]]<-v$fee
    s$cols$meta_json[[i]]<-v$meta_json; s$cols$event_seq[[i]]<-v$event_seq }
}
# V2 nested + doubling + base
make_v2 <- function(initial_cap=1024L) {
  s <- new.env(parent=emptyenv()); s$cap <- initial_cap; s$n <- 0L; s$cols <- new_cols(initial_cap)
  grow <- function() { ex <- new_cols(s$cap); for (nm in COLS) s$cols[[nm]] <- c(s$cols[[nm]], ex[[nm]]); s$cap <- s$cap*2L }
  function(v) { s$n <- s$n+1L; i <- s$n; if (i > s$cap) grow()
    s$cols$event_id[[i]]<-v$event_id; s$cols$run_id[[i]]<-v$run_id; s$cols$ts_utc[[i]]<-v$ts_utc
    s$cols$event_type[[i]]<-v$event_type; s$cols$instrument_id[[i]]<-v$instrument_id; s$cols$side[[i]]<-v$side
    s$cols$qty[[i]]<-v$qty; s$cols$price[[i]]<-v$price; s$cols$fee[[i]]<-v$fee
    s$cols$meta_json[[i]]<-v$meta_json; s$cols$event_seq[[i]]<-v$event_seq }
}
# V3 direct + worstcase + base
make_v3 <- function(max_events) {
  s <- new.env(parent=emptyenv()); s$n <- 0L; cc <- new_cols(max_events); for (nm in COLS) s[[nm]] <- cc[[nm]]
  function(v) { s$n <- s$n+1L; i <- s$n
    s$event_id[[i]]<-v$event_id; s$run_id[[i]]<-v$run_id; s$ts_utc[[i]]<-v$ts_utc
    s$event_type[[i]]<-v$event_type; s$instrument_id[[i]]<-v$instrument_id; s$side[[i]]<-v$side
    s$qty[[i]]<-v$qty; s$price[[i]]<-v$price; s$fee[[i]]<-v$fee; s$meta_json[[i]]<-v$meta_json; s$event_seq[[i]]<-v$event_seq }
}
# V4 direct + doubling + base
make_v4 <- function(initial_cap=1024L) {
  s <- new.env(parent=emptyenv()); s$cap <- initial_cap; s$n <- 0L; cc <- new_cols(initial_cap); for (nm in COLS) s[[nm]] <- cc[[nm]]
  grow <- function() { ex <- new_cols(s$cap); for (nm in COLS) s[[nm]] <- c(s[[nm]], ex[[nm]]); s$cap <- s$cap*2L }
  function(v) { s$n <- s$n+1L; i <- s$n; if (i > s$cap) grow()
    s$event_id[[i]]<-v$event_id; s$run_id[[i]]<-v$run_id; s$ts_utc[[i]]<-v$ts_utc
    s$event_type[[i]]<-v$event_type; s$instrument_id[[i]]<-v$instrument_id; s$side[[i]]<-v$side
    s$qty[[i]]<-v$qty; s$price[[i]]<-v$price; s$fee[[i]]<-v$fee; s$meta_json[[i]]<-v$meta_json; s$event_seq[[i]]<-v$event_seq }
}
# V5 direct + doubling + setv
make_v5 <- function(initial_cap=1024L) {
  s <- new.env(parent=emptyenv()); s$cap <- initial_cap; s$n <- 0L; cc <- new_cols(initial_cap); for (nm in COLS) s[[nm]] <- cc[[nm]]
  grow <- function() { ex <- new_cols(s$cap); for (nm in COLS) s[[nm]] <- c(s[[nm]], ex[[nm]]); s$cap <- s$cap*2L }
  function(v) { s$n <- s$n+1L; i <- s$n; if (i > s$cap) grow()
    collapse::setv(s$event_id,i,v$event_id,vind1=TRUE); collapse::setv(s$run_id,i,v$run_id,vind1=TRUE); collapse::setv(s$ts_utc,i,v$ts_utc,vind1=TRUE)
    collapse::setv(s$event_type,i,v$event_type,vind1=TRUE); collapse::setv(s$instrument_id,i,v$instrument_id,vind1=TRUE); collapse::setv(s$side,i,v$side,vind1=TRUE)
    collapse::setv(s$qty,i,v$qty,vind1=TRUE); collapse::setv(s$price,i,v$price,vind1=TRUE); collapse::setv(s$fee,i,v$fee,vind1=TRUE)
    collapse::setv(s$meta_json,i,v$meta_json,vind1=TRUE); collapse::setv(s$event_seq,i,v$event_seq,vind1=TRUE) }
}

tv <- function(buffer, fills) system.time(for (k in seq_len(fills)) buffer(VALS))[["elapsed"]]

shapes <- list(c(100800L, 2099L), c(315000L, 6784L))
res <- list()
cat(sprintf("%-8s %-7s | %7s %7s %7s %7s %7s\n", "max_evt","fills","V1 nwb","V2 ndb","V3 dwb","V4 ddb","V5 dds"))
for (sp in shapes) {
  me <- sp[1]; nf <- sp[2]
  t1 <- tv(make_v1(me), nf); t2 <- tv(make_v2(1024L), nf); t3 <- tv(make_v3(me), nf); t4 <- tv(make_v4(1024L), nf); t5 <- tv(make_v5(1024L), nf)
  cat(sprintf("%-8d %-7d | %6.2fs %6.2fs %6.2fs %6.2fs %6.2fs\n", me, nf, t1,t2,t3,t4,t5))
  cat(sprintf("   factors: capacity(worst->double) nested %.1fx / direct %.1fx | topology(nest->direct) worst %.1fx / double %.1fx | write(base->setv) %.1fx\n",
              t1/t2, t3/t4, t1/t3, t2/t4, t4/t5))
  res[[length(res)+1L]] <- data.frame(max_events=me, fills=nf, v1_nwb=t1, v2_ndb=t2, v3_dwb=t3, v4_ddb=t4, v5_dds=t5,
                                      cap_nested=t1/t2, cap_direct=t3/t4, topo_worst=t1/t3, topo_double=t2/t4, write_setv=t4/t5)
}
out <- "dev/bench/results/spike_event_buffer_factorial.csv"
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(do.call(rbind, res), out, row.names = FALSE)
cat("\nWROTE", out, "\n")
