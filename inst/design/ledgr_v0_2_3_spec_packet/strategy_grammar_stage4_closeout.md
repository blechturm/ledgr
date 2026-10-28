# Stage 4 closeout

**RED: neither the initial prototype nor the requested local optimization clears the 5% timing gate.** Optimized Turtle takes 15.33 seconds against 14.53 seconds for the current context: +5.51% eager, +6.97% lazy. Both experiments stopped at their failed gate; no unfavorable runs were discarded. Initial code/evidence is preserved in `a38a24e0`; [optimization follow-up](optimization.md).

| Cold-read rule | Baseline / flat fills | Both feature modes |
| --- | ---: | --- |
| Monthly 60/40 | 91 / 91 | All native fill columns identical |
| SPY trend | 47 / 47 | Identical |
| Monthly momentum decile | 90 / 90 | Identical |
| Sleeve beside gold | 91 / 91 | Identical |
| Connors RSI-2 | 2,031 / 2,031 | Identical |
| Trailing stop | 58 / 54 | Named peak-definition change; removed state records also renumber event_seq |

**Definitions.** `peak_since_entry` is the highest finite decision close observed while the posted position is held, including today. It resets at the actual flat-to-held transition. Opening holdings start at the first run close; pre-run peaks are unavailable. The baseline also includes the pre-purchase decision close. Changing only that expression reproduces the flat strategy's nine economic fill columns. First moved sale: June 18, 2019 -> July 29, 2019, 347 shares. [Full differences](evidence/6_definition_diff.csv).

`days_since_exit` is zero in the full-exit fill session, then counts every declared open run session, including skipped decisions and nonmember days. Without a recorded exit it is Inf, including during the first held episode. The baseline's daily countdown gives equivalent re-entry decisions once peaks are aligned; monthly decision countdowns count a different unit. Native fills and sealed closes independently reproduce both facts on 1,045 daily and 47 monthly decisions. Updates use fixed-axis vector operations, without future data or an R loop over instruments.

| 300-stock workload | Optimized current -> eager median seconds | Eager overhead | Lazy overhead |
| --- | ---: | ---: | ---: |
| Momentum | 2.92 -> 3.00 | +2.74% | +4.24% |
| Momentr funnel | 4.11 -> 3.97 | -3.41% | +9.90% |
| Connors | 10.77 -> 10.78 | +0.09% | -0.19% |
| Turtle | 14.53 -> 15.33 | **+5.51%** | **+6.97%** |

[Initial timing](evidence/timing_summary.csv), [optimized timing](evidence/optimized/timing_summary.csv): High performance, inherited P-core mask 0xFFFF, one R process, three alternating pairs per mode, fresh run IDs. Each gate's 48 runs preserves complete wide-baseline fills. Clock: run plus native fill reads from the reused sealed stage-3 fixture; snapshot preparation is recorded separately. The adapter constructs the existing context before adding flat fields. Direct flat-context construction remains untested.

**Readability and checks.** Flat columns remove the reader split; the trailing rule drops handwritten memory. Prefer `within = ctx$buyable`: it names the ranking pool; column subsetting is correct but puts policy inside brackets; target-only refusal explains the problem too late. All three ran. Reserved names, unknown columns, missing keep/exit decisions and undecided leavers fail closed. Adjust discloses its total-equity default and supports the remaining-equity override. Lazy reads: 0 at creation, 1 after first access, still 1 after repetition; eager reads both declarations at creation.

The unchanged checker reproduces every non-timing CSV after optimization and catches all three guts. [Inventory](inventory.md); [six-strategy cold read](cold_read_v2.md). Open: direct construction/performance, acceptance of the peak definition, and resume/storage semantics. The cold-read momentum wording follows the executed decile baseline. No merge or push.