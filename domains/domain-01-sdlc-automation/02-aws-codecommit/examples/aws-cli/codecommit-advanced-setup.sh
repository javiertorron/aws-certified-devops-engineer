#!/bin/bash

# Advanced CodeCommit Repository Setup Script
# This script creates a comprehensive CodeCommit setup with security, monitoring, and automation
# Usage: ./codecommit-advanced-setup.sh [organization] [project] [environment] [team-email]

set -e  # Exit on any error

# Configuration
ORGANIZATION_NAME=${1:-"MyCompany"}
PROJECT_NAME=${2:-"WebApp"}
ENVIRONMENT=${3:-"Production"}
TEAM_EMAIL=${4:-"team@example.com"}
AWS_REGION=${AWS_REGION:-"us-west-2"}
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Repository names
PRIMARY_REPO_NAME="${ORGANIZATION_NAME}-${PROJECT_NAME}-${ENVIRONMENT}"
INFRASTRUCTURE_REPO_NAME="${ORGANIZATION_NAME}-${PROJECT_NAME}-infrastructure"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured"
        exit 1
    fi
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed. Please install jq for JSON processing."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Create KMS key for encryption
create_kms_key() {
    log_step "Creating KMS key for CodeCommit encryption..."
    
    KMS_KEY_POLICY=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${AWS_ACCOUNT_ID}:root"
            },
            "Action": "kms:*",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "codecommit.amazonaws.com"
            },
            "Action": [
                "kms:Decrypt",
                "kms:DescribeKey",
                "kms:Encrypt",
                "kms:GenerateDataKey*",
                "kms:ReEncrypt*"
            ],
            "Resource": "*"
        }
    ]
}
EOF
)
    
    # Create KMS key
    KMS_KEY_RESPONSE=$(aws kms create-key \
        --description "KMS key for ${ORGANIZATION_NAME} CodeCommit repositories" \
        --policy "$KMS_KEY_POLICY" \
        --tags TagKey=Organization,TagValue="$ORGANIZATION_NAME" \
               TagKey=Project,TagValue="$PROJECT_NAME" \
               TagKey=ManagedBy,TagValue="Script" \
        --output json)
    
    KMS_KEY_ID=$(echo "$KMS_KEY_RESPONSE" | jq -r '.KeyMetadata.KeyId')
    KMS_KEY_ARN=$(echo "$KMS_KEY_RESPONSE" | jq -r '.KeyMetadata.Arn')
    
    # Create alias
    aws kms create-alias \
        --alias-name "alias/${ORGANIZATION_NAME}-codecommit" \
        --target-key-id "$KMS_KEY_ID"
    
    log_success "KMS key created: $KMS_KEY_ARN"
}

# Create CodeCommit repositories
create_repositories() {
    log_step "Creating CodeCommit repositories..."
    
    # Create primary repository
    if aws codecommit get-repository --repository-name "$PRIMARY_REPO_NAME" &> /dev/null; then
        log_warning "Repository $PRIMARY_REPO_NAME already exists"
        PRIMARY_REPO_ARN=$(aws codecommit get-repository --repository-name "$PRIMARY_REPO_NAME" --query 'repositoryMetadata.Arn' --output text)
    else
        PRIMARY_REPO_RESPONSE=$(aws codecommit create-repository \
            --repository-name "$PRIMARY_REPO_NAME" \
            --repository-description "Primary repository for $PROJECT_NAME in $ENVIRONMENT environment" \
            --kms-key-id "$KMS_KEY_ID" \
            --tags Organization="$ORGANIZATION_NAME",Project="$PROJECT_NAME",Environment="$ENVIRONMENT",ManagedBy="Script" \
            --output json)
        
        PRIMARY_REPO_ARN=$(echo "$PRIMARY_REPO_RESPONSE" | jq -r '.repositoryMetadata.Arn')
        log_success "Primary repository created: $PRIMARY_REPO_NAME"
    fi
    
    # Create infrastructure repository
    if aws codecommit get-repository --repository-name "$INFRASTRUCTURE_REPO_NAME" &> /dev/null; then
        log_warning "Repository $INFRASTRUCTURE_REPO_NAME already exists"
        INFRASTRUCTURE_REPO_ARN=$(aws codecommit get-repository --repository-name "$INFRASTRUCTURE_REPO_NAME" --query 'repositoryMetadata.Arn' --output text)
    else
        INFRASTRUCTURE_REPO_RESPONSE=$(aws codecommit create-repository \
            --repository-name "$INFRASTRUCTURE_REPO_NAME" \
            --repository-description "Infrastructure as Code repository for $PROJECT_NAME" \
            --kms-key-id "$KMS_KEY_ID" \
            --tags Organization="$ORGANIZATION_NAME",Project="$PROJECT_NAME",Type="Infrastructure",ManagedBy="Script" \
            --output json)
        
        INFRASTRUCTURE_REPO_ARN=$(echo "$INFRASTRUCTURE_REPO_RESPONSE" | jq -r '.repositoryMetadata.Arn')
        log_success "Infrastructure repository created: $INFRASTRUCTURE_REPO_NAME"
    fi
}

