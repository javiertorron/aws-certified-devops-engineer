# Lab 1: Advanced CodeCommit Repository Setup with Enterprise Features

## Objectives
By the end of this lab, you will be able to:
- Create CodeCommit repositories with enterprise-grade configurations
- Implement KMS encryption for repositories
- Configure repository triggers and SNS notifications
- Set up approval rules for pull request workflows
- Implement basic cross-account access patterns
- Monitor repository activity with CloudWatch

## Prerequisites
- AWS account with administrative access
- AWS CLI configured with appropriate credentials
- Git client installed and configured
- Basic understanding of IAM policies and roles
- Completion of Topic 1: Source Code Management

## Estimated Time
**90 minutes**

## Resources Created
This lab will create the following AWS resources:
- 2 CodeCommit repositories
- 1 KMS key with alias
- 2 SNS topics with email subscriptions
- 3 IAM policies and roles
- 1 Lambda function for automation
- 2 approval rule templates
- CloudWatch alarms and EventBridge rules

## Part 1: Environment Setup and Planning (15 minutes)

### Step 1: Define Variables
Create environment variables to maintain consistency throughout the lab:

```bash
# Set your lab configuration
export LAB_ORGANIZATION="DevOpsAcademy"
export LAB_PROJECT="WebApplication"
export LAB_ENVIRONMENT="Production"
export LAB_TEAM_EMAIL="your-email@example.com"  # Replace with your email
export AWS_REGION="us-west-2"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Lab Configuration:"
echo "Organization: $LAB_ORGANIZATION"
echo "Project: $LAB_PROJECT"
echo "Environment: $LAB_ENVIRONMENT"
echo "Email: $LAB_TEAM_EMAIL"
echo "Region: $AWS_REGION"
echo "Account ID: $AWS_ACCOUNT_ID"
```

### Step 2: Verify Prerequisites
```bash
# Check AWS CLI configuration
aws sts get-caller-identity

# Check Git configuration
git --version
git config --global --list | grep credential

# Check required tools
jq --version
```

## Part 2: KMS Key Creation for Encryption (15 minutes)

### Step 3: Create KMS Key
```bash
# Create KMS key policy
cat > /tmp/kms-key-policy.json << EOF
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

# Create KMS key
KMS_KEY_RESPONSE=$(aws kms create-key \
    --description "KMS key for ${LAB_ORGANIZATION} CodeCommit repositories" \
    --policy file:///tmp/kms-key-policy.json \
    --tags TagKey=Organization,TagValue="$LAB_ORGANIZATION" \
           TagKey=Project,TagValue="$LAB_PROJECT" \
           TagKey=ManagedBy,TagValue="Lab" \
    --output json)

export KMS_KEY_ID=$(echo "$KMS_KEY_RESPONSE" | jq -r '.KeyMetadata.KeyId')
export KMS_KEY_ARN=$(echo "$KMS_KEY_RESPONSE" | jq -r '.KeyMetadata.Arn')

# Create alias
aws kms create-alias \
    --alias-name "alias/${LAB_ORGANIZATION}-codecommit" \
    --target-key-id "$KMS_KEY_ID"

echo "KMS Key created: $KMS_KEY_ARN"
```

## Part 3: CodeCommit Repository Creation (20 minutes)

### Step 4: Create Primary Repository
```bash
# Create primary repository
PRIMARY_REPO_NAME="${LAB_ORGANIZATION}-${LAB_PROJECT}-${LAB_ENVIRONMENT}"

PRIMARY_REPO_RESPONSE=$(aws codecommit create-repository \
    --repository-name "$PRIMARY_REPO_NAME" \
    --repository-description "Primary repository for $LAB_PROJECT in $LAB_ENVIRONMENT environment" \
    --kms-key-id "$KMS_KEY_ID" \
    --tags Organization="$LAB_ORGANIZATION",Project="$LAB_PROJECT",Environment="$LAB_ENVIRONMENT",ManagedBy="Lab" \
    --output json)

export PRIMARY_REPO_ARN=$(echo "$PRIMARY_REPO_RESPONSE" | jq -r '.repositoryMetadata.Arn')
export PRIMARY_REPO_CLONE_URL=$(echo "$PRIMARY_REPO_RESPONSE" | jq -r '.repositoryMetadata.cloneUrlHttp')

echo "Primary repository created: $PRIMARY_REPO_NAME"
echo "Clone URL: $PRIMARY_REPO_CLONE_URL"
```

