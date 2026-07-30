resource "aws_msk_cluster" "main" {
  count                  = var.msk.create ? 1 : 0
  cluster_name           = "${local.pxa_prefix}-msk-main"
  kafka_version          = "3.6.0"
  number_of_broker_nodes = var.msk.new.number_of_broker_nodes

  broker_node_group_info {
    instance_type  = var.msk.new.instance_type
    client_subnets = var.vpc.subnets.private
    storage_info {
      ebs_storage_info {
        volume_size = var.msk.new.volume_size
      }
    }
    security_groups = [aws_security_group.allow_msk[count.index].id]
  }
  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.main[count.index].name
      }
    }
  }
  configuration_info {
    arn      = aws_msk_configuration.main[count.index].arn
    revision = aws_msk_configuration.main[count.index].latest_revision
  }
  encryption_info {
    encryption_in_transit {
      client_broker = "TLS_PLAINTEXT"
    }
  }
  client_authentication {
    unauthenticated = true
  }

  tags = {
    Name        = "${local.pxa_prefix}-msk-main"
    Project     = "${local.pxa_project_name}"
    Customer    = var.PROJECT_CUSTOMER
    Environment = var.PROJECT_ENV
    Terraform   = true
  }
}

resource "aws_appautoscaling_target" "msk_storage" {
  count = var.msk.create && var.msk.new.storage_autoscaling.enabled ? 1 : 0

  service_namespace  = "kafka"
  scalable_dimension = "kafka:broker-storage:VolumeSize"
  resource_id        = aws_msk_cluster.main[0].arn
  # AWS rejects any value greater than 1 here for this scalable dimension
  # ("Minimum capacity cannot be greater than 1") -- the real floor/ceiling
  # for storage scaling is enforced via max_capacity and the target-tracking
  # policy's target_utilization_percent below, not via min_capacity. Sourced
  # from config rather than hardcoded so each environment's json is the
  # single source of truth.
  min_capacity = var.msk.new.storage_autoscaling.min_capacity
  max_capacity = var.msk.new.storage_autoscaling.max_volume_size_gb
}

resource "aws_appautoscaling_policy" "msk_storage" {
  count = var.msk.create && var.msk.new.storage_autoscaling.enabled ? 1 : 0

  name               = "${local.pxa_prefix}-msk-main-storage-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.msk_storage[0].resource_id
  scalable_dimension = aws_appautoscaling_target.msk_storage[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.msk_storage[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "KafkaBrokerStorageUtilization"
    }
    target_value = var.msk.new.storage_autoscaling.target_utilization_percent
  }
}

resource "aws_cloudwatch_log_group" "main" {
  count = var.msk.create ? 1 : 0
  name  = "/aws/msk/${local.pxa_prefix}"

  tags = {
    Name        = "${local.pxa_prefix}-lg-msk-main"
    Project     = "${local.pxa_project_name}"
    Customer    = var.PROJECT_CUSTOMER
    Environment = var.PROJECT_ENV
    Terraform   = true
  }
}

resource "aws_msk_configuration" "main" {
  count          = var.msk.create ? 1 : 0
  kafka_versions = ["3.6.0"]
  name           = "${local.pxa_prefix}-msk-main-config"

  server_properties = <<PROPERTIES
auto.create.topics.enable = true
delete.topic.enable = true
default.replication.factor=3
min.insync.replicas=1
num.io.threads=8
num.network.threads=5
num.partitions=1
num.replica.fetchers=2
offsets.topic.replication.factor=1
replica.lag.time.max.ms=30000
socket.receive.buffer.bytes=102400
socket.request.max.bytes=104857600
socket.send.buffer.bytes=102400
unclean.leader.election.enable=false
zookeeper.session.timeout.ms=18000
PROPERTIES
}
