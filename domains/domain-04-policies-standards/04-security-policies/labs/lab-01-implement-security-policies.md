# Lab 1: Implementing Comprehensive Security Policies

## Overview

This hands-on lab will guide you through implementing comprehensive security policies in AWS. You'll configure security controls, monitoring, and compliance validation using Infrastructure as Code and AWS native services.

## Learning Objectives

By the end of this lab, you will be able to:
- Implement IAM security policies with permissions boundaries
- Configure AWS security services (Config, GuardDuty, Security Hub)
- Create secure S3 bucket policies with encryption
- Set up automated security monitoring and alerting
- Validate security compliance using AWS CLI tools

## Prerequisites

- AWS account with administrative access
- AWS CLI installed and configured
- Basic understanding of IAM, S3, and AWS security services
- Familiarity with CloudFormation or Terraform (optional)

## Lab Duration

Estimated time: 2-3 hours

## Architecture Overview

In this lab, you will create:
- IAM roles and policies with security constraints
- Secure S3 buckets with comprehensive policies
- AWS Config rules for compliance monitoring
- GuardDuty for threat detection
- Security Hub for centralized security findings
- CloudWatch dashboard for security metrics
- Automated alerting for security events

## Part 1: Environment Setup (20 minutes)

### Step 1.1: Verify Prerequisites

1. **Check AWS CLI Configuration**
   ```bash
   aws sts get-caller-identity
   aws configure list
   ```

2. **Set Environment Variables**
   ```bash
   export PROJECT_NAME="security-lab"
   export ENVIRONMENT="lab"
   export AWS_REGION="us-east-1"
   export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
   ```

3. **Create Working Directory**
   ```bash
   mkdir -p ~/security-policies-lab
   cd ~/security-policies-lab
   ```

### Step 1.2: Enable Required AWS Services

1. **Enable AWS Config**
   ```bash
   # Create S3 bucket for Config
   aws s3 mb s3://$PROJECT_NAME-config-$ACCOUNT_ID-$AWS_REGION
   
   # Create Config service role (simplified for lab)
   aws iam create-role \
     --role-name ConfigRole \
     --assume-role-policy-document '{
       "Version": "2012-10-17",
       "Statement": [{
         "Effect": "Allow",
         "Principal": {"Service": "config.amazonaws.com"},
         "Action": "sts:AssumeRole"
       }]
     }'
   
   aws iam attach-role-policy \
     --role-name ConfigRole \
     --policy-arn arn:aws:iam::aws:policy/service-role/ConfigRole
   ```

## Part 2: IAM Security Policies Implementation (30 minutes)

### Step 2.1: Create Permissions Boundary Policy

1. **Create Permissions Boundary**
   ```bash
   cat > permissions-boundary-policy.json << 'EOF'
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Sid": "AllowBasicServices",
         "Effect": "Allow",
         "Action": [
           "logs:*",
           "cloudwatch:*",
           "s3:GetObject",
           "s3:PutObject",
           "s3:ListBucket"
         ],
         "Resource": "*"
       },
       {
         "Sid": "DenyDangerousActions",
         "Effect": "Deny",
         "Action": [
           "iam:CreatePolicy",
           "iam:DeletePolicy",
           "iam:CreateUser",
           "iam:DeleteUser",
           "organizations:*",
           "account:*"
         ],
         "Resource": "*"
       }
     ]
   }
   EOF
   
   aws iam create-policy \
     --policy-name "$PROJECT_NAME-permissions-boundary" \
     --policy-document file://permissions-boundary-policy.json
   ```

### Step 2.2: Create Secure IAM Role

1. **Create Developer Role with Permissions Boundary**
   ```bash
   cat > developer-trust-policy.json << 'EOF'
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Principal": {
           "AWS": "arn:aws:iam::ACCOUNT_ID:root"
         },
         "Action": "sts:AssumeRole",
         "Condition": {
           "StringEquals": {
             "aws:RequestedRegion": ["us-east-1", "us-west-2"]
           }
         }
       }
     ]
   }
   EOF
   
   sed -i "s/ACCOUNT_ID/$ACCOUNT_ID/g" developer-trust-policy.json
   
   aws iam create-role \
     --role-name "$PROJECT_NAME-developer-role" \
     --assume-role-policy-document file://developer-trust-policy.json \
     --permissions-boundary "arn:aws:iam::$ACCOUNT_ID:policy/$PROJECT_NAME-permissions-boundary"
   ```

