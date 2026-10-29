Verdict: PASS
Role: record; independent clean-context implementation review of LDG-3159.
Status: accepted; review recorded 2026-10-29.
Authority: review evidence against the accepted cut; this file grants no new implementation scope.

Reviewed `7353594b..dec120e5` on `claude/ws2-rng`, including all six named
commits; HEAD was `dec120e5d58f3cf997218602f5304fcaed825c7d`. This is the
requested Type 1 ticket review, not the LDG-3160/3161 workstream close review.
Authority is AGENTS.md, cut 4 decisions (2)/(7), LDG-3159's scope,
acceptance and evidence (`tickets.yml:628-643`), and the accepted
`ws2_rng_design.md` Sections 2, 6-8 and 10. Relevant stable contract addresses
are `contracts.md#contract-strategy-reproducibility` and
`contracts.md#contract-execution-fold-core`. The prior `ldg3158_review.md`
supplies the clock disposition and isolation context.

## Findings, in severity order

No blocking or required-patch finding. I found no wrong pulse seed, wrong
identity, missing-marker fallback or weakened existing test in this range.
The arithmetic and run-local axis are settled design inputs; the bounded
statistical evidence does not claim independent streams or collision freedom.
No unsettled design question requires Type 2.

Two evidence limits are retained explicitly below: the original A0 checker
is expected to fail on the declared changes and the existing clock field;
the revert runner's error blocks are not successful oracle-predicate guts.
Neither is presented as a green workstream-close gate.

## 1. Arithmetic, golden values and refusals

`R/rng.R:48-97` implements exactly
`fmix32(fmix32(u32(s)) xor u32(p)) %% 2147483647 + 1`. The two multiplier
constants are the specified `0x85EBCA6B` and `0xC2B2AE35`. Each XOR receives
two non-negative 16-bit integer halves; reconstruction uses doubles.
The cross-product sum and the final low-product-plus-shifted-cross-term
are below 2^33. Shifts/divisions and modular reductions operate on exact
integer-valued doubles, far below 2^53. The final integer conversion occurs
only in `[1, 2147483647]`. There is no signed overflow or approximate
64-bit multiplication masquerading as exact arithmetic.

I wrote and executed a separate Python integer implementation using full
products and 32-bit masks, without calling R or importing production code.
It reproduced all 63 fixture values. Representative independently derived
values are:

| Execution seed | Pulse | Pulse seed |
| ---: | ---: | ---: |
| -2147483647 | 1 | 1329652449 |
| -2147483647 | 65536 | 1000840576 |
| -2147483647 | 2147483647 | 1830298223 |
| -1 | 65535 | 231637156 |
| -1 | 65536 | 1778090837 |
| 0 | 2147483647 | 2043416234 |
| 1 | 65536 | 1150499547 |
| 2 | 3 | 581926497 |
| 7 | 65537 | 1089673948 |
| 2591 | 65535 | 1632251389 |
| 2147483646 | 2147483647 | 687568460 |
| 2147483647 | 2147483647 | 1019020745 |

The fixture matches the already accepted Section 2.5 table in every cell;
that note is unchanged in this implementation range. The supplied
`golden.py` is also an exact-integer derivation with no package dependency.
The committed test only reads the fixed CSV (`test-pulse-seed-v2.R:8-13`),
and never regenerates it from the routine under test. This supports the
claimed independent provenance, rather than an expected-value capture from
production.

Both supplied logs contain precisely those 63 integers and report zero
mismatches. Their driver loads the installed package and invokes its
routine. Windows is R 4.6.1 ucrt, x86_64-w64-mingw32; Linux is R 4.6.0,
x86_64-pc-linux-gnu under WSL2. I independently reran Windows production
through the committed tests and checked both logs against Python; I did not
independently launch Linux. The logged installed-package check supplies the
required Linux execution evidence.

The edge block (`test-pulse-seed-v2.R:117`) passes: seed -2147483648,
NA and fractional seeds refuse with `ledgr_invalid_args`; so do pulse 0,
negative, fractional, NA, 2147483648 and Inf inputs. Numeric -2147483648
exists as a double but cannot become a non-missing R integer; normalization
correctly refuses it. NULL seed returns NULL and an empty pulse vector
returns `integer()` as specified.

B1-B6 and all three failing controls pass their frozen assertions
(`test-pulse-seed-v2.R:142`). B4 is 10000 distinct/0 shared, B5 is 0,
B6 is 1000; the controls fail exactly the named bounds. No threshold changed.

## 2. Fold integration and pulse axis

