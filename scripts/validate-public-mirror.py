import os
import sys
import json
import re

def print_failure(msg):
    print(f"FAIL: {msg}")

def read_file_content(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            return f.read()
    except Exception as e:
        print_failure(f"Could not read {filepath}: {e}")
        return None

def read_json_file(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception as e:
        print_failure(f"Could not parse JSON in {filepath}: {e}")
        return None

def main():
    failures = 0

    # 1. Confirm required public files exist
    required_files = [
        "README.md",
        "index.html",
        "app.js",
        "styles.css",
        "data/manifest.json",
        "data/weather-context.json",
        "data/live.json"
    ]

    for f in required_files:
        if not os.path.exists(f):
            print_failure(f"Missing required file: {f}")
            failures += 1

    # Parse all public JSON files under data/ to make sure they are valid
    if os.path.isdir('data'):
        for file in os.listdir('data'):
            if file.endswith('.json'):
                path = os.path.join('data', file)
                if read_json_file(path) is None:
                    failures += 1

    # 2. Check boundary phrases in README.md and HTML
    readme_content = read_file_content("README.md")
    index_content = read_file_content("index.html")

    # Based on scripts/validate-public-mirror.ps1 exact needles
    readme_phrases = [
        "not official public-health guidance",
        "late-prototype / early-MVP"
    ]

    index_phrases = [
        "late prototype / early MVP",
        "Public Data Snapshot, Not Advisory Guidance"
    ]

    if readme_content:
        for phrase in readme_phrases:
            if phrase.lower() not in readme_content.lower():
                print_failure(f"README.md missing boundary phrase: '{phrase}'")
                failures += 1

    if index_content:
        for phrase in index_phrases:
            if phrase.lower() not in index_content.lower():
                print_failure(f"index.html missing boundary phrase: '{phrase}'")
                failures += 1

    # 3. Check weather-context.json boundaries
    weather_context = read_json_file("data/weather-context.json")
    if weather_context:
        status = weather_context.get("machineReadableStatus")
        source_name = weather_context.get("sourceName", "")

        if status != "unavailable":
            if "noaa" not in source_name.lower() and "national weather service" not in source_name.lower():
                print_failure(f"weather-context is available but sourceName does not look like reviewed telemetry (NOAA/NWS): {source_name}")
                failures += 1

    # 4. Check for private/trusted-review references in the public mirror

    private_patterns = [
        r"data/private/",
        r"\.local\.json",
        r"\.local\.sqlite",
        r"docs/trusted-review-request\.md"
    ]

    # Also look at tracked files without relying on git
    tracked_files = []
    for root, dirs, files in os.walk('.'):
        if '.git' in root:
            continue
        for file in files:
            path = os.path.join(root, file)
            path_unix = path.replace('\\', '/')
            if path_unix.startswith('./'):
                path_unix = path_unix[2:]
            tracked_files.append(path_unix)

    for file_path in tracked_files:
        for pattern in private_patterns:
            if re.search(pattern, file_path):
                print_failure(f"Found private/trusted-review file: {file_path}")
                failures += 1

    # check that no public files mention private paths
    public_content_files = ["app.js", "index.html", "project.html", "methodology.html"]
    for file in public_content_files:
        if os.path.exists(file):
            content = read_file_content(file)
            if content:
                for pattern in private_patterns:
                    if re.search(pattern, content):
                        print_failure(f"Public file {file} contains reference to private path matching: {pattern}")
                        failures += 1

    if failures > 0:
        print(f"\nValidation FAILED with {failures} errors.")
        sys.exit(1)
    else:
        print("\nValidation PASSED. All checks look good.")
        sys.exit(0)

if __name__ == "__main__":
    main()
