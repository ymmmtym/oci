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

メモリ 1GB のため、cloud-init の `user_data` で 2GB のスワップファイル（`/swap`）を作成します。`user_data` は初回ブート時のみ実行されるため、`metadata["user_data"]` の変更は `ignore_changes` で無視し、インスタンスを作り直したときに反映します（`ssh_authorized_keys` の変更は引き続き検出され、再作成を伴います）。

詳細は `AGENTS.md` を参照。

## 死活監視（OCI Monitoring）

`monitoring.tf` で OCI Monitoring のアラームと Notifications のトピック・購読を管理します。[Qiita の手順](https://qiita.com/yosakata/items/da0fff6b96297b91078b)をベースに、通知先をメールから webhook に変え、absence alarm のパラメータを調整しています。

| コンソール操作 | Terraform リソース |
|---|---|
| トピック（通知先）の作成 | `oci_ons_notification_topic.alarm` |
| webhook URL の登録 | `oci_ons_subscription.alarm_webhook` |
| アラーム定義の作成 | `oci_monitoring_alarm.instance_down` |

### 有効化

`alert_webhook_url` に通知先 URL を設定すると、トピック・購読・アラームが作成されます。未設定（空文字）の場合は何も作られません。購読プロトコルの既定は `SLACK`（Slack Incoming Webhook）です。

```hcl
# .auto.tfvars
alert_webhook_url = "https://hooks.slack.com/services/T000/B000/xxxx"
```

```bash
terraform apply
```

`SLACK` プロトコルでは、OCI がアラームを Slack 用のメッセージに整形して投稿します。タイトルは `Alarm: <type> | <severity> | <title> | <timestamp>` 形式でアラームへのリンク付きになり、`notification_title` に指定した文言がタイトル部分に入ります。

整形にはアラーム側の `message_format = "ONS_OPTIMIZED"` を指定します。未指定だと既定の `RAW` になり、アラーム JSON がそのまま通知本文になります。

Slack Incoming Webhook の URL は `CUSTOM_HTTPS` では使えません。Slack はリクエストに `text` フィールドを要求し、OCI の購読確認リクエスト（`{"ConfirmationURL": "..."}`）を `no_text` で拒否するため、確認が完了せず購読が `PENDING` のまま残ります。Slack に送る場合は必ず `SLACK` を指定してください。

### `CUSTOM_HTTPS` を使う場合

Slack 以外（自前の HTTPS エンドポイントなど）に送る場合は `CUSTOM_HTTPS` を指定します。

```hcl
alert_webhook_url      = "https://user:pass@example.com/hooks/oci-alarm"
alert_webhook_protocol = "CUSTOM_HTTPS"
```

エンドポイントは次の条件を満たす必要があります（[Oracle ドキュメント](https://docs.oracle.com/en-us/iaas/Content/Notification/Tasks/create-subscription-https.htm)）。

- 公開 URL であること（プライベートネットワークの宛先は不可）
- POST を受け付けること。Content-Type はアラーム通知が `text/plain; charset=UTF-8`、購読確認リクエストが `application/json` なので、両方受け付ける
- TLS ハンドシェイクと応答開始が 5 秒以内（接続・読み取りタイムアウトは 5 秒固定）
- 認証は Basic 認証のみ。`https://user:pass@host/path` の形で URL に埋め込む
- 未認証のリクエストには `401` と `WWW-Authenticate: Basic` ヘッダを返す
- クエリパラメータと、利用側が任意に追加するカスタムヘッダは使えない（`?token=...` 形式の URL は不可）

URL に資格情報を埋める代わりに、リクエストの検証は OCI が付与するヘッダで行えます（[標準ヘッダメタデータ](https://docs.oracle.com/en-us/iaas/Content/Notification/Concepts/notificationoverview.htm)）。`X-OCI-NS-Signature` / `X-OCI-NS-Timestamp` / `X-OCI-NS-SignatureVersion` / `X-OCI-NS-SigningCertURL` が付くので、`SigningCertURL` から証明書を取得して署名を検証してください。

### 購読の確認（手動）

`oci_ons_subscription` は作成直後 `PENDING` 状態です。確認を完了するまでアラーム通知は配信されません。確認 URL の有効期限は 3 日で、Terraform では代行できません。

**`CUSTOM_HTTPS` の場合**、Notifications はエンドポイントへ `application/json` の確認リクエストを POST します。確認リクエストへ 200 を返すだけでは `ACTIVE` になりません。次のどちらかから確認 URL を取り出し、その URL を開いて確定させてください。

- リクエストヘッダ `X-OCI-NS-ConfirmationURL`
- リクエストボディの `ConfirmationURL` キー

**`SLACK` の場合**、Slack チャンネルに "To confirm the subscription" で始まる確認メッセージが届くので、その中のリンクを開きます。

`PENDING` のまま期限が切れた場合は購読を作り直してください。

### アラームの条件

`jp-bastion-01` / `jp-bastion-02` それぞれについて、`oci_computeagent` の `CpuUtilization` が 5 分間まったく届かなくなったら `CRITICAL` で発報します。

```
CpuUtilization[1m]{resourceId = "<instance OCID>"}.groupBy(resourceId).absent(3d)
```

- `pending_duration = "PT5M"` が「5 分間継続したら発報」を担います
- `absent(3d)` は absence detection period（メトリクスが欠損し続けたときに `absent()` が値を返し続ける上限）です。デフォルトは 2 時間で、`PT4H` の再通知より先に切れてアラームが `OK` に戻ってしまうため、指定可能な最大値の 3 日まで延ばしています
- ただし absence detection period を過ぎると OCI 側のリセットで `OK` に戻り、通知も止まります。復旧まで通知し続ける保証はないため、長期停止が疑われる場合はコンソールでインスタンス状態を確認してください
- `groupBy(resourceId)` は、OCI が新しいディメンションを追加したときに空のメトリクスストリームで誤発報するのを防ぎます
- インスタンスを正常に停止した場合もメトリクスが止まるため発報します。計画停止のときはアラームを一時無効化してください
- 通知は `PT4H` ごとに再送されます
- `CpuUtilization` は Oracle Cloud Agent の **Compute Instance Monitoring** プラグインが出力します。プラグインが無効・停止しているとメトリクスが届かず常時発報になるため、コンソールの「Oracle Cloud Agent」タブで `RUNNING` になっているか確認してください

## バックアップ

`jp-bastion-01` のブートボリュームのみ、日次バックアップポリシーを適用しています（`backup.tf`）。

- スケジュール: 毎日 18:00 UTC（JST 03:00）、増分バックアップ
- 保持: 4 日 18 時間（通常 4〜5 世代でローテーション）
- Always Free のボリュームバックアップはテナント全体で同時 5 個までのため、6 個目が作られないよう保持期間を 5 日より少し短くしています。`jp-bastion-02` にも適用する場合は、両ボリュームを含むテナント全体のバックアップが合計 5 個以内に収まるよう、保持期間を短縮してください。既存バックアップが枠を消費している場合は、必要に応じて削除してください。

ポリシーはユーザー定義（`oci_core_volume_backup_policy`）で作成し、`oci_core_volume_backup_policy_assignment` でブートボリュームに割り当てます。

## ライセンス

MIT
