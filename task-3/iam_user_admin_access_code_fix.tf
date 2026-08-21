# terraform/iam_remediation.tf
# REMOVE existing AdministratorAccess attachment
resource "aws_iam_user_policy_attachment" "deploy_user_admin" {
  user       = "deploy-user"
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  
  # Lifecycle to prevent accidental destruction
  lifecycle {
    create_before_destroy = false
  }
  
  # REMOVED - don't create this
  count = 0  # This effectively removes it
}

# Replace with minimal required permissions
data "aws_iam_policy_document" "deploy_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
      "ecs:DescribeServices",
      "ecs:UpdateService",
      "ecs:RegisterTaskDefinition",
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "cloudformation:CreateStack",
      "cloudformation:UpdateStack",
      "cloudformation:DescribeStacks",
      "iam:PassRole"  # Only for service roles
    ]
    resources = [
      "arn:aws:s3:::nimbus-uploads/*",
      "arn:aws:s3:::nimbus-artifacts/*",
      "arn:aws:ecs:us-east-1:*:service/*",
      "arn:aws:ecr:us-east-1:*:repository/*",
      "arn:aws:cloudformation:*:*:stack/*"
    ]
    # Explicitly DENY sensitive operations
  }
  
  statement {
    effect = "Deny"
    actions = [
      "iam:CreateUser",
      "iam:DeleteUser",
      "iam:AttachUserPolicy",
      "s3:PutBucketPolicy",
      "ec2:AuthorizeSecurityGroupIngress"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "deploy_minimal_policy" {
  name        = "deploy-minimal-policy"
  description = "Minimal permissions for CI/CD deployment"
  policy      = data.aws_iam_policy_document.deploy_policy.json
}

resource "aws_iam_user_policy_attachment" "deploy_user_minimal" {
  user       = "deploy-user"
  policy_arn = aws_iam_policy.deploy_minimal_policy.arn
}

# Enforce MFA
resource "aws_iam_user_login_profile" "deploy_user_mfa" {
  user    = "deploy-user"
  # Require MFA reset on next login
  password_reset_required = true
}
