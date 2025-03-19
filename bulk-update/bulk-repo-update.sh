#!/bin/bash

log_info() {
  echo "[INFO] $1"
}

log_error() {
  echo "[ERROR] $1" >&2
}

# YAMLパーサーのインストール確認
if ! command -v yq &> /dev/null; then
  log_error "yq could not be found, please install it."
  exit 1
fi

# GitHub CLIツールのインストール確認
if ! command -v gh &> /dev/null; then
  log_error "gh CLI could not be found, please install it."
  exit 1
fi

# リポジトリリストファイル
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_LIST="$SCRIPT_DIR/repo-list.yaml"

# PRテンプレートファイル
PR_TEMPLATE_FILE="$SCRIPT_DIR/pr-template.md"

# YAMLファイルから設定を読み込む
log_info "Reading configuration from $REPO_LIST"
TARGET_FILES=$(yq e '.target-files[]' "$REPO_LIST")
if [ -z "$TARGET_FILES" ]; then
  log_error "Target files not specified in $REPO_LIST"
  exit 1
fi

NEW_BRANCH=$(yq e '.new-branch' "$REPO_LIST")
if [ -z "$NEW_BRANCH" ]; then
  log_error "New branch name not specified in $REPO_LIST"
  exit 1
fi

COMMIT_MESSAGE=$(yq e '.commit-message // "Update $TARGET_FILE_NAME"' "$REPO_LIST")

PR_TITLE=$(yq e '.pr-title // "Update strings in $TARGET_FILE_NAME"' "$REPO_LIST")

if [ -n "$PR_TEMPLATE_FILE" ]; then
  PR_BODY=$(cat "$PR_TEMPLATE_FILE")
else
  PR_BODY=$(yq e '.pr-body // "This PR updates multiple strings in $TARGET_FILE_NAME."' "$REPO_LIST")
fi

repos=$(yq e '.repositories[].name' "$REPO_LIST")
if [ -z "$repos" ]; then
  log_error "No repositories specified in $REPO_LIST"
  exit 1
fi

log_info "Target files: $TARGET_FILES"
log_info "New branch: $NEW_BRANCH"
log_info "Repositories: $repos"
log_info "PR title: $PR_TITLE"
log_info "PR body: $PR_BODY"

# PRリストを格納する配列
PR_LIST=()

# スクリプトの実行ディレクトリを保存
SCRIPT_DIR=$(pwd)

# 現在のディレクトリ以下を検索
for REPO_NAME in $repos; do
  log_info "Processing repository: $REPO_NAME"
  REPO_PATH=$(find "$SCRIPT_DIR" -type d -name "$REPO_NAME" -print -quit)
  if [ -n "$REPO_PATH" ]; then
    log_info "Found repository path: $REPO_PATH"
    cd "$REPO_PATH" || exit

    # リポジトリを最新の状態に更新
    log_info "Pulling latest changes for $REPO_NAME"
    git pull origin main

    # 現在のブランチがmainかどうか確認
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    if [ "$CURRENT_BRANCH" != "main" ]; then
      log_info "Current branch is not main in $REPO_NAME, switching to main"
      git checkout main
      if [ $? -ne 0 ]; then
      log_error "Failed to switch to main branch in $REPO_NAME"
      cd "$SCRIPT_DIR" || exit
      continue
      fi
    fi

    # 新しいブランチを作成
    if git show-ref --verify --quiet refs/heads/"$NEW_BRANCH"; then
      log_info "Branch $NEW_BRANCH already exists, checking it out"
      git checkout "$NEW_BRANCH"
    else
      log_info "Creating new branch: $NEW_BRANCH"
      git checkout -b "$NEW_BRANCH"
    fi

    FILE_MODIFIED=false
    for TARGET_FILE_NAME in $TARGET_FILES; do
      # 指定されたファイルをリポジトリ内で探索
      TARGET_FILES_FOUND=$(find . -type f -name "$TARGET_FILE_NAME")
      if [ -z "$TARGET_FILES_FOUND" ]; then
        log_error "Target file $TARGET_FILE_NAME not found in $REPO_NAME"
        continue
      fi
      log_info "Found target files: $TARGET_FILES_FOUND"
      # 各ファイルに対して処理を実行
      for TARGET_FILE in $TARGET_FILES_FOUND; do
        log_info "Processing target file: $TARGET_FILE"
        # 指定されたファイルの文字列を置換または削除
        num_strings=$(yq e '.strings | length' "$REPO_LIST")
        for i in $(seq 0 $((num_strings - 1))); do
          OLD_STRING=$(yq e ".strings[$i].old" "$REPO_LIST")
          NEW_STRING=$(yq e ".strings[$i].new // \"\"" "$REPO_LIST")
          ACTION=$(yq e ".strings[$i].action" "$REPO_LIST")
          log_info "Processing string: $OLD_STRING -> $NEW_STRING (action: $ACTION)"
          if [ "$ACTION" == "replace" ]; then
            if grep -q "$OLD_STRING" "$TARGET_FILE"; then
              sed -i '' "s|$OLD_STRING|$NEW_STRING|g" "$TARGET_FILE"
              FILE_MODIFIED=true
              log_info "Replaced $OLD_STRING with $NEW_STRING in $TARGET_FILE"
            fi
          elif [ "$ACTION" == "delete" ]; then
            if grep -q "$OLD_STRING" "$TARGET_FILE"; then
              sed -i '' "/$OLD_STRING/d" "$TARGET_FILE"
              FILE_MODIFIED=true
              log_info "Deleted $OLD_STRING from $TARGET_FILE"
            fi
          fi
        done
        # 変更があった場合のみコミット
        if [ "$FILE_MODIFIED" = true ]; then
          log_info "Changes detected, staging file: $TARGET_FILE"
          git add "$TARGET_FILE"
        fi
      done
    done

    if [ "$FILE_MODIFIED" = true ]; then
      git commit -m "$COMMIT_MESSAGE"
      # リモートにプッシュ
      log_info "Pushing branch $NEW_BRANCH to origin"
      git push origin "$NEW_BRANCH"
      # プルリクエストを作成
      log_info "Creating pull request"
      PR_URL=$(gh pr create --base main --head "$NEW_BRANCH" --title "$PR_TITLE" --body "$PR_BODY")
      PR_LIST+=("$PR_URL")
      log_info "Pull request created: $PR_URL"
    else
      log_info "No changes made in $REPO_NAME"
    fi
    # 元のディレクトリに戻る
    cd "$SCRIPT_DIR" || exit
  else
    log_error "Repository $REPO_NAME does not exist locally."
  fi
done

# 作成したPRのリストを出力
log_info "Created Pull Requests:"
for PR in "${PR_LIST[@]}"; do
  log_info "$PR"
done
