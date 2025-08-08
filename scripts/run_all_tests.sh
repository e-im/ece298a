#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
cd "${ROOT_DIR}/test"

if [ -d venv_cocotb ]; then
  # shellcheck source=/dev/null
  source venv_cocotb/bin/activate
fi

echo "[tests] engine"
make tb-engine
echo "[tests] vga"
make tb-vga
echo "[tests] mandelbrot"
make tb-mandelbrot
echo "[tests] png"
make tb-png

echo "[tests] summary:"
grep -E "\*\* TESTS=.* PASS=.* FAIL=0" -n results.xml || true
if [ -f out.png ]; then
  echo "[tests] out.png present"
fi

echo "[tests] done."


