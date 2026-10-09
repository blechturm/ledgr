#!/bin/sh
# Per-ticket byte-identity ladder (Cut 11 Workstream 22).
#
#   sh ladder.sh <worktree> <out_dir> <first_predecessor_record> <ticket>=<commit> ...
#
# Checks out each commit in order in a clean precompiled worktree, records the
# fixture lane and compares the record with its predecessor's (the first with
# the given record). Writes <out_dir>/ladder.csv (ticket, commit, verdict).
# A record's work databases are removed once recorded; a predecessor record is
# removed once its successor compared identical.
set -u
here=$(cd "$(dirname "$0")" && pwd)
tree=$1; out=$2; prev=$3; shift 3
rscript="/c/Program Files/R/R-4.6.1/bin/x64/Rscript.exe"
mkdir -p "$out"
echo "ticket,commit,verdict" > "$out/ladder.csv"
first=$prev
for pair in "$@"; do
  ticket=${pair%%=*}; commit=${pair#*=}
  git -C "$tree" checkout -q --detach "$commit" || exit 1
  rec="$out/$ticket"
  "$rscript" "$here/run_record.R" "$tree" "$rec" > "$out/$ticket.log" 2>&1
  rm -rf "$rec/work"
  if "$rscript" "$here/check_record.R" "$prev" "$rec" > "$out/$ticket.check" 2>&1; then
    verdict=identical
  else
    verdict=different
  fi
  echo "$ticket,$commit,$verdict" >> "$out/ladder.csv"
  tail -n 2 "$out/$ticket.check"
  [ "$verdict" = identical ] && [ "$prev" != "$first" ] && rm -rf "$prev"
  prev=$rec
done
cat "$out/ladder.csv"
