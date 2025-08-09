# Multi-Project CodeBuild Setup with Terraform
# This configuration creates multiple CodeBuild projects with different configurations
# optimized for various application types and deployment scenarios

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

# Variables
variable "organization_name" {
  description = "Organization name for resource naming"
  type        = string
  default     = "MyCompany"
}

variable "project_prefix" {
  description = "Project prefix for naming"
  type        = string
  default     = "WebApp"
}

variable "environment" {
  description = "Environment (development, staging, production)"
  type        = string
  default     = "production"
  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be development, staging, or production."
  }
}

variable "team_email" {
  description = "Team email for notifications"
  type        = string
  validation {
    condition     = can(regex("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$", var.team_email))
    error_message = "Team email must be a valid email address."
  }
}

variable "vpc_id" {
  description = "VPC ID for private builds (optional)"
  type        = string
  default     = ""
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for VPC builds"
  type        = list(string)
  default     = []
}

variable "build_projects" {
  description = "Map of build project configurations"
  type = map(object({
    description     = string
    build_timeout   = number
    compute_type    = string
    image          = string
    privileged_mode = bool
    runtime_versions = map(string)
    enable_batch   = bool
  }))
  default = {
    nodejs = {
      description     = "Node.js application build"
      build_timeout   = 60
      compute_type    = "BUILD_GENERAL1_MEDIUM"
      image          = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
      privileged_mode = false
      runtime_versions = {
        nodejs = "18"
      }
      enable_batch = true
    }
    python = {
      description     = "Python application build"
      build_timeout   = 45
      compute_type    = "BUILD_GENERAL1_MEDIUM"
      image          = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
      privileged_mode = false
      runtime_versions = {
        python = "3.9"
      }
      enable_batch = false
    }
    docker = {
      description     = "Docker containerized build"
      build_timeout   = 90
      compute_type    = "BUILD_GENERAL1_LARGE"
      image          = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
      privileged_mode = true
      runtime_versions = {
        docker = "20"
      }
      enable_batch = true
    }
    java = {
      description     = "Java application build with Maven"
      build_timeout   = 120
      compute_type    = "BUILD_GENERAL1_LARGE"
      image          = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
      privileged_mode = false
      runtime_versions = {
        java = "corretto11"
      }
      enable_batch = false
    }
  }
}

variable "enable_vpc_config" {
  description = "Enable VPC configuration for builds"
  type        = bool
  default     = false
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Random suffix for unique naming
resource "random_string" "suffix" {
  length  = 8
  upper   = false
  special = false
}

# KMS Key for encryption
resource "aws_kms_key" "codebuild_key" {
  description             = "KMS key for CodeBuild encryption"
  deletion_window_in_days = 7

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CodeBuild Service"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name         = "${var.organization_name}-codebuild-key"
    Organization = var.organization_name
    Environment  = var.environment
    ManagedBy    = "Terraform"
  }
}

resource "aws_kms_alias" "codebuild_key_alias" {
  name          = "alias/${var.organization_name}-codebuild"
  target_key_id = aws_kms_key.codebuild_key.key_id
}

