#!/bin/bash

set -eu

readonly TMP_DIR=tmp
readonly INDEX_FILE=dist/index.md

mkdir -p "$TMP_DIR"
cp config.yml "$TMP_DIR"

mkdir -p dist
cat << EOS > "$INDEX_FILE"
# スライド一覧

EOS


# 各種スライドHTMLを生成する
find src/ -name "*.md" | sort | while read -r f; do
  echo -en "[\x1b[34m Doing   \x1b[m] $f"

  src_dir=$(dirname "$f")
  dist_dir=$(echo "$src_dir" | sed -E "s@^src@dist@")

  # reveal-ckはカレントディレクトリにファイルがないと動作しないので
  # 作業用ディレクトリに一旦ファイルを移動
  mkdir -p "$dist_dir"
  cp "$f" "$TMP_DIR"

  # 目次を見出し表記から自動生成
  ./replace.py "$TMP_DIR/slides.md"

  # HTMLの生成
  (cd "$TMP_DIR" && reveal-ck generate -d "../$dist_dir") >& /dev/null

  # スライド一覧ファイルに追記
  url=$(echo "$dist_dir" | sed -E "s@^dist/@./@g")
  title=$(head -n 1 "$f" | sed -E 's@^#\s*@@g')
  echo "* [$title]($url/)" >> "$INDEX_FILE"

  echo -e "\e[2K\e[0G[\x1b[32m Success \x1b[m] $f -> $dist_dir"
done
