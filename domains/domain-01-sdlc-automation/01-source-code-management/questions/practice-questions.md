# Source Code Management - Practice Questions

## Instructions
This question bank covers source code management concepts for the AWS DevOps Engineer Professional certification. Questions are organized by difficulty level and include detailed explanations.

**Time Allocation**: 2 minutes per question
**Passing Score**: 70% or higher

---

## Basic Level Questions (1-10)

### Question 1
Which branching strategy is MOST appropriate for a small development team (3-5 developers) practicing continuous deployment?

A) Git Flow with feature, develop, and main branches
B) GitHub Flow with feature branches and main branch only
C) GitLab Flow with environment-specific branches
D) Centralized workflow with only main branch

**Correct Answer: B**

**Explanation:**
GitHub Flow is ideal for small teams practicing continuous deployment because:
- Simple workflow with only feature branches and main
- Supports continuous deployment with direct merges to main
- Less overhead than Git Flow for small teams
- Enables quick releases and hotfixes

**Reference:** AWS DevOps Best Practices - Source Control Strategies

---

### Question 2
What is the PRIMARY benefit of using AWS CodeCommit over self-managed Git repositories?

A) Lower cost for storage
B) Native integration with AWS services
C) Better performance for large repositories
D) Support for more file formats

**Correct Answer: B**

**Explanation:**
AWS CodeCommit's primary advantage is native integration with AWS services:
- Seamless integration with CodeBuild, CodeDeploy, and CodePipeline
- Built-in IAM authentication and authorization
- Automatic encryption at rest and in transit
- Event-driven triggers for AWS services

**Reference:** AWS CodeCommit User Guide - Benefits

---

### Question 3
Which IAM policy action is required for developers to clone and pull from a CodeCommit repository?

A) codecommit:GitPush
B) codecommit:GitPull
C) codecommit:BatchGetRepositories
D) codecommit:CreateRepository

**Correct Answer: B**

**Explanation:**
The codecommit:GitPull action is specifically required for:
- Cloning repositories
- Pulling changes from remote
- Fetching repository data
This is separate from push permissions and repository management actions.

**Reference:** AWS CodeCommit User Guide - IAM Policies

---

### Question 4
In a Git Flow branching strategy, where should hotfixes be created from?

A) develop branch
B) feature branch
C) main/master branch
D) release branch

**Correct Answer: C**

**Explanation:**
Hotfixes in Git Flow are created from the main/master branch because:
- They address critical production issues
- Need to be based on current production code
- Must be merged back to both main and develop branches
- Cannot wait for the regular release cycle

**Reference:** Git Flow Documentation - Hotfix Branches

---

### Question 5
What is the BEST practice for commit message format in a DevOps environment?

A) Single line with timestamp
B) Conventional Commits format with type and description
C) Detailed paragraph describing all changes
D) Ticket number only

**Correct Answer: B**

**Explanation:**
Conventional Commits format provides:
- Structured format: `type(scope): description`
- Automation-friendly for changelog generation
- Clear categorization (feat, fix, docs, etc.)
- Consistent team communication
- Integration with CI/CD tools

**Reference:** Conventional Commits Specification

---

### Question 6
Which CodeCommit feature helps prevent direct pushes to protected branches?

A) Repository triggers
B) Approval rule templates
C) Branch policies
D) Pull request templates

**Correct Answer: B**

**Explanation:**
Approval rule templates in CodeCommit:
- Require pull requests for protected branches
- Enforce minimum number of approvers
- Can specify required approvers by role
- Prevent direct pushes to protected branches like main

**Reference:** AWS CodeCommit User Guide - Approval Rules

---

### Question 7
What should be included in a comprehensive .gitignore file for an AWS project?

A) Only compiled binaries
B) IDE files, credentials, environment variables, and build outputs
C) Documentation files
D) Source code files

**Correct Answer: B**

**Explanation:**
A comprehensive .gitignore for AWS projects should exclude:
- AWS credentials (.aws/, *.pem, *.key)
- Environment variables (.env files)
- IDE-specific files (.vscode/, .idea/)
- Build outputs (dist/, target/, build/)
- OS files (.DS_Store, Thumbs.db)
- Dependencies (node_modules/, __pycache__)

**Reference:** Git Documentation - gitignore

---

### Question 8
Which Git command is used to configure CodeCommit credential helper?

