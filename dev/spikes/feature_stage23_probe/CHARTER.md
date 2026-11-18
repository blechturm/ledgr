# Feature engine stages 2-3: measuring step

Input to the stages 2-3 RFC seed. The accepted feature-engine seed
(`inst/design/rfc/rfc_feature_engine_v0_2_3_seed_v2.md`, Section 7 answer 1)
says that RFC measures on the cleaned path; this probe does that. It binds
nothing and changes nothing in `R/`.

**Code measured.** release/v0.2.3 with R/ at `68b505b9` (Cut 22 stage 1 and
Cut 23), installed with `dev/feature_parity/install_arm.R`.

**Question.** On the cleaned feature path, how much preparation time could a
stage-3 direct path remove on the cells a conservative gate admits, and how
many cells does that gate admit on public substrates?

**Prerequisite.** Where the feature time goes now (`steps.R`), with the
per-instrument calculation split into the parts a direct path replaces.

**Kill condition.** If the measured ceiling saving is under 10 percent of the
compute call on every wide cell (500 x 1,260 and 1,166 x 252, run and
sweep), stage 3 does not justify an RFC section: the seed then proposes stage
2 alone. A direct-path value that differs from the general path on an
admitted cell stops the probe until the gate is corrected.

**Runnable core.** `common.R`: the gate predicate (conservative and relaxed)
and a direct calculation (one adapter call per admitted cell, segment record
from the block). `direct.R` checks it cell by cell against the package's
own compute call and times both; `gate_count.R` counts and checks admitted
cells on public substrates; `ttr_inventory.R` lists the R/ sites that name
TTR (stage 2 input). `check.R` reruns the deterministic evidence, diffs it,
runs the gut (gate without its full-coverage clause), and guards package
scope by hashing.

**Out of scope.** The real-data (H1) gate count: it needs the private
aggregate route and the maintainer's go. Any R/ change, compiled code, a
matrix entry point, the sweep-architecture questions.
