# `clone-repos.sh`

このスクリプトは、指定されたORG名とリポジトリリストファイルに基づいてリポジトリをクローンします。

## 使用方法

```bash
./clone-repos.sh <org-name> <repo-list-file>
```

## 引数

- `<org-name>`: GitHubのOrg名
- `<repo-list-file>`: リポジトリ名が記載されたファイルのパス

リポジトリリストファイルは、リポジトリ名を1行ずつ記載したテキストファイルです。例:

```
repo_name_1
repo_name_2
repo_name_3
```

## 注意事項

- スクリプトを実行する前に、Gitがインストールされていることを確認してください。