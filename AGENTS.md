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
- **ストレージ**: Object Storage Bucket 20GB (上限)
- **追加可能なリソース**: 
  - Block Volume (200GB)
  - フレキシブルロードバランサー (1台)
  - ネットワークロードバランサー (1台)
  - Autonomous Database (2インスタンス)
  - VM.Standard.A1.Flex (キャパシティ要確認)

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

4. **"Out of host capacity" または "Capacity unavailable"**
   - VM.Standard.A1.Flexインスタンス作成時に発生
   - ap-osaka-1リージョンでArmインスタンスのキャパシティ不足
   - 他のリージョン（ap-tokyo-1等）を試すまたはAMDインスタンスに切り替え

5. **"Always Free limit exceeded" または "Resource limit exceeded"**
   - Always Free枠の制限を超えている
   - VM.Standard.E2.1.Microは2台のみ、Object Storageは20GBのみなど
   - AGENTS.mdの制限表を確認し、枠内でリソース管理

### 確認コマンド
```bash
# Terraform状態確認
terraform show

# OCI CLI でリソース確認
oci compute instance list
oci bv volume list
oci lb load-balancer list
oci network vcn list

# Always Free枠の制限確認（OCI CLI）
oci limits value list --service-name compute
oci limits value list --service-name block-storage
oci limits value list --service-name object-storage
oci limits value list --service-name load-balancer

# 現在のAlways Free枠確認結果（ap-osaka-1リージョン）
# VM.Standard.A1.Flex: standard-a1-core-count = 4 (OCPU), standard-a1-memory-count = 24 (GB)
# Block Volume: total-free-storage-gb = 200 (GB), backup-count = 5
# Object Storage: storage-bytes = 21474836480 (20GB)
# Load Balancer: lb-flexible-count = 1, lb-flexible-bandwidth-sum = 10 (Mbps)
```

## OCI Always Free枠の詳細（2026年5月公式仕様）

### コンピューティング
- **VM.Standard.E2.1.Micro (AMD)**: 
  - 最大2インスタンス
  - 1/8 OCPU (バースト可能)
  - 1GBメモリ
  - 50 Mbpsインターネット帯域幅
  - Oracle Linux Cloud Developer 8, Oracle Linux, Ubuntu, CentOS
  - **制限**: 既に2台使用中 → 追加不可

- **VM.Standard.A1.Flex (Arm)**: 
  - 最初の3,000 OCPU時間 + 18,000 GBメモリ時間/月
  - 4 OCPU + 24 GBメモリ相当
  - Oracle Linux Cloud Developer, Oracle Linux, Ubuntu
  - Oracle Linux Cloud Developerは8GBメモリ以上が必要
  - **注意**: ap-osaka-1リージョンではキャパシティ不足の可能性あり

### ストレージ
- **Block Volume**: 200GB合計容量（boot volumes + block volumes）
  - 最大5つのバックアップ（boot volumes + block volumes）
  - **制限**: ホームリージョンのみ作成可能
  - **注意**: 現在定義されてない → 追加可能

- **Object Storage**: 20GB合計容量（Standard, Infrequent Access, Archive）
  - 50,000 APIリクエスト/月
  - **制限**: 既に20GB使用中 → 追加不可

### ネットワーク
- **VCN**: 最大2VCN
- **フレキシブルロードバランサー**: 1台（10 Mbps min/max）
- **ネットワークロードバランサー**: 1台
- **Outbound Data Transfer**: 10TB/月
- **Site-to-site VPN**: 最大50 IPSec接続

### データベース
- **Oracle Autonomous Database**: 2インスタンス（各1 OCPU + 20GB）
- **Oracle NoSQL Database**: 
  - 133M読み書き/月
  - 25GBストレージ/テーブル
- **Oracle MySQL HeatWave**: 
  - シングルノードクラスタ
  - 50GBストレージ + 50GBバックアップ

### 重要ポイント
- Always Freeリソースは全OCIアカウント（無料/有料）で利用可能
- コンソールで「Always Free eligible」と表示されるリソースのみ作成可能
- **ホームリージョン制限**: ほとんどのリソースはホームリージョンのみ作成可能
- 有料リソースとの混在は可能だが推奨しない
- サービス制限は「Governance & Administration → Tenancy Management → Limits, Quotas and Usage」で確認可能

## 現在の使用状況とOCI制限確認

| リソース | 利用量 | 無料枠上限 | OCI制限（ap-osaka-1） | 状態 |
|---------|--------|-----------|----------------------|------|
| VM.Standard.E2.1.Micro | 2台 | 2台 | インスタンス制限なし | ✅ **上限到達済み** |
| VM.Standard.A1.Flex (Arm) | 0 | 3,000 OCPU時間/月 | `standard-a1-core-count`: 4<br>`standard-a1-memory-count`: 24 | ✅ **追加可能** |
| Block Volume | 0GB | 200GB | `total-free-storage-gb`: 200<br>`backup-count`: 5 | ✅ **追加可能** |
| Object Storage | 20GB | 20GB | `storage-bytes`: 21474836480 (20GB) | ✅ **上限到達済み** |
| データ転送 | - | 10TB/月 | 未確認 | ✅ **未使用** |
| フレキシブルロードバランサー | 0台 | 1台 | `lb-flexible-count`: 1<br>`lb-flexible-bandwidth-sum`: 10 Mbps | ✅ **追加可能** |
| ネットワークロードバランサー | 0台 | 1台 | `lb-10mbps-micro-count`: 0 | ✅ **追加可能？要確認** |
| Autonomous Database | 0 | 2インスタンス | 未確認 | ✅ **追加可能** |

## VM.Standard.A1.Flexの制限確認結果（2026-05-02 OCI CLI確認）
OCI CLIの`limits value list`で確認した結果：
- `standard-a1-core-count`: 4 OCPU（ADレベル）
- `standard-a1-core-regional-count`: 4 OCPU（リージョンレベル）
- `standard-a1-memory-count`: 24 GB（ADレベル）
- `standard-a1-memory-regional-count`: 24 GB（リージョンレベル）

この制限値は**AP-OSAKA-1リージョンでのAlways Free枠**です。**キャパシティ不足の問題**（Terraformでコメント化されている）は別の問題で、制限枠があっても実際にインスタンスを作成できるかは別途確認が必要です。

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
