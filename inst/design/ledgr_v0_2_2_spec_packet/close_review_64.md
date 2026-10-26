# Workstream 64 close review

**Mode:** Type 1 with an independent input check  
**Range:** `946078d9..518a200f`  
**Reviewer:** clean-context Claude Opus CLI  
**Verdict:** `CHANGES_REQUIRED`

The two declarations close a real gap: explicit dates snap forward without a
same-period boundary and therefore cannot directly express a weekday or
numbered month-day recurrence. The implementation correctly extends the
existing validator, compiler and generic carriers. It adds no second scheduler,
format bump or pulse-time calendar work.

The reviewer found six bounded evidence gaps rather than a product-design
defect:

1. LTB-0511 did not exercise `ledgr_run_strategy()` recovery for either new
   declaration.
2. Its run/sweep comparison used final equity from a constant target, which
   could remain equal under different decision masks.
3. The two exact public display lines were neither shown by executable teaching
   nor pinned as public output.
4. Closed-Friday behavior was described in prose but not executed in the
   article.
5. The walk-forward carrier checked the normalized argument but not the
   resolved hash.
6. The shared reference topic contained both aliases, but `_pkgdown.yml` and
   its detector named only the parent topic.

Acceptance items 1 through 4 and 6 passed. Item 5 was partial because of items
1, 2 and 5 above. Item 7 was partial because of items 3, 4 and 6. The compiler
logic, validation, normalized identity, literal old pins, contracts, NEWS,
NAMESPACE, export lock and seven-shape walk were clean. A public probe also
confirmed that both new declarations already survived recovery and printed the
correct labels; the findings require durable detecting evidence for those
behaviors.
