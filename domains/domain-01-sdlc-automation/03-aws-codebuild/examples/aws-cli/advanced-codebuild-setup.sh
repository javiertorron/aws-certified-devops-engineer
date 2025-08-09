#!/bin/bash

# Advanced CodeBuild Setup Script
# This script creates a comprehensive CodeBuild environment with multiple projects,
# advanced monitoring, batch builds, and enterprise security features
# Usage: ./advanced-codebuild-setup.sh [organization] [project] [environment] [team-email]

set -e  # Exit on any error

# Configuration
ORGANIZATION_NAME=${1:-"MyCompany"}
PROJECT_PREFIX=${2:-"WebApp"}
ENVIRONMENT=${3:-"Production"}
TEAM_EMAIL=${4:-"team@example.com"}
AWS_REGION=${AWS_REGION:-"us-west-2"}
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

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
    log_step "Creating KMS key for CodeBuild encryption..."
    
    KMS_KEY_POLICY=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Enable IAM User Permissions",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${AWS_ACCOUNT_ID}:root"
            },
            "Action": "kms:*",
            "Resource": "*"
        },
        {
            "Sid": "Allow CodeBuild Service",
            "Effect": "Allow",
            "Principal": {
                "Service": "codebuild.amazonaws.com"
            },
            "Action": [
                "kms:Decrypt",
                "kms:DescribeKey",
                "kms:Encrypt",
                "kms:GenerateDataKey*",
                "kms:ReEncrypt*"
            ],
            "Resource": "*"
        },
        {
            "Sid": "Allow CloudWatch Logs",
            "Effect": "Allow",
            "Principal": {
                "Service": "logs.${AWS_REGION}.amazonaws.com"
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
}
EOF
)
    
    # Create KMS key
    KMS_KEY_RESPONSE=$(aws kms create-key \
        --description "KMS key for ${ORGANIZATION_NAME} CodeBuild encryption" \
        --policy "$KMS_KEY_POLICY" \
        --tags TagKey=Name,TagValue="${ORGANIZATION_NAME}-codebuild-key" \
               TagKey=Organization,TagValue="$ORGANIZATION_NAME" \
               TagKey=Environment,TagValue="$ENVIRONMENT" \
               TagKey=ManagedBy,TagValue="Script" \
        --output json)
    
    KMS_KEY_ID=$(echo "$KMS_KEY_RESPONSE" | jq -r '.KeyMetadata.KeyId')
    KMS_KEY_ARN=$(echo "$KMS_KEY_RESPONSE" | jq -r '.KeyMetadata.Arn')
    
    # Create alias
    aws kms create-alias \
        --alias-name "alias/${ORGANIZATION_NAME}-codebuild" \
        --target-key-id "$KMS_KEY_ID"
    
    log_success "KMS key created: $KMS_KEY_ARN"
}

