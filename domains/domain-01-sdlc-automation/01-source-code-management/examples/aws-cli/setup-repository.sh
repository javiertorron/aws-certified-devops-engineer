#!/bin/bash

# AWS CLI Script for Source Code Management Setup
# This script creates a CodeCommit repository with proper configuration
# Usage: ./setup-repository.sh [repository-name] [description] [team-name]

set -e  # Exit on any error

# Configuration
REPOSITORY_NAME=${1:-"my-application"}
REPOSITORY_DESCRIPTION=${2:-"Main application repository for DevOps pipeline"}
TEAM_NAME=${3:-"DevOpsTeam"}
AWS_REGION=${AWS_REGION:-"us-west-2"}
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Check if AWS CLI is installed and configured
check_aws_cli() {
    log_info "Checking AWS CLI configuration..."
    
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS CLI is not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    log_success "AWS CLI is properly configured"
}

# Create CodeCommit repository
create_repository() {
    log_info "Creating CodeCommit repository: $REPOSITORY_NAME"
    
    # Check if repository already exists
    if aws codecommit get-repository --repository-name "$REPOSITORY_NAME" &> /dev/null; then
        log_warning "Repository $REPOSITORY_NAME already exists"
        return 0
    fi
    
    # Create the repository
    REPO_RESPONSE=$(aws codecommit create-repository \
        --repository-name "$REPOSITORY_NAME" \
        --repository-description "$REPOSITORY_DESCRIPTION" \
        --tags Team="$TEAM_NAME",Purpose="SourceControl",CreatedBy="script" \
        --output json)
    
    if [ $? -eq 0 ]; then
        log_success "Repository created successfully"
        echo "$REPO_RESPONSE" | jq -r '.repositoryMetadata | "Repository ARN: \(.Arn)\nClone URL (HTTP): \(.cloneUrlHttp)\nClone URL (SSH): \(.cloneUrlSsh)"'
    else
        log_error "Failed to create repository"
        exit 1
    fi
}

# Create IAM policies and roles
create_iam_resources() {
    log_info "Creating IAM resources..."
    
    # Developer policy document
    DEVELOPER_POLICY=$(cat <<EOF
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
            "Resource": "arn:aws:codecommit:${AWS_REGION}:${AWS_ACCOUNT_ID}:${REPOSITORY_NAME}"
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
            "Resource": "arn:aws:codecommit:${AWS_REGION}:${AWS_ACCOUNT_ID}:${REPOSITORY_NAME}"
        }
    ]
}
EOF
)
    
    # Create developer policy
    POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${REPOSITORY_NAME}-developer-policy"
    
    if aws iam get-policy --policy-arn "$POLICY_ARN" &> /dev/null; then
        log_warning "Developer policy already exists"
    else
        aws iam create-policy \
            --policy-name "${REPOSITORY_NAME}-developer-policy" \
            --policy-document "$DEVELOPER_POLICY" \
            --description "Policy for developers to access $REPOSITORY_NAME repository" > /dev/null
        
        if [ $? -eq 0 ]; then
            log_success "Developer policy created: $POLICY_ARN"
        else
            log_error "Failed to create developer policy"
            exit 1
        fi
    fi
    
    # Trust policy for developer role
    TRUST_POLICY=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${AWS_ACCOUNT_ID}:root"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
)
    
    # Create developer role
    ROLE_NAME="${REPOSITORY_NAME}-developer-role"
    
    if aws iam get-role --role-name "$ROLE_NAME" &> /dev/null; then
        log_warning "Developer role already exists"
    else
        aws iam create-role \
            --role-name "$ROLE_NAME" \
            --assume-role-policy-document "$TRUST_POLICY" \
            --description "Role for developers to access $REPOSITORY_NAME repository" > /dev/null
        
        if [ $? -eq 0 ]; then
            log_success "Developer role created: $ROLE_NAME"
            
            # Attach policy to role
            aws iam attach-role-policy \
                --role-name "$ROLE_NAME" \
                --policy-arn "$POLICY_ARN"
                
            log_success "Policy attached to developer role"
        else
            log_error "Failed to create developer role"
            exit 1
        fi
    fi
}

# Create CloudWatch Log Group
create_log_group() {
    log_info "Creating CloudWatch Log Group..."
    
    LOG_GROUP_NAME="/aws/codecommit/${REPOSITORY_NAME}"
    
    if aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP_NAME" --query 'logGroups[0].logGroupName' --output text | grep -q "$LOG_GROUP_NAME"; then
        log_warning "Log group already exists"
    else
        aws logs create-log-group \
            --log-group-name "$LOG_GROUP_NAME" \
            --tags Team="$TEAM_NAME",Repository="$REPOSITORY_NAME"
        
        if [ $? -eq 0 ]; then
            log_success "Log group created: $LOG_GROUP_NAME"
            
            # Set retention policy
            aws logs put-retention-policy \
                --log-group-name "$LOG_GROUP_NAME" \
                --retention-in-days 30
                
            log_success "Retention policy set to 30 days"
        else
            log_error "Failed to create log group"
        fi
    fi
}

