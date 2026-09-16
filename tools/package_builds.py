"""Package native exports only; do not include caches, source fonts or local saves."""
from __future__ import annotations

import hashlib
import json
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    artifacts = ROOT / "artifacts"
    artifacts.mkdir(exist_ok=True)
    outputs = []
    for platform, executable in (("windows", "OfficeMischief.exe"), ("linux", "OfficeMischief.x86_64")):
        directory = ROOT / "build" / platform
        binary = directory / executable
        if not binary.is_file() or binary.stat().st_size < 1_000_000:
            raise RuntimeError(f"Native export is missing or suspiciously small: {binary}")
        archive = artifacts / f"OfficeMischief-{platform}-x64.zip"
        with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=1) as output:
            for path in sorted(directory.iterdir()):
                if path.is_file():
                    output.write(path, path.name)
        outputs.append({"file": archive.name, "size": archive.stat().st_size,
                        "sha256": hashlib.sha256(archive.read_bytes()).hexdigest()})
    (artifacts / "build_manifest.json").write_text(json.dumps(outputs, indent=2), encoding="utf-8")
    print(json.dumps(outputs, indent=2))


if __name__ == "__main__":
    main()
