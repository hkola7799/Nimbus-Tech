#!/bin/bash
# User data script for secure EC2 instance
# This script configures SSM, CloudWatch agent, and security hardening

set -e

# Variables
ENVIRONMENT="${environment}"
LOG_GROUP="${log_group_name}"
ENABLE_CW_AGENT="${enable_cloudwatch_agent}"
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region/)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id/)

echo "========================================="
echo "Starting EC2 instance bootstrap for ${ENVIRONMENT}"
echo "Instance ID: ${INSTANCE_ID}"
echo "Region: ${REGION}"
echo "========================================="

# Update system
echo "Updating system packages..."
yum update -y
yum install -y jq curl wget

# Install SSM Agent (usually pre-installed on Amazon Linux 2)
echo "Ensuring SSM Agent is running..."
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Configure IMDSv2 (already enforced by Terraform metadata_options)
echo "IMDSv2 enforced via Terraform configuration"

# Install and configure CloudWatch Agent
if [ "${ENABLE_CW_AGENT}" = "true" ]; then
    echo "Installing CloudWatch Agent..."
    
    # Download CloudWatch Agent
    wget -O /tmp/amazon-cloudwatch-agent.rpm \
        https://s3.${REGION}.amazonaws.com/amazoncloudwatch-agent-${REGION}/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
    
    # Install CloudWatch Agent
    rpm -Uvh /tmp/amazon-cloudwatch-agent.rpm
    
    # Create CloudWatch Agent config directory
    mkdir -p /opt/aws/amazon-cloudwatch-agent/etc/
    
    # Generate CloudWatch Agent config
    cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
${cloudwatch_agent_config}
EOF
    
    # Replace instance_id placeholder
    sed -i "s/{instance_id}/${INSTANCE_ID}/g" /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
    
    # Start CloudWatch Agent
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
        -a fetch-config \
        -m ec2 \
        -s \
        -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
    
    echo "CloudWatch Agent configured and started"
else
    echo "CloudWatch Agent installation skipped"
fi

# Custom user data execution
${custom_user_data}

# Install common tools for troubleshooting
echo "Installing additional tools..."
yum install -y htop iotop net-tools nmap-ncat telnet bind-utils

# Configure system settings for security
echo "Configuring system security settings..."

# Disable root login via SSH (if SSH is enabled)
if [ -f /etc/ssh/sshd_config ]; then
    sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    # Reload SSH only if service exists
    if systemctl status sshd &>/dev/null; then
        systemctl reload sshd
    fi
fi

# Set secure umask
echo "umask 027" >> /etc/profile

# Disable unused services
systemctl disable rpcbind 2>/dev/null || true

# Ensure NTP/Chrony is running
yum install -y chrony
systemctl enable chronyd
systemctl start chronyd

# Create application user (optional - customize as needed)
useradd -m -s /bin/bash ec2-app-user 2>/dev/null || true
echo "ec2-app-user ALL=(ALL) NOPASSWD: /usr/bin/systemctl" >> /etc/sudoers.d/ec2-app-user
chmod 440 /etc/sudoers.d/ec2-app-user

# Enable audit logging
systemctl enable auditd
systemctl start auditd

# Set up log rotation for application logs
cat > /etc/logrotate.d/application << 'EOF'
/var/log/application/*.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
    create 0640 ec2-app-user ec2-app-user
}
EOF

mkdir -p /var/log/application
chown ec2-app-user:ec2-app-user /var/log/application

echo "========================================="
echo "Bootstrap completed successfully!"
echo "Instance is ready for SSM access"
echo "========================================="

# Print status
echo "SSM Agent Status: $(systemctl is-active amazon-ssm-agent)"
if [ "${ENABLE_CW_AGENT}" = "true" ]; then
    echo "CloudWatch Agent Status: $(systemctl is-active amazon-cloudwatch-agent 2>/dev/null || echo 'not running')"
fi

# Create a marker file to indicate bootstrap completion
touch /var/log/bootstrap-completed