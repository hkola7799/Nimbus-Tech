#!/usr/bin/env python3
"""
AWS SSM Patch Management - Fleet Remediation Script
Senior AWS/Python Developer - Production Ready
"""

import boto3
import time
import json
import logging
from typing import List, Dict, Any
from datetime import datetime, timedelta
import argparse

# Configure structured logging for CloudWatch
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class SSMPatchManager:
    """Manages SSM patching operations for EC2 fleets"""
    
    def __init__(self, region: str = 'us-east-1'):
        self.ssm = boto3.client('ssm', region_name=region)
        self.ec2 = boto3.client('ec2', region_name=region)
        
    def get_ubuntu_instances(self, tag_filters: Dict[str, str] = None) -> List[str]:
        """
        Get list of Ubuntu EC2 instance IDs with optional tag filtering
        """
        filters = [
            {'Name': 'platform', 'Values': ['ubuntu']},
            {'Name': 'instance-state-name', 'Values': ['running']}
        ]
        
        # Add tag filters if provided
        if tag_filters:
            for key, value in tag_filters.items():
                filters.append({
                    'Name': f'tag:{key}',
                    'Values': [value]
                })
        
        response = self.ec2.describe_instances(Filters=filters)
        instances = []
        
        for reservation in response['Reservations']:
            for instance in reservation['Instances']:
                instances.append(instance['InstanceId'])
        
        logger.info(f"Found {len(instances)} Ubuntu instances to patch")
        return instances
    
    def create_patch_baseline(self, baseline_name: str = 'ubuntu-critical-patch') -> str:
        """
        Create or reuse a patch baseline for Ubuntu critical CVEs
        """
        # Check if baseline exists
        try:
            response = self.ssm.describe_patch_baselines(
                Filters=[{'Key': 'NAME_PREFIX', 'Values': [baseline_name]}]
            )
            if response['BaselineIdentities']:
                baseline_id = response['BaselineIdentities'][0]['BaselineId']
                logger.info(f"Using existing patch baseline: {baseline_id}")
                return baseline_id
        except Exception as e:
            logger.warning(f"Could not check baseline: {e}")
        
        # Create new baseline
        response = self.ssm.create_patch_baseline(
            Name=baseline_name,
            OperatingSystem='UBUNTU',
            GlobalFilters={
                'PatchFilters': [
                    {
                        'Key': 'PRODUCT',
                        'Values': ['Ubuntu*']
                    },
                    {
                        'Key': 'CLASSIFICATION',
                        'Values': ['Security']  # Only security patches
                    },
                    {
                        'Key': 'SEVERITY',
                        'Values': ['Critical', 'Important']  # Prioritize critical
                    }
                ]
            },
            ApprovalRules={
                'PatchRules': [
                    {
                        'PatchFilterGroup': {
                            'PatchFilters': [
                                {'Key': 'PRODUCT', 'Values': ['Ubuntu*']},
                                {'Key': 'CLASSIFICATION', 'Values': ['Security']}
                            ]
                        },
                        'ApproveAfterDays': 0,  # Immediately approve critical
                        'ComplianceLevel': 'CRITICAL'
                    }
                ]
            },
            Description='Patch baseline for Ubuntu critical and important security updates',
            RejectedPatchesAction='ALLOW_AS_DEPENDENCY'
        )
        
        baseline_id = response['BaselineId']
        logger.info(f"Created new patch baseline: {baseline_id}")
        return baseline_id
    
    def run_patch_scan(self, instance_ids: List[str], baseline_id: str) -> Dict[str, Any]:
        """
        Run a patch scan on instances to identify missing patches
        """
        response = self.ssm.send_command(
            InstanceIds=instance_ids,
            DocumentName='AWS-RunPatchBaseline',
            DocumentVersion='$DEFAULT',
            Parameters={
                'Operation': ['Scan'],
                'SnapshotId': ['$LATEST'],
                'PatchBaseline': [baseline_id]
            },
            CloudWatchOutputConfig={
                'CloudWatchLogGroupName': '/aws/ssm/patch-scan',
                'CloudWatchOutputEnabled': True
            },
            TimeoutSeconds=3600,
            Comment='Security patch scan - Critical CVEs'
        )
        
        command_id = response['Command']['CommandId']
        logger.info(f"Patch scan initiated with command ID: {command_id}")
        
        # Wait for completion
        self._wait_for_command_completion(command_id, instance_ids)
        
        # Get results
        return self._get_patch_summary(command_id, instance_ids)
    
    def apply_patches(self, instance_ids: List[str], baseline_id: str) -> Dict[str, Any]:
        """
        Apply patches to instances with reboot handling
        """
        response = self.ssm.send_command(
            InstanceIds=instance_ids,
            DocumentName='AWS-RunPatchBaseline',
            DocumentVersion='$DEFAULT',
            Parameters={
                'Operation': ['Install'],
                'RebootOption': ['RebootIfNeeded'],  # Critical for kernel updates
                'SnapshotId': ['$LATEST'],
                'PatchBaseline': [baseline_id]
            },
            CloudWatchOutputConfig={
                'CloudWatchLogGroupName': '/aws/ssm/patch-install',
                'CloudWatchOutputEnabled': True
            },
            TimeoutSeconds=7200,  # 2 hours for large patches
            Comment='Security patch installation - Critical CVEs'
        )
        
        command_id = response['Command']['CommandId']
        logger.info(f"Patch installation initiated with command ID: {command_id}")
        
        # Wait for completion
        self._wait_for_command_completion(command_id, instance_ids)
        
        # Verify patches
        return self._verify_patches(instance_ids, baseline_id)
    
    def _wait_for_command_completion(self, command_id: str, instance_ids: List[str], 
                                     timeout: int = 7200) -> None:
        """
        Wait for SSM command to complete on all instances
        """
        start_time = time.time()
        completed = set()
        
        while len(completed) < len(instance_ids):
            if time.time() - start_time > timeout:
                raise TimeoutError(f"Command {command_id} timed out after {timeout} seconds")
            
            response = self.ssm.list_commands(CommandId=command_id)
            command_status = response['Commands'][0]['Status']
            
            if command_status in ['Success', 'Failed', 'Cancelled', 'TimedOut']:
                # Check each instance
                inv_response = self.ssm.list_command_invocations(
                    CommandId=command_id,
                    Details=True
                )
                
                for invocation in inv_response['CommandInvocations']:
                    instance_id = invocation['InstanceId']
                    status = invocation['Status']
                    
                    if status in ['Success', 'Failed', 'Cancelled', 'TimedOut']:
                        completed.add(instance_id)
                        logger.info(f"Instance {instance_id}: {status}")
            
            time.sleep(30)  # Check every 30 seconds
            logger.info(f"Progress: {len(completed)}/{len(instance_ids)} instances completed")
    
    def _get_patch_summary(self, command_id: str, instance_ids: List[str]) -> Dict[str, Any]:
        """
        Get patch scan summary for all instances
        """
        summary = {
            'total_instances': len(instance_ids),
            'patched_instances': [],
            'missing_patches': {},
            'status': 'PENDING'
        }
        
        response = self.ssm.list_command_invocations(
            CommandId=command_id,
            Details=True
        )
        
        for invocation in response['CommandInvocations']:
            instance_id = invocation['InstanceId']
            status = invocation['Status']
            
            if status == 'Success':
                # Parse output for patch details
                output = invocation.get('CommandPlugins', [{}])[0].get('Output', '')
                summary['patched_instances'].append({
                    'instance_id': instance_id,
                    'status': status,
                    'output': output
                })
                
                # Extract missing patches count
                if 'Missing patches:' in output:
                    count = output.split('Missing patches:')[1].split()[0]
                    summary['missing_patches'][instance_id] = int(count)
            else:
                logger.warning(f"Instance {instance_id} patch scan failed: {status}")
        
        summary['status'] = 'COMPLETED'
        return summary
    
    def _verify_patches(self, instance_ids: List[str], baseline_id: str) -> Dict[str, Any]:
        """
        Verify patches were successfully applied
        """
        logger.info("Running verification scan...")
        
        # Run a second scan to verify patches
        scan_response = self.ssm.send_command(
            InstanceIds=instance_ids,
            DocumentName='AWS-RunPatchBaseline',
            Parameters={
                'Operation': ['Scan'],
                'SnapshotId': ['$LATEST'],
                'PatchBaseline': [baseline_id]
            },
            TimeoutSeconds=3600
        )
        
        command_id = scan_response['Command']['CommandId']
        self._wait_for_command_completion(command_id, instance_ids)
        
        results = self._get_patch_summary(command_id, instance_ids)
        results['verification'] = 'COMPLETED'
        
        # Check if any critical patches remain
        remaining_critical = sum(results['missing_patches'].values())
        results['critical_patches_remaining'] = remaining_critical
        
        if remaining_critical == 0:
            logger.info("✅ All critical patches applied successfully!")
        else:
            logger.warning(f"⚠️ {remaining_critical} critical patches still missing")
        
        return results
    
    def generate_patch_report(self, results: Dict[str, Any]) -> str:
        """
        Generate a human-readable patch report for compliance
        """
        report = []
        report.append("=" * 80)
        report.append("NIMBUS PATCH COMPLIANCE REPORT")
        report.append(f"Generated: {datetime.now().isoformat()}")
        report.append("=" * 80)
        report.append(f"Total Instances: {results['total_instances']}")
        report.append(f"Patched: {len(results.get('patched_instances', []))}")
        report.append(f"Critical Patches Remaining: {results.get('critical_patches_remaining', 0)}")
        
        if results.get('critical_patches_remaining', 0) > 0:
            report.append("\n⚠️ INSTANCES REQUIRING ADDITIONAL PATCHING:")
            for instance_id, count in results.get('missing_patches', {}).items():
                if count > 0:
                    report.append(f"  - {instance_id}: {count} patches missing")
        
        report.append("\n" + "=" * 80)
        report.append("RECOMMENDATION: Schedule recurring patching maintenance windows")
        report.append("=" * 80)
        
        return "\n".join(report)


