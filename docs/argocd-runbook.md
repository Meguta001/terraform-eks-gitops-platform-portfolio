# Argo CD Bootstrap / Recovery Runbook

> **公開用ポートフォリオに関する注意**
>
> 本Runbookは、Private環境で実施したEKS・Argo CDの
> 構築・復旧手順を記録したものです。
>
> 公開版ではAWSアカウントID、ECR URI、GitHub識別情報の
> 一部をプレースホルダーに変更しています。
>
> 公開版の設定をそのまま適用しても、
> 実際のECRイメージを取得してPodを起動することはできません。
>
> TerraformのPlan・Apply・Destroyやkubectl applyを実行する前に、
> 利用者自身の環境設定・認証・Backend・リソースを確認してください。
>
> 記載された実環境での成功実績は過去の検証結果であり、
> 公開用スナップショット自体のデプロイ成功を示すものではありません。

**プロジェクト:** Terraform × Amazon EKS × GitOps による Production-like Kubernetes Platform  
**初版:** 2026-11-03  
**対象環境:** Windows 11 / PowerShell / AWS `ap-northeast-1` / Amazon EKS  
**目的:** EKSをDestroy後に再構築し、Argo CDとGitOps管理対象のアプリを安全に復元する。

## 1. 構成・管理境界

| 項目 | 設定 |
|---|---|
| Terraform用AWS SSO Profile | `terraform-bootstrap` |
| EKS管理用AWS SSO Profile | `eks-admin` |
| EKS Cluster | `eks-gitops-platform-dev-eks` |
| Argo CD Namespace / Helm Release | `argocd` / `argocd` |
| Argo CD Helm Chart / App Version | `10.11.6` / `v3.5.6` |
| Argo CD values | `gitops/argocd/values.yaml` |
| Argo CD Application | `gitops/apps/dev-application.yaml` (`gitops-demo-dev`) |
| Kustomize source | `k8s/overlays/dev` |
| App Namespace / Deployment | `gitops-demo` / `eks-gitops-app` |
| Git Repository（公開用） | `https://github.com/Meguta001/terraform-eks-gitops-platform-portfolio.git` |
| SSH Deploy Key（秘密鍵） | `$HOME\.ssh\argocd_gitops_readonly`（Git管理禁止） |
| TerraformでDestroyするRoot | `environments/dev/` のみ |
| 永続保持するRoot | `bootstrap/`、`environments/dev/registry/`、`environments/dev/ci/` |

**設計方針**

- Argo CDはHelmで導入し、`ClusterIP` + `kubectl port-forward`で管理する。外部Load Balancerは作成しない。
- GitHubのPrivate Repositoryは**読み取り専用のSSH Deploy Key**で参照する。Kubernetes SecretはGitに保存しない。
- `gitops-demo-dev`はAuto SyncとSelf-Healを有効化済み。Pruneは無効。
- Image DigestのGitへの反映は手動で行う。
- 実際のPrivate環境でAuto SyncとSelf-Healを検証済み。
- ECRのイメージはDigest固定。新DigestのOverlayへの反映は現段階で手動コミットする。
- 本構成は学習・ポートフォリオ向けのProduction-like環境であり、完全な本番HA構成ではない。


## 2. 前提チェック（毎回）

以下は公開用リポジトリのローカル配置例です。

```powershell
$repoRoot = "$HOME\k8s-projects\terraform-eks-gitops-platform-portfolio"

cd $repoRoot

# Gitリポジトリ初期化後に実行
git status -sb
git log -3 --oneline

helm version --short
kubectl version --client
```

- Gitの変更を勝手に消さない。`git reset --hard`等は使わない。
- `gitops/argocd/values.yaml`と`gitops/apps/dev-application.yaml`がGitにあることを確認する。
- 秘密鍵・State・自宅IP・管理者パスワードはGit、Issue、公開ログに記録しない。

## 3. EKSがDestroy済みの場合：Terraformで基盤を復元

> **EKSが稼働中ならこの節を飛ばす。** `environments/dev/registry/`、`environments/dev/ci/`、`bootstrap/`にはApply/Destroyしない。

### 3.1 SSO認証・Terraform変数