`R/fold-engine.R:1618-1624` prepares one vector inside the existing seeded
branch, using the entire `pulses_posix` calendar. It is carried in services
at line 1836 and read at line 766 through `ledgr_pulse_seed_at`
(`R/rng.R:101-107`). This is a scalar read, not another calculation.
Unseeded folds construct no vector and expose NULL.

The loop continues to use calendar index `i` (`R/fold-engine.R:1899,1933`);
resume still derives `start_idx = last_idx + 1L` (`R/run-resume.R:53`).
Scheduled skips retain their index and bypass the decision-stage read.
No new execution-mode branch or fold engine was introduced.

Grep and source reading find no `ledgr_derive_pulse_seed` in R/ and no alias.
The new arithmetic/accessor closure reaches no JSON, digest, serialization
or derived-seed hash. `ledgr_derive_seed` remains unchanged for candidate
and window derivation. The structural and runtime test at
`test-pulse-seed-v2.R:170` passes: seeded 10/30-pulse runs build one
vector, perform 10/30 reads and zero derive-seed calls; unseeded runs build
none; adding a seed causes no pulse-count-dependent JSON work.

All same-calendar witnesses pass: straight, checkpointed resume at indices
4-8, a window with its own axis, scheduled decisions at 3/6, sweep and
promotion, plus the two-worker economic witness. The actual-draw witness
executes resumed pulses 6-12 and checks varying quantities and identical
fills, as well as window/direct equality. The independent first-three-value
anchor added in 936ed585 prevents a self-consistent wrong rule from passing
the straight-run witness. No longer-calendar overlapping-bar claim is made.

## 3. Versioning, candidates and missing markers

One constant (`R/rng.R:42`) feeds the marker helper, seeded configuration,
validation and automatically discovered store binding. Both sweep writes
use that helper (`R/sweep.R:452,2202`); persistence copies provenance
(`R/sweep-persistence.R:584`). The walk-forward derivation marker remains
`ledgr_walk_forward_seed_v1` as required.

Walk-forward results are stamped only at production/open
(`R/walk-forward.R:301`, `R/walk-forward-inspection.R:80`). Open reads the
session through the gated run-store open (`walk-forward-inspection.R:385`).
Candidate extraction copies the results attribute at lines 143, 258 and
298; it does not consult the current constant to repair an old object.

`R/sweep.R:838` validates before the first snapshot hold at line 839 and
before `ledgr_run` at line 869. The validator (`R/rng.R:114-149`) checks
provenance directly, with no metadata fallback, for seeded and unseeded
candidates. The complete current/old/missing sweep/walk-forward table passes;
all eight refusal cases observe zero holds, zero run calls and an unchanged
run list. A wrong walk-forward derivation marker also refuses. Conditions
have the required `c("ledgr_seed_rule_mismatch", "ledgr_invalid_args")` pairing.

Search of candidate consumers found no other executable stored-candidate
entry point. Reproduction-key and inspection helpers read evidence;
walk-forward runs its newly evaluated grid selections. The similarly named
internal sweep execution builder also serves pulse inspection, which creates
its own execution inputs rather than consuming a stored candidate.

Dropping NULL `pulse_seed_contract` from a sweep key or source context is
consistent with Section 6's stated intent. A missing walk-forward marker is
not synthesized in the key (`R/sweep.R:744`) and cannot reach context
publication: validation has already refused it. I additionally checked that
a current marker left in `sweep_meta` cannot rescue missing walk-forward
provenance. The context's metadata/provenance copy at
`R/promotion-context.R:147` therefore does not provide a validation fallback.

## 4. Config validation and existing-test integrity

`R/config-validate.R:78-96` refuses old/missing/non-current rules only for
seeded configs. The pairing
`c("ledgr_seed_rule_mismatch", "ledgr_invalid_config")` is appropriate:
the design requires the first class for config validation and reserves the
`ledgr_invalid_args` pairing for candidate promotion. Accepting numeric 2
and integer 2L accommodates JSON decoding of the same integer value, not an
old format. Unseeded validation and serialization are unchanged.

3956415a is a legitimate, stated-reason fixture update to the current config
format. Its exact diff adds the one required field through the existing
modernizing helper (`helper-fixtures.R:226-229`) and three inline validation
fixtures (`test-config.R:275,363`, `test-risk-config.R:101`). The affected
runner cases are six v0.1.0 acceptance blocks and three v0.1.1 blocks, plus
the two config and one risk validation blocks. These exercise other contracts
and require otherwise valid current-format inputs. No assertion, fault,
oracle or pinned hash changes; new tests explicitly cover refusal of a
missing rule. The reason is recorded in the commit and ticket evidence.
This is not a reason to retain a compatibility fallback in production.