# Create SNS topics for notifications
create_sns_topics() {
    log_step "Creating SNS topics for notifications..."
    
    # Primary repository notifications
    PRIMARY_TOPIC_NAME="${ORGANIZATION_NAME}-${PROJECT_NAME}-codecommit-notifications"
    if aws sns get-topic-attributes --topic-arn "arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT_ID}:${PRIMARY_TOPIC_NAME}" &> /dev/null; then
        log_warning "SNS topic $PRIMARY_TOPIC_NAME already exists"
        PRIMARY_TOPIC_ARN="arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT_ID}:${PRIMARY_TOPIC_NAME}"
    else
        PRIMARY_TOPIC_ARN=$(aws sns create-topic \
            --name "$PRIMARY_TOPIC_NAME" \
            --tags Key=Organization,Value="$ORGANIZATION_NAME" \
                   Key=Project,Value="$PROJECT_NAME" \
                   Key=ManagedBy,Value="Script" \
            --query 'TopicArn' --output text)
        log_success "Primary SNS topic created: $PRIMARY_TOPIC_ARN"
    fi
    
    # Infrastructure notifications
    INFRA_TOPIC_NAME="${ORGANIZATION_NAME}-${PROJECT_NAME}-infrastructure-notifications"
    if aws sns get-topic-attributes --topic-arn "arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT_ID}:${INFRA_TOPIC_NAME}" &> /dev/null; then
        log_warning "SNS topic $INFRA_TOPIC_NAME already exists"
        INFRA_TOPIC_ARN="arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT_ID}:${INFRA_TOPIC_NAME}"
    else
        INFRA_TOPIC_ARN=$(aws sns create-topic \
            --name "$INFRA_TOPIC_NAME" \
            --tags Key=Organization,Value="$ORGANIZATION_NAME" \
                   Key=Project,Value="$PROJECT_NAME" \
                   Key=Type,Value="Infrastructure" \
                   Key=ManagedBy,Value="Script" \
            --query 'TopicArn' --output text)
        log_success "Infrastructure SNS topic created: $INFRA_TOPIC_ARN"
    fi
    
    # Subscribe email to topics
    aws sns subscribe \
        --topic-arn "$PRIMARY_TOPIC_ARN" \
        --protocol email \
        --notification-endpoint "$TEAM_EMAIL" > /dev/null
    
    aws sns subscribe \
        --topic-arn "$INFRA_TOPIC_ARN" \
        --protocol email \
        --notification-endpoint "$TEAM_EMAIL" > /dev/null
    
    log_success "Email subscriptions created for $TEAM_EMAIL"
}

