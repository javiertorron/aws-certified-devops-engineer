# AWS CodeCommit Repository Creation and Configuration

## Table of Contents
1. [Repository Creation Methods](#repository-creation-methods)
2. [Advanced Configuration Options](#advanced-configuration-options)
3. [Repository Policies and Access Control](#repository-policies-and-access-control)
4. [Metadata Management and Tagging](#metadata-management-and-tagging)
5. [Repository Templates and Standards](#repository-templates-and-standards)
6. [Bulk Repository Management](#bulk-repository-management)
7. [Migration and Import Strategies](#migration-and-import-strategies)
8. [Configuration Best Practices](#configuration-best-practices)

---

## Repository Creation Methods

### AWS CLI Repository Creation

#### Basic Repository Creation
```bash
# Simple repository creation
aws codecommit create-repository \
    --repository-name my-application \
    --repository-description "Main application repository"

# Repository with initial code from S3
aws codecommit create-repository \
    --repository-name imported-app \
    --repository-description "Application imported from legacy system" \
    --code S3="{\"S3BucketName\":\"legacy-code-bucket\",\"S3ObjectKey\":\"app-v2.zip\"}"
```

#### Advanced CLI Creation with All Options
```bash
# Comprehensive repository creation
aws codecommit create-repository \
    --repository-name enterprise-application \
    --repository-description "Enterprise application with full governance" \
    --kms-key-id "arn:aws:kms:us-west-2:123456789012:key/12345678-1234-1234-1234-123456789012" \
    --tags Environment=Production,Team=Platform,Project=CoreServices,Compliance=SOC2,CostCenter=Engineering,Owner=platform-team@company.com \
    --code S3="{\"S3BucketName\":\"application-seeds\",\"S3ObjectKey\":\"enterprise-template-v1.0.zip\"}" \
    --region us-west-2 \
    --cli-input-json file://repository-config.json
```

#### Repository Configuration JSON
```json
{
    "repositoryName": "microservice-auth",
    "repositoryDescription": "Authentication microservice - Handles user authentication and authorization",
    "tags": {
        "Environment": "Production",
        "Service": "Authentication",
        "Team": "Security",
        "Architecture": "Microservice",
        "Language": "Go",
        "Database": "PostgreSQL",
        "Monitoring": "Required",
        "Backup": "Required",
        "Compliance": "SOX,GDPR",
        "MaintenanceWindow": "Sunday-02:00-04:00-UTC"
    },
    "code": {
        "S3": {
            "Bucket": "microservice-templates",
            "Key": "auth-service-template-v2.1.zip"
        }
    }
}
```

### CloudFormation Repository Creation

#### Basic CloudFormation Template
```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'CodeCommit Repository with comprehensive configuration'

Parameters:
  RepositoryName:
    Type: String
    Description: Name of the CodeCommit repository
    AllowedPattern: '^[a-zA-Z0-9._-]+$'
    ConstraintDescription: Repository name can only contain letters, numbers, periods, hyphens, and underscores

  TeamName:
    Type: String
    Description: Team responsible for this repository
    AllowedValues: [Platform, Security, Frontend, Backend, DevOps, QA, Data]

  EnvironmentType:
    Type: String
    Description: Target environment
    AllowedValues: [Development, Staging, Production, Sandbox]
    Default: Development

  KMSKeyId:
    Type: String
    Description: KMS Key ID for encryption (optional)
    Default: ""

Conditions:
  UseCustomKMSKey: !Not [!Equals [!Ref KMSKeyId, ""]]
  IsProduction: !Equals [!Ref EnvironmentType, Production]

Resources:
  CodeCommitRepository:
    Type: AWS::CodeCommit::Repository
    Properties:
      RepositoryName: !Sub "${TeamName}-${RepositoryName}-${EnvironmentType}"
      RepositoryDescription: !Sub "Repository for ${TeamName} team - ${RepositoryName} - ${EnvironmentType} environment"
      KmsKeyId: !If [UseCustomKMSKey, !Ref KMSKeyId, !Ref "AWS::NoValue"]
      Triggers:
        - Name: MainBranchTrigger
          DestinationArn: !Ref RepositoryNotificationTopic
          Events:
            - updateReference
          Branches:
            - main
            - master
        - Name: SecurityScanTrigger
          DestinationArn: !Ref SecurityScanFunction
          Events:
            - all
      Tags:
        - Key: Team
          Value: !Ref TeamName
        - Key: Environment
          Value: !Ref EnvironmentType
        - Key: ManagedBy
          Value: CloudFormation
        - Key: CreatedDate
          Value: !Sub "${AWS::Timestamp}"
        - Key: BackupRequired
          Value: !If [IsProduction, "true", "false"]
        - Key: MonitoringLevel
          Value: !If [IsProduction, "High", "Standard"]

  RepositoryNotificationTopic:
    Type: AWS::SNS::Topic
    Properties:
      TopicName: !Sub "${TeamName}-${RepositoryName}-notifications"
      DisplayName: !Sub "Notifications for ${RepositoryName} repository"
      KmsMasterKeyId: alias/aws/sns

  SecurityScanFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub "${RepositoryName}-security-scan"
      Runtime: python3.9
      Handler: index.lambda_handler
      Role: !GetAtt SecurityScanRole.Arn
      Environment:
        Variables:
          REPOSITORY_NAME: !GetAtt CodeCommitRepository.Name
          NOTIFICATION_TOPIC: !Ref RepositoryNotificationTopic
      Code:
        ZipFile: |
          import boto3
          import json
          import os
          
          def lambda_handler(event, context):
              # Security scanning logic here
              print(f"Security scan triggered for {os.environ['REPOSITORY_NAME']}")
              return {'statusCode': 200, 'body': 'Security scan completed'}

  SecurityScanRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: lambda.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
      Policies:
        - PolicyName: CodeCommitAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - codecommit:GetRepository
                  - codecommit:GetCommit
                  - codecommit:GetDifferences
                Resource: !GetAtt CodeCommitRepository.Arn
              - Effect: Allow
                Action:
                  - sns:Publish
                Resource: !Ref RepositoryNotificationTopic

Outputs:
  RepositoryArn:
    Description: ARN of the created repository
    Value: !GetAtt CodeCommitRepository.Arn
    Export:
      Name: !Sub "${AWS::StackName}-RepositoryArn"

  RepositoryName:
    Description: Name of the created repository
    Value: !GetAtt CodeCommitRepository.Name
    Export:
      Name: !Sub "${AWS::StackName}-RepositoryName"

  CloneUrlHttp:
    Description: HTTP clone URL
    Value: !GetAtt CodeCommitRepository.CloneUrlHttp
    Export:
      Name: !Sub "${AWS::StackName}-CloneUrlHttp"

  CloneUrlSsh:
    Description: SSH clone URL
    Value: !GetAtt CodeCommitRepository.CloneUrlSsh
    Export:
      Name: !Sub "${AWS::StackName}-CloneUrlSsh"
```

### Terraform Repository Creation

#### Terraform Configuration
```hcl
# variables.tf
variable "repository_name" {
  description = "Name of the CodeCommit repository"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9._-]+$", var.repository_name))
    error_message = "Repository name can only contain letters, numbers, periods, hyphens, and underscores."
  }
}

variable "team_name" {
  description = "Team responsible for the repository"
  type        = string
}

variable "environment" {
  description = "Environment type"
  type        = string
  default     = "development"
  validation {
    condition = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be development, staging, or production."
  }
}

variable "enable_encryption" {
  description = "Enable KMS encryption for the repository"
  type        = bool
  default     = true
}

variable "backup_required" {
  description = "Whether backup is required for this repository"
  type        = bool
  default     = false
}

# main.tf
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# KMS key for repository encryption
resource "aws_kms_key" "codecommit_key" {
  count                   = var.enable_encryption ? 1 : 0
  description             = "KMS key for CodeCommit repository ${var.repository_name}"
  key_usage               = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM policies"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CodeCommit service"
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

  tags = local.common_tags
}

resource "aws_kms_alias" "codecommit_key_alias" {
  count         = var.enable_encryption ? 1 : 0
  name          = "alias/codecommit-${var.repository_name}"
  target_key_id = aws_kms_key.codecommit_key[0].key_id
}

# SNS topic for repository notifications
resource "aws_sns_topic" "repository_notifications" {
  name              = "${var.team_name}-${var.repository_name}-notifications"
  display_name      = "Notifications for ${var.repository_name} repository"
  kms_master_key_id = "alias/aws/sns"

  tags = local.common_tags
}

# CodeCommit repository
resource "aws_codecommit_repository" "main" {
  repository_name   = "${var.team_name}-${var.repository_name}-${var.environment}"
  description       = "Repository for ${var.team_name} team - ${var.repository_name} - ${var.environment}"
  kms_key_id        = var.enable_encryption ? aws_kms_key.codecommit_key[0].arn : null

  tags = local.common_tags
}

# Repository triggers
resource "aws_codecommit_trigger" "main_branch_trigger" {
  repository_name = aws_codecommit_repository.main.repository_name

  trigger {
    name            = "MainBranchTrigger"
    events          = ["updateReference"]
    destination_arn = aws_sns_topic.repository_notifications.arn
    branches        = ["main", "master"]
  }
}

# Lambda function for security scanning
resource "aws_lambda_function" "security_scan" {
  filename         = "security_scan.zip"
  function_name    = "${var.repository_name}-security-scan"
  role            = aws_iam_role.security_scan_role.arn
  handler         = "index.lambda_handler"
  runtime         = "python3.9"
  timeout         = 300

  environment {
    variables = {
      REPOSITORY_NAME    = aws_codecommit_repository.main.repository_name
      NOTIFICATION_TOPIC = aws_sns_topic.repository_notifications.arn
    }
  }

  tags = local.common_tags
}

# IAM role for Lambda function
resource "aws_iam_role" "security_scan_role" {
  name = "${var.repository_name}-security-scan-role"

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

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.security_scan_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "codecommit_access" {
  name = "CodeCommitAccess"
  role = aws_iam_role.security_scan_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "codecommit:GetRepository",
          "codecommit:GetCommit",
          "codecommit:GetDifferences"
        ]
        Resource = aws_codecommit_repository.main.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.repository_notifications.arn
      }
    ]
  })
}

# Local values
locals {
  common_tags = {
    Team           = var.team_name
    Environment    = var.environment
    ManagedBy      = "Terraform"
    Repository     = var.repository_name
    BackupRequired = var.backup_required ? "true" : "false"
    CreatedDate    = formatdate("YYYY-MM-DD", timestamp())
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# outputs.tf
output "repository_arn" {
  description = "ARN of the CodeCommit repository"
  value       = aws_codecommit_repository.main.arn
}

output "repository_name" {
  description = "Name of the CodeCommit repository"
  value       = aws_codecommit_repository.main.repository_name
}

output "clone_url_http" {
  description = "HTTP clone URL"
  value       = aws_codecommit_repository.main.clone_url_http
}

output "clone_url_ssh" {
  description = "SSH clone URL"
  value       = aws_codecommit_repository.main.clone_url_ssh
}

output "kms_key_id" {
  description = "KMS key ID used for encryption"
  value       = var.enable_encryption ? aws_kms_key.codecommit_key[0].key_id : null
}
```

---

## Advanced Configuration Options

### Repository Metadata Management

#### Comprehensive Repository Information
```python
import boto3
import json
from datetime import datetime

class RepositoryMetadataManager:
    def __init__(self):
        self.codecommit = boto3.client('codecommit')
    
    def set_comprehensive_metadata(self, repository_name, metadata):
        """
        Set comprehensive metadata for a repository
        """
        # Update repository description with structured metadata
        structured_description = self.format_structured_description(metadata)
        
        self.codecommit.update_repository_description(
            repositoryName=repository_name,
            repositoryDescription=structured_description
        )
        
        # Apply comprehensive tagging
        repository_arn = self.get_repository_arn(repository_name)
        
        comprehensive_tags = self.prepare_comprehensive_tags(metadata)
        
        self.codecommit.tag_resource(
            resourceArn=repository_arn,
            tags=comprehensive_tags
        )
        
        return {
            "repository_name": repository_name,
            "metadata_applied": metadata,
            "tags_count": len(comprehensive_tags),
            "timestamp": datetime.utcnow().isoformat()
        }
    
    def format_structured_description(self, metadata):
        """
        Format metadata into structured description
        """
        description_parts = [
            f"Service: {metadata.get('service_name', 'Unknown')}",
            f"Team: {metadata.get('team', 'Unknown')}",
            f"Purpose: {metadata.get('purpose', 'General purpose repository')}",
            f"Technology: {metadata.get('technology_stack', 'Multiple')}"
        ]
        
        if metadata.get('compliance_requirements'):
            description_parts.append(f"Compliance: {', '.join(metadata['compliance_requirements'])}")
        
        if metadata.get('dependencies'):
            description_parts.append(f"Dependencies: {', '.join(metadata['dependencies'])}")
        
        return " | ".join(description_parts)
    
    def prepare_comprehensive_tags(self, metadata):
        """
        Prepare comprehensive tag set
        """
        base_tags = {
            'Team': metadata.get('team', 'Unknown'),
            'Environment': metadata.get('environment', 'development'),
            'Service': metadata.get('service_name', 'unknown'),
            'TechnologyStack': metadata.get('technology_stack', 'multiple'),
            'ManagedBy': 'PlatformTeam',
            'CreatedDate': datetime.utcnow().strftime('%Y-%m-%d'),
            'LastUpdated': datetime.utcnow().strftime('%Y-%m-%d')
        }
        
        # Add optional tags
        optional_tags = {
            'CostCenter': metadata.get('cost_center'),
            'Project': metadata.get('project_name'),
            'Owner': metadata.get('owner_email'),
            'MaintenanceWindow': metadata.get('maintenance_window'),
            'BackupSchedule': metadata.get('backup_schedule'),
            'MonitoringLevel': metadata.get('monitoring_level', 'standard'),
            'SecurityClassification': metadata.get('security_classification', 'internal')
        }
        
        # Add non-null optional tags
        for key, value in optional_tags.items():
            if value:
                base_tags[key] = str(value)
        
        # Add compliance tags
        if metadata.get('compliance_requirements'):
            for i, requirement in enumerate(metadata['compliance_requirements']):
                base_tags[f'Compliance{i+1}'] = requirement
        
        return base_tags
    
    def get_repository_arn(self, repository_name):
        """
        Get repository ARN
        """
        response = self.codecommit.get_repository(repositoryName=repository_name)
        return response['repositoryMetadata']['Arn']

# Usage example
metadata_manager = RepositoryMetadataManager()

repository_metadata = {
    'service_name': 'user-authentication-service',
    'team': 'Security',
    'environment': 'production',
    'purpose': 'Handles user authentication and session management',
    'technology_stack': 'Node.js, PostgreSQL, Redis',
    'compliance_requirements': ['SOX', 'GDPR', 'SOC2'],
    'cost_center': 'Engineering',
    'project_name': 'Identity-Platform',
    'owner_email': 'security-team@company.com',
    'maintenance_window': 'Sunday-02:00-04:00-UTC',
    'backup_schedule': 'daily',
    'monitoring_level': 'high',
    'security_classification': 'confidential',
    'dependencies': ['user-service', 'notification-service']
}

result = metadata_manager.set_comprehensive_metadata(
    'security-user-auth-production',
    repository_metadata
)
```

### Repository Configuration Validation

```python
class RepositoryConfigurationValidator:
    def __init__(self):
        self.codecommit = boto3.client('codecommit')
        self.validation_rules = self.load_validation_rules()
    
    def load_validation_rules(self):
        """
        Load repository configuration validation rules
        """
        return {
            'naming_convention': {
                'pattern': r'^[a-z]+(-[a-z]+)*-(dev|staging|prod)$',
                'description': 'Repository name must follow team-service-environment pattern'
            },
            'required_tags': [
                'Team', 'Environment', 'Service', 'ManagedBy'
            ],
            'environment_specific_rules': {
                'production': {
                    'required_tags': ['BackupSchedule', 'MonitoringLevel', 'Owner'],
                    'encryption_required': True,
                    'approval_rules_required': True
                },
                'staging': {
                    'required_tags': ['Owner'],
                    'encryption_required': False,
                    'approval_rules_required': False
                }
            }
        }
    
    def validate_repository_configuration(self, repository_name):
        """
        Validate repository configuration against rules
        """
        validation_results = {
            'repository_name': repository_name,
            'is_valid': True,
            'violations': [],
            'warnings': [],
            'recommendations': []
        }
        
        try:
            # Get repository information
            repo_info = self.codecommit.get_repository(repositoryName=repository_name)
            repo_metadata = repo_info['repositoryMetadata']
            
            # Get repository tags
            tags = self.codecommit.list_tags_for_resource(
                resourceArn=repo_metadata['Arn']
            )
            
            tag_dict = {tag['key']: tag['value'] for tag in tags.get('tags', [])}
            
            # Validate naming convention
            self.validate_naming_convention(repository_name, validation_results)
            
            # Validate required tags
            self.validate_required_tags(tag_dict, validation_results)
            
            # Environment-specific validation
            environment = tag_dict.get('Environment', '').lower()
            if environment in self.validation_rules['environment_specific_rules']:
                self.validate_environment_specific_rules(
                    repository_name, environment, repo_metadata, tag_dict, validation_results
                )
            
            # Check encryption
            self.validate_encryption(repo_metadata, validation_results)
            
            # Check approval rules if required
            if environment == 'production':
                self.validate_approval_rules(repository_name, validation_results)
            
        except Exception as e:
            validation_results['is_valid'] = False
            validation_results['violations'].append(f"Validation error: {str(e)}")
        
        return validation_results
    
    def validate_naming_convention(self, repository_name, results):
        """Validate repository naming convention"""
        import re
        
        pattern = self.validation_rules['naming_convention']['pattern']
        if not re.match(pattern, repository_name):
            results['is_valid'] = False
            results['violations'].append(
                f"Repository name '{repository_name}' doesn't match required pattern: {pattern}"
            )
    
    def validate_required_tags(self, tag_dict, results):
        """Validate required tags are present"""
        required_tags = self.validation_rules['required_tags']
        missing_tags = [tag for tag in required_tags if tag not in tag_dict]
        
        if missing_tags:
            results['is_valid'] = False
            results['violations'].append(f"Missing required tags: {', '.join(missing_tags)}")
    
    def validate_environment_specific_rules(self, repo_name, environment, repo_metadata, tag_dict, results):
        """Validate environment-specific rules"""
        env_rules = self.validation_rules['environment_specific_rules'][environment]
        
        # Check environment-specific required tags
        missing_env_tags = [tag for tag in env_rules.get('required_tags', []) 
                           if tag not in tag_dict]
        if missing_env_tags:
            results['is_valid'] = False
            results['violations'].append(
                f"Missing required tags for {environment} environment: {', '.join(missing_env_tags)}"
            )
        
        # Check encryption requirement
        if env_rules.get('encryption_required') and not repo_metadata.get('kmsKeyId'):
            results['is_valid'] = False
            results['violations'].append(f"Encryption is required for {environment} repositories")
    
    def validate_encryption(self, repo_metadata, results):
        """Validate encryption configuration"""
        if repo_metadata.get('kmsKeyId'):
            results['recommendations'].append("Repository is properly encrypted")
        else:
            results['warnings'].append("Consider enabling encryption for additional security")
    
    def validate_approval_rules(self, repository_name, results):
        """Validate approval rules for production repositories"""
        try:
            approval_rules = self.codecommit.list_approval_rule_templates()
            
            # Check if repository has approval rules
            associated_templates = self.codecommit.list_associated_approval_rule_templates_for_repository(
                repositoryName=repository_name
            )
            
            if not associated_templates.get('approvalRuleTemplateNames'):
                results['warnings'].append(
                    "Production repository should have approval rules configured"
                )
        except Exception:
            results['warnings'].append("Could not validate approval rules configuration")
```

---

## Repository Policies and Access Control

### Resource-Based Policies

#### Comprehensive Repository Policy
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowDeveloperReadAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "arn:aws:iam::123456789012:role/Developer-Role",
          "arn:aws:iam::123456789012:group/Developers"
        ]
      },
      "Action": [
        "codecommit:BatchGetRepositories",
        "codecommit:GetBranch",
        "codecommit:GetCommit",
        "codecommit:GetRepository",
        "codecommit:ListBranches",
        "codecommit:ListRepositories",
        "codecommit:GitPull"
      ],
      "Resource": "arn:aws:codecommit:us-west-2:123456789012:my-app-repo"
    },
    {
      "Sid": "AllowDeveloperFeatureBranchAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "arn:aws:iam::123456789012:role/Developer-Role",
          "arn:aws:iam::123456789012:group/Developers"
        ]
      },
      "Action": [
        "codecommit:GitPush",
        "codecommit:CreateBranch",
        "codecommit:DeleteBranch",
        "codecommit:CreatePullRequest",
        "codecommit:UpdatePullRequestDescription",
        "codecommit:UpdatePullRequestTitle"
      ],
      "Resource": "arn:aws:codecommit:us-west-2:123456789012:my-app-repo",
      "Condition": {
        "StringLike": {
          "codecommit:References": [
            "refs/heads/feature/*",
            "refs/heads/bugfix/*",
            "refs/heads/hotfix/*"
          ]
        }
      }
    },
    {
      "Sid": "DenyDirectPushToProtectedBranches",
      "Effect": "Deny",
      "Principal": "*",
      "Action": [
        "codecommit:GitPush",
        "codecommit:DeleteBranch",
        "codecommit:PutFile",
        "codecommit:MergeBranchesByFastForward",
        "codecommit:MergeBranchesBySquash",
        "codecommit:MergeBranchesByThreeWay"
      ],
      "Resource": "arn:aws:codecommit:us-west-2:123456789012:my-app-repo",
      "Condition": {
        "StringEquals": {
          "codecommit:References": [
            "refs/heads/main",
            "refs/heads/master",
            "refs/heads/develop"
          ]
        },
        "StringNotEquals": {
          "aws:PrincipalTag/Role": "ReleaseManager"
        }
      }
    },
    {
      "Sid": "AllowReleaseManagerFullAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789012:role/ReleaseManager-Role"
      },
      "Action": "codecommit:*",
      "Resource": "arn:aws:codecommit:us-west-2:123456789012:my-app-repo"
    },
    {
      "Sid": "AllowReadOnlyAuditAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "arn:aws:iam::123456789012:role/AuditReadOnly-Role",
          "arn:aws:iam::123456789012:role/ComplianceOfficer-Role"
        ]
      },
      "Action": [
        "codecommit:BatchGetRepositories",
        "codecommit:GetCommit",
        "codecommit:GetDifferences",
        "codecommit:GetRepository",
        "codecommit:ListBranches",
        "codecommit:ListPullRequests",
        "codecommit:GetPullRequest"
      ],
      "Resource": "arn:aws:codecommit:us-west-2:123456789012:my-app-repo"
    },
    {
      "Sid": "AllowCrossAccountReadAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::987654321098:role/CrossAccountDeveloper-Role"
      },
      "Action": [
        "codecommit:GetRepository",
        "codecommit:GitPull"
      ],
      "Resource": "arn:aws:codecommit:us-west-2:123456789012:my-app-repo",
      "Condition": {
        "StringEquals": {
          "codecommit:References": [
            "refs/heads/main"
          ]
        },
        "IpAddress": {
          "aws:SourceIp": [
            "192.168.100.0/24",
            "10.0.0.0/8"
          ]
        }
      }
    },
    {
      "Sid": "RequireMFAForProductionAccess",
      "Effect": "Deny",
      "Principal": "*",
      "Action": [
        "codecommit:GitPush",
        "codecommit:CreatePullRequest",
        "codecommit:MergePullRequestByFastForward"
      ],
      "Resource": "arn:aws:codecommit:us-west-2:123456789012:my-app-repo",
      "Condition": {
        "Bool": {
          "aws:MultiFactorAuthPresent": "false"
        },
        "StringEquals": {
          "codecommit:References": [
            "refs/heads/main",
            "refs/heads/master"
          ]
        }
      }
    }
  ]
}
```

### Policy Management Automation

```python
class RepositoryPolicyManager:
    def __init__(self):
        self.codecommit = boto3.client('codecommit')
        self.iam = boto3.client('iam')
    
    def apply_policy_template(self, repository_name, policy_template_type, parameters):
        """
        Apply a policy template to a repository
        """
        policy_templates = {
            'development': self.get_development_policy_template,
            'staging': self.get_staging_policy_template,
            'production': self.get_production_policy_template,
            'shared_service': self.get_shared_service_policy_template
        }
        
        if policy_template_type not in policy_templates:
            raise ValueError(f"Unknown policy template: {policy_template_type}")
        
        # Generate policy from template
        policy_document = policy_templates[policy_template_type](repository_name, parameters)
        
        # Apply policy to repository
        repository_arn = self.get_repository_arn(repository_name)
        
        self.codecommit.put_repository_policy(
            repositoryName=repository_name,
            policyDocument=json.dumps(policy_document)
        )
        
        return {
            "repository_name": repository_name,
            "policy_template": policy_template_type,
            "policy_applied": True,
            "timestamp": datetime.utcnow().isoformat()
        }
    
    def get_production_policy_template(self, repository_name, parameters):
        """
        Generate production-grade policy template
        """
        account_id = parameters.get('account_id')
        region = parameters.get('region', 'us-west-2')
        developer_role = parameters.get('developer_role', 'Developer-Role')
        release_manager_role = parameters.get('release_manager_role', 'ReleaseManager-Role')
        
        resource_arn = f"arn:aws:codecommit:{region}:{account_id}:{repository_name}"
        
        return {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Sid": "AllowDeveloperReadAccess",
                    "Effect": "Allow",
                    "Principal": {
                        "AWS": f"arn:aws:iam::{account_id}:role/{developer_role}"
                    },
                    "Action": [
                        "codecommit:BatchGetRepositories",
                        "codecommit:GetBranch",
                        "codecommit:GetCommit",
                        "codecommit:GetRepository",
                        "codecommit:ListBranches",
                        "codecommit:ListRepositories",
                        "codecommit:GitPull"
                    ],
                    "Resource": resource_arn
                },
                {
                    "Sid": "AllowFeatureBranchAccess",
                    "Effect": "Allow",
                    "Principal": {
                        "AWS": f"arn:aws:iam::{account_id}:role/{developer_role}"
                    },
                    "Action": [
                        "codecommit:GitPush",
                        "codecommit:CreateBranch",
                        "codecommit:CreatePullRequest"
                    ],
                    "Resource": resource_arn,
                    "Condition": {
                        "StringLike": {
                            "codecommit:References": [
                                "refs/heads/feature/*",
                                "refs/heads/bugfix/*"
                            ]
                        }
                    }
                },
                {
                    "Sid": "DenyDirectPushToMain",
                    "Effect": "Deny",
                    "Principal": "*",
                    "Action": "codecommit:GitPush",
                    "Resource": resource_arn,
                    "Condition": {
                        "StringEquals": {
                            "codecommit:References": [
                                "refs/heads/main",
                                "refs/heads/master"
                            ]
                        },
                        "StringNotEquals": {
                            "aws:userid": f"AIDACKCEVSQ6C2EXAMPLE:{release_manager_role}"
                        }
                    }
                },
                {
                    "Sid": "RequireMFAForMainBranch",
                    "Effect": "Deny",
                    "Principal": "*",
                    "Action": "*",
                    "Resource": resource_arn,
                    "Condition": {
                        "Bool": {
                            "aws:MultiFactorAuthPresent": "false"
                        },
                        "StringEquals": {
                            "codecommit:References": [
                                "refs/heads/main",
                                "refs/heads/master"
                            ]
                        }
                    }
                }
            ]
        }
    
    def validate_policy_compliance(self, repository_name):
        """
        Validate repository policy compliance
        """
        try:
            policy_response = self.codecommit.get_repository_policy(
                repositoryName=repository_name
            )
            
            policy_document = json.loads(policy_response['policyDocument'])
            
            compliance_results = {
                'repository_name': repository_name,
                'has_policy': True,
                'compliance_checks': {},
                'violations': [],
                'recommendations': []
            }
            
            # Check for MFA requirement
            has_mfa_requirement = self.check_mfa_requirement(policy_document)
            compliance_results['compliance_checks']['mfa_required'] = has_mfa_requirement
            
            if not has_mfa_requirement:
                compliance_results['violations'].append("No MFA requirement found for sensitive operations")
            
            # Check for branch protection
            has_branch_protection = self.check_branch_protection(policy_document)
            compliance_results['compliance_checks']['branch_protection'] = has_branch_protection
            
            if not has_branch_protection:
                compliance_results['violations'].append("No branch protection found for main branches")
            
            # Check for proper access controls
            access_control_score = self.evaluate_access_controls(policy_document)
            compliance_results['compliance_checks']['access_control_score'] = access_control_score
            
            if access_control_score < 80:
                compliance_results['recommendations'].append("Consider tightening access controls")
            
            return compliance_results
            
        except self.codecommit.exceptions.PolicyDoesNotExistException:
            return {
                'repository_name': repository_name,
                'has_policy': False,
                'violations': ['No repository policy configured'],
                'recommendations': ['Configure appropriate repository policy for security']
            }
    
    def check_mfa_requirement(self, policy_document):
        """Check if policy requires MFA for sensitive operations"""
        for statement in policy_document.get('Statement', []):
            conditions = statement.get('Condition', {})
            if 'aws:MultiFactorAuthPresent' in str(conditions):
                return True
        return False
    
    def check_branch_protection(self, policy_document):
        """Check if policy protects main branches"""
        for statement in policy_document.get('Statement', []):
            if statement.get('Effect') == 'Deny':
                conditions = statement.get('Condition', {})
                if 'codecommit:References' in str(conditions):
                    refs = str(conditions)
                    if 'main' in refs or 'master' in refs:
                        return True
        return False
```

This comprehensive repository creation and configuration guide provides detailed examples and advanced patterns for managing CodeCommit repositories at enterprise scale, covering all aspects from basic creation to sophisticated policy management and compliance validation.