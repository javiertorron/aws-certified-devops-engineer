# Lab 1: Setting Up a CodeCommit Repository with Source Code Management Best Practices

## Lab Overview
In this hands-on lab, you will create a CodeCommit repository from scratch, configure proper access controls, implement branching strategies, and set up automated workflows for source code management.

### Learning Objectives
By the end of this lab, you will be able to:
- Create and configure a CodeCommit repository
- Set up IAM policies and roles for repository access
- Implement Git branching strategies
- Configure automated notifications and monitoring
- Create and manage pull requests with approval rules

### Prerequisites
- AWS CLI configured with appropriate permissions
- Git installed on your local machine
- Basic understanding of Git commands
- An AWS account with CodeCommit access

### Estimated Time
**2-3 hours**

---

## Part 1: Repository Creation and Basic Configuration (45 minutes)

### Step 1: Create CodeCommit Repository

1. **Using AWS CLI:**
   ```bash
   # Create the repository
   aws codecommit create-repository \
       --repository-name "devops-demo-app" \
       --repository-description "Demo application for DevOps pipeline learning" \
       --tags Team=DevOpsLearning,Purpose=Training,Environment=Demo
   
   # Verify creation
   aws codecommit get-repository --repository-name devops-demo-app
   ```

2. **Record the output:**
   - Repository ARN
   - Clone URL (HTTP)
   - Clone URL (SSH)

### Step 2: Configure Local Git Environment

1. **Configure Git credentials for CodeCommit:**
   ```bash
   # Configure credential helper
   git config --global credential.helper '!aws codecommit credential-helper $@'
   git config --global credential.UseHttpPath true
   
   # Set your identity (replace with your information)
   git config --global user.name "Your Name"
   git config --global user.email "your.email@example.com"
   ```

2. **Clone the repository:**
   ```bash
   # Use the clone URL from Step 1
   git clone https://git-codecommit.us-west-2.amazonaws.com/v1/repos/devops-demo-app
   cd devops-demo-app
   ```

### Step 3: Create Initial Repository Structure

1. **Create basic directory structure:**
   ```bash
   # Create directories
   mkdir -p src/{main/{java,resources},test/{java,resources}}
   mkdir -p docs
   mkdir -p scripts/{build,deploy}
   mkdir -p infrastructure/{cloudformation,terraform}
   mkdir -p .github/workflows
   ```

2. **Create .gitignore file:**
   ```bash
   cat > .gitignore << 'EOF'
   # Compiled class files
   *.class
   
   # Log files
   *.log
   
   # Package files
   *.jar
   *.war
   *.nar
   *.ear
   *.zip
   *.tar.gz
   *.rar
   
   # IDE files
   .idea/
   *.iml
   .vscode/
   
   # OS files
   .DS_Store
   Thumbs.db
   
   # AWS credentials
   .aws/
   *.pem
   *.key
   
   # Environment variables
   .env
   .env.local
   .env.*.local
   
   # Build outputs
   target/
   build/
   dist/
   EOF
   ```

