#!/bin/bash

set -eu

readonly TMP_DIR=tmp
readonly INDEX_FILE=dist/index.md

mkdir -p "$TMP_DIR"
cp config.yml "$TMP_DIR"

cat << EOS > "$INDEX_FILE"
# スライド一覧

EOS


# 各種スライドHTMLを生成する
find src/ -name "*.md" | sort | while read -r f; do
  echo -en "[\x1b[34m Doing   \x1b[m] $f"

  src_dir=$(dirname "$f")
  dist_dir=$(echo "$src_dir" | sed -E "s@^src@dist@")
  mkdir -p "$dist_dir"
  cp "$f" "$TMP_DIR"
  (cd "$TMP_DIR" && reveal-ck generate -d "../$dist_dir") >& /dev/null

  url=$(echo "$dist_dir" | sed -E "s@^dist/@./@g")
  title=$(head -n 1 "$f" | sed -E 's@^#\s*@@g')
  echo "* [$title]($url/)" >> "$INDEX_FILE"

  echo -e "\e[2K\e[0G[\x1b[32m Success \x1b[m] $f -> $dist_dir"
done
