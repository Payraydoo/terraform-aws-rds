# Terraform AWS RDS Module

This module creates an AWS RDS PostgreSQL database with security best practices applied.

## Features

- Creates a PostgreSQL RDS instance
- Creates a subnet group using the provided private subnets
- Creates a security group with restricted access
- Implements AWS security best practices:
  - Encryption at rest
  - Backup retention
  - Enhanced monitoring
  - Parameter group for PostgreSQL security settings
  - Multi-AZ deployment option
- Standardized tagging system

## Usage

```hcl
module "rds" {
  source  = "your-org/aws-rds/terraform"
  version = "0.1.0"

  tag_org        = "company"
  env            = "dev"
  vpc_id         = module.vpc.id
  private_subnet_ids = module.vpc.private_subnet_ids
  
  # Database configuration
  identifier      = "myapp"
  engine_version  = "15.3"
  instance_class  = "db.t3.medium"
  allocated_storage = 20
  db_name         = "appdb"
  username        = "dbadmin"
  password        = "YourSecurePassword" # Use AWS Secrets Manager in production
  
  # Security settings
  multi_az        = true
  backup_retention_period = 7
  deletion_protection = true
  
  # Source security group for access
  allowed_security_groups = [module.app.security_group_id]
  
  tags = {
    Project     = "my-project"
    ManagedBy   = "terraform"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0.0 |
| aws | >= 4.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 4.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| tag_org | Organization tag | `string` | n/a | yes |
| env | Environment (dev, staging, prod) | `string` | n/a | yes |
| vpc_id | VPC ID where the DB instance will be created | `string` | n/a | yes |
| private_subnet_ids | List of private subnet IDs | `list(string)` | n/a | yes |
| identifier | The name of the RDS instance | `string` | n/a | yes |
| engine_version | PostgreSQL engine version | `string` | `"15.3"` | no |
| instance_class | The instance type of the RDS instance | `string` | `"db.t3.medium"` | no |
| allocated_storage | The allocated storage in gigabytes | `number` | `20` | no |
| max_allocated_storage | The upper limit to which RDS can automatically scale the storage | `number` | `100` | no |
| db_name | The DB name to create | `string` | n/a | yes |
| username | Username for the master DB user | `string` | n/a | yes |
| password | Password for the master DB user | `string` | n/a | yes |
| port | The port on which the DB accepts connections | `number` | `5432` | no |
| multi_az | Specifies if the RDS instance is multi-AZ | `bool` | `false` | no |
| backup_retention_period | The days to retain backups for | `number` | `7` | no |
| backup_window | The daily time range during which automated backups are created | `string` | `"03:00-04:00"` | no |
| maintenance_window | The window to perform maintenance in | `string` | `"Mon:00:00-Mon:03:00"` | no |
| deletion_protection | If the DB instance should have deletion protection enabled | `bool` | `true` | no |
| storage_encrypted | Specifies whether the DB instance is encrypted | `bool` | `true` | no |
| monitoring_interval | The interval, in seconds, between points when Enhanced Monitoring metrics are collected | `number` | `30` | no |
| allowed_security_groups | List of security group IDs to allow access to the DB | `list(string)` | `[]` | no |
| allowed_cidr_blocks | List of CIDR blocks to allow access to the DB | `list(string)` | `[]` | no |
| tags | Additional tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| instance_id | The RDS instance ID |
| instance_address | The address of the RDS instance |
| instance_endpoint | The connection endpoint |
| instance_port | The database port |
| db_name | The database name |
| security_group_id | The security group ID |
| subnet_group_id | The DB subnet group ID |
| parameter_group_id | The DB parameter group ID |

## Security Best Practices

This module follows AWS security best practices for RDS:

1. **Encryption at rest**: Enabled by default
2. **Network isolation**: Placed in private subnets
3. **Access control**: Security group limits access to specified sources
4. **Backup strategy**: Regular automated backups
5. **Enhanced monitoring**: For performance and security monitoring
6. **Deletion protection**: Enabled by default
7. **PostgreSQL security configurations**: Applied through parameter group
8. **Multi-AZ deployment option**: For high availability

## Cloudflare Integration

To use Cloudflare for DNS records pointing to the database (for admin tools, etc.), you can use the Cloudflare provider:

```hcl
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

resource "cloudflare_record" "db" {
  zone_id = var.cloudflare_zone_id
  name    = "db-admin"
  value   = module.rds.instance_address
  type    = "CNAME"
  ttl     = 1
  proxied = false # Database connections should typically not be proxied
}
```