A) `git config credential.codecommit true`
B) `git config credential.helper '!aws codecommit credential-helper $@'`
C) `git config aws.codecommit.helper true`
D) `git config --global codecommit.credentials aws`

**Correct Answer: B**

**Explanation:**
The correct credential helper configuration for CodeCommit is:
```
git config --global credential.helper '!aws codecommit credential-helper $@'
git config --global credential.UseHttpPath true
```
This integrates Git with AWS CLI credentials for seamless authentication.

**Reference:** AWS CodeCommit User Guide - Setup

---

### Question 9
What is the purpose of semantic versioning in source code management?

A) To encrypt version numbers
B) To provide meaningful version numbers with backward compatibility information
C) To reduce repository size
D) To improve Git performance

**Correct Answer: B**

**Explanation:**
Semantic versioning (SemVer) uses MAJOR.MINOR.PATCH format where:
- MAJOR: Breaking changes
- MINOR: New features (backward compatible)
- PATCH: Bug fixes (backward compatible)
This provides clear communication about compatibility and change impact.

**Reference:** Semantic Versioning Specification

---

### Question 10
Which approach is BEST for handling secrets in a Git repository?

A) Store them in a separate secrets.txt file
B) Use environment variables and exclude credential files from Git
C) Encrypt them within the repository
D) Store them in commit messages

**Correct Answer: B**

**Explanation:**
Best practices for secrets management:
- Use environment variables for runtime secrets
- Store in AWS Systems Manager Parameter Store or Secrets Manager
- Exclude credential files in .gitignore
- Use pre-commit hooks to detect secrets
- Never commit secrets to version control

**Reference:** AWS Security Best Practices

---

## Intermediate Level Questions (11-20)

### Question 11
A development team uses feature branches and wants to ensure all commits on the main branch maintain a linear history. Which merge strategy should they use?

A) Merge commits with --no-ff
B) Squash and merge
C) Rebase and merge
D) Fast-forward merge only

**Correct Answer: C**

**Explanation:**
Rebase and merge strategy:
- Maintains linear history on main branch
- Replays feature commits on top of main
- Avoids merge commit clutter
- Preserves individual commits with clean history
- Ideal for teams wanting linear progression

**Reference:** Git Documentation - Merging vs Rebasing

---

### Question 12
A company needs to implement branch protection that requires at least 2 approvals from senior developers and prevents administrators from bypassing the rule. How should this be configured in CodeCommit?

A) Create a simple approval rule requiring 2 approvals
B) Create an approval rule template with specific approval pool members and no override permissions
C) Use IAM policies to restrict branch access
D) Configure repository-level permissions

**Correct Answer: B**

**Explanation:**
Approval rule templates with specific requirements:
- Define approval pool members (senior developers)
- Set NumberOfApprovalsNeeded to 2
- Apply to specific destination references (main branch)
- Override permissions can be controlled separately
- Templates can be applied across multiple repositories

**Reference:** AWS CodeCommit User Guide - Approval Rule Templates

---

### Question 13
A DevOps engineer needs to automate the creation of release branches when a version tag is pushed. Which AWS services combination would be MOST effective?

A) CloudWatch Events + Lambda + CodeCommit APIs
B) CodePipeline + CodeBuild + CloudFormation
C) EventBridge + Step Functions + CodeCommit APIs
D) SNS + SQS + Lambda

**Correct Answer: A**

**Explanation:**
CloudWatch Events (now EventBridge) + Lambda + CodeCommit APIs provides:
- Event-driven trigger on tag creation
- Lambda function to process the event
- CodeCommit APIs to create branches programmatically
- Simple and cost-effective solution
- Real-time response to repository events

**Reference:** AWS CodeCommit User Guide - Monitoring

---

### Question 14
When implementing Git Flow, a release branch needs to be merged to both main and develop branches. What is the correct sequence of operations?

A) Merge to develop first, then to main
B) Merge to main first, then to develop  
C) Create separate PRs for both branches simultaneously
D) Merge to main, then merge main to develop

**Correct Answer: B**

**Explanation:**
Correct Git Flow release sequence:
1. Merge release branch to main (production deployment)
2. Tag the main branch with version number
3. Merge release branch back to develop (include any release fixes)
4. Delete the release branch
This ensures production changes are captured in develop branch.

**Reference:** Git Flow Workflow Documentation

---

### Question 15
A team wants to implement automated code quality gates that run on every pull request. Which combination provides the MOST comprehensive solution?