Every other existing-test diff is similarly bounded:

- `test-sweep.R:549,573,755`: literal v1-to-v2 marker pins, retaining exact
  assertions rather than replacing them with a value derived from production.
- `test-rng.R:15-31` and `test-experiment-run.R:157`: deleted scalar helper
  replaced by vector owner; stability, ambient independence, adjacency,
  range, refusal and observed-context assertions retained. The derive-seed
  golden 350931654 is unchanged. The existing modulo resume fixture is unchanged.
- `test-store-gate-contracts.R:20,75`: exactly one new named integer binding
  and 27-to-28 count; all previous exact-binding predicates remain.
- Condition reference/Rd and the census: one new public condition row,
  recording both emission sites; no existing row or scanner predicate removed.

I independently ran the nine existing test files covering these changes and
the condition census: 84 blocks, 687 expectations, no failures/errors/skips.
The new file passes 16 blocks/230 expectations with no skips. The supplied
full-suite log and RDS independently agree on 1269 blocks, 23197 expectations,
zero failures/errors and one existing quantmod missing-path skip. I did not
rerun the full suite or perform build/check in this ticket review.

## 5. Identity and old stores

The independent identity probe on the designated design base `aa2931e9`
matches the supplied `7353594b` base probe in every field. Comparing the
candidate gives exactly one added binding, integer
`ledgr_pulse_seed_rule_version = 2L`; all 27 old bindings are identical.
No identity/content hash rule version changes.

| Identity | Base | Candidate |
| --- | --- | --- |
| Seeded config hash prefix | a64da030 | 91229b23 |
| Seeded default run id | run_c2972ecc9472b4d8 | run_e9c5c0be332eabfa |
| Unseeded config hash prefix | 5946f113 | 5946f113 |
| Unseeded default run id | run_ddacac4bf6b7b5b3 | run_ddacac4bf6b7b5b3 |
| Identical-input snapshot hash prefix | b54a78e3 | b54a78e3 |

The seeded engine gains only `pulse_seed_rule:2`. Removing that field restores
the full base hash in the committed identity test. The old-store test
(`test-pulse-seed-v2.R:670`) removes that binding from the recorded
fingerprint and independently passes: open refuses with
`ledgr_store_rebuild_required`, cause `fingerprint_mismatch`, differing
constant exactly `ledgr_pulse_seed_rule_version`. No old reader or migration
was added.

## 6. Original oracles and permitted observer changes

Original A0/RNG sources, records and checkers are unchanged in this range.
All review outputs are outside the repository.

The original A0 checker exits 1 with 52 differing files; its agreement report
still has 213 checks and four existing disagreements. My independent
field comparator validates both manifests' bytes/SHA-256 and all 290 record
files: 238 identical, 14 A1, 12 A2-only, 11 A3, 11 A4, three A5, and one
clock file. A2 also applies to the two economic sweep tables in A4/A5.
Every new stored config hash independently equals `config_hash(new JSON)`;
the two unseeded run directories are identical.

For A4 I archived **aa2931e9**, ran the original sequential harness, and
replaced only its scalar pulse function with my Python exact-integer model.
Candidate economic rows match that model exactly. Only tight changes; loose
rows remain identical. Changed current-row counts are exactly the note's
5 ledger events, 5 fills, 6 equity rows, 2 trades, 7 metrics, 6 memory events,
5 memory fills, 6 memory equity rows, 1 sweep row, 6 returns and 2 sweep trades.
A5 matches the sequential candidate. The remaining change is exactly the
two `selected_at_utc` cells, 2026-10-28 to 2026-10-29. The LDG-3158 review's
narrow clock-disposition obligation remains at LDG-3161; this review grants
no extra allowance or change to the immutable originals.

The unadapted RNG checker exits 1 because its deleted-helper observer stops
the probe, producing no records. I diffed the supplied scratch probe against
the original: apart from root relocation, there are **only three** changes:
the two current-rule reads use `ledgr_pulse_seeds`, and the census wraps
`ledgr_pulse_seed_at`, taking execution seed from services. Fixtures,
canonicalization, stochastic strategies and original records are untouched.
The scratch checker's only change is its root relocation. These are exactly
the Section 8 permitted pulse-observation changes.