3. **Create comprehensive README.md:**
   ```bash
   cat > README.md << 'EOF'
   # DevOps Demo Application
   
   A demonstration application for learning AWS DevOps practices and CI/CD pipelines.
   
   ## Architecture Overview
   
   This application demonstrates:
   - Source code management with CodeCommit
   - Automated builds with CodeBuild
   - Deployment automation with CodeDeploy
   - Pipeline orchestration with CodePipeline
   
   ## Repository Structure
   
   ```
   .
   ├── src/                    # Source code
   │   ├── main/
   │   └── test/
   ├── docs/                   # Documentation
   ├── scripts/                # Build and deployment scripts
   ├── infrastructure/         # Infrastructure as Code
   │   ├── cloudformation/
   │   └── terraform/
   ├── .github/                # GitHub Actions (if using)
   ├── buildspec.yml          # CodeBuild specification
   └── appspec.yml            # CodeDeploy specification
   ```
   
   ## Development Workflow
   
   ### Branching Strategy
   We follow Git Flow methodology:
   
   - `main`: Production-ready code
   - `develop`: Integration branch
   - `feature/*`: Feature development
   - `hotfix/*`: Production hotfixes
   - `release/*`: Release preparation
   
   ### Getting Started
   
   1. Clone the repository:
      ```bash
      git clone https://git-codecommit.us-west-2.amazonaws.com/v1/repos/devops-demo-app
      ```
   
   2. Create a feature branch:
      ```bash
      git checkout develop
      git checkout -b feature/your-feature-name
      ```
   
   3. Make your changes and commit:
      ```bash
      git add .
      git commit -m "feat: add your feature description"
      ```
   
   4. Push and create pull request:
      ```bash
      git push -u origin feature/your-feature-name
      ```
   
   ## Contributing
   
   1. Follow the branching strategy
   2. Write descriptive commit messages
   3. Include tests for new features
   4. Update documentation as needed
   5. Request code review before merging
   
   ## CI/CD Pipeline
   
   This repository is configured with:
   - Automated testing on pull requests
   - Automatic deployment to staging on merge to develop
   - Manual promotion to production
   
   ## Team
   - DevOps Learning Team
   EOF
   ```

4. **Create buildspec.yml for CodeBuild:**
   ```bash
   cat > buildspec.yml << 'EOF'
   version: 0.2
   
   phases:
     pre_build:
       commands:
         - echo Logging in to Amazon ECR...
         - aws --version
         - echo Build started on `date`
         - echo Setting up environment...
     build:
       commands:
         - echo Build started on `date`
         - echo Compiling the application...
         # Add your build commands here
         - echo Running unit tests...
         # mvn clean test (for Java projects)
         - echo Build phase completed
     post_build:
       commands:
         - echo Build completed on `date`
         - echo Preparing artifacts...
   
   artifacts:
     files:
       - '**/*'
     name: devops-demo-app-$(date +%Y-%m-%d-%H-%M-%S)
     
   cache:
     paths:
       - '/root/.m2/**/*'  # Maven dependencies cache
   EOF
   ```

5. **Commit initial structure:**
   ```bash
   git add .
   git commit -m "feat: initial repository structure
   
   - Add basic directory structure
   - Configure .gitignore for Java/AWS projects
   - Add comprehensive README with workflow documentation
   - Include buildspec.yml for CodeBuild integration
   - Set up foundation for DevOps pipeline"
   
   git push -u origin main
   ```

**✅ Checkpoint 1:** You should now have a CodeCommit repository with basic structure pushed to the main branch.

---

## Part 2: IAM Configuration and Access Control (30 minutes)

### Step 4: Create IAM Policies and Roles

1. **Create Developer Policy:**
   ```bash
   cat > developer-policy.json << 'EOF'
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
               "Resource": "arn:aws:codecommit:*:*:devops-demo-app"
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
               "Resource": "arn:aws:codecommit:*:*:devops-demo-app"
           }
       ]
   }
   EOF
   
   # Create the policy
   aws iam create-policy \
       --policy-name "DevOpsDemoApp-Developer-Policy" \
       --policy-document file://developer-policy.json \
       --description "Policy for developers to access DevOps demo application repository"
   ```

2. **Create CI/CD Policy:**
   ```bash
   cat > cicd-policy.json << 'EOF'
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
               "Resource": "arn:aws:codecommit:*:*:devops-demo-app"
           }
       ]
   }
   EOF
   
   # Create the policy
   aws iam create-policy \
       --policy-name "DevOpsDemoApp-CICD-Policy" \
       --policy-document file://cicd-policy.json \
       --description "Policy for CI/CD pipeline to access DevOps demo application repository"
   ```

3. **Create Developer Role:**
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
               "Action": "sts:AssumeRole"
           }
       ]
   }
   EOF
   
   # Replace ACCOUNT_ID with your actual account ID
   ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
   sed -i "s/ACCOUNT_ID/$ACCOUNT_ID/g" developer-trust-policy.json
   
   # Create the role
   aws iam create-role \
       --role-name "DevOpsDemoApp-Developer-Role" \
       --assume-role-policy-document file://developer-trust-policy.json \
       --description "Role for developers to access DevOps demo application repository"
   
   # Attach policy to role
   POLICY_ARN="arn:aws:iam::$ACCOUNT_ID:policy/DevOpsDemoApp-Developer-Policy"
   aws iam attach-role-policy \
       --role-name "DevOpsDemoApp-Developer-Role" \
       --policy-arn "$POLICY_ARN"
   ```

**✅ Checkpoint 2:** You should have IAM policies and roles configured for repository access.

---

## Part 3: Branching Strategy Implementation (45 minutes)

### Step 5: Implement Git Flow Branching Strategy

