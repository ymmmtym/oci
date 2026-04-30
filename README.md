# OCI Always Free Tier Infrastructure

Oracle Cloud Infrastructure (OCI) のAlways Free枠を活用したインフラ構築用Terraformプロジェクト。

## 構成リソース

### ネットワーク
- **VCN**: 10.0.0.0/16
- **パブリックサブネット**: 10.0.1.0/24
- **プライベートサブネット**: 10.0.2.0/24
- **Internet Gateway**
- **セキュリティリスト**: SSH(22), HTTP(80), HTTPS(443)

### コンピューティング
- **VM.Standard.E2.1.Micro** × 2台 (AMD)
- **VM.Standard.A1.Flex** × 1台 (Ampere ARM, 4 OCPU, 24GB RAM)

### ストレージ
- **Object Storage Bucket**: 20GB

## セットアップ

### 前提条件
- Terraform 1.0以上
- OCI APIキー (秘密鍵、フィンガープリント)
- SSH公開鍵

### 認証設定

`.auto.tfvars` ファイルを作成:

```hcl
tenancy_ocid = "ocid1.tenancy.oc1..aaaaaaaxxxxx"
user_ocid    = "ocid1.user.oc1..aaaaaaaxxxxx"
fingerprint  = "xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx"
region       = "ap-osaka-1"
private_key  = "-----BEGIN PRIVATE KEY-----\nMIIE...\n-----END PRIVATE KEY-----\n"
```

**重要**: `private_key` は改行を `\n` でエスケープして1行で記述してください。

または環境変数で設定:

```bash
export TF_VAR_tenancy_ocid="ocid1.tenancy.oc1..aaaaaaaxxxxx"
export TF_VAR_user_ocid="ocid1.user.oc1..aaaaaaaxxxxx"
export TF_VAR_fingerprint="xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx"
export TF_VAR_region="ap-osaka-1"
export TF_VAR_private_key="$(cat ~/.oci/oci_api_key.pem)"
```

### デプロイ

```bash
terraform init
terraform plan
terraform apply
```

### 削除

```bash
terraform destroy
```

## SSHアクセス

```bash
ssh opc@<public-ip>
```

パブリックIPは `terraform output` で確認できます:

```bash
terraform output instance_public_ips  # Microインスタンス
terraform output ampere_public_ip     # Ampereインスタンス
```

## Always Free枠の制限

| リソース | 利用量 | 無料枠上限 |
|---------|--------|-----------|
| コンピューティング (AMD) | 2 Micro | 2 Micro |
| コンピューティング (ARM) | 4 OCPU, 24GB | 4 OCPU, 24GB |
| ブロックボリューム | - | 200GB |
| Object Storage | 20GB | 20GB |
| データ転送 | - | 10TB/月 |

## トラブルシューティング

### "bad configuration: did not find a proper configuration for private key"
`.auto.tfvars` の `private_key` が改行エスケープされていません。改行を `\n` に置換してください。

### "No value for required variable"
必須変数が未設定です。`.auto.tfvars` または環境変数 `TF_VAR_*` を確認してください。

## ライセンス

MIT
