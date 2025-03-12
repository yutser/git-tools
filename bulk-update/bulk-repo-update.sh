#!/bin/bash

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

# リポジトリリストファイル
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_LIST="$SCRIPT_DIR/repo-list.yaml"

# YAMLファイルから設定を読み込む
echo "Reading configuration from $REPO_LIST"
TARGET_FILE_NAME=$(yq e '.target-file' "$REPO_LIST")
if [ -z "$TARGET_FILE_NAME" ]; then
  echo "Target file name not specified in $REPO_LIST"
  exit 1
fi

NEW_BRANCH=$(yq e '.new-branch' "$REPO_LIST")
if [ -z "$NEW_BRANCH" ]; then
  echo "New branch name not specified in $REPO_LIST"
  exit 1
fi

repos=$(yq e '.repositories[].name' "$REPO_LIST")
if [ -z "$repos" ]; then
  echo "No repositories specified in $REPO_LIST"
  exit 1
fi

echo "Target file: $TARGET_FILE_NAME"
echo "New branch: $NEW_BRANCH"
echo "Repositories: $repos"

# PRリストを格納する配列
PR_LIST=()

# スクリプトの実行ディレクトリを保存
SCRIPT_DIR=$(pwd)

# 現在のディレクトリ以下を検索
for REPO_NAME in $repos; do
  echo "Processing repository: $REPO_NAME"
  REPO_PATH=$(find "$SCRIPT_DIR" -type d -name "$REPO_NAME" -print -quit)
  if [ -n "$REPO_PATH" ]; then
    echo "Found repository path: $REPO_PATH"
    cd "$REPO_PATH" || exit
    # 新しいブランチを作成
    echo "Creating new branch: $NEW_BRANCH"
    git checkout -b $NEW_BRANCH
    # 指定されたファイルをリポジトリ内で探索
    TARGET_FILE=$(find . -type f -name "$TARGET_FILE_NAME" -print -quit)
    if [ -z "$TARGET_FILE" ]; then
      echo "Target file $TARGET_FILE_NAME not found in $REPO_NAME"
      cd "$SCRIPT_DIR" || exit
      continue
    fi
    echo "Found target file: $TARGET_FILE"
    # 指定されたファイルの文字列を置換または削除
    FILE_MODIFIED=false
    num_strings=$(yq e '.strings | length' "$REPO_LIST")
    for i in $(seq 0 $((num_strings - 1))); do
      OLD_STRING=$(yq e ".strings[$i].old" "$REPO_LIST")
      NEW_STRING=$(yq e ".strings[$i].new // \"\"" "$REPO_LIST")
      ACTION=$(yq e ".strings[$i].action" "$REPO_LIST")
      echo "Processing string: $OLD_STRING -> $NEW_STRING (action: $ACTION)"
      if [ "$ACTION" == "replace" ]; then
        if grep -q "$OLD_STRING" "$TARGET_FILE"; then
          sed -i '' "s|$OLD_STRING|$NEW_STRING|g" "$TARGET_FILE"
          FILE_MODIFIED=true
          echo "Replaced $OLD_STRING with $NEW_STRING in $TARGET_FILE"
        fi
      elif [ "$ACTION" == "delete" ]; then
        if grep -q "$OLD_STRING" "$TARGET_FILE"; then
          sed -i '' "/$OLD_STRING/d" "$TARGET_FILE"
          FILE_MODIFIED=true
          echo "Deleted $OLD_STRING from $TARGET_FILE"
        fi
      fi
    done
    # 変更があった場合のみコミット
    if [ "$FILE_MODIFIED" = true ]; then
      echo "Changes detected, committing changes"
      git add "$TARGET_FILE"
      git commit -m "Update $TARGET_FILE"
      # リモートにプッシュ
      echo "Pushing branch $NEW_BRANCH to origin"
      git push origin "$NEW_BRANCH"
      # プルリクエストを作成
      echo "Creating pull request"
      PR_URL=$(gh pr create --base main --head "$NEW_BRANCH" --title "Update strings in $TARGET_FILE" --body "This PR updates multiple strings in $TARGET_FILE.")
      PR_LIST+=("$PR_URL")
      echo "Pull request created: $PR_URL"
    else
      echo "No changes made in $REPO_NAME"
    fi
    # 元のディレクトリに戻る
    cd "$SCRIPT_DIR" || exit
  else
    echo "Repository $REPO_NAME does not exist locally."
  fi
done

# 作成したPRのリストを出力
echo "Created Pull Requests:"
for PR in "${PR_LIST[@]}"; do
  echo "$PR"
done
