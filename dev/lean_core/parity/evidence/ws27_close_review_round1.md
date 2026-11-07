CHANGES_REQUIRED

One evidence finding under question 3; no supported-operation kernel mismatch found.

**Generated-stream coverage in LDG-3213 is not supported by its cited record.**

Location: [tickets.yml, LDG-3213, Acceptance 1 evidence](C:/Users/maxth/ledgr-wt/ws27-close/inst/design/ledgr_v0_2_3_spec_packet/tickets.yml:4188), citing `fifo_streams.csv`.

The ticket claims 18 generated streams, **2,240 steps and 125 refusals**. The registered generator and committed CSV establish **18 streams, 1,560 steps and 181 refusals**. Thus the cited coverage overstates executed steps by 680 and gives the wrong refusal total.

Executed witness: [probe_evidence.R](C:/Users/maxth/ledgr-wt/ws27-close-out/probe_evidence.R) runs every registered stream against the installed pin, checks that every stream's step, row and refusal counts exactly reproduce the committed CSV, and writes [streams_actual.csv](C:/Users/maxth/ledgr-wt/ws27-close-out/streams_actual.csv). Its [output](C:/Users/maxth/ledgr-wt/ws27-close-out/probe_evidence.txt) reports 1,560 steps, 10,461 rows and 181 refusals. [probe_core.txt](C:/Users/maxth/ledgr-wt/ws27-close-out/probe_core.txt) independently confirms all 1,560 steps match with debug off and on. Neither separate debug runs nor input rows account for the ticket's 2,240-step total.

Correct the ticket's empirical totals to the reproduced record, or supply runnable evidence establishing the claimed additional steps. This finding concerns numerical acceptance evidence, not FIFO behavior.

Reproduction:

```powershell
& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" C:/Users/maxth/ledgr-wt/ws27-close-out/probe_evidence.R
```

Reviewed `4b835e236a7eb93a56174dd4429a1e1b034b0b4c` against installed `d5b3a151`, Windows/R 4.6.1. Additional checks matched 2,935 captured calls in both modes, including all 37 unmocked kernel refusals and all ten workload sources; all 39 input refusals matched with debug on; 2,500 extreme-value cases using supported operations matched in both modes. All six registered mutations were detected. The saved gate passes the current checker, its FIFO overlay matches the reviewed source, and the source has 343 code lines. Probe scripts and outputs are in this output folder. No worktree files were edited; no timing windows or test-suite captures were run.
