# terraform/rds_remediation.tf
resource "aws_db_instance" "nimbus_database" {
  # ... existing configuration ...
  
  publicly_accessible = false  # CRITICAL FIX
  
  # Ensure it's in private subnets
  db_subnet_group_name = aws_db_subnet_group.private.name
  
  # Enable encryption at rest
  storage_encrypted = true
  
  # Enable automated backups
  backup_retention_period = 30
}

# Network ACLs to restrict traffic
resource "aws_security_group" "rds_sg" {
  name        = "rds-nimbus-sg"
  description = "RDS security group - private only"
  vpc_id      = var.vpc_id
  
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]  # Only app tier
    description     = "Allow app tier access"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

 