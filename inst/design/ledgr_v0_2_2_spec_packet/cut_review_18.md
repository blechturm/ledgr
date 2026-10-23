# Cut 18 review: residual performance and release evidence

**Mode:** independent clean-context Type 1 cut review with an input and
necessity check.

**Draft:** `8a75e6d0`

**Verdict:** `CHANGES_REQUIRED`

The cut is necessary and its four-workstream order is sound. Existing evidence
supports the four growth defects, the expensive explain reader, the exhausted
fast lane and the unresolved memory attribution. No item requires a Type 2
decision before implementation, and speculative telemetry, scheduler and
shared-memory changes remain behind explicit escalation gates.

Required corrections applied before acceptance:

1. LDG-3092 now says that only LTB-0393's broken tracer capture changes and
   retains the existing placement and sequential assertions.
2. LDG-3093 uses an appropriate vectorized POSIXct formatting description and
   gives each of its four repairs an independent three-scale growth and exact
   parity proof.
3. LDG-3094 fixes the H1 measurement design: three alternating fresh-process
   pairs, declared cache state, clock boundary, heap method and median.
4. LDG-3095 makes profiling non-mutating and requires a maintainer amendment
   naming any candidate before implementation. Every measured cost now needs
   one explicit disposition and the phase/profile reconciliation has a numeric
   tolerance.
5. LDG-3096 replaces "where affordable" with fixed repeat rules and preserves
   ownership of the accepted `seed = NULL` RNG obligation if a sweep backend
   change is promoted.
6. LDG-3097 names both release-only cases, and LDG-3098 uses the benchmark
   manual's four measured phases with reconciliation to the outer wall.

After these patches every macro WS8 route and release-definition-of-done item
has an owner, an accepted citation or an explicit exclusion and trigger.