A fresh run of that scratch copy exits 1 on the eight expected changed
tables. Rerunning the supplied field comparator against the fresh records
passes 35/35 checks. I supplemented it with independent Python pulse values,
exact checks of unmentioned census/caller/store fields, and a fresh
**aa2931e9** economic model using Python-computed pulse vectors. Sequential
fills/trades/equities match; workers match the sequential successor. Trade
counts are 33, 36 and 39 for lecuyer, mt and none. Caller/store/detection
outputs retain their LDG-3158 staging. No unexplained field change remains.

Those 35 checks are ticket evidence, not the entire future Section 8.2.1
census gate: this copy still has the original 13 census columns. LDG-3161
must implement/check the separately authorized query/mutation observations,
new columns and exact caller ledger when recording its successor. Retain the
same three pulse-observation edits; no broader fixture or observer change is
justified by this PASS.

## 7. Revert runner

`dev/bench/v0_2_3_ws2_reverts/runner.R` is a proportionate 101-line namespace
mutation driver, reusing committed tests and separating failed expectations,
errors and skips in its CSV. I executed none and all seven mutations.

| Mutation | Observed result across the 16 blocks |
| --- | --- |
| none | all pass, 230 expectations, no skips |
| pulse_shift | assertion failures in straight/sweep witnesses; golden and edge blocks error when maximum pulse becomes 2147483648 |
| seed_ignoring | golden, edge, frozen bounds and sweep blocks have assertion failures; no errors |
| marker_stale | sweep witness, constant and both candidate blocks have assertion failures; no errors |
| config_rule_dropped | 12 seeded-execution blocks error at config validation; resume also has the explicit missing-field assertion failure |
| wf_marker_from_constant | only walk-forward candidate block fails its assertions; no errors |
| validation_noop | only the two candidate blocks fail their assertions; no errors |
| per_pulse_hash | structural/no-hash and five same-calendar blocks fail assertions; the accessor unit case also errors because its synthetic services omit execution_seed |

Thus the claim that every red block is the intended predicate failing
would be too strong. The errors above are accounted for, not accepted as
successful oracle-predicate guts. The runner returns process exit 0 after
reporting mutations, by design; its CSV is evidence, not an automatic gate.
In particular config_rule_dropped is fail-closed refusal evidence, not a
successful A3 economic-record comparison. LDG-3161 owns the actual
replacement oracle guts and their expected predicates.

The documented namespace-only limitation is real: mirai workers load the
unmodified source. These executions establish sequential/test-namespace
mutation sensitivity, not worker delivery of a revert. Worker-sensitive
replacement guts need the source-copy mechanism already identified in the
LDG-3158 review. No unrelated product defect was exposed.

## 8. Seven shapes and timing risk

| Manual shape, verbatim | Touched fold assessment |
| --- | --- |
| One-row frame per element, bound at the end. | None added. |
| Full-table subset inside a loop over ids. | None added. |
| Per-element parsing or formatting where a vectorised call exists. | One vectorized rule call; no R loop over pulses. |
| Per-row JSON on repetitive strings. | The per-decision JSON/SHA-256 is removed. |
| Work computed and discarded, or recomputed on every call. | Full-calendar vector built once; resume prefixes and skipped entries are deliberately unused, as Section 2.3 accepts. None for unseeded folds. |
| Quadratic validators. | None added; argument validation scans vectors linearly once. |
| Scalar writes into an environment-held vector. | None added; services carries a read-only integer vector. |

The vector and arithmetic temporaries are O(calendar pulses), rather than
R-level per-pulse hashing. Source inspection identifies no extra hot-path
work that defeats the intended optimization, but cannot certify a 0.97
end-to-end ratio. Very sparse schedules or a late resume still pay for the
whole calendar, an explicit accepted tradeoff. No timing measurement was
performed and neither excluded timing directory was edited.

## Optional

For LDG-3161 evidence tooling, an explicit expected-block/predicate map and
separate error totals would make mutation reports harder to overstate.
Retain the runner's worker-delivery warning. This is not a required patch
to LDG-3159 and does not authorize changes to frozen tests or guts.

## Commands and exit codes

For compactness, R denotes `C:/Users/maxth/ledgr-wt/ws2-rng`, T denotes
`C:/Users/maxth/AppData/Local/Temp/ldg3159-independent-review`, and I denotes
`C:/Users/maxth/AppData/Local/Temp/claude/c--Users-maxth-Documents-GitHub-ledgr/78383ced-ac83-4579-b480-65f39660106d/scratchpad/ldg3159`.
These abbreviations expand to absolute paths; commands did not change shell
working directory. G denotes the supplied
`git --git-dir=C:/Users/maxth/Documents/GitHub/ledgr/.git/worktrees/ws2-rng --work-tree=R`
fallback. Each shell invocation was a single command. Rscript is R 4.6.1
ucrt; recurring startup C.UTF-8 locale warnings occurred before execution.

