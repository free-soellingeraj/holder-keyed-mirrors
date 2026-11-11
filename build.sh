#!/usr/bin/env bash
# Builds the generated formats from the Markdown source.
#
#   1. mmdc (Mermaid CLI) renders every Mermaid block in architecture.md to a
#      PNG and writes build/architecture.md, with each block replaced by an
#      image link. Its alt text is the diagram's accDescr line.
#   2. pandoc turns build/architecture.md into build/holder-keyed-mirrors.docx,
#      with a title page and a table of contents (tools/docx-front.lua).
#
# architecture.md is the only source. Never edit anything under build/ by
# hand: this script deletes and rewrites the whole directory.
set -euo pipefail

cd "$(dirname "$0")"

for tool in mmdc pandoc; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "build.sh: '$tool' is not on PATH. See CONTRIBUTING.md, 'Building'." >&2
    exit 1
  fi
done

# 0. The feedback form's section dropdown must list exactly the numbered
#    headings of architecture.md, in the same order.
doc_sections="$(grep -E '^(## [0-9]+\. |### [0-9]+\.[0-9]+ )' architecture.md | sed -E 's/^#+ //')"
form_sections="$(sed -n '/section-options:start/,/section-options:end/p' feedback-form.md \
  | sed -n -E 's/^- ([0-9].*)$/\1/p')"
if [ -z "$doc_sections" ] || [ "$doc_sections" != "$form_sections" ]; then
  echo "build.sh: feedback-form.md's section list does not match architecture.md's numbered headings:" >&2
  diff <(printf '%s\n' "$doc_sections") <(printf '%s\n' "$form_sections") >&2 || true
  exit 1
fi

rm -rf build
mkdir -p build

# 1. Diagrams. Fails on the first Mermaid block that does not parse.
mmdc_args=(-i architecture.md -o build/architecture.md -e png -s 2 -b white -t neutral)
if [ -n "${CI:-}" ]; then
  # Headless Chrome cannot use its sandbox on most CI runners.
  mmdc_args+=(-p tools/puppeteer-ci.json)
fi
mmdc "${mmdc_args[@]}"

expected="$(grep -c '^```mermaid' architecture.md)"
rendered="$(find build -maxdepth 1 -name 'architecture-*.png' | wc -l | tr -d ' ')"
if [ "$expected" != "$rendered" ]; then
  echo "build.sh: architecture.md has $expected Mermaid blocks but $rendered were rendered." >&2
  exit 1
fi
if grep -q '^```mermaid' build/architecture.md; then
  echo "build.sh: build/architecture.md still contains an unrendered Mermaid block." >&2
  exit 1
fi

# 2. The .docx. A fixed timestamp keeps the file the same for the same source.
if [ -z "${SOURCE_DATE_EPOCH:-}" ]; then
  SOURCE_DATE_EPOCH="$(git log -1 --format=%ct 2>/dev/null || date +%s)"
  export SOURCE_DATE_EPOCH
fi

pandoc build/architecture.md \
  --from gfm \
  --to docx \
  --lua-filter tools/docx-front.lua \
  --resource-path build \
  --output build/holder-keyed-mirrors.docx

echo "build.sh: rendered $rendered diagrams"
echo "build.sh: wrote build/holder-keyed-mirrors.docx ($(wc -c < build/holder-keyed-mirrors.docx | tr -d ' ') bytes)"
