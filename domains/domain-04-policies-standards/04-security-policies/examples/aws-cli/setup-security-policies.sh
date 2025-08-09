#!/bin/bash

# AWS CLI Script for Security Policies Setup
# This script demonstrates security policy implementation using AWS CLI
# Prerequisites: AWS CLI configured with appropriate permissions

set -euo pipefail

# Configuration variables
PROJECT_NAME="${PROJECT_NAME:-devops-security}"
ENVIRONMENT="${ENVIRONMENT:-production}"
AWS_REGION="${AWS_REGION:-us-east-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Function to check if AWS CLI is configured
check_aws_cli() {
    log_info "Checking AWS CLI configuration..."
    
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS CLI is not configured properly"
        exit 1
    fi
    
    log_success "AWS CLI is properly configured"
    log_info "Account ID: $ACCOUNT_ID"
    log_info "Region: $AWS_REGION"
}

# Function to create KMS key for encryption
create_kms_key() {
    log_info "Creating KMS key for security policies..."
    
    KMS_KEY_POLICY='{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "Enable IAM User Permissions",
                "Effect": "Allow",
                "Principal": {
                    "AWS": "arn:aws:iam::'$ACCOUNT_ID':root"
                },
                "Action": "kms:*",
                "Resource": "*"
            },
            {
                "Sid": "Allow CloudTrail and S3 Services",
                "Effect": "Allow",
                "Principal": {
                    "Service": [
                        "cloudtrail.amazonaws.com",
                        "s3.amazonaws.com"
                    ]
                },
                "Action": [
                    "kms:Encrypt",
                    "kms:Decrypt",
                    "kms:ReEncrypt*",
                    "kms:GenerateDataKey*",
                    "kms:DescribeKey"
                ],
                "Resource": "*"
            }
        ]
    }'
    
    KMS_KEY_ID=$(aws kms create-key \
        --description "Security policies encryption key for $PROJECT_NAME" \
        --policy "$KMS_KEY_POLICY" \
        --tags TagKey=Project,TagValue=$PROJECT_NAME TagKey=Environment,TagValue=$ENVIRONMENT \
        --query 'KeyMetadata.KeyId' \
        --output text)
    
    log_success "Created KMS key: $KMS_KEY_ID"
    
    # Create alias for the key
    aws kms create-alias \
        --alias-name "alias/$PROJECT_NAME-security-key" \
        --target-key-id "$KMS_KEY_ID"
    
    log_success "Created KMS key alias: alias/$PROJECT_NAME-security-key"
    
    echo "$KMS_KEY_ID"
}

# Function to set up account password policy
setup_password_policy() {
    log_info "Setting up account password policy..."
    
    aws iam update-account-password-policy \
        --minimum-password-length 14 \
        --require-symbols \
        --require-numbers \
        --require-uppercase-characters \
        --require-lowercase-characters \
        --allow-users-to-change-password \
        --max-password-age 90 \
        --password-reuse-prevention 5 \
        --no-hard-expiry
    
    log_success "Account password policy configured"
}

