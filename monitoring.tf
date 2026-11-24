# OCI Monitoring + Notifications によるコンピュート死活監視。
# alert_webhook_url が空のときは何も作らない（webhook 先未設定でも plan が通るようにする）。
locals {
  monitoring_enabled = var.alert_webhook_url != ""
}

resource "oci_ons_notification_topic" "alarm" {
  count          = local.monitoring_enabled ? 1 : 0
  compartment_id = var.tenancy_ocid
  name           = "compute-alarm-topic"
  description    = "Compute instance liveness alarms"
  freeform_tags  = local.tags
}

# 作成直後は PENDING。エンドポイントへ届く確認リクエストに応答するまで通知は配信されない。
resource "oci_ons_subscription" "alarm_webhook" {
  count          = local.monitoring_enabled ? 1 : 0
  compartment_id = var.tenancy_ocid
  endpoint       = var.alert_webhook_url
  protocol       = var.alert_webhook_protocol
  topic_id       = oci_ons_notification_topic.alarm[0].id
}

# CpuUtilization が 5 分間まったく届かなくなったら発報する（= インスタンス停止・OS 停止）。
resource "oci_monitoring_alarm" "instance_down" {
  count = local.monitoring_enabled ? length(oci_core_instance.micro) : 0

  compartment_id = var.tenancy_ocid
  display_name   = format("%s-down", oci_core_instance.micro[count.index].display_name)
  is_enabled     = true
  freeform_tags  = local.tags

  destinations          = [oci_ons_notification_topic.alarm[0].id]
  metric_compartment_id = var.tenancy_ocid
  namespace             = "oci_computeagent"
  query                 = format("CpuUtilization[1m]{resourceId = \"%s\"}.groupBy(resourceId).absent(3d)", oci_core_instance.micro[count.index].id)
  resolution            = "1m"
  severity              = "CRITICAL"
  pending_duration      = "PT5M"

  # ONS_OPTIMIZED を指定しないと RAW（生 JSON）がそのまま本文になる。Slack でも整形される
  message_format               = "ONS_OPTIMIZED"
  notification_title           = "[${oci_core_instance.micro[count.index].display_name}] メトリクスが届いていません"
  alarm_summary                = "インスタンスが停止しているか、Monitoring に到達できていません"
  body                         = "OCI コンソールでインスタンスの状態を確認し、必要なら起動してください。"
  repeat_notification_duration = "PT4H"
}