1. **Create develop branch:**
   ```bash
   # Ensure you're on main and up to date
   git checkout main
   git pull origin main
   
   # Create develop branch
   git checkout -b develop
   git push -u origin develop
   ```

2. **Create your first feature branch:**
   ```bash
   # Create feature branch from develop
   git checkout develop
   git checkout -b feature/add-hello-world-service
   ```

3. **Add sample code:**
   ```bash
   # Create a simple Java service
   mkdir -p src/main/java/com/demo/service
   cat > src/main/java/com/demo/service/HelloWorldService.java << 'EOF'
   package com.demo.service;
   
   public class HelloWorldService {
       
       public String getGreeting(String name) {
           if (name == null || name.trim().isEmpty()) {
               return "Hello, World!";
           }
           return "Hello, " + name + "!";
       }
       
       public String getStatus() {
           return "Service is running";
       }
   }
   EOF
   
   # Create corresponding test
   mkdir -p src/test/java/com/demo/service
   cat > src/test/java/com/demo/service/HelloWorldServiceTest.java << 'EOF'
   package com.demo.service;
   
   import org.junit.Test;
   import static org.junit.Assert.*;
   
   public class HelloWorldServiceTest {
       
       private HelloWorldService service = new HelloWorldService();
       
       @Test
       public void testGetGreetingWithName() {
           String result = service.getGreeting("DevOps");
           assertEquals("Hello, DevOps!", result);
       }
       
       @Test
       public void testGetGreetingWithoutName() {
           String result = service.getGreeting(null);
           assertEquals("Hello, World!", result);
       }
       
       @Test
       public void testGetStatus() {
           String result = service.getStatus();
           assertEquals("Service is running", result);
       }
   }
   EOF
   ```

4. **Commit and push feature:**
   ```bash
   git add .
   git commit -m "feat: add HelloWorldService with comprehensive tests
   
   - Implement greeting service with name parameter support
   - Add status endpoint for health checks
   - Include comprehensive unit tests
   - Follow Java naming conventions and best practices"
   
   git push -u origin feature/add-hello-world-service
   ```

**✅ Checkpoint 3:** You should have a feature branch with sample code pushed to the repository.

---

## Part 4: Pull Request and Approval Rules (30 minutes)

### Step 6: Configure Approval Rules

1. **Create approval rule template:**
   ```bash
   cat > approval-rule-template.json << 'EOF'
   {
       "approvalRuleTemplateName": "DevOpsDemoApp-Main-Branch-Approval",
       "approvalRuleTemplateDescription": "Approval rule for main branch requiring senior developer approval",
       "approvalRuleTemplateContent": "{\"Version\": \"2018-11-08\", \"DestinationReferences\": [\"refs/heads/main\"], \"Statements\": [{\"Type\": \"Approvers\", \"NumberOfApprovalsNeeded\": 1, \"ApprovalPoolMembers\": [\"arn:aws:iam::ACCOUNT_ID:root\"]}]}"
   }
   EOF
   
   # Replace ACCOUNT_ID
   sed -i "s/ACCOUNT_ID/$ACCOUNT_ID/g" approval-rule-template.json
   
   # Create the approval rule template
   aws codecommit create-approval-rule-template \
       --cli-input-json file://approval-rule-template.json
   ```

2. **Associate approval rule with repository:**
   ```bash
   aws codecommit associate-approval-rule-template-with-repository \
       --approval-rule-template-name "DevOpsDemoApp-Main-Branch-Approval" \
       --repository-name "devops-demo-app"
   ```

### Step 7: Create Pull Request

1. **Create pull request from feature to develop:**
   ```bash
   aws codecommit create-pull-request \
       --title "Add HelloWorldService implementation" \
       --description "This pull request adds a HelloWorldService with the following features:
   
   ## Changes Made
   - Implemented HelloWorldService with greeting functionality
   - Added comprehensive unit tests
   - Followed Java naming conventions and best practices
   
   ## Testing
   - Unit tests cover all public methods
   - Edge cases handled (null and empty inputs)
   - All tests pass locally
   
   ## Type of Change
   - [x] New feature
   - [ ] Bug fix
   - [ ] Breaking change
   - [ ] Documentation update" \
       --targets repositoryName=devops-demo-app,sourceReference=refs/heads/feature/add-hello-world-service,destinationReference=refs/heads/develop
   ```

2. **List pull requests to verify creation:**
   ```bash
   aws codecommit list-pull-requests --repository-name devops-demo-app
   ```