# Function to create permissions boundary policy
create_permissions_boundary() {
    log_info "Creating permissions boundary policy..."
    
    PERMISSIONS_BOUNDARY_POLICY='{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "AllowBasicAWSServiceInteractions",
                "Effect": "Allow",
                "Action": [
                    "logs:CreateLogGroup",
                    "logs:CreateLogStream",
                    "logs:PutLogEvents",
                    "logs:DescribeLogGroups",
                    "logs:DescribeLogStreams"
                ],
                "Resource": "arn:aws:logs:*:'$ACCOUNT_ID':log-group:/aws/'$PROJECT_NAME'/*"
            },
            {
                "Sid": "AllowCloudWatchMetrics",
                "Effect": "Allow",
                "Action": [
                    "cloudwatch:PutMetricData",
                    "cloudwatch:GetMetricStatistics",
                    "cloudwatch:ListMetrics"
                ],
                "Resource": "*",
                "Condition": {
                    "StringLike": {
                        "cloudwatch:namespace": "'$PROJECT_NAME'/*"
                    }
                }
            },
            {
                "Sid": "AllowS3AccessToProjectBuckets",
                "Effect": "Allow",
                "Action": [
                    "s3:GetObject",
                    "s3:PutObject",
                    "s3:DeleteObject",
                    "s3:ListBucket"
                ],
                "Resource": [
                    "arn:aws:s3:::'$PROJECT_NAME'-*",
                    "arn:aws:s3:::'$PROJECT_NAME'-*/*"
                ]
            },
            {
                "Sid": "DenyAccessToSensitiveServices",
                "Effect": "Deny",
                "Action": [
                    "iam:CreatePolicy",
                    "iam:DeletePolicy",
                    "iam:CreateUser",
                    "iam:DeleteUser",
                    "iam:AttachUserPolicy",
                    "iam:DetachUserPolicy",
                    "organizations:*",
                    "account:*"
                ],
                "Resource": "*"
            }
        ]
    }'
    
    aws iam create-policy \
        --policy-name "$PROJECT_NAME-permissions-boundary" \
        --policy-document "$PERMISSIONS_BOUNDARY_POLICY" \
        --description "Permissions boundary for $PROJECT_NAME resources" \
        --tags Key=Project,Value=$PROJECT_NAME Key=Environment,Value=$ENVIRONMENT
    
    log_success "Created permissions boundary policy: $PROJECT_NAME-permissions-boundary"
}

# Function to create security audit role
create_security_audit_role() {
    log_info "Creating security audit role..."
    
    ASSUME_ROLE_POLICY='{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "AWS": "arn:aws:iam::'$ACCOUNT_ID':root"
                },
                "Action": "sts:AssumeRole",
                "Condition": {
                    "Bool": {
                        "aws:MultiFactorAuthPresent": "true"
                    },
                    "StringEquals": {
                        "sts:ExternalId": "'$PROJECT_NAME'-audit-external-id"
                    }
                }
            }
        ]
    }'
    
    aws iam create-role \
        --role-name "$PROJECT_NAME-security-audit-role" \
        --assume-role-policy-document "$ASSUME_ROLE_POLICY" \
        --description "Security audit role for $PROJECT_NAME" \
        --tags Key=Project,Value=$PROJECT_NAME Key=Environment,Value=$ENVIRONMENT
    
    # Attach managed policies
    aws iam attach-role-policy \
        --role-name "$PROJECT_NAME-security-audit-role" \
        --policy-arn "arn:aws:iam::aws:policy/SecurityAudit"
    
    aws iam attach-role-policy \
        --role-name "$PROJECT_NAME-security-audit-role" \
        --policy-arn "arn:aws:iam::aws:policy/ReadOnlyAccess"
    
    log_success "Created security audit role: $PROJECT_NAME-security-audit-role"
}

# Function to enable GuardDuty
enable_guardduty() {
    log_info "Enabling GuardDuty..."
    
    # Check if GuardDuty is already enabled
    if aws guardduty list-detectors --query 'DetectorIds[0]' --output text | grep -q "None"; then
        DETECTOR_ID=$(aws guardduty create-detector \
            --enable \
            --finding-publishing-frequency FIFTEEN_MINUTES \
            --data-sources S3Logs='{Enable=true}',KubernetesConfiguration='{AuditLogs={Enable=true}}',MalwareProtection='{ScanEc2InstanceWithFindings={EbsVolumes=true}}' \
            --tags Project=$PROJECT_NAME,Environment=$ENVIRONMENT \
            --query 'DetectorId' \
            --output text)
        
        log_success "GuardDuty enabled with detector ID: $DETECTOR_ID"
    else
        DETECTOR_ID=$(aws guardduty list-detectors --query 'DetectorIds[0]' --output text)
        log_info "GuardDuty already enabled with detector ID: $DETECTOR_ID"
    fi
}

