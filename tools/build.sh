#!/usr/bin/env bash
# Build shell/ into build/.
#
#   build.sh          configure (if needed) and build
#   build.sh clean    remove the build tree first
#
# The upstream CMakeLists derives VERSION and GIT_REVISION from `git describe`,
# which assumes the tree carries upstream history. Ours is a snapshot, so both
# are passed explicitly from upstream.json.

set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"

if [ "${1:-}" = clean ]; then
    rm -rf build
fi

read -r version sha < <(python3 - "$root/upstream.json" <<'PY'
import json, sys
entry = json.load(open(sys.argv[1]))["shell"]
print(entry["pin"].lstrip("v"), entry["sha"])
PY
)

cmake -S shell -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$root/stage" \
    -DVERSION="$version" \
    -DGIT_REVISION="$sha"

cmake --build build -j"$(nproc)"

printf '\nbuilt %s (%s) -> %s/build\n' "$version" "${sha:0:7}" "$root"
