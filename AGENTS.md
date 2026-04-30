# OCI Terraform プロジェクト - エージェント指示

## プロジェクト概要
Oracle Cloud Infrastructure (OCI) のリソースをTerraformで管理するプロジェクト。Always Free枠を活用した無料インフラ構築が目的。

## 作業時の前提知識

### インフラ構成
- **ネットワーク**: VCN (10.0.0.0/16)、パブリック/プライベートサブネット、IGW/NAT Gateway
- **コンピューティング**: VM.Standard.A1.Flex (1 OCPU, 1GB RAM) Ubuntu 20.04
- **ストレージ**: ブロックボリューム 2 × 10GB
- **ロードバランサー**: 100Mbps ALB (注: Always Free枠は10Mbpsまで)

### 認証設定
2つの認証方法をサポート:
1. `.auto.tfvars` ファイル (private_keyは `\n` でエスケープ必須)
2. 環境変数 `TF_VAR_*`

必須変数: `tenancy_ocid`, `user_ocid`, `fingerprint`, `region`, `private_key`, `ssh_public_key_path`

### SSHアクセス
- デフォルトキー: `~/.ssh/oci_free_key`
- 接続: `ssh opc@<public-ip> -i ~/.ssh/oci_free_key`

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
- ロードバランサーのシェイプは10Mbps推奨 (100Mbpsは有料)

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
| コンピューティング | 1 OCPU, 1GB | 4 OCPU | ✅ |
| ブロックボリューム | 20GB | 200GB | ✅ |
| ロードバランサー | 100Mbps設定 | 10Mbps | ⚠️ 超過 |
| データ転送 | - | 10TB/月 | ✅ |

**重要**: ロードバランサーは現在100Mbps設定だが、無料枠は10Mbpsまで。変更提案時は10Mbpsを推奨。

## コーディング規約

### Terraformスタイル
- `terraform fmt` で自動整形
- リソース名: `snake_case`
- コメント: `#` で意図や制約を説明

### 変更提案時
- 段階的な変更を推奨
- `terraform plan` の出力を確認
- 複雑な変更はブランチ作成を提案