# Function to set up Config
setup_config() {
    log_info "Setting up AWS Config..."
    
    # Create S3 bucket for Config
    CONFIG_BUCKET="$PROJECT_NAME-config-$ACCOUNT_ID-$AWS_REGION"
    aws s3 mb "s3://$CONFIG_BUCKET" --region "$AWS_REGION" || log_warning "Config bucket may already exist"
    
    # Apply bucket policy for Config
    CONFIG_BUCKET_POLICY='{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "AWSConfigBucketPermissionsCheck",
                "Effect": "Allow",
                "Principal": {
                    "Service": "config.amazonaws.com"
                },
                "Action": "s3:GetBucketAcl",
                "Resource": "arn:aws:s3:::'$CONFIG_BUCKET'",
                "Condition": {
                    "StringEquals": {
                        "AWS:SourceAccount": "'$ACCOUNT_ID'"
                    }
                }
            },
            {
                "Sid": "AWSConfigBucketExistenceCheck",
                "Effect": "Allow",
                "Principal": {
                    "Service": "config.amazonaws.com"
                },
                "Action": "s3:ListBucket",
                "Resource": "arn:aws:s3:::'$CONFIG_BUCKET'",
                "Condition": {
                    "StringEquals": {
                        "AWS:SourceAccount": "'$ACCOUNT_ID'"
                    }
                }
            },
            {
                "Sid": "AWSConfigBucketDelivery",
                "Effect": "Allow",
                "Principal": {
                    "Service": "config.amazonaws.com"
                },
                "Action": "s3:PutObject",
                "Resource": "arn:aws:s3:::'$CONFIG_BUCKET'/*",
                "Condition": {
                    "StringEquals": {
                        "s3:x-amz-acl": "bucket-owner-full-control",
                        "AWS:SourceAccount": "'$ACCOUNT_ID'"
                    }
                }
            }
        ]
    }'
    
    aws s3api put-bucket-policy \
        --bucket "$CONFIG_BUCKET" \
        --policy "$CONFIG_BUCKET_POLICY"
    
    # Create Config service role
    CONFIG_ROLE_POLICY='{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "config.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }'
    
    aws iam create-role \
        --role-name "$PROJECT_NAME-config-role" \
        --assume-role-policy-document "$CONFIG_ROLE_POLICY" \
        --tags Key=Project,Value=$PROJECT_NAME Key=Environment,Value=$ENVIRONMENT || log_warning "Config role may already exist"
    
    aws iam attach-role-policy \
        --role-name "$PROJECT_NAME-config-role" \
        --policy-arn "arn:aws:iam::aws:policy/service-role/ConfigRole"
    
    # Create configuration recorder
    aws configservice put-configuration-recorder \
        --configuration-recorder name="$PROJECT_NAME-recorder",roleARN="arn:aws:iam::$ACCOUNT_ID:role/$PROJECT_NAME-config-role",recordingGroup='{allSupported=true,includeGlobalResourceTypes=true}'
    
    # Create delivery channel
    aws configservice put-delivery-channel \
        --delivery-channel name="$PROJECT_NAME-delivery-channel",s3BucketName="$CONFIG_BUCKET",configSnapshotDeliveryProperties='{deliveryFrequency=TwentyFour_Hours}'
    
    # Start configuration recorder
    aws configservice start-configuration-recorder \
        --configuration-recorder-name "$PROJECT_NAME-recorder"
    
    log_success "AWS Config configured with bucket: $CONFIG_BUCKET"
}

# Function to create Config rules
create_config_rules() {
    log_info "Creating Config rules..."
    
    # Encrypted volumes rule
    aws configservice put-config-rule \
        --config-rule '{
            "ConfigRuleName": "encrypted-volumes",
            "Description": "Checks whether Amazon EBS volumes are encrypted",
            "Source": {
                "Owner": "AWS",
                "SourceIdentifier": "ENCRYPTED_VOLUMES"
            }
        }'
    
    # S3 bucket public read prohibited
    aws configservice put-config-rule \
        --config-rule '{
            "ConfigRuleName": "s3-bucket-public-read-prohibited",
            "Description": "Checks if S3 buckets allow public read access",
            "Source": {
                "Owner": "AWS",
                "SourceIdentifier": "S3_BUCKET_PUBLIC_READ_PROHIBITED"
            }
        }'
    
    # Root access key check
    aws configservice put-config-rule \
        --config-rule '{
            "ConfigRuleName": "root-access-key-check",
            "Description": "Checks whether root access keys are available",
            "Source": {
                "Owner": "AWS",
                "SourceIdentifier": "ROOT_ACCESS_KEY_CHECK"
            }
        }'
    
    # IAM password policy
    aws configservice put-config-rule \
        --config-rule '{
            "ConfigRuleName": "iam-password-policy",
            "Description": "Checks whether the IAM password policy meets specified requirements",
            "Source": {
                "Owner": "AWS",
                "SourceIdentifier": "IAM_PASSWORD_POLICY"
            },
            "InputParameters": "{\"RequireUppercaseCharacters\":\"true\",\"RequireLowercaseCharacters\":\"true\",\"RequireSymbols\":\"true\",\"RequireNumbers\":\"true\",\"MinimumPasswordLength\":\"14\",\"PasswordReusePrevention\":\"5\",\"MaxPasswordAge\":\"90\"}"
        }'
    
    log_success "Created Config rules for security compliance"
}

