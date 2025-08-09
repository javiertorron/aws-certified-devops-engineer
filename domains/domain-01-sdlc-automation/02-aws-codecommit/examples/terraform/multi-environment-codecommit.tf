# Multi-Environment CodeCommit Setup with Terraform
# This configuration creates CodeCommit repositories for different environments
# with appropriate security, monitoring, and automation features

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Variables
variable "organization_name" {
  description = "Organization name for resource naming"
  type        = string
  default     = "MyCompany"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "WebApplication"
}

variable "environments" {
  description = "List of environments to create repositories for"
  type = list(object({
    name               = string
    approval_required  = bool
    min_approvers     = number
    backup_required   = bool
  }))
  default = [
    {
      name               = "development"
      approval_required  = false
      min_approvers     = 1
      backup_required   = false
    },
    {
      name               = "staging"
      approval_required  = true
      min_approvers     = 1
      backup_required   = true
    },
    {
      name               = "production"
      approval_required  = true
      min_approvers     = 2
      backup_required   = true
    }
  ]
}

variable "team_email" {
  description = "Team email for notifications"
  type        = string
  validation {
    condition = can(regex("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$", var.team_email))
    error_message = "Team email must be a valid email address."
  }
}

variable "kms_key_id" {
  description = "KMS Key ID for encryption (optional)"
  type        = string
  default     = null
}

variable "enable_vpc_endpoint" {
  description = "Enable VPC endpoint for private access"
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "VPC ID for endpoint creation"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Subnet IDs for VPC endpoint"
  type        = list(string)
  default     = []
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# KMS Key for CodeCommit encryption (optional)
resource "aws_kms_key" "codecommit_key" {
  count = var.kms_key_id == null ? 1 : 0
  
  description             = "KMS key for CodeCommit repository encryption"
  deletion_window_in_days = 7
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "kms:*"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "codecommit.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = "*"
      }
    ]
  })
  
  tags = {
    Name         = "${var.organization_name}-codecommit-key"
    Organization = var.organization_name
    Project      = var.project_name
    ManagedBy    = "Terraform"
  }
}

resource "aws_kms_alias" "codecommit_key_alias" {
  count = var.kms_key_id == null ? 1 : 0
  
  name          = "alias/${var.organization_name}-codecommit"
  target_key_id = aws_kms_key.codecommit_key[0].key_id
}

# CodeCommit repositories for each environment
resource "aws_codecommit_repository" "app_repositories" {
  for_each = {
    for env in var.environments : env.name => env
  }
  
  repository_name   = "${var.organization_name}-${var.project_name}-${each.key}"
  repository_description = "Repository for ${var.project_name} in ${each.key} environment"
  
  kms_key_id = var.kms_key_id != null ? var.kms_key_id : (
    length(aws_kms_key.codecommit_key) > 0 ? aws_kms_key.codecommit_key[0].arn : null
  )
  
  tags = {
    Name         = "${var.organization_name}-${var.project_name}-${each.key}"
    Organization = var.organization_name
    Project      = var.project_name
    Environment  = each.key
    ManagedBy    = "Terraform"
    BackupRequired = each.value.backup_required ? "true" : "false"
  }
}

# Infrastructure repository
resource "aws_codecommit_repository" "infrastructure_repository" {
  repository_name   = "${var.organization_name}-${var.project_name}-infrastructure"
  repository_description = "Infrastructure as Code repository for ${var.project_name}"
  
  kms_key_id = var.kms_key_id != null ? var.kms_key_id : (
    length(aws_kms_key.codecommit_key) > 0 ? aws_kms_key.codecommit_key[0].arn : null
  )
  
  tags = {
    Name         = "${var.organization_name}-${var.project_name}-infrastructure"
    Organization = var.organization_name
    Project      = var.project_name
    Type         = "Infrastructure"
    ManagedBy    = "Terraform"
    BackupRequired = "true"
  }
}

# SNS Topic for notifications
resource "aws_sns_topic" "codecommit_notifications" {
  name = "${var.organization_name}-${var.project_name}-codecommit-notifications"
  
  kms_master_key_id = var.kms_key_id != null ? var.kms_key_id : (
    length(aws_kms_key.codecommit_key) > 0 ? aws_kms_key.codecommit_key[0].arn : "alias/aws/sns"
  )
  
  tags = {
    Name         = "${var.organization_name}-${var.project_name}-codecommit-notifications"
    Organization = var.organization_name
    Project      = var.project_name
    ManagedBy    = "Terraform"
  }
}

