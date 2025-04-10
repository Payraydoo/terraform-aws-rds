# RDS PostgreSQL Module

This Terraform module creates an Amazon RDS PostgreSQL database with security best practices enabled.

## Features

- Creates an RDS PostgreSQL instance with configurable settings
- Generates a random password using `random_id`
- Stores credentials securely in AWS Secrets Manager
- Sets up security groups with restricted access
- Configures backups, encryption, and monitoring
- Enables enhanced monitoring and performance insights
- Uses parameter groups for database optimization

## Usage

```hcl
module "postgres_db" {
  source = "./modules/rds-postgresql"

  identifier      = "my-postgres-db"
  db_name         = "mydb"
  db_username     = "dbadmin"
  
  vpc_id          = "vpc-12345678"
  subnet_ids      = ["subnet-12345678", "subnet-87654321"]
  
  # Allow connections from specific security groups (e.g., pgAdmin in ECS)
  allowed_security_groups = [module.pgadmin_ecs.security_group_id]
  
  # Optional customizations
  instance_class  = "db.t3.small"
  allocated_storage = 30
  
  tags = {
    Environment = "production"
    Project     = "my-project"
  }
}
```

## Input Variables

See the `variables.tf` file for all available input variables and their descriptions.

## Outputs

See the `outputs.tf` file for all available outputs and their descriptions.

## Security Considerations

This module implements the following security best practices:

1. **Password Management**:
   - Generates random database passwords
   - Stores credentials in AWS Secrets Manager

2. **Network Security**:
   - Places the database in private subnets
   - Restricts access through security groups
   - Allows specifying allowed CIDRs and security groups

3. **Encryption**:
   - Enables storage encryption by default
   - Supports custom KMS keys

4. **Access Control**:
   - Enables IAM database authentication

5. **Monitoring**:
   - Configures enhanced monitoring
   - Enables performance insights
   - Exports logs to CloudWatch

6. **Data Protection**:
   - Enables automated backups
   - Configurable backup retention period
   - Creates final snapshot by default when deleting
   - Enables deletion protection by default

## PgAdmin Integration

This module is designed to work with a separate PgAdmin module running in ECS. The PgAdmin security group ID can be added to the `allowed_security_groups` variable to allow database access.

## Notes

- The password is generated using `random_id` and stored in AWS Secrets Manager
- Modification of certain settings may require instance replacement
- The module uses the latest CA certificate for secure connections