# Protocol cut10-pulse-inspection-1

This is the Cut 10 paired gate for LDG-3198 and LDG-3199. It times the two
public current-pulse inspection helpers over one real 600-instrument,
three-feature `ledgr_pulse_snapshot()` context. Snapshot construction, feature
preparation and pulse construction are outside the clock. Each arm runs in a
fresh process installed from its pinned commit by the shared timing harness.

Eight alternating pairs time repeated calls long enough to clear the Windows
timer quantum. The work string pins output dimensions and numeric content.
The long-helper candidate/base bound is 0.40; the wide-helper bound is 0.25.
These are implementation materiality gates, not public callback-cost promises.