# Configure repository triggers
configure_triggers() {
    log_step "Configuring repository triggers..."
    
    # Primary repository triggers
    PRIMARY_TRIGGERS=$(cat <<EOF
[
    {
        "name": "MainBranchTrigger",
        "destinationArn": "$PRIMARY_TOPIC_ARN",
        "events": ["updateReference"],
        "branches": ["main", "master"]
    },
    {
        "name": "DevelopBranchTrigger", 
        "destinationArn": "$PRIMARY_TOPIC_ARN",
        "events": ["updateReference", "createReference"],
        "branches": ["develop", "staging"]
    }
]
EOF
)
    
    echo "$PRIMARY_TRIGGERS" > /tmp/primary_triggers.json
    
    aws codecommit put-repository-triggers \
        --repository-name "$PRIMARY_REPO_NAME" \
        --triggers file:///tmp/primary_triggers.json
    
    log_success "Primary repository triggers configured"
    
    # Infrastructure repository triggers
    INFRA_TRIGGERS=$(cat <<EOF
[
    {
        "name": "InfrastructureChangeTrigger",
        "destinationArn": "$INFRA_TOPIC_ARN",
        "events": ["updateReference"],
        "branches": ["main", "production"]
    }
]
EOF
)
    
    echo "$INFRA_TRIGGERS" > /tmp/infra_triggers.json
    
    aws codecommit put-repository-triggers \
        --repository-name "$INFRASTRUCTURE_REPO_NAME" \
        --triggers file:///tmp/infra_triggers.json
    
    log_success "Infrastructure repository triggers configured"
    
    # Clean up temporary files
    rm -f /tmp/primary_triggers.json /tmp/infra_triggers.json
}

# Create approval rule templates
create_approval_rules() {
    log_step "Creating approval rule templates..."
    
    # Production approval rule for primary repository
    if [ "$ENVIRONMENT" = "Production" ]; then
        PRODUCTION_APPROVAL_RULE_NAME="${ORGANIZATION_NAME}-${PROJECT_NAME}-production-approval"
        
        PRODUCTION_APPROVAL_CONTENT=$(cat <<EOF
{
    "Version": "2018-11-08",
    "DestinationReferences": ["refs/heads/main", "refs/heads/master"],
    "Statements": [
        {
            "Type": "Approvers",
            "NumberOfApprovalsNeeded": 2,
            "ApprovalPoolMembers": [
                "arn:aws:iam::${AWS_ACCOUNT_ID}:role/SeniorDeveloper",
                "arn:aws:iam::${AWS_ACCOUNT_ID}:role/TechLead"
            ]
        }
    ]
}
EOF
)
        
        # Create approval rule template
        if aws codecommit get-approval-rule-template --approval-rule-template-name "$PRODUCTION_APPROVAL_RULE_NAME" &> /dev/null; then
            log_warning "Approval rule template $PRODUCTION_APPROVAL_RULE_NAME already exists"
        else
            aws codecommit create-approval-rule-template \
                --approval-rule-template-name "$PRODUCTION_APPROVAL_RULE_NAME" \
                --approval-rule-template-description "Approval rule requiring senior developer approval for production" \
                --approval-rule-template-content "$PRODUCTION_APPROVAL_CONTENT" > /dev/null
            
            log_success "Production approval rule template created"
        fi
        
        # Associate with repository
        aws codecommit associate-approval-rule-template-with-repository \
            --approval-rule-template-name "$PRODUCTION_APPROVAL_RULE_NAME" \
            --repository-name "$PRIMARY_REPO_NAME" 2> /dev/null || log_warning "Approval rule already associated"
    fi
    
    # Infrastructure approval rule
    INFRASTRUCTURE_APPROVAL_RULE_NAME="${ORGANIZATION_NAME}-infrastructure-approval"
    
    INFRASTRUCTURE_APPROVAL_CONTENT=$(cat <<EOF
{
    "Version": "2018-11-08",
    "DestinationReferences": ["refs/heads/main", "refs/heads/production"],
    "Statements": [
        {
            "Type": "Approvers",
            "NumberOfApprovalsNeeded": 1,
            "ApprovalPoolMembers": [
                "arn:aws:iam::${AWS_ACCOUNT_ID}:role/DevOpsEngineer",
                "arn:aws:iam::${AWS_ACCOUNT_ID}:role/InfrastructureAdmin"
            ]
        }
    ]
}
EOF
)
    
    # Create infrastructure approval rule template
    if aws codecommit get-approval-rule-template --approval-rule-template-name "$INFRASTRUCTURE_APPROVAL_RULE_NAME" &> /dev/null; then
        log_warning "Approval rule template $INFRASTRUCTURE_APPROVAL_RULE_NAME already exists"
    else
        aws codecommit create-approval-rule-template \
            --approval-rule-template-name "$INFRASTRUCTURE_APPROVAL_RULE_NAME" \
            --approval-rule-template-description "Approval rule for infrastructure changes" \
            --approval-rule-template-content "$INFRASTRUCTURE_APPROVAL_CONTENT" > /dev/null
        
        log_success "Infrastructure approval rule template created"
    fi
    
    # Associate with infrastructure repository
    aws codecommit associate-approval-rule-template-with-repository \
        --approval-rule-template-name "$INFRASTRUCTURE_APPROVAL_RULE_NAME" \
        --repository-name "$INFRASTRUCTURE_REPO_NAME" 2> /dev/null || log_warning "Approval rule already associated"
}

