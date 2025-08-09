# AWS CodeCommit - Practice Questions

This collection contains **35 practice questions** designed to test your understanding of AWS CodeCommit concepts, features, and integration patterns. Questions are categorized by difficulty and topic area.

## Question Categories

- **Foundational** (Questions 1-10): Basic concepts and features
- **Intermediate** (Questions 11-25): Advanced configuration and integration
- **Advanced** (Questions 26-35): Complex scenarios and troubleshooting

---

## Foundational Questions (1-10)

### Question 1
What are the key differences between AWS CodeCommit and other Git hosting services like GitHub?

**A)** CodeCommit supports only SSH authentication while GitHub supports HTTPS  
**B)** CodeCommit integrates natively with AWS services and uses IAM for access control  
**C)** CodeCommit only supports private repositories  
**D)** CodeCommit has unlimited repository size while GitHub has limitations  

<details>
<summary>Click to reveal answer</summary>

**Answer: B**

CodeCommit's primary differentiators are its native AWS integration and IAM-based access control. While CodeCommit does focus on private repositories, this isn't the key difference. Both services support multiple authentication methods, and both have size limitations.
</details>

---

### Question 2
Which authentication methods are supported for accessing CodeCommit repositories?

**A)** SSH keys only  
**B)** HTTPS with Git credentials only  
**C)** IAM users/roles, SSH keys, and Git credentials  
**D)** OAuth and personal access tokens only  

<details>
<summary>Click to reveal answer</summary>

**Answer: C**

CodeCommit supports multiple authentication methods: IAM users and roles (using AWS credential helper), SSH keys associated with IAM users, and Git credentials (username/password generated for IAM users).
</details>

---

### Question 3
What is the maximum file size limit for a single file in a CodeCommit repository?

**A)** 100 MB  
**B)** 2 GB  
**C)** 1 GB  
**D)** 500 MB  

<details>
<summary>Click to reveal answer</summary>

**Answer: B**

CodeCommit supports files up to 2 GB in size. However, Git performance can degrade with very large files, so it's recommended to use Git LFS for large binary files.
</details>

---

### Question 4
Which AWS service should you use to encrypt CodeCommit repositories at rest?

**A)** AWS CloudHSM  
**B)** AWS Key Management Service (KMS)  
**C)** AWS Certificate Manager  
**D)** AWS Secrets Manager  

<details>
<summary>Click to reveal answer</summary>

**Answer: B**

AWS KMS is used to encrypt CodeCommit repositories at rest. You can use either AWS managed keys or customer managed keys for encryption.
</details>

---

### Question 5
What happens when you delete a CodeCommit repository?

**A)** The repository is moved to a recycle bin for 30 days  
**B)** The repository is immediately deleted and cannot be recovered  
**C)** The repository is archived and can be restored within 7 days  
**D)** Only the repository metadata is deleted, content remains  

<details>
<summary>Click to reveal answer</summary>

**Answer: B**

When you delete a CodeCommit repository, it is permanently deleted immediately and cannot be recovered. There is no recycle bin or archive feature. Always ensure you have proper backups before deletion.
</details>

---

### Question 6
Which of the following is NOT a valid CodeCommit repository trigger event?

**A)** createReference  
**B)** deleteReference  
**C)** updateReference  
**D)** modifyFile  

<details>
<summary>Click to reveal answer</summary>

**Answer: D**

CodeCommit triggers support createReference, deleteReference, and updateReference events. There is no "modifyFile" event - file modifications are captured through reference updates (commits).
</details>

---

### Question 7
What is the recommended way to handle large binary files in CodeCommit?

**A)** Store them directly in the repository  
**B)** Use Git LFS (Large File Storage)  
**C)** Compress them before committing  
**D)** Store them in S3 and reference them in code  

<details>
<summary>Click to reveal answer</summary>

**Answer: B**

Git LFS is the recommended approach for handling large binary files in Git repositories, including CodeCommit. This keeps the repository clone size manageable while still version controlling the large files.
</details>

---

### Question 8
In which AWS regions is CodeCommit available?

**A)** Only in US East (N. Virginia) and US West (Oregon)  
**B)** In all AWS regions globally  
**C)** In most AWS regions where other developer tools are available  
**D)** Only in regions that support AWS GovCloud  

<details>
<summary>Click to reveal answer</summary>

**Answer: C**

