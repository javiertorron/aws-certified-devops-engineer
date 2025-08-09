# Source Code Management - Comprehensive Guide

## Table of Contents
1. [Version Control Fundamentals](#version-control-fundamentals)
2. [Git Architecture and Best Practices](#git-architecture-and-best-practices)
3. [Branching Strategies](#branching-strategies)
4. [Code Review and Quality Gates](#code-review-and-quality-gates)
5. [AWS Integration Patterns](#aws-integration-patterns)
6. [Security and Compliance](#security-and-compliance)
7. [Monitoring and Observability](#monitoring-and-observability)
8. [Troubleshooting Common Issues](#troubleshooting-common-issues)

---

## Version Control Fundamentals

### Core Concepts

**Version Control System (VCS)** is a system that records changes to files over time, allowing you to recall specific versions later. In the context of AWS DevOps, version control is the cornerstone of automated pipelines and infrastructure as code.

#### Key Benefits in AWS DevOps:
- **Traceability**: Every change is tracked and attributed
- **Collaboration**: Multiple developers can work simultaneously
- **Rollback Capability**: Easy reversion to previous states
- **Branch Management**: Parallel development streams
- **Integration**: Seamless connection with CI/CD pipelines

### Git vs Other Version Control Systems

| Feature | Git (Distributed) | SVN (Centralized) | Perforce |
|---------|-------------------|-------------------|----------|
| Architecture | Distributed | Centralized | Centralized |
| Offline Work | Full capability | Limited | Limited |
| Branching | Lightweight | Heavy | Heavy |
| AWS Integration | Native support | Limited | Limited |
| Performance | Fast | Slower | Fast |

**Why Git for AWS DevOps?**
- Native integration with all AWS Developer Tools
- Distributed nature supports cloud-native architectures
- Excellent branching model for microservices
- Strong community and tooling ecosystem

---

## Git Architecture and Best Practices

### Repository Structure

#### Recommended Directory Structure:
```
project-root/
├── .gitignore
├── README.md
├── LICENSE
├── CHANGELOG.md
├── src/
│   ├── main/
│   └── test/
├── docs/
├── scripts/
│   ├── build/
│   └── deploy/
├── infrastructure/
│   ├── cloudformation/
│   ├── terraform/
│   └── cdk/
├── .github/
│   ├── workflows/
│   └── ISSUE_TEMPLATE/
└── buildspec.yml
```

### Commit Best Practices

#### Commit Message Convention (Conventional Commits):
```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

**Examples:**
```
feat(auth): add OAuth2 integration with Cognito
fix(api): resolve null pointer exception in user service
docs: update deployment guide for EKS
chore(deps): bump boto3 from 1.26.0 to 1.27.0
```

#### Commit Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or modifying tests
- `chore`: Maintenance tasks

### Tagging and Release Management

#### Semantic Versioning (SemVer):
```
MAJOR.MINOR.PATCH
```

**Examples:**
- `1.0.0` - Initial release
- `1.1.0` - New feature (backwards compatible)
- `1.1.1` - Bug fix (backwards compatible)
- `2.0.0` - Breaking change

#### Git Tagging Commands:
```bash
# Create annotated tag
git tag -a v1.2.3 -m "Release version 1.2.3"

# Push tags to remote
git push origin --tags

# List tags
git tag -l
```

---

## Branching Strategies

### Git Flow

**Best for:** Large teams with scheduled releases

#### Main Branches:
- `main`: Production-ready code
- `develop`: Integration branch for features

#### Supporting Branches:
- `feature/*`: New features
- `release/*`: Release preparation
- `hotfix/*`: Critical production fixes

#### Workflow:
```bash
# Start new feature
git checkout develop
git checkout -b feature/user-authentication

# Finish feature
git checkout develop
git merge --no-ff feature/user-authentication
git branch -d feature/user-authentication

# Create release
git checkout develop
git checkout -b release/1.2.0

# Finish release
git checkout main
git merge --no-ff release/1.2.0
git tag -a v1.2.0
git checkout develop
git merge --no-ff release/1.2.0
```

### GitHub Flow

**Best for:** Continuous deployment environments

#### Simple Workflow:
1. Create feature branch from `main`
2. Make commits
3. Open pull request
4. Deploy to staging for testing
5. Merge to `main`
6. Deploy to production

```bash
# Create feature branch
git checkout main
git pull origin main
git checkout -b feature/add-monitoring

# Make changes and commit
git add .
git commit -m "feat: add CloudWatch monitoring"

# Push and create PR
git push -u origin feature/add-monitoring
```

### GitLab Flow

**Best for:** Environment-specific deployments

#### Environment Branches:
- `main`: Development environment
- `pre-production`: Staging environment  
- `production`: Production environment

#### Workflow with Environments:
```bash
# Deploy to staging
git checkout pre-production
git merge main

# Deploy to production
git checkout production  
git merge pre-production
```

### Strategy Selection Guidelines

| Team Size | Release Frequency | Recommended Strategy |
|-----------|------------------|---------------------|
| Small (1-5) | Continuous | GitHub Flow |
| Medium (5-20) | Weekly/Bi-weekly | GitLab Flow |
| Large (20+) | Monthly/Quarterly | Git Flow |

---

## Code Review and Quality Gates

### Pull Request Workflow

#### Essential Elements:
1. **Clear Description**: What and why
2. **Small, Focused Changes**: Single responsibility
3. **Tests Included**: Unit and integration tests
4. **Documentation Updated**: README, API docs, etc.

#### Pull Request Template:
```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature  
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No sensitive data exposed
```

### Automated Quality Gates

#### Pre-commit Hooks:
```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
  
  - repo: https://github.com/psf/black
    rev: 22.10.0
    hooks:
      - id: black
        language_version: python3
```

#### GitHub Actions for Quality Gates:
```yaml
name: Quality Gates
on:
  pull_request:
    branches: [ main, develop ]

jobs:
  code-quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.9'
          
      - name: Install dependencies
        run: |
          pip install flake8 pytest black
          
      - name: Lint with flake8
        run: flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics
        
      - name: Test with pytest
        run: pytest tests/
        
      - name: Check formatting
        run: black --check .
```

### Security Scanning Integration

#### Tools and Services:
- **AWS CodeGuru Reviewer**: AI-powered code reviews
- **Snyk**: Vulnerability scanning
- **SonarQube**: Code quality and security
- **GitHub Advanced Security**: SAST/DAST scanning

---

## AWS Integration Patterns

### CodeCommit Repository Setup

#### Repository Configuration:
```bash
# Create repository
aws codecommit create-repository \
    --repository-name my-application \
    --repository-description "Main application repository"

# Clone repository
git clone https://git-codecommit.us-west-2.amazonaws.com/v1/repos/my-application
```

#### IAM Policies for CodeCommit:
```json
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
                "codecommit:Update*"
            ],
            "Resource": "arn:aws:codecommit:us-west-2:123456789012:my-application"
        }
    ]
}
```

### Event-Driven Automation

#### CloudWatch Events for Repository Changes:
```json
{
    "source": ["aws.codecommit"],
    "detail-type": ["CodeCommit Repository State Change"],
    "detail": {
        "event": ["referenceCreated", "referenceUpdated"],
        "repositoryName": ["my-application"],
        "referenceName": ["refs/heads/main"]
    }
}
```

#### Lambda Function for Automated Actions:
```python
import boto3
import json

def lambda_handler(event, context):
    """
    Triggered on CodeCommit events to start CodePipeline
    """
    detail = event['detail']
    repository_name = detail['repositoryName']
    reference_name = detail['referenceName']
    
    if reference_name == 'refs/heads/main':
        # Trigger pipeline
        codepipeline = boto3.client('codepipeline')
        
        response = codepipeline.start_pipeline_execution(
            name=f'{repository_name}-pipeline'
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps(f'Pipeline started: {response["pipelineExecutionId"]}')
        }
    
    return {
        'statusCode': 200,
        'body': json.dumps('No action taken')
    }
```

---

## Security and Compliance

### Repository Access Controls

#### Branch Protection Rules:
- Require pull request reviews
- Dismiss stale reviews when new commits are pushed
- Require status checks before merging
- Require branches to be up-to-date
- Include administrators in restrictions

#### CodeCommit Approval Rules:
```json
{
    "destinationReferences": ["refs/heads/main"],
    "approvalRules": [{
        "approvalRuleName": "Require-2-Approvers",
        "approvalRuleContent": {
            "Version": "2018-11-08",
            "DestinationReferences": ["refs/heads/main"],
            "Statements": [{
                "Type": "Approvers",
                "NumberOfApprovalsNeeded": 2,
                "ApprovalPoolMembers": [
                    "arn:aws:sts::123456789012:assumed-role/CodeCommitRole/senior-dev-1",
                    "arn:aws:sts::123456789012:assumed-role/CodeCommitRole/senior-dev-2"
                ]
            }]
        }
    }]
}
```

### Secrets Management

#### .gitignore Best Practices:
```gitignore
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

# Dependencies
node_modules/
__pycache__/
*.pyc
```

#### Pre-commit Hooks for Secret Detection:
```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']
```

### Audit and Compliance

#### CloudTrail for Repository Auditing:
- Track all API calls to CodeCommit
- Monitor user access patterns
- Detect unauthorized access attempts
- Maintain compliance audit trails

#### Compliance Frameworks:
- **SOX**: Change tracking and approval workflows
- **PCI DSS**: Access controls and audit trails
- **HIPAA**: Encryption and access logging
- **ISO 27001**: Information security management

---

## Monitoring and Observability

### Key Metrics to Track

#### Repository Health Metrics:
- Commit frequency
- Pull request cycle time
- Code review participation
- Branch age and cleanup
- Security vulnerability detection rate

#### AWS CloudWatch Metrics:
```python
import boto3
from datetime import datetime, timedelta

cloudwatch = boto3.client('cloudwatch')

# Custom metric for commit frequency
cloudwatch.put_metric_data(
    Namespace='CodeCommit/Repository',
    MetricData=[
        {
            'MetricName': 'CommitsPerDay',
            'Dimensions': [
                {
                    'Name': 'RepositoryName',
                    'Value': 'my-application'
                }
            ],
            'Value': commit_count,
            'Unit': 'Count',
            'Timestamp': datetime.utcnow()
        }
    ]
)
```

### Dashboard Creation

#### CloudWatch Dashboard Configuration:
```json
{
    "widgets": [
        {
            "type": "metric",
            "properties": {
                "metrics": [
                    ["CodeCommit/Repository", "CommitsPerDay", "RepositoryName", "my-application"],
                    [".", "PullRequestsCreated", ".", "."],
                    [".", "PullRequestsMerged", ".", "."]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "us-west-2",
                "title": "Repository Activity"
            }
        }
    ]
}
```

---

## Troubleshooting Common Issues

### Authentication Problems

#### Issue: Git credentials not working
**Solution:**
```bash
# Configure Git credential helper for CodeCommit
git config --global credential.helper '!aws codecommit credential-helper $@'
git config --global credential.UseHttpPath true
```

#### Issue: Access denied errors
**Troubleshooting Steps:**
1. Verify IAM permissions
2. Check repository policies
3. Validate AWS CLI configuration
4. Test with different authentication method

### Performance Issues

#### Issue: Large repository size
**Solutions:**
- Use Git LFS for large files
- Implement repository pruning
- Consider repository splitting
- Regular cleanup of old branches

```bash
# Enable Git LFS
git lfs install
git lfs track "*.zip"
git lfs track "*.tar.gz"
git add .gitattributes
```

### Merge Conflicts

#### Prevention Strategies:
- Keep branches short-lived
- Rebase frequently
- Use small, focused commits
- Communicate with team about overlapping work

#### Resolution Process:
```bash
# Fetch latest changes
git fetch origin main

# Rebase feature branch
git checkout feature-branch
git rebase origin/main

# Resolve conflicts manually
# Then continue rebase
git add .
git rebase --continue
```

---

## Best Practices Summary

### Development Workflow
1. **Small, Frequent Commits**: Easier to review and debug
2. **Meaningful Commit Messages**: Following conventional commit format
3. **Feature Branches**: Isolate development work
4. **Regular Integration**: Avoid large merge conflicts

### Security
1. **Never Commit Secrets**: Use environment variables and secret management
2. **Code Reviews**: Mandatory for all changes
3. **Automated Scanning**: Integrate security tools in pipeline
4. **Access Controls**: Principle of least privilege

### AWS Integration
1. **Event-Driven Automation**: Use CloudWatch Events for triggers
2. **Proper IAM Policies**: Granular permissions for different roles
3. **Monitoring**: Track repository health and usage metrics
4. **Cross-Region Replication**: For disaster recovery

### Performance
1. **Repository Size Management**: Keep repositories focused and lean
2. **Branch Cleanup**: Regular pruning of merged branches
3. **Efficient Branching Strategy**: Match strategy to team size and release cadence
4. **Automated Quality Gates**: Fail fast with pre-commit hooks and CI checks

---

This comprehensive guide provides the foundation for effective source code management in AWS DevOps environments. The next topic will focus on implementing these concepts specifically with AWS CodeCommit.