# Configure local Git repository
configure_git() {
    log_info "Configuring local Git settings..."
    
    # Get repository URL
    CLONE_URL=$(aws codecommit get-repository \
        --repository-name "$REPOSITORY_NAME" \
        --query 'repositoryMetadata.cloneUrlHttp' \
        --output text)
    
    # Create Git configuration file
    cat > ".gitconfig-${REPOSITORY_NAME}" <<EOF
# Git configuration for ${REPOSITORY_NAME}
[credential]
    helper = !aws codecommit credential-helper \$@
    UseHttpPath = true

# Repository Information
# Clone URL: ${CLONE_URL}
# Repository: ${REPOSITORY_NAME}
# Team: ${TEAM_NAME}

# Recommended global settings
[user]
    # name = Your Name
    # email = your.email@company.com

[core]
    editor = code --wait
    autocrlf = input

[pull]
    rebase = true

[push]
    default = current

[branch]
    autosetuprebase = always
EOF
    
    log_success "Git configuration file created: .gitconfig-${REPOSITORY_NAME}"
    log_info "To use this configuration, run: git config --local include.path $(pwd)/.gitconfig-${REPOSITORY_NAME}"
}

# Create sample repository structure
create_sample_structure() {
    log_info "Creating sample repository structure..."
    
    TEMP_DIR="/tmp/${REPOSITORY_NAME}-setup"
    
    # Clean up existing temp directory
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Initialize Git repository
    git init
    
    # Configure Git for this repository
    git config credential.helper '!aws codecommit credential-helper $@'
    git config credential.UseHttpPath true
    
    # Create sample files
    cat > README.md <<EOF
# ${REPOSITORY_NAME}

${REPOSITORY_DESCRIPTION}

## Getting Started

This repository is set up for AWS DevOps practices with CodeCommit.

### Prerequisites

- AWS CLI configured
- Git installed
- Appropriate IAM permissions

### Repository Structure

\`\`\`
.
├── README.md
├── .gitignore
├── src/
│   ├── main/
│   └── test/
├── docs/
├── scripts/
├── infrastructure/
└── buildspec.yml
\`\`\`

### Development Workflow

1. Create feature branch: \`git checkout -b feature/your-feature\`
2. Make changes and commit
3. Push branch: \`git push -u origin feature/your-feature\`
4. Create pull request
5. After approval, merge to main

### CI/CD Integration

This repository is configured to work with:
- AWS CodeBuild
- AWS CodeDeploy
- AWS CodePipeline

## Team: ${TEAM_NAME}
EOF
    
    # Create .gitignore
    cat > .gitignore <<EOF
# AWS credentials
.aws/
*.pem
*.key

# Environment variables
.env
.env.local
.env.*.local

# IDE files
.vscode/
.idea/
*.swp
*.swo

# OS files
.DS_Store
Thumbs.db

# Logs
logs/
*.log

# Dependencies
node_modules/
__pycache__/
*.pyc
*.pyo

# Build outputs
dist/
build/
target/
EOF
    
    # Create basic directory structure
    mkdir -p src/{main,test}
    mkdir -p docs
    mkdir -p scripts/{build,deploy}
    mkdir -p infrastructure/{cloudformation,terraform}
    
    # Create sample buildspec.yml
    cat > buildspec.yml <<EOF
version: 0.2

phases:
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - echo Build started on \`date\`
  build:
    commands:
      - echo Build phase started
      - echo Running tests...
      # Add your build commands here
  post_build:
    commands:
      - echo Build completed on \`date\`

artifacts:
  files:
    - '**/*'
  name: ${REPOSITORY_NAME}-\$(date +%Y-%m-%d)
EOF
    
    # Add and commit files
    git add .
    git commit -m "Initial commit: Setup repository structure

- Add README with project information
- Add .gitignore for common files
- Create basic directory structure
- Add sample buildspec.yml for CodeBuild"
    
    # Add remote and push
    CLONE_URL=$(aws codecommit get-repository \
        --repository-name "$REPOSITORY_NAME" \
        --query 'repositoryMetadata.cloneUrlHttp' \
        --output text)
    
    git remote add origin "$CLONE_URL"
    git push -u origin main
    
    log_success "Sample repository structure created and pushed"
    
    # Clean up
    cd - > /dev/null
    rm -rf "$TEMP_DIR"
}

# Display summary
display_summary() {
    log_info "Setup Summary:"
    echo
    echo "Repository Details:"
    echo "  Name: $REPOSITORY_NAME"
    echo "  Description: $REPOSITORY_DESCRIPTION"
    echo "  Team: $TEAM_NAME"
    echo
    
    # Get repository information
    REPO_INFO=$(aws codecommit get-repository --repository-name "$REPOSITORY_NAME" --output json)
    CLONE_URL_HTTP=$(echo "$REPO_INFO" | jq -r '.repositoryMetadata.cloneUrlHttp')
    CLONE_URL_SSH=$(echo "$REPO_INFO" | jq -r '.repositoryMetadata.cloneUrlSsh')
    
    echo "Clone URLs:"
    echo "  HTTP: $CLONE_URL_HTTP"
    echo "  SSH:  $CLONE_URL_SSH"
    echo
    
    echo "IAM Resources Created:"
    echo "  Developer Policy: ${REPOSITORY_NAME}-developer-policy"
    echo "  Developer Role: ${REPOSITORY_NAME}-developer-role"
    echo
    
    echo "Next Steps:"
    echo "1. Clone the repository: git clone $CLONE_URL_HTTP"
    echo "2. Configure your Git user: git config user.name 'Your Name'"
    echo "3. Configure your Git email: git config user.email 'your.email@company.com'"
    echo "4. Start developing!"
    echo
    
    log_success "Repository setup completed successfully!"
}

# Main execution
main() {
    log_info "Starting CodeCommit repository setup..."
    log_info "Repository: $REPOSITORY_NAME"
    log_info "Description: $REPOSITORY_DESCRIPTION"
    log_info "Team: $TEAM_NAME"
    echo
    
    check_aws_cli
    create_repository
    create_iam_resources
    create_log_group
    configure_git
    create_sample_structure
    display_summary
}

# Execute main function
main "$@"