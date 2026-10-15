# Governance Record Normalization

Role: record; Workstream 35 implementation and verification closeout.
Status: working
Authority: evidence for LDG-3047 and LDG-3048 only; `tickets.yml` remains the
sole ticket authority.

## Scope and necessity

Workstream 35 applies the accepted governance-lifecycle vocabulary to records
that were still forcing a reader to infer current state from historical prose.
It also turns the packet README back into a front door and teaches the existing
report-only guard the two new failure families. It adds no registry, second
ticket ledger, check mode or package gate.

## Lifecycle normalization

The bounded input is the 47 synthesis records listed by
`dev/governance_census/records/synthesis_headers.csv`. Each now starts with a
canonical Role, Status and Authority block. The resulting states are:

| State | Records | Meaning |
| --- | ---: | --- |
| accepted | 28 | operative within the record's stated scope |
| amended | 4 | operative with a dated linked amendment |
| superseded | 10 | historical only, with a dated linked replacement |
| superseded in part | 2 | only the declared remainder stays operative |
| under review | 0 | non-binding until maintainer acceptance |
| draft | 2 | non-binding synthesis input |
| rejected | 1 | historical only, with its rejection reason retained |

The history-projection chain now has explicit dated replacements from v1
through v11. V10 points to accepted v11. Snapshot verification names the
accepted pre-CRAN legacy-removal amendment; accounting-core, validation and
walk-forward name their dated amendments. The risk/OMS and feature-projection
records name both their replacements and operative remainders.

The normalization added metadata only. The synthesis diff contains no removed
line, so decisions, alternative rejections, review results, author names and
independence disclosures remain verbatim below the new headers.

The close review corrected three records that the initial census had mistaken
for `under review`: their final reviews and the v0.1.8.10 accepted-input list
establish all three as accepted. It also restores the exact recorded reason for
the rejected governance synthesis, names receivers for two promotion drafts,
and makes clear that the history-wave register is an input to, not an amendment
of, accepted v11 authority.

The RFC pipeline now documents all six allowed row states. Its history-wave
row stays Paused, every Obligations-open row names Trigger and Route, and the
compiled-execution row carries feasibility as evidence rather than embedding
it in the state token. The history-wave register names its future v11 amendment
as the first application-specific supersession carrier and keeps that work
with the history wave.

## Packet front door and evidence form

The packet README shrank from 684 raw lines and 582 nonblank lines (45,534
UTF-8 bytes at `07f91bcf`) to 115 raw lines and 93 nonblank lines (5,686
bytes). It now links the macro plan, ticket authority, current and earlier cut
review artifacts and durable closeouts without copying mutable ticket status,
dependencies or acceptance text.

It states the Section 5 evidence form once: one stable pointer plus one-line
result for every acceptance item, with input identity, environment, source
commit, reproduction command, result and clock retained for empirical records
where applicable. The Cut 15 scan reports no malformed completed-ticket
evidence and no acceptance/evidence count mismatch.

The final Workstream 34 records were normalized at the same boundary:
LDG-3045 and LDG-3046 are complete, and LDG-3046's last item now records the
finding-bearing review files plus the final finding-free PASS instead of the
superseded CHANGES_REQUIRED state.

The independent WS35 finding report is preserved in `close_review_35.md`.
Earlier Cut 7, 9, 13 and 14 reviews are linked again, and the two legacy RFC
anchors handed over from WS34 now resolve through explicit redirect stubs.

## Guard extension and mutations

`tools/governance-report.R` remains report-only. It now additionally reports:

- an accepted header made stale by a dated linked amendment;
- an Active pipeline row whose route says it is paused;
- an Obligations-open row without both Trigger and Route;
- a completed current-cut ticket whose evidence count differs from acceptance;
- ticket evidence without both a stable pointer and a one-line result; and
- explicitly empirical evidence missing one of its required metadata labels.

LTB-0273 mutates each boundary independently. The reviewed fixture fails when
an accepted record gains an amendment without changing state, when Active is
paired with Paused prose, when Trigger is removed, when evidence is reduced to
a bare path or test anchor, when path words are joined by `and/or`, when an
acceptance/evidence count differs, when evidence is empty, when empirical
evidence omits its reviewed range, and when the required tickets source is
deleted. The existing missing-replacement mutation continues to cover the
superseded receiver rule. The pristine fixture contains a valid empirical
record, remains byte-deterministic and the command still rejects `--check`.

## Verification

- `test-governance-report.R`: 182 expectations passed, with no failure,
  warning or skip.
- `test-documentation-contracts.R` and `test-test-control-plane.R`: passed
  with no failure, warning or skip.
- Canonical header scan: all 47 bounded syntheses passed with zero lifecycle
  findings; state counts match the table above.
- Cut 15 evidence scan: zero findings after the WS34 current-state correction.
- Empirical: input was the tracked design and governance population;
  environment was Windows with R 4.6.1; source commit was `477980e2`;
  reproduction command was `Rscript tools/governance-report.R`; reviewed range
  was `07f91bcf..477980e2`; result was a successful report-only scan of 328
  sources with 996 visible findings; clock was 71.687 seconds. It resolves
  existing debt but remains informational; no finding changes a package, CI,
  release or local gate result.
- Reconciliation against the accepted WS38 integration tree at merge commit
  `7a030be9` preserved that report-only boundary. `Rscript
  tools/governance-report.R` scanned 339 sources and reported 1,034 visible
  findings in 74.129 seconds; the direct current-cut evidence scan reported
  zero malformed, incomplete-count or incomplete-empirical findings. The
  reconciliation also retained WS38's accepted evidence while repairing its
  three records to the pointer-plus-result and one-evidence-per-acceptance
  form.
- The new replacement, amendment and packet links resolve; pre-existing link
  debt remains visible in the report. YAML parsing and `git diff --check`
  passed.

The relevant seven-shape walk is clean. The change adds no event or fact
collector, repeated parser, per-pulse work, candidate recomputation, table
rewrite or R-side data-intensive loop. The only new loops walk the bounded
current cut and its evidence once after one YAML parse. No product runtime path
changed.
