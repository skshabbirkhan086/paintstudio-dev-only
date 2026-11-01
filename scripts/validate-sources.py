#!/usr/bin/env python3
"""Zero-cloud static validation: JSON + YAML parse + enforce Dev-only paths and markers."""
from pathlib import Path
import json
import yaml
root=Path(__file__).resolve().parents[1]
errors=[]; examined=0
for p in root.rglob('*'):
    if not p.is_file() or '.git' in p.parts: continue
    if p.name in {'qa.json','prod.json'} or '/overlays/qa/' in str(p) or '/overlays/prod/' in str(p):
        errors.append(f'Forbidden non-Dev resource: {p}')
    try:
        if p.suffix=='.json': json.loads(p.read_text());examined+=1
        if p.suffix in {'.yaml','.yml'}: list(yaml.safe_load_all(p.read_text()));examined+=1
    except Exception as exc: errors.append(f'{p}: {exc}')
if errors: raise SystemExit('\n'.join(errors))
print(f'Parsed {examined} JSON/YAML files. No QA/Prod resource files. Remember: this is not Terraform/Helm/.NET validation.')
