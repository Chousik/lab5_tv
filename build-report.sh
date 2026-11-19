#!/usr/bin/env bash
# Собирает report.pdf; скрины из screens/ подставляются по имени файла.
set -euo pipefail
cd "$(dirname "$0")"
ls screens | grep -Ei '\.(png|jpe?g)$' > screens/ready.txt || true
typst compile report.typ report.pdf
echo "report.pdf готов. Скринов найдено: $(wc -l < screens/ready.txt | tr -d ' ') из 21"