# Create S3 buckets for artifacts and cache
create_s3_buckets() {
    log_step "Creating S3 buckets for artifacts and cache..."
    
    # Generate unique suffix
    RANDOM_SUFFIX=$(openssl rand -hex 4)
    
    # Artifacts bucket
    ARTIFACTS_BUCKET_NAME="codebuild-artifacts-${AWS_ACCOUNT_ID}-${AWS_REGION}-${ORGANIZATION_NAME}-${RANDOM_SUFFIX}"
    aws s3 mb s3://$ARTIFACTS_BUCKET_NAME --region $AWS_REGION
    
    # Configure artifacts bucket encryption
    aws s3api put-bucket-encryption \
        --bucket $ARTIFACTS_BUCKET_NAME \
        --server-side-encryption-configuration '{
            "Rules": [
                {
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "aws:kms",
                        "KMSMasterKeyID": "'$KMS_KEY_ARN'"
                    },
                    "BucketKeyEnabled": true
                }
            ]
        }'
    
    # Configure public access block
    aws s3api put-public-access-block \
        --bucket $ARTIFACTS_BUCKET_NAME \
        --public-access-block-configuration \
        'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true'
    
    # Configure lifecycle policy
    aws s3api put-bucket-lifecycle-configuration \
        --bucket $ARTIFACTS_BUCKET_NAME \
        --lifecycle-configuration '{
            "Rules": [
                {
                    "ID": "ArtifactsLifecycle",
                    "Status": "Enabled",
                    "Expiration": {
                        "Days": '$([[ "$ENVIRONMENT" == "Production" ]] && echo "90" || echo "30")'
                    },
                    "NoncurrentVersionExpiration": {
                        "NoncurrentDays": 7
                    },
                    "AbortIncompleteMultipartUpload": {
                        "DaysAfterInitiation": 1
                    }
                }
            ]
        }'
    
    # Cache bucket
    CACHE_BUCKET_NAME="codebuild-cache-${AWS_ACCOUNT_ID}-${AWS_REGION}-${ORGANIZATION_NAME}-${RANDOM_SUFFIX}"
    aws s3 mb s3://$CACHE_BUCKET_NAME --region $AWS_REGION
    
    # Configure cache bucket encryption
    aws s3api put-bucket-encryption \
        --bucket $CACHE_BUCKET_NAME \
        --server-side-encryption-configuration '{
            "Rules": [
                {
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "aws:kms",
                        "KMSMasterKeyID": "'$KMS_KEY_ARN'"
                    }
                }
            ]
        }'
    
    # Configure cache bucket lifecycle
    aws s3api put-bucket-lifecycle-configuration \
        --bucket $CACHE_BUCKET_NAME \
        --lifecycle-configuration '{
            "Rules": [
                {
                    "ID": "CacheLifecycle",
                    "Status": "Enabled",
                    "Expiration": {
                        "Days": 7
                    },
                    "Transitions": [
                        {
                            "Days": 1,
                            "StorageClass": "STANDARD_INFREQUENT_ACCESS"
                        }
                    ]
                }
            ]
        }'
    
    log_success "S3 buckets created:"
    log_success "  Artifacts: $ARTIFACTS_BUCKET_NAME"
    log_success "  Cache: $CACHE_BUCKET_NAME"
}

# Create CloudWatch Log Group
create_log_group() {
    log_step "Creating CloudWatch Log Group..."
    
    LOG_GROUP_NAME="/aws/codebuild/${ORGANIZATION_NAME}-projects"
    RETENTION_DAYS=$([[ "$ENVIRONMENT" == "Production" ]] && echo "90" || echo "30")
    
    aws logs create-log-group \
        --log-group-name "$LOG_GROUP_NAME" \
        --kms-key-id "$KMS_KEY_ARN" \
        --tags Organization="$ORGANIZATION_NAME",Environment="$ENVIRONMENT",ManagedBy="Script"
    
    aws logs put-retention-policy \
        --log-group-name "$LOG_GROUP_NAME" \
        --retention-in-days $RETENTION_DAYS
    
    log_success "CloudWatch Log Group created: $LOG_GROUP_NAME"
}

# Create SNS topic for notifications
create_sns_topic() {
    log_step "Creating SNS topic for build notifications..."
    
    SNS_TOPIC_NAME="${ORGANIZATION_NAME}-codebuild-notifications"
    SNS_TOPIC_ARN=$(aws sns create-topic \
        --name "$SNS_TOPIC_NAME" \
        --attributes '{
            "DisplayName": "'$ORGANIZATION_NAME' CodeBuild Notifications",
            "KmsMasterKeyId": "'$KMS_KEY_ARN'"
        }' \
        --tags Key=Name,Value="$SNS_TOPIC_NAME" \
               Key=Organization,Value="$ORGANIZATION_NAME" \
               Key=Environment,Value="$ENVIRONMENT" \
               Key=ManagedBy,Value="Script" \
        --query 'TopicArn' --output text)
    
    # Subscribe email to topic
    aws sns subscribe \
        --topic-arn "$SNS_TOPIC_ARN" \
        --protocol email \
        --notification-endpoint "$TEAM_EMAIL" > /dev/null
    
    log_success "SNS topic created: $SNS_TOPIC_ARN"
    log_success "Email subscription created for: $TEAM_EMAIL"
}

