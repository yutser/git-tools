#!/bin/bash

# スクリプトの実行ディレクトリを保存
SCRIPT_DIR=$(pwd)

# 現在のディレクトリ以下にあるGitリポジトリを検索
find "$SCRIPT_DIR" -type d -name ".git" | while read -r git_dir; do
  REPO_DIR=$(dirname "$git_dir")
  echo "Updating repository: $REPO_DIR"
  cd "$REPO_DIR" || exit
  # mainブランチに切り替えて最新の変更を取得
  git checkout main
  git pull origin main
  # 元のディレクトリに戻る
  cd "$SCRIPT_DIR" || exit
done