### Step 2.3: Test Role Assumptions

1. **Assume the Role and Test Permissions**
   ```bash
   # Get role ARN
   ROLE_ARN=$(aws iam get-role --role-name "$PROJECT_NAME-developer-role" --query 'Role.Arn' --output text)
   
   # Assume role (this will fail without proper permissions - expected for demonstration)
   aws sts assume-role \
     --role-arn "$ROLE_ARN" \
     --role-session-name "TestSession" \
     --duration-seconds 3600
   ```

## Part 3: Secure S3 Bucket Implementation (30 minutes)

### Step 3.1: Create KMS Key for S3 Encryption

1. **Create KMS Key**
   ```bash
   cat > kms-key-policy.json << 'EOF'
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Sid": "Enable IAM User Permissions",
         "Effect": "Allow",
         "Principal": {
           "AWS": "arn:aws:iam::ACCOUNT_ID:root"
         },
         "Action": "kms:*",
         "Resource": "*"
       },
       {
         "Sid": "Allow S3 Service",
         "Effect": "Allow",
         "Principal": {
           "Service": "s3.amazonaws.com"
         },
         "Action": [
           "kms:Decrypt",
           "kms:GenerateDataKey"
         ],
         "Resource": "*"
       }
     ]
   }
   EOF
   
   sed -i "s/ACCOUNT_ID/$ACCOUNT_ID/g" kms-key-policy.json
   
   KMS_KEY_ID=$(aws kms create-key \
     --description "S3 encryption key for $PROJECT_NAME" \
     --policy file://kms-key-policy.json \
     --query 'KeyMetadata.KeyId' \
     --output text)
   
   aws kms create-alias \
     --alias-name "alias/$PROJECT_NAME-s3-key" \
     --target-key-id "$KMS_KEY_ID"
   
   echo "KMS Key ID: $KMS_KEY_ID"
   ```

### Step 3.2: Create Secure S3 Bucket

1. **Create Bucket with Security Configuration**
   ```bash
   BUCKET_NAME="$PROJECT_NAME-secure-bucket-$ACCOUNT_ID"
   
   # Create bucket
   aws s3 mb "s3://$BUCKET_NAME"
   
   # Enable versioning
   aws s3api put-bucket-versioning \
     --bucket "$BUCKET_NAME" \
     --versioning-configuration Status=Enabled
   
   # Configure encryption
   aws s3api put-bucket-encryption \
     --bucket "$BUCKET_NAME" \
     --server-side-encryption-configuration '{
       "Rules": [{
         "ApplyServerSideEncryptionByDefault": {
           "SSEAlgorithm": "aws:kms",
           "KMSMasterKeyID": "'$KMS_KEY_ID'"
         },
         "BucketKeyEnabled": true
       }]
     }'
   
   # Block public access
   aws s3api put-public-access-block \
     --bucket "$BUCKET_NAME" \
     --public-access-block-configuration \
       BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
   ```

### Step 3.3: Apply Comprehensive Bucket Policy

1. **Create and Apply Bucket Policy**
   ```bash
   cat > bucket-policy.json << 'EOF'
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Sid": "DenyInsecureConnections",
         "Effect": "Deny",
         "Principal": "*",
         "Action": "s3:*",
         "Resource": [
           "arn:aws:s3:::BUCKET_NAME",
           "arn:aws:s3:::BUCKET_NAME/*"
         ],
         "Condition": {
           "Bool": {
             "aws:SecureTransport": "false"
           }
         }
       },
       {
         "Sid": "RequireKMSEncryption",
         "Effect": "Deny",
         "Principal": "*",
         "Action": "s3:PutObject",
         "Resource": "arn:aws:s3:::BUCKET_NAME/*",
         "Condition": {
           "StringNotEquals": {
             "s3:x-amz-server-side-encryption": "aws:kms",
             "s3:x-amz-server-side-encryption-aws-kms-key-id": "KMS_KEY_ID"
           }
         }
       }
     ]
   }
   EOF
   
   sed -i "s/BUCKET_NAME/$BUCKET_NAME/g" bucket-policy.json
   sed -i "s/KMS_KEY_ID/$KMS_KEY_ID/g" bucket-policy.json
   
   aws s3api put-bucket-policy \
     --bucket "$BUCKET_NAME" \
     --policy file://bucket-policy.json
   ```

## Part 4: Security Monitoring Setup (40 minutes)

### Step 4.1: Enable GuardDuty