# SNS Topic for infrastructure changes
resource "aws_sns_topic" "infrastructure_notifications" {
  name = "${var.organization_name}-${var.project_name}-infrastructure-notifications"
  
  kms_master_key_id = var.kms_key_id != null ? var.kms_key_id : (
    length(aws_kms_key.codecommit_key) > 0 ? aws_kms_key.codecommit_key[0].arn : "alias/aws/sns"
  )
  
  tags = {
    Name         = "${var.organization_name}-${var.project_name}-infrastructure-notifications"
    Organization = var.organization_name
    Project      = var.project_name
    Type         = "Infrastructure"
    ManagedBy    = "Terraform"
  }
}

# Email subscriptions
resource "aws_sns_topic_subscription" "team_email_app" {
  topic_arn = aws_sns_topic.codecommit_notifications.arn
  protocol  = "email"
  endpoint  = var.team_email
}

resource "aws_sns_topic_subscription" "team_email_infrastructure" {
  topic_arn = aws_sns_topic.infrastructure_notifications.arn
  protocol  = "email"
  endpoint  = var.team_email
}

# IAM role for Lambda functions
resource "aws_iam_role" "lambda_codecommit_role" {
  name = "${var.organization_name}-${var.project_name}-lambda-codecommit-role"
  
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
    Name         = "${var.organization_name}-${var.project_name}-lambda-codecommit-role"
    Organization = var.organization_name
    Project      = var.project_name
    ManagedBy    = "Terraform"
  }
}

# IAM policy for Lambda functions
resource "aws_iam_role_policy" "lambda_codecommit_policy" {
  name = "${var.organization_name}-${var.project_name}-lambda-codecommit-policy"
  role = aws_iam_role.lambda_codecommit_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "codecommit:GetRepository",
          "codecommit:GetCommit",
          "codecommit:GetPullRequest",
          "codecommit:GetDifferences",
          "codecommit:CreatePullRequestApprovalRule",
          "codecommit:UpdatePullRequestApprovalRuleContent"
        ]
        Resource = [
          for repo in aws_codecommit_repository.app_repositories : repo.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codecommit:GetRepository",
          "codecommit:GetCommit",
          "codecommit:GetPullRequest",
          "codecommit:GetDifferences"
        ]
        Resource = aws_codecommit_repository.infrastructure_repository.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = [
          aws_sns_topic.codecommit_notifications.arn,
          aws_sns_topic.infrastructure_notifications.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "codeguru-reviewer:AssociateRepository",
          "codeguru-reviewer:ListRepositoryAssociations"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lambda function for repository monitoring
resource "aws_lambda_function" "repository_monitor" {
  filename         = "repository_monitor.zip"
  function_name    = "${var.organization_name}-${var.project_name}-repo-monitor"
  role            = aws_iam_role.lambda_codecommit_role.arn
  handler         = "index.lambda_handler"
  source_code_hash = data.archive_file.repository_monitor_zip.output_base64sha256
  runtime         = "python3.9"
  timeout         = 300
  
  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.codecommit_notifications.arn
      INFRASTRUCTURE_SNS_TOPIC_ARN = aws_sns_topic.infrastructure_notifications.arn
      ORGANIZATION_NAME = var.organization_name
      PROJECT_NAME = var.project_name
    }
  }
  
  tags = {
    Name         = "${var.organization_name}-${var.project_name}-repo-monitor"
    Organization = var.organization_name
    Project      = var.project_name
    ManagedBy    = "Terraform"
  }
}