CodeCommit is available in most AWS regions where other developer tools and services are available, but not in all regions globally. Always check the current AWS documentation for the most up-to-date list of supported regions.
</details>

---

### Question 9
What is the primary purpose of approval rules in CodeCommit?

**A)** To automatically merge pull requests  
**B)** To enforce code review requirements before merging  
**C)** To validate code syntax and style  
**D)** To schedule pull request deployments  

<details>
<summary>Click to reveal answer</summary>

**Answer: B**

Approval rules are used to enforce code review requirements by specifying how many approvals are needed and who can provide them before a pull request can be merged.
</details>

---

### Question 10
Which service integrates with CodeCommit to provide automated code reviews?

**A)** AWS CodeGuru Reviewer  
**B)** AWS Inspector  
**C)** AWS Config  
**D)** AWS CloudFormation  

<details>
<summary>Click to reveal answer</summary>

**Answer: A**

AWS CodeGuru Reviewer integrates with CodeCommit to provide AI-powered automated code reviews, identifying issues and suggesting improvements.
</details>

---

## Intermediate Questions (11-25)

### Question 11
Your organization needs to enforce that all commits to the main branch of a production repository require approval from at least 2 senior developers. How would you implement this?

**A)** Create an IAM policy that restricts push access to the main branch  
**B)** Use CodeCommit approval rules with an approval rule template  
**C)** Implement a Lambda function that validates commits  
**D)** Use branch protection rules in the repository settings  

<details>
<summary>Click to reveal answer</summary>

**Answer: B**

CodeCommit approval rules and approval rule templates are specifically designed for this use case. You can create an approval rule template that requires 2 approvals from specific IAM users/roles and associate it with the repository.
</details>

---

### Question 12
You want to automatically trigger a CodeBuild project when code is pushed to the 'develop' branch of your CodeCommit repository. What's the most efficient approach?

**A)** Create a CodeCommit trigger that calls a Lambda function to start CodeBuild  
**B)** Use CloudWatch Events (EventBridge) to monitor CodeCommit and trigger CodeBuild  
**C)** Configure CodePipeline with CodeCommit as the source  
**D)** Set up a scheduled Lambda function to check for new commits  

<details>
<summary>Click to reveal answer</summary>

**Answer: B**

EventBridge (CloudWatch Events) can directly monitor CodeCommit repository state changes and trigger CodeBuild projects without requiring intermediate Lambda functions or complex pipeline setups for simple build triggers.
</details>

---

### Question 13
Your team needs to access a CodeCommit repository from an on-premises environment through a VPN connection. What should you configure?

**A)** VPC endpoint for CodeCommit  
**B)** NAT Gateway for internet access  
**C)** Direct Connect gateway  
**D)** AWS PrivateLink for Git operations  

<details>
<summary>Click to reveal answer</summary>

**Answer: A**

A VPC endpoint for CodeCommit allows private access to the service without routing traffic over the internet, which is ideal for on-premises environments connected via VPN.
</details>

---

### Question 14
You're implementing a multi-account strategy where developers in Account A need read-only access to repositories in Account B. What's the recommended approach?

**A)** Share IAM credentials between accounts  
**B)** Create cross-account IAM roles and assume them for access  
**C)** Use CodeCommit resource-based policies  
**D)** Create identical repositories in both accounts  

<details>
<summary>Click to reveal answer</summary>

**Answer: B**

Cross-account access in AWS is best implemented using cross-account IAM roles. Users in Account A can assume roles in Account B that grant the necessary CodeCommit permissions.
</details>

---

### Question 15
Which CloudWatch metric is NOT available for CodeCommit repositories?

**A)** NumberOfRepositories  
**B)** RepositorySize  
**C)** NumberOfCommits  
**D)** NumberOfPullRequests  

<details>
<summary>Click to reveal answer</summary>

**Answer: C**

CloudWatch provides metrics for NumberOfRepositories, RepositorySize, and NumberOfPullRequests, but not NumberOfCommits. You would need to implement custom metrics for commit counting.
</details>

---

### Question 16
Your organization requires all repository access to be logged for compliance. Which service should you configure?

**A)** CloudWatch Logs  
**B)** AWS CloudTrail  
**C)** AWS Config  
**D)** AWS X-Ray  

<details>
<summary>Click to reveal answer</summary>

**Answer: B**

