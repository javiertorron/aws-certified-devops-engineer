# AWS CodeCommit - Comprehensive Guide

## Table of Contents
1. [CodeCommit Service Overview](#codecommit-service-overview)
2. [Architecture and Core Concepts](#architecture-and-core-concepts)
3. [Repository Creation and Configuration](#repository-creation-and-configuration)
4. [Authentication and Authorization](#authentication-and-authorization)
5. [Advanced Security Features](#advanced-security-features)
6. [Repository Triggers and Automation](#repository-triggers-and-automation)
7. [Approval Rules and Pull Requests](#approval-rules-and-pull-requests)
8. [Monitoring and Observability](#monitoring-and-observability)
9. [Integration with AWS Developer Tools](#integration-with-aws-developer-tools)
10. [Performance Optimization](#performance-optimization)
11. [Enterprise Features and Multi-Account Strategies](#enterprise-features)
12. [Migration and Hybrid Scenarios](#migration-and-hybrid-scenarios)
13. [Troubleshooting Common Issues](#troubleshooting-common-issues)

---

## CodeCommit Service Overview

### What is AWS CodeCommit?

AWS CodeCommit is a fully managed source control service that hosts secure Git-based repositories. It eliminates the need to operate your own source control system or worry about scaling its infrastructure.

#### Key Features:
- **Fully Managed**: No infrastructure to manage or scale
- **Secure**: Encryption at rest and in transit by default
- **Highly Available**: Built on AWS's proven infrastructure
- **Scalable**: No repository size limits or file count restrictions
- **Integrated**: Native integration with AWS Developer Tools
- **Cost-Effective**: Pay only for active users per month

#### Service Benefits:
- **Enhanced Security**: IAM integration, VPC support, encryption
- **High Performance**: Low latency, high throughput
- **Reliable**: 99.9% availability SLA
- **Collaborative**: Pull requests, approval rules, notifications
- **Auditable**: CloudTrail integration, detailed logging

### CodeCommit vs Other Git Providers

| Feature | CodeCommit | GitHub | GitLab | Bitbucket |
|---------|------------|--------|--------|-----------|
| Hosting | AWS Managed | Cloud/Enterprise | Cloud/Self-hosted | Cloud/Server |
| Security | IAM + Encryption | OAuth + 2FA | OAuth + SAML | OAuth + 2FA |
| Integration | AWS Native | Third-party | CI/CD Built-in | Atlassian Suite |
| Pricing | Per User | Per User/Repo | Per User | Per User |
| Enterprise | Yes | Yes | Yes | Yes |
| On-Premises | No | Enterprise only | Yes | Server only |

### Regional Availability and Limitations

#### Available Regions:
CodeCommit is available in most AWS regions including:
- US East (N. Virginia, Ohio)
- US West (Oregon, N. California)
- Europe (Ireland, London, Frankfurt, Paris, Stockholm)
- Asia Pacific (Tokyo, Seoul, Singapore, Sydney, Mumbai)
- Canada (Central)
- South America (São Paulo)

#### Service Limits:
- **Repository size**: No limit
- **File size**: 2 GB per file
- **Number of repositories**: 1,000 per account (soft limit)
- **Concurrent connections**: 4,000 per repository
- **API requests**: 5,000 per second per region

---

## Architecture and Core Concepts

### CodeCommit Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        AWS CodeCommit Service                   │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐  │
│  │ Repository  │  │ Repository  │  │ Repository  │  │   ...   │  │
│  │   Storage   │  │   Storage   │  │   Storage   │  │         │  │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘  │
├─────────────────────────────────────────────────────────────────┤
│                    Security & Access Layer                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │     IAM     │  │  Resource   │  │    KMS      │              │
│  │  Policies   │  │   Policies  │  │ Encryption  │              │
│  └─────────────┘  └─────────────┘  └─────────────┘              │
├─────────────────────────────────────────────────────────────────┤
│                      Event & Trigger Layer                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │ CloudWatch  │  │ EventBridge │  │   Lambda    │              │
│  │   Events    │  │    Rules    │  │  Triggers   │              │
│  └─────────────┘  └─────────────┘  └─────────────┘              │
└─────────────────────────────────────────────────────────────────┘
                                 │
                    ┌─────────────┴─────────────┐
                    │       Client Access       │
                    ├───────────┬───────────────┤
                    │   Git     │      AWS      │
                    │ Commands  │      CLI      │
                    └───────────┴───────────────┘
```

### Core Components

#### 1. Repository Storage
- **Git-compatible**: Standard Git operations supported
- **Encrypted**: Data encrypted at rest using AWS KMS
- **Versioned**: Full Git history and branching support
- **Metadata**: Additional AWS-specific repository information

#### 2. Access Control
- **IAM Integration**: Fine-grained permissions
- **Resource Policies**: Repository-level access control
- **Cross-account Access**: Support for multi-account architectures
- **Temporary Credentials**: STS integration for secure access

#### 3. Event System
- **Repository Triggers**: React to repository changes
- **CloudWatch Events**: Integration with AWS event system
- **Custom Actions**: Lambda-based automation
- **Notifications**: SNS integration for alerts

### Git Operations in CodeCommit

#### Standard Git Commands:
```bash
# Clone repository
git clone https://git-codecommit.region.amazonaws.com/v1/repos/repository-name

# Standard Git workflow
git add .
git commit -m "commit message"
git push origin main

# Branch operations
git branch feature-branch
git checkout feature-branch
git merge main

# Tag operations
git tag v1.0.0
git push origin --tags
```

#### CodeCommit-Specific Features:
- **HTTPS Git Credentials**: AWS-managed credentials
- **SSH Keys**: IAM user SSH key support
- **Temporary Credentials**: STS token support
- **Federated Access**: SAML and Active Directory integration

---

## Repository Creation and Configuration

### Creating Repositories

#### Using AWS CLI:
```bash
# Basic repository creation
aws codecommit create-repository \
    --repository-name my-app-repo \
    --repository-description "My application repository"

# Repository with initial code from S3
aws codecommit create-repository \
    --repository-name my-app-repo \
    --repository-description "My application repository" \
    --code S3="{\"S3BucketName\":\"my-bucket\",\"S3ObjectKey\":\"source.zip\"}"

# Repository with tags
aws codecommit create-repository \
    --repository-name my-app-repo \
    --repository-description "My application repository" \
    --tags Environment=Production,Team=DevOps,Cost-Center=Engineering
```

#### Using CloudFormation:
```yaml
MyCodeCommitRepository:
  Type: AWS::CodeCommit::Repository
  Properties:
    RepositoryName: my-app-repo
    RepositoryDescription: My application repository
    Code:
      S3:
        Bucket: !Ref InitialCodeBucket
        Key: source.zip
    Triggers:
      - Name: MasterTrigger
        DestinationArn: !Ref NotificationTopic
        Events:
          - updateReference
        Branches:
          - main
    Tags:
      - Key: Environment
        Value: Production
      - Key: Team
        Value: DevOps
```

### Repository Configuration

#### Repository Metadata:
```bash
# Get repository information
aws codecommit get-repository --repository-name my-app-repo

# List repositories
aws codecommit list-repositories

# Update repository description
aws codecommit update-repository-description \
    --repository-name my-app-repo \
    --repository-description "Updated description"

# Update repository name
aws codecommit update-repository-name \
    --old-name my-app-repo \
    --new-name my-application-repo
```

#### Repository Settings:
- **Default Branch**: Can be configured via Git operations
- **Repository Policies**: JSON-based access control
- **Approval Rules**: Pull request approval requirements
- **Triggers**: Event-based automation configuration

### Repository Policies

#### Resource-Based Policy Example:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowDeveloperAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "arn:aws:iam::123456789012:role/Developer-Role",
          "arn:aws:iam::123456789012:user/dev-user"
        ]
      },
      "Action": [
        "codecommit:GitPull",
        "codecommit:GitPush"
      ],
      "Resource": "arn:aws:codecommit:us-west-2:123456789012:my-app-repo"
    },
    {
      "Sid": "DenyDirectPushToMain",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "codecommit:GitPush",
      "Resource": "arn:aws:codecommit:us-west-2:123456789012:my-app-repo",
      "Condition": {
        "StringEquals": {
          "codecommit:References": "refs/heads/main"
        }
      }
    }
  ]
}
```

---

## Authentication and Authorization

### Authentication Methods

#### 1. HTTPS Git Credentials
```bash
# Generate Git credentials in IAM console
# Configure Git
git config --global credential.helper store

# Use generated username/password for Git operations
git clone https://git-codecommit.us-west-2.amazonaws.com/v1/repos/my-repo
```

#### 2. AWS CLI Credential Helper
```bash
# Configure credential helper
git config --global credential.helper '!aws codecommit credential-helper $@'
git config --global credential.UseHttpPath true

# Now use standard Git commands
git clone https://git-codecommit.us-west-2.amazonaws.com/v1/repos/my-repo
```

#### 3. SSH Keys
```bash
# Generate SSH key pair
ssh-keygen -t rsa -b 4096 -C "your.email@example.com"

# Upload public key to IAM
aws iam upload-ssh-public-key \
    --user-name MyUser \
    --ssh-public-key-body file://~/.ssh/id_rsa.pub

# Configure SSH
cat >> ~/.ssh/config << EOF
Host git-codecommit.*.amazonaws.com
  User APKAEIBAERJR2EXAMPLE
  IdentityFile ~/.ssh/id_rsa
EOF

# Clone using SSH
git clone ssh://git-codecommit.us-west-2.amazonaws.com/v1/repos/my-repo
```

#### 4. Temporary Credentials (STS)
```bash
# Assume role and get temporary credentials
aws sts assume-role \
    --role-arn arn:aws:iam::123456789012:role/CodeCommit-Access-Role \
    --role-session-name codecommit-session

# Export credentials
export AWS_ACCESS_KEY_ID=ASIAIOSFODNN7EXAMPLE
export AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
export AWS_SESSION_TOKEN=very-long-session-token

# Use Git with temporary credentials
git clone https://git-codecommit.us-west-2.amazonaws.com/v1/repos/my-repo
```

### Authorization with IAM Policies

#### Developer Policy Example:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "codecommit:BatchGetRepositories",
        "codecommit:GetBranch",
        "codecommit:GetCommit",
        "codecommit:GetRepository",
        "codecommit:ListBranches",
        "codecommit:ListRepositories",
        "codecommit:GitPull"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "codecommit:GitPush"
      ],
      "Resource": "arn:aws:codecommit:*:*:*",
      "Condition": {
        "StringLike": {
          "codecommit:References": [
            "refs/heads/feature/*",
            "refs/heads/bugfix/*",
            "refs/heads/hotfix/*"
          ]
        }
      }
    }
  ]
}
```

#### Admin Policy Example:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "codecommit:*",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:ListUsers",
        "iam:ListSSHPublicKeys",
        "iam:ListServiceSpecificCredentials",
        "iam:CreateServiceSpecificCredential",
        "iam:UpdateServiceSpecificCredential",
        "iam:DeleteServiceSpecificCredential",
        "iam:ResetServiceSpecificCredential"
      ],
      "Resource": "*"
    }
  ]
}
```

### Cross-Account Access

#### Trust Policy for Cross-Account Role:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::EXTERNAL-ACCOUNT-ID:role/CrossAccountRole"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "unique-external-id"
        }
      }
    }
  ]
}
```

#### Cross-Account Access Implementation:
```bash
# In external account, assume role
aws sts assume-role \
    --role-arn arn:aws:iam::TARGET-ACCOUNT:role/CodeCommitCrossAccountRole \
    --role-session-name cross-account-session \
    --external-id unique-external-id

# Use temporary credentials to access CodeCommit
export AWS_ACCESS_KEY_ID=ASIAIOSFODNN7EXAMPLE
export AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
export AWS_SESSION_TOKEN=session-token

git clone https://git-codecommit.us-west-2.amazonaws.com/v1/repos/cross-account-repo
```

---

## Advanced Security Features

### Encryption

#### Encryption at Rest:
- **Default**: AWS managed KMS key
- **Custom**: Customer managed KMS key
- **Configuration**: Set during repository creation

```bash
# Create repository with custom KMS key
aws codecommit create-repository \
    --repository-name encrypted-repo \
    --repository-description "Repository with custom encryption" \
    --kms-key-id arn:aws:kms:us-west-2:123456789012:key/12345678-1234-1234-1234-123456789012
```

#### Encryption in Transit:
- **HTTPS**: All Git operations over TLS
- **SSH**: Secure Shell protocol
- **API**: All AWS API calls over HTTPS

### VPC Integration

#### VPC Endpoint Configuration:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": [
        "codecommit:GitPull",
        "codecommit:GitPush"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:PrincipalVpc": "vpc-12345678"
        }
      }
    }
  ]
}
```

#### Private Access Configuration:
```bash
# Create VPC endpoint for CodeCommit
aws ec2 create-vpc-endpoint \
    --vpc-id vpc-12345678 \
    --service-name com.amazonaws.us-west-2.codecommit \
    --vpc-endpoint-type Interface \
    --subnet-ids subnet-12345678 subnet-87654321 \
    --security-group-ids sg-12345678 \
    --policy-document file://codecommit-vpc-policy.json
```

### IP Address Restrictions

#### IP-Based Access Policy:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "*"
      },
      "Action": "codecommit:*",
      "Resource": "*",
      "Condition": {
        "IpAddress": {
          "aws:SourceIp": [
            "192.168.1.0/24",
            "10.0.0.0/16"
          ]
        }
      }
    }
  ]
}
```

### Multi-Factor Authentication

#### MFA Policy Example:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789012:user/developer"
      },
      "Action": "codecommit:*",
      "Resource": "*",
      "Condition": {
        "Bool": {
          "aws:MultiFactorAuthPresent": "true"
        },
        "NumericLessThan": {
          "aws:MultiFactorAuthAge": "3600"
        }
      }
    }
  ]
}
```

