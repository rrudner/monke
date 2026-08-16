#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SCRIPTORIUM_MANUAL_UPDATE=1 \
    SCRIPTORIUM_SKIP_SNOOZE_CHECK=1 \
    "$repo_dir/bin/scodex" update
