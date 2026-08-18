#!/bin/sh

set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)

(
  cd "$project_root"
  MUHARC_RUNTIME_DIR=build/runtime ./tests/uharc_integration_test.sh
)

printf '%s\n' 'PASS: UHARC integration test accepts a relative runtime path'
