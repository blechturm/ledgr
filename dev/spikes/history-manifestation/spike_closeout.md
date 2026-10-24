# History manifestation spike closeout

**Terminal outcome:** GREEN. Charter v2 asked whether a prepared
finite-observation summary permits exact matrix and wide-frame manifestation
at no more than 0.5 ms median for 500 instruments by 252 sessions, without a
value rescan, digest, excessive copying or non-linear growth. The recorded
medians are 0.427 and 0.405 ms and every detecting gate passes.

## What ran

The public APIs built one availability-aware snapshot with 1,166 instruments,
1,260 sessions, complete point-in-time membership and deterministic sparse bar
gaps. At the last public pulse, the runner compared the current history reader
with one direct candidate over the same substrate values and canonical carry
answers. It recorded 50 x 252, 500 x 252, 1,166 x 252 and 500 x 1,260 shapes.

The benchmark ran under the repository's Windows reference method: R 4.6.1,
High performance power plan and process affinity `0xFFFF`. The checker rebuilt
the public fixture in scratch, reproduced the deterministic fields and parity,
reapplied every gate and confirmed that no product or design file changed.

| Shape | Current rich read | Matrix | Wide frame |
| --- | ---: | ---: | ---: |
| 50 x 252 | 5.206 ms | 0.075 ms | 0.075 ms |
| 500 x 252 | 24.198 ms | 0.427 ms | 0.405 ms |
| 1,166 x 252 | 44.103 ms | 1.107 ms | 0.992 ms |
| 500 x 1,260 | 97.800 ms | 2.200 ms | 2.154 ms |

All candidate reads use zero digests. Numeric values, dimensions, dimnames and
selected IDs match the current public reader in all four cases. Matrix and
frame allocate about two returned-payload copies at the decision shape. Their
growth exponents are 0.861 and 0.849. Holding the 500 x 252 request fixed while
expanding its source from 252 to 1,260 sessions changes the raw-slice median by
0.037 ms, inside the 0.1 ms gate.

## What was learned

Final R manifestation is cheap when it receives the right prepared answers.
The expensive design is the eager reconstruction and sealing of rich evidence,
not matrices or data frames themselves. One collapse-native detail matters:
`collapse::mrtl()` manifests the frame directly from instrument rows, avoiding
the transpose and its extra payload allocation.

The v1 charter did its job. Its candidate rescanned every returned value for
completeness and narrowly missed the raw-copy stop. A follow-up probe isolated
prepared finite counts; v2 then removed that scan and met the stricter 0.5 ms
target. This does not authorize a dense count plane: its storage and RAM cost
remain a design input.

## What the specification may consume

The focused amendment may bind sibling matrix/frame manifestations, the
verified-substrate trust boundary, zero transient hashes, direct row-to-column
frame construction, one prepared selection summary and runtime/allocation that
scale with returned cells. A reasonable registered implementation gate is at
most 0.75 ms median for each output at 500 x 252, exact parity, zero digest
calls, at most 2.5 payload-copy allocations, a 0.65-1.30 growth exponent and no
more than 0.1 ms fixed-window sensitivity to unrequested source history. The
0.75 ms implementation margin is deliberately wider than this spike's 0.5 ms
research target.

The amendment still has to decide compact reason provenance and a
memory-bounded finite-count representation. It may not claim that this spike
proved feature and late-knowledge paths that it did not run.
