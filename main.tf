# Create DB subnet group
resource "aws_db_subnet_group" "this" {
  name        = "${var.tag_org}-${var.env}-db-subnet-group"
  description = "Database subnet group for ${var.tag_org}-${var.env}"
  subnet_ids  = var.private_subnet_ids

  tags = merge(
    {
      Name        = "${var.tag_org}-${var.env}-db-subnet-group"
      Environment = var.env
      Organization = var.tag_org
    },
    var.tags
  )
}

# Create security group for RDS instance
resource "aws_security_group" "this" {
  name        = "${var.tag_org}-${var.env}-${var.identifier}-sg"
  description = "Security group for ${var.identifier} RDS instance"
  vpc_id      = var.vpc_id

  tags = merge(
    {
      Name        = "${var.tag_org}-${var.env}-${var.identifier}-sg"
      Environment = var.env
      Organization = var.tag_org
    },
    var.tags
  )
}

# Create ingress rule for allowed security groups
resource "aws_security_group_rule" "allow_security_groups" {
  count = length(var.allowed_security_groups) > 0 ? 1 : 0

  type                     = "ingress"
  from_port                = var.port
  to_port                  = var.port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.this.id
  source_security_group_id = var.allowed_security_groups[0]
}

# Create ingress rules for additional security groups
resource "aws_security_group_rule" "allow_security_groups_additional" {
  count = length(var.allowed_security_groups) > 1 ? length(var.allowed_security_groups) - 1 : 0

  type                     = "ingress"
  from_port                = var.port
  to_port                  = var.port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.this.id
  source_security_group_id = var.allowed_security_groups[count.index + 1]
}

# Create ingress rule for allowed CIDR blocks
resource "aws_security_group_rule" "allow_cidr_blocks" {
  count = length(var.allowed_cidr_blocks) > 0 ? 1 : 0

  type              = "ingress"
  from_port         = var.port
  to_port           = var.port
  protocol          = "tcp"
  security_group_id = aws_security_group.this.id
  cidr_blocks       = var.allowed_cidr_blocks
}

# Create a parameter group for PostgreSQL
resource "aws_db_parameter_group" "this" {
  name        = "${var.tag_org}-${var.env}-${var.identifier}-pg"
  family      = "postgres${replace(var.engine_version, "/\\.\\d+$/", "")}"
  description = "Parameter group for ${var.identifier} PostgreSQL instance"

  # Security best practices for PostgreSQL
  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_statement"
    value = "ddl"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  parameter {
    name  = "ssl"
    value = "1"
  }

  tags = merge(
    {
      Name        = "${var.tag_org}-${var.env}-${var.identifier}-pg"
      Environment = var.env
      Organization = var.tag_org
    },
    var.tags
  )
}

# Create IAM role for enhanced monitoring
resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "${var.tag_org}-${var.env}-${var.identifier}-monitoring-role"

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
      Name        = "${var.tag_org}-${var.env}-${var.identifier}-monitoring-role"
      Environment = var.env
      Organization = var.tag_org
    },
    var.tags
  )
}

# Attach policy for enhanced monitoring
resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Create the RDS instance
resource "aws_db_instance" "this" {
  identifier = "${var.tag_org}-${var.env}-${var.identifier}"
  
  # Engine configuration
  engine               = "postgres"
  engine_version       = var.engine_version
  instance_class       = var.instance_class
  
  # Storage configuration
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = var.storage_encrypted
  
  # Database configuration
  db_name  = var.db_name
  username = var.username
  password = var.password
  port     = var.port
  
  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  multi_az               = var.multi_az
  publicly_accessible    = false
  
  # Backup configuration
  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window
  
  # Parameter and option groups
  parameter_group_name = aws_db_parameter_group.this.name
  
  # Monitoring and logs
  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = aws_iam_role.rds_enhanced_monitoring.arn
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  
  # Additional configuration
  apply_immediately   = false
  deletion_protection = var.deletion_protection
  skip_final_snapshot = false
  final_snapshot_identifier = "${var.tag_org}-${var.env}-${var.identifier}-final-snapshot"
  
  # Performance Insights
  performance_insights_enabled = true
  performance_insights_retention_period = 7
  
  # Auto minor version upgrade
  auto_minor_version_upgrade = true
  
  # Enhanced monitoring
  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = aws_iam_role.rds_enhanced_monitoring.arn
  
  tags = merge(
    {
      Name        = "${var.tag_org}-${var.env}-${var.identifier}"
      Environment = var.env
      Organization = var.tag_org
    },
    var.tags
  )
}
