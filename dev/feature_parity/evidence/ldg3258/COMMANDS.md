# LDG-3258 commands and results

Cut base: release/v0.2.3 `ea580bc6` (R/ equals `68b505b9`), installed with
`dev/feature_parity/install_arm.R` into
`C:/Users/maxth/ledgr-wt/cut24-scratch/libs/base-ea580bc6`. Tools committed on
branch ws43 at `02b34843` before any record.

## Protocol and calibration (decision 3, R1, R2)

    Rscript dev/bench/v0_2_3_cut24_feature/calibrate.R --lib=<base lib> --work=<scratch> --out=<scratch>/calib.csv

Per-cell seconds per preparation and the frozen reps: 
`dev/bench/v0_2_3_cut24_feature/results/calibration.csv`; reps written into
`dev/bench/timing/protocols/cut24-feature-1/matrix.csv` before the A/A record.

    Rscript dev/bench/v0_2_3_cut24_feature/admission_counts.R --lib=<base lib> --work=<scratch> --out=dev/bench/v0_2_3_cut24_feature/results

Expected admission counts (the measuring step's independent gate,
`dev/spikes/feature_stage23_probe/common.R`): custom 0/500 (custom
certification), certified zero 0/500 and low 5/500 for every definition of
both sets, PIT 197/200 for every definition (`results/admission_expected.csv`);
fixture digests in `results/fixture_digests.csv`.

## Identity completeness (R4)

`identity_names_changed_engine.csv`: Cut 23's reviewed unchanged-engine name
set without `old_precompute:reused_table` and `old_precompute:fresh_table`
(written only when an old precompute is reused): 156 both, 2 base, 6
candidate. It equals the names of Cut 22's committed changed-engine records
(`evidence/ldg3255/identity_base.csv`, `identity_final.csv`) on both arms,
with none missing or extra.

    Rscript dev/feature_parity/identity_controls.R --mode=changed-engine --base=<Cut 22 base> --candidate=<Cut 22 final> --scratch=<scratch>
    Rscript dev/feature_parity/identity_controls.R --base=<Cut 23 base> --candidate=<Cut 23 final> --scratch=<scratch> --engine-prefix=bc6a3ea2

`identity_controls_changed_engine.txt`: the unedited Cut 22 records pass;
removed from both arms, renamed in both, dropped from one, duplicated and the
candidate's engine record removed each fail. `identity_controls_unchanged_engine.txt`:
Cut 23's controls unchanged, all as before.

## Emitted-function pin (rule 13)

    Rscript dev/feature_parity/identity.R --lib=<base lib> --out=<scratch>/identity_base --save-store=1
    Rscript dev/feature_parity/emitted_pin.R --record=<scratch>/identity_base --write-expected
    Rscript dev/feature_parity/emitted_pin_controls.R --record=<scratch>/identity_base --scratch=<scratch>

`identity_base.csv` (158 records on the base). `emitted_pin_expected.csv`: 134
identities (12 forms x 11 components, plus the parameterised form's two
fingerprints). `emitted_pin_controls.txt`: the base passes; an altered fn body,
param and declaration, a form removed from record and pin alike, and a
duplicated component each fail.

## Calculated counts (R5)

    Rscript dev/feature_parity/counts.R --lib=<base lib> --out=<scratch> --write-expected
    Rscript dev/feature_parity/counts.R --lib=<base lib> --out=<scratch>
    Rscript dev/feature_parity/counts.R --lib=<base lib> --out=<scratch> --fault=count

`counts_expected.csv`: 385 cells (296 positive) over the dense, hostile,
panel, short and empty substrates at the default and a later start, seven
definitions. `counts_base_check.txt`: pass; `counts_fault_count.txt`: the
count-only fault (every positive count plus one) fails.

## Certification split (descriptive)

    Rscript dev/bench/v0_2_3_cut24_feature/cert_split.R --lib=<base lib> --out=dev/bench/v0_2_3_cut24_feature/results/cert_split_base.csv

About 15 ms (run set) and 18 ms (sweep set) per definition. Constructing the
candidates is about 30 percent (the synthetic TTR call 3-4 percent);
turning each candidate into a definition, with its fingerprints, is about 70
percent (`canonical_def` includes construction). A TTR definition matches its
last candidate, after the four built-ins of its width are built and
converted, so lazy in-order construction (LDG-3260) cannot shorten
certification of the protocol's TTR definition sets.

## Base A/A records

    pcore.ps1 <log> dev/bench/timing/runner.R --protocol=dev/bench/timing/protocols/cut24-feature-1 --base=ea580bc6 --candidate=ea580bc6 --label=aa-base
    Rscript dev/bench/timing/check.R --protocol=dev/bench/timing/protocols/cut24-feature-1 --record=<attempt-1> --aa
    Rscript dev/bench/v0_2_3_cut24_feature/exchange.R --record=<attempt-1> --out=dev/bench/v0_2_3_cut24_feature/records/aa-base --aa

Timing (busy host: another project's R processes, annotated by the
harness; High performance, P-cores): A/A VALID, 16 cells x 8 pairs, every
slot ok, every ratio within margin. Label-exchange intervals
(`records/aa-base/intervals.csv`): U from 1.0042 (adm_custom_run) to 1.0260
(adm_low_sweep), L from 0.9746 to 0.9958. Each cell's U, rounded up at the
sixth decimal, is frozen as its bound in `thresholds.csv`.

    pcore.ps1 <log> dev/bench/v0_2_3_cut24_feature/memory.R --base=<base lib> --candidate=<base lib> --work=<scratch> --out=dev/bench/v0_2_3_cut24_feature/records/aa-base-memory --debug=0 --aa

Memory: peak R heap is exactly repeatable (every heap child of a cell gives
the same bytes), so the label-exchange noise is 0 on all four cells
(`memory_noise.csv`). Sensitivity: the extra live 8 MiB raises the median
peak by 8.39 MB on 500 x 1,260 run and 1,166 x 252 run, by 8.08-8.61 MB on
1,166 x 252 sweep, but by only 8,160 bytes on 500 x 1,260 sweep (both arms),
where the peak Vcells reading is the same with and without the extra
vector. The frozen rule (lift above the noise, here 0) counts every cell as
sensitive; the 500 x 1,260 sweep cell's peak is nonetheless set where the
gc maxima do not see the live extra vector, so its memory evidence is weak
and is reported as such at the stage-3 retention decision.