# Create IAM policies and roles
create_iam_resources() {
    log_step "Creating IAM policies and roles..."
    
    # Developer policy
    DEVELOPER_POLICY_NAME="${ORGANIZATION_NAME}-${PROJECT_NAME}-developer-policy"
    DEVELOPER_POLICY_DOC=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "codecommit:BatchGetRepositories",
                "codecommit:Get*",
                "codecommit:List*",
                "codecommit:GitPull"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "codecommit:GitPush",
                "codecommit:Merge*",
                "codecommit:Put*",
                "codecommit:Create*",
                "codecommit:Update*",
                "codecommit:Test*"
            ],
            "Resource": [
                "$PRIMARY_REPO_ARN",
                "$INFRASTRUCTURE_REPO_ARN"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "codecommit:CreatePullRequest",
                "codecommit:DescribePullRequestEvents",
                "codecommit:GetPullRequest",
                "codecommit:ListPullRequests",
                "codecommit:MergePullRequestByFastForward",
                "codecommit:PostCommentForPullRequest",
                "codecommit:UpdatePullRequest*"
            ],
            "Resource": [
                "$PRIMARY_REPO_ARN",
                "$INFRASTRUCTURE_REPO_ARN"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "kms:Decrypt",
                "kms:DescribeKey"
            ],
            "Resource": "$KMS_KEY_ARN"
        }
    ]
}
EOF
)
    
    # Create developer policy
    if aws iam get-policy --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${DEVELOPER_POLICY_NAME}" &> /dev/null; then
        log_warning "Developer policy already exists"
    else
        aws iam create-policy \
            --policy-name "$DEVELOPER_POLICY_NAME" \
            --policy-document "$DEVELOPER_POLICY_DOC" \
            --description "Policy for developers to access CodeCommit repositories" > /dev/null
        
        log_success "Developer policy created"
    fi
    
    # CI/CD policy
    CICD_POLICY_NAME="${ORGANIZATION_NAME}-${PROJECT_NAME}-cicd-policy"
    CICD_POLICY_DOC=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "codecommit:BatchGetRepositories",
                "codecommit:Get*",
                "codecommit:List*",
                "codecommit:GitPull",
                "codecommit:UploadArchive"
            ],
            "Resource": [
                "$PRIMARY_REPO_ARN",
                "$INFRASTRUCTURE_REPO_ARN"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "kms:Decrypt",
                "kms:DescribeKey"
            ],
            "Resource": "$KMS_KEY_ARN"
        }
    ]
}
EOF
)
    
    # Create CI/CD policy
    if aws iam get-policy --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${CICD_POLICY_NAME}" &> /dev/null; then
        log_warning "CI/CD policy already exists"
    else
        aws iam create-policy \
            --policy-name "$CICD_POLICY_NAME" \
            --policy-document "$CICD_POLICY_DOC" \
            --description "Policy for CI/CD pipeline to access CodeCommit repositories" > /dev/null
        
        log_success "CI/CD policy created"
    fi
}