---

## Repository Triggers and Automation

### CloudWatch Events Integration

#### Repository State Change Events:
```json
{
  "source": ["aws.codecommit"],
  "detail-type": ["CodeCommit Repository State Change"],
  "detail": {
    "event": [
      "referenceCreated",
      "referenceUpdated",
      "referenceDeleted"
    ],
    "repositoryName": ["my-repo"],
    "referenceName": ["refs/heads/main"]
  }
}
```

#### Event Rule Configuration:
```bash
# Create EventBridge rule
aws events put-rule \
    --name CodeCommitMainBranchRule \
    --event-pattern '{
        "source": ["aws.codecommit"],
        "detail-type": ["CodeCommit Repository State Change"],
        "detail": {
            "event": ["referenceUpdated"],
            "repositoryName": ["my-repo"],
            "referenceName": ["refs/heads/main"]
        }
    }' \
    --state ENABLED

# Add Lambda target
aws events put-targets \
    --rule CodeCommitMainBranchRule \
    --targets "Id"="1","Arn"="arn:aws:lambda:us-west-2:123456789012:function:ProcessCommit"
```

### Lambda Trigger Functions

#### Basic Trigger Function:
```python
import json
import boto3

def lambda_handler(event, context):
    """
    Process CodeCommit repository events
    """
    # Parse the event
    detail = event['detail']
    repository_name = detail['repositoryName']
    reference_name = detail['referenceName']
    commit_id = detail['commitId']
    
    print(f"Processing commit {commit_id} in {repository_name} on {reference_name}")
    
    # Initialize clients
    codecommit = boto3.client('codecommit')
    sns = boto3.client('sns')
    
    try:
        # Get commit details
        commit_response = codecommit.get_commit(
            repositoryName=repository_name,
            commitId=commit_id
        )
        
        commit_message = commit_response['commit']['message']
        author_name = commit_response['commit']['author']['name']
        
        # Send notification
        message = f"""
        New commit in repository: {repository_name}
        Branch: {reference_name}
        Author: {author_name}
        Commit: {commit_id}
        Message: {commit_message}
        """
        
        sns.publish(
            TopicArn='arn:aws:sns:us-west-2:123456789012:codecommit-notifications',
            Subject=f'New commit in {repository_name}',
            Message=message
        )
        
        # Trigger downstream processes
        if reference_name == 'refs/heads/main':
            trigger_pipeline(repository_name, commit_id)
        
        return {
            'statusCode': 200,
            'body': json.dumps('Event processed successfully')
        }
        
    except Exception as e:
        print(f"Error processing event: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }

def trigger_pipeline(repository_name, commit_id):
    """
    Trigger CodePipeline execution
    """
    codepipeline = boto3.client('codepipeline')
    
    try:
        response = codepipeline.start_pipeline_execution(
            name=f'{repository_name}-pipeline'
        )
        print(f"Pipeline started: {response['pipelineExecutionId']}")
    except Exception as e:
        print(f"Failed to start pipeline: {str(e)}")
```

