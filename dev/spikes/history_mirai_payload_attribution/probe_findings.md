# E0 probe findings

The smallest public-path probe used an availability-active synthetic snapshot
with eight instruments, 87 pulses and two candidates. It ran
`ledgr_sweep(..., workers = 1)` and intercepted only the private task builder;
candidate evaluation was unchanged.

Each actual task serialized to about 332 KB. Eighteen of its 28 fields were
identical between candidates: experiment value data, bars by instrument, bar
matrices and views, pulse axes, metric kernel, retention, feature projection,
identity values, availability data and configuration, execution opportunities,
and corporate-action rows. Ten small fields varied by candidate.

The observed failure risk is therefore concrete: current parallel submission
passes the whole task to every `mirai()` call, so candidate-invariant prepared
data is serialized with every candidate. The probe does not say that this is
the cause of H1's full memory peak. The spike must attribute transport and
retention before Session E selects a representation.
