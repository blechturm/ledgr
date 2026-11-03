# Focused review: Cut 11 Workstream 23 private-gate reader fix

Mode: Type 1, focused review of product commit `01cc546d` and evidence commit
`2d403ec7`, read against LDG-3200..3202, `close_review_23.md`,
`close_review_23_rereview_1.md` and `close_review_23_rereview_2.md`. Host
boundary: no full suite, no worktree, no private data, no E:. Only named test
files, in-memory mutations and probes were run.

Verdict: **PASS_AFTER_PATCHES**. The product change is correct and stays in
scope. There is no design challenge, so not `NEEDS_TYPE_2`. Two evidence
statements claim more than the code shows; the exact patches are below, and
applying them needs no further review. The private Sharadar gate stays OPEN.

## What was verified

1. **Row scoping is correct.** `R/accounting-replay.R:387-397` now uses
   `any_present()`. That is the same per-row non-null rule the 3.3 field matrix
   uses for every other irrelevant field, so a subtype counts only where it is
   present on that row. Probes against the candidate:
   - a block where only the opening CASHFLOW has `subtype` is admitted;
   - the same block plus `subtype`, `equity_subtype` or `vendor_subtype` on the
     DISPOSITION is refused with `ledgr_invalid_accounting_event`;
   - a DISPOSITION-only block with `subtype` is refused;
   - `""`, `5` and `false` as the disposition subtype are refused.
2. **The new detectors are failure-sensitive.** Mutation M1 puts back the
   block-wide `names(meta)` test. It fails LTB-0550 (the new mixed-block case)
   and LTB-0553 (the post-update readers). The current-shape half of LTB-0553
   passes under M1, so the failure is the legacy-row edit, as intended.
3. **Nothing forbidden is re-admitted, and no other rule is weakened.** The
   diff touches only the subtype term. The field matrix, unknown-key check,
   ordering/boundary checks and reconciliation are byte-unchanged.
   `test-typed-accounting-boundary.R`, `test-terminal-reporting.R`,
   `test-corporate-action-{disposition,cash,results,recovery,composition}.R`,
   `test-result-output.R` and `test-run-store.R` all pass.
4. **The tooling records are exact.**
   - `dev/bench/v0_2_3_typed_accounting/check.R` reports PASS.
   - `a0_successor/compare.R` on the committed pair reports PASS (281 files,
     four accepted cells).
   - The A0 "no output change" claim holds by construction: on any block with
     none of the three keys, old and new code compute the same predicate.
   - `tools/check-codebase-contracts.R --mode=check`, written to a temp dir,
     reproduces the committed census byte for byte (apart from its README). The
     `523` line shift, `reader_prepare` 8→9 and the two `ledger_events`
     references in `test-terminal-reporting.R` match the diff.
   - `git rev-parse 01cc546d:R` is `9cd2d613…` and `:src` is `b8e90af3…`, as
     `record_identities.csv` states. HEAD's `R/` tree equals `01cc546d`'s.
5. **No new optimization antipattern.** `any_present()` applies a fixed
   three-name `lapply` over vectorized row predicates. Nothing iterates over
   events.

## Findings

P1. **Low: the record names the wrong detector for "an actual disposition
subtype stays forbidden".**
`tickets.yml` (LDG-3201 evidence, the `01cc546d` line) says "LTB-0550 keeps an
actual disposition subtype forbidden". LCL-0542 `overlapping_evidence` says
"LCL-0539 owns the field matrix and still refuses an actual subtype value on a
disposition". Neither statement holds. LTB-0550 has no disposition-subtype
case: its `mutation_cases` list contains no subtype field. Mutation M2 deletes
the subtype term entirely, and it still passes LTB-0550 and LTB-0553. The only
test that catches M2 is LTB-0050 (`test-corporate-action-disposition.R:158-166`,
`vendor_subtype` on a single-row block).

*Exact patch:*
- In `tickets.yml`, replace "LTB-0550 keeps an actual disposition subtype
  forbidden;" with "LTB-0050 keeps an actual disposition subtype forbidden;
  LTB-0550 admits a subtype on a non-disposition row of a mixed block;".
- In `tests/claims.yml` LCL-0542 `overlapping_evidence`, replace "LCL-0539 owns
  the field matrix and still refuses an actual subtype value on a disposition"
  with "LTB-0050 still refuses an actual subtype value on a disposition;
  LCL-0539 owns the field matrix".

No test change is required. The mixed-block refusal (a non-disposition subtype
plus a disposition subtype) is confirmed by probe only.

P2. **Low: the "legacy / base-shaped" origin of the subtype key has no support
in the repository.**
No ledger writer at `v0.2.2`, base `0d6c0b11` or `01cc546d` puts `subtype`,
`equity_subtype` or `vendor_subtype` into ledger `meta_json`:
- the opening writer (`R/fold-event-buffer.R:127-133`), the corporate cash
  writer and the terminal writer emit none of them;
- the only `subtype =` assignments in `R/` build fact frames or condition
  fields.

Even so, three places state the origin as fact:
- the LTB-0553 comment says "Base-shaped stores may have a subtype on a
  different accounting row";
- LCL-0542 `scope` says "base-shaped stored rows remain readable";
- the closeout says the private failure came from "a subtype on one valid
  non-disposition event".

The fix is the right semantics either way. But on a block without those keys,
old and new code are provably identical. So the fix clears the private gate
only if the private store really does carry such a key, and the record never
says which row or writer put it there.

*Exact patch:*
- In `typed_accounting_reader_closeout.md`, after "creates a missing subtype
  cell on every other row.", add one sentence naming the observed key and event
  type from the private store (aggregate only, no private values). If that
  cannot be stated, add instead: "No in-repository writer emits these keys; the
  resumed aggregate comparison is the confirmation of this diagnosis."
- Change the LTB-0553 comment to "A store may carry a subtype on a different
  accounting row".
- In LCL-0542 `scope`, change "base-shaped stored rows" to "rows carrying a
  non-disposition subtype".

## Observation (no action)

A DISPOSITION with an explicit `"subtype": null`, or a non-scalar subtype
(`["a","b"]`, `{}`), is now admitted. The base per-row key check refused these.
This matches synthesis 3.3 ("any … non-null irrelevant field refuses"), and
every other matrix field already behaves the same way: `entitled_quantity` as
null or `[1,2]` on a disposition is admitted today. No writer can produce
these values. Treat it as a pre-existing property of the matrix, not a
regression from this patch.

## Gate

The private Sharadar aggregate stays **OPEN** and blocks WS24. If P2's origin
sentence cannot be written, the resumed comparison on `01cc546d` is also the
only evidence that this patch was the fault.
