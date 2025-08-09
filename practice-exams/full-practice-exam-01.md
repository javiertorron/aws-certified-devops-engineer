# AWS DevOps Engineer Professional - Practice Exam 01

## Instructions

- **Time Limit**: 180 minutes
- **Questions**: 75 questions
- **Passing Score**: 750/1000 (approximately 56-57 correct answers)
- **Format**: Multiple choice (single answer) and multiple response (multiple correct answers)

---

## Questions

### Question 1 (Domain 1: SDLC Automation)

A development team is using AWS CodePipeline with AWS CodeBuild for their CI/CD pipeline. The build stage frequently fails due to intermittent network issues when downloading dependencies. What is the MOST effective approach to improve build reliability?

A) Increase the build timeout in CodeBuild
B) Use CodeBuild with VPC configuration and NAT Gateway
C) Enable CodeBuild caching for dependencies
D) Switch to a larger CodeBuild instance type

**Correct Answer**: C
**Explanation**: CodeBuild caching stores dependencies between builds, reducing download time and network-related failures.

---

### Question 2 (Domain 2: Configuration Management)

Your organization needs to deploy infrastructure across multiple AWS accounts while maintaining consistent configurations. Which approach provides the BEST solution for cross-account CloudFormation deployments?

A) Use CloudFormation StackSets
B) Copy templates manually to each account
C) Use AWS Organizations with Service Control Policies
D) Create identical stacks in each account individually

**Correct Answer**: A
**Explanation**: CloudFormation StackSets enable deployment and management of stacks across multiple accounts and regions.

---

*This practice exam will be expanded to include all 75 questions covering all six domains with detailed explanations.*