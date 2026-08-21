# RDS Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "nimbustech-db-subnet"
  subnet_ids = aws_subnet.private[*].id
  
  tags = {
    Name = "nimbustech-db-subnet"
  }
}

# RDS Instance
resource "aws_db_instance" "main" {
  identifier = "nimbustech-db"
  
  engine         = "postgres"
  engine_version = "13.7"
  
  instance_class    = var.db_instance_class
  allocated_storage = 100
  storage_type      = "gp3"
  
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  
  backup_retention_period = 30
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  multi_az            = true
  storage_encrypted   = true
  deletion_protection = true
  skip_final_snapshot = false
  
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  
  tags = {
    Name = "nimbustech-rds"
  }
}