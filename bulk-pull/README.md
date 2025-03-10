# Bulk Pull Script

このスクリプトは、指定されたディレクトリ以下にあるすべてのGitリポジトリを検索し、それぞれのリポジトリの`main`ブランチを最新の状態に更新します。

## 使用方法

1. スクリプトを実行したいディレクトリに移動します。
2. `bulk-pull.sh`スクリプトを実行します。

```bash
cd /path/to/your/directory
./bulk-pull.sh
```

## スクリプトの内容

```bash
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
```

## 注意事項

- スクリプトは`main`ブランチを前提としています。他のブランチを使用している場合は、スクリプトを適宜修正してください。
- スクリプトを実行する前に、作業中の変更がないことを確認してください。未コミットの変更がある場合、`git checkout main`コマンドでエラーが発生する可能性があります。