### Step 5: Create Infrastructure Repository
```bash
# Create infrastructure repository
INFRA_REPO_NAME="${LAB_ORGANIZATION}-${LAB_PROJECT}-infrastructure"

INFRA_REPO_RESPONSE=$(aws codecommit create-repository \
    --repository-name "$INFRA_REPO_NAME" \
    --repository-description "Infrastructure as Code repository for $LAB_PROJECT" \
    --kms-key-id "$KMS_KEY_ID" \
    --tags Organization="$LAB_ORGANIZATION",Project="$LAB_PROJECT",Type="Infrastructure",ManagedBy="Lab" \
    --output json)

export INFRA_REPO_ARN=$(echo "$INFRA_REPO_RESPONSE" | jq -r '.repositoryMetadata.Arn')
export INFRA_REPO_CLONE_URL=$(echo "$INFRA_REPO_RESPONSE" | jq -r '.repositoryMetadata.cloneUrlHttp')

echo "Infrastructure repository created: $INFRA_REPO_NAME"
echo "Clone URL: $INFRA_REPO_CLONE_URL"
```

### Step 6: Initialize Repositories with Content
```bash
# Create temporary directory for repository initialization
mkdir -p /tmp/codecommit-lab
cd /tmp/codecommit-lab

# Clone and initialize primary repository
git clone "$PRIMARY_REPO_CLONE_URL" primary-repo
cd primary-repo

# Create initial structure
mkdir -p src tests docs
echo "# ${LAB_PROJECT}" > README.md
echo "print('Hello from ${LAB_PROJECT}!')" > src/main.py
echo "# Test placeholder" > tests/test_main.py
echo "# API Documentation" > docs/api.md

# Initial commit
git add .
git commit -m "Initial project structure

- Added README.md with project description
- Created src/ directory with main.py
- Added tests/ directory structure
- Added docs/ directory for documentation"

git push origin main

cd ..

# Clone and initialize infrastructure repository
git clone "$INFRA_REPO_CLONE_URL" infra-repo
cd infra-repo

# Create infrastructure structure
mkdir -p terraform cloudformation scripts
echo "# Infrastructure as Code for ${LAB_PROJECT}" > README.md
echo "# Terraform configuration files" > terraform/README.md
echo "# CloudFormation templates" > cloudformation/README.md
echo "# Deployment scripts" > scripts/README.md

git add .
git commit -m "Initial infrastructure repository structure

- Added README.md with infrastructure overview
- Created terraform/ directory for Terraform configs
- Created cloudformation/ directory for CF templates
- Added scripts/ directory for automation"

git push origin main

cd /tmp
rm -rf codecommit-lab

echo "Repositories initialized with content"
```

## Part 4: SNS Topics and Notifications (15 minutes)

### Step 7: Create SNS Topics
```bash
# Create primary repository notifications topic
PRIMARY_TOPIC_NAME="${LAB_ORGANIZATION}-${LAB_PROJECT}-codecommit-notifications"
export PRIMARY_TOPIC_ARN=$(aws sns create-topic \
    --name "$PRIMARY_TOPIC_NAME" \
    --tags Key=Organization,Value="$LAB_ORGANIZATION" \
           Key=Project,Value="$LAB_PROJECT" \
           Key=ManagedBy,Value="Lab" \
    --query 'TopicArn' --output text)

# Create infrastructure notifications topic
INFRA_TOPIC_NAME="${LAB_ORGANIZATION}-${LAB_PROJECT}-infrastructure-notifications"
export INFRA_TOPIC_ARN=$(aws sns create-topic \
    --name "$INFRA_TOPIC_NAME" \
    --tags Key=Organization,Value="$LAB_ORGANIZATION" \
           Key=Project,Value="$LAB_PROJECT" \
           Key=Type,Value="Infrastructure" \
           Key=ManagedBy,Value="Lab" \
    --query 'TopicArn' --output text)

# Subscribe email to topics
aws sns subscribe \
    --topic-arn "$PRIMARY_TOPIC_ARN" \
    --protocol email \
    --notification-endpoint "$LAB_TEAM_EMAIL"

aws sns subscribe \
    --topic-arn "$INFRA_TOPIC_ARN" \
    --protocol email \
    --notification-endpoint "$LAB_TEAM_EMAIL"

echo "SNS topics created:"
echo "Primary: $PRIMARY_TOPIC_ARN"
echo "Infrastructure: $INFRA_TOPIC_ARN"
echo "Check your email for subscription confirmations"
```