A) CodeCommit triggers + CodeBuild + SonarQube
B) GitHub Actions + CodeGuru Reviewer + CodeCommit
C) CodeCommit triggers + Lambda + CloudWatch
D) Pull request templates + manual review only

**Correct Answer: A**

**Explanation:**
CodeCommit triggers + CodeBuild + SonarQube provides:
- Automated triggering on pull request events
- CodeBuild for running tests and analysis
- SonarQube for comprehensive code quality metrics
- Integration with pull request status checks
- Configurable quality gates and thresholds

**Reference:** AWS CodeBuild User Guide - Source Providers

---

### Question 16
A company has multiple development teams working on microservices. Each team needs isolated access to their repositories while sharing common libraries. What is the BEST repository organization strategy?

A) Single monorepo with folder-based team separation
B) Individual repositories per microservice with shared library repositories
C) Team-based repositories with all microservices per team
D) Environment-based repositories (dev, staging, prod)

**Correct Answer: B**

**Explanation:**
Individual repositories per microservice with shared libraries:
- Provides clear ownership boundaries
- Enables independent deployment and versioning
- Supports different access controls per service
- Shared libraries can be managed as separate repositories
- Scales well with team growth and service evolution

**Reference:** AWS Well-Architected Framework - Microservices

---

### Question 17
An organization needs to implement compliance auditing for all source code changes. Which combination of AWS services provides the MOST comprehensive audit trail?

A) CodeCommit + CloudTrail + CloudWatch Logs
B) CodeCommit + Config + GuardDuty
C) CodeCommit + Inspector + Systems Manager
D) CodeCommit + Macie + Security Hub

**Correct Answer: A**

**Explanation:**
CodeCommit + CloudTrail + CloudWatch Logs provides:
- CloudTrail logs all API calls to CodeCommit
- Detailed audit trail of who made what changes when
- CloudWatch Logs for centralized log management
- Integration with compliance monitoring tools
- Historical data retention for audit requirements

**Reference:** AWS CloudTrail User Guide - CodeCommit

---

### Question 18
A development team needs to implement feature flags in their branching strategy to support gradual feature rollouts. Which approach is MOST effective?

A) Create separate branches for each feature flag
B) Use feature branches with configuration-driven flags
C) Implement feature flags in main branch with runtime configuration
D) Use release branches with selective feature inclusion

**Correct Answer: C**

**Explanation:**
Feature flags in main branch with runtime configuration:
- Separates deployment from feature release
- Enables gradual rollouts and A/B testing
- Reduces branch complexity and merge conflicts
- Supports quick feature toggles in production
- Integrates well with continuous deployment

**Reference:** Feature Flag Best Practices

---

### Question 19
A company wants to implement cross-account repository access for their CI/CD pipeline. What is the MOST secure approach?

A) Share AWS credentials across accounts
B) Use cross-account IAM roles with temporary credentials
C) Create duplicate repositories in each account
D) Use public repositories for cross-account access

**Correct Answer: B**

**Explanation:**
Cross-account IAM roles provide:
- Temporary credentials with limited scope
- No long-term credential sharing
- Fine-grained permission control
- Audit trail of cross-account access
- Follows AWS security best practices

**Reference:** AWS IAM User Guide - Cross-Account Access

---

### Question 20
When implementing repository monitoring, which metrics are MOST important for identifying potential issues?

A) Repository size and file count only
B) Commit frequency, pull request cycle time, and branch age
C) User count and login frequency
D) Network bandwidth and storage usage

**Correct Answer: B**

**Explanation:**
Key repository health metrics:
- Commit frequency indicates development activity
- Pull request cycle time shows process efficiency
- Branch age identifies stale or abandoned work
- These metrics help identify workflow bottlenecks
- Enable proactive team management decisions

**Reference:** DevOps Metrics Best Practices

---

## Advanced Level Questions (21-30)

### Question 21
A large enterprise has 50+ microservices with complex dependencies. They need a branching strategy that supports independent service deployments while maintaining system integration testing. Which approach is MOST suitable?

A) Trunk-based development with feature flags and comprehensive CI/CD
B) Git Flow with synchronized release branches across all services
C) Service-specific feature branches with integration branches
D) Monorepo with module-based development branches

**Correct Answer: A**

**Explanation:**
Trunk-based development for microservices:
- Short-lived branches minimize integration complexity
- Feature flags enable independent deployments
- Comprehensive CI/CD ensures quality gates
- Supports service autonomy while maintaining system integrity
- Reduces merge conflicts across service boundaries

