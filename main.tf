###################################################
# modules/rds-postgresql/main.tf
###################################################

resource "random_id" "db_password" {
  byte_length = var.password_length / 2  # 2 hex chars per byte
  keepers = {
    id = var.identifier
  }
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.subnet_ids
  
  tags = merge(
    {
      Name        = "${var.tag_org}-${var.environment}-db-subnet-group"
      Environment = var.environment
      Organization = var.tag_org
    },
    var.tags
  )
}

resource "aws_security_group" "this" {
  name        = "${var.identifier}-sg"
  description = "Security group for ${var.identifier} RDS instance"
  vpc_id      = var.vpc_id

  tags = merge(
    {
      Name        = "${var.tag_org}-${var.environment}-db-sg"
      Environment = var.environment
      Organization = var.tag_org
    },
    var.tags
  )
}

resource "aws_security_group_rule" "ingress_cidr" {
  count             = length(var.allowed_cidr_blocks) > 0 ? 1 : 0
  type              = "ingress"
  from_port         = var.port
  to_port           = var.port
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.this.id
  description       = "Allow inbound traffic from specified CIDR blocks"
}

resource "aws_security_group_rule" "ingress_sg" {
  count                    = length(var.allowed_security_groups)
  type                     = "ingress"
  from_port                = var.port
  to_port                  = var.port
  protocol                 = "tcp"
  source_security_group_id = var.allowed_security_groups[count.index]
  security_group_id        = aws_security_group.this.id
  description              = "Allow inbound traffic from specified security group"
}

resource "aws_security_group_rule" "egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.this.id
  description       = "Allow all outbound traffic"
}

resource "aws_db_parameter_group" "this" {
  count = var.parameter_group_name == null ? 1 : 0

  name        = "${var.identifier}-pg"
  family      = var.parameter_group_family
  description = "Parameter group for ${var.identifier}"

  dynamic "parameter" {
    for_each = var.parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = lookup(parameter.value, "apply_method", null)
    }
  }

  tags = merge(
    {
      Name        = "${var.tag_org}-${var.environment}-db-parameter-group"
      Environment = var.environment
      Organization = var.tag_org
    },
    var.tags
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role" "monitoring_role" {
  count = var.create_monitoring_role ? 1 : 0

  name               = var.monitoring_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      },
    ]
  })

  tags = merge(
    {
      Name        = "${var.tag_org}-${var.environment}-db-monitoring-role"
      Environment = var.environment
      Organization = var.tag_org
    },
    var.tags
  )
}

resource "aws_iam_role_policy_attachment" "monitoring_policy" {
  count = var.create_monitoring_role ? 1 : 0

  role       = aws_iam_role.monitoring_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${var.identifier}-credentials"
  description = "Credentials for ${var.identifier} PostgreSQL database"
  tags        = merge(
    {
      Name        = "${var.tag_org}-${var.environment}-db-credentials"
      Environment = var.environment
      Organization = var.tag_org
    },
    var.tags
  )
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_id.db_password.hex
    engine   = "postgres"
    host     = aws_db_instance.this.address
    port     = var.port
    dbname   = var.db_name
  })
}

resource "aws_db_instance" "this" {
  identifier        = var.identifier
  engine            = "postgres"
  engine_version    = var.engine_version
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_type      = var.storage_type
  storage_encrypted = var.storage_encrypted
  kms_key_id        = var.kms_key_id

  db_name                = var.db_name
  username               = var.db_username
  password               = random_id.db_password.hex
  port                   = var.port

  vpc_security_group_ids = [aws_security_group.this.id]
  db_subnet_group_name   = aws_db_subnet_group.this.name
  parameter_group_name   = var.parameter_group_name == null ? aws_db_parameter_group.this[0].name : var.parameter_group_name

  # High availability and reliability settings
  multi_az               = var.multi_az
  max_allocated_storage  = var.max_allocated_storage
  backup_retention_period = var.backup_retention_period
  backup_window          = var.backup_window
  maintenance_window     = var.maintenance_window
  deletion_protection    = var.deletion_protection
  skip_final_snapshot    = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.final_snapshot_identifier_prefix}-${var.identifier}-${formatdate("YYYYMMDDHHmmss", timestamp())}"
  
  # Monitoring and performance settings
  monitoring_interval    = var.monitoring_interval
  monitoring_role_arn    = var.create_monitoring_role ? aws_iam_role.monitoring_role[0].arn : null
  performance_insights_enabled = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports
  
  # Update settings
  apply_immediately      = var.apply_immediately
  allow_major_version_upgrade = var.allow_major_version_upgrade
  auto_minor_version_upgrade  = var.auto_minor_version_upgrade

  # Security settings
  iam_database_authentication_enabled = true
  ca_cert_identifier     = "rds-ca-rsa4096-g1"  # Latest CA certificate

  tags = merge(
    {
      Name        = "${var.tag_org}-${var.environment}-postgres-db"
      Environment = var.environment
      Organization = var.tag_org
    },
    var.tags
  )

  lifecycle {
    ignore_changes = [
      password
    ]
  }
}
