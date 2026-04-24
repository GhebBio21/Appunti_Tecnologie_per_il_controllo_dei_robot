#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

PDFLATEX_BIN="${PDFLATEX_BIN:-/Library/TeX/texbin/pdflatex}"
STAGE1_JOB="build_stage1"
STAGE2_JOB="build_stage2"

cleanup_job() {
  local job="$1"
  rm -f "${job}.aux" "${job}.out" "${job}.toc" "${job}.pdf" "${job}.log" "${job}.fls" "${job}.fdb_latexmk"
}

cleanup_job "$STAGE1_JOB"
cleanup_job "$STAGE2_JOB"

"$PDFLATEX_BIN" -interaction=nonstopmode -file-line-error -jobname="$STAGE1_JOB" main.tex

python3 - <<'PY'
from pathlib import Path

root = Path(".")
stage1 = "build_stage1"
stage2 = "build_stage2"

aux_lines = (
    (root / f"{stage1}.aux")
    .read_bytes()
    .replace(b"\x00", b"")
    .decode("utf-8", errors="replace")
    .splitlines()
)

toc_lines = []
prefix = r"\@writefile{toc}{"

for line in aux_lines:
    if line.startswith(prefix) and line.endswith("}"):
        toc_lines.append(line[len(prefix):-1])

(root / f"{stage2}.toc").write_text(
    "\n".join(toc_lines) + ("\n" if toc_lines else ""),
    encoding="utf-8",
)
PY

"$PDFLATEX_BIN" -interaction=nonstopmode -file-line-error -jobname="$STAGE2_JOB" main.tex
cp "${STAGE2_JOB}.pdf" main.pdf

echo "Built main.pdf via ${STAGE2_JOB}.pdf"