**Reference:** Accelerate - State of DevOps Research

---

### Question 22
A company needs to implement automatic security scanning for all code changes while maintaining developer productivity. Pull requests should be blocked if critical vulnerabilities are found. Which implementation is MOST effective?

A) Manual security reviews for all pull requests
B) CodeCommit triggers + CodeBuild with SAST/DAST tools + pull request status checks
C) Periodic security scans on release branches only
D) Security scanning in production environment post-deployment

**Correct Answer: B**

**Explanation:**
Automated security scanning with blocking:
- CodeCommit triggers enable automatic scanning on PR events
- CodeBuild runs SAST (Static Analysis) and DAST (Dynamic Analysis) tools
- Pull request status checks prevent merge if vulnerabilities found
- Maintains developer velocity while ensuring security
- Provides early feedback in development cycle

**Reference:** AWS DevSecOps Best Practices

---

### Question 23
An organization has regulatory requirements to maintain an immutable audit trail of all code changes including author identity verification. Which combination BEST meets these requirements?

A) CodeCommit + CloudTrail + signed commits + branch protection
B) CodeCommit + Config + CloudWatch + backup policies
C) Git with PGP signatures + external audit system
D) CodeCommit + GuardDuty + Security Hub

**Correct Answer: A**

**Explanation:**
Immutable audit trail requirements:
- CloudTrail provides immutable API call logs
- Signed commits ensure author identity verification
- Branch protection prevents history rewriting
- CodeCommit integrates with AWS compliance services
- Meets regulatory requirements for financial/healthcare sectors

**Reference:** AWS Compliance and Regulatory Requirements

---

### Question 24
A DevOps team needs to implement automated dependency updates across multiple repositories while ensuring system stability. Which strategy provides the BEST balance of automation and safety?

A) Automatic updates to all dependencies daily
B) Staged dependency updates with automated testing and gradual rollout
C) Manual dependency updates quarterly
D) Dependency updates only during major releases

**Correct Answer: B**

**Explanation:**
Staged dependency updates strategy:
- Automated testing validates updates before deployment
- Gradual rollout enables quick rollback if issues arise
- Balances security updates with system stability
- Reduces manual effort while maintaining control
- Supports both security patches and feature updates

**Reference:** Dependency Management Best Practices

---

### Question 25
A company with global development teams needs to optimize their Git workflow for distributed collaboration across time zones. Which approach addresses latency and collaboration challenges MOST effectively?

A) Single central repository with strict working hours
B) Regional repository mirrors with periodic synchronization
C) Distributed Git workflow with decentralized collaboration
D) Multiple CodeCommit repositories in different regions with cross-region replication

**Correct Answer: D**

**Explanation:**
Multi-region CodeCommit with replication:
- Reduces latency for global teams
- AWS managed cross-region replication ensures consistency
- Maintains single source of truth across regions
- Integrates with regional CI/CD pipelines
- Provides disaster recovery capabilities

**Reference:** AWS Multi-Region Architecture Best Practices

---

### Question 26
A development team needs to implement sophisticated merge conflict resolution for a high-velocity codebase with frequent conflicts. Which approach provides the MOST effective conflict prevention and resolution?

A) Rebase-heavy workflow with conflict resolution training
B) Small, frequent commits with automated merge tools and semantic merge strategies
C) Feature branches with delayed integration
D) Manual conflict resolution with senior developer approval

**Correct Answer: B**

**Explanation:**
Effective conflict prevention strategy:
- Small, frequent commits reduce conflict complexity
- Automated merge tools handle simple conflicts
- Semantic merge strategies understand code structure
- Reduces manual intervention and developer overhead
- Maintains high development velocity

**Reference:** Git Merge Strategies and Best Practices

---

### Question 27
An organization needs to implement policy-as-code for repository governance, ensuring consistent configuration across hundreds of repositories. Which approach is MOST scalable and maintainable?

A) Manual configuration with documentation
B) CloudFormation templates with approval rule templates and IAM automation
C) Individual repository configuration with team responsibility
D) Custom scripts run by administrators

**Correct Answer: B**

**Explanation:**
Policy-as-code with CloudFormation:
- Approval rule templates ensure consistent governance
- IAM automation provides standardized access control
- Version-controlled infrastructure enables change tracking
- Scales across hundreds of repositories
- Supports compliance and audit requirements

**Reference:** AWS CloudFormation Best Practices

---

