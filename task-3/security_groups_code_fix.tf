# terraform/ssh_remediation.tf
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-nimbus-sg"
  description = "EC2 security group - restricted SSH"
  vpc_id      = var.vpc_id
  
  # OPTION 1: IP whitelist (temporary)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["203.0.113.0/24"]  # Replace with corporate VPN/CIDR
    description = "SSH from corporate network"
  }
  
  # OPTION 2: RECOMMENDED - Session Manager (no SSH ingress)
  # Remove port 22 entirely and use SSM Session Manager
  # This is the preferred modern approach
  
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
    description     = "HTTPS from ALB"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