AWS CloudTrail logs all API calls to CodeCommit, providing a complete audit trail of repository access and operations for compliance purposes.
</details>

---

### Question 17
You need to migrate 500 repositories from GitHub Enterprise to CodeCommit while preserving commit history. What's the recommended approach?

**A)** Use git clone --bare and push to CodeCommit  
**B)** Use AWS Database Migration Service  
**C)** Use CodeCommit's built-in migration tool  
**D)** Export and import using CSV files  

<details>
<summary>Click to reveal answer</summary>

**Answer: A**

The recommended approach is to use `git clone --bare` to create a bare clone that preserves all history, branches, and tags, then push to the new CodeCommit repository. This preserves complete Git history.
</details>

---

### Question 18
What's the maximum number of approval rules you can associate with a single CodeCommit repository?

**A)** 10  
**B)** 25  
**C)** 50  
**D)** 100  

<details>
<summary>Click to reveal answer</summary>

**Answer: B**

You can associate up to 25 approval rule templates with a single CodeCommit repository. This allows for complex approval workflows with different rules for different scenarios.
</details>

---

### Question 19
Your Lambda function needs to access multiple CodeCommit repositories. What's the minimum IAM permission required?

**A)** codecommit:*  
**B)** codecommit:GitPull  
**C)** codecommit:BatchGetRepositories and codecommit:GitPull  
**D)** codecommit:ListRepositories and codecommit:GetRepository  

<details>
<summary>Click to reveal answer</summary>

**Answer: C**

For Lambda to access repository content, it needs both BatchGetRepositories (to get repository metadata) and GitPull (to access the actual repository content). ListRepositories and GetRepository alone don't provide content access.
</details>

---

### Question 20
You want to automatically backup CodeCommit repositories to S3 daily. What's the most cost-effective approach?

**A)** Use AWS Backup service  
**B)** Create a scheduled Lambda function that clones repositories and uploads to S3  
**C)** Use CodeCommit's built-in backup feature  
**D)** Use AWS DataSync to sync repositories to S3  

<details>
<summary>Click to reveal answer</summary>

**Answer: B**

A scheduled Lambda function that performs git operations to clone repositories and upload them to S3 is the most cost-effective approach. CodeCommit doesn't have built-in backup features, and AWS Backup doesn't support CodeCommit.
</details>

---

### Question 21
Which CodeCommit event will NOT trigger a repository trigger?

**A)** Pushing commits to a branch  
**B)** Creating a new branch  
**C)** Deleting a branch  
**D)** Creating a pull request  

<details>
<summary>Click to reveal answer</summary>

**Answer: D**

Repository triggers are based on reference changes (createReference, updateReference, deleteReference). Pull request creation is a separate event that can trigger Lambda functions directly but not through repository triggers.
</details>

---

### Question 22
Your team uses feature branch workflows and wants to automatically delete merged branches. How would you implement this?

**A)** Configure repository settings to auto-delete merged branches  
**B)** Use a Lambda function triggered by pull request merge events  
**C)** Use CodeCommit's branch lifecycle management  
**D)** Configure Git hooks on the repository  

<details>
<summary>Click to reveal answer</summary>

**Answer: B**

You can create a Lambda function that responds to pull request events (via EventBridge) and automatically deletes the source branch after successful merges. CodeCommit doesn't have built-in branch lifecycle management.
</details>

---

### Question 23
What's the recommended way to handle secrets (API keys, passwords) in CodeCommit repositories?

**A)** Store them in encrypted files within the repository  
**B)** Use AWS Secrets Manager and reference them in code  
**C)** Store them in environment variables in the Lambda function  
**D)** Use KMS to encrypt the secrets in the repository  

<details>
<summary>Click to reveal answer</summary>

**Answer: B**

AWS Secrets Manager is the recommended service for storing and managing secrets. Applications should reference secrets from Secrets Manager rather than storing them in source code, even if encrypted.
</details>

---

### Question 24
You need to implement automatic code quality checks that block pull requests if quality gates fail. Which combination of services would you use?

**A)** CodeCommit + CodeGuru Reviewer + Lambda  
**B)** CodeCommit + CodeBuild + approval rules  
**C)** CodeCommit + CodePipeline + CodeDeploy  
**D)** CodeCommit + SonarQube + SNS  

<details>
<summary>Click to reveal answer</summary>

**Answer: B**

