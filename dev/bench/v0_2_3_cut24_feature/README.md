# Cut 24 feature timing and memory tools

Cut 24 (inst/design/ledgr_v0_2_3_spec_packet/tickets.yml) decision 3 and
LDG-3258. The timing protocol itself is
`dev/bench/timing/protocols/cut24-feature-1/` (shared harness); the tools here
are what the harness does not provide.

| File | Purpose |
| --- | --- |
| `calibrate.R` | per-cell seconds per preparation on the cut base; sets the frozen reps (`results/calibration.csv`) |
| `admission_counts.R` | expected admission counts and fixture digests of the four admission workloads, from the measuring step's independent gate (`results/admission_expected.csv`, `results/fixture_digests.csv`) |
| `exchange.R` | the decision statistics: per-cell [L, U] from all 256 within-pair label exchanges of a base A/A record (`--aa`), and per-cell verdicts of a comparison record (`--intervals=`) |
| `memory.R` | peak R heap of run and sweep preparation on the wide shapes: fresh children, gc maxima, the 8 MiB sensitivity check, label-exchange noise (`--aa`) and the retention verdict (`--noise=`) |
| `cert_split.R` | descriptive split of certification cost on the base (`results/cert_split_base.csv`) |

Records go to `records/` (timing exchange intervals and memory files);
the raw timing attempts stay in `dev/bench/timing/records/cut24-feature-1/`.

    Rscript dev/bench/v0_2_3_cut24_feature/calibrate.R --lib=<base lib> --work=<dir> --out=<csv>
    Rscript dev/bench/v0_2_3_cut24_feature/admission_counts.R --lib=<base lib> --work=<dir> --out=dev/bench/v0_2_3_cut24_feature/results
    Rscript dev/bench/v0_2_3_cut24_feature/exchange.R --record=<attempt dir> --out=<dir> --aa
    Rscript dev/bench/v0_2_3_cut24_feature/exchange.R --record=<attempt dir> --out=<dir> --intervals=<intervals.csv>
    Rscript dev/bench/v0_2_3_cut24_feature/memory.R --base=<lib> --candidate=<lib> --work=<dir> --out=<dir> --debug=0 --aa
    Rscript dev/bench/v0_2_3_cut24_feature/memory.R --base=<lib> --candidate=<lib> --work=<dir> --out=<dir> --debug=0 --noise=<memory_noise.csv>
    Rscript dev/bench/v0_2_3_cut24_feature/cert_split.R --lib=<base lib> --out=<csv>