# Function to enable Security Hub
enable_security_hub() {
    log_info "Enabling Security Hub..."
    
    aws securityhub enable-security-hub \
        --tags Project=$PROJECT_NAME,Environment=$ENVIRONMENT || log_warning "Security Hub may already be enabled"
    
    # Enable AWS Foundational Security Standard
    aws securityhub batch-enable-standards \
        --standards-subscription-requests StandardsArn="arn:aws:securityhub:::ruleset/finding-format/aws-foundational-security-standard/v/1.0.0"
    
    log_success "Security Hub enabled with AWS Foundational Security Standard"
}

# Function to create CloudWatch security dashboard
create_security_dashboard() {
    log_info "Creating CloudWatch security dashboard..."
    
    DASHBOARD_BODY='{
        "widgets": [
            {
                "type": "metric",
                "x": 0,
                "y": 0,
                "width": 12,
                "height": 6,
                "properties": {
                    "metrics": [
                        [ "AWS/Config", "ComplianceByConfigRule", "RuleName", "encrypted-volumes", "ComplianceType", "NON_COMPLIANT" ],
                        [ ".", ".", ".", "s3-bucket-public-read-prohibited", ".", "." ],
                        [ ".", ".", ".", "root-access-key-check", ".", "." ],
                        [ ".", ".", ".", "iam-password-policy", ".", "." ]
                    ],
                    "period": 300,
                    "stat": "Maximum",
                    "region": "'$AWS_REGION'",
                    "title": "Config Rule Non-Compliance"
                }
            },
            {
                "type": "metric",
                "x": 12,
                "y": 0,
                "width": 12,
                "height": 6,
                "properties": {
                    "metrics": [
                        [ "AWS/GuardDuty", "FindingCount" ]
                    ],
                    "period": 300,
                    "stat": "Sum",
                    "region": "'$AWS_REGION'",
                    "title": "GuardDuty Findings"
                }
            }
        ]
    }'
    
    aws cloudwatch put-dashboard \
        --dashboard-name "$PROJECT_NAME-security-dashboard" \
        --dashboard-body "$DASHBOARD_BODY"
    
    log_success "Created security dashboard: $PROJECT_NAME-security-dashboard"
}

# Function to create SNS topic for security alerts
create_security_alerts_topic() {
    log_info "Creating SNS topic for security alerts..."
    
    TOPIC_ARN=$(aws sns create-topic \
        --name "$PROJECT_NAME-security-alerts" \
        --attributes DisplayName="Security Alerts for $PROJECT_NAME" \
        --tags Key=Project,Value=$PROJECT_NAME Key=Environment,Value=$ENVIRONMENT \
        --query 'TopicArn' \
        --output text)
    
    log_success "Created SNS topic: $TOPIC_ARN"
    
    # Set topic policy
    TOPIC_POLICY='{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": [
                        "events.amazonaws.com",
                        "cloudwatch.amazonaws.com"
                    ]
                },
                "Action": "sns:Publish",
                "Resource": "'$TOPIC_ARN'"
            }
        ]
    }'
    
    aws sns set-topic-attributes \
        --topic-arn "$TOPIC_ARN" \
        --attribute-name Policy \
        --attribute-value "$TOPIC_POLICY"
    
    echo "$TOPIC_ARN"
}

