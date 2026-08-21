#!/bin/bash
# Simple user data for EC2 instance

set -e

APP_PORT=${app_port}

# Update system
yum update -y

# Install basic application (replace with your actual app)
yum install -y httpd

# Create a simple health check
echo "OK" > /var/www/html/health

# Configure Apache to listen on app port
sed -i "s/Listen 80/Listen ${APP_PORT}/g" /etc/httpd/conf/httpd.conf

# Start web server
systemctl start httpd
systemctl enable httpd

# Install CloudWatch Agent for monitoring
yum install -y amazon-cloudwatch-agent

echo "Application setup complete on port ${APP_PORT}"