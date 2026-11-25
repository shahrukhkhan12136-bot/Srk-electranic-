#!/usr/bin/env python3
"""Restore the committed founder WebP asset from its base64 transport file."""
from base64 import b64decode
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = root / "packages/srk_mobile_core/assets/founder.webp.b64"
target = root / "packages/srk_mobile_core/assets/founder(2).webp"

if not source.is_file():
    raise SystemExit(f"Missing source asset: {source}")
encoded = "".join(source.read_text(encoding="ascii").split())
data = b64decode(encoded, validate=True)
if not data.startswith(b"RIFF") or data[8:12] != b"WEBP":
    raise SystemExit("Founder asset failed WebP signature validation.")
target.parent.mkdir(parents=True, exist_ok=True)
target.write_bytes(data)
print(f"Prepared verified WebP asset ({len(data)} bytes).")
