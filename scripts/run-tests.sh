#!/usr/bin/env bash
# Run lint, Lua unit tests and pipeline tests with the local toolchain (see README for setup).
set -euo pipefail
cd "$(dirname "$0")/.."
make lint
make test
make pytest