## Part 5: Repository Triggers Configuration (20 minutes)

### Step 8: Configure Repository Triggers
```bash
# Configure primary repository triggers
cat > /tmp/primary-triggers.json << EOF
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

aws codecommit put-repository-triggers \
    --repository-name "$PRIMARY_REPO_NAME" \
    --triggers file:///tmp/primary-triggers.json

# Configure infrastructure repository triggers
cat > /tmp/infra-triggers.json << EOF
[
    {
        "name": "InfrastructureChangeTrigger",
        "destinationArn": "$INFRA_TOPIC_ARN",
        "events": ["updateReference"],
        "branches": ["main", "production"]
    }
]
EOF

aws codecommit put-repository-triggers \
    --repository-name "$INFRA_REPO_NAME" \
    --triggers file:///tmp/infra-triggers.json

echo "Repository triggers configured"
```

### Step 9: Test Triggers
```bash
# Create a test commit to trigger notifications
cd /tmp
git clone "$PRIMARY_REPO_CLONE_URL" test-trigger
cd test-trigger

echo "# Test Change $(date)" >> README.md
git add README.md
git commit -m "Test trigger functionality

Added timestamp to README to test repository triggers"

git push origin main

cd /tmp
rm -rf test-trigger

echo "Test commit pushed. Check your email for trigger notification."
```

## Part 6: Approval Rules Configuration (20 minutes)

### Step 10: Create Approval Rule Templates
```bash
# Create production approval rule template
PRODUCTION_APPROVAL_RULE_NAME="${LAB_ORGANIZATION}-${LAB_PROJECT}-production-approval"

cat > /tmp/production-approval-content.json << EOF
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

# Create approval rule template
aws codecommit create-approval-rule-template \
    --approval-rule-template-name "$PRODUCTION_APPROVAL_RULE_NAME" \
    --approval-rule-template-description "Approval rule requiring senior developer approval for production" \
    --approval-rule-template-content file:///tmp/production-approval-content.json

# Associate with primary repository
aws codecommit associate-approval-rule-template-with-repository \
    --approval-rule-template-name "$PRODUCTION_APPROVAL_RULE_NAME" \
    --repository-name "$PRIMARY_REPO_NAME"

# Create infrastructure approval rule template
INFRASTRUCTURE_APPROVAL_RULE_NAME="${LAB_ORGANIZATION}-infrastructure-approval"

cat > /tmp/infrastructure-approval-content.json << EOF
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

aws codecommit create-approval-rule-template \
    --approval-rule-template-name "$INFRASTRUCTURE_APPROVAL_RULE_NAME" \
    --approval-rule-template-description "Approval rule for infrastructure changes" \
    --approval-rule-template-content file:///tmp/infrastructure-approval-content.json

aws codecommit associate-approval-rule-template-with-repository \
    --approval-rule-template-name "$INFRASTRUCTURE_APPROVAL_RULE_NAME" \
    --repository-name "$INFRA_REPO_NAME"

echo "Approval rule templates created and associated"
```

## Part 7: Basic IAM Policies (15 minutes)

### Step 11: Create Developer Access Policy
```bash
# Create developer policy
DEVELOPER_POLICY_NAME="${LAB_ORGANIZATION}-${LAB_PROJECT}-developer-policy"

cat > /tmp/developer-policy.json << EOF
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
                "$INFRA_REPO_ARN"
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
                "$INFRA_REPO_ARN"
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

aws iam create-policy \
    --policy-name "$DEVELOPER_POLICY_NAME" \
    --policy-document file:///tmp/developer-policy.json \
    --description "Policy for developers to access CodeCommit repositories"

echo "Developer policy created: $DEVELOPER_POLICY_NAME"
```

## Part 8: Validation and Testing (10 minutes)

