# jp-bastion-01 のブートボリュームだけを日次でバックアップする。
# Always Free のボリュームバックアップはテナント全体で同時 5 個までなので、
# 5 世代を保ったまま 6 個目を作らないよう保持期間を 4 日 18 時間にしている
# （スケジュール実行は数時間ずれることがあるため 6 時間の余裕を確保）。
resource "oci_core_volume_backup_policy" "daily" {
  compartment_id = var.tenancy_ocid
  display_name   = "daily-5-generations"
  freeform_tags  = local.tags

  schedules {
    backup_type = "INCREMENTAL"
    period      = "ONE_DAY"

    retention_seconds = 5 * 24 * 60 * 60 - 6 * 60 * 60

    # hour_of_day を反映させるには offset_type = "STRUCTURED" が必須
    offset_type = "STRUCTURED"
    hour_of_day = 18 # UTC = JST 03:00
    time_zone   = "UTC"
  }
}

# micro[0] は display_name が jp-bastion-01 になるインスタンス
resource "oci_core_volume_backup_policy_assignment" "bastion_01" {
  asset_id  = oci_core_instance.micro[0].boot_volume_id
  policy_id = oci_core_volume_backup_policy.daily.id
}