### Question 28
A company needs to implement advanced code analytics to identify technical debt and improve code quality across multiple programming languages. Which combination provides the MOST comprehensive solution?

A) SonarQube + CodeGuru + custom metrics in CloudWatch
B) Basic linting tools + manual code reviews
C) GitHub Advanced Security + Dependabot
D) CodeCommit insights + pull request analytics

**Correct Answer: A**

**Explanation:**
Comprehensive code analytics solution:
- SonarQube provides multi-language quality analysis
- CodeGuru offers AI-powered code reviews and performance insights
- Custom CloudWatch metrics track quality trends
- Supports technical debt identification and remediation
- Integrates with development workflow

**Reference:** AWS CodeGuru User Guide

---

### Question 29
A financial services company needs to implement zero-trust security principles in their source code management. Which architectural approach BEST implements zero-trust for code repositories?

A) VPC isolation + IAM roles + encryption at rest
B) Multi-factor authentication + network ACLs + audit logging
C) Identity-based access + least privilege + continuous verification + encrypted communication
D) Private subnets + security groups + CloudTrail logging

**Correct Answer: C**

**Explanation:**
Zero-trust security principles:
- Identity-based access (no implicit trust)
- Least privilege access controls
- Continuous verification of access requests
- End-to-end encrypted communication
- Comprehensive monitoring and analytics

**Reference:** Zero Trust Architecture - NIST Framework

---

### Question 30
A company implementing DevOps transformation needs to measure the effectiveness of their source code management practices. Which metrics combination provides the MOST meaningful insights into team productivity and code quality?

A) Lines of code and commit count only
B) Lead time, deployment frequency, mean time to recovery, and change failure rate (DORA metrics)
C) Repository size and user count
D) Pull request count and merge frequency

**Correct Answer: B**

**Explanation:**
DORA (DevOps Research and Assessment) metrics:
- Lead time: Time from commit to production
- Deployment frequency: How often deployments occur
- Mean time to recovery: Recovery time from failures
- Change failure rate: Percentage of changes causing failures
These metrics correlate with organizational performance and business outcomes.

**Reference:** State of DevOps Report - DORA Metrics

---

## Answer Key Summary

### Basic Level (70% to pass)
1. B - GitHub Flow for small teams
2. B - Native AWS integration
3. B - codecommit:GitPull for cloning
4. C - Hotfixes from main branch
5. B - Conventional Commits format
6. B - Approval rule templates
7. B - Comprehensive .gitignore
8. B - Credential helper configuration
9. B - Semantic versioning meaning
10. B - Environment variables for secrets

### Intermediate Level (75% to pass)
11. C - Rebase and merge strategy
12. B - Approval rule templates with specific pools
13. A - CloudWatch Events + Lambda
14. B - Merge to main first, then develop
15. A - CodeCommit + CodeBuild + SonarQube
16. B - Individual microservice repositories
17. A - CodeCommit + CloudTrail + Logs
18. C - Feature flags in main branch
19. B - Cross-account IAM roles
20. B - Key repository health metrics

### Advanced Level (80% to pass)
21. A - Trunk-based development
22. B - Automated security scanning pipeline
23. A - Immutable audit trail components
24. B - Staged dependency updates
25. D - Multi-region CodeCommit
26. B - Small commits + automated tools
27. B - CloudFormation policy-as-code
28. A - Comprehensive analytics solution
29. C - Zero-trust principles
30. B - DORA metrics

---

## Study Tips

1. **Focus on Integration**: Understanding how CodeCommit integrates with other AWS services
2. **Security Best Practices**: Know IAM policies, secrets management, and compliance requirements
3. **Workflow Patterns**: Understand different branching strategies and when to use each
4. **Automation**: Learn about event-driven automation and CI/CD integration
5. **Monitoring and Metrics**: Understand how to measure and improve development practices

## Additional Resources

- [AWS CodeCommit User Guide](https://docs.aws.amazon.com/codecommit/)
- [Git Flow Documentation](https://nvie.com/posts/a-successful-git-branching-model/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [DORA Metrics](https://cloud.google.com/blog/products/devops-sre/using-the-four-keys-to-measure-your-devops-performance)
- [AWS Well-Architected DevOps Guidance](https://docs.aws.amazon.com/wellarchitected/latest/devops-guidance/)

---

**Note**: Practice with real AWS environments to reinforce theoretical knowledge. Hands-on experience with CodeCommit, IAM policies, and Git workflows is essential for exam success.