# Create Lambda function for advanced monitoring
create_monitoring_function() {
    log_step "Creating Lambda function for repository monitoring..."
    
    # Create Lambda execution role
    LAMBDA_ROLE_NAME="${ORGANIZATION_NAME}-${PROJECT_NAME}-lambda-codecommit-role"
    
    LAMBDA_TRUST_POLICY=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
)
    
    if aws iam get-role --role-name "$LAMBDA_ROLE_NAME" &> /dev/null; then
        log_warning "Lambda role already exists"
    else
        aws iam create-role \
            --role-name "$LAMBDA_ROLE_NAME" \
            --assume-role-policy-document "$LAMBDA_TRUST_POLICY" \
            --description "Role for CodeCommit monitoring Lambda function" > /dev/null
        
        # Attach basic execution policy
        aws iam attach-role-policy \
            --role-name "$LAMBDA_ROLE_NAME" \
            --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
        
        log_success "Lambda role created"
    fi
    
    # Create custom policy for Lambda
    LAMBDA_POLICY_NAME="${ORGANIZATION_NAME}-${PROJECT_NAME}-lambda-codecommit-policy"
    LAMBDA_POLICY_DOC=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "codecommit:GetRepository",
                "codecommit:GetCommit",
                "codecommit:GetPullRequest",
                "codecommit:GetDifferences"
            ],
            "Resource": [
                "$PRIMARY_REPO_ARN",
                "$INFRASTRUCTURE_REPO_ARN"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "sns:Publish"
            ],
            "Resource": [
                "$PRIMARY_TOPIC_ARN",
                "$INFRA_TOPIC_ARN"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "cloudwatch:PutMetricData"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "kms:Decrypt",
                "kms:DescribeKey"
            ],
            "Resource": "$KMS_KEY_ARN"
        }
    ]
}
EOF
)
    
    if aws iam get-policy --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${LAMBDA_POLICY_NAME}" &> /dev/null; then
        log_warning "Lambda policy already exists"
    else
        aws iam create-policy \
            --policy-name "$LAMBDA_POLICY_NAME" \
            --policy-document "$LAMBDA_POLICY_DOC" \
            --description "Policy for CodeCommit monitoring Lambda function" > /dev/null
        
        log_success "Lambda policy created"
    fi
    
    # Attach custom policy to role
    aws iam attach-role-policy \
        --role-name "$LAMBDA_ROLE_NAME" \
        --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${LAMBDA_POLICY_NAME}"
    
    # Create Lambda function code
    LAMBDA_CODE=$(cat <<'EOF'
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
                send_commit_notification(repository_name, detail)
        
        return {'statusCode': 200}
        
    except Exception as e:
        print(f"Error in repository monitoring: {str(e)}")
        return {'statusCode': 500}

def send_commit_notification(repository_name, detail):
    try:
        commit_id = detail.get('commitId', 'Unknown')
        reference_name = detail.get('referenceName', 'Unknown')
        
        # Determine SNS topic based on repository type
        if 'infrastructure' in repository_name:
            topic_arn = os.getenv('INFRASTRUCTURE_SNS_TOPIC_ARN')
        else:
            topic_arn = os.getenv('SNS_TOPIC_ARN')
        
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
)
    
    # Create Lambda function ZIP file
    echo "$LAMBDA_CODE" > /tmp/lambda_function.py
    cd /tmp && zip lambda_function.zip lambda_function.py
    
    # Create Lambda function
    LAMBDA_FUNCTION_NAME="${ORGANIZATION_NAME}-${PROJECT_NAME}-repo-monitor"
    
    if aws lambda get-function --function-name "$LAMBDA_FUNCTION_NAME" &> /dev/null; then
        log_warning "Lambda function already exists"
        
        # Update function code
        aws lambda update-function-code \
            --function-name "$LAMBDA_FUNCTION_NAME" \
            --zip-file fileb:///tmp/lambda_function.zip > /dev/null
    else
        aws lambda create-function \
            --function-name "$LAMBDA_FUNCTION_NAME" \
            --runtime python3.9 \
            --role "arn:aws:iam::${AWS_ACCOUNT_ID}:role/${LAMBDA_ROLE_NAME}" \
            --handler lambda_function.lambda_handler \
            --zip-file fileb:///tmp/lambda_function.zip \
            --timeout 300 \
            --environment Variables="{SNS_TOPIC_ARN=$PRIMARY_TOPIC_ARN,INFRASTRUCTURE_SNS_TOPIC_ARN=$INFRA_TOPIC_ARN}" \
            --tags Organization="$ORGANIZATION_NAME",Project="$PROJECT_NAME",ManagedBy="Script" > /dev/null
        
        log_success "Lambda function created"
    fi
    
    # Clean up
    rm -f /tmp/lambda_function.py /tmp/lambda_function.zip
}

