# AWS CodeCommit - Hands-on Labs

This directory contains practical, hands-on labs designed to reinforce AWS CodeCommit concepts and provide real-world experience with enterprise-grade repository management, automation, and integration patterns.

## Lab Structure

Each lab includes:
- **Objectives**: Clear learning goals
- **Prerequisites**: Required knowledge and resources
- **Estimated Time**: Time investment required
- **Step-by-step Instructions**: Detailed implementation guide
- **Validation**: How to verify successful completion
- **Cleanup**: Resource cleanup procedures
- **Extensions**: Additional challenges for advanced learning

## Available Labs

### Lab 1: Advanced CodeCommit Repository Setup with Enterprise Features
**Duration**: 90 minutes  
**Difficulty**: Intermediate  
**Focus**: Repository creation, security, encryption, and basic automation

Set up a comprehensive CodeCommit environment with KMS encryption, cross-account access, approval rules, and SNS notifications.

### Lab 2: Implementing Repository Triggers and Automation
**Duration**: 120 minutes  
**Difficulty**: Advanced  
**Focus**: EventBridge integration, Lambda automation, and workflow triggers

Build event-driven automation using repository triggers, Lambda functions, and EventBridge rules for comprehensive workflow automation.

### Lab 3: Cross-Account Access and Multi-Region Configuration
**Duration**: 90 minutes  
**Difficulty**: Advanced  
**Focus**: Enterprise access patterns and disaster recovery

Implement cross-account repository access, multi-region backup strategies, and enterprise access control patterns.

### Lab 4: CodeCommit Integration with CI/CD Pipeline
**Duration**: 150 minutes  
**Difficulty**: Advanced  
**Focus**: CI/CD integration and pipeline automation

Create end-to-end CI/CD pipeline integration with CodeCommit as source, including build triggers and deployment automation.

### Lab 5: Monitoring, Alerting, and Performance Optimization
**Duration**: 60 minutes  
**Difficulty**: Intermediate  
**Focus**: Observability and performance

Implement comprehensive monitoring, custom metrics, alerting, and performance optimization for CodeCommit repositories.

## Prerequisites for All Labs

### AWS Account Requirements
- AWS account with administrative access
- AWS CLI configured with appropriate credentials
- Git client installed and configured
- Python 3.8+ installed
- jq command-line JSON processor

### IAM Permissions
The following managed policies are recommended for lab execution:
- `AWSCodeCommitFullAccess`
- `IAMFullAccess` (for role/policy creation)
- `AWSLambdaFullAccess`
- `CloudWatchFullAccess`
- `AmazonEventBridgeFullAccess`
- `AmazonSNSFullAccess`
- `AWSKeyManagementServicePowerUser`

### Cost Considerations
- Most labs use AWS Free Tier eligible services
- Estimated cost per lab: $0.10-$2.00 (depending on duration)
- Always clean up resources after completion
- Monitor costs using AWS Budgets

## Lab Environment Setup

Before starting any lab, ensure you have:

1. **AWS CLI Configuration**:
   ```bash
   aws configure
   aws sts get-caller-identity
   ```

2. **Git Configuration**:
   ```bash
   git config --global credential.helper '!aws codecommit credential-helper $@'
   git config --global credential.UseHttpPath true
   ```

3. **Required Tools**:
   ```bash
   # Install jq (if not already installed)
   # macOS:
   brew install jq
   
   # Ubuntu/Debian:
   sudo apt-get install jq
   
   # Amazon Linux:
   sudo yum install jq
   ```

## Getting Started

1. Choose a lab based on your current skill level
2. Review the prerequisites and objectives
3. Set up your environment as described above
4. Follow the step-by-step instructions
5. Validate your implementation
6. Clean up resources to avoid charges
7. Document your learnings and challenges

## Lab Progression Recommendation

For maximum learning effectiveness, complete the labs in this order:
1. **Lab 1** → Foundation setup and basic features
2. **Lab 5** → Monitoring and observability
3. **Lab 2** → Advanced automation
4. **Lab 3** → Enterprise patterns
5. **Lab 4** → Full CI/CD integration

## Additional Resources

- [AWS CodeCommit User Guide](https://docs.aws.amazon.com/codecommit/)
- [AWS CLI CodeCommit Command Reference](https://docs.aws.amazon.com/cli/latest/reference/codecommit/)
- [CodeCommit Best Practices](https://docs.aws.amazon.com/codecommit/latest/userguide/best-practices.html)
- [Git Documentation](https://git-scm.com/doc)

## Support and Troubleshooting

Common issues and solutions:
- **Credential Helper Issues**: Ensure AWS CLI is configured correctly
- **Permission Errors**: Verify IAM permissions and policies
- **Git Operations Failing**: Check credential helper configuration
- **Resource Limits**: Monitor service limits and quotas

For additional help, refer to the troubleshooting section in the main content or AWS documentation.

---

**Note**: These labs are designed for educational purposes. Always follow your organization's security policies and AWS best practices when implementing in production environments.