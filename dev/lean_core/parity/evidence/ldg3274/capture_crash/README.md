# The FIFO capture crash (LDG-3274, 2026-11-27)

## What happened

FIFO captures run on the pinned source archive
(`slice5-scratch/pin-archive`, d5b3a151). The first captures of the day
started at about 08:26, several processes at once, on a fresh archive with
no built DLL. Each process loaded the source with `pkgload::load_all()`,
and so each compiled and linked `src/ledgr.dll` into the same folder at
the same moment.

The object files came out identical. The interleaved links, however, left
the DLL's `.pdata` broken. `.pdata` is the x64 function table that Windows
searches to unwind the stack. In the broken DLL, 329 entries are duplicated
and as many functions have no entry.

Normal computation never reads that table. An R error raised from C++ does:
cpp11 longjmps and then throws, and Windows walks the C++ frames. At a
frame with no entry, Windows stops the process with STATUS_BAD_STACK
(0xC0000028) and prints nothing. Git Bash reports the exit as 127.

Two captures died this way (`../fifo_captureA_crashed.log`,
`../fifo_captureB_crashed.log`). An earlier repro died at "compiled spot
FIFO validates scalar state argument types". The cause was first misread as
duckdb 2.0.1 drift and as the compiled kernel. On that reading,
fifo_capture_tests.R skipped that test (48942f66). The skip is withdrawn in
ec40f6d7.

## Evidence

The probe is `minimal4.R`. It loads a source tree with `load_all()` and
raises the native type-check refusal of `ledgr_cpp_spot_fifo_batch()`
three times in one process. `launch3.ps1` starts it through PowerShell and
records the raw Windows exit code. Every probe ran under duckdb 2.0.1 and
nanonext 1.10.4.

| file | DLL | result |
| --- | --- | --- |
| `r_archive.txt` | the 08:26 build | second refusal: exit 0xC0000028 |
| `r_rebuilt.txt` | one fresh build of the same tree, one process | three refusals, exit 0 |
| `r_race.txt` | a fresh `git archive d5b3a151` built by three processes at once (`race_load.R`) | second refusal: exit 0xC0000028 |
| `r_pinsrc.txt` | pin-src-d5b3a151, built 2026-11-16 | three refusals, exit 0 |
| `r_ws44.txt` | ws44, built 2026-11-26 with the same -O0 flags | three refusals, exit 0 |

The installed pin library (R CMD INSTALL) also survives three refusals.

`pdata.R` reads a DLL's `.pdata` and reports any entry out of order.

| file | DLL | entries | out of order |
| --- | --- | ---: | ---: |
| `pdata_0826_vs_rebuilt.txt` | 08:26 build | 4,254 | 329 |
| `pdata_0826_vs_rebuilt.txt` | rebuilt | 4,254 | 0 |
| `pdata_race_vs_rebuilt.txt` | race build | 4,254 | 1,467 |

The duplicate entries replace others, so the two builds do not hold the
same set of entries.

`objects_0826_vs_rebuilt.txt`: the three object files are byte-identical.
The DLLs differ in 31,401 bytes. Leaving out the PE timestamp and checksum,
every difference lies in `.pdata`. `.text` and `.xdata` are identical.

## Consequences

- duckdb 2.0.1 is not the cause, and neither is the compiled kernel.
- The release and the product are unaffected: a package install builds
  once.
- No reported number is affected:
  - gates, variants, the bridge and the timing smoke load the installed
    pin library;
  - the broken DLL computed with intact code, and only an error raised
    from C++ reached the missing entries.
- The captures in `..` rerun on the single rebuild, after `pdata.R`
  confirmed a clean table, and with every test run.
- Parallel jobs on a fresh source tree now build the DLL once, in one
  process, before they start.
