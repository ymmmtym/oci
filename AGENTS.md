# OCI Terraform プロジェクト - エージェント指示

## プロジェクト概要
Oracle Cloud Infrastructure (OCI) のリソースをTerraformで管理するプロジェクト。Always Free枠を活用した無料インフラ構築が目的。

## 作業時の前提知識

### インフラ構成（詳細）
- **ネットワーク**: 
  - VCN: 10.0.0.0/16
  - パブリックサブネット: 10.0.1.0/24
  - プライベートサブネット: 10.0.2.0/24
  - Internet Gateway
  - セキュリティリスト: SSH(22), HTTP(80), HTTPS(443)
- **コンピューティング**: VM.Standard.E2.1.Micro × 2台 (AMD)
- **ストレージ**: Object Storage Bucket 20GB

### 認証設定
2つの認証方法をサポート:

**方法1: `.auto.tfvars` ファイル**
```hcl
tenancy_ocid = "ocid1.tenancy.oc1..aaaaaaaxxxxx"
user_ocid    = "ocid1.user.oc1..aaaaaaaxxxxx"
fingerprint  = "xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx"
region       = "ap-osaka-1"
private_key  = "-----BEGIN PRIVATE KEY-----\nMIIE...\n-----END PRIVATE KEY-----\n"
```
**重要**: private_keyは `\n` でエスケープ必須

**方法2: 環境変数**
```bash
export TF_VAR_tenancy_ocid="ocid1.tenancy.oc1..aaaaaaaxxxxx"
export TF_VAR_user_ocid="ocid1.user.oc1..aaaaaaaxxxxx"
export TF_VAR_fingerprint="xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx"
export TF_VAR_region="ap-osaka-1"
export TF_VAR_private_key="$(cat ~/.oci/oci_api_key.pem)"
```

必須変数: `tenancy_ocid`, `user_ocid`, `fingerprint`, `region`, `private_key`, `ssh_public_key_path`

### SSHアクセス
```bash
# パブリックIP確認
terraform output instance_public_ips

# 接続
ssh opc@<public-ip>
```

## Terraform操作ルール

### 基本ワークフロー
```bash
terraform init    # 初回のみ
terraform plan    # 変更確認
terraform apply   # 適用
terraform destroy # 削除
```

### 実行前の確認事項
- `terraform validate` で構文チェック
- `terraform plan` で変更内容を確認
- Always Free枠の制限内か確認

### 変更時の注意
- リソース削除・変更は必ずユーザー確認を取る
- `terraform apply/destroy` 実行前に影響範囲を説明

## トラブルシューティング

### よくあるエラー
1. **"bad configuration: did not find a proper configuration for private key"**
   - `.auto.tfvars` の private_key が改行エスケープされていない
   - 改行を `\n` に置換するか、環境変数でファイルパスを指定

2. **"No value for required variable"**
   - `.auto.tfvars` または環境変数 `TF_VAR_*` が未設定
   - 6つの必須変数すべてを確認

3. **"Invalid multi-line string"**
   - private_key を複数行で記載している
   - 1行に変換して `\n` でエスケープ

### 確認コマンド
```bash
# Terraform状態確認
terraform show

# OCI CLI でリソース確認
oci compute instance list --compartment-id <compartment-ocid>
oci bv volume list --compartment-id <compartment-ocid>
oci lb load-balancer list --compartment-id <compartment-ocid>
oci network vcn list --compartment-id <compartment-ocid>
```

## Always Free枠の制限

| リソース | 利用量 | 無料枠上限 | 状態 |
|---------|--------|-----------|------|
| コンピューティング (AMD) | 2 Micro | 2 Micro | ✅ |
| ブロックボリューム | ~100GB | 200GB | ✅ |
| Object Storage | 20GB | 20GB | ✅ |
| データ転送 | - | 10TB/月 | ✅ |

## コーディング規約

### Terraformスタイル
- `terraform fmt` で自動整形
- リソース名: `snake_case`
- コメント: `#` で意図や制約を説明

### 変更提案時
- 段階的な変更を推奨
- `terraform plan` の出力を確認
- 複雑な変更はブランチ作成を提案

## 開発フロー（GitHub + GitLab Flow）

このプロジェクトでは、変更の可視化・検証・承認を確実に行うため、**GitHub を利用した軽量 GitLab Flow** を採用します。  
`main` ブランチは常に本番環境（OCI Always Free）に直接適用可能な状態を保ち、すべての変更は Pull Request（PR）経由でマージされます。

### ブランチ戦略

| ブランチ名 | 用途 | 命名例 | マージ先 |
|------------|------|---------|------------|
| `main` | ✅ **本番環境に反映される唯一の信頼済みブランチ**<br>→ `terraform apply` はこのブランチから実行<br>→ 直接 push は禁止（保護ブランチ推奨） | `main` | — |
| `feature/xxx` | ✅ 新規リソース追加（例：Load Balancer, Autonomous DB）<br>→ Terraform の `.tf` ファイル追加／変更 | `feature/lb`, `feature/adb` | `main` |
| `issue/xxx` | ✅ 既存の問題対応（例：`.auto.tfvars` のエスケープ修正、セキュリティリストのポート追加） | `issue/1`, `issue/ssh-key-path` | `main` |

### PR（Pull Request）運用ルール

- ✅ **`terraform plan` の出力は必須**：<br>　PR 作成前に `terraform plan -out=plan-xxx.tfplan` を実行し、ファイルを添付するか、`terraform show plan-xxx.tfplan` の出力を PR 説明欄に記載してください。
- ✅ **タイトルは Conventional Commits 準拠**：<br>　`feat(lb): Add public load balancer (Free Tier)` や `fix(tfvars): Escape newlines in private_key...` のように、`feat()` / `fix()` で始めてください。
- ✅ **説明欄には影響範囲を明記**：<br>　例：`✅ Free Tier 制限内（LB: 1台）`、`⚠️ この変更は `terraform apply` 実行後に本番OCIに即時反映されます`。
- ⚠️ **`main` へのマージ前には必ず確認**：<br>　`AGENTS.md` の「Terraform操作ルール」に従い、ユーザーによる `terraform plan` 内容の確認と同意を得てからマージしてください。

### GitHub 設定推奨（管理者向け）

- `main` ブランチを **Branch Protection Rules** で保護：
  - ✅ `Require pull request reviews before merging`（最低1名）
  - ✅ `Require status checks to pass before merging`（CIで `terraform validate` を設定可能）
  - ✅ `Include administrators`（管理者もルール適用）
  - ✅ `Require linear history`
