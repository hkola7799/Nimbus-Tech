# terraform/s3_remediation.tf
resource "aws_s3_bucket" "nimbus_uploads" {
  bucket = "nimbus-uploads"
  
  # Force all new objects to be private
  force_destroy = false
  
  # Tags for tracking
  tags = {
    Environment = var.environment
    Compliance  = "GDPR"
    Remediated  = "2026-08-20"
  }
}

# Block ALL public access
resource "aws_s3_bucket_public_access_block" "nimbus_uploads_block" {
  bucket = aws_s3_bucket.nimbus_uploads.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Remove existing public ACLs and set ownership
resource "aws_s3_bucket_ownership_controls" "nimbus_uploads_ownership" {
  bucket = aws_s3_bucket.nimbus_uploads.id
  
  rule {
    object_ownership = "BucketOwnerEnforced"  # Forces all objects to be owned by bucket
  }
}

# Enable encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "nimbus_uploads_encryption" {
  bucket = aws_s3_bucket.nimbus_uploads.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Enable access logging (send to separate audit bucket)
resource "aws_s3_bucket_logging" "nimbus_uploads_logging" {
  bucket = aws_s3_bucket.nimbus_uploads.id
  
  target_bucket = aws_s3_bucket.nimbus_audit_logs.id
  target_prefix = "nimbus-uploads-access/"
}

# Python script to remediate existing objects
"""
import boto3

s3 = boto3.client('s3')
bucket = 'nimbus-uploads'

# List and remove public ACLs
response = s3.list_objects_v2(Bucket=bucket)
for obj in response.get('Contents', []):
    s3.put_object_acl(Bucket=bucket, Key=obj['Key'], ACL='private')