```powershell
$env:AWS_PROFILE = "terraform-bootstrap"
$env:AWS_DEFAULT_REGION = "ap-northeast-1"
aws sso login --profile terraform-bootstrap
aws sts get-caller-identity

# 実際のEKS管理用IAM Role ARNを対話入力する（Gitへ書かない）
$env:TF_VAR_eks_admin_principal_arn = Read-Host "EKS admin IAM Role ARN"
if ([string]::IsNullOrWhiteSpace($env:TF_VAR_eks_admin_principal_arn)) {
    throw "EKS admin ARN is not set"
}

# 再構築のたびに現在の接続元IPv4を確認する
$currentIp = (Invoke-RestMethod -Uri "https://checkip.amazonaws.com").Trim()
$parsedIp = $null
if (-not [System.Net.IPAddress]::TryParse($currentIp, [ref]$parsedIp) -or
    $parsedIp.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
    throw "Valid public IPv4 was not obtained"
}
$cidr = "$currentIp/32"
$env:TF_VAR_eks_public_access_cidrs = ConvertTo-Json -InputObject @($cidr) -Compress
$allowed = @($env:TF_VAR_eks_public_access_cidrs | ConvertFrom-Json)
if ($allowed.Count -ne 1 -or $allowed[0] -ne $cidr) {
    throw "Public API CIDR setting is invalid"
}
Write-Host "EKS admin ARN configured; API CIDR count: $($allowed.Count)"
```

**注意:** CIDRは自宅の現在のグローバルIPv4 `/32`。実IPをGitへコミットしない。SSO Role ARNが変わった場合はAWS上で再確認する。

### 3.2 Terraformの検証・構築

```powershell
# 公開用コピーではAWSリソースを変更しない
cd "$repoRoot\environments\dev"

terraform init -backend=false
terraform fmt -check -recursive
terraform validate
```

実際のTerraform Plan・Applyは、利用者自身が用意した独立したBackend・AWS環境でのみ実施する。Private環境のBackendを公開用コピーから流用しない。

### 3.3 EKSへ接続

```powershell
$env:AWS_PROFILE = "eks-admin"
$env:AWS_DEFAULT_REGION = "ap-northeast-1"
aws sso login --profile eks-admin
aws sts get-caller-identity
aws eks update-kubeconfig `
  --region ap-northeast-1 `
  --name eks-gitops-platform-dev-eks `
  --profile eks-admin

kubectl config current-context
kubectl get nodes -o wide
kubectl get pods -n kube-system
```

**期待値:** 対象EKSに接続し、Worker Node 2台が`Ready`。失敗時はSSO、接続元CIDR、EKS Access Entry、Node状態を確認する。

## 4. Argo CDの再インストール（新規EKSの場合）

```powershell
cd $repoRoot
$env:AWS_PROFILE = "eks-admin"
$chartVersion = "10.11.6"

# 既存リリースがないことを確認してからインストール
helm list -n argocd
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm show chart argo/argo-cd --version $chartVersion

helm template argocd argo/argo-cd `
  --namespace argocd `
  --version $chartVersion `
  --values .\gitops\argocd\values.yaml `
  > (Join-Path $env:TEMP "argocd-rendered.yaml")
if ($LASTEXITCODE -ne 0) { throw "Helm template failed" }
```

生成結果を確認し、想定外の`LoadBalancer`/`NodePort`サービスや権限がないことを確かめる。**既存Helm Releaseがあれば再度installしない。** ※Private環境での参考手順であり、公開用コピーでは実行しない。

```powershell
helm install argocd argo/argo-cd `
  --namespace argocd `
  --create-namespace `
  --version $chartVersion `
  --values .\gitops\argocd\values.yaml `
  --wait `
  --timeout 10m

helm status argocd -n argocd
kubectl get pods -n argocd
kubectl get svc -n argocd
kubectl get crd applications.argoproj.io
```

**期待値:** Helm `deployed`、必要なPodがReady、`argocd-server` Serviceは`ClusterIP`。PodがPendingなら`t3.medium ×2`のCPU/メモリ余力を確認する。

## 5. Private GitHub Repositoryの認証復元（実装時の参考記録）

> この章は、実際のPrivate環境で使用したSSH Deploy Key方式の参考記録です。
> 公開用ApplicationはHTTPSでPublicリポジトリを参照するため、
> 通常このRepository Secretの作成は不要です。

### 5.1 既存秘密鍵を確認

```powershell
$keyPath = Join-Path $HOME ".ssh\argocd_gitops_readonly"
if (-not (Test-Path $keyPath)) {
    throw "Deploy Key private file not found. Recover securely or rotate the GitHub Deploy Key."
}
```

- 秘密鍵が残っていれば**同じ鍵を再利用**する。既存のGitHub Deploy Keyを重複登録しない。
- 秘密鍵を失った場合は、新しい鍵を生成し、GitHub側で旧Deploy Keyを撤去・新公開鍵を登録する。安全な保管・復旧方法を別途確認する。
- `Allow write access`は有効にしない。

### 5.2 Argo CD Repository Secretの再登録

```powershell
$repoSsh = "git@github.com:YOUR_OWNER/YOUR_PRIVATE_REPOSITORY.git"

