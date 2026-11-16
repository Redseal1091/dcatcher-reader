#!/usr/bin/env python3
"""
Downloads pinned upstream Mihon source-api and core/common network/preference/util components
for the :tachiyomi-runtime library module.
Pinned commit: e588e04359fe1058206a2cbac1b01018ad787359 (Apache-2.0)
"""

import json
import os
import sys
import urllib.request
from pathlib import Path

PINNED_COMMIT = "e588e04359fe1058206a2cbac1b01018ad787359"
REPO = "mihonapp/mihon"
RAW_BASE = f"https://raw.githubusercontent.com/{REPO}/{PINNED_COMMIT}"
API_TREE = f"https://api.github.com/repos/{REPO}/git/trees/{PINNED_COMMIT}?recursive=1"

SCRIPT_DIR = Path(__file__).resolve().parent
TARGET_SRC = SCRIPT_DIR / "src" / "main" / "kotlin"
TARGET_LICENSES = SCRIPT_DIR / "LICENSE"

HEADERS = {"User-Agent": "DCatcher-Runtime-Importer"}

def fetch_url(url: str) -> bytes:
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=60) as resp:
        return resp.read()

def main():
    print(f"Fetching repository tree at {PINNED_COMMIT}...")
    tree_data = json.loads(fetch_url(API_TREE).decode("utf-8"))
    entries = tree_data.get("tree", [])

    # Filter files from source-api/src/main/kotlin and specific core/common targets
    source_api_prefix = "source-api/src/main/kotlin/"
    core_common_prefix = "core/common/src/main/kotlin/"

    explicit_targets = [
        "tachiyomi/core/common/util/lang/RxCoroutineBridge.kt",
        "tachiyomi/core/common/preference/Preference.kt",
        "tachiyomi/core/common/preference/PreferenceStore.kt",
        "tachiyomi/core/common/preference/AndroidPreference.kt",
        "tachiyomi/core/common/preference/AndroidPreferenceStore.kt",
        "tachiyomi/core/common/util/system/LogcatExtensions.kt",
    ]

    files_to_download = []
    for entry in entries:
        if entry["type"] != "blob":
            continue
        path = entry["path"]
        if path.startswith(source_api_prefix) and path.endswith(".kt"):
            rel_path = path[len(source_api_prefix):]
            files_to_download.append((path, rel_path))
        elif path.startswith("core/common/src/main/kotlin/eu/kanade/tachiyomi/network/") and path.endswith(".kt"):
            rel_path = path[len("core/common/src/main/kotlin/"):]
            files_to_download.append((path, rel_path))
        elif path.startswith(core_common_prefix):
            rel_path = path[len(core_common_prefix):]
            for target in explicit_targets:
                if rel_path == target:
                    files_to_download.append((path, rel_path))
            if any(name in rel_path for name in ["DeviceUtil", "WebViewUtil", "ToastExtensions"]):
                files_to_download.append((path, rel_path))
        elif any(name in path for name in ["DeviceUtil", "WebViewUtil", "ToastExtensions"]) and path.endswith(".kt"):
            rel_path = "eu/kanade/tachiyomi/util/system/" + Path(path).name
            files_to_download.append((path, rel_path))

    # De-duplicate
    files_to_download = list(dict.fromkeys(files_to_download))
    print(f"Discovered {len(files_to_download)} files to import.")

    # Fetch LICENSE
    print("Fetching LICENSE...")
    try:
        license_bytes = fetch_url(f"{RAW_BASE}/LICENSE")
        TARGET_LICENSES.parent.mkdir(parents=True, exist_ok=True)
        TARGET_LICENSES.write_bytes(license_bytes)
        print("Wrote LICENSE.")
    except Exception as e:
        print(f"Warning: could not fetch LICENSE: {e}")

    # Fetch Kotlin files
    imported = []
    for upstream_path, rel_target in files_to_download:
        dest = TARGET_SRC / rel_target
        dest.parent.mkdir(parents=True, exist_ok=True)
        raw_url = f"{RAW_BASE}/{upstream_path}"
        try:
            content = fetch_url(raw_url)
            dest.write_bytes(content)
            imported.append(str(dest))
            print(f"Imported: {rel_target}")
        except Exception as e:
            print(f"Failed to fetch {raw_url}: {e}", file=sys.stderr)

    print(f"\nDone! Successfully imported {len(imported)} files into {TARGET_SRC}.")

if __name__ == "__main__":
    main()