### Step 12: Validate Repository Setup
```bash
echo "=== VALIDATION RESULTS ==="
echo

# Check repositories
echo "1. Repository Validation:"
aws codecommit get-repository --repository-name "$PRIMARY_REPO_NAME" --query 'repositoryMetadata.[repositoryName,repositoryDescription,kmsKeyId]' --output table
aws codecommit get-repository --repository-name "$INFRA_REPO_NAME" --query 'repositoryMetadata.[repositoryName,repositoryDescription,kmsKeyId]' --output table

# Check triggers
echo "2. Trigger Validation:"
aws codecommit get-repository-triggers --repository-name "$PRIMARY_REPO_NAME" --query 'triggers[*].[name,events,branches]' --output table

# Check approval rule templates
echo "3. Approval Rule Validation:"
aws codecommit list-approval-rule-templates --query 'approvalRuleTemplateNames' --output table

# Check SNS topics
echo "4. SNS Topic Validation:"
aws sns get-topic-attributes --topic-arn "$PRIMARY_TOPIC_ARN" --query 'Attributes.DisplayName' --output text
aws sns get-topic-attributes --topic-arn "$INFRA_TOPIC_ARN" --query 'Attributes.DisplayName' --output text

# Check KMS key
echo "5. KMS Key Validation:"
aws kms describe-key --key-id "$KMS_KEY_ID" --query 'KeyMetadata.[KeyId,Description,KeyUsage]' --output table

echo
echo "=== SETUP SUMMARY ==="
echo "Organization: $LAB_ORGANIZATION"
echo "Project: $LAB_PROJECT"
echo "Environment: $LAB_ENVIRONMENT"
echo
echo "Repositories:"
echo "  Primary: $PRIMARY_REPO_NAME"
echo "  Clone URL: $PRIMARY_REPO_CLONE_URL"
echo "  Infrastructure: $INFRA_REPO_NAME"
echo "  Clone URL: $INFRA_REPO_CLONE_URL"
echo
echo "Security:"
echo "  KMS Key: $KMS_KEY_ARN"
echo "  Encryption: Enabled"
echo "  Approval Rules: Configured"
echo
echo "Notifications:"
echo "  Primary Topic: $PRIMARY_TOPIC_ARN"
echo "  Infrastructure Topic: $INFRA_TOPIC_ARN"
echo "  Email: $LAB_TEAM_EMAIL"
echo
echo "✅ Lab 1 completed successfully!"
```

## Cleanup Instructions

**Important**: Run cleanup to avoid ongoing charges:

```bash
# Delete repositories
aws codecommit delete-repository --repository-name "$PRIMARY_REPO_NAME"
aws codecommit delete-repository --repository-name "$INFRA_REPO_NAME"

# Delete approval rule templates
aws codecommit delete-approval-rule-template --approval-rule-template-name "$PRODUCTION_APPROVAL_RULE_NAME"
aws codecommit delete-approval-rule-template --approval-rule-template-name "$INFRASTRUCTURE_APPROVAL_RULE_NAME"

# Delete SNS topics
aws sns delete-topic --topic-arn "$PRIMARY_TOPIC_ARN"
aws sns delete-topic --topic-arn "$INFRA_TOPIC_ARN"

# Delete IAM policy
aws iam delete-policy --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${DEVELOPER_POLICY_NAME}"

# Schedule KMS key deletion (7-day waiting period)
aws kms schedule-key-deletion --key-id "$KMS_KEY_ID" --pending-window-in-days 7

# Clean up temporary files
rm -f /tmp/kms-key-policy.json
rm -f /tmp/primary-triggers.json
rm -f /tmp/infra-triggers.json
rm -f /tmp/production-approval-content.json
rm -f /tmp/infrastructure-approval-content.json
rm -f /tmp/developer-policy.json

echo "Cleanup completed. KMS key will be deleted in 7 days."
```

## Key Learnings

After completing this lab, you should understand:

1. **Enterprise Repository Setup**: How to create CodeCommit repositories with enterprise-grade features
2. **Security Implementation**: KMS encryption, IAM policies, and access control
3. **Automation Configuration**: Repository triggers and SNS notifications
4. **Workflow Management**: Approval rules and pull request workflows
5. **Best Practices**: Tagging, naming conventions, and resource organization

## Next Steps

- Proceed to **Lab 2: Implementing Repository Triggers and Automation** for advanced automation
- Review CloudWatch metrics and set up custom alarms
- Experiment with cross-account access patterns
- Practice with approval rule modifications and testing

## Troubleshooting

**Common Issues**:
- **Email not received**: Check spam folder, confirm subscription
- **Git operations fail**: Verify credential helper configuration
- **Permission denied**: Check IAM permissions and policies
- **KMS errors**: Ensure KMS key policy allows CodeCommit service

**Additional Resources**:
- [CodeCommit Troubleshooting Guide](https://docs.aws.amazon.com/codecommit/latest/userguide/troubleshooting.html)
- [Git Credential Helper Configuration](https://docs.aws.amazon.com/codecommit/latest/userguide/setting-up-https-unixes.html)