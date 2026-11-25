#!/usr/bin/env python3
"""Collect the locked engine's third-party license and notice files."""
import json
from pathlib import Path
import sys


metadata = json.loads(Path(sys.argv[1]).read_text())
notices = []
for package in sorted(metadata['packages'], key=lambda item: (item['name'], item['version'])):
    if package['name'] == 'librespeed-cli':
        continue
    root = Path(package['manifest_path']).parent
    files = {path for path in root.rglob('*')
             if path.name.upper().startswith(('LICENSE', 'COPYING', 'NOTICE', 'UNLICENSE', 'AUTHORS'))
             and path.is_file()}
    if package.get('license_file'):
        files.add(root / package['license_file'])
    if not files:
        raise ValueError(f"No license files found for {package['name']} {package['version']}")
    notices.append(f"\n{'=' * 72}\n{package['name']} {package['version']}\nLicense: {package['license']}\n")
    for path in sorted(files):
        notices.append(f"\n--- {path.relative_to(root)} ---\n")
        notices.append(path.read_text(encoding='utf-8'))
Path(sys.argv[2]).write_text(''.join(notices), encoding='utf-8')