CodeBuild can run quality checks and tests, and approval rules can be configured to require successful builds before allowing merges. This combination provides automated quality gates within AWS services.
</details>

---

### Question 25
Your organization has repositories in multiple AWS regions and needs a centralized view of all repository activity. What's the best approach?

**A)** Use CloudWatch dashboards in each region  
**B)** Use AWS Organizations to centralize logging  
**C)** Configure CloudTrail with a central S3 bucket and use AWS Config  
**D)** Use Amazon QuickSight to analyze multi-region data  

<details>
<summary>Click to reveal answer</summary>

**Answer: C**

CloudTrail can be configured to send logs from all regions to a central S3 bucket, and AWS Config can provide compliance and configuration monitoring across regions. This gives you centralized visibility into all CodeCommit activity.
</details>

---

## Advanced Questions (26-35)

### Question 26
You're designing a CI/CD pipeline for a microservices architecture with 50+ repositories. Each service should only trigger builds when its specific code changes. How would you optimize this?

**A)** Create separate pipelines for each repository  
**B)** Use a monorepo approach with all services in one repository  
**C)** Use CodeCommit triggers with path filtering in Lambda functions  
**D)** Use EventBridge rules with content-based filtering  

<details>
<summary>Click to reveal answer</summary>

**Answer: C**

Lambda functions triggered by CodeCommit can analyze the changed files in commits and selectively trigger builds only for affected services. This provides fine-grained control over build triggers in a microservices architecture.
</details>

---

### Question 27
Your security team requires that all code changes be signed with GPG keys and verified. How would you implement this requirement in CodeCommit?

**A)** Configure CodeCommit to only accept signed commits  
**B)** Use Lambda functions to verify commit signatures post-push  
**C)** Implement client-side Git hooks to enforce signing  
**D)** Use AWS Certificate Manager to manage GPG keys  

<details>
<summary>Click to reveal answer</summary>

**Answer: C**

CodeCommit doesn't natively enforce GPG signature verification. This must be implemented through client-side Git hooks or organizational policies. Lambda functions can verify signatures after commits are pushed but can't prevent unsigned commits.
</details>

---

### Question 28
You're experiencing slow Git operations with a 10GB repository containing large binary assets. What's the best optimization strategy?

**A)** Enable CodeCommit's compression feature  
**B)** Implement Git LFS and migrate existing large files  
**C)** Split the repository into smaller repositories  
**D)** Use shallow clones in CI/CD pipelines  

<details>
<summary>Click to reveal answer</summary>

**Answer: B**

Git LFS is specifically designed to handle large files efficiently. Migrating existing large files to LFS and configuring it for future large files will significantly improve Git operation performance.
</details>

---

### Question 29
Your team needs to implement semantic versioning with automatic tagging based on commit messages. How would you automate this process?

**A)** Use CodeCommit's built-in semantic versioning  
**B)** Implement a Lambda function that analyzes commit messages and creates tags  
**C)** Use CodeBuild with semantic-release tools  
**D)** Configure Git hooks to create tags automatically  

<details>
<summary>Click to reveal answer</summary>

**Answer: B**

A Lambda function triggered by repository events can analyze commit messages, determine version bumps according to semantic versioning rules, and create appropriate tags. CodeCommit doesn't have built-in semantic versioning features.
</details>

---

### Question 30
You need to implement a code review workflow where infrastructure changes require approval from DevOps engineers, while application changes require approval from senior developers. How would you configure this?

**A)** Create separate repositories for infrastructure and application code  
**B)** Use multiple approval rule templates with path-based conditions  
**C)** Implement custom Lambda functions to enforce different approval rules  
**D)** Use branch-based approval rules with naming conventions  

<details>
<summary>Click to reveal answer</summary>

**Answer: C**

CodeCommit approval rules don't support path-based conditions natively. You need custom Lambda functions that analyze changed files and apply different approval requirements based on the file paths and content types.
</details>

---

### Question 31
Your organization operates in a highly regulated environment requiring immutable audit trails. How would you ensure CodeCommit repository history cannot be altered?

**A)** Enable CodeCommit's immutable history feature  
**B)** Use CloudTrail with log file validation and store logs in S3 with legal hold  
**C)** Implement Lambda functions that continuously backup repository state  
**D)** Use AWS Config rules to monitor repository changes  

<details>
<summary>Click to reveal answer</summary>

**Answer: B**

