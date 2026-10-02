#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}

cd "$PROJECT_DIR"
swift run MiniKeyboardCoreTests
swift run MiniKeyboardDiag --self-test
