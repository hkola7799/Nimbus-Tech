# evidence_collector.py - Automated evidence gathering
import boto3
import json
from datetime import datetime

def collect_evidence():
    """Collects screenshots and JSON output for compliance"""
    evidence = {}
    
    # S3 Public Access
    s3 = boto3.client('s3')
    evidence['s3_public_access'] = s3.get_public_access_block(Bucket='nimbus-uploads')
    
    # RDS Public Accessibility
    rds = boto3.client('rds')
    instances = rds.describe_db_instences()
    evidence['rds_private'] = all(not inst['PubliclyAccessible'] for inst in instances['DBInstances'])
    
    # EC2 Security Group
    ec2 = boto3.client('ec2')
    sgs = ec2.describe_security_groups(
        Filters=[{'Name': 'group-name', 'Values': ['*nimbus*']}]
    )
    evidence['ssh_restricted'] = all(
        not any(rule['CidrIp'] == '0.0.0.0/0' for rule in sg['IpPermissions'] 
                if rule['FromPort'] == 22)
        for sg in sgs['SecurityGroups']
    )
    
    # CloudTrail
    cloudtrail = boto3.client('cloudtrail')
    trails = cloudtrail.describe_trails()
    evidence['cloudtrail_enabled'] = any(
        trail.get('IsMultiRegionTrail') and trail.get('IsLogging')
        for trail in trails['trailList']
    )
    
    # IAM Audit
    iam = boto3.client('iam')
    policies = iam.list_attached_user_policies(UserName='deploy-user')
    evidence['deploy_user'] = not any(
        p['PolicyName'] == 'AdministratorAccess' 
        for p in policies['AttachedPolicies']
    )
    
    # Store evidence in S3 audit bucket
    s3.put_object(
        Bucket='nimbus-audit-evidence',
        Key=f'evidence_{datetime.now().isoformat()}.json',
        Body=json.dumps(evidence, indent=2)
    )
    
    return evidence