CloudTrail with log file validation provides cryptographic proof that logs haven't been altered. Storing these logs in S3 with legal hold ensures immutability. While Git history can be rewritten, CloudTrail provides an immutable audit trail of all operations.
</details>

---

### Question 32
You're implementing a disaster recovery strategy for critical CodeCommit repositories across multiple regions. What's the most robust approach?

**A)** Use CodeCommit's built-in cross-region replication  
**B)** Implement Lambda-based replication to secondary regions  
**C)** Use AWS Backup with cross-region backup configuration  
**D)** Create mirror repositories and sync them with EventBridge  

<details>
<summary>Click to reveal answer</summary>

**Answer: B**

Since CodeCommit doesn't have built-in cross-region replication, Lambda functions triggered by repository events can maintain mirror repositories in other regions. This provides the most control over the replication process and timing.
</details>

---

### Question 33
Your CI/CD pipeline frequently encounters rate limiting issues when multiple builds try to clone large repositories simultaneously. How would you optimize this?

**A)** Increase the CodeCommit service limits  
**B)** Implement repository caching with ElastiCache  
**C)** Use Lambda layers to cache repository content  
**D)** Implement a caching layer with S3 and periodic sync  

<details>
<summary>Click to reveal answer</summary>

**Answer: D**

A caching layer that periodically syncs repository content to S3 can serve multiple build processes without hitting CodeCommit rate limits. This is more cost-effective and scalable than other caching solutions for this use case.
</details>

---

### Question 34
You need to implement automatic license compliance checking for all repositories in your organization. What's the most scalable approach?

**A)** Use AWS Config rules to check repository contents  
**B)** Implement EventBridge rules that trigger Lambda functions for license scanning  
**C)** Use CodeGuru Reviewer with custom rules for license compliance  
**D)** Create CodeBuild projects that run license scanning tools  

<details>
<summary>Click to reveal answer</summary>

**Answer: B**

EventBridge can capture all CodeCommit events and trigger Lambda functions that perform license scanning using tools like FOSSA or custom scanning logic. This provides real-time compliance checking across all repositories.
</details>

---

### Question 35
Your organization needs to implement a complex approval workflow where different approval requirements apply based on the file types being changed, the target branch, and the committer's role. How would you architect this solution?

**A)** Create multiple approval rule templates and associate them with different branches  
**B)** Use AWS Step Functions to orchestrate a complex approval workflow with Lambda functions  
**C)** Implement a custom approval system using API Gateway and Lambda  
**D)** Use CodeCommit's conditional approval rules feature  

<details>
<summary>Click to reveal answer</summary>

**Answer: B**

AWS Step Functions can orchestrate complex workflows involving multiple Lambda functions that analyze file changes, user roles, and target branches to determine appropriate approval requirements. This provides the flexibility needed for complex approval logic that CodeCommit's built-in features can't handle.
</details>

---

## Answer Summary

| Question | Answer | Question | Answer | Question | Answer |
|----------|--------|----------|--------|----------|--------|
| 1        | B      | 13       | A      | 25       | C      |
| 2        | C      | 14       | B      | 26       | C      |
| 3        | B      | 15       | C      | 27       | C      |
| 4        | B      | 16       | B      | 28       | B      |
| 5        | B      | 17       | A      | 29       | B      |
| 6        | D      | 18       | B      | 30       | C      |
| 7        | B      | 19       | C      | 31       | B      |
| 8        | C      | 20       | B      | 32       | B      |
| 9        | B      | 21       | D      | 33       | D      |
| 10       | A      | 22       | B      | 34       | B      |
| 11       | B      | 23       | B      | 35       | B      |
| 12       | B      | 24       | B      |          |        |

## Study Tips

1. **Focus on Integration**: CodeCommit questions often involve integration with other AWS services
2. **Understand Limitations**: Know what CodeCommit can and cannot do natively
3. **Security is Key**: Many questions test understanding of IAM, KMS, and access control
4. **Event-Driven Architecture**: Understand how to use triggers, EventBridge, and Lambda for automation
5. **Enterprise Patterns**: Focus on scalability, compliance, and multi-account scenarios

## Additional Practice

For more practice questions and detailed explanations:
- Review AWS CodeCommit documentation
- Practice with hands-on labs
- Take AWS practice exams
- Join AWS certification study groups
- Experiment with different CodeCommit configurations in your own AWS account