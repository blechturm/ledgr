# Q1 cost of today's pulse-seed derivation: descriptive, not a gate, not
# deterministic, never compared by check.R. Sourced by probe.R --cost after
# the records are written; writes cost/micro.csv, cost/share.csv and
# cost/host.csv next to this file.
#
# micro: microbenchmark medians per call (derivation, its parts, C4 candidate
#   rules and the seeding calls a strategy pays per pulse).
# share: WS1 timing fixtures (timing_scale 20 x 252, dense_scale_50x1260
#   50 x 1260), seeded committed runs (every grid candidate, sweep execution
#   seeds, as WS1 measure.R) and a seeded sweep (workers = 1). For each: Rprof
#   share of samples with ledgr_derive_pulse_seed on the stack, derivation
#   calls x per-call median, and wall clock seeded vs unseeded (median of 3
#   alternating repetitions after one untimed warm-up).

rp_ps <- function(cmd) {
  out <- tryCatch(suppressWarnings(system2("powershell", c("-NoProfile", "-Command", shQuote(cmd, type = "cmd")),
    stdout = TRUE, stderr = TRUE)), error = function(e) conditionMessage(e))
  paste(trimws(out[nzchar(trimws(out))]), collapse = " ")
}
rp_host <- function(when) {
  data.frame(when = when, utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    cpu_load_pct = rp_ps("[int](Get-CimInstance Win32_Processor | Measure-Object LoadPercentage -Average).Average"),
    r_processes = rp_ps("(Get-Process -Name R,Rscript,Rterm -ErrorAction SilentlyContinue | Measure-Object).Count"),
    top_cpu = rp_ps(paste0("Get-Process | Sort-Object CPU -Descending | Select-Object -First 6 Name,CPU | ",
      "ForEach-Object { $_.Name + '=' + [int]$_.CPU }")), stringsAsFactors = FALSE)
}

rp_micro <- function() {
  ns <- asNamespace("ledgr")
  payload <- ledgr:::canonical_json(list(base_seed = 7L, salt = list(scope = "pulse", pulse_idx = 500L)))
  pulses <- 1:1260
  old <- rp_seed_state()
  on.exit(if (is.null(old)) rp_clear_seed() else assign(".Random.seed", old, envir = globalenv()), add = TRUE)
  set_kind <- function(k) RNGkind(k, "Inversion", "Rejection")
  mb <- function(expr_list, times) {
    s <- summary(microbenchmark::microbenchmark(list = expr_list, times = times, unit = "us"))
    data.frame(expr = as.character(s$expr), median_us = s$median, min_us = s$min, times = times, stringsAsFactors = FALSE)
  }
  rows <- list(
    mb(list(
      `ledgr_derive_pulse_seed(7, 500) [today, per pulse]` = quote(ledgr:::ledgr_derive_pulse_seed(7L, 500L)),
      `canonical_json(list(base_seed, salt))` = quote(ledgr:::canonical_json(list(base_seed = 7L, salt = list(scope = "pulse", pulse_idx = 500L)))),
      `digest sha256 of the payload` = quote(digest::digest(payload, algo = "sha256", serialize = FALSE)),
      `ledgr_seed_normalize(7)` = quote(ledgr:::ledgr_seed_normalize(7L)),
      `rule add, scalar` = quote(rp_rules$add(7, 500)),
      `rule stride, scalar` = quote(rp_rules$stride(7, 500)),
      `rule mixer, scalar` = quote(rp_rules$mixer(7, 500)),
      `rule mixer, vector of 1260 pulses` = quote(rp_rules$mixer(7, pulses)),
      `withr::with_seed(s, NULL) [kind kept]` = quote(withr::with_seed(500L, NULL)),
      `withr::with_seed(s, NULL) [3 kinds pinned to MT]` = quote(withr::with_seed(500L, NULL, .rng_kind = "Mersenne-Twister",
        .rng_normal_kind = "Inversion", .rng_sample_kind = "Rejection"))
    ), 2000L)
  )
  for (k in c("Mersenne-Twister", "L'Ecuyer-CMRG")) {
    set_kind(k)
    rows[[length(rows) + 1L]] <- mb(stats::setNames(list(quote(set.seed(500L))), paste0("set.seed(s) [", k, " active]")), 2000L)
  }
  set_kind("Mersenne-Twister")
  rows[[length(rows) + 1L]] <- mb(list(`set.seed(s, kind = MT, normal.kind, sample.kind) [pinned call]` =
    quote(set.seed(500L, kind = "Mersenne-Twister", normal.kind = "Inversion", sample.kind = "Rejection"))), 2000L)
  do.call(rbind, rows)
}