# Create EventBridge rules
create_eventbridge_rules() {
    log_step "Creating EventBridge rules..."
    
    # Rule for primary repository
    PRIMARY_RULE_NAME="${ORGANIZATION_NAME}-${PROJECT_NAME}-codecommit-events"
    
    PRIMARY_EVENT_PATTERN=$(cat <<EOF
{
    "source": ["aws.codecommit"],
    "detail-type": ["CodeCommit Repository State Change"],
    "detail": {
        "repositoryName": ["$PRIMARY_REPO_NAME"]
    }
}
EOF
)
    
    if aws events describe-rule --name "$PRIMARY_RULE_NAME" &> /dev/null; then
        log_warning "EventBridge rule $PRIMARY_RULE_NAME already exists"
    else
        aws events put-rule \
            --name "$PRIMARY_RULE_NAME" \
            --description "Capture CodeCommit events for primary repository" \
            --event-pattern "$PRIMARY_EVENT_PATTERN" \
            --state ENABLED > /dev/null
        
        log_success "Primary repository EventBridge rule created"
    fi
    
    # Rule for infrastructure repository
    INFRA_RULE_NAME="${ORGANIZATION_NAME}-${PROJECT_NAME}-infrastructure-events"
    
    INFRA_EVENT_PATTERN=$(cat <<EOF
{
    "source": ["aws.codecommit"],
    "detail-type": ["CodeCommit Repository State Change"],
    "detail": {
        "repositoryName": ["$INFRASTRUCTURE_REPO_NAME"]
    }
}
EOF
)
    
    if aws events describe-rule --name "$INFRA_RULE_NAME" &> /dev/null; then
        log_warning "EventBridge rule $INFRA_RULE_NAME already exists"
    else
        aws events put-rule \
            --name "$INFRA_RULE_NAME" \
            --description "Capture CodeCommit events for infrastructure repository" \
            --event-pattern "$INFRA_EVENT_PATTERN" \
            --state ENABLED > /dev/null
        
        log_success "Infrastructure repository EventBridge rule created"
    fi
    
    # Add Lambda targets to rules
    LAMBDA_FUNCTION_ARN="arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:${LAMBDA_FUNCTION_NAME}"
    
    aws events put-targets \
        --rule "$PRIMARY_RULE_NAME" \
        --targets "Id"="1","Arn"="$LAMBDA_FUNCTION_ARN" > /dev/null
    
    aws events put-targets \
        --rule "$INFRA_RULE_NAME" \
        --targets "Id"="1","Arn"="$LAMBDA_FUNCTION_ARN" > /dev/null
    
    # Grant EventBridge permission to invoke Lambda
    aws lambda add-permission \
        --function-name "$LAMBDA_FUNCTION_NAME" \
        --statement-id "AllowExecutionFromEventBridge1" \
        --action lambda:InvokeFunction \
        --principal events.amazonaws.com \
        --source-arn "arn:aws:events:${AWS_REGION}:${AWS_ACCOUNT_ID}:rule/${PRIMARY_RULE_NAME}" 2> /dev/null || true
    
    aws lambda add-permission \
        --function-name "$LAMBDA_FUNCTION_NAME" \
        --statement-id "AllowExecutionFromEventBridge2" \
        --action lambda:InvokeFunction \
        --principal events.amazonaws.com \
        --source-arn "arn:aws:events:${AWS_REGION}:${AWS_ACCOUNT_ID}:rule/${INFRA_RULE_NAME}" 2> /dev/null || true
    
    log_success "EventBridge rules and targets configured"
}