# Create IAM roles and policies
create_iam_resources() {
    log_step "Creating IAM roles and policies..."
    
    # CodeBuild Service Role
    CODEBUILD_ROLE_NAME="${ORGANIZATION_NAME}-CodeBuild-ServiceRole"
    
    # Trust policy
    TRUST_POLICY=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "codebuild.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
)
    
    # Create service role
    aws iam create-role \
        --role-name "$CODEBUILD_ROLE_NAME" \
        --assume-role-policy-document "$TRUST_POLICY" \
        --description "Service role for CodeBuild projects" \
        --tags Key=Name,Value="$CODEBUILD_ROLE_NAME" \
               Key=Organization,Value="$ORGANIZATION_NAME" \
               Key=Environment,Value="$ENVIRONMENT" \
               Key=ManagedBy,Value="Script" > /dev/null
    
    # Service role policy
    CODEBUILD_POLICY=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "LoggingPermissions",
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:${AWS_REGION}:${AWS_ACCOUNT_ID}:log-group:${LOG_GROUP_NAME}:*",
                "arn:aws:logs:${AWS_REGION}:${AWS_ACCOUNT_ID}:log-group:/aws/codebuild/${ORGANIZATION_NAME}-*"
            ]
        },
        {
            "Sid": "S3ArtifactsPermissions",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:GetObjectVersion",
                "s3:PutObject",
                "s3:GetBucketAcl",
                "s3:GetBucketLocation"
            ],
            "Resource": [
                "arn:aws:s3:::${ARTIFACTS_BUCKET_NAME}/*",
                "arn:aws:s3:::${ARTIFACTS_BUCKET_NAME}",
                "arn:aws:s3:::${CACHE_BUCKET_NAME}/*",
                "arn:aws:s3:::${CACHE_BUCKET_NAME}"
            ]
        },
        {
            "Sid": "CodeCommitPermissions",
            "Effect": "Allow",
            "Action": [
                "codecommit:GitPull",
                "codecommit:ListBranches",
                "codecommit:ListRepositories"
            ],
            "Resource": "arn:aws:codecommit:${AWS_REGION}:${AWS_ACCOUNT_ID}:*"
        },
        {
            "Sid": "ECRPermissions",
            "Effect": "Allow",
            "Action": [
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:GetAuthorizationToken",
                "ecr:BatchGetImage",
                "ecr:PutImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload"
            ],
            "Resource": "*"
        },
        {
            "Sid": "ParameterStorePermissions",
            "Effect": "Allow",
            "Action": [
                "ssm:GetParameter",
                "ssm:GetParameters",
                "ssm:GetParametersByPath"
            ],
            "Resource": "arn:aws:ssm:${AWS_REGION}:${AWS_ACCOUNT_ID}:parameter/${ORGANIZATION_NAME}/*"
        },
        {
            "Sid": "SecretsManagerPermissions",
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue"
            ],
            "Resource": "arn:aws:secretsmanager:${AWS_REGION}:${AWS_ACCOUNT_ID}:secret:${ORGANIZATION_NAME}/*"
        },
        {
            "Sid": "KMSPermissions",
            "Effect": "Allow",
            "Action": [
                "kms:Decrypt",
                "kms:DescribeKey",
                "kms:Encrypt",
                "kms:GenerateDataKey*",
                "kms:ReEncrypt*"
            ],
            "Resource": "$KMS_KEY_ARN"
        },
        {
            "Sid": "SNSPermissions",
            "Effect": "Allow",
            "Action": [
                "sns:Publish"
            ],
            "Resource": "$SNS_TOPIC_ARN"
        },
        {
            "Sid": "CloudWatchMetricsPermissions",
            "Effect": "Allow",
            "Action": [
                "cloudwatch:PutMetricData"
            ],
            "Resource": "*"
        }
    ]
}
EOF
)
    
    # Attach policy to role
    aws iam put-role-policy \
        --role-name "$CODEBUILD_ROLE_NAME" \
        --policy-name "${ORGANIZATION_NAME}-CodeBuild-ServicePolicy" \
        --policy-document "$CODEBUILD_POLICY"
    
    CODEBUILD_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${CODEBUILD_ROLE_NAME}"
    
    # Batch Build Service Role
    BATCH_ROLE_NAME="${ORGANIZATION_NAME}-CodeBuild-BatchServiceRole"
    
    aws iam create-role \
        --role-name "$BATCH_ROLE_NAME" \
        --assume-role-policy-document "$TRUST_POLICY" \
        --description "Batch service role for CodeBuild projects" \
        --tags Key=Name,Value="$BATCH_ROLE_NAME" \
               Key=Organization,Value="$ORGANIZATION_NAME" \
               Key=Environment,Value="$ENVIRONMENT" \
               Key=ManagedBy,Value="Script" > /dev/null
    
    # Batch role policy
    BATCH_POLICY=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "codebuild:StartBuild",
                "codebuild:StopBuild",
                "codebuild:RetryBuild"
            ],
            "Resource": "arn:aws:codebuild:${AWS_REGION}:${AWS_ACCOUNT_ID}:project/${ORGANIZATION_NAME}-*"
        }
    ]
}
EOF
)
    
    aws iam put-role-policy \
        --role-name "$BATCH_ROLE_NAME" \
        --policy-name "${ORGANIZATION_NAME}-CodeBuild-BatchPolicy" \
        --policy-document "$BATCH_POLICY"
    
    BATCH_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${BATCH_ROLE_NAME}"
    
    log_success "IAM roles created:"
    log_success "  Service Role: $CODEBUILD_ROLE_ARN"
    log_success "  Batch Role: $BATCH_ROLE_ARN"
}