### Advanced Automation Examples

#### Automated Branch Protection:
```python
import boto3
import json

def lambda_handler(event, context):
    """
    Automatically apply approval rules to new branches
    """
    detail = event['detail']
    
    if detail['event'] == 'referenceCreated':
        repository_name = detail['repositoryName']
        reference_name = detail['referenceName']
        
        # Apply approval rules to main and develop branches
        protected_branches = ['refs/heads/main', 'refs/heads/develop']
        
        if reference_name in protected_branches:
            apply_approval_rules(repository_name, reference_name)
    
    return {'statusCode': 200}

def apply_approval_rules(repository_name, reference_name):
    """
    Apply approval rules to protected branches
    """
    codecommit = boto3.client('codecommit')
    
    # Check if approval rule template exists
    try:
        template_name = 'MainBranchApprovalRule'
        
        # Associate template with repository
        codecommit.associate_approval_rule_template_with_repository(
            approvalRuleTemplateName=template_name,
            repositoryName=repository_name
        )
        
        print(f"Applied approval rules to {reference_name} in {repository_name}")
        
    except Exception as e:
        print(f"Error applying approval rules: {str(e)}")
```

### SNS Integration

#### Repository Triggers Configuration:
```bash
# Create SNS topic
aws sns create-topic --name codecommit-notifications

# Add trigger to repository
aws codecommit put-repository-triggers \
    --repository-name my-repo \
    --triggers '[
        {
            "name": "MainBranchTrigger",
            "destinationArn": "arn:aws:sns:us-west-2:123456789012:codecommit-notifications",
            "events": ["updateReference"],
            "branches": ["main"]
        }
    ]'
```

