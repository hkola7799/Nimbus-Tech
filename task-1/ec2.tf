# Launch Template
resource "aws_launch_template" "main" {
  name_prefix   = "nimbustech-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = var.instance_type
  
  vpc_security_group_ids = [aws_security_group.ec2.id]
  
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    app_port = var.app_port
  }))
  
  monitoring {
    enabled = true
  }
  
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "nimbustech-ec2"
    }
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "main" {
  name                = "nimbustech-asg"
  vpc_zone_identifier = aws_subnet.private[*].id
  target_group_arns   = [aws_lb_target_group.main.arn]
  health_check_type   = "ELB"
  min_size            = 2
  max_size            = 6
  desired_capacity    = 2
  
  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }
  
  tag {
    key                 = "Name"
    value               = "nimbustech-ec2"
    propagate_at_launch = true
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

# AMI Data Source
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