# Create CodeBuild projects
create_codebuild_projects() {
    log_step "Creating CodeBuild projects..."
    
    declare -A projects
    projects[nodejs]="Node.js application build"
    projects[python]="Python application build"
    projects[docker]="Docker containerized build"
    projects[java]="Java application build with Maven"
    
    for project_type in "${!projects[@]}"; do
        PROJECT_NAME="${ORGANIZATION_NAME}-${PROJECT_PREFIX}-${project_type}"
        PROJECT_DESCRIPTION="${projects[$project_type]}"
        
        # Determine compute type and privileged mode
        if [ "$project_type" = "docker" ]; then
            COMPUTE_TYPE="BUILD_GENERAL1_LARGE"
            PRIVILEGED_MODE="true"
        elif [ "$project_type" = "java" ]; then
            COMPUTE_TYPE="BUILD_GENERAL1_LARGE"
            PRIVILEGED_MODE="false"
        else
            COMPUTE_TYPE="BUILD_GENERAL1_MEDIUM"
            PRIVILEGED_MODE="false"
        fi
        
        # Create buildspec based on project type
        create_buildspec "$project_type"
        
        # Project configuration
        PROJECT_CONFIG=$(cat <<EOF
{
    "name": "$PROJECT_NAME",
    "description": "$PROJECT_DESCRIPTION",
    "source": {
        "type": "CODECOMMIT",
        "buildspec": "$BUILDSPEC_CONTENT"
    },
    "artifacts": {
        "type": "S3",
        "location": "${ARTIFACTS_BUCKET_NAME}/${project_type}-builds",
        "name": "${PROJECT_PREFIX}-${project_type}-artifacts",
        "overrideArtifactName": true,
        "packaging": "ZIP"
    },
    "cache": {
        "type": "S3",
        "location": "${CACHE_BUCKET_NAME}/${project_type}-cache"
    },
    "environment": {
        "type": "LINUX_CONTAINER",
        "image": "aws/codebuild/amazonlinux2-x86_64-standard:4.0",
        "computeType": "$COMPUTE_TYPE",
        "privilegedMode": $PRIVILEGED_MODE,
        "environmentVariables": [
            {
                "name": "ORGANIZATION_NAME",
                "value": "$ORGANIZATION_NAME"
            },
            {
                "name": "PROJECT_PREFIX",
                "value": "$PROJECT_PREFIX"
            },
            {
                "name": "ENVIRONMENT",
                "value": "$ENVIRONMENT"
            },
            {
                "name": "APPLICATION_TYPE",
                "value": "$project_type"
            },
            {
                "name": "ARTIFACTS_BUCKET",
                "value": "$ARTIFACTS_BUCKET_NAME"
            },
            {
                "name": "CACHE_BUCKET",
                "value": "$CACHE_BUCKET_NAME"
            },
            {
                "name": "SNS_TOPIC_ARN",
                "value": "$SNS_TOPIC_ARN"
            },
            {
                "name": "AWS_DEFAULT_REGION",
                "value": "$AWS_REGION"
            },
            {
                "name": "AWS_ACCOUNT_ID",
                "value": "$AWS_ACCOUNT_ID"
            }
        ]
    },
    "serviceRole": "$CODEBUILD_ROLE_ARN",
    "timeoutInMinutes": $([[ "$project_type" == "java" ]] && echo "120" || echo "60"),
    "queuedTimeoutInMinutes": 480,
    "encryptionKey": "$KMS_KEY_ARN",
    "logsConfig": {
        "cloudWatchLogs": {
            "status": "ENABLED",
            "groupName": "$LOG_GROUP_NAME",
            "streamName": "${project_type}-builds"
        }
    },
    "buildBatchConfig": {
        "serviceRole": "$BATCH_ROLE_ARN",
        "restrictions": {
            "maximumBuildsAllowed": 10,
            "computeTypesAllowed": [
                "BUILD_GENERAL1_SMALL",
                "BUILD_GENERAL1_MEDIUM",
                "BUILD_GENERAL1_LARGE"
            ]
        },
        "timeoutInMinutes": $([[ "$project_type" == "java" ]] && echo "150" || echo "90"),
        "batchReportMode": "REPORT_INDIVIDUAL_BUILDS"
    },
    "tags": [
        {
            "key": "Name",
            "value": "$PROJECT_NAME"
        },
        {
            "key": "Organization",
            "value": "$ORGANIZATION_NAME"
        },
        {
            "key": "Environment",
            "value": "$ENVIRONMENT"
        },
        {
            "key": "ApplicationType",
            "value": "$project_type"
        },
        {
            "key": "ManagedBy",
            "value": "Script"
        }
    ]
}
EOF
)
        
        # Create the project
        echo "$PROJECT_CONFIG" > "/tmp/${project_type}_project.json"
        aws codebuild create-project --cli-input-json file:///tmp/${project_type}_project.json > /dev/null
        
        log_success "Created CodeBuild project: $PROJECT_NAME"
        
        # Clean up temp file
        rm "/tmp/${project_type}_project.json"
    done
}

