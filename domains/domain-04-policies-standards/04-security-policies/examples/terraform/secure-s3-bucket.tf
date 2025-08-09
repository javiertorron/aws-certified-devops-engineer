# Terraform configuration for secure S3 bucket with comprehensive security policies
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
variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
  default     = "secure-data-bucket"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "security-demo"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "retention_days" {
  description = "Number of days to retain objects"
  type        = number
  default     = 2555  # 7 years
}

# KMS Key for S3 encryption
resource "aws_kms_key" "s3_encryption" {
  description             = "KMS Key for S3 bucket encryption"
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
        Sid    = "Allow S3 Service"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "s3.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-s3-key"
    Environment = var.environment
    Project     = var.project_name
  }
}

# KMS Key Alias
resource "aws_kms_alias" "s3_encryption" {
  name          = "alias/${var.bucket_name}-key"
  target_key_id = aws_kms_key.s3_encryption.key_id
}

# Access logging bucket
resource "aws_s3_bucket" "access_logs" {
  bucket = "${var.bucket_name}-access-logs"

  tags = {
    Name        = "${var.bucket_name}-access-logs"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Access logs bucket versioning
resource "aws_s3_bucket_versioning" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Access logs bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Access logs bucket public access block
resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Main secure S3 bucket
resource "aws_s3_bucket" "secure_bucket" {
  bucket = var.bucket_name

  tags = {
    Name        = var.bucket_name
    Environment = var.environment
    Project     = var.project_name
    DataClass   = "Sensitive"
  }
}

# Bucket versioning
resource "aws_s3_bucket_versioning" "secure_bucket" {
  bucket = aws_s3_bucket.secure_bucket.id
  versioning_configuration {
    status     = "Enabled"
    mfa_delete = "Enabled"  # Requires MFA for permanent deletion
  }
}

# Bucket encryption configuration
resource "aws_s3_bucket_server_side_encryption_configuration" "secure_bucket" {
  bucket = aws_s3_bucket.secure_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_encryption.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# Public access block configuration
resource "aws_s3_bucket_public_access_block" "secure_bucket" {
  bucket = aws_s3_bucket.secure_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Access logging configuration
resource "aws_s3_bucket_logging" "secure_bucket" {
  bucket = aws_s3_bucket.secure_bucket.id

  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "access-logs/"
}

# Lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "secure_bucket" {
  depends_on = [aws_s3_bucket_versioning.secure_bucket]
  bucket     = aws_s3_bucket.secure_bucket.id

  rule {
    id     = "transition_to_ia"
    status = "Enabled"

    expiration {
      days = var.retention_days
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

# CloudWatch Log Group for S3 events
resource "aws_cloudwatch_log_group" "s3_events" {
  name              = "/aws/s3/${var.bucket_name}"
  retention_in_days = 90

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# SNS Topic for security alerts
resource "aws_sns_topic" "security_alerts" {
  name         = "${var.bucket_name}-security-alerts"
  display_name = "S3 Security Alerts"

  kms_master_key_id = "alias/aws/sns"

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Lambda function for security validation
resource "aws_lambda_function" "security_validator" {
  filename         = "security_validator.zip"
  function_name    = "${var.bucket_name}-security-validator"
  role            = aws_iam_role.lambda_execution.arn
  handler         = "index.lambda_handler"
  runtime         = "python3.9"
  timeout         = 60

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.security_alerts.arn
      BUCKET_NAME   = aws_s3_bucket.secure_bucket.id
    }
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Lambda function code (would typically be in a separate file)
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "security_validator.zip"
  source {
    content = <<EOF
import boto3
import json
import urllib.parse
import os

def lambda_handler(event, context):
    s3_client = boto3.client('s3')
    sns_client = boto3.client('sns')
    
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = urllib.parse.unquote_plus(record['s3']['object']['key'])
        
        try:
            # Check object metadata
            response = s3_client.head_object(Bucket=bucket, Key=key)
            
            # Validate encryption
            encryption = response.get('ServerSideEncryption', 'None')
            if encryption != 'aws:kms':
                # Send alert
                sns_client.publish(
                    TopicArn=os.environ['SNS_TOPIC_ARN'],
                    Message=f'Unencrypted object detected: {key} in bucket {bucket}',
                    Subject='S3 Security Violation'
                )
                
                # Optionally delete non-compliant object
                s3_client.delete_object(Bucket=bucket, Key=key)
                print(f'Deleted non-compliant object: {key}')
            
            # Check for sensitive data patterns
            sensitive_patterns = ['password', 'secret', 'key', 'token', 'credential']
            if any(pattern in key.lower() for pattern in sensitive_patterns):
                sns_client.publish(
                    TopicArn=os.environ['SNS_TOPIC_ARN'],
                    Message=f'Potentially sensitive file uploaded: {key}',
                    Subject='S3 Sensitive Data Alert'
                )
        
        except Exception as e:
            print(f'Error processing {key}: {str(e)}')
    
    return {'statusCode': 200}
EOF
    filename = "index.py"
  }
}

# IAM role for Lambda function
resource "aws_iam_role" "lambda_execution" {
  name = "${var.bucket_name}-lambda-execution-role"

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
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM policy for Lambda function
resource "aws_iam_role_policy" "lambda_s3_policy" {
  name = "${var.bucket_name}-lambda-s3-policy"
  role = aws_iam_role.lambda_execution.id

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
          "s3:GetObject",
          "s3:GetObjectMetadata",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.secure_bucket.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.security_alerts.arn
      }
    ]
  })
}

# Lambda permission for S3 to invoke function
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.security_validator.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.secure_bucket.arn
}

# S3 bucket notification
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.secure_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.security_validator.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

# CloudWatch Alarm for unauthorized access attempts
resource "aws_cloudwatch_metric_alarm" "unauthorized_access" {
  alarm_name          = "${var.bucket_name}-unauthorized-access"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4xxErrors"
  namespace           = "AWS/S3"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors unauthorized S3 access attempts"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  dimensions = {
    BucketName = aws_s3_bucket.secure_bucket.id
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Comprehensive bucket policy
resource "aws_s3_bucket_policy" "secure_bucket_policy" {
  bucket = aws_s3_bucket.secure_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyInsecureConnections"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.secure_bucket.arn,
          "${aws_s3_bucket.secure_bucket.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid    = "DenyUnencryptedObjectUploads"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:PutObject"
        Resource = "${aws_s3_bucket.secure_bucket.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      },
      {
        Sid    = "RequireSpecificKMSKey"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:PutObject"
        Resource = "${aws_s3_bucket.secure_bucket.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption-aws-kms-key-id" = aws_kms_key.s3_encryption.arn
          }
        }
      },
      {
        Sid    = "AllowAWSServices"
        Effect = "Allow"
        Principal = {
          Service = [
            "ec2.amazonaws.com",
            "lambda.amazonaws.com",
            "glue.amazonaws.com"
          ]
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.secure_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      }
    ]
  })
}

# Outputs
output "bucket_name" {
  description = "Name of the created S3 bucket"
  value       = aws_s3_bucket.secure_bucket.id
}

output "bucket_arn" {
  description = "ARN of the created S3 bucket"
  value       = aws_s3_bucket.secure_bucket.arn
}

output "kms_key_id" {
  description = "KMS Key ID used for bucket encryption"
  value       = aws_kms_key.s3_encryption.key_id
}

output "kms_key_arn" {
  description = "KMS Key ARN used for bucket encryption"
  value       = aws_kms_key.s3_encryption.arn
}

output "security_alerts_topic_arn" {
  description = "ARN of the security alerts SNS topic"
  value       = aws_sns_topic.security_alerts.arn
}

output "lambda_function_arn" {
  description = "ARN of the security validation Lambda function"
  value       = aws_lambda_function.security_validator.arn
}