---

## Approval Rules and Pull Requests

### Approval Rule Templates

#### Basic Approval Rule:
```json
{
  "Version": "2018-11-08",
  "DestinationReferences": ["refs/heads/main"],
  "Statements": [
    {
      "Type": "Approvers",
      "NumberOfApprovalsNeeded": 2,
      "ApprovalPoolMembers": [
        "arn:aws:iam::123456789012:user/senior-dev-1",
        "arn:aws:iam::123456789012:user/senior-dev-2",
        "arn:aws:iam::123456789012:role/TechLead-Role"
      ]
    }
  ]
}
```

#### Advanced Approval Rule with Conditions:
```json
{
  "Version": "2018-11-08",
  "DestinationReferences": ["refs/heads/main", "refs/heads/develop"],
  "Statements": [
    {
      "Type": "Approvers",
      "NumberOfApprovalsNeeded": 2,
      "ApprovalPoolMembers": [
        "arn:aws:iam::123456789012:role/SeniorDeveloper-Role"
      ]
    },
    {
      "Type": "Approvers",
      "NumberOfApprovalsNeeded": 1,
      "ApprovalPoolMembers": [
        "arn:aws:iam::123456789012:role/SecurityReviewer-Role"
      ]
    }
  ]
}
```

#### Creating Approval Rule Template:
```bash
# Create approval rule template
aws codecommit create-approval-rule-template \
    --approval-rule-template-name "ProductionApprovalRule" \
    --approval-rule-template-description "Approval rule for production branches" \
    --approval-rule-template-content file://approval-rule.json

# Associate with repository
aws codecommit associate-approval-rule-template-with-repository \
    --approval-rule-template-name "ProductionApprovalRule" \
    --repository-name my-repo
```

### Pull Request Workflows

#### Creating Pull Requests:
```bash
# Create pull request via CLI
aws codecommit create-pull-request \
    --title "Add new feature" \
    --description "This PR adds a new authentication feature with tests" \
    --targets repositoryName=my-repo,sourceReference=refs/heads/feature/auth,destinationReference=refs/heads/main

# Add reviewers
aws codecommit update-pull-request-description \
    --pull-request-id 123 \
    --description "Updated description with reviewer assignments"
```

#### Pull Request Automation:
```python
import boto3

def auto_assign_reviewers(repository_name, pull_request_id, source_branch):
    """
    Automatically assign reviewers based on changed files
    """
    codecommit = boto3.client('codecommit')
    
    # Get changed files
    response = codecommit.get_differences(
        repositoryName=repository_name,
        beforeCommitSpecifier='main',
        afterCommitSpecifier=source_branch
    )
    
    # Determine reviewers based on file paths
    reviewers = set()
    for diff in response['differences']:
        file_path = diff['afterBlob']['path']
        
        if file_path.startswith('src/security/'):
            reviewers.add('arn:aws:iam::123456789012:user/security-lead')
        elif file_path.startswith('src/database/'):
            reviewers.add('arn:aws:iam::123456789012:user/database-expert')
        elif file_path.startswith('infrastructure/'):
            reviewers.add('arn:aws:iam::123456789012:user/devops-lead')
    
    # Create approval rule for this PR
    if reviewers:
        approval_rule = {
            "Version": "2018-11-08",
            "Statements": [
                {
                    "Type": "Approvers",
                    "NumberOfApprovalsNeeded": 1,
                    "ApprovalPoolMembers": list(reviewers)
                }
            ]
        }
        
        codecommit.create_pull_request_approval_rule(
            pullRequestId=str(pull_request_id),
            approvalRuleName=f"AutoAssigned-{pull_request_id}",
            approvalRuleContent=json.dumps(approval_rule)
        )
```

### Integration with CodeGuru Reviewer

#### Enabling CodeGuru Reviewer:
```python
import boto3

def enable_codeguru_reviewer(repository_arn):
    """
    Enable CodeGuru Reviewer for repository
    """
    codeguru_reviewer = boto3.client('codeguru-reviewer')
    
    try:
        response = codeguru_reviewer.associate_repository(
            Repository={
                'CodeCommit': {
                    'Name': repository_arn
                }
            },
            Type='CodeCommit'
        )
        
        print(f"CodeGuru Reviewer enabled: {response['RepositoryAssociation']['AssociationId']}")
        
    except Exception as e:
        print(f"Error enabling CodeGuru Reviewer: {str(e)}")
```

---

## Monitoring and Observability

### CloudWatch Metrics

#### Built-in Metrics:
- **Repository Events**: Push, pull, merge events
- **API Calls**: Number of API calls per operation
- **Error Rates**: Failed operations and errors
- **User Activity**: Active users and access patterns

#### Custom Metrics Implementation:
```python
import boto3
from datetime import datetime

def publish_custom_metrics(repository_name, metric_name, value, unit='Count'):
    """
    Publish custom metrics to CloudWatch
    """
    cloudwatch = boto3.client('cloudwatch')
    
    cloudwatch.put_metric_data(
        Namespace='CodeCommit/Repository',
        MetricData=[
            {
                'MetricName': metric_name,
                'Dimensions': [
                    {
                        'Name': 'RepositoryName',
                        'Value': repository_name
                    }
                ],
                'Value': value,
                'Unit': unit,
                'Timestamp': datetime.utcnow()
            }
        ]
    )

# Example usage
def lambda_handler(event, context):
    detail = event['detail']
    repository_name = detail['repositoryName']
    
    # Track commits per day
    publish_custom_metrics(repository_name, 'CommitsPerDay', 1)
    
    # Track pull requests
    if 'pullRequestId' in detail:
        publish_custom_metrics(repository_name, 'PullRequestsCreated', 1)
```