# Create buildspec content for different project types
create_buildspec() {
    local project_type=$1
    
    case $project_type in
        nodejs)
            BUILDSPEC_CONTENT=$(cat <<'EOF'
version: 0.2

env:
  variables:
    NODE_ENV: production
  parameter-store:
    BUILD_CONFIG: /$ORGANIZATION_NAME/build/config

phases:
  install:
    runtime-versions:
      nodejs: 18
    commands:
      - echo "Installing Node.js dependencies"
      - npm ci --production=false
      
  pre_build:
    commands:
      - echo "Running pre-build checks"
      - npm run lint
      - npm run test:unit
      - npm audit --audit-level moderate
      
  build:
    commands:
      - echo "Building Node.js application"
      - npm run build
      - npm run test:integration
      
  post_build:
    commands:
      - echo "Post-build activities"
      - |
        if [ "$ENVIRONMENT" = "Production" ]; then
          npm run test:e2e
        fi
      - |
        aws sns publish \
          --topic-arn $SNS_TOPIC_ARN \
          --subject "Build Completed: $CODEBUILD_PROJECT_NAME" \
          --message "Build $CODEBUILD_BUILD_NUMBER completed successfully"

artifacts:
  files:
    - 'dist/**/*'
    - 'package.json'
    - 'package-lock.json'
  name: nodejs-build-$CODEBUILD_BUILD_NUMBER

cache:
  paths:
    - node_modules/**/*
    - ~/.npm/**/*

reports:
  unit-tests:
    files:
      - 'coverage/lcov.info'
    file-format: COBERTURAXML
EOF
)
            ;;
        python)
            BUILDSPEC_CONTENT=$(cat <<'EOF'
version: 0.2

phases:
  install:
    runtime-versions:
      python: 3.9
    commands:
      - echo "Installing Python dependencies"
      - pip install --upgrade pip setuptools wheel
      - pip install -r requirements.txt
      - pip install pytest pytest-cov bandit safety
      
  pre_build:
    commands:
      - echo "Running pre-build checks"
      - pylint src/ --exit-zero
      - bandit -r src/ -f json -o security-report.json
      - safety check --json --output safety-report.json
      - pytest tests/unit/ --cov=src --cov-report=xml
      
  build:
    commands:
      - echo "Building Python application"
      - python setup.py bdist_wheel
      - pip install dist/*.whl
      
  post_build:
    commands:
      - echo "Running integration tests"
      - pytest tests/integration/

artifacts:
  files:
    - 'dist/**/*'
    - 'requirements.txt'
    - 'setup.py'
  name: python-build-$CODEBUILD_BUILD_NUMBER

cache:
  paths:
    - ~/.cache/pip/**/*

reports:
  unit-tests:
    files:
      - 'coverage.xml'
    file-format: COBERTURAXML
EOF
)
            ;;
        docker)
            BUILDSPEC_CONTENT=$(cat <<'EOF'
version: 0.2

phases:
  pre_build:
    commands:
      - echo "Logging in to Amazon ECR"
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
      - REPOSITORY_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$ORGANIZATION_NAME-$PROJECT_PREFIX
      - IMAGE_TAG=$CODEBUILD_BUILD_NUMBER
      
  build:
    commands:
      - echo "Build started on $(date)"
      - echo "Building Docker image"
      - docker build -t $REPOSITORY_URI:latest .
      - docker tag $REPOSITORY_URI:latest $REPOSITORY_URI:$IMAGE_TAG
      
      # Security scanning
      - echo "Running security scan"
      - docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest image --exit-code 0 --no-progress --format table $REPOSITORY_URI:$IMAGE_TAG
      
  post_build:
    commands:
      - echo "Build completed on $(date)"
      - echo "Pushing Docker image"
      - docker push $REPOSITORY_URI:latest
      - docker push $REPOSITORY_URI:$IMAGE_TAG
      - echo "Writing image definitions file"
      - printf '[{"name":"%s","imageUri":"%s"}]' $ORGANIZATION_NAME-$PROJECT_PREFIX $REPOSITORY_URI:$IMAGE_TAG > imagedefinitions.json

artifacts:
  files:
    - imagedefinitions.json
EOF
)
            ;;
        java)
            BUILDSPEC_CONTENT=$(cat <<'EOF'
version: 0.2

phases:
  install:
    runtime-versions:
      java: corretto11
    commands:
      - echo "Installing Java dependencies"
      - mvn dependency:resolve
      
  pre_build:
    commands:
      - echo "Running pre-build checks"
      - mvn checkstyle:check
      - mvn spotbugs:check
      - mvn test
      
  build:
    commands:
      - echo "Building Java application"
      - mvn package -DskipTests
      - mvn integration-test
      
  post_build:
    commands:
      - echo "Post-build activities"
      - mvn verify

artifacts:
  files:
    - 'target/*.jar'
    - 'target/lib/**/*'
  name: java-build-$CODEBUILD_BUILD_NUMBER

cache:
  paths:
    - ~/.m2/repository/**/*

reports:
  unit-tests:
    files:
      - 'target/surefire-reports/*.xml'
    file-format: JUNITXML
  integration-tests:
    files:
      - 'target/failsafe-reports/*.xml'
    file-format: JUNITXML
EOF
)
            ;;
    esac
}

