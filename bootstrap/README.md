# STEP 1-B — Terraform Bootstrap (S3 state bucket)

## 目的

`environments/dev` の Terraform State を保存するための S3 バケットを作成する。

- バケット名: Terraform変数 `backend_bucket_name` で指定
- 実際のバケット名はGit管理外のローカル設定ファイルで管理
- リージョン: `ap-northeast-1`（東京）
- バージョニング: 有効
- デフォルト暗号化: SSE-S3 (`AES256`)
- パブリックアクセス: すべてブロック
- オブジェクト所有権: Bucket owner enforced（ACL無効）
- バケットの削除防止: `prevent_destroy = true`, `force_destroy = false`

## ファイルの役割

| ファイル | 役割 |
|---|---|
| `versions.tf` | Terraform / AWS Provider のバージョン制約。S3 Backendは指定しない |
| `providers.tf` | AWS Providerの東京リージョン設定。認証情報は含めない |
| `main.tf` | S3バケットとセキュリティ設定の定義 |
| `outputs.tf` | 作成されたバケット名とARNの出力 |

## PowerShellでの検証（まだAWSリソースは作成しない）

```powershell
# Terraform用AWSプロファイル
$env:AWS_PROFILE = "terraform-bootstrap"
$env:AWS_DEFAULT_REGION = "ap-northeast-1"

# リポジトリの正しいディレクトリ
cd "$HOME\k8s-projects\terraform-eks-gitops-platform-portfolio\bootstrap"

# AWS認証
aws sso login --profile terraform-bootstrap
aws sts get-caller-identity --profile terraform-bootstrap

# Terraform構文検証のみ
terraform init -backend=false
terraform fmt -check
terraform validate
```

`terraform plan` の内容とアカウントを確認するまで `terraform apply` は実行しない。

## 事前に確認すること

1. `TerraformBootstrap` のPermission SetをAWSアカウント／ユーザーに割り当てておく。
2. 実際のPrivate検証環境ではS3バケットを構築済み。
   公開用コピーには実際のバケット名とTerraform Stateを含めない。
   新規環境へのデプロイ時は、利用者自身のS3 Backendと認証設定を用意する。
3. `aws sts get-caller-identity` の Account / Arn が意図した値であることを確認する。
4. `bootstrap` のTerraform Stateはローカル管理。元のStateを安全に保管し、Stateの所在を確認するまでPlan・Apply・Destroyを実行しない。
5. 既存の `.gitignore` に `*.tfstate`, `*.tfstate.*`, `.terraform/` があるか確認する。`.terraform.lock.hcl` はコミット対象にする。

## IAM権限について

このコードは事前作成した `TerraformBootstrap` のバケット操作権限（作成・読み取り・バージョニング・暗号化・パブリックアクセス・所有権設定）を前提とする。AWS Providerが利用するAPIと実際の権限に差がある場合は、AccessDeniedの操作名を確認して必要な権限だけ追加する。

AWS Provider v6 の最近のバージョンではS3の新しいタグAPIを使う場合がある。今回のコードにはタグを付けていない。既存権限で使うことを優先し、タグ管理は後続の改善フェーズで検討する。

`prevent_destroy` は誤削除を防ぐため、Terraformで後から削除する際には意図的な設計変更と権限が必要。

## 後続ステップ

既存のS3 Backendを利用する際は、Git管理外の設定ファイルを使用する。

ローカル設定ファイル：

`$HOME/.terraform-eks-gitops/backend.hcl`

このファイルには、既存のS3バケット名を設定する。

```hcl
bucket = "実際のS3バケット名"
```

Terraformの各Root Moduleでは、以下のように初期化する。

```powershell
$backendConfig = Join-Path $HOME ".terraform-eks-gitops/backend.hcl"

terraform init -reconfigure "-backend-config=$backendConfig"
```

この設定は以下のRoot Moduleで共通して使用する。

- `environments/dev/`
- `environments/dev/registry/`
- `environments/dev/ci/`

各Root ModuleのState Keyは異なるため、Stateは分離される。

既存のStateを保持したまま設定することが目的であり、Stateの移行やAWSリソースの再作成は行わない。

## 参考

- https://developer.hashicorp.com/terraform/language/backend/s3
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block
