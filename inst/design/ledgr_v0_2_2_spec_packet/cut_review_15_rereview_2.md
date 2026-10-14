# Cut 15 Final Focused Confirmation

- Mode: Type 1 focused confirmation of the second Cut 15 correction.
- Reviewer: clean-context Claude Opus session at high effort; read-only.
- Date: 2026-10-14.
- Base product tree: `f262e77a`; Cut 15 remained an uncommitted draft.
- Prior reviews: [cut_review_15.md](cut_review_15.md) and
  [cut_review_15_rereview.md](cut_review_15_rereview.md).

## Verdict

**CHANGES_REQUIRED.** Three of the four reviewed residues were closed. One
adversarial strict-TTR environment case remained. The prescribed repair is one
ticket clause. Because this is the third correction turn, the result returns
to the maintainer rather than requesting a fourth review.

## Closed residues

1. LDG-3056 now enumerates the one-time rule-3 identity changes, binds ordinary
   deterministic direct captures, keeps all package constructors usable and
   gives the CSV adapter a private constructor-owned route through its existing
   `params$data_hash` without serializing row values or changing
   `ledgr_stable_payload()`.
2. LDG-3043 waits for LDG-3056. LDG-3056 owns the contract and teaching update,
   including the explicit boundary that a captured function's own captures are
   not recursively included. The packet README says Workstream 33 waits for all
   of Workstream 36.
3. LDG-3053 and LDG-3054 name the dense peer-benchmark `record` preset and its
   matching availability arm in the one-execution-mode probe.

The stale feature-cache comment is owned by LDG-3049, Workstream 37 waits on
LDG-3056, every dependency resolves and no product file is changed by the
draft.

## Remaining finding

### N1: the strict-TTR environment check remained forgeable

LDG-3051 required matching template bodies, one shared enclosing environment
and the ledgr namespace as that environment's parent. A forged closure could
still meet all three conditions while binding a local `ledgr_ttr_call` and
thereby skip the parity check that detects changed behavior.

Required correction: the shared enclosing environment must bind none of the
call symbols resolved by either template body, including `ledgr_ttr_call`,
`as.numeric` and `::`. The hostile witness must use an environment whose parent
is the ledgr namespace and which locally binds `ledgr_ttr_call`, so it tests the
new boundary rather than failing only on the parent check.

## Validation

The reviewer parsed 15 cuts, 39 workstreams and 134 unique tickets; Cut 15 had
8 workstreams and 16 tickets. Every ticket and workstream dependency resolved,
`git diff --check` was clean and no product file differed from `f262e77a`.