# Create CloudWatch alarms
create_cloudwatch_alarms() {
    log_step "Creating CloudWatch alarms..."
    
    # Get list of created projects
    PROJECT_NAMES=(
        "${ORGANIZATION_NAME}-${PROJECT_PREFIX}-nodejs"
        "${ORGANIZATION_NAME}-${PROJECT_PREFIX}-python"
        "${ORGANIZATION_NAME}-${PROJECT_PREFIX}-docker"
        "${ORGANIZATION_NAME}-${PROJECT_PREFIX}-java"
    )
    
    for PROJECT_NAME in "${PROJECT_NAMES[@]}"; do
        # Build failure alarm
        aws cloudwatch put-metric-alarm \
            --alarm-name "${PROJECT_NAME}-build-failures" \
            --alarm-description "Alert when build failures occur for ${PROJECT_NAME}" \
            --metric-name "FailedBuilds" \
            --namespace "AWS/CodeBuild" \
            --statistic "Sum" \
            --period 300 \
            --threshold 2 \
            --comparison-operator "GreaterThanThreshold" \
            --evaluation-periods 2 \
            --alarm-actions "$SNS_TOPIC_ARN" \
            --dimensions Name=ProjectName,Value="$PROJECT_NAME" \
            --tags Key=Name,Value="${PROJECT_NAME}-build-failures" \
                   Key=Organization,Value="$ORGANIZATION_NAME" \
                   Key=Environment,Value="$ENVIRONMENT" \
                   Key=ManagedBy,Value="Script"
        
        # Build duration alarm
        DURATION_THRESHOLD=$([[ "$PROJECT_NAME" == *"java"* ]] && echo "90" || echo "45")
        aws cloudwatch put-metric-alarm \
            --alarm-name "${PROJECT_NAME}-long-builds" \
            --alarm-description "Alert when build duration is too long for ${PROJECT_NAME}" \
            --metric-name "Duration" \
            --namespace "AWS/CodeBuild" \
            --statistic "Average" \
            --period 300 \
            --threshold $DURATION_THRESHOLD \
            --comparison-operator "GreaterThanThreshold" \
            --evaluation-periods 2 \
            --alarm-actions "$SNS_TOPIC_ARN" \
            --dimensions Name=ProjectName,Value="$PROJECT_NAME" \
            --tags Key=Name,Value="${PROJECT_NAME}-long-builds" \
                   Key=Organization,Value="$ORGANIZATION_NAME" \
                   Key=Environment,Value="$ENVIRONMENT" \
                   Key=ManagedBy,Value="Script"
    done
    
    log_success "CloudWatch alarms created for all projects"
}