### CloudWatch Alarms

#### Repository Health Alarms:
```bash
# Low commit activity alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "CodeCommit-LowActivity" \
    --alarm-description "Alert when commit activity is low" \
    --metric-name "CommitsPerDay" \
    --namespace "CodeCommit/Repository" \
    --statistic "Sum" \
    --period 86400 \
    --threshold 1 \
    --comparison-operator "LessThanThreshold" \
    --evaluation-periods 2 \
    --alarm-actions "arn:aws:sns:us-west-2:123456789012:codecommit-alerts"

# High error rate alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "CodeCommit-HighErrorRate" \
    --alarm-description "Alert when error rate is high" \
    --metric-name "ErrorRate" \
    --namespace "CodeCommit/Repository" \
    --statistic "Average" \
    --period 300 \
    --threshold 5 \
    --comparison-operator "GreaterThanThreshold" \
    --evaluation-periods 2
```

### CloudTrail Logging

#### CodeCommit API Logging:
```json
{
  "eventVersion": "1.05",
  "userIdentity": {
    "type": "IAMUser",
    "principalId": "AIDACKCEVSQ6C2EXAMPLE",
    "arn": "arn:aws:iam::123456789012:user/developer",
    "accountId": "123456789012",
    "accessKeyId": "AKIAIOSFODNN7EXAMPLE",
    "userName": "developer"
  },
  "eventTime": "2023-01-01T12:00:00Z",
  "eventSource": "codecommit.amazonaws.com",
  "eventName": "GitPush",
  "awsRegion": "us-west-2",
  "sourceIPAddress": "192.168.1.100",
  "userAgent": "git/2.39.1",
  "requestParameters": {
    "repositoryName": "my-repo"
  },
  "responseElements": null,
  "requestID": "12345678-1234-1234-1234-123456789012",
  "eventID": "87654321-4321-4321-4321-210987654321",
  "eventType": "AwsApiCall",
  "recipientAccountId": "123456789012",
  "serviceEventDetails": {
    "connectionsAffected": 1
  }
}
```

### Repository Analytics

#### Activity Analysis Script:
```python
import boto3
from datetime import datetime, timedelta

def analyze_repository_activity(repository_name, days=30):
    """
    Analyze repository activity over specified period
    """
    codecommit = boto3.client('codecommit')
    cloudtrail = boto3.client('cloudtrail')
    
    end_time = datetime.utcnow()
    start_time = end_time - timedelta(days=days)
    
    # Get CloudTrail events
    events = cloudtrail.lookup_events(
        LookupAttributes=[
            {
                'AttributeKey': 'ResourceName',
                'AttributeValue': repository_name
            }
        ],
        StartTime=start_time,
        EndTime=end_time
    )
    
    # Analyze activity
    activity_stats = {
        'total_events': len(events['Events']),
        'unique_users': set(),
        'event_types': {},
        'daily_activity': {}
    }
    
    for event in events['Events']:
        # Track unique users
        if 'UserName' in event:
            activity_stats['unique_users'].add(event['UserName'])
        
        # Track event types
        event_name = event['EventName']
        activity_stats['event_types'][event_name] = \
            activity_stats['event_types'].get(event_name, 0) + 1
        
        # Track daily activity
        event_date = event['EventTime'].date()
        activity_stats['daily_activity'][event_date] = \
            activity_stats['daily_activity'].get(event_date, 0) + 1
    
    activity_stats['unique_users'] = len(activity_stats['unique_users'])
    
    return activity_stats

# Generate activity report
def generate_activity_report(repository_name):
    stats = analyze_repository_activity(repository_name)
    
    print(f"Repository Activity Report: {repository_name}")
    print(f"Total Events: {stats['total_events']}")
    print(f"Unique Users: {stats['unique_users']}")
    print(f"Event Types: {stats['event_types']}")
    
    # Most active days
    sorted_days = sorted(
        stats['daily_activity'].items(),
        key=lambda x: x[1],
        reverse=True
    )
    
    print("Most Active Days:")
    for date, count in sorted_days[:5]:
        print(f"  {date}: {count} events")
```

---

## Integration with AWS Developer Tools

### CodeBuild Integration

#### CodeBuild Source Configuration:
```yaml
# buildspec.yml
version: 0.2

phases:
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws --version
      - COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - IMAGE_TAG=${COMMIT_HASH:=latest}
  build:
    commands:
      - echo Build started on `date`
      - echo Building the Docker image...
      - docker build -t $REPOSITORY_URI:latest .
      - docker tag $REPOSITORY_URI:latest $REPOSITORY_URI:$IMAGE_TAG
  post_build:
    commands:
      - echo Build completed on `date`
      - echo Pushing the Docker images...
      - docker push $REPOSITORY_URI:latest
      - docker push $REPOSITORY_URI:$IMAGE_TAG

artifacts:
  files:
    - '**/*'
  name: myapp-$(date +%Y-%m-%d)
```

#### CodeBuild Project Configuration:
```json
{
  "name": "my-codecommit-build",
  "source": {
    "type": "CODECOMMIT",
    "location": "https://git-codecommit.us-west-2.amazonaws.com/v1/repos/my-repo",
    "gitCloneDepth": 1,
    "buildspec": "buildspec.yml"
  },
  "artifacts": {
    "type": "S3",
    "location": "my-build-artifacts-bucket/builds"
  },
  "environment": {
    "type": "LINUX_CONTAINER",
    "image": "aws/codebuild/standard:5.0",
    "computeType": "BUILD_GENERAL1_MEDIUM"
  },
  "serviceRole": "arn:aws:iam::123456789012:role/service-role/codebuild-service-role"
}
```

### CodePipeline Integration

