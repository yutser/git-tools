#!/bin/bash

# リポジトリリストファイル
REPO_LIST="repo-list.yaml"

# YAMLパーサーのインストール確認
if ! command -v yq &> /dev/null; then
  echo "yq could not be found, please install it."
  exit 1
fi

# GitHub CLIツールのインストール確認
if ! command -v gh &> /dev/null; then
  echo "gh CLI could not be found, please install it."
  exit 1
fi

# YAMLファイルから設定を読み込む
TARGET_FILE=$(yq e '.target-file' "$REPO_LIST")
NEW_BRANCH=$(yq e '.new-branch' "$REPO_LIST")
repos=$(yq e '.repositories[].name' "$REPO_LIST")
strings=$(yq e '.strings' "$REPO_LIST")

# 現在のディレクトリ以下を検索
for REPO_NAME in $repos; do
  REPO_PATH=$(find . -type d -name "$REPO_NAME" -print -quit)
  if [ -n "$REPO_PATH" ]; then
    cd "$REPO_PATH" || exit
    # 新しいブランチを作成
    git checkout -b "$NEW_BRANCH"
    # 指定されたファイルの文字列を置換または削除
    for row in $(echo "${strings}" | yq -o=json | jq -c '.[]'); do
      OLD_STRING=$(echo "${row}" | jq -r '.old')
      NEW_STRING=$(echo "${row}" | jq -r '.new // empty')
      ACTION=$(echo "${row}" | jq -r '.action')
      if [ "$ACTION" == "replace" ]; then
        sed -i '' "s/$OLD_STRING/$NEW_STRING/g" "$TARGET_FILE"
      elif [ "$ACTION" == "delete" ]; then
        sed -i '' "/$OLD_STRING/d" "$TARGET_FILE"
      fi
    done
    # 変更をコミット
    git add "$TARGET_FILE"
    git commit -m "Update strings in $TARGET_FILE"
    # リモートにプッシュ
    git push origin "$NEW_BRANCH"
    # プルリクエストを作成
    gh pr create --base main --head "$NEW_BRANCH" --title "Update strings in $TARGET_FILE" --body "This PR updates multiple strings in $TARGET_FILE."
    # 元のディレクトリに戻る
    cd - || exit
  else
    echo "Repository $REPO_NAME does not exist locally."
  fi
done