# Create EventBridge rule and Lambda function for build state changes
create_monitoring_automation() {
    log_step "Creating monitoring automation..."
    
    # Create Lambda execution role
    LAMBDA_ROLE_NAME="${ORGANIZATION_NAME}-BuildStateHandler-Role"
    
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
    
    # Create Lambda role
    aws iam create-role \
        --role-name "$LAMBDA_ROLE_NAME" \
        --assume-role-policy-document "$LAMBDA_TRUST_POLICY" \
        --description "Role for CodeBuild state change handler" \
        --tags Key=Name,Value="$LAMBDA_ROLE_NAME" \
               Key=Organization,Value="$ORGANIZATION_NAME" \
               Key=Environment,Value="$ENVIRONMENT" \
               Key=ManagedBy,Value="Script" > /dev/null
    
    # Attach basic execution policy
    aws iam attach-role-policy \
        --role-name "$LAMBDA_ROLE_NAME" \
        --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
    
    # Lambda custom policy
    LAMBDA_POLICY=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "sns:Publish"
            ],
            "Resource": "$SNS_TOPIC_ARN"
        },
        {
            "Effect": "Allow",
            "Action": [
                "cloudwatch:PutMetricData"
            ],
            "Resource": "*"
        }
    ]
}
EOF
)
    
    aws iam put-role-policy \
        --role-name "$LAMBDA_ROLE_NAME" \
        --policy-name "${ORGANIZATION_NAME}-BuildStateHandler-Policy" \
        --policy-document "$LAMBDA_POLICY"
    
    LAMBDA_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${LAMBDA_ROLE_NAME}"
    
    # Create Lambda function code
    LAMBDA_CODE=$(cat <<'EOF'
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
)
    
    # Create Lambda function ZIP
    echo "$LAMBDA_CODE" > /tmp/lambda_function.py
    cd /tmp && zip build_state_handler.zip lambda_function.py
    
    # Create Lambda function
    LAMBDA_FUNCTION_NAME="${ORGANIZATION_NAME}-codebuild-state-handler"
    
    LAMBDA_RESPONSE=$(aws lambda create-function \
        --function-name "$LAMBDA_FUNCTION_NAME" \
        --runtime python3.9 \
        --role "$LAMBDA_ROLE_ARN" \
        --handler lambda_function.lambda_handler \
        --zip-file fileb:///tmp/build_state_handler.zip \
        --timeout 60 \
        --environment Variables="{SNS_TOPIC_ARN=$SNS_TOPIC_ARN,ORGANIZATION_NAME=$ORGANIZATION_NAME}" \
        --tags Organization="$ORGANIZATION_NAME",Environment="$ENVIRONMENT",ManagedBy="Script" \
        --output json)
    
    LAMBDA_FUNCTION_ARN=$(echo "$LAMBDA_RESPONSE" | jq -r '.FunctionArn')
    
    # Clean up
    rm -f /tmp/lambda_function.py /tmp/build_state_handler.zip
    
    # Create EventBridge rule
    RULE_NAME="${ORGANIZATION_NAME}-codebuild-state-changes"
    
    EVENT_PATTERN=$(cat <<EOF
{
    "source": ["aws.codebuild"],
    "detail-type": ["CodeBuild Build State Change"],
    "detail": {
        "project-name": [
            "${ORGANIZATION_NAME}-${PROJECT_PREFIX}-nodejs",
            "${ORGANIZATION_NAME}-${PROJECT_PREFIX}-python",
            "${ORGANIZATION_NAME}-${PROJECT_PREFIX}-docker",
            "${ORGANIZATION_NAME}-${PROJECT_PREFIX}-java"
        ],
        "build-status": ["FAILED", "SUCCEEDED", "STOPPED"]
    }
}
EOF
)
    
    # Create the rule
    aws events put-rule \
        --name "$RULE_NAME" \
        --description "Capture CodeBuild state changes" \
        --event-pattern "$EVENT_PATTERN" \
        --state ENABLED \
        --tags Key=Name,Value="$RULE_NAME" \
               Key=Organization,Value="$ORGANIZATION_NAME" \
               Key=Environment,Value="$ENVIRONMENT" \
               Key=ManagedBy,Value="Script"
    
    # Add Lambda target to rule
    aws events put-targets \
        --rule "$RULE_NAME" \
        --targets "Id"="1","Arn"="$LAMBDA_FUNCTION_ARN"
    
    # Grant EventBridge permission to invoke Lambda
    aws lambda add-permission \
        --function-name "$LAMBDA_FUNCTION_NAME" \
        --statement-id "AllowExecutionFromEventBridge" \
        --action lambda:InvokeFunction \
        --principal events.amazonaws.com \
        --source-arn "arn:aws:events:${AWS_REGION}:${AWS_ACCOUNT_ID}:rule/${RULE_NAME}" 2> /dev/null || true
    
    log_success "Monitoring automation created:"
    log_success "  Lambda Function: $LAMBDA_FUNCTION_NAME"
    log_success "  EventBridge Rule: $RULE_NAME"
}

