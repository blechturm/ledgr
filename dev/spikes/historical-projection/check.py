"""Rerun existing-code evidence, remove one path, and diff. No package edits.

python check.py IMPLEMENTATION_REPO [--rscript PATH]
"""
import argparse
import difflib
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("implementation_repo", type=Path)
parser.add_argument("--rscript", default="Rscript")
args = parser.parse_args()
here = Path(__file__).resolve().parent
implementation = args.implementation_repo.resolve()
design = here.parents[2]
scope = ["R", "src", "tests", "NAMESPACE", "DESCRIPTION", "man", "inst/design"]


def git(repo, *arguments):
    return subprocess.check_output(["git", "-C", str(repo), *arguments])


def snapshot(repo):
    # Transient mutation guard, not a provenance registry or identity scheme.
    extra = git(repo, "ls-files", "--others", "--exclude-standard", "--", *scope)
    return (git(repo, "diff", "--binary", "HEAD", "--", *scope),
            {name: (repo / name).read_bytes() for name in extra.decode().splitlines()})


before = {repo: snapshot(repo) for repo in {implementation, design}}
expected = (here / "observations.csv").read_text().splitlines(keepends=True)
try:
    with tempfile.TemporaryDirectory(prefix="ledgr-projection-check-") as temp:
        for mode in ("normal", "gut"):
            output = Path(temp) / mode
            command = [args.rscript, str(here / "probe.R"), str(implementation), str(output)]
            if mode == "gut":
                command.append("gut")
            subprocess.run(command, check=True)
            actual = (output / "observations.csv").read_text().splitlines(keepends=True)
            diff = list(difflib.unified_diff(expected, actual,
                                           fromfile="recorded", tofile=mode))
            if mode == "normal" and diff:
                raise SystemExit("".join(diff))
            if mode == "gut":
                if not diff:
                    raise SystemExit("Removing raw projection access changed no evidence")
                print("".join(diff), end="")
        print("Normal evidence reproduced; gutted access changed evidence.")
finally:
    for repo, original in before.items():
        if snapshot(repo) != original:
            raise SystemExit(f"Package/design scope changed during execution: {repo}")