| Command or inspection group | Exit / result |
| --- | --- |
| `git -C R status --short`; `git -C R diff --stat 7353594b..dec120e5` | 1 each, ownership refusal; used G thereafter. |
| `G status --short`; `diff --stat`; `diff ... -- R`; existing-test and census/Rd diffs; `show 3956415a --stat`; `log --oneline 7353594b..dec120e5`; `rev-parse HEAD`; `diff --check 7353594b..dec120e5` | 0 each; intended six commits, no whitespace defects. |
| `Get-Content -LiteralPath <authority/source/test/scratch evidence path>`; `rg -n` source/call-site inspections; scratch directory listing | 0, except two exploratory ticket-ID rg patterns returned 1 before the quoted YAML ID was located by title. |
| `G diff --no-index R/dev/bench/v0_2_3_rng_baseline/probe.R I/rngprobe/probe.R`; corresponding check.R comparison | 1 each, expected differences: root relocation and exactly three permitted observer edits in probe; root relocation only in checker. |
| `python -I T/independent.py` | 0; all 63 note/fixture/platform-log integers independently reproduced. |
| `G archive --format=tar --output=T/base.tar aa2931e9`; native `C:/Windows/System32/tar.exe -xf T/base.tar -C T/base` | 0 each; directory creation also 0. |
| `Rscript R/dev/bench/v0_2_3_output_freeze/check.R --out=T/a0 --agreement=T/a0-agreement.csv --pkg=R` | 1; 52 expected differing files, 213 agreement checks/four existing disagreements. |
| `Rscript T/model.R --pkg=T/base`; `python -I T/compare.py` | 0 each; independent Python-backed base A4 model and exact A1-A5/clock/manifests comparison. |
| `Rscript T/additional.R` | 0; every A0 config hash verified, nine existing files: 84 blocks/687 expectations, no failure/error/skip. |
| `Rscript R/dev/bench/v0_2_3_rng_baseline/check.R --out=T/rng-original-observer` | 1; deleted observer helper stops probe, nine tables consequently absent. |
| `Copy-Item -LiteralPath I/rngprobe -Destination T/rngprobe -Recurse`; `Rscript T/prepare.R` | 0 each; independent-output copy and scratch comparator/model preparation. |
| `Rscript T/rngprobe/check.R --records=R/dev/bench/v0_2_3_rng_baseline/records --out=T/rng` | 1; exactly eight expected differing tables. |
| `Rscript T/rng_compare.R`; `Rscript T/rng-model.R`; `python -I T/rng_extra.py` | 0 each finally; 35/35 checks, independent economic model, full unmentioned-field checks. First rng_extra.py attempt exited 1 because my scratch check mistakenly required original final_equity_a unchanged in store_rng; corrected to the note's explicit allowance for both equity columns, then passed. |
| `Rscript I/identity.R T/base T/id-base.rds`; `Rscript I/identity.R R T/id-candidate.rds`; `Rscript T/finalchecks.R` | 0 each; bindings/hashes/ids, missing-provenance refusal despite current metadata, supplied full-suite RDS and independent test/mutation totals verified. |
| `Rscript R/dev/bench/v0_2_3_ws2_reverts/runner.R --root=R --mutation=<m> --out=T/<m>.csv` for each of none, pulse_shift, seed_ignoring, marker_stale, config_rule_dropped, wf_marker_from_constant, validation_noop, per_pulse_hash | 0 each; CSV outcomes above, no skips. Exit 0 is the reporting runner's status, not a claim that mutated tests passed. |
| `G diff --numstat 7353594b..dec120e5 -- dev/bench/v0_2_3_output_freeze dev/bench/v0_2_3_rng_baseline inst/design/ledgr_v0_2_3_spec_packet/ws2_rng_design.md` | 0, empty: original oracles and accepted note unchanged. |
| `G checkout -- R/cpp11.R src/cpp11.cpp` | Initial call 1, external git index.lock permission; authorized escalated retry 0. Repeated after the final load; only these generated files restored. |
| Final `G status --short`; `G diff --exit-code -- R/cpp11.R src/cpp11.cpp` | 0 each; only this review and the pre-existing untracked timing directory, no generated-file diff. |

Scratch scripts and this review were written with apply_patch. Final status
is checked after recording the review and restoring generated bindings. No
commit was made; the pre-existing untracked timing directory remains untouched.
