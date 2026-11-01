#!/usr/bin/env python3
"""Run from project bundle root: python3 scripts/configure-dev.py ORG 1.2.3.4/32
Requires AWS CLI with the intended Dev account selected.
"""
from pathlib import Path
import subprocess, json, sys, re
root=Path(__file__).resolve().parents[1]
if len(sys.argv)!=3 or not re.fullmatch(r'[A-Za-z0-9_.-]+',sys.argv[1]) or not re.fullmatch(r'(?:\d{1,3}\.){3}\d{1,3}/32',sys.argv[2]):
    raise SystemExit('Usage: python3 scripts/configure-dev.py GITHUB_ORG YOUR_PUBLIC_IP/32')
org,cidr=sys.argv[1:]
account=subprocess.check_output(['aws','sts','get-caller-identity','--query','Account','--output','text'],text=True).strip()
assert re.fullmatch(r'\d{12}',account)
for rel in ['paintstudio-app/Jenkinsfile',
            'paintstudio-infra-live/main.tf',
            'paintstudio-gitops/applications/dev.yaml',
            'paintstudio-gitops/overlays/dev/kustomization.yaml',
            'paintstudio-gitops/observability/fluent-bit-values.yaml']:
    path=root/rel
    source=path.read_text().replace('YOUR_ORG',org).replace('REPLACE_ACCOUNT_ID',account)
    path.write_text(source)
p=root/'paintstudio-infra-live/payloads/dev.json'
d=json.loads(p.read_text());d['eks']['public_access_cidrs']=[cidr]
p.write_text(json.dumps(d,indent=2)+'\n')
print(f'Configured Git organization={org}, AWS account={account}, EKS public access={cidr}.')
print('Review git diff. Do not commit credentials or personal secrets. Change the placeholder OpenSearch admin ARN before enabling it.')