# Create ZIP file for Lambda function
data "archive_file" "repository_monitor_zip" {
  type        = "zip"
  output_path = "repository_monitor.zip"
  source {
    content = <<EOF
import boto3
import json
import os
from datetime import datetime

cloudwatch = boto3.client('cloudwatch')
sns = boto3.client('sns')
codecommit = boto3.client('codecommit')

def lambda_handler(event, context):
    try:
        detail = event['detail']
        repository_name = detail['repositoryName']
        event_type = detail['event']
        reference_name = detail.get('referenceName', '')
        
        # Determine if this is infrastructure repository
        is_infrastructure = 'infrastructure' in repository_name
        topic_arn = os.getenv('INFRASTRUCTURE_SNS_TOPIC_ARN') if is_infrastructure else os.getenv('SNS_TOPIC_ARN')
        
        # Send custom metrics to CloudWatch
        cloudwatch.put_metric_data(
            Namespace='CodeCommit/Repository',
            MetricData=[
                {
                    'MetricName': 'RepositoryEvents',
                    'Dimensions': [
                        {'Name': 'RepositoryName', 'Value': repository_name},
                        {'Name': 'EventType', 'Value': event_type}
                    ],
                    'Value': 1,
                    'Unit': 'Count',
                    'Timestamp': datetime.utcnow()
                }
            ]
        )
        
        # Track commits per day
        if event_type == 'referenceUpdated':
            cloudwatch.put_metric_data(
                Namespace='CodeCommit/Repository',
                MetricData=[
                    {
                        'MetricName': 'CommitsPerDay',
                        'Dimensions': [
                            {'Name': 'RepositoryName', 'Value': repository_name}
                        ],
                        'Value': 1,
                        'Unit': 'Count',
                        'Timestamp': datetime.utcnow()
                    }
                ]
            )
            
            # Send notification for main branch changes
            if reference_name in ['refs/heads/main', 'refs/heads/master']:
                send_commit_notification(repository_name, detail, topic_arn)
        
        return {'statusCode': 200}
        
    except Exception as e:
        print(f"Error in repository monitoring: {str(e)}")
        return {'statusCode': 500}

def send_commit_notification(repository_name, detail, topic_arn):
    try:
        commit_id = detail.get('commitId', 'Unknown')
        reference_name = detail.get('referenceName', 'Unknown')
        
        # Get commit details
        try:
            commit_response = codecommit.get_commit(
                repositoryName=repository_name,
                commitId=commit_id
            )
            commit_message = commit_response['commit']['message']
            author_name = commit_response['commit']['author']['name']
        except:
            commit_message = "Unable to retrieve commit message"
            author_name = "Unknown"
        
        message = f"""
Repository: {repository_name}
Branch: {reference_name}
Commit: {commit_id}
Author: {author_name}
Message: {commit_message}
"""
        
        sns.publish(
            TopicArn=topic_arn,
            Subject=f'New commit in {repository_name}',
            Message=message
        )
    except Exception as e:
        print(f"Error sending notification: {str(e)}")
EOF
    filename = "index.py"
  }
}

# EventBridge rules for repository monitoring
resource "aws_cloudwatch_event_rule" "codecommit_events" {
  name        = "${var.organization_name}-${var.project_name}-codecommit-events"
  description = "Capture CodeCommit repository events"
  
  event_pattern = jsonencode({
    source      = ["aws.codecommit"]
    detail-type = ["CodeCommit Repository State Change"]
    detail = {
      repositoryName = [
        for repo in aws_codecommit_repository.app_repositories : repo.repository_name
      ]
    }
  })
  
  tags = {
    Name         = "${var.organization_name}-${var.project_name}-codecommit-events"
    Organization = var.organization_name
    Project      = var.project_name
    ManagedBy    = "Terraform"
  }
}

resource "aws_cloudwatch_event_rule" "infrastructure_events" {
  name        = "${var.organization_name}-${var.project_name}-infrastructure-events"
  description = "Capture infrastructure repository events"
  
  event_pattern = jsonencode({
    source      = ["aws.codecommit"]
    detail-type = ["CodeCommit Repository State Change"]
    detail = {
      repositoryName = [aws_codecommit_repository.infrastructure_repository.repository_name]
    }
  })
  
  tags = {
    Name         = "${var.organization_name}-${var.project_name}-infrastructure-events"
    Organization = var.organization_name
    Project      = var.project_name
    Type         = "Infrastructure"
    ManagedBy    = "Terraform"
  }
}

# EventBridge targets
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.codecommit_events.name
  target_id = "CodeCommitLambdaTarget"
  arn       = aws_lambda_function.repository_monitor.arn
}

resource "aws_cloudwatch_event_target" "infrastructure_lambda_target" {
  rule      = aws_cloudwatch_event_rule.infrastructure_events.name
  target_id = "InfrastructureLambdaTarget"
  arn       = aws_lambda_function.repository_monitor.arn
}

# Lambda permissions for EventBridge
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.repository_monitor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.codecommit_events.arn
}

resource "aws_lambda_permission" "allow_infrastructure_eventbridge" {
  statement_id  = "AllowExecutionFromInfrastructureEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.repository_monitor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.infrastructure_events.arn
}

# Approval rule templates for environments requiring approval
resource "aws_codecommit_approval_rule_template" "environment_approval" {
  for_each = {
    for env in var.environments : env.name => env
    if env.approval_required
  }
  
  approval_rule_template_name        = "${var.organization_name}-${each.key}-approval"
  approval_rule_template_description = "Approval rule for ${each.key} environment"
  
  approval_rule_template_content = jsonencode({
    Version = "2018-11-08"
    DestinationReferences = ["refs/heads/main", "refs/heads/master"]
    Statements = [
      {
        Type = "Approvers"
        NumberOfApprovalsNeeded = each.value.min_approvers
        ApprovalPoolMembers = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/SeniorDeveloper",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/TechLead"
        ]
      }
    ]
  })
}