# Function to create EventBridge rules for security events
create_eventbridge_rules() {
    local TOPIC_ARN=$1
    log_info "Creating EventBridge rules for security events..."
    
    # GuardDuty findings rule
    aws events put-rule \
        --name "$PROJECT_NAME-guardduty-findings" \
        --description "Capture GuardDuty findings" \
        --event-pattern '{
            "source": ["aws.guardduty"],
            "detail-type": ["GuardDuty Finding"],
            "detail": {
                "severity": [4.0, 4.1, 4.2, 4.3, 7.0, 7.1, 7.2, 7.3, 8.0, 8.1, 8.2, 8.3]
            }
        }' \
        --state ENABLED
    
    aws events put-targets \
        --rule "$PROJECT_NAME-guardduty-findings" \
        --targets "Id"="1","Arn"="$TOPIC_ARN"
    
    # Config compliance rule
    aws events put-rule \
        --name "$PROJECT_NAME-config-compliance" \
        --description "Capture Config compliance changes" \
        --event-pattern '{
            "source": ["aws.config"],
            "detail-type": ["Config Rules Compliance Change"],
            "detail": {
                "newEvaluationResult": {
                    "complianceType": ["NON_COMPLIANT"]
                }
            }
        }' \
        --state ENABLED
    
    aws events put-targets \
        --rule "$PROJECT_NAME-config-compliance" \
        --targets "Id"="1","Arn"="$TOPIC_ARN"
    
    log_success "Created EventBridge rules for security monitoring"
}

# Function to display setup summary
display_summary() {
    log_info "Security Policies Setup Summary:"
    echo "=================================="
    echo "Project Name: $PROJECT_NAME"
    echo "Environment: $ENVIRONMENT"
    echo "AWS Region: $AWS_REGION"
    echo "Account ID: $ACCOUNT_ID"
    echo ""
    echo "Components Configured:"
    echo "- Account Password Policy"
    echo "- Permissions Boundary Policy"
    echo "- Security Audit Role"
    echo "- AWS Config with Security Rules"
    echo "- GuardDuty Threat Detection"
    echo "- Security Hub"
    echo "- CloudWatch Security Dashboard"
    echo "- SNS Security Alerts Topic"
    echo "- EventBridge Security Event Rules"
    echo ""
    log_success "Security policies setup completed successfully!"
    echo ""
    echo "Next Steps:"
    echo "1. Subscribe email addresses to the SNS topic for alerts"
    echo "2. Review and customize Config rules as needed"
    echo "3. Configure GuardDuty trusted IP lists and threat lists"
    echo "4. Set up CloudTrail for comprehensive audit logging"
    echo "5. Implement automated remediation actions"
}

# Main execution function
main() {
    log_info "Starting Security Policies Setup for $PROJECT_NAME"
    
    # Check prerequisites
    check_aws_cli
    
    # Create KMS key
    KMS_KEY_ID=$(create_kms_key)
    
    # Set up security policies
    setup_password_policy
    create_permissions_boundary
    create_security_audit_role
    
    # Enable security services
    enable_guardduty
    setup_config
    create_config_rules
    enable_security_hub
    
    # Create monitoring and alerting
    TOPIC_ARN=$(create_security_alerts_topic)
    create_eventbridge_rules "$TOPIC_ARN"
    create_security_dashboard
    
    # Display summary
    display_summary
}

# Script options
case "${1:-}" in
    --help|-h)
        echo "AWS Security Policies Setup Script"
        echo ""
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Environment Variables:"
        echo "  PROJECT_NAME    Project name (default: devops-security)"
        echo "  ENVIRONMENT     Environment (default: production)"
        echo "  AWS_REGION      AWS region (default: us-east-1)"
        echo ""
        echo "Options:"
        echo "  --help, -h      Show this help message"
        echo "  --dry-run       Show what would be done without executing"
        echo ""
        exit 0
        ;;
    --dry-run)
        log_info "DRY RUN MODE - No changes will be made"
        log_info "This script would set up the following security policies:"
        log_info "1. Account password policy with strong requirements"
        log_info "2. Permissions boundary policy for privilege limitation"
        log_info "3. Security audit role with MFA requirement"
        log_info "4. AWS Config with security compliance rules"
        log_info "5. GuardDuty for threat detection"
        log_info "6. Security Hub for centralized security management"
        log_info "7. CloudWatch dashboard for security metrics"
        log_info "8. SNS topic and EventBridge rules for security alerts"
        exit 0
        ;;
    *)
        main
        ;;
esac