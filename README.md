# OCI Always Free Tier Infrastructure

Oracle Cloud Infrastructure (OCI) のAlways Free枠を活用したインフラ構築用Terraformプロジェクト。

## クイックスタート

### 1. 認証設定

`.auto.tfvars` を作成:

```hcl
tenancy_ocid = "ocid1.tenancy.oc1..aaaaaaaxxxxx"
user_ocid    = "ocid1.user.oc1..aaaaaaaxxxxx"
fingerprint  = "xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx"
region       = "ap-osaka-1"
private_key  = "-----BEGIN PRIVATE KEY-----\nMIIE...\n-----END PRIVATE KEY-----\n"
```

**注意**: `private_key` は改行を `\n` でエスケープして1行で記述。

### 2. デプロイ

このプロジェクトは **Terraform Cloud**（organization: `yumenomatayume`, workspace: `oci`）をバックエンドとして使用しています。
初回は `terraform login` を実行して API Token を設定してください。

```bash
terraform login
terraform init
terraform plan
terraform apply
```

### 3. 接続

**Compute Instance:**
```bash
terraform output instance_public_ips
ssh opc@<public-ip>
```

**Autonomous Database:**
```bash
terraform output adb_connection_strings
```

管理者パスワードは `adb_admin_password` 変数で設定します。デフォルト値を使用せず、`.auto.tfvars` で必ず変更してください。

## 構成

- **VM.Standard.E2.1.Micro** × 2台 (AMD)
- **VCN**: 10.0.0.0/16（DNSラベル `vcn`、サブネットは `public` / `private`）
- **Object Storage**: 20GB
- **Autonomous Database (ADB) Lite**: Always Free, 1 ECPU, 20GB

インスタンスには VCN Resolver の FQDN が付きます（VCN 内からのみ解決可能）。

```
jp-bastion-01.public.vcn.oraclevcn.com
```

`terraform output instance_fqdns` で確認できます。

メモリ 1GB のため、cloud-init の `user_data` で 2GB のスワップファイル（`/swap`）を作成します。

詳細は `AGENTS.md` を参照。

## バックアップ

`jp-bastion-01` のブートボリュームのみ、日次で 5 世代保持するバックアップポリシーを適用しています（`backup.tf`）。

- スケジュール: 毎日 18:00 UTC（JST 03:00）、増分バックアップ
- 保持: 4 日 18 時間（= 常時 5 世代）
- Always Free のボリュームバックアップはテナント全体で同時 5 個までのため、6 個目が作られないよう保持期間を 5 日より少し短くしています。`jp-bastion-02` にも適用する場合は、保持世代数を減らすか、既存バックアップを削除してください。

ポリシーはユーザー定義（`oci_core_volume_backup_policy`）で作成し、`oci_core_volume_backup_policy_assignment` でブートボリュームに割り当てます。

## ライセンス

MIT