# Create CloudWatch alarms
create_cloudwatch_alarms() {
    log_step "Creating CloudWatch alarms..."
    
    # Low activity alarm for primary repository
    aws cloudwatch put-metric-alarm \
        --alarm-name "${ORGANIZATION_NAME}-${PROJECT_NAME}-${ENVIRONMENT}-low-activity" \
        --alarm-description "Alert when repository activity is low" \
        --metric-name "CommitsPerDay" \
        --namespace "CodeCommit/Repository" \
        --statistic "Sum" \
        --period 86400 \
        --threshold 1 \
        --comparison-operator "LessThanThreshold" \
        --evaluation-periods 2 \
        --alarm-actions "$PRIMARY_TOPIC_ARN" \
        --dimensions Name=RepositoryName,Value="$PRIMARY_REPO_NAME" \
        --tags Key=Organization,Value="$ORGANIZATION_NAME" \
               Key=Project,Value="$PROJECT_NAME" \
               Key=Environment,Value="$ENVIRONMENT" \
               Key=ManagedBy,Value="Script"
    
    log_success "CloudWatch alarm created for low activity"
}

# Generate summary report
generate_summary() {
    log_step "Generating setup summary..."
    
    # Get repository URLs
    PRIMARY_CLONE_URL=$(aws codecommit get-repository --repository-name "$PRIMARY_REPO_NAME" --query 'repositoryMetadata.cloneUrlHttp' --output text)
    INFRA_CLONE_URL=$(aws codecommit get-repository --repository-name "$INFRASTRUCTURE_REPO_NAME" --query 'repositoryMetadata.cloneUrlHttp' --output text)
    
    echo
    echo "========================================="
    echo "         CODECOMMIT SETUP COMPLETE      "
    echo "========================================="
    echo
    echo "Organization: $ORGANIZATION_NAME"
    echo "Project: $PROJECT_NAME"
    echo "Environment: $ENVIRONMENT"
    echo "Team Email: $TEAM_EMAIL"
    echo
    echo "REPOSITORIES CREATED:"
    echo "  Primary Repository: $PRIMARY_REPO_NAME"
    echo "  Clone URL: $PRIMARY_CLONE_URL"
    echo
    echo "  Infrastructure Repository: $INFRASTRUCTURE_REPO_NAME"
    echo "  Clone URL: $INFRA_CLONE_URL"
    echo
    echo "SECURITY:"
    echo "  KMS Key: $KMS_KEY_ARN"
    echo "  Encryption: Enabled"
    echo "  Approval Rules: Configured"
    echo
    echo "NOTIFICATIONS:"
    echo "  Primary Topic: $PRIMARY_TOPIC_ARN"
    echo "  Infrastructure Topic: $INFRA_TOPIC_ARN"
    echo "  Email: $TEAM_EMAIL"
    echo
    echo "MONITORING:"
    echo "  Lambda Function: $LAMBDA_FUNCTION_NAME"
    echo "  CloudWatch Alarms: Enabled"
    echo "  EventBridge Rules: Configured"
    echo
    echo "NEXT STEPS:"
    echo "  1. Check your email and confirm SNS subscriptions"
    echo "  2. Configure Git credentials:"
    echo "     git config --global credential.helper '!aws codecommit credential-helper \$@'"
    echo "     git config --global credential.UseHttpPath true"
    echo "  3. Clone repositories:"
    echo "     git clone $PRIMARY_CLONE_URL"
    echo "     git clone $INFRA_CLONE_URL"
    echo "  4. Set up your development environment"
    echo "  5. Create your first commit to test the setup"
    echo
    echo "========================================="
    
    log_success "Advanced CodeCommit setup completed successfully!"
}

# Main execution
main() {
    echo "========================================="
    echo "    ADVANCED CODECOMMIT SETUP SCRIPT    "
    echo "========================================="
    echo
    echo "Organization: $ORGANIZATION_NAME"
    echo "Project: $PROJECT_NAME"
    echo "Environment: $ENVIRONMENT"
    echo "Team Email: $TEAM_EMAIL"
    echo "AWS Region: $AWS_REGION"
    echo "AWS Account: $AWS_ACCOUNT_ID"
    echo
    
    read -p "Do you want to continue with this configuration? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 1
    fi
    
    check_prerequisites
    create_kms_key
    create_repositories
    create_sns_topics
    configure_triggers
    create_approval_rules
    create_iam_resources
    create_monitoring_function
    create_eventbridge_rules
    create_cloudwatch_alarms
    generate_summary
}

# Execute main function
main "$@"