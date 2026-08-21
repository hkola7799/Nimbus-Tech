# outputs.tf - Module outputs

output "instance_ids" {
  description = "List of EC2 instance IDs"
  value       = aws_instance.secure_ec2[*].id
}

output "instance_private_ips" {
  description = "List of private IP addresses of EC2 instances"
  value       = aws_instance.secure_ec2[*].private_ip
}

output "instance_public_ips" {
  description = "List of public IP addresses (if any)"
  value       = aws_instance.secure_ec2[*].public_ip
}

output "instance_arn" {
  description = "List of EC2 instance ARNs"
  value       = aws_instance.secure_ec2[*].arn
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.ec2_sg.id
}

output "iam_role_arn" {
  description = "ARN of the IAM role attached to instances"
  value       = aws_iam_role.instance_role.arn
}

output "iam_role_name" {
  description = "Name of the IAM role attached to instances"
  value       = aws_iam_role.instance_role.name
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name"
  value       = var.enable_cloudwatch_agent ? aws_cloudwatch_log_group.app_logs[0].name : null
}

output "cloudwatch_log_group_arn" {
  description = "CloudWatch log group ARN"
  value       = var.enable_cloudwatch_agent ? aws_cloudwatch_log_group.app_logs[0].arn : null
}

output "instance_profile_name" {
  description = "Name of the IAM instance profile"
  value       = aws_iam_instance_profile.instance_profile.name
}

output "ssh_connection_command" {
  description = "Command to connect via SSM session manager"
  value       = "aws ssm start-session --target ${aws_instance.secure_ec2[0].id}"
}

output "all_ssh_commands" {
  description = "SSM session commands for all instances"
  value = [
    for instance in aws_instance.secure_ec2 :
    "aws ssm start-session --target ${instance.id}"
  ]
}