def main():
    """Main execution function"""
    parser = argparse.ArgumentParser(description='Patch Ubuntu EC2 instances with SSM')
    parser.add_argument('--region', default='us-east-1', help='AWS region')
    parser.add_argument('--tag-key', help='Filter instances by tag key')
    parser.add_argument('--tag-value', help='Filter instances by tag value')
    parser.add_argument('--dry-run', action='store_true', help='Scan only, no patching')
    
    args = parser.parse_args()
    
    # Initialize manager
    manager = SSMPatchManager(region=args.region)
    
    # Get instances
    tag_filters = {}
    if args.tag_key and args.tag_value:
        tag_filters[args.tag_key] = args.tag_value
    
    instance_ids = manager.get_ubuntu_instances(tag_filters)
    if not instance_ids:
        logger.warning("No Ubuntu instances found to patch")
        return
    
    logger.info(f"Starting patch remediation on {len(instance_ids)} instances")
    
    # Create or get patch baseline
    baseline_id = manager.create_patch_baseline()
    
    if args.dry_run:
        logger.info("🔄 DRY RUN: Performing patch scan only")
        results = manager.run_patch_scan(instance_ids, baseline_id)
    else:
        logger.info("🔧 PRODUCTION: Applying patches")
        results = manager.apply_patches(instance_ids, baseline_id)
    
    # Generate and log report
    report = manager.generate_patch_report(results)
    logger.info("\n" + report)
    
    # Save report for client
    with open(f'patch_report_{datetime.now().strftime("%Y%m%d_%H%M%S")}.txt', 'w') as f:
        f.write(report)
    
    # Exit with appropriate code
    if results.get('critical_patches_remaining', 0) > 0:
        exit(1)  # Some patches still missing
    exit(0)


if __name__ == '__main__':
    main()