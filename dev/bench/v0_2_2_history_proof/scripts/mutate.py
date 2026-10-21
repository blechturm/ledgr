"""Mutation driver for Workstream 44 phase A.

Usage: python mutate.py <copy_root> <spec.json> <out.csv> [ids...]

Each spec entry: {"id", "desc", "file", "old", "new", "test_files": [...],
"blocks": [...]}. The old string must occur exactly once in the file. The
file is restored byte for byte after each run. A block "fails" when it has
failed expectations or an error.
"""
import csv
import json
import os
import subprocess
import sys

root, spec_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
only = set(sys.argv[4:])
specs = json.load(open(spec_path, encoding='utf-8'))
rscript = 'Rscript'
runner = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'block_runner.R')
rows = []
for spec in specs:
    if only and spec['id'] not in only:
        continue
    path = os.path.join(root, spec['file'])
    original = open(path, 'rb').read()
    text = original.decode('utf-8')
    nl = '\r\n' if '\r\n' in text else '\n'
    old = spec['old'].replace('\n', nl)
    new = spec['new'].replace('\n', nl)
    count = text.count(old)
    if count != 1:
        rows.append([spec['id'], spec['desc'], spec['file'], 'SPEC_ERROR match=%d' % count, ''])
        print(spec['id'], 'SPEC_ERROR', count, flush=True)
        continue
    try:
        open(path, 'wb').write(text.replace(old, new).encode('utf-8'))
        cmd = [rscript, runner, root, ','.join(spec['blocks'])] + spec['test_files']
        proc = subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8', errors='replace')
        result = [l for l in proc.stdout.splitlines() if l.startswith('BLOCK|')]
    finally:
        open(path, 'wb').write(original)
    detail = ';'.join(r[len('BLOCK|'):] for r in result)
    failed = [r.split('|')[1] for r in result if r.split('|')[2] != 'pass']
    verdict = 'DETECTED' if all(b in failed for b in spec.get('must_fail', spec['blocks'])) and failed else 'SURVIVED'
    if not result:
        verdict = 'RUN_ERROR'
        detail = (proc.stdout[-400:] + proc.stderr[-400:]).replace('\n', ' ')
    rows.append([spec['id'], spec['desc'], spec['file'], verdict, detail])
    print(spec['id'], verdict, detail, flush=True)
with open(out_path, 'a', newline='', encoding='utf-8') as f:
    w = csv.writer(f)
    for r in rows:
        w.writerow(r)
