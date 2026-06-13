#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"

if [[ ! -f .env.test.local ]]; then
    echo "Missing .env.test.local. Copy .env.test.local.example and fill in a dedicated test account." >&2
    exit 1
fi

set -a
# shellcheck disable=SC1091
. ./.env.test.local
set +a

required=(
    NEXTNOTES_TEST_SERVER
    NEXTNOTES_TEST_USERNAME
    NEXTNOTES_TEST_APP_PASSWORD
)

for name in "${required[@]}"; do
    if [[ -z "${!name:-}" ]]; then
        echo "Missing $name in .env.test.local." >&2
        exit 1
    fi
done

mkdir -p .clickable
tmp_config="$(mktemp .clickable/nextnotes-desktop-test.XXXXXX.yaml)"
desktop_env_file=".clickable/nextnotes-desktop-env.local"
cleanup() {
    rm -f "$tmp_config"
    rm -f "$desktop_env_file"
}
trap cleanup EXIT

python3 - "$tmp_config" "$desktop_env_file" <<'PY'
import json
import os
import pathlib
import sys

project_config = pathlib.Path("clickable.yaml").read_text(encoding="utf-8")
target = pathlib.Path(sys.argv[1])
desktop_env_file = pathlib.Path(sys.argv[2])
env_vars = {
    "NEXTNOTES_DESKTOP_TEST_AUTH": "1",
    "NEXTNOTES_TEST_SERVER": os.environ["NEXTNOTES_TEST_SERVER"],
    "NEXTNOTES_TEST_USERNAME": os.environ["NEXTNOTES_TEST_USERNAME"],
    "NEXTNOTES_TEST_APP_PASSWORD": os.environ["NEXTNOTES_TEST_APP_PASSWORD"],
}

with target.open("w", encoding="utf-8") as handle:
    handle.write(project_config.rstrip())
    handle.write("\n")
    handle.write("env_vars:\n")
    for key, value in env_vars.items():
        handle.write(f"  {key}: {json.dumps(value)}\n")

with desktop_env_file.open("w", encoding="utf-8") as handle:
    for key, value in env_vars.items():
        handle.write(f"{key}={json.dumps(value)}\n")
PY

chmod 600 "$desktop_env_file"

~/.local/bin/clickable desktop --arch amd64 --config "$tmp_config"