# Associate approval rules with repositories
resource "aws_codecommit_approval_rule_template_association" "environment_approval" {
  for_each = {
    for env in var.environments : env.name => env
    if env.approval_required
  }
  
  approval_rule_template_name = aws_codecommit_approval_rule_template.environment_approval[each.key].approval_rule_template_name
  repository_name            = aws_codecommit_repository.app_repositories[each.key].repository_name
}

# Infrastructure approval rule template
resource "aws_codecommit_approval_rule_template" "infrastructure_approval" {
  approval_rule_template_name        = "${var.organization_name}-infrastructure-approval"
  approval_rule_template_description = "Approval rule for infrastructure changes"
  
  approval_rule_template_content = jsonencode({
    Version = "2018-11-08"
    DestinationReferences = ["refs/heads/main", "refs/heads/production"]
    Statements = [
      {
        Type = "Approvers"
        NumberOfApprovalsNeeded = 1
        ApprovalPoolMembers = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/DevOpsEngineer",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/InfrastructureAdmin"
        ]
      }
    ]
  })
}

resource "aws_codecommit_approval_rule_template_association" "infrastructure_approval" {
  approval_rule_template_name = aws_codecommit_approval_rule_template.infrastructure_approval.approval_rule_template_name
  repository_name            = aws_codecommit_repository.infrastructure_repository.repository_name
}

# CloudWatch alarms for repository monitoring
resource "aws_cloudwatch_metric_alarm" "low_activity" {
  for_each = {
    for env in var.environments : env.name => env
  }
  
  alarm_name          = "${var.organization_name}-${var.project_name}-${each.key}-low-activity"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CommitsPerDay"
  namespace           = "CodeCommit/Repository"
  period              = "86400"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "This metric monitors commit activity in ${each.key} repository"
  
  dimensions = {
    RepositoryName = aws_codecommit_repository.app_repositories[each.key].repository_name
  }
  
  alarm_actions = [aws_sns_topic.codecommit_notifications.arn]
  
  tags = {
    Name         = "${var.organization_name}-${var.project_name}-${each.key}-low-activity"
    Organization = var.organization_name
    Project      = var.project_name
    Environment  = each.key
    ManagedBy    = "Terraform"
  }
}

# VPC Endpoint for private CodeCommit access (optional)
resource "aws_vpc_endpoint" "codecommit" {
  count = var.enable_vpc_endpoint ? 1 : 0
  
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.codecommit"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.codecommit_vpce[0].id]
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = "*"
        Action = [
          "codecommit:GitPull",
          "codecommit:GitPush"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:PrincipalVpc" = var.vpc_id
          }
        }
      }
    ]
  })
  
  tags = {
    Name         = "${var.organization_name}-codecommit-vpce"
    Organization = var.organization_name
    Project      = var.project_name
    ManagedBy    = "Terraform"
  }
}

# Security Group for VPC Endpoint
resource "aws_security_group" "codecommit_vpce" {
  count = var.enable_vpc_endpoint ? 1 : 0
  
  name_prefix = "${var.organization_name}-codecommit-vpce-"
  description = "Security group for CodeCommit VPC endpoint"
  vpc_id      = var.vpc_id
  
  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }
  
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name         = "${var.organization_name}-codecommit-vpce-sg"
    Organization = var.organization_name
    Project      = var.project_name
    ManagedBy    = "Terraform"
  }
}

# Outputs
output "repository_names" {
  description = "Names of created repositories"
  value = {
    for env, repo in aws_codecommit_repository.app_repositories : env => repo.repository_name
  }
}

output "repository_clone_urls" {
  description = "Clone URLs for repositories"
  value = {
    for env, repo in aws_codecommit_repository.app_repositories : env => repo.clone_url_http
  }
}

output "infrastructure_repository_name" {
  description = "Name of infrastructure repository"
  value = aws_codecommit_repository.infrastructure_repository.repository_name
}

output "infrastructure_repository_clone_url" {
  description = "Clone URL for infrastructure repository"
  value = aws_codecommit_repository.infrastructure_repository.clone_url_http
}

output "notification_topic_arn" {
  description = "ARN of the notification topic"
  value = aws_sns_topic.codecommit_notifications.arn
}

output "infrastructure_notification_topic_arn" {
  description = "ARN of the infrastructure notification topic"
  value = aws_sns_topic.infrastructure_notifications.arn
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for encryption"
  value = var.kms_key_id != null ? var.kms_key_id : (
    length(aws_kms_key.codecommit_key) > 0 ? aws_kms_key.codecommit_key[0].arn : null
  )
}

output "vpc_endpoint_id" {
  description = "ID of the VPC endpoint"
  value = var.enable_vpc_endpoint ? aws_vpc_endpoint.codecommit[0].id : null
}