kubectl get secret github-repo-ssh -n argocd --ignore-not-found -o name
# 新クラスターでSecretが存在しない場合のみ実行
kubectl -n argocd create secret generic github-repo-ssh `
  --from-literal=type=git `
  --from-literal="url=$repoSsh" `
  --from-file="sshPrivateKey=$keyPath"

kubectl -n argocd label secret github-repo-ssh `
  argocd.argoproj.io/secret-type=repository --overwrite

kubectl get secret github-repo-ssh -n argocd --show-labels
```

**期待値:** `argocd.argoproj.io/secret-type=repository`ラベルあり。`kubectl get secret -o yaml`等で**秘密鍵内容を表示・共有しない**。Argo CD UIの`Settings > Repositories`で接続状態が`Successful`となることを確認する。

## 6. Argo CD UIへアクセス（外部非公開）

別のPowerShellターミナルで実行する。

```powershell
$env:AWS_PROFILE = "eks-admin"
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

- ブラウザ: `https://localhost:8080`。接続先が自分のPort Forwardであることを確認する。
- 初回ログインは`admin`と初期パスワード。パスワードをGitや手順書に書かない。
- 初期パスワードを取得する場合は端末に平文表示せず、一時的にクリップボードへ入れる。使用後はクリップボードをクリアする。

```powershell
$encoded = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
$password = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encoded))
Set-Clipboard -Value $password
Remove-Variable encoded, password
```

初回ログイン後に管理者パスワードを変更し、`kubectl -n argocd delete secret argocd-initial-admin-secret`で初期パスワードSecretを削除する（パスワード変更後に限る）。初回パスワードは環境再構築ごとに新たに生成される。

## 7. Applicationを復元し、初回Syncする

なお、公開用KustomizeのECR URIとDigestはダミー値のため、そのままではPodは正常稼働しない。実環境での検証には有効なECRイメージへの置き換えが必要。

```powershell
cd $repoRoot

# Kustomizeの構文・マニフェスト生成確認
kubectl kustomize .\k8s\overlays\dev
kubectl apply --dry-run=client -f .\gitops\apps\dev-application.yaml
kubectl get applications -n argocd
```

`gitops-demo-dev`はAuto SyncとSelf-Healを有効化済みのため、Gitとの差分が発生すると自動同期される。UIでDiffを確認し、同期状態が`Synced / Healthy`になることを確認する。`Prune`は無効、`Force`は使用しない。`gitops-demo` NamespaceはOverlayで宣言しており、`CreateNamespace=false`を維持する。


```powershell
kubectl get application gitops-demo-dev -n argocd
kubectl rollout status deployment/eks-gitops-app -n gitops-demo --timeout=300s
kubectl get deployments,pods,svc -n gitops-demo
```

**期待値:** Applicationが`Synced / Healthy`、DeploymentのRollout成功、アプリPod 2台が`Running`・Ready、ServiceはClusterIP。必要に応じて既存のService Port Forward手順で`GET /`と`GET /health`を再検証する。

## 8. 障害時の切り分け

| 症状 | 最初に確認する事項 |
|---|---|
| GitHub接続が失敗 | Deploy Keyの登録・読み取り権限、Repository URL、Secretラベル、SSHホスト鍵検証 |
| `OutOfSync`が続く | Argo CDのDiff、Application Conditions、Gitブランチ・Overlay・生成Manifest |
| `Progressing` / `Degraded` | `kubectl describe pod`、Events、Probe、Podのイメージ取得状況 |
| `ImagePullBackOff` | ECR Digestの存在、Lifecycle削除、Node RoleのECR Pull権限、ネットワーク |
| Podが`Pending` | Worker NodeのReadyとCPU/メモリ空き、スケジューリングイベント |
| EKS APIに接続不可 | `eks-admin` SSO期限、Access Entry、接続元IPv4 `/32`、`kubeconfig` |