1. **Enable GuardDuty**
   ```bash
   DETECTOR_ID=$(aws guardduty create-detector \
     --enable \
     --finding-publishing-frequency FIFTEEN_MINUTES \
     --query 'DetectorId' \
     --output text)
   
   echo "GuardDuty Detector ID: $DETECTOR_ID"
   ```

### Step 4.2: Configure AWS Config Rules

1. **Create Config Rules for Security Compliance**
   ```bash
   # Start configuration recorder first
   aws configservice put-configuration-recorder \
     --configuration-recorder name="SecurityRecorder",roleARN="arn:aws:iam::$ACCOUNT_ID:role/ConfigRole",recordingGroup='{allSupported=true,includeGlobalResourceTypes=true}'
   
   aws configservice put-delivery-channel \
     --delivery-channel name="SecurityChannel",s3BucketName="$PROJECT_NAME-config-$ACCOUNT_ID-$AWS_REGION"
   
   aws configservice start-configuration-recorder \
     --configuration-recorder-name "SecurityRecorder"
   
   # Wait a moment for Config to initialize
   sleep 30
   
   # Create Config rules
   aws configservice put-config-rule \
     --config-rule '{
       "ConfigRuleName": "encrypted-volumes",
       "Description": "Checks whether EBS volumes are encrypted",
       "Source": {
         "Owner": "AWS",
         "SourceIdentifier": "ENCRYPTED_VOLUMES"
       }
     }'
   
   aws configservice put-config-rule \
     --config-rule '{
       "ConfigRuleName": "s3-bucket-public-read-prohibited",
       "Description": "Checks if S3 buckets allow public read access",
       "Source": {
         "Owner": "AWS",
         "SourceIdentifier": "S3_BUCKET_PUBLIC_READ_PROHIBITED"
       }
     }'
   
   aws configservice put-config-rule \
     --config-rule '{
       "ConfigRuleName": "root-access-key-check",
       "Description": "Checks whether root access keys exist",
       "Source": {
         "Owner": "AWS",
         "SourceIdentifier": "ROOT_ACCESS_KEY_CHECK"
       }
     }'
   ```

### Step 4.3: Enable Security Hub

1. **Enable Security Hub and Standards**
   ```bash
   aws securityhub enable-security-hub
   
   # Enable AWS Foundational Security Standard
   aws securityhub batch-enable-standards \
     --standards-subscription-requests StandardsArn="arn:aws:securityhub:::ruleset/finding-format/aws-foundational-security-standard/v/1.0.0"
   ```

### Step 4.4: Create Security Alerting

1. **Create SNS Topic for Alerts**
   ```bash
   TOPIC_ARN=$(aws sns create-topic \
     --name "$PROJECT_NAME-security-alerts" \
     --query 'TopicArn' \
     --output text)
   
   echo "SNS Topic ARN: $TOPIC_ARN"
   
   # Subscribe your email (replace with your email)
   read -p "Enter your email for security alerts: " EMAIL_ADDRESS
   aws sns subscribe \
     --topic-arn "$TOPIC_ARN" \
     --protocol email \
     --notification-endpoint "$EMAIL_ADDRESS"
   ```

2. **Create EventBridge Rules**
   ```bash
   # GuardDuty findings rule
   aws events put-rule \
     --name "$PROJECT_NAME-guardduty-findings" \
     --description "Capture high severity GuardDuty findings" \
     --event-pattern '{
       "source": ["aws.guardduty"],
       "detail-type": ["GuardDuty Finding"],
       "detail": {
         "severity": [7.0, 7.1, 7.2, 7.3, 8.0, 8.1, 8.2, 8.3]
       }
     }'
   
   aws events put-targets \
     --rule "$PROJECT_NAME-guardduty-findings" \
     --targets "Id"="1","Arn"="$TOPIC_ARN"
   
   # Config compliance rule
   aws events put-rule \
     --name "$PROJECT_NAME-config-compliance" \
     --description "Capture Config non-compliance" \
     --event-pattern '{
       "source": ["aws.config"],
       "detail-type": ["Config Rules Compliance Change"],
       "detail": {
         "newEvaluationResult": {
           "complianceType": ["NON_COMPLIANT"]
         }
       }
     }'
   
   aws events put-targets \
     --rule "$PROJECT_NAME-config-compliance" \
     --targets "Id"="1","Arn"="$TOPIC_ARN"
   ```

## Part 5: Testing and Validation (30 minutes)

### Step 5.1: Test S3 Security Policies