**✅ Checkpoint 4:** You should have created a pull request with approval rules configured.

---

## Part 5: Monitoring and Automation (30 minutes)

### Step 8: Set up CloudWatch Monitoring

1. **Create CloudWatch Log Group:**
   ```bash
   aws logs create-log-group \
       --log-group-name "/aws/codecommit/devops-demo-app" \
       --tags Team=DevOpsLearning,Purpose=Monitoring
   
   # Set retention policy
   aws logs put-retention-policy \
       --log-group-name "/aws/codecommit/devops-demo-app" \
       --retention-in-days 30
   ```

2. **Create SNS topic for notifications:**
   ```bash
   aws sns create-topic \
       --name "devops-demo-app-notifications" \
       --tags Key=Team,Value=DevOpsLearning Key=Purpose,Value=Notifications
   
   # Subscribe your email (replace with your email)
   aws sns subscribe \
       --topic-arn "arn:aws:sns:us-west-2:$ACCOUNT_ID:devops-demo-app-notifications" \
       --protocol email \
       --notification-endpoint your.email@example.com
   ```

3. **Create repository trigger:**
   ```bash
   # Get the SNS topic ARN
   TOPIC_ARN=$(aws sns list-topics --query 'Topics[?contains(TopicArn, `devops-demo-app-notifications`)].TopicArn' --output text)
   
   # Create trigger configuration
   cat > trigger-config.json << EOF
   {
       "repositoryName": "devops-demo-app",
       "triggers": [
           {
               "name": "MainBranchTrigger",
               "destinationArn": "$TOPIC_ARN",
               "events": ["updateReference"],
               "branches": ["main"]
           },
           {
               "name": "DevelopBranchTrigger", 
               "destinationArn": "$TOPIC_ARN",
               "events": ["updateReference"],
               "branches": ["develop"]
           }
       ]
   }
   EOF
   
   # Apply triggers
   aws codecommit put-repository-triggers --cli-input-json file://trigger-config.json
   ```

### Step 9: Test the Complete Workflow

1. **Merge the pull request:**
   ```bash
   # Get pull request ID
   PR_ID=$(aws codecommit list-pull-requests --repository-name devops-demo-app --query 'pullRequestIds[0]' --output text)
   
   # Merge pull request (if you have approval)
   aws codecommit merge-pull-request-by-fast-forward \
       --pull-request-id "$PR_ID" \
       --repository-name "devops-demo-app"
   ```

2. **Create a release branch:**
   ```bash
   # Switch to develop and pull latest
   git checkout develop
   git pull origin develop
   
   # Create release branch
   git checkout -b release/1.0.0
   
   # Create version file
   echo "1.0.0" > VERSION
   git add VERSION
   git commit -m "chore: bump version to 1.0.0 for release"
   
   # Push release branch
   git push -u origin release/1.0.0
   ```

3. **Merge release to main:**
   ```bash
   # Create pull request from release to main
   aws codecommit create-pull-request \
       --title "Release v1.0.0" \
       --description "Release version 1.0.0 with HelloWorldService implementation" \
       --targets repositoryName=devops-demo-app,sourceReference=refs/heads/release/1.0.0,destinationReference=refs/heads/main
   ```

**✅ Checkpoint 5:** You should have a complete workflow with monitoring and notifications configured.

---

## Part 6: Repository Health Check and Best Practices (20 minutes)

### Step 10: Implement Repository Health Checks

1. **Run the health check script:**
   ```bash
   # Copy the automation script from examples
   curl -o git-workflow-automation.py https://raw.githubusercontent.com/your-repo/examples/scripts/git-workflow-automation.py
   chmod +x git-workflow-automation.py
   
   # Run health check
   python3 git-workflow-automation.py --repository devops-demo-app health
   ```

2. **Clean up merged branches:**
   ```bash
   # Check what would be cleaned (dry run)
   python3 git-workflow-automation.py cleanup --dry-run
   
   # Actually clean up merged branches
   python3 git-workflow-automation.py cleanup --no-dry-run
   ```