#### Pipeline Source Stage:
```json
{
  "Name": "Source",
  "Actions": [
    {
      "Name": "SourceAction",
      "ActionTypeId": {
        "Category": "Source",
        "Owner": "AWS",
        "Provider": "CodeCommit",
        "Version": "1"
      },
      "Configuration": {
        "RepositoryName": "my-repo",
        "BranchName": "main",
        "PollForSourceChanges": "false"
      },
      "OutputArtifacts": [
        {
          "Name": "SourceOutput"
        }
      ]
    }
  ]
}
```

#### Event-Driven Pipeline:
```python
import boto3

def lambda_handler(event, context):
    """
    Trigger CodePipeline on CodeCommit changes
    """
    detail = event['detail']
    repository_name = detail['repositoryName']
    reference_name = detail['referenceName']
    
    # Only trigger on main branch changes
    if reference_name == 'refs/heads/main':
        codepipeline = boto3.client('codepipeline')
        
        try:
            response = codepipeline.start_pipeline_execution(
                name=f'{repository_name}-pipeline'
            )
            
            print(f"Pipeline started: {response['pipelineExecutionId']}")
            
            return {
                'statusCode': 200,
                'body': 'Pipeline triggered successfully'
            }
            
        except Exception as e:
            print(f"Error starting pipeline: {str(e)}")
            return {
                'statusCode': 500,
                'body': f'Error: {str(e)}'
            }
    
    return {
        'statusCode': 200,
        'body': 'No action taken'
    }
```

### CodeDeploy Integration

#### Application Configuration:
```bash
# Create CodeDeploy application
aws deploy create-application \
    --application-name MyApp \
    --compute-platform Server

# Create deployment group
aws deploy create-deployment-group \
    --application-name MyApp \
    --deployment-group-name Production \
    --service-role-arn arn:aws:iam::123456789012:role/CodeDeployServiceRole \
    --auto-rollback-configuration enabled=true,events=DEPLOYMENT_FAILURE
```

#### AppSpec File Integration:
```yaml
# appspec.yml in CodeCommit repository
version: 0.0
os: linux
files:
  - source: /
    destination: /var/www/html
hooks:
  BeforeInstall:
    - location: scripts/install_dependencies.sh
      timeout: 300
  ApplicationStart:
    - location: scripts/start_server.sh
      timeout: 300
  ApplicationStop:
    - location: scripts/stop_server.sh
      timeout: 300
```

---

## Performance Optimization

### Repository Size Management

#### Large File Handling:
```bash
# Check repository size
aws codecommit get-repository --repository-name my-repo \
    --query 'repositoryMetadata.[repositoryName,repositorySizeInBytes]'

# Use Git LFS for large files
git lfs install
git lfs track "*.zip"
git lfs track "*.tar.gz"
git lfs track "*.dmg"

# Add .gitattributes
echo "*.zip filter=lfs diff=lfs merge=lfs -text" >> .gitattributes
git add .gitattributes
git commit -m "Add LFS configuration"
```

#### Repository Cleanup:
```bash
# Clean up repository history (use with caution)
git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch large-file.zip' \
  --prune-empty --tag-name-filter cat -- --all

# Remove references and garbage collect
rm -rf .git/refs/original/
git reflog expire --expire=now --all
git gc --prune=now --aggressive
```

### Connection Optimization

#### Regional Considerations:
```python
def get_optimal_codecommit_endpoint(user_region):
    """
    Determine optimal CodeCommit endpoint based on user location
    """
    regional_endpoints = {
        'us-east-1': 'git-codecommit.us-east-1.amazonaws.com',
        'us-west-2': 'git-codecommit.us-west-2.amazonaws.com',
        'eu-west-1': 'git-codecommit.eu-west-1.amazonaws.com',
        'ap-southeast-1': 'git-codecommit.ap-southeast-1.amazonaws.com'
    }
    
    return regional_endpoints.get(user_region, regional_endpoints['us-east-1'])

# Configure Git for optimal performance
def configure_git_performance():
    """
    Configure Git for optimal CodeCommit performance
    """
    import subprocess
    
    commands = [
        ['git', 'config', '--global', 'core.preloadindex', 'true'],
        ['git', 'config', '--global', 'core.fscache', 'true'],
        ['git', 'config', '--global', 'gc.auto', '256'],
        ['git', 'config', '--global', 'http.postBuffer', '1048576000'],
        ['git', 'config', '--global', 'pack.windowMemory', '256m']
    ]
    
    for cmd in commands:
        subprocess.run(cmd)
```

### Concurrent Operations

#### Batch Operations:
```python
import boto3
from concurrent.futures import ThreadPoolExecutor, as_completed

def batch_repository_operations(repository_names, operation_func):
    """
    Perform operations on multiple repositories concurrently
    """
    results = {}
    
    with ThreadPoolExecutor(max_workers=10) as executor:
        # Submit all operations
        future_to_repo = {
            executor.submit(operation_func, repo_name): repo_name
            for repo_name in repository_names
        }
        
        # Collect results
        for future in as_completed(future_to_repo):
            repo_name = future_to_repo[future]
            try:
                result = future.result()
                results[repo_name] = {'status': 'success', 'data': result}
            except Exception as e:
                results[repo_name] = {'status': 'error', 'error': str(e)}
    
    return results

def get_repository_info(repo_name):
    """
    Get repository information
    """
    codecommit = boto3.client('codecommit')
    return codecommit.get_repository(repositoryName=repo_name)

# Example usage
repo_names = ['repo1', 'repo2', 'repo3']
results = batch_repository_operations(repo_names, get_repository_info)
```

---

## Enterprise Features and Multi-Account Strategies

### Organization-Wide Repository Management