1. **Test Encrypted Upload**
   ```bash
   # Create test file
   echo "This is a test file" > test-file.txt
   
   # Upload with KMS encryption (should succeed)
   aws s3 cp test-file.txt "s3://$BUCKET_NAME/encrypted-test.txt" \
     --sse aws:kms \
     --sse-kms-key-id "$KMS_KEY_ID"
   
   # Try upload without encryption (should fail due to bucket policy)
   aws s3 cp test-file.txt "s3://$BUCKET_NAME/unencrypted-test.txt" || \
     echo "✅ Unencrypted upload blocked as expected"
   ```

2. **Test Insecure Transport Denial**
   ```bash
   # This would require curl/wget to test HTTP vs HTTPS
   # For demonstration, we can verify the policy is in place
   aws s3api get-bucket-policy --bucket "$BUCKET_NAME" | \
     jq -r '.Policy | fromjson | .Statement[] | select(.Sid=="DenyInsecureConnections")'
   ```

### Step 5.2: Validate Security Configuration

1. **Use the Validation Script**
   ```bash
   # Download the validation script from the examples
   curl -O https://raw.githubusercontent.com/your-repo/validate-security-policies.sh
   chmod +x validate-security-policies.sh
   
   # Run validation
   ./validate-security-policies.sh
   ```

### Step 5.3: Check Config Rules Compliance

1. **Monitor Config Rules**
   ```bash
   # Wait for Config to evaluate rules (this may take several minutes)
   sleep 120
   
   # Check compliance status
   aws configservice get-compliance-details-by-config-rule \
     --config-rule-name encrypted-volumes \
     --query 'EvaluationResults[*].[EvaluationResultIdentifier.EvaluationResultQualifier.ResourceId,ComplianceType]' \
     --output table
   
   aws configservice get-compliance-details-by-config-rule \
     --config-rule-name s3-bucket-public-read-prohibited \
     --query 'EvaluationResults[*].[EvaluationResultIdentifier.EvaluationResultQualifier.ResourceId,ComplianceType]' \
     --output table
   ```

## Part 6: Create Security Dashboard (20 minutes)

### Step 6.1: Create CloudWatch Dashboard

1. **Create Security Metrics Dashboard**
   ```bash
   cat > dashboard-body.json << 'EOF'
   {
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
             [ ".", ".", ".", "root-access-key-check", ".", "." ]
           ],
           "period": 300,
           "stat": "Maximum",
           "region": "AWS_REGION",
           "title": "Config Rules Compliance"
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
           "region": "AWS_REGION",
           "title": "GuardDuty Findings"
         }
       }
     ]
   }
   EOF
   
   sed -i "s/AWS_REGION/$AWS_REGION/g" dashboard-body.json
   
   aws cloudwatch put-dashboard \
     --dashboard-name "$PROJECT_NAME-security-dashboard" \
     --dashboard-body file://dashboard-body.json
   
   echo "Dashboard created: https://console.aws.amazon.com/cloudwatch/home?region=$AWS_REGION#dashboards:name=$PROJECT_NAME-security-dashboard"
   ```

## Part 7: Simulate Security Events (15 minutes)

### Step 7.1: Trigger Config Rule Violations

1. **Create Non-Compliant S3 Bucket**
   ```bash
   # Create a bucket without encryption to trigger Config rule
   TEST_BUCKET="$PROJECT_NAME-test-violation-$ACCOUNT_ID"
   aws s3 mb "s3://$TEST_BUCKET"
   
   # Wait for Config to detect and evaluate
   echo "Waiting for Config to detect non-compliant resource..."
   sleep 60
   
   # Check for violations
   aws configservice get-compliance-details-by-config-rule \
     --config-rule-name s3-bucket-public-read-prohibited \
     --compliance-types NON_COMPLIANT \
     --query 'EvaluationResults[0].ComplianceType' \
     --output text
   ```

### Step 7.2: Generate Test GuardDuty Finding

1. **Generate Sample Finding** (This is simulated - GuardDuty findings are typically based on real threats)
   ```bash
   # Create a test EC2 instance with security groups that might trigger GuardDuty
   # Note: This is for educational purposes only
   echo "GuardDuty findings are generated based on real threat detection."
   echo "In a real scenario, you would see findings for suspicious activities."
   echo "Check the GuardDuty console for any actual findings."
   ```

## Part 8: Cleanup (10 minutes)

### Step 8.1: Clean Up Resources

