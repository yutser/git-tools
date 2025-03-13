# Bulk Repository Update Script

このスクリプトは、複数のリポジトリに対して指定されたファイルの文字列を一括で置換または削除し、新しいブランチを作成してプルリクエストを作成します。

## 前提条件

以下のツールがインストールされている必要があります。

- `yq`
- `gh`

また、事前にGitHubにログインしておく必要があります。

```bash
gh auth login
```

## 使用方法

1. `repo-list.yaml`ファイルを作成し、以下の形式でリポジトリと文字列の情報を記述します。

    ```yaml
    target-file: "ファイル名"
    new-branch: "新しいブランチ名"
    commit-message: "コミットメッセージ"
    pr-title: "PRのタイトル"
    strings:
      - old: "置換前の文字列"
        new: "置換後の文字列"
        action: "replace"
      - old: "削除する文字列"
        action: "delete"
    repositories:
      - name: "リポジトリ名1"
      - name: "リポジトリ名2"
    ```

2. `pr-template.md`ファイルを作成し、PRのテンプレートをMarkdown形式で記述します。

    ```markdown
    # Custom PR Body

    This PR includes the following changes:
    - Replaced old_string1 with new_string1
    - Replaced old_string2 with new_string2
    - Deleted string_to_delete

    Please review the changes and provide feedback.
    ```

3. スクリプトを実行します。

    ```bash
    bash bulk-repo-update.sh
    ```

4. スクリプトが実行されると、指定されたリポジトリ内の指定されたファイルに対して文字列の置換または削除が行われ、新しいブランチが作成されます。変更がコミットされ、リモートにプッシュされ、プルリクエストが作成されます。

5. 作成されたプルリクエストのURLが出力されます。

## 注意事項

- スクリプトは現在のディレクトリ以下のリポジトリを検索します。リポジトリが存在しない場合はエラーメッセージが表示されます。