rp_prof <- function(expr_fn) {
  f <- tempfile(fileext = ".prof")
  utils::Rprof(f, interval = 0.01)
  t0 <- as.numeric(Sys.time())
  expr_fn()
  t1 <- as.numeric(Sys.time())
  utils::Rprof(NULL)
  s <- utils::summaryRprof(f)
  hit <- s$by.total[rownames(s$by.total) == "\"ledgr_derive_pulse_seed\"", , drop = FALSE]
  list(wall = t1 - t0, samples = round(s$sampling.time / 0.01),
    derive_samples = if (nrow(hit)) round(hit$total.time / 0.01) else 0, derive_pct = if (nrow(hit)) hit$total.pct else 0)
}

rp_share <- function(work, micro) {
  per_call <- micro$median_us[grepl("^ledgr_derive_pulse_seed", micro$expr)] / 1e6
  fixtures <- list(timing_scale = ws1_extract_definition(file.path(rp_root, "dev/bench/v0_2_3_output_freeze/timing.R"),
    "a0_fx_timing_scale"), dense_scale_50x1260 = ws1_fx_dense_scale_50x1260)
  rows <- list()
  for (id in names(fixtures)) {
    fx <- fixtures[[id]](file.path(work, paste0("cost_", id, ".duckdb")))
    retain <- a0_retain()
    n <- 0L
    sweep <- function(seed) suppressWarnings(ledgr_sweep(fx$exp, fx$grid, seed = seed, retain = retain))
    sw <- sweep(fx$seed)
    runs <- function(seeded, tag) for (i in seq_len(nrow(sw))) {
      n <<- n + 1L
      close(suppressWarnings(ledgr_run(fx$exp, params = sw$params[[i]], feature_params = sw$feature_params[[i]],
        run_id = sprintf("cost-%s-%d-%d", tag, n, i), seed = if (seeded) sw$execution_seed[[i]] else NULL)))
    }
    calls <- 0L
    count <- list(ledgr_derive_pulse_seed = function(orig) function(execution_seed, pulse_idx) {
      calls <<- calls + 1L
      orig(execution_seed, pulse_idx)
    })
    a0_with_patches(count, runs(TRUE, "warm")) # warm-up; also counts derivations per pass of all candidates
    paths <- list(run = function(seeded) runs(seeded, "t"), sweep = function(seeded) sweep(if (seeded) fx$seed else NULL))
    for (p in names(paths)) {
      prof <- rp_prof(function() paths[[p]](TRUE))
      wall <- list(seeded = numeric(), unseeded = numeric())
      for (r in 1:3) for (arm in if (r %% 2L) c("seeded", "unseeded") else c("unseeded", "seeded")) {
        t0 <- as.numeric(Sys.time()); paths[[p]](arm == "seeded"); wall[[arm]] <- c(wall[[arm]], as.numeric(Sys.time()) - t0)
      }
      seeded <- stats::median(wall$seeded); unseeded <- stats::median(wall$unseeded)
      rows[[length(rows) + 1L]] <- data.frame(fixture = id, path = p, candidates = nrow(sw), derive_calls = calls,
        seeded_wall_s = seeded, unseeded_wall_s = unseeded, seeded_minus_unseeded_s = seeded - unseeded,
        est_derive_s = calls * per_call, est_share_of_seeded = calls * per_call / seeded,
        rprof_wall_s = prof$wall, rprof_samples = prof$samples, rprof_derive_samples = prof$derive_samples,
        rprof_derive_pct = prof$derive_pct, wall_seeded_reps = paste(sprintf("%.3f", wall$seeded), collapse = ";"),
        wall_unseeded_reps = paste(sprintf("%.3f", wall$unseeded), collapse = ";"), stringsAsFactors = FALSE)
    }
    ledgr_snapshot_close(fx$snapshot)
  }
  do.call(rbind, rows)
}

rp_cost <- function(out_dir, work) {
  dir.create(out_dir, showWarnings = FALSE)
  host <- rp_host("before")
  micro <- rp_micro()
  utils::write.csv(micro, file.path(out_dir, "micro.csv"), row.names = FALSE)
  share <- rp_share(work, micro)
  utils::write.csv(share, file.path(out_dir, "share.csv"), row.names = FALSE)
  host <- rbind(host, rp_host("after"))
  host$R_version <- R.version.string
  host$packages <- paste(vapply(c("digest", "withr", "mirai", "duckdb", "microbenchmark"), function(p)
    sprintf("%s %s", p, utils::packageVersion(p)), character(1)), collapse = "; ")
  utils::write.csv(host, file.path(out_dir, "host.csv"), row.names = FALSE)
  print(micro[, c("expr", "median_us")], row.names = FALSE)
  print(share[, c("fixture", "path", "derive_calls", "seeded_wall_s", "unseeded_wall_s", "est_share_of_seeded",
    "rprof_derive_pct")], row.names = FALSE)
  print(host[, c("when", "cpu_load_pct", "r_processes")], row.names = FALSE)
}
