# main.tf - Core module resources

locals {
  ami_id = var.ami_id != null ? var.ami_id : data.aws_ami.amazon_linux_2[0].id

  name_prefix = var.name_prefix
  common_tags = merge({
    Name        = var.name_prefix
    Environment = var.environment
    ManagedBy   = "Terraform"
    SSMAccess   = "true"
    IMDSv2      = "enforced"
  }, var.tags)

  # Determine SSH access
  enable_ssh = var.enable_ssh_emergency && length(var.allowed_ssh_cidrs) > 0

  # CloudWatch log group name
  log_group_name = var.cloudwatch_log_group_name != null ? var.cloudwatch_log_group_name : "/ec2/${var.name_prefix}"

  # Render user data template
  user_data_template = templatefile("${path.module}/user-data/user_data.sh.tpl", {
    enable_cloudwatch_agent = var.enable_cloudwatch_agent
    log_group_name          = local.log_group_name
    environment             = var.environment
    custom_user_data        = var.custom_user_data
  })

  # Render CloudWatch agent config
  cloudwatch_agent_config = var.cloudwatch_agent_config != null ? var.cloudwatch_agent_config : templatefile("${path.module}/templates/cloudwatch-agent-config.json.tpl", {
    namespace    = var.cloudwatch_metrics_namespace
    log_group    = local.log_group_name
    region       = data.aws_region.current.name
    instance_id  = "$${instance_id}" # Will be replaced by sed in user_data
  })
}

# IAM Role for EC2 instances
resource "aws_iam_role" "instance_role" {
  name = "${var.name_prefix}-role-${var.environment}"

  assume_role_policy = data.aws_iam_policy_document.instance_assume_role.json

  managed_policy_arns = concat(
    [var.ssm_managed_policy_arn],
    var.additional_iam_policies
  )

  inline_policy {
    name = "${var.name_prefix}-inline-policy"
    policy = data.aws_iam_policy_document.instance_policy.json
  }

  tags = local.common_tags
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "instance_profile" {
  name = "${var.name_prefix}-profile-${var.environment}"
  role = aws_iam_role.instance_role.name

  tags = local.common_tags
}

# Security Group for EC2 instances
resource "aws_security_group" "ec2_sg" {
  name_prefix = "${var.name_prefix}-sg-"
  vpc_id      = var.vpc_id
  description = "Security group for secure EC2 instances with SSM access only"

  # Egress - Allow all outbound (common practice for private subnets)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  # SSM VPC Endpoint Access (HTTPS)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_id]
    description = "HTTPS from VPC (for SSM, S3, CloudWatch)"
  }

  # Optional SSH access for emergency
  dynamic "ingress" {
    for_each = local.enable_ssh ? [1] : []
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.allowed_ssh_cidrs
      description = "Emergency SSH access"
    }
  }

  # Additional custom rules
  dynamic "ingress" {
    for_each = [for rule in var.security_group_rules : rule if rule.type == "ingress"]
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      description = ingress.value.description
    }
  }

  dynamic "egress" {
    for_each = [for rule in var.security_group_rules : rule if rule.type == "egress"]
    content {
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
      description = egress.value.description
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-sg-${var.environment}"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# AWS Security Group Rule for VPC Endpoints (if VPC endpoints exist)
# This allows instances to access SSM, SSM Messages, and EC2 Messages
resource "aws_security_group_rule" "ssm_endpoints" {
  count = var.vpc_id != "" ? 1 : 0

  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.ec2_sg.id
  cidr_blocks       = [var.vpc_id]
  description       = "Allow HTTPS to VPC endpoints (SSM, S3, CloudWatch)"
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "app_logs" {
  count = var.enable_cloudwatch_agent ? 1 : 0

  name              = local.log_group_name
  retention_in_days = 30

  tags = local.common_tags
}

# EC2 Instances
resource "aws_instance" "secure_ec2" {
  count = var.instance_count

  ami                         = local.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.private_subnet_ids[count.index % length(var.private_subnet_ids)]
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.instance_profile.name
  key_name                    = local.enable_ssh ? var.key_name : null
  user_data_base64            = base64encode(local.user_data_template)
  user_data_replace_on_change = true

  # EBS Volume
  root_block_device {
    volume_size = var.volume_size
    volume_type = var.volume_type
    encrypted   = true
    tags        = local.common_tags
  }

  # Metadata options - Enforce IMDSv2
  metadata_options {
    http_tokens                 = var.metadata_http_tokens == "required" ? "required" : "optional"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  # Detailed monitoring
  monitoring = var.monitoring

  # Termination protection
  disable_api_termination = var.enable_termination_protection

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-${var.environment}-${count.index + 1}"
  })

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      ami, # Allow AMI updates without replace
    ]
  }

  depends_on = [
    aws_cloudwatch_log_group.app_logs
  ]
}

# Elastic IPs (optional - only if instances need to be reachable from internet)
# Note: Typically not needed for private subnets
resource "aws_eip" "instance_eip" {
  count = 0

  instance = aws_instance.secure_ec2[count.index]
  vpc      = true

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-eip-${var.environment}-${count.index + 1}"
  })
}

# SNS Topic for Alerts (Optional)
resource "aws_sns_topic" "ec2_alerts" {
  count = 0

  name = "${var.name_prefix}-alerts-${var.environment}"

  tags = local.common_tags
}