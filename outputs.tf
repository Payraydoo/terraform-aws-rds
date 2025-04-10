output "instance_id" {
  description = "The RDS instance ID"
  value       = aws_db_instance.this.id
}

output "instance_address" {
  description = "The address of the RDS instance"
  value       = aws_db_instance.this.address
}

output "instance_endpoint" {
  description = "The connection endpoint"
  value       = aws_db_instance.this.endpoint
}

output "instance_port" {
  description = "The database port"
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "The database name"
  value       = aws_db_instance.this.db_name
}

output "security_group_id" {
  description = "The security group ID"
  value       = aws_security_group.this.id
}

output "subnet_group_id" {
  description = "The DB subnet group ID"
  value       = aws_db_subnet_group.this.id
}

output "parameter_group_id" {
  description = "The DB parameter group ID"
  value       = aws_db_parameter_group.this.id
}