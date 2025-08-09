# Terraform configuration for comprehensive IAM security policies
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Variables
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "devops-security"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be development, staging, or production."
  }
}

variable "allowed_regions" {
  description = "List of allowed AWS regions"
  type        = list(string)
  default     = ["us-east-1", "us-west-2"]
}

variable "external_id" {
  description = "External ID for cross-account access"
  type        = string
  default     = "secure-external-id"
  sensitive   = true
}

# Permissions boundary policy
resource "aws_iam_policy" "permissions_boundary" {
  name        = "${var.project_name}-permissions-boundary"
  description = "Permissions boundary to limit maximum privileges"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowBasicAWSServiceInteractions"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:/aws/${var.project_name}/*"
      },
      {
        Sid    = "AllowCloudWatchMetrics"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "cloudwatch:namespace" = "${var.project_name}/*"
          }
        }
      },
      {
        Sid    = "AllowS3AccessToProjectBuckets"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-*",
          "arn:aws:s3:::${var.project_name}-*/*"
        ]
      },
      {
        Sid    = "DenyAccessToSensitiveServices"
        Effect = "Deny"
        Action = [
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:CreateUser",
          "iam:DeleteUser",
          "iam:AttachUserPolicy",
          "iam:DetachUserPolicy",
          "organizations:*",
          "account:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyAccessToOtherAccounts"
        Effect = "Deny"
        Action = "*"
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:PrincipalAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "RestrictToAllowedRegions"
        Effect = "Deny"
        Action = "*"
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion" = var.allowed_regions
          }
          Bool = {
            "aws:ViaAWSService" = "false"
          }
        }
      }
    ]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# Cross-account CI/CD role
resource "aws_iam_role" "cross_account_cicd" {
  name                 = "${var.project_name}-${var.environment}-cicd-role"
  max_session_duration = 3600  # 1 hour
  permissions_boundary = aws_iam_policy.permissions_boundary.arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.external_id
          }
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
          DateGreaterThan = {
            "aws:CurrentTime" = "2024-01-01T00:00:00Z"
          }
          DateLessThan = {
            "aws:CurrentTime" = "2025-12-31T23:59:59Z"
          }
        }
      }
    ]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# CI/CD deployment policy
resource "aws_iam_role_policy" "cicd_deployment" {
  name = "${var.project_name}-cicd-deployment-policy"
  role = aws_iam_role.cross_account_cicd.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudFormationPermissions"
        Effect = "Allow"
        Action = [
          "cloudformation:CreateStack",
          "cloudformation:UpdateStack",
          "cloudformation:DeleteStack",
          "cloudformation:DescribeStacks",
          "cloudformation:DescribeStackEvents",
          "cloudformation:DescribeStackResources",
          "cloudformation:ValidateTemplate",
          "cloudformation:GetTemplate"
        ]
        Resource = "arn:aws:cloudformation:*:${data.aws_caller_identity.current.account_id}:stack/${var.project_name}-*"
      },
      {
        Sid    = "S3DeploymentArtifacts"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-deployment-artifacts",
          "arn:aws:s3:::${var.project_name}-deployment-artifacts/*"
        ]
      },
      {
        Sid    = "IAMPermissionsRestricted"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:UpdateRole",
          "iam:DeleteRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRole",
          "iam:ListRolePolicies",
          "iam:PassRole"
        ]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-*"
        Condition = {
          StringEquals = {
            "iam:PermissionsBoundary" = aws_iam_policy.permissions_boundary.arn
          }
        }
      },
      {
        Sid    = "DenyDangerousIAMActions"
        Effect = "Deny"
        Action = [
          "iam:CreateUser",
          "iam:CreateAccessKey",
          "iam:DeleteUser",
          "iam:AttachUserPolicy",
          "iam:PutUserPolicy",
          "iam:CreatePolicy",
          "iam:DeletePolicy"
        ]
        Resource = "*"
      }
    ]
  })
}

# Developer role
resource "aws_iam_role" "developer" {
  name                 = "${var.project_name}-developer-role"
  permissions_boundary = aws_iam_policy.permissions_boundary.arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.allowed_regions
          }
          DateGreaterThan = {
            "aws:CurrentTime" = "09:00:00Z"
          }
          DateLessThan = {
            "aws:CurrentTime" = "18:00:00Z"
          }
        }
      }
    ]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# Developer base policy
