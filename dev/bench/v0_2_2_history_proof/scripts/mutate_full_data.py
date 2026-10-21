import shutil, subprocess, os, sys
src = sys.argv[1]; work = sys.argv[2]; checker = sys.argv[3]
muts = [
 ("F1 bars count changed", "census__identity.csv", '"bars","5481906"', '"bars","5481905"'),
 ("F2 snapshot hash changed", "census__identity.csv", '"snapshot_hash","1f53c09897dfc39c02cde728077be65f8c3b1819e5224eb80786b9e5d30e2b5a"', '"snapshot_hash","0f53c09897dfc39c02cde728077be65f8c3b1819e5224eb80786b9e5d30e2b5a"'),
 ("F3 segment-guard breach", "census__segment_guard.csv", '"changing","membership",1166,1166,967091,677446,1160,581,0.7005,1,0.25,0', '"changing","membership",1166,1166,967091,677446,1160,581,0.7005,1,0.25,1'),
 ("F4 unexpected stop", "full__run.csv", '"status","DONE"', '"status","STOPPED"'),
 ("F5 pulse count changed", "changing__run.csv", '"pulse_count","7213"', '"pulse_count","7212"'),
 ("F6 late-known fact appears", "census__facts.csv", '"lifetime",829,751,78,2,0,0,0,0', '"lifetime",829,751,78,2,1,1,1,0'),
 ("F7 failed stage", "steps.csv", '"full","full",0,', '"full","full",1,'),
]
for name, f, old, new in muts:
    d = os.path.join(work, "data")
    if os.path.exists(d): shutil.rmtree(d)
    shutil.copytree(src, d)
    p = os.path.join(d, f); t = open(p, encoding="utf-8").read()
    if t.count(old) != 1: print(name, "SPEC_ERROR", t.count(old)); continue
    open(p, "w", encoding="utf-8", newline="").write(t.replace(old, new))
    r = subprocess.run(["Rscript", checker, d], capture_output=True, text=True)
    print(name, "DETECTED" if r.returncode != 0 else "SURVIVED", (r.stdout.strip().splitlines() or [""])[-1][:100])
