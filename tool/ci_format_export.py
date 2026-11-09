"""Emit only changed Dart sources after formatting for remote review tooling."""
import json
import subprocess
from pathlib import Path

paths = subprocess.check_output(["git", "diff", "--name-only"], text=True).splitlines()
files = {p: Path(p).read_text() for p in paths if p.endswith(".dart") or p == "pubspec.lock"}
print("FORMATTED_SOURCES=" + json.dumps(files, separators=(",", ":")))
