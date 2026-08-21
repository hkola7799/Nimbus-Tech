# terraform/cloudtrail_remediation.tf
resource "aws_cloudtrail" "nimbus_trail" {
  name                          = "nimbus-multi-region-trail"
  s3_bucket_name                = aws_s3_bucket.nimbus_cloudtrail_logs.id
  s3_key_prefix                 = "cloudtrail/"
  include_global_service_events = true
  is_multi_region_trail         = true  # Ensures ALL regions including us-east-1
  enable_log_file_validation    = true
  enable_logging                = true
  
  # Encrypt logs
  kms_key_id = aws_kms_key.cloudtrail_key.arn
  
  # CloudWatch Logs for monitoring
  cloud_watch_logs_role_arn = aws_iam_role.cloudtrail_cloudwatch_role.arn
  cloud_watch_logs_group_arn = aws_cloudwatch_log_group.cloudtrail_logs.arn
  
  tags = {
    Environment = var.environment
    Purpose     = "Security Audit"
  }
}

# S3 bucket with strict controls
resource "aws_s3_bucket" "nimbus_cloudtrail_logs" {
  bucket = "nimbus-cloudtrail-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = false
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_logs_block" {
  bucket = aws_s3_bucket.nimbus_cloudtrail_logs.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "cloudtrail_logs_policy" {
  bucket = aws_s3_bucket.nimbus_cloudtrail_logs.id
  policy = data.aws_iam_policy_document.cloudtrail_bucket_policy.json
}

data "aws_iam_policy_document" "cloudtrail_bucket_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.nimbus_cloudtrail_logs.arn}/cloudtrail/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

# KMS key for encryption
resource "aws_kms_key" "cloudtrail_key" {
  description             = "KMS key for CloudTrail logs"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}
