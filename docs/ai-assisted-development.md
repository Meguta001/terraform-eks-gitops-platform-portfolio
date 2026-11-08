# AI-Assisted Development — Kustomize Validation CI

## 1. 概要

このドキュメントは、Terraform × Amazon EKS × GitOpsによるKubernetesプラットフォームの個人開発において、**OpenAI Codex（VS Code拡張機能）を利用した開発事例**を記録するものです。

対象は、KubernetesマニフェストをGitHub Actionsで自動検証するワークフローです。AIに実装とローカル検証を支援させ、人間が要件定義・計画承認・レビュー・Gitへの反映判断を担当しました。

- 対象ファイル：`.github/workflows/validate-kustomize.yml`
- 開発目的：Kustomizeマニフェストの構造とコンテナイメージ参照をCIで検証する
- 利用技術：OpenAI Codex、GitHub Actions、Kustomize、kubectl、Python、PyYAML
- AWSへの認証・EKSへの接続：このCIでは**使用しない**

## 2. 背景と課題

従来は、Kubernetesマニフェストを変更した際に、開発者がローカルで `kubectl kustomize` を実行していました。

これをCI化することで、`main` ブランチに反映されるマニフェストの変更を継続的に検証し、リソース定義の欠落や不適切なイメージ参照を早期に検出できるようにしました。

## 3. Codexと人間の役割分担

| 担当 | 実施内容 |
| --- | --- |
| 人間 | 目的・要件・対象ファイル・禁止操作を指定 |
| Codex | 既存のWorkflowとKustomize構成を調査し、実装計画を提示 |
| 人間 | 計画を確認し、kubectlのバージョン指定とECRのDigest検証を追加要件として承認 |
| Codex | 検証用Workflowを新規作成し、ローカル検証を実施 |
| 人間 | 作成ファイルの内容と差分をレビューし、GitへのCommit・Pushを判断・実施 |
| GitHub Actions | CI環境でWorkflowを実行し、実行結果を確認 |

### Codexへの主な制約

- 新規作成対象は `.github/workflows/validate-kustomize.yml` のみとする
- 既存のTerraform、Kubernetesマニフェスト、Workflowは変更しない
- `git commit` / `git push` は実行しない
- `terraform apply` / `terraform destroy` / `kubectl apply` は実行しない
- AWSアクセスキーなどの認証情報を使用しない
- 実装後に差分、検証結果、未確認事項を報告する

## 4. 実装したCIの内容

### 起動条件と権限

- `main` ブランチへのPushのうち `k8s/**` に変更がある場合に実行
- `workflow_dispatch` による手動実行にも対応
- GitHub Actionsの権限は `contents: read` のみ
- EKSクラスタやAWS APIへの接続は不要

### 主な処理

1. リポジトリをチェックアウトする
2. バージョンを指定して `kubectl` とPythonを用意する
3. PyYAMLをインストールする
4. `kubectl kustomize k8s/overlays/dev` でマニフェストを生成する
5. Pythonで生成結果の次の項目を検証する
   - `Deployment`・`Service`・`Namespace` の存在
   - 対象リソースの `apiVersion` と `metadata.name` の存在
   - Deployment内の通常コンテナ・initContainerのイメージ指定
   - コンテナイメージがPrivate Amazon ECR形式であること
   - イメージが `@sha256:` と64桁の16進数によるDigestで固定されていること

**設計意図：** AWS認証や実クラスタを必要としない静的検証としてCIを独立させ、低コストかつ安全に繰り返し実行できるようにしました。

## 5. 検証結果と証跡

### Codexから報告されたローカル検証

- YAML解析および設定チェック：成功（Codex報告）
- 埋め込みPythonの構文チェック：成功（Codex報告）
- dev Overlayの生成と検証：成功（Codex報告）
- リソース欠落や不正なイメージ参照を含む異常系11件：すべて検出（Codex報告）
- 既存ファイルへの変更なし、検証用一時ファイルは削除済み（Codex報告）

これらは**Codexによる報告内容**であり、独立したテスト記録一式を保存・再実行して確認したことを意味しません。

### GitHub Actionsでの確認

- GitHub Actions上で手動実行を実施
- 後処理で `azure/setup-kubectl@v4` に対するNode.js 20非推奨のWarningを確認
- WarningはNode.js 24への強制切り替えについての通知であり、単独ではジョブの失敗を意味しない
- **最終的な成功判定はGitHub Actions画面のWorkflow / Jobステータスで確認する**

### バージョンに関する注記

- Codexによるローカル検証：既存環境の `kubectl v1.36.1`
- GitHub Actionsの設定：`kubectl v1.35.0`
- GitHub Actionsでの実行結果をもって、指定したバージョンでの動作を確認する

## 6. 検証範囲と限界

このCIが確認するのは、Kustomizeによるマニフェスト生成と、実装したルールに基づく静的チェックです。

次の項目は**このCI単体では検証していません**。

- Kubernetes API Serverによるスキーマ全体の検証
- 実際のPod起動・Readiness・Liveness・Service疎通
- ECR上の対象イメージの存在やPull可否
- Argo CDによる同期・更新・ロールバック
- 実環境のセキュリティ設定全般

これらはEKS上の稼働検証、GitOps検証、後続の運用・セキュリティ工程で別途確認します。

## 7. 得られた成果と学び

- AIコーディングエージェントを、**要件定義 → 実装計画の承認 → コード生成 → 人間のレビュー → CI実行検証**という開発プロセスに組み込んだ
- Kustomizeの手動チェックをCIで実行できる形にし、変更時の検証漏れを減らす基盤を整備した
- AWS認証や実クラスタへのアクセスを与えず、Codexの操作対象を最小化できた
- AIの自己申告によるテスト結果と、GitHub Actions上の実行結果を区別して記録する重要性を確認した

## 8. 今後の改善候補

- Workflow自身を変更した場合にも自動起動するよう、必要に応じて `paths` に `.github/workflows/validate-kustomize.yml` を追加する
- Kubernetesリソース名の期待値との一致検証を追加する（現在は名前の存在を確認）
- Node.jsの非推奨Warningを解消するため、対応済みActionへの更新を検討する
- 必要に応じてKubernetesスキーマ検証やPolicy as Codeを導入する

---

**公開時の情報管理方針：** 本ファイルには認証情報、アクセスキー、トークン、個人のIPアドレス、AWSアカウントID、IAM Role ARN、ローカルPCのユーザー名、機密値、実行ログ固有の識別子を記載しません。