resource "aws_iam_role_policy" "developer_base" {
  name = "${var.project_name}-developer-base-policy"
  role = aws_iam_role.developer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadOnlyAccessToMostServices"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "s3:Get*",
          "s3:List*",
          "logs:Describe*",
          "logs:Get*",
          "cloudformation:Describe*",
          "cloudformation:Get*",
          "cloudformation:List*",
          "lambda:Get*",
          "lambda:List*"
        ]
        Resource = "*"
      },
      {
        Sid    = "LimitedWriteAccessToDevelopmentResources"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::${var.project_name}-dev-*/*"
      },
      {
        Sid    = "CloudFormationStackManagementForDevStacks"
        Effect = "Allow"
        Action = [
          "cloudformation:CreateStack",
          "cloudformation:UpdateStack",
          "cloudformation:DeleteStack"
        ]
        Resource = "arn:aws:cloudformation:*:${data.aws_caller_identity.current.account_id}:stack/${var.project_name}-dev-*"
      },
      {
        Sid    = "DenyProductionResourceModification"
        Effect = "Deny"
        Action = [
          "ec2:TerminateInstances",
          "ec2:StopInstances",
          "rds:DeleteDBInstance",
          "s3:DeleteBucket"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:ResourceTag/Environment" = "production"
          }
        }
      }
    ]
  })
}

# Security audit role
resource "aws_iam_role" "security_audit" {
  name = "${var.project_name}-security-audit-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
          StringEquals = {
            "sts:ExternalId" = "${var.project_name}-audit-external-id"
          }
        }
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/SecurityAudit",
    "arn:aws:iam::aws:policy/ReadOnlyAccess"
  ]

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# Additional security audit policy
resource "aws_iam_role_policy" "security_audit_additional" {
  name = "${var.project_name}-security-audit-additional"
  role = aws_iam_role.security_audit.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowConfigRuleEvaluation"
        Effect = "Allow"
        Action = [
          "config:GetComplianceDetailsByConfigRule",
          "config:GetComplianceDetailsByResource",
          "config:GetComplianceSummaryByConfigRule",
          "config:GetComplianceSummaryByResourceType"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowGuardDutyFindingsAccess"
        Effect = "Allow"
        Action = [
          "guardduty:GetFindings",
          "guardduty:ListFindings",
          "guardduty:GetDetector",
          "guardduty:ListDetectors"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowSecurityHubAccess"
        Effect = "Allow"
        Action = [
          "securityhub:GetFindings",
          "securityhub:GetInsights",
          "securityhub:GetComplianceStatus"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lambda execution role
resource "aws_iam_role" "lambda_execution" {
  name = "${var.project_name}-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  ]

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# Lambda security policy
resource "aws_iam_role_policy" "lambda_security" {
  name = "${var.project_name}-lambda-security-policy"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowKMSOperationsForEncryption"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "arn:aws:kms:*:${data.aws_caller_identity.current.account_id}:key/*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = [
              "s3.${data.aws_region.current.name}.amazonaws.com",
              "secretsmanager.${data.aws_region.current.name}.amazonaws.com"
            ]
          }
        }
      },
      {
        Sid    = "AllowSecretsManagerAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:*:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/*"
      },
      {
        Sid    = "DenyNetworkModifications"
        Effect = "Deny"
        Action = [
          "ec2:CreateVpc",
          "ec2:DeleteVpc",
          "ec2:ModifyVpc*",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroup*",
          "ec2:RevokeSecurityGroup*"
        ]
        Resource = "*"
      }
    ]
  })
}

# EC2 instance role
resource "aws_iam_role" "ec2_instance" {
  name                 = "${var.project_name}-ec2-instance-role"
  permissions_boundary = aws_iam_policy.permissions_boundary.arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# EC2 security policy
resource "aws_iam_role_policy" "ec2_security" {
  name = "${var.project_name}-ec2-security-policy"
  role = aws_iam_role.ec2_instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchAgentPermissions"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Sid    = "SystemsManagerPermissions"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/*"
      },
      {
        Sid    = "S3AccessForApplicationData"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "arn:aws:s3:::${var.project_name}-application-data/*"
      },
      {
        Sid    = "DenyMetadataServiceV1"
        Effect = "Deny"
        Action = "*"
        Resource = "*"
        Condition = {
          NumericEquals = {
            "ec2:MetadataHttpTokens" = "1"
          }
        }
      }
    ]
  })
}

# Instance profile for EC2
resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-ec2-instance-profile"
  role = aws_iam_role.ec2_instance.name

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# Power users group
resource "aws_iam_group" "power_users" {
  name = "${var.project_name}-power-users"
}

# Power users policy
resource "aws_iam_group_policy" "power_users_restrictions" {
  name  = "${var.project_name}-power-user-restrictions"
  group = aws_iam_group.power_users.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyIAMPolicyModifications"
        Effect = "Deny"
        Action = [
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:SetDefaultPolicyVersion"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyOrganizationModifications"
        Effect = "Deny"
        Action = [
          "organizations:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyBillingAccess"
        Effect = "Deny"
        Action = [
          "aws-portal:*",
          "budgets:*",
          "ce:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach PowerUserAccess managed policy to group
resource "aws_iam_group_policy_attachment" "power_users" {
  group      = aws_iam_group.power_users.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# Account password policy
resource "aws_iam_account_password_policy" "password_policy" {
  minimum_password_length        = 14
  require_lowercase_characters   = true
  require_numbers               = true
  require_uppercase_characters   = true
  require_symbols               = true
  allow_users_to_change_password = true
  hard_expiry                   = false
  max_password_age              = 90
  password_reuse_prevention     = 5
}

# Outputs
output "cross_account_cicd_role_arn" {
  description = "ARN of the cross-account CI/CD role"
  value       = aws_iam_role.cross_account_cicd.arn
}

output "developer_role_arn" {
  description = "ARN of the developer role"
  value       = aws_iam_role.developer.arn
}

output "security_audit_role_arn" {
  description = "ARN of the security audit role"
  value       = aws_iam_role.security_audit.arn
}

output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.arn
}

output "ec2_instance_profile_arn" {
  description = "ARN of the EC2 instance profile"
  value       = aws_iam_instance_profile.ec2.arn
}

output "permissions_boundary_policy_arn" {
  description = "ARN of the permissions boundary policy"
  value       = aws_iam_policy.permissions_boundary.arn
}