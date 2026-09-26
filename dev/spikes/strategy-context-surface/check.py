"""From repo root: R_BIN=/path/to/R python dev/spikes/strategy-context-surface/check.py."""
import difflib
import os
from pathlib import Path
import subprocess
import tempfile

here = Path(__file__).resolve().parent
root = here.parents[2]
scopes = ["R", "src", "tests", "NAMESPACE", "DESCRIPTION", "man", "inst/design"]
def scope_state():
    return tuple(subprocess.check_output(["git", *args, "--", *scopes], cwd=root)
                 for args in (["diff", "HEAD", "--binary"], ["status", "--porcelain"]))
before = scope_state()
expected = (here / "observations.csv").read_text().splitlines(keepends=True)
with tempfile.TemporaryDirectory() as directory:
    for mode in ("normal", "gut"):
        out = Path(directory) / mode
        command = [os.environ.get("R_BIN", "R"), "--vanilla", "--slave", "-f",
                   str(here / "probe.R"), "--args", str(out)]
        if mode == "gut":
            command.append("gut")
        subprocess.run(command, cwd=root, check=True)
        actual = (out / "observations.csv").read_text().splitlines(keepends=True)
        delta = "".join(difflib.unified_diff(expected, actual, "recorded", mode))
        if mode == "normal":
            assert not delta, delta
        else:
            assert delta and '"membership","member_allocation"' in delta, delta
            print(delta, end="")
assert before == scope_state(), "Probe changed package or design scope"
print("Recorded observations reproduced; gutted reservation detected; scope unchanged.")
