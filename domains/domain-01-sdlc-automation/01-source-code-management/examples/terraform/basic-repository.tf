# Basic CodeCommit Repository with Terraform
# This example creates a CodeCommit repository with basic IAM policies

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
variable "repository_name" {
  description = "Name of the CodeCommit repository"
  type        = string
  default     = "my-application"
}

variable "repository_description" {
  description = "Description for the repository"
  type        = string
  default     = "Main application repository for DevOps pipeline"
}

variable "team_name" {
  description = "Name of the development team"
  type        = string
  default     = "DevOpsTeam"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "development"
  
  validation {
    condition = contains([
      "development",
      "staging", 
      "production"
    ], var.environment)
    error_message = "Environment must be development, staging, or production."
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# CodeCommit Repository
resource "aws_codecommit_repository" "main" {
  repository_name   = var.repository_name
  repository_description = var.repository_description
  
  tags = {
    Name        = var.repository_name
    Team        = var.team_name
    Environment = var.environment
    Purpose     = "SourceControl"
    ManagedBy   = "Terraform"
  }
}

# IAM Policy Document for Developer Access
data "aws_iam_policy_document" "developer_policy" {
  # Read access to all repositories
  statement {
    effect = "Allow"
    actions = [
      "codecommit:BatchGetRepositories",
      "codecommit:Get*",
      "codecommit:List*",
      "codecommit:GitPull"
    ]
    resources = ["*"]
  }
  
  # Write access to specific repository
  statement {
    effect = "Allow"
    actions = [
      "codecommit:GitPush",
      "codecommit:Merge*",
      "codecommit:Put*",
      "codecommit:Create*",
      "codecommit:Update*",
      "codecommit:Test*"
    ]
    resources = [aws_codecommit_repository.main.arn]
  }
  
  # Pull Request access
  statement {
    effect = "Allow"
    actions = [
      "codecommit:CreatePullRequest",
      "codecommit:CreatePullRequestApprovalRule",
      "codecommit:DescribePullRequestEvents",
      "codecommit:GetPullRequest",
      "codecommit:ListPullRequests",
      "codecommit:MergePullRequestByFastForward",
      "codecommit:PostCommentForPullRequest",
      "codecommit:UpdatePullRequestApprovalRuleContent",
      "codecommit:UpdatePullRequestDescription",
      "codecommit:UpdatePullRequestStatus",
      "codecommit:UpdatePullRequestTitle"
    ]
    resources = [aws_codecommit_repository.main.arn]
  }
}

# IAM Policy for Developers
resource "aws_iam_policy" "developer_policy" {
  name        = "${var.repository_name}-developer-policy"
  description = "Policy for developers to access CodeCommit repository"
  policy      = data.aws_iam_policy_document.developer_policy.json
  
  tags = {
    Name = "${var.repository_name}-developer-policy"
    Team = var.team_name
  }
}

# IAM Role for Developers
resource "aws_iam_role" "developer_role" {
  name = "${var.repository_name}-developer-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
      }
    ]
  })
  
  tags = {
    Name = "${var.repository_name}-developer-role"
    Team = var.team_name
  }
}

# Attach policy to developer role
resource "aws_iam_role_policy_attachment" "developer_role_policy" {
  role       = aws_iam_role.developer_role.name
  policy_arn = aws_iam_policy.developer_policy.arn
}

# IAM Policy Document for CI/CD Access (Read-only)
data "aws_iam_policy_document" "cicd_policy" {
  statement {
    effect = "Allow"
    actions = [
      "codecommit:BatchGetRepositories",
      "codecommit:Get*",
      "codecommit:List*",
      "codecommit:GitPull",
      "codecommit:UploadArchive"
    ]
    resources = [aws_codecommit_repository.main.arn]
  }
}

# IAM Policy for CI/CD
resource "aws_iam_policy" "cicd_policy" {
  name        = "${var.repository_name}-cicd-policy"
  description = "Policy for CI/CD pipeline to access CodeCommit repository"
  policy      = data.aws_iam_policy_document.cicd_policy.json
  
  tags = {
    Name = "${var.repository_name}-cicd-policy"
    Team = var.team_name
  }
}

# IAM Role for CI/CD
resource "aws_iam_role" "cicd_role" {
  name = "${var.repository_name}-cicd-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "codebuild.amazonaws.com",
            "codepipeline.amazonaws.com"
          ]
        }
      }
    ]
  })
  
  tags = {
    Name = "${var.repository_name}-cicd-role"
    Team = var.team_name
  }
}

# Attach policy to CI/CD role
resource "aws_iam_role_policy_attachment" "cicd_role_policy" {
  role       = aws_iam_role.cicd_role.name
  policy_arn = aws_iam_policy.cicd_policy.arn
}

# CloudWatch Log Group for monitoring
resource "aws_cloudwatch_log_group" "repository_logs" {
  name              = "/aws/codecommit/${var.repository_name}"
  retention_in_days = 30
  
  tags = {
    Name = "${var.repository_name}-logs"
    Team = var.team_name
  }
}

# CloudWatch Metric Alarm for repository activity
resource "aws_cloudwatch_metric_alarm" "low_commit_activity" {
  alarm_name          = "${var.repository_name}-low-commit-activity"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CommitsPerDay"
  namespace           = "CodeCommit/Repository"
  period              = "86400" # 24 hours
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "This metric monitors commit activity in the repository"
  insufficient_data_actions = []
  
  dimensions = {
    RepositoryName = aws_codecommit_repository.main.repository_name
  }
  
  tags = {
    Name = "${var.repository_name}-commit-activity-alarm"
    Team = var.team_name
  }
}

# Local file to store repository configuration
resource "local_file" "git_config" {
  filename = "${path.module}/.gitconfig-${var.repository_name}"
  content  = <<EOF
[credential]
    helper = !aws codecommit credential-helper $@
    UseHttpPath = true

[remote "origin"]
    url = ${aws_codecommit_repository.main.clone_url_http}
    fetch = +refs/heads/*:refs/remotes/origin/*

# Repository: ${var.repository_name}
# Clone URL: ${aws_codecommit_repository.main.clone_url_http}
# SSH URL: ${aws_codecommit_repository.main.clone_url_ssh}
EOF
}

# Outputs
output "repository_name" {
  description = "Name of the created CodeCommit repository"
  value       = aws_codecommit_repository.main.repository_name
}

output "repository_arn" {
  description = "ARN of the created CodeCommit repository"
  value       = aws_codecommit_repository.main.arn
}

output "repository_clone_url_http" {
  description = "HTTP clone URL for the repository"
  value       = aws_codecommit_repository.main.clone_url_http
}

output "repository_clone_url_ssh" {
  description = "SSH clone URL for the repository"
  value       = aws_codecommit_repository.main.clone_url_ssh
}

output "developer_role_arn" {
  description = "ARN of the developer role"
  value       = aws_iam_role.developer_role.arn
}

output "cicd_role_arn" {
  description = "ARN of the CI/CD role"
  value       = aws_iam_role.cicd_role.arn
}

output "repository_id" {
  description = "ID of the repository"
  value       = aws_codecommit_repository.main.repository_id
}

output "git_config_file" {
  description = "Path to the generated Git configuration file"
  value       = local_file.git_config.filename
}