# Generate summary report
generate_summary() {
    log_step "Generating setup summary..."
    
    echo
    echo "========================================="
    echo "         CODEBUILD SETUP COMPLETE       "
    echo "========================================="
    echo
    echo "Organization: $ORGANIZATION_NAME"
    echo "Project Prefix: $PROJECT_PREFIX"
    echo "Environment: $ENVIRONMENT"
    echo "Team Email: $TEAM_EMAIL"
    echo "AWS Region: $AWS_REGION"
    echo "AWS Account: $AWS_ACCOUNT_ID"
    echo
    echo "CODEBUILD PROJECTS CREATED:"
    echo "  • ${ORGANIZATION_NAME}-${PROJECT_PREFIX}-nodejs"
    echo "  • ${ORGANIZATION_NAME}-${PROJECT_PREFIX}-python"
    echo "  • ${ORGANIZATION_NAME}-${PROJECT_PREFIX}-docker"
    echo "  • ${ORGANIZATION_NAME}-${PROJECT_PREFIX}-java"
    echo
    echo "INFRASTRUCTURE:"
    echo "  • S3 Artifacts Bucket: $ARTIFACTS_BUCKET_NAME"
    echo "  • S3 Cache Bucket: $CACHE_BUCKET_NAME"
    echo "  • KMS Key: $KMS_KEY_ARN"
    echo "  • CloudWatch Log Group: $LOG_GROUP_NAME"
    echo "  • SNS Topic: $SNS_TOPIC_ARN"
    echo
    echo "SECURITY:"
    echo "  • Encryption: Enabled (KMS)"
    echo "  • IAM Service Role: $CODEBUILD_ROLE_ARN"
    echo "  • IAM Batch Role: $BATCH_ROLE_ARN"
    echo "  • S3 Public Access: Blocked"
    echo
    echo "MONITORING:"
    echo "  • CloudWatch Alarms: Configured"
    echo "  • Lambda Function: ${LAMBDA_FUNCTION_NAME}"
    echo "  • EventBridge Rule: ${RULE_NAME}"
    echo "  • Email Notifications: $TEAM_EMAIL"
    echo
    echo "NEXT STEPS:"
    echo "  1. Check your email and confirm SNS subscription"
    echo "  2. Connect your CodeCommit repositories to the build projects"
    echo "  3. Customize buildspec files as needed for your applications"
    echo "  4. Test builds by pushing code to your repositories"
    echo "  5. Monitor build performance in CloudWatch"
    echo
    echo "========================================="
    
    log_success "Advanced CodeBuild setup completed successfully!"
}

# Main execution
main() {
    echo "========================================="
    echo "    ADVANCED CODEBUILD SETUP SCRIPT     "
    echo "========================================="
    echo
    echo "Organization: $ORGANIZATION_NAME"
    echo "Project Prefix: $PROJECT_PREFIX"
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
    create_s3_buckets
    create_log_group
    create_sns_topic
    create_iam_resources
    create_codebuild_projects
    create_cloudwatch_alarms
    create_monitoring_automation
    generate_summary
}

# Execute main function
main "$@"