#### Service Catalog Integration:
```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'CodeCommit Repository Product for Service Catalog'

Parameters:
  RepositoryName:
    Type: String
    Description: Name of the repository
    AllowedPattern: '^[a-zA-Z0-9._-]+$'
  
  TeamName:
    Type: String
    Description: Team responsible for the repository
    AllowedValues: [Frontend, Backend, DevOps, QA, Security]
  
  EnvironmentType:
    Type: String
    Description: Environment type
    AllowedValues: [Development, Staging, Production]

Resources:
  Repository:
    Type: AWS::CodeCommit::Repository
    Properties:
      RepositoryName: !Sub '${TeamName}-${RepositoryName}-${EnvironmentType}'
      RepositoryDescription: !Sub 'Repository for ${TeamName} team - ${EnvironmentType}'
      Tags:
        - Key: Team
          Value: !Ref TeamName
        - Key: Environment
          Value: !Ref EnvironmentType
        - Key: ManagedBy
          Value: ServiceCatalog

  ApprovalRuleTemplate:
    Type: AWS::CodeCommit::ApprovalRuleTemplate
    Properties:
      ApprovalRuleTemplateName: !Sub '${TeamName}-ApprovalRule'
      ApprovalRuleTemplateContent: !Sub |
        {
          "Version": "2018-11-08",
          "DestinationReferences": ["refs/heads/main"],
          "Statements": [
            {
              "Type": "Approvers",
              "NumberOfApprovalsNeeded": 2,
              "ApprovalPoolMembers": [
                "arn:aws:iam::${AWS::AccountId}:role/${TeamName}-Lead-Role"
              ]
            }
          ]
        }

Outputs:
  RepositoryArn:
    Description: Repository ARN
    Value: !GetAtt Repository.Arn
  
  CloneUrl:
    Description: Repository clone URL
    Value: !GetAtt Repository.CloneUrlHttp
```

### Multi-Account Architecture

#### Cross-Account Repository Access:
```python
import boto3

class CrossAccountCodeCommitManager:
    def __init__(self):
        self.sts = boto3.client('sts')
    
    def assume_role_in_account(self, account_id, role_name, session_name):
        """
        Assume role in target account
        """
        role_arn = f"arn:aws:iam::{account_id}:role/{role_name}"
        
        response = self.sts.assume_role(
            RoleArn=role_arn,
            RoleSessionName=session_name
        )
        
        credentials = response['Credentials']
        
        return boto3.client(
            'codecommit',
            aws_access_key_id=credentials['AccessKeyId'],
            aws_secret_access_key=credentials['SecretAccessKey'],
            aws_session_token=credentials['SessionToken']
        )
    
    def create_repository_in_account(self, account_id, role_name, repo_config):
        """
        Create repository in target account
        """
        codecommit = self.assume_role_in_account(
            account_id, 
            role_name, 
            f"create-repo-{repo_config['name']}"
        )
        
        try:
            response = codecommit.create_repository(**repo_config)
            return response
        except Exception as e:
            print(f"Error creating repository in account {account_id}: {str(e)}")
            return None
    
    def sync_repositories_across_accounts(self, source_account, target_accounts, repo_name):
        """
        Sync repository configuration across accounts
        """
        # Get source repository configuration
        source_codecommit = self.assume_role_in_account(
            source_account['account_id'],
            source_account['role_name'],
            'sync-repos-source'
        )
        
        source_repo = source_codecommit.get_repository(repositoryName=repo_name)
        
        # Create repository in target accounts
        for target_account in target_accounts:
            target_codecommit = self.assume_role_in_account(
                target_account['account_id'],
                target_account['role_name'],
                f"sync-repos-target-{target_account['account_id']}"
            )
            
            try:
                target_codecommit.create_repository(
                    repositoryName=repo_name,
                    repositoryDescription=source_repo['repositoryMetadata']['repositoryDescription']
                )
                print(f"Repository {repo_name} created in account {target_account['account_id']}")
            except Exception as e:
                print(f"Error creating repository in {target_account['account_id']}: {str(e)}")
```

### Backup and Disaster Recovery

#### Repository Backup Strategy:
```python
import boto3
import subprocess
import os
from datetime import datetime

class CodeCommitBackupManager:
    def __init__(self, backup_bucket):
        self.codecommit = boto3.client('codecommit')
        self.s3 = boto3.client('s3')
        self.backup_bucket = backup_bucket
    
    def backup_repository(self, repository_name, backup_path="/tmp/backups"):
        """
        Create a full backup of a CodeCommit repository
        """
        try:
            # Get repository information
            repo_info = self.codecommit.get_repository(repositoryName=repository_name)
            clone_url = repo_info['repositoryMetadata']['cloneUrlHttp']
            
            # Create backup directory
            backup_dir = f"{backup_path}/{repository_name}"
            os.makedirs(backup_dir, exist_ok=True)
            
            # Clone repository with all branches and tags
            subprocess.run([
                'git', 'clone', '--mirror', clone_url, backup_dir
            ], check=True)
            
            # Create archive
            timestamp = datetime.now().strftime('%Y%m%d-%H%M%S')
            archive_name = f"{repository_name}-backup-{timestamp}.tar.gz"
            archive_path = f"{backup_path}/{archive_name}"
            
            subprocess.run([
                'tar', '-czf', archive_path, '-C', backup_path, repository_name
            ], check=True)
            
            # Upload to S3
            s3_key = f"codecommit-backups/{repository_name}/{archive_name}"
            self.s3.upload_file(archive_path, self.backup_bucket, s3_key)
            
            # Clean up local files
            subprocess.run(['rm', '-rf', backup_dir])
            subprocess.run(['rm', archive_path])
            
            return {
                'status': 'success',
                'backup_location': f"s3://{self.backup_bucket}/{s3_key}",
                'timestamp': timestamp
            }
            
        except Exception as e:
            return {
                'status': 'error',
                'error': str(e)
            }
    
    def backup_all_repositories(self):
        """
        Backup all repositories in the account
        """
        repositories = self.codecommit.list_repositories()
        results = []
        
        for repo in repositories['repositories']:
            repo_name = repo['repositoryName']
            result = self.backup_repository(repo_name)
            result['repository'] = repo_name
            results.append(result)
        
        return results
    
    def restore_repository(self, backup_s3_key, new_repository_name=None):
        """
        Restore repository from backup
        """
        try:
            # Download backup from S3
            backup_file = f"/tmp/{backup_s3_key.split('/')[-1]}"
            self.s3.download_file(self.backup_bucket, backup_s3_key, backup_file)
            
            # Extract backup
            extract_dir = "/tmp/restore"
            subprocess.run(['mkdir', '-p', extract_dir])
            subprocess.run(['tar', '-xzf', backup_file, '-C', extract_dir])
            
            # Determine repository name
            original_name = backup_s3_key.split('/')[-2]
            restore_name = new_repository_name or f"{original_name}-restored"
            
            # Create new repository
            self.codecommit.create_repository(
                repositoryName=restore_name,
                repositoryDescription=f"Restored from backup: {backup_s3_key}"
            )
            
            # Push backup to new repository
            repo_info = self.codecommit.get_repository(repositoryName=restore_name)
            clone_url = repo_info['repositoryMetadata']['cloneUrlHttp']
            
            repo_path = f"{extract_dir}/{original_name}"
            subprocess.run([
                'git', 'push', '--mirror', clone_url
            ], cwd=repo_path, check=True)
            
            # Clean up
            subprocess.run(['rm', '-rf', extract_dir])
            subprocess.run(['rm', backup_file])
            
            return {
                'status': 'success',
                'restored_repository': restore_name
            }
            
        except Exception as e:
            return {
                'status': 'error',
                'error': str(e)
            }
```

