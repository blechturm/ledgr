# v0.2.0.1 Batch 6 Seal-Validator Evidence

Status: Complete after independent correctness review and maintainer acceptance.

Tickets: LDG-2728, LDG-2729, and LDG-2730.
Implementation base: `7a6217bffa77f26ae4626dfab8de7199262b5972`.

## Production replacement

The membership and lifetime validators now use one grouped sort-and-sweep.
Rows are ordered deterministically by scope, effective start, effective end,
state, and stable fact identity. Within each scope, the validator maintains a
previous running maximum end for each schema-bounded state and reports a
conflict when a row starts before an opposing state's prior maximum. `NA`
ends remain open through numeric infinity. Equal starts, equal or nested
intervals, and touching half-open endpoints retain the pairwise semantics.

Trading status uses the accepted hybrid. Rows that neither name a direct
predecessor nor are named by one enter the same grouped sweep under
`(instrument_id, source, precedence)`. Every unordered same-scope pair with
at least one supersession-involved row is then compared under the former
predicate. Only a pair in which one row directly names the other is exempt.
The supersession-reference and acyclicity validator is unchanged.

The public constructors still call the three production validators, so
membership intervals, status facts, and lifetime facts take the new paths at
construction. Seal validation calls those same validators over persisted
evidence.

## Set-backed membership boundary

Before set-backed rows bypass the opposing-state sweep, the seal path proves:

- every set row has a non-empty set identity and `member = TRUE`;
- every `(universe_id, set_id)` references exactly one valid persisted header;
- row effective and knowledge times equal the header, and row effective ends
  are open;
- row and header provenance are identical;
- `(universe_id, set_id, instrument_id)` is unique; and
- the header identity and required fields are non-missing and non-empty.

Both headers and rows are read under the same snapshot-ID predicate. A set row
sharing `(instrument_id, universe_id)` with an interval assertion does not
bypass: both rows enter the general sweep. Valid set-only scopes return no
rows to that sweep. Empty set headers remain valid because they have no set
rows to exempt.

The mutation matrix changes member state, header presence, universe scope,
set identity, effective start, effective end, knowledge time, provenance, and
member identity independently, plus one combined mutation. Every case fails
closed. A mixed opposing interval enters the sweep and raises the retained
structural-conflict class. An end-to-end sealed snapshot passes normally and
rejects a directly persisted negative set member under the new set-invalid
class.

## Equivalence evidence

The deterministic harness uses seed `20260917`. For each of 2,000 iterations,
it generates and shuffles one membership, one lifetime, and one status row
set, for 6,000 randomized comparisons in total. Each production result is
compared with its retained test-only pairwise reference over success/failure,
the complete condition-class vector, and the message. All 6,000 agree.

Explicit cases additionally cover:

- zero and one row;
- same-state and opposing-state overlap;
- touching half-open endpoints;
- nested and equal intervals;
- finite and open ends;
- multiple instruments and universes;
- all three lifetime assertion states;
- status source and precedence separation;
- direct supersession and unlinked conflict; and
- the accepted X/Y/J false-positive and Y/Z false-negative guards.

The installed-source structural test rejects retained reference names in the
namespace, rejects the former nested row-pair loop shape in all three
validators, and requires the seal path to call the setwise routing helper.
The quadratic references remain only in the test helper.

## Batch 5 review carry-forwards

The malformed equity-prefix matrix now asserts the distinct exact-prefix,
non-monotone, and out-of-calendar messages. A foreign run-ID row has a direct
rejection witness. These are test-only closures and do not alter Batch 5
production behavior.

## Verification

- focused fact, state, retained-reference, equivalence, finalization, seal,
  and persistence files: passed in 54.5 seconds;
- all 19 `test-availability*.R` files: passed in 265.5 seconds with zero
  failures, errors, warnings, or skips;
- all snapshot-focused files: passed in 41.4 seconds with one expected skip
  for the installed quantmod missing-package path;
- the complete source-tree suite: passed in 989.6 seconds with the same one
  expected skip;
- the corrected source package and all vignettes built in 263.0 seconds with
  only the existing long-path portability warnings; and
- `R CMD check --no-manual --no-build-vignettes`: passed under R 4.6.1 in
  1,210.1 seconds with zero errors, zero warnings, and the existing long-path
  NOTE.

The first build invocation exposed Pandoc but not the Quarto executable and
therefore stopped before package checking. The successful build explicitly
set both `QUARTO_PATH` and `RSTUDIO_PANDOC`. The first check found one new
namespace-qualification NOTE for `ave()` and `head()`; qualifying them and
rebuilding returned the final check to the existing one-NOTE baseline.

The registered full-scale cold seal was not run. Its single measurement
belongs to Batch 8, and the historical 60-90 second estimate remains a
forecast rather than an achieved Batch 6 result.

## Independent review

The independent reviewer replayed all 6,000 randomized comparisons with zero
mismatches and passed the focused 118-block, 2,617-expectation regression set.
The review accepted the grouped sweeps, status hybrid, setwise bypass, and
Batch 5 carry-forwards.

## Post-review follow-up

The three Low observations from the accepted review were closed with the
Batch 7 correction follow-up. Scope identity is now grouped directly on its
columns, so control characters cannot merge distinct scopes or bind a set row
to the wrong header. Missing membership, lifetime, or status state now raises
`ledgr_fact_structural_conflict`, including a status row routed through the
supersession lane. The production-source guard now walks the R syntax tree and
rejects any nested `for` construct across the validators and grouped overlap
helper rather than recognizing one deparsed loop spelling.

Focused witnesses cover the delimiter collision in membership, status, and
set-header matching; all three missing-state families; and a rewritten nested
row-pair loop that the old literal guard missed. The original 6,000 randomized
comparisons remain part of the focused validator test. All 20 availability and
snapshot-seal test files passed on the final tree in 330 seconds. Routing
30,300 valid complete-set rows through the corrected setwise guard took
0.01-0.15 seconds across two local checks, so the exact multi-column grouping
does not restore the retired quadratic behavior. This bounded check is a
regression guard, not a release
benchmark.
