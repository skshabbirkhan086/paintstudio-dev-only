#!/usr/bin/env python3
"""Change only the image newTag in one Kustomize overlay, without extra PyPI dependencies."""
from pathlib import Path
import re
import sys

if len(sys.argv) != 3:
    raise SystemExit("usage: update_kustomize_tag.py path/to/kustomization.yaml sha_tag")
path = Path(sys.argv[1])
tag = sys.argv[2]
if not re.fullmatch(r"[a-f0-9]{12}", tag):
    raise SystemExit("tag must be a 12 character git SHA")
content = path.read_text()
updated, count = re.subn(r"(?m)^(\s*newTag:\s*).+$", lambda m: m.group(1) + tag, content)
if count != 1:
    raise SystemExit(f"Expected exactly one newTag, found {count}")
path.write_text(updated)