1. **Remove Created Resources**
   ```bash
   # Delete test files and buckets
   aws s3 rm "s3://$BUCKET_NAME/encrypted-test.txt"
   aws s3 rb "s3://$BUCKET_NAME"
   aws s3 rb "s3://$TEST_BUCKET"
   aws s3 rb "s3://$PROJECT_NAME-config-$ACCOUNT_ID-$AWS_REGION"
   
   # Delete IAM resources
   aws iam delete-role --role-name "$PROJECT_NAME-developer-role"
   aws iam delete-policy --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/$PROJECT_NAME-permissions-boundary"
   aws iam detach-role-policy --role-name ConfigRole --policy-arn arn:aws:iam::aws:policy/service-role/ConfigRole
   aws iam delete-role --role-name ConfigRole
   
   # Disable Config
   aws configservice stop-configuration-recorder --configuration-recorder-name SecurityRecorder
   aws configservice delete-configuration-recorder --configuration-recorder-name SecurityRecorder
   aws configservice delete-delivery-channel --delivery-channel-name SecurityChannel
   
   # Delete Config rules
   aws configservice delete-config-rule --config-rule-name encrypted-volumes
   aws configservice delete-config-rule --config-rule-name s3-bucket-public-read-prohibited
   aws configservice delete-config-rule --config-rule-name root-access-key-check
   
   # Disable GuardDuty
   aws guardduty delete-detector --detector-id "$DETECTOR_ID"
   
   # Disable Security Hub
   aws securityhub disable-security-hub
   
   # Delete EventBridge rules
   aws events remove-targets --rule "$PROJECT_NAME-guardduty-findings" --ids "1"
   aws events remove-targets --rule "$PROJECT_NAME-config-compliance" --ids "1"
   aws events delete-rule --name "$PROJECT_NAME-guardduty-findings"
   aws events delete-rule --name "$PROJECT_NAME-config-compliance"
   
   # Delete SNS topic
   aws sns delete-topic --topic-arn "$TOPIC_ARN"
   
   # Delete CloudWatch dashboard
   aws cloudwatch delete-dashboards --dashboard-names "$PROJECT_NAME-security-dashboard"
   
   # Schedule KMS key deletion (cannot be deleted immediately)
   aws kms schedule-key-deletion --key-id "$KMS_KEY_ID" --pending-window-in-days 7
   
   echo "✅ Cleanup completed!"
   ```

## Lab Validation

### Validation Checklist

Mark each item as completed:

- [ ] Created permissions boundary policy limiting privileges
- [ ] Implemented secure IAM role with conditions
- [ ] Created KMS key for S3 encryption
- [ ] Configured secure S3 bucket with comprehensive policies
- [ ] Enabled GuardDuty for threat detection
- [ ] Set up AWS Config with security rules
- [ ] Enabled Security Hub for centralized findings
- [ ] Created SNS topic for security alerts
- [ ] Configured EventBridge rules for automated notifications
- [ ] Built CloudWatch dashboard for security monitoring
- [ ] Tested security policies with compliant and non-compliant actions
- [ ] Validated configuration using security validation script

### Expected Outcomes

After completing this lab, you should have:
1. A comprehensive understanding of AWS security policy implementation
2. Experience with Infrastructure as Code security patterns
3. Knowledge of security monitoring and alerting setup
4. Skills in security compliance validation and testing

## Troubleshooting

### Common Issues

1. **Config Rules Not Evaluating**
   - Ensure Config service role has proper permissions
   - Verify configuration recorder is active
   - Wait sufficient time for evaluation (can take 10-15 minutes)

2. **S3 Bucket Policy Errors**
   - Check JSON syntax in policy documents
   - Verify KMS key permissions include S3 service
   - Ensure bucket names are globally unique

3. **GuardDuty Not Enabling**
   - Check if GuardDuty is already enabled in the region
   - Verify account has necessary permissions
   - Ensure region supports all GuardDuty features

4. **EventBridge Rules Not Triggering**
   - Verify event pattern syntax
   - Check SNS topic permissions for EventBridge
   - Confirm services are generating events to match patterns

### Support Resources

- AWS Documentation: Security Best Practices
- AWS Config Rules Reference
- GuardDuty User Guide
- Security Hub Findings Format Reference

## Next Steps

After completing this lab:
1. Explore advanced security policies and conditions
2. Implement automated remediation using Lambda functions
3. Set up cross-account security monitoring
4. Practice with different compliance frameworks (PCI DSS, SOC 2)
5. Implement security scanning in CI/CD pipelines