from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[1]
errors = []
sources = sorted((root / "lib").rglob("*.dart"))
for source in sources:
    text = source.read_text()
    relative = source.relative_to(root).as_posix()
    for pattern in [
        r"\bsetState\s*\(",
        r"\b(?:StatefulWidget|ConsumerStatefulWidget|StatefulBuilder|ValueNotifier|ChangeNotifier|StreamBuilder|FutureBuilder|ValueListenableBuilder|useState|useReducer)\b",
        r"package:(?:flutter_bloc|bloc|get_it)/",
        r"\b(?:StateProvider|StateNotifierProvider|ChangeNotifierProvider)\b",
    ]:
        if re.search(pattern, text):
            errors.append(f"{relative}: forbidden application state API: {pattern}")
    imports = re.findall(r"(?:import|export)\s+['\"]([^'\"]+)['\"]", text)
    for imported in imports:
        if "/domain/" in relative:
            if imported.startswith(("package:flutter/", "package:firebase_", "package:cloud_firestore/", "package:hooks_riverpod/", "package:flutter_riverpod/")):
                errors.append(f"{relative}: domain depends on a framework: {imported}")
            resolved = (source.parent / imported).resolve().as_posix() if not imported.startswith("package:") else imported
            if "/data/" in resolved or "/presentation/" in resolved:
                errors.append(f"{relative}: domain depends on an outer layer: {imported}")
        if "/data/" in relative and "/presentation/" in (source.parent / imported).resolve().as_posix():
            errors.append(f"{relative}: data depends on presentation: {imported}")
        if "/presentation/" in relative and "/providers/" not in relative:
            resolved = (source.parent / imported).resolve().as_posix()
            if "/data/" in resolved or imported.startswith(("package:firebase_", "package:cloud_firestore/")):
                errors.append(f"{relative}: widget bypasses domain/provider boundaries: {imported}")
for old in ["lib/data", "lib/domain", "lib/presentation", "lib/core/di"]:
    if (root / old).exists():
        errors.append(f"Legacy directory remains: {old}")
spec = (root / "pubspec.yaml").read_text()
if re.search(r"^\s+(?:flutter_bloc|bloc|get_it):", spec, re.M):
    errors.append("Legacy state/DI dependency remains")
if errors:
    print("\n".join(errors))
    sys.exit(1)
print(f"Architecture checks passed for {len(sources)} Dart files; no application setState or legacy state APIs.")
