# variables.tf - Input variables for the secure-ec2 module

variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "secure-ec2"
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_id" {
  description = "VPC ID where resources will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EC2 deployment"
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "instance_count" {
  description = "Number of EC2 instances to create"
  type        = number
  default     = 1
}

variable "ami_id" {
  description = "AMI ID for EC2 instances. If null, uses latest Amazon Linux 2"
  type        = string
  default     = null
}

variable "key_name" {
  description = "Key pair name for SSH (optional - only used for emergency access)"
  type        = string
  default     = null
}

variable "enable_ssh_emergency" {
  description = "Enable SSH as emergency fallback (not recommended)"
  type        = bool
  default     = false
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed for SSH access (only if enable_ssh_emergency is true)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "volume_size" {
  description = "Size of root EBS volume in GB"
  type        = number
  default     = 50
}

variable "volume_type" {
  description = "EBS volume type (gp2, gp3, io1, etc.)"
  type        = string
  default     = "gp3"
}

variable "enable_cloudwatch_agent" {
  description = "Enable CloudWatch agent installation"
  type        = bool
  default     = true
}

variable "cloudwatch_log_group_name" {
  description = "CloudWatch log group name for application logs"
  type        = string
  default     = null
}

variable "cloudwatch_metrics_namespace" {
  description = "CloudWatch namespace for custom metrics"
  type        = string
  default     = "SecureEC2"
}

variable "ssm_managed_policy_arn" {
  description = "ARN of the SSM managed policy (default: AmazonSSMManagedInstanceCore)"
  type        = string
  default     = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

variable "additional_iam_policies" {
  description = "List of additional IAM policy ARNs to attach to instance role"
  type        = list(string)
  default     = []
}

variable "custom_user_data" {
  description = "Custom user data script to run on instance launch (appended to base script)"
  type        = string
  default     = ""
}

variable "enable_termination_protection" {
  description = "Enable termination protection on EC2 instances"
  type        = bool
  default     = false
}

variable "monitoring" {
  description = "Enable detailed monitoring (CloudWatch metrics every 1 minute)"
  type        = bool
  default     = true
}

variable "metadata_http_tokens" {
  description = "IMDSv2 token requirement (optional or required)"
  type        = string
  default     = "required"
  validation {
    condition     = contains(["optional", "required"], var.metadata_http_tokens)
    error_message = "metadata_http_tokens must be either 'optional' or 'required'."
  }
}

variable "security_group_rules" {
  description = "Additional security group rules (ingress and egress)"
  type = list(object({
    type        = string # "ingress" or "egress"
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  default = []
}

variable "cloudwatch_agent_config" {
  description = "Custom CloudWatch agent configuration (JSON string)"
  type        = string
  default     = null
}