3. **Create repository documentation:**
   ```bash
   mkdir -p docs
   cat > docs/CONTRIBUTING.md << 'EOF'
   # Contributing to DevOps Demo Application
   
   Thank you for your interest in contributing! This document provides guidelines and best practices.
   
   ## Branching Strategy
   
   We follow Git Flow:
   - `main`: Production releases
   - `develop`: Integration branch  
   - `feature/*`: New features
   - `hotfix/*`: Production fixes
   - `release/*`: Release preparation
   
   ## Pull Request Process
   
   1. Create feature branch from `develop`
   2. Make your changes with tests
   3. Push branch and create PR
   4. Request review from team members
   5. Address feedback and update PR
   6. Merge after approval
   
   ## Code Standards
   
   - Follow language-specific style guides
   - Include unit tests for new code
   - Update documentation as needed
   - Use descriptive commit messages
   - Keep PRs focused and small
   
   ## Testing Requirements
   
   - All tests must pass
   - New features require tests
   - Aim for >80% code coverage
   - Integration tests for API changes
   
   ## Documentation
   
   - Update README for user-facing changes
   - Include inline code comments
   - Document API changes
   - Update architecture diagrams if needed
   EOF
   
   git add docs/CONTRIBUTING.md
   git commit -m "docs: add contributing guidelines and best practices"
   git push origin main
   ```

**✅ Final Checkpoint:** You have completed the lab with a fully configured CodeCommit repository including branching strategy, access controls, monitoring, and documentation.

---

## Lab Verification and Testing

### Verification Checklist

- [ ] CodeCommit repository created and accessible
- [ ] IAM policies and roles properly configured
- [ ] Git Flow branching strategy implemented
- [ ] Pull requests working with approval rules
- [ ] Notifications configured and tested
- [ ] Repository health checks passing
- [ ] Documentation complete and accessible

### Test Your Setup

1. **Clone repository as a new user:**
   ```bash
   # Test with different AWS profile if available
   git clone https://git-codecommit.us-west-2.amazonaws.com/v1/repos/devops-demo-app test-clone
   ```

2. **Create and test a new feature:**
   ```bash
   cd test-clone
   git checkout develop
   git checkout -b feature/test-workflow
   echo "Test change" > test-file.txt
   git add test-file.txt
   git commit -m "feat: test workflow implementation"
   git push -u origin feature/test-workflow
   ```

3. **Verify notifications:**
   - Check your email for SNS notifications
   - Verify CloudWatch logs are being created
   - Test pull request notifications

---

## Troubleshooting

### Common Issues

1. **Git authentication fails:**
   ```bash
   # Reconfigure credential helper
   git config --global credential.helper '!aws codecommit credential-helper $@'
   git config --global credential.UseHttpPath true
   
   # Test AWS CLI access
   aws codecommit list-repositories
   ```

2. **IAM permission denied:**
   ```bash
   # Check current user permissions
   aws sts get-caller-identity
   
   # Test specific CodeCommit permissions
   aws codecommit get-repository --repository-name devops-demo-app
   ```

3. **Pull request creation fails:**
   ```bash
   # Check branch exists on remote
   git ls-remote origin
   
   # Verify approval rules
   aws codecommit list-approval-rule-templates
   ```

### Clean Up Resources

After completing the lab, clean up resources to avoid charges:

```bash
# Delete repository
aws codecommit delete-repository --repository-name devops-demo-app

# Delete IAM resources
aws iam detach-role-policy --role-name DevOpsDemoApp-Developer-Role --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/DevOpsDemoApp-Developer-Policy
aws iam delete-role --role-name DevOpsDemoApp-Developer-Role
aws iam delete-policy --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/DevOpsDemoApp-Developer-Policy
aws iam delete-policy --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/DevOpsDemoApp-CICD-Policy

# Delete CloudWatch resources
aws logs delete-log-group --log-group-name "/aws/codecommit/devops-demo-app"

# Delete SNS topic
aws sns delete-topic --topic-arn arn:aws:sns:us-west-2:$ACCOUNT_ID:devops-demo-app-notifications
```

---

## Key Takeaways

1. **Repository Structure**: A well-organized repository structure supports maintainability and collaboration
2. **Access Control**: Proper IAM policies ensure security while enabling productivity
3. **Branching Strategy**: Git Flow provides a robust framework for team collaboration
4. **Automation**: Automated notifications and monitoring improve visibility and response times
5. **Documentation**: Clear documentation and contributing guidelines support team onboarding

## Next Steps

- Proceed to Topic 2: AWS CodeCommit for advanced repository features
- Explore integration with AWS CodeBuild for automated testing
- Set up AWS CodePipeline to orchestrate the complete CI/CD workflow