検証例：

```powershell
kubectl describe application gitops-demo-dev -n argocd
kubectl get events -n gitops-demo --sort-by=.lastTimestamp
kubectl get pods -n gitops-demo -o wide
kubectl describe deployment eks-gitops-app -n gitops-demo
```

**安全原則:** 原因未確認のまま`kubectl delete -k`、`helm uninstall`、`terraform apply/destroy`を実行しない。

## 9. 開発終了時の安全な撤収（AWS時間課金停止）

1. Argo CD Applicationの同期状態と変更履歴を確認する。必要な証跡は個人情報を伏せて保存する。
2. Kubernetesが作成したAWS外部リソースの有無を確認する。**LoadBalancer Service / Ingressにより作成されたAWS LBは、EKS削除前に適切に削除する**。PVC/PVに紐づくEBSも確認する。
3. 現行構成のようにArgo CD／アプリがクラスター内に閉じている場合、クラスター全体をDestroyする前に、**無理にApplicationやHelm Releaseを手動削除する必要はない**。ただし外部リソースの削除確認を優先する。
4. `terraform-bootstrap`に切り替え、**`environments/dev/`のStateだけ**でDestroy Planを確認する。
5. 問題なければTerraform Destroyを実行し、AWS側のリソース残存も確認する。

```powershell
$env:AWS_PROFILE = "eks-admin"
kubectl get svc -A
kubectl get ingress -A
kubectl get pvc -A
kubectl get pv
kubectl get application -n argocd

$env:AWS_PROFILE = "terraform-bootstrap"
aws sso login --profile terraform-bootstrap
aws sts get-caller-identity
# 別PowerShellを開いた場合、3.1のTF_VAR_*を再設定してから実施
cd "$repoRoot\environments\dev"
```
実際のPrivate検証環境では、作業終了時に`environments/dev/`のTerraform Stateを使用してDestroyを実施した。

公開用ポートフォリオでは、実際のTerraform StateおよびBackend設定を含めないため、Destroyコマンドは実行しない。

リソース削除が必要な場合は、利用者自身のAWSアカウント、Terraform State、Backend設定、削除対象を確認した上で実施する。


**重要:** `bootstrap/`、`environments/dev/registry/`、`environments/dev/ci/`ではDestroyしない。ECR・GitHub OIDC・S3 Backend・GitHub Deploy Key・ローカルSSH鍵は保持する。AWS側のEKS、Node Group、NAT Gateway、EIP、LB等の残存を確認し、次の起動まで時間課金を抑える。

## 10. Git管理・公開用ポートフォリオ

本リポジトリは、Private環境で実装・検証したコードを
公開向けに匿名化したスナップショットです。

Private環境のGit履歴は引き継ぎません。

公開前には以下を確認します。

- AWSアカウント番号、S3バケット名、認証情報が含まれていないこと
- エビデンス画像に公開できない識別情報が含まれていないこと
- KustomizeのECR URIとDigestが公開用ダミー値であること
- Terraform Stateや秘密鍵などが含まれていないこと
- Gitleaksの検査が成功していること

監査が完了した後、新しい公開用Gitリポジトリを作成し、
初期Commitを行います。

Private環境の稼働用リポジトリには変更を加えません。

## 11. 完了判定・現時点の証跡

- **2026-11-03確認:** `gitops-demo-dev`が`Synced / Healthy`。
- **2026-11-03確認:** `deployment/eks-gitops-app`のRollout成功。
- **2026-11-03確認:** アプリPod 2台が`1/1 Running`、再起動0回。
- **未確認:** このRunbookどおりのEKS Destroy → 完全再構築を通したリハーサル（将来の検証項目）。
- **運用上の制約:** SSH秘密鍵はGitに保存しないため、安全なローカル保管と復旧または鍵ローテーションの手順が必要。

## 12. 公式参考資料

- [Argo CD: Installation](https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/)
- [Argo CD: Declarative Setup / Repository Secret](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/)
- [Argo CD: Getting Started](https://argo-cd.readthedocs.io/en/stable/getting_started/)
- [Argo Helm Chart](https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd)
- [AWS: Delete an EKS Cluster](https://docs.aws.amazon.com/eks/latest/userguide/delete-cluster.html)
