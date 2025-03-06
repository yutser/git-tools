#!/bin/bash

# 引数の確認
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <org-name> <repo-list-file>"
  exit 1
fi

# 引数からORG名とリポジトリリストファイルのパスを取得
ORG_NAME="$1"
REPO_LIST_FILE="$2"

# リポジトリのベースURL
BASE_URL="https://github.com/${ORG_NAME}"

# リポジトリリストファイルを読み込んでクローン
while read -r repo; do
  if [ -n "$repo" ]; then
    git clone "${BASE_URL}/${repo}.git" 
  fi
done < "$REPO_LIST_FILE"