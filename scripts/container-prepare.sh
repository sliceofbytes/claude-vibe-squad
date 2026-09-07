#!/usr/bin/env bash
# One home for the image's source-tree preparation. Both Dockerfile stages call
# this; do not inline a second copy (CLAUDE.md Rule 10 — the two stages had
# byte-identical 12-line blocks that could drift apart silently).
#
# Strip CRLF a Windows build context carries in, mark the entrypoints
# executable, and hand what was rewritten back to the runtime user.
set -euo pipefail

ROOT="${1:-/squad}"
OWNER="${2:-squad:squad}"

# `WORKDIR` creates $ROOT as root and `COPY --chown` only owns what it copies
# INTO it, so the directory itself stays root-owned. `uv sync` then cannot
# create $ROOT/.venv, and the runtime user cannot create _state. This one
# non-recursive chown is the part of the old `chown -R` that was load-bearing
# (measured: without it the test stage fails at `uv sync --locked` with
# "failed to create directory `/squad/.venv`: Permission denied").
chown "$OWNER" "$ROOT"

# `sed -i` renames a temp file into place, so anything it rewrites comes back
# root-owned. chown only those files: a `chown -R` over the whole tree copies
# every file in the checkout into a second image layer.
find "$ROOT" \( -name '*.sh' -o -name '*.py' -o -name 'squad-watch' \
        -o -name 'squad' -o -name 'test' -o -path '*/.githooks/*' \) \
    -type f -exec sed -i 's/\r$//' {} + -exec chown "$OWNER" {} +

chmod +x "$ROOT/scripts/container-entrypoint.sh" "$ROOT/bin/squad-watch" \
    "$ROOT/bin/squad" "$ROOT/bin/test" "$ROOT/bin/doctor.sh"
[ ! -f "$ROOT/.githooks/pre-commit" ] || chmod +x "$ROOT/.githooks/pre-commit"
