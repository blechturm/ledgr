# Inventory row review brief: the switch's test inventory

- Status: approved by the maintainer on 2026-11-27. LDG-3280 requires this
  review before the switch: "The maintainer approves each row and an
  independent Type 1 review verifies it before the switch; unresolved
  affected rows block it." The maintainer approved every row on
  2026-11-27.
- Mode: **Type 1.** Verify the approved rows against their stated claims,
  and independently ask whether the inputs are right. A row whose
  disposition needs a design change returns NEEDS_TYPE_2.
- Reviewer: an independent session that wrote none of the inventory.

## What you review

The inventory lists every test, helper and maintained detector that the
lean-core switch (Cut 28) affects, and how each is handled:
`dev/lean_core/parity/evidence/ldg3280/census/inventory.csv`, with 196 rows,
R001 to R196. Its README (`evidence/ldg3280/README.md`) and the census
(`census/census.md`) say how it was built. Handling letters:
- a: needs a lean injection or observation point;
- b: a mechanical remap;
- c: an authorized semantic disposition;
- d: resolved by the switch;
- e: fixed in Cut 27;
- g: kept until WS14.

The binding rules (lean fold core synthesis Q3; pulse plumbing Section 7;
tickets.yml LDG-3280 and Cut 27 decision 8):
- a representation remap preserves fixtures, semantic oracles and
  registered witness strength;
- a semantic change cites its own accepted disposition;
- a proof that needs Cut 28's actual API or format removal stays an
  individually named gate.

## What to check

1. **Completeness.** Is every affected test block, helper and detector in
   the inventory?
   - Check the census method.
   - Rerun `evidence/ldg3280/suite_reconcile.R` on
     `evidence/ldg3280/suite/tests.csv`.
   - Spot-check blocks the census excluded (`census/part_*_excluded.txt`)
     against their stated reasons.
2. **Handling.** For each row, is the handling right?
   - A b row must truly preserve its fixture, oracle and witness.
   - A c row must cite an accepted authority: a rules-ledger entry, a
     pulse-plumbing section, or a maintainer decision in tickets.yml.
   - An a row must truly need a seam.
   - A g row must match Cut 27 decision 10.
   Read the twelve decision rows (`question` column) against
   `amendment_test_inventory`.
3. **The demonstrations** (`evidence/ldg3280/remaps/`, `summary.csv`).
   - Does each DEMONSTRATED row's patch keep the block's claim, and does
     its mutation break that claim, not merely crash?
   - Rerun `dev/lean_core/parity/remap_demo.R` on a sample of rows of your
     choice, at least one per test file, into your own output directory.
     The runner writes into `--row`, so copy the row directory first.
   - Are the six no-witness rows' identity probes sound?
   - Are the twelve gates truly blocked on Cut 28?
   - Are the four findings handled?
4. **Vacuous passes.** After Cut 28, could any row's block pass without
   testing anything? The census lists known cases (cross-cutting finding
   2); look for more.
5. **The Cut 28 design item** (`evidence/ldg3280/cut28_design_item.md`).
   Does it list every a row, and is each row's need stated precisely
   enough to design against?

## Output

Write `inventory_row_review.md` into the output directory you are given:
- a verdict: PASS, PASS_AFTER_PATCHES, CHANGES_REQUIRED or NEEDS_TYPE_2;
- findings numbered F1, F2, ..., each naming its row ids, what is wrong,
  why it matters, and the fix;
- mark each finding blocking or optional;
- the rows you sampled and the commands you ran.

## Rules

- Read only. Do not edit the repository; do not commit or push.
- Run R as "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe", one command
  per call, with absolute paths. Never load a source tree from two processes
  at once. Use the pin's source archive
  C:/Users/maxth/ledgr-wt/pin-src-7f65733f and library
  C:/Users/maxth/ledgr-wt/pin-lib-7f65733f.
- Do not touch E:, C:/Users/maxth/ledgr-research or vendor data.
- Write plain English, UTF-8 or ASCII.
