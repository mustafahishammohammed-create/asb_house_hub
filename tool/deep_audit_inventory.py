"""Inventory every tracked source/config file; indicators are review leads, not bugs.

Run from the repository root: python tool/deep_audit_inventory.py
No network, production data, or secret values are read into the output.
"""

import csv
import hashlib
import json
from pathlib import Path
import re
import subprocess


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "audit" / "2026-11-26"
SUFFIXES = {
    ".dart", ".js", ".cjs", ".py", ".kt", ".kts", ".swift", ".cpp", ".cc", ".h",
    ".rules", ".html", ".cmake", ".json", ".yaml", ".xml", ".plist", ".arb",
    ".pbxproj", ".xcscheme", ".xcconfig", ".xcworkspacedata", ".xcsettings",
    ".storyboard", ".manifest", ".rc", ".bat", ".properties", ".pro", ".lock",
}
INDICATORS = {
    "empty_catches": r"catch\s*\([^)]*\)\s*\{\s*\}",
    "todo_markers": r"\b(?:TODO|FIXME|HACK|UnimplementedError)\b",
    "now_defaults": r"\?\?\s*DateTime\.now\(\)",
    "local_storage_refs": r"SharedPreferences|_prefs\??\.",
    "database_refs": r"\.collection\(",
    "test_hook_refs": r"visibleForTesting|isFirebaseLiveOverride|FailureSimulated",
}

# These are entry points for the targeted behavioral review. Other files still
# receive the language checks/builds applicable to their platform and the scan.
TARGETS = {
    "firestore.rules", "storage.rules", "firebase.json", "firebase.audit.json",
    "pubspec.yaml", "analysis_options.yaml", "lib/main.dart", "lib/firebase_options.dart",
    "android/app/build.gradle.kts", "android/app/src/main/AndroidManifest.xml",
    "ios/Runner/Info.plist", "ios/Runner.xcodeproj/project.pbxproj",
    "ios/Runner/AppDelegate.swift", "ios/Runner/SceneDelegate.swift",
    "android/app/src/main/kotlin/bh/asianschool/asb_house_hub/MainActivity.kt",
    "windows/runner/main.cpp", "web/index.html", "tool/scripts/run_windows.bat",
    "lib/models/sports_trophy.dart", "lib/models/sports_tournament.dart",
    "lib/models/match_telemetry.dart", "lib/widgets/school_circular_composer.dart",
    "lib/widgets/account_switcher_modal.dart", "lib/widgets/academic_image.dart",
    "lib/widgets/camera_capture_dialog.dart", "lib/screens/school_elections_page.dart",
    "lib/screens/election_audit_screen.dart", "lib/screens/chat_room_screen.dart",
    "lib/screens/teacher_timetable_editor_screen.dart", "lib/screens/home_screen.dart",
    "lib/screens/merch_store_tab.dart", "lib/screens/digital_wallet_screen.dart",
    "lib/screens/academics_screen.dart", "lib/screens/house_arena_screen.dart",
}


def main():
    paths = subprocess.check_output(
        ["git", "ls-files", "-z"], cwd=ROOT
    ).decode("utf-8").split("\0")
    paths += ["tool/deep_audit_inventory.py", "tool/probe_known_gaps.cjs", "functions/test/security.test.js", "firebase.audit.json"]
    rows = []
    for name in sorted(set(paths)):
        path = ROOT / name
        if not name or name.startswith("audit/") or not path.is_file():
            continue
        if path.suffix not in SUFFIXES and path.name not in {"CMakeLists.txt", ".firebaserc"}:
            continue
        raw = path.read_bytes()
        source = raw.decode("utf-8-sig")
        generated = "generated" in name or name.startswith("lib/l10n/app_localizations")
        reviewed = name in TARGETS or name.startswith("lib/services/") or name.startswith("functions/") and path.suffix == ".js"
        mode = "generated/config scan" if generated else "source/config scan"
        if name.startswith("test/") or name.startswith("functions/test/"):
            mode = "test suite inspection/execution"
        elif reviewed:
            mode += "; targeted behavioral review"
        rows.append({
            "path": name, "lines": len(source.splitlines()),
            "sha256": hashlib.sha256(raw).hexdigest(), "review_mode": mode,
            **{key: len(re.findall(pattern, source)) for key, pattern in INDICATORS.items()},
        })
    OUTPUT.mkdir(parents=True, exist_ok=True)
    with (OUTPUT / "source_inventory.csv").open("w", encoding="utf-8", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    totals = {"files": len(rows), "lines": sum(row["lines"] for row in rows)}
    for group in ["lib/", "test/", "functions/", "tool/", "android/", "ios/", "windows/", "web/"]:
        selected = [r for r in rows if r["path"].startswith(group)]
        totals[group] = {"files": len(selected), "lines": sum(r["lines"] for r in selected)}
    print(json.dumps(totals, indent=2))


if __name__ == "__main__":
    main()
