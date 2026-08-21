NimbusTech AWS Infrastructure - Plain English Explanation
What We're Building
Let me explain this infrastructure setup in simple terms, like I'm describing it to someone who isn't a cloud expert.

The Big Picture
Imagine we're building a secure office building for NimbusTech's application. We need to make sure:

The application is accessible to customers (public)

The application servers are in a secure area (private)

The database is in a vault (completely private)

Network Layout (VPC)
Think of this as our office building with different security zones:

The Building Itself (VPC)
What: Our entire AWS network

Address range: 10.0.0.0/16 (like having 65,000 possible room numbers)

Purpose: Everything lives inside this network

Public Areas (Public Subnets) - 2 of them
Location: Like the lobby and reception area

Addresses: 10.0.1.0/24 and 10.0.2.0/24

What lives here:

Internet Gateway (front door to the internet)

Application Load Balancer (receptionist directing traffic)

NAT Gateways (secure exit doors for private areas)

Private Areas (Private Subnets) - 2 of them
Location: Like the back office and server room

Addresses: 10.0.3.0/24 and 10.0.4.0/24

What lives here:

Application servers (EC2 instances) - the actual workers

PostgreSQL Database (RDS) - where all data is stored securely

Why 2 of Everything?
High Availability: If one data center (AZ) has issues, the other takes over

Redundancy: Like having a backup generator - we're prepared for failures

The Application Load Balancer (ALB)
Think of this as the reception desk of our application:

Location: Public area (accessible from internet)

Job:

Receives all customer requests (HTTP/HTTPS)

Distributes traffic to healthy application servers

Automatically redirects HTTP to HTTPS (security)

Security: Only allows web traffic (ports 80 and 443)

Application Servers (EC2 + Auto Scaling Group)
EC2 Instances - The Workers
Location: Private area (no direct internet access)

What they do: Run the NimbusTech application

Security: Only accept traffic from the ALB (no one can access them directly)

Communication: They can reach the internet via NAT Gateways (for updates)

Auto Scaling Group - The Workforce Manager
Purpose: Automatically hires/fires workers based on demand

Minimum: 2 workers (always have backup)

Maximum: 6 workers (can scale up during busy times)

Default: 2 workers running

Why: If traffic spikes, more servers spin up automatically

Database (RDS PostgreSQL)
Think of this as the vault where all important data lives:

Location: Deep in private area (completely hidden from public)

What it is: PostgreSQL database (13.7 version)

Security:

Only application servers can talk to it

Encrypted data (like having a locked safe)

No one from the internet can reach it

High Availability: Multi-AZ setup (automatic backup database in another location)

Backup: 30 days of automated backups (like having a time machine)

Internet Access Strategy
Public Access (Inbound)
text
Internet → Internet Gateway → ALB → EC2 → RDS
Customers go through: Front door → Receptionist → Worker → Data Vault

Private Access (Outbound)
text
EC2 → NAT Gateway → Internet (for updates)
Workers can go out for supplies (software updates) but no one can come in directly

Database Access
text
EC2 → RDS (only internally)
Only workers can access the vault, and only for business purposes

Security Groups (The Bouncers)
Each area has security guards (Security Groups) controlling who gets in:

ALB Security Guard
Allows: Web traffic (HTTP/HTTPS) from ANYONE on the internet

Why: This is the public face of the application

EC2 Security Guard
Allows: Only traffic from the ALB on the application port (8080)

Allows: SSH from within the building (for system administrators)

Why: Workers shouldn't be accessible directly from the internet

RDS Security Guard
Allows: Only PostgreSQL traffic from EC2 servers

ALLOWS NOTHING ELSE

Why: Database is TOP SECRET - only application servers can access it

Deployment Strategy
What Gets Deployed:
Network Foundation (VPC + Subnets + Gateways)

Security Groups (The bouncers)

Application Load Balancer (The receptionist)

RDS Database (The vault)

Application Servers (The workers)

Scaling Strategy
CPU Usage > 70%: Add more workers (scale out)

CPU Usage < 30%: Remove workers (scale in)

Health Checks: If a worker is sick (unhealthy), replace it

Cost Considerations
Where Money Goes:
EC2 Instances: t3.medium (balanced performance)

RDS: db.t3.medium (database server)

NAT Gateways: 2 of them (one per AZ) for high availability

Load Balancer: ALB with cross-zone load balancing

Storage: 100GB gp3 (fast, cost-effective)

Cost Optimization Tips:
Use reserved instances for long-term savings

Right-size instances based on actual usage

Consider spot instances for non-production environments

Disaster Recovery Plan
If ONE data center fails:
Automatic failover to the other AZ

No manual intervention needed

Users experience minimal disruption

If AN EC2 instance fails:
Auto Scaling Group automatically replaces it

New instance spins up with the same configuration

If THE DATABASE fails:
Multi-AZ RDS automatically fails over

Secondary database becomes primary (5-10 minute switch)

If THE ENTIRE REGION fails:
Use cross-region backups (RDS snapshots)

Have a disaster recovery plan in another region

Monitoring & Maintenance
What We Watch:
CPU Utilization: Too high? Scale up

Memory Usage: Memory leak? Investigate

Database Connections: Too many? Optimize queries

Application Health: /health endpoint - if fails, replace instance

How We Maintain:
Backups: Daily automated, 30-day retention

Updates: Security patches via auto-update scripts

Logs: CloudWatch for centralized logging

Deployment Commands (Simple Steps)
bash
# 1. Setup (one-time)
terraform init

# 2. Plan (see what will be created)
terraform plan

# 3. Deploy (build everything)
terraform apply

# 4. Destroy (remove everything)
terraform destroy
Questions You Might Have
Q: Why can't the database be public?
A: Security - if the database is public, it's vulnerable to attacks. Keeping it private is standard best practice.

Q: Why use 2 availability zones?
A: Redundancy - if one data center goes down, the other keeps working. This is called "high availability."

Q: Why have 2 NAT Gateways?
A: If one fails, the other still works. Plus, traffic is faster within the same AZ.

Q: What if we get a sudden spike in traffic?
A: Auto Scaling Group will automatically add more EC2 instances to handle the load.

Q: How do we update the application?
A: Create a new launch template with the updated application, then update the Auto Scaling Group to use the new version.

Summary
This architecture gives NimbusTech:

Security: Everything properly segmented, least-privilege access

Availability: No single point of failure

Scalability: Auto-scaling for traffic fluctuations

Performance: Load balanced across multiple servers

Cost-Effective: Only pay for what you use, with auto-scaling

Think of it as building a secure, modern office building with:

A public reception area (ALB)

A private work area (EC2)

A vault for sensitive data (RDS)

Security guards everywhere (Security Groups)

Staff that automatically multiplies when busy (Auto Scaling)

All managed through code (Terraform) so it's reproducible, version-controlled, and can be destroyed/recreated easily.

This infrastructure follows AWS Well-Architected Framework best practices for security, reliability, and cost optimization.