---

## Troubleshooting Common Issues

### Authentication Issues

#### Credential Helper Problems:
```bash
# Diagnose credential issues
git config --get credential.helper
git config --get credential.UseHttpPath

# Reset credential configuration
git config --global --unset credential.helper
git config --global credential.helper '!aws codecommit credential-helper $@'
git config --global credential.UseHttpPath true

# Test AWS CLI access
aws codecommit list-repositories
aws sts get-caller-identity
```

#### Permission Errors:
```python
def diagnose_codecommit_permissions(repository_name, user_arn):
    """
    Diagnose CodeCommit permission issues
    """
    iam = boto3.client('iam')
    codecommit = boto3.client('codecommit')
    
    try:
        # Check if user can list repositories
        repositories = codecommit.list_repositories()
        print("✓ User can list repositories")
    except Exception as e:
        print(f"✗ Cannot list repositories: {str(e)}")
        return
    
    try:
        # Check if user can access specific repository
        repo_info = codecommit.get_repository(repositoryName=repository_name)
        print(f"✓ User can access repository: {repository_name}")
    except Exception as e:
        print(f"✗ Cannot access repository {repository_name}: {str(e)}")
    
    # Check IAM policies
    try:
        user_name = user_arn.split('/')[-1]
        attached_policies = iam.list_attached_user_policies(UserName=user_name)
        
        print("Attached IAM policies:")
        for policy in attached_policies['AttachedPolicies']:
            print(f"  - {policy['PolicyName']}")
    except Exception as e:
        print(f"Cannot check IAM policies: {str(e)}")
```

### Performance Issues

#### Large Repository Handling:
```bash
# Optimize Git configuration for large repositories
git config --global core.preloadindex true
git config --global core.fscache true
git config --global gc.auto 256

# Use partial clone for large repositories
git clone --filter=blob:none https://git-codecommit.region.amazonaws.com/v1/repos/large-repo

# Optimize network settings
git config --global http.postBuffer 524288000
git config --global http.maxRequestBuffer 100M
```

#### Connection Timeouts:
```python
import boto3
from botocore.config import Config

def create_optimized_codecommit_client():
    """
    Create CodeCommit client with optimized configuration
    """
    config = Config(
        region_name='us-west-2',
        retries={
            'max_attempts': 3,
            'mode': 'adaptive'
        },
        max_pool_connections=50
    )
    
    return boto3.client('codecommit', config=config)

# Usage
codecommit = create_optimized_codecommit_client()
```

### Repository Corruption Issues

#### Repository Validation:
```bash
# Validate repository integrity
git fsck --full --strict

# Check for large objects
git rev-list --objects --all | git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' | grep '^blob' | sort --numeric-sort --key=3 | tail -10

# Repair repository
git gc --aggressive --prune=now
```

#### Disaster Recovery:
```python
def emergency_repository_recovery(repository_name, backup_s3_bucket):
    """
    Emergency recovery procedure for corrupted repository
    """
    import subprocess
    import tempfile
    
    # Create temporary directory
    with tempfile.TemporaryDirectory() as temp_dir:
        try:
            # Try to clone repository
            clone_path = f"{temp_dir}/original"
            subprocess.run([
                'git', 'clone', '--mirror',
                f'https://git-codecommit.us-west-2.amazonaws.com/v1/repos/{repository_name}',
                clone_path
            ], check=True)
            
            print("✓ Repository is accessible")
            
            # Validate repository
            subprocess.run(['git', 'fsck', '--full'], cwd=clone_path, check=True)
            print("✓ Repository integrity check passed")
            
        except subprocess.CalledProcessError as e:
            print(f"✗ Repository issue detected: {e}")
            print("Attempting recovery from backup...")
            
            # Restore from latest backup
            backup_manager = CodeCommitBackupManager(backup_s3_bucket)
            
            # List available backups
            s3 = boto3.client('s3')
            backups = s3.list_objects_v2(
                Bucket=backup_s3_bucket,
                Prefix=f'codecommit-backups/{repository_name}/'
            )
            
            if 'Contents' in backups:
                # Get latest backup
                latest_backup = sorted(
                    backups['Contents'],
                    key=lambda x: x['LastModified'],
                    reverse=True
                )[0]
                
                print(f"Restoring from: {latest_backup['Key']}")
                result = backup_manager.restore_repository(
                    latest_backup['Key'],
                    f"{repository_name}-recovered"
                )
                
                return result
            else:
                return {
                    'status': 'error',
                    'error': 'No backups available'
                }
```

---

This comprehensive guide covers all aspects of AWS CodeCommit for the DevOps Engineer Professional certification. The content provides both theoretical understanding and practical implementation guidance for enterprise-scale source code management with AWS CodeCommit.