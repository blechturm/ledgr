# E1 public-path probe findings

The probe ran `ledgr_sweep()` on E0's smoke fixture, captured the actual
candidate tasks from the production task builder, and touched no product code.

All eight observed large immutable fields accepted by the E0 boundary can be
shared by mori 0.2.2. Each root and independently mapped value reports
`mori::is_shared()`, each mapped value is `identical()` to the production task
field, and each XDR serialization is smaller than its ordinary counterpart.
At this small shape the reductions range from 1,132 to 748 bytes for an empty
corporate-action frame and from 84,288 to 136 bytes for static bar views.

A write to a mapped numeric bar vector produced a private ordinary vector;
the mapped source stayed unchanged. The runner therefore must distinguish
read-only task evaluation from any accidental materialization. This probe says
nothing about process-tree memory, retained promises, returned results, or
cleanup after failures; those belong to the binding runner.