# S3 Bucket for Artifacts
resource "aws_s3_bucket" "artifacts" {
  bucket = "codebuild-artifacts-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}-${var.organization_name}-${random_string.suffix.result}"

  tags = {
    Name         = "${var.organization_name}-codebuild-artifacts"
    Organization = var.organization_name
    Environment  = var.environment
    ManagedBy    = "Terraform"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts_encryption" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.codebuild_key.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts_pab" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "artifacts_versioning" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = var.environment == "production" ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts_lifecycle" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "artifacts_lifecycle"
    status = "Enabled"

    expiration {
      days = var.environment == "production" ? 90 : 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

# S3 Bucket for Build Cache
resource "aws_s3_bucket" "cache" {
  bucket = "codebuild-cache-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}-${var.organization_name}-${random_string.suffix.result}"

  tags = {
    Name         = "${var.organization_name}-codebuild-cache"
    Organization = var.organization_name
    Environment  = var.environment
    ManagedBy    = "Terraform"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cache_encryption" {
  bucket = aws_s3_bucket.cache.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.codebuild_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cache_pab" {
  bucket = aws_s3_bucket.cache.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "cache_lifecycle" {
  bucket = aws_s3_bucket.cache.id

  rule {
    id     = "cache_lifecycle"
    status = "Enabled"

    expiration {
      days = 7
    }

    transition {
      days          = 1
      storage_class = "STANDARD_INFREQUENT_ACCESS"
    }
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "codebuild_logs" {
  name              = "/aws/codebuild/${var.organization_name}-projects"
  retention_in_days = var.environment == "production" ? 90 : 30
  kms_key_id        = aws_kms_key.codebuild_key.arn

  tags = {
    Name         = "${var.organization_name}-codebuild-logs"
    Organization = var.organization_name
    Environment  = var.environment
    ManagedBy    = "Terraform"
  }
}

# SNS Topic for Build Notifications
resource "aws_sns_topic" "build_notifications" {
  name         = "${var.organization_name}-codebuild-notifications"
  display_name = "${var.organization_name} CodeBuild Notifications"
  kms_master_key_id = aws_kms_key.codebuild_key.arn

  tags = {
    Name         = "${var.organization_name}-codebuild-notifications"
    Organization = var.organization_name
    Environment  = var.environment
    ManagedBy    = "Terraform"
  }
}

resource "aws_sns_topic_subscription" "email_notification" {
  topic_arn = aws_sns_topic.build_notifications.arn
  protocol  = "email"
  endpoint  = var.team_email
}

# Security Group for VPC builds
resource "aws_security_group" "codebuild_sg" {
  count = var.enable_vpc_config ? 1 : 0

  name_prefix = "${var.organization_name}-codebuild-"
  description = "Security group for CodeBuild VPC builds"
  vpc_id      = var.vpc_id

  egress {
    description = "HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP outbound"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Git SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  tags = {
    Name         = "${var.organization_name}-codebuild-sg"
    Organization = var.organization_name
    Environment  = var.environment
    ManagedBy    = "Terraform"
  }
}

# IAM Service Role for CodeBuild
resource "aws_iam_role" "codebuild_service_role" {
  name = "${var.organization_name}-CodeBuild-ServiceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name         = "${var.organization_name}-CodeBuild-ServiceRole"
    Organization = var.organization_name
    Environment  = var.environment
    ManagedBy    = "Terraform"
  }
}

resource "aws_iam_role_policy" "codebuild_service_policy" {
  name = "${var.organization_name}-CodeBuild-ServicePolicy"
  role = aws_iam_role.codebuild_service_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LoggingPermissions"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "${aws_cloudwatch_log_group.codebuild_logs.arn}:*",
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${var.organization_name}-*"
        ]
      },
      {
        Sid    = "S3ArtifactsPermissions"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "${aws_s3_bucket.artifacts.arn}/*",
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.cache.arn}/*",
          aws_s3_bucket.cache.arn
        ]
      },
      {
        Sid    = "CodeCommitPermissions"
        Effect = "Allow"
        Action = [
          "codecommit:GitPull",
          "codecommit:ListBranches",
          "codecommit:ListRepositories"
        ]
        Resource = "arn:aws:codecommit:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Sid    = "ECRPermissions"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetAuthorizationToken",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "*"
      },
      {
        Sid    = "ParameterStorePermissions"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${var.organization_name}/*"
      },
      {
        Sid    = "SecretsManagerPermissions"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.organization_name}/*"
      },
      {
        Sid    = "KMSPermissions"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = aws_kms_key.codebuild_key.arn
      },
      {
        Sid    = "SNSPermissions"
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.build_notifications.arn
      },
      {
        Sid    = "CloudWatchMetricsPermissions"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      }
    ]
  })
}

# VPC permissions policy (conditional)
resource "aws_iam_role_policy" "codebuild_vpc_policy" {
  count = var.enable_vpc_config ? 1 : 0

  name = "${var.organization_name}-CodeBuild-VPCPolicy"
  role = aws_iam_role.codebuild_service_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "VPCPermissions"
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeDhcpOptions",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeVpcs",
          "ec2:CreateNetworkInterfacePermission"
        ]
        Resource = "*"
      }
    ]
  })
}

# Batch Build Service Role
resource "aws_iam_role" "codebuild_batch_service_role" {
  name = "${var.organization_name}-CodeBuild-BatchServiceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name         = "${var.organization_name}-CodeBuild-BatchServiceRole"
    Organization = var.organization_name
    Environment  = var.environment
    ManagedBy    = "Terraform"
  }
}

resource "aws_iam_role_policy" "codebuild_batch_policy" {
  name = "${var.organization_name}-CodeBuild-BatchPolicy"
  role = aws_iam_role.codebuild_batch_service_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "codebuild:StartBuild",
          "codebuild:StopBuild",
          "codebuild:RetryBuild"
        ]
        Resource = "arn:aws:codebuild:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:project/${var.organization_name}-*"
      }
    ]
  })
}

# CodeBuild Projects
resource "aws_codebuild_project" "build_projects" {
  for_each = var.build_projects

  name          = "${var.organization_name}-${var.project_prefix}-${each.key}"
  description   = each.value.description
  service_role  = aws_iam_role.codebuild_service_role.arn
  encryption_key = aws_kms_key.codebuild_key.arn

  artifacts {
    type                = "S3"
    location           = "${aws_s3_bucket.artifacts.bucket}/${each.key}-builds"
    name              = "${var.project_prefix}-${each.key}-artifacts"
    override_artifact_name = true
    packaging         = "ZIP"
  }

  cache {
    type     = "S3"
    location = "${aws_s3_bucket.cache.bucket}/${each.key}-cache"
  }

  environment {
    compute_type                = each.value.compute_type
    image                      = each.value.image
    type                       = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode            = each.value.privileged_mode

    environment_variable {
      name  = "ORGANIZATION_NAME"
      value = var.organization_name
    }

    environment_variable {
      name  = "PROJECT_PREFIX"
      value = var.project_prefix
    }

    environment_variable {
      name  = "ENVIRONMENT"
      value = var.environment
    }

    environment_variable {
      name  = "APPLICATION_TYPE"
      value = each.key
    }

    environment_variable {
      name  = "ARTIFACTS_BUCKET"
      value = aws_s3_bucket.artifacts.bucket
    }

    environment_variable {
      name  = "CACHE_BUCKET"
      value = aws_s3_bucket.cache.bucket
    }

    environment_variable {
      name  = "SNS_TOPIC_ARN"
      value = aws_sns_topic.build_notifications.arn
    }

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = data.aws_region.current.name
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }
  }

  dynamic "vpc_config" {
    for_each = var.enable_vpc_config ? [1] : []
    content {
      vpc_id             = var.vpc_id
      subnets            = var.private_subnet_ids
      security_group_ids = [aws_security_group.codebuild_sg[0].id]
    }
  }

  source {
    type = "CODECOMMIT"
    buildspec = templatefile("${path.module}/buildspecs/${each.key}-buildspec.yml", {
      runtime_versions   = each.value.runtime_versions
      application_type   = each.key
      organization_name  = var.organization_name
      environment       = var.environment
    })
  }

  dynamic "build_batch_config" {
    for_each = each.value.enable_batch ? [1] : []
    content {
      service_role = aws_iam_role.codebuild_batch_service_role.arn
      restrictions {
        maximum_builds_allowed = 10
        compute_types_allowed = [
          "BUILD_GENERAL1_SMALL",
          "BUILD_GENERAL1_MEDIUM",
          "BUILD_GENERAL1_LARGE"
        ]
      }
      timeout_in_minutes = each.value.build_timeout + 30
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.codebuild_logs.name
      stream_name = "${each.key}-builds"
    }
  }

  timeout_in_minutes         = each.value.build_timeout
  queued_timeout_in_minutes = 480

  tags = {
    Name            = "${var.organization_name}-${var.project_prefix}-${each.key}"
    Organization    = var.organization_name
    Environment     = var.environment
    ApplicationType = each.key
    ManagedBy       = "Terraform"
  }
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "build_failure_alarm" {
  for_each = var.build_projects

  alarm_name          = "${var.organization_name}-${each.key}-build-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "FailedBuilds"
  namespace           = "AWS/CodeBuild"
  period              = "300"
  statistic           = "Sum"
  threshold           = "2"
  alarm_description   = "This metric monitors build failures for ${each.key}"
  alarm_actions       = [aws_sns_topic.build_notifications.arn]

  dimensions = {
    ProjectName = aws_codebuild_project.build_projects[each.key].name
  }

  tags = {
    Name         = "${var.organization_name}-${each.key}-build-failures"
    Organization = var.organization_name
    Environment  = var.environment
    ManagedBy    = "Terraform"
  }
}

resource "aws_cloudwatch_metric_alarm" "build_duration_alarm" {
  for_each = var.build_projects

  alarm_name          = "${var.organization_name}-${each.key}-long-builds"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/CodeBuild"
  period              = "300"
  statistic           = "Average"
  threshold           = each.value.build_timeout * 0.8
  alarm_description   = "This metric monitors long build durations for ${each.key}"
  alarm_actions       = [aws_sns_topic.build_notifications.arn]

  dimensions = {
    ProjectName = aws_codebuild_project.build_projects[each.key].name
  }

  tags = {
    Name         = "${var.organization_name}-${each.key}-long-builds"
    Organization = var.organization_name
    Environment  = var.environment
    ManagedBy    = "Terraform"
  }
}

# EventBridge Rule for Build State Changes
resource "aws_cloudwatch_event_rule" "build_state_change" {
  name        = "${var.organization_name}-codebuild-state-changes"
  description = "Capture CodeBuild state changes"

  event_pattern = jsonencode({
    source      = ["aws.codebuild"]
    detail-type = ["CodeBuild Build State Change"]
    detail = {
      project-name = [for project in aws_codebuild_project.build_projects : project.name]
      build-status = ["FAILED", "SUCCEEDED", "STOPPED"]
    }
  })

  tags = {
    Name         = "${var.organization_name}-codebuild-state-changes"
    Organization = var.organization_name
    Environment  = var.environment
    ManagedBy    = "Terraform"
  }
}

# Lambda Function for Build State Changes
resource "aws_lambda_function" "build_state_handler" {
  filename         = "build_state_handler.zip"
  function_name    = "${var.organization_name}-codebuild-state-handler"
  role            = aws_iam_role.build_state_handler_role.arn
  handler         = "index.lambda_handler"
  runtime         = "python3.9"
  timeout         = 60
  source_code_hash = data.archive_file.build_state_handler_zip.output_base64sha256

  environment {
    variables = {
      SNS_TOPIC_ARN     = aws_sns_topic.build_notifications.arn
      ORGANIZATION_NAME = var.organization_name
    }
  }

  tags = {
    Name         = "${var.organization_name}-codebuild-state-handler"
    Organization = var.organization_name
    Environment  = var.environment
    ManagedBy    = "Terraform"
  }
}

# Create ZIP file for Lambda function
data "archive_file" "build_state_handler_zip" {
  type        = "zip"
  output_path = "build_state_handler.zip"
  source {
    content = <<EOF
import boto3
import json
import os
from datetime import datetime

sns = boto3.client('sns')
cloudwatch = boto3.client('cloudwatch')

def lambda_handler(event, context):
    try:
        detail = event['detail']
        project_name = detail['project-name']
        build_status = detail['build-status']
        build_id = detail['build-id']
        
        # Send custom metrics
        metric_value = 1 if build_status == 'SUCCEEDED' else 0
        cloudwatch.put_metric_data(
            Namespace='CodeBuild/CustomMetrics',
            MetricData=[
                {
                    'MetricName': 'BuildSuccess',
                    'Dimensions': [
                        {'Name': 'ProjectName', 'Value': project_name},
                        {'Name': 'Organization', 'Value': os.getenv('ORGANIZATION_NAME')}
                    ],
                    'Value': metric_value,
                    'Unit': 'Count',
                    'Timestamp': datetime.utcnow()
                }
            ]
        )
        
        # Send notification for failures
        if build_status == 'FAILED':
            message = f"""
CodeBuild Project: {project_name}
Build ID: {build_id}
Status: {build_status}
Time: {detail.get('build-start-time', 'Unknown')}

Please check the build logs for details:
https://console.aws.amazon.com/codesuite/codebuild/projects/{project_name}/history
            """
            
            sns.publish(
                TopicArn=os.getenv('SNS_TOPIC_ARN'),
                Subject=f'CodeBuild FAILED: {project_name}',
                Message=message
            )
        
        return {'statusCode': 200}
        
    except Exception as e:
        print(f'Error processing build state change: {str(e)}')
        return {'statusCode': 500}
EOF
    filename = "index.py"
  }
}

# IAM Role for Lambda Function
resource "aws_iam_role" "build_state_handler_role" {
  name = "${var.organization_name}-BuildStateHandler-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name         = "${var.organization_name}-BuildStateHandler-Role"
    Organization = var.organization_name
    Environment  = var.environment
    ManagedBy    = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.build_state_handler_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "build_state_handler_policy" {
  name = "${var.organization_name}-BuildStateHandler-Policy"
  role = aws_iam_role.build_state_handler_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.build_notifications.arn
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      }
    ]
  })
}

# EventBridge Target
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.build_state_change.name
  target_id = "BuildStateHandlerTarget"
  arn       = aws_lambda_function.build_state_handler.arn
}

# Lambda Permission for EventBridge
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.build_state_handler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.build_state_change.arn
}

# Outputs
output "project_names" {
  description = "Names of created CodeBuild projects"
  value       = { for k, v in aws_codebuild_project.build_projects : k => v.name }
}

output "project_arns" {
  description = "ARNs of created CodeBuild projects"
  value       = { for k, v in aws_codebuild_project.build_projects : k => v.arn }
}

output "artifacts_bucket" {
  description = "S3 bucket for build artifacts"
  value       = aws_s3_bucket.artifacts.bucket
}

output "cache_bucket" {
  description = "S3 bucket for build cache"
  value       = aws_s3_bucket.cache.bucket
}

output "service_role_arn" {
  description = "ARN of the CodeBuild service role"
  value       = aws_iam_role.codebuild_service_role.arn
}

output "batch_service_role_arn" {
  description = "ARN of the CodeBuild batch service role"
  value       = aws_iam_role.codebuild_batch_service_role.arn
}

output "notification_topic_arn" {
  description = "ARN of the build notifications topic"
  value       = aws_sns_topic.build_notifications.arn
}

output "encryption_key_arn" {
  description = "ARN of the KMS encryption key"
  value       = aws_kms_key.codebuild_key.arn
}

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.codebuild_logs.name
}