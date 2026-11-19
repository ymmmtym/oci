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

## 死活監視（OCI Monitoring）

`monitoring.tf` で OCI Monitoring のアラームと Notifications のトピック・購読を管理します。Qiita の[手順](https://qiita.com/yosakata/items/da0fff6b96297b91078b)をそのまま Terraform 化したものです。

| コンソール操作 | Terraform リソース |
|---|---|
| トピック（通知先）の作成 | `oci_ons_notification_topic.alarm` |
| メールアドレスの登録 | `oci_ons_subscription.alarm_email` |
| アラーム定義の作成 | `oci_monitoring_alarm.instance_down` |

### 有効化

`alert_email` に通知先メールアドレスを設定すると、トピック・購読・アラームが作成されます。未設定（空文字）の場合は何も作られません。

```hcl
# .auto.tfvars
alert_email = "you@example.com"
```

```bash
terraform apply
```

### メール購読の確認（手動）

`oci_ons_subscription` は作成直後 `PENDING` 状態です。指定したアドレスに届く確認メールの **Confirm subscription** をクリックするまで通知は配信されません。Terraform では代行できないため手動で対応してください。

### アラームの条件

`jp-bastion-01` / `jp-bastion-02` それぞれについて、`oci_computeagent` の `CpuUtilization` が 5 分間まったく届かなくなったら `CRITICAL` で発報します。

```
CpuUtilization[1m]{resourceId = "<instance OCID>"}.absent(5m)
```

- `absent(5m)` は「メトリクスが 5 分間欠損」を意味します（`absent()` のデフォルトは 2 時間なので明示的に短縮）
- インスタンスを正常に停止した場合もメトリクスが止まるため発報します。計画停止のときはアラームを一時無効化してください
- 通知は `PT4H` ごとに再送されます

## ライセンス

MIT
