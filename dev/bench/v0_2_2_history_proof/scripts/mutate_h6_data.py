import shutil, subprocess, os, sys, gzip, csv, io
src = sys.argv[1]; work = sys.argv[2]; checker = sys.argv[3]
def edit_text(d, f, old, new):
    p = os.path.join(d, f); t = open(p, encoding="utf-8").read()
    if t.count(old) < 1: return False
    open(p, "w", encoding="utf-8", newline="").write(t.replace(old, new, 1)); return True
def inflate_samples(d, tag, factor, role="parent"):
    p = os.path.join(d, "samples", tag + ".csv.gz")
    rows = list(csv.DictReader(gzip.open(p, "rt")))
    for r in rows:
        if r["role"] == role:
            r["wset_bytes"] = str(float(r["wset_bytes"]) * factor)
            r["private_bytes"] = str(float(r["private_bytes"]) * factor)
    with gzip.open(p, "wt", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
    return True
muts = [
 ("H1 single-run candidate parent peaks x1.9 in two repeats", lambda d: inflate_samples(d, "run_cand_r1", 1.9) and inflate_samples(d, "run_cand_r2", 1.9)),
 ("H2 sweep candidate daemons x8 in two repeats", lambda d: inflate_samples(d, "sweep_cand_r1", 8, "daemon") and inflate_samples(d, "sweep_cand_r2", 8, "daemon")),
 ("H3 sweep candidate parent x6 in two repeats", lambda d: inflate_samples(d, "sweep_cand_r1", 6) and inflate_samples(d, "sweep_cand_r3", 6)),
 ("H4 current-dispatch final equity differs", lambda d: edit_text(d, "transport_current__sweep_candidates.csv", '"14153680.996000"', '"14153680.997000"')),
 ("H5 sequential execution seed differs", lambda d: edit_text(d, "transport_sequential__sweep_candidates.csv", '"578231579"', '"578231578"')),
 ("H6 a candidate run repeat differs", lambda d: edit_text(d, "run_cand_r2__run.csv", '"fill_rows","8798"', '"fill_rows","8797"')),
 ("H7 a failed step", lambda d: edit_text(d, "steps.csv", '"sweep_cand_r3","sweep","cand","staged",0,', '"sweep_cand_r3","sweep","cand","staged",1,')),
 ("H8 a missing repeat", lambda d: edit_text(d, "steps.csv", '"run_base_r3"', '"run_base_rX"')),
]
for name, fn in muts:
    d = os.path.join(work, "data")
    if os.path.exists(d): shutil.rmtree(d)
    shutil.copytree(src, d)
    if not fn(d): print(name, "SPEC_ERROR"); continue
    r = subprocess.run(["Rscript", checker, d], capture_output=True, text=True)
    out = (r.stdout + r.stderr).strip().splitlines()
    print(name, "DETECTED" if r.returncode != 0 else "SURVIVED", " | ".join(l for l in out if l.startswith("- ") or "Error" in l)[:160])
