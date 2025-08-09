# AWS CodeBuild - Hands-on Labs

This directory contains comprehensive hands-on labs designed to provide practical experience with AWS CodeBuild, covering everything from basic project setup to advanced enterprise configurations.

## Lab Structure

Each lab includes:
- **Clear Objectives**: Specific learning goals and outcomes
- **Prerequisites**: Required knowledge and AWS resources
- **Estimated Time**: Realistic time investment
- **Step-by-step Instructions**: Detailed implementation guide
- **Validation Steps**: Methods to verify successful completion
- **Troubleshooting**: Common issues and solutions
- **Cleanup Instructions**: Resource removal to avoid charges
- **Extension Activities**: Additional challenges for advanced learning

## Available Labs

### Lab 1: Basic CodeBuild Project Setup and Configuration
**Duration**: 60 minutes  
**Difficulty**: Beginner  
**Focus**: Project creation, basic buildspec, and artifact management

Learn to create your first CodeBuild project with a simple Node.js application, configure basic build settings, and understand the build lifecycle.

### Lab 2: Advanced Buildspec and Multi-Stage Builds
**Duration**: 90 minutes  
**Difficulty**: Intermediate  
**Focus**: Complex buildspec files, environment variables, and conditional logic

Master advanced buildspec features including parameter store integration, conditional builds, and multi-stage build processes.

### Lab 3: Custom Build Environments and Container Builds
**Duration**: 120 minutes  
**Difficulty**: Advanced  
**Focus**: Custom Docker images, ECR integration, and containerized builds

Create custom build environments using Docker, integrate with ECR, and implement containerized build workflows.

### Lab 4: Build Optimization with Caching and Parallel Execution
**Duration**: 75 minutes  
**Difficulty**: Intermediate  
**Focus**: Performance optimization, caching strategies, and batch builds

Implement build caching, optimize build performance, and configure batch builds for parallel execution.

### Lab 5: Secure Builds with VPC and Secrets Management
**Duration**: 105 minutes  
**Difficulty**: Advanced  
**Focus**: VPC configuration, secrets management, and security best practices

Configure secure builds within a VPC, implement secrets management, and apply enterprise security best practices.

### Lab 6: CodeBuild Integration with CI/CD Pipeline
**Duration**: 150 minutes  
**Difficulty**: Advanced  
**Focus**: End-to-end CI/CD integration with CodeCommit and CodePipeline

Build a complete CI/CD pipeline integrating CodeBuild with CodeCommit, CodePipeline, and deployment automation.

## Prerequisites for All Labs

### AWS Account Requirements
- AWS account with administrative access or equivalent permissions
- AWS CLI installed and configured
- Git client installed
- Docker installed (for Labs 3, 5, and 6)
- Node.js 16+ installed (for Labs 1, 2, and 6)

### Required IAM Permissions
The following managed policies provide sufficient permissions for all labs:
- `AWSCodeBuildDeveloperAccess`
- `AmazonS3FullAccess` (for artifact storage)
- `CloudWatchFullAccess` (for monitoring and logs)
- `AWSCodeCommitFullAccess` (for source integration)
- `AmazonEC2ContainerRegistryFullAccess` (for custom images)
- `IAMFullAccess` (for role creation)
- `AWSKeyManagementServicePowerUser` (for encryption)

### Cost Considerations
- Most labs use AWS Free Tier eligible services
- Estimated cost per lab: $0.50-$3.00 (depending on build time and resources)
- Always clean up resources after completion
- Set up billing alerts to monitor usage

## Lab Environment Setup

### Initial AWS CLI Configuration
```bash
# Configure AWS CLI if not already done
aws configure

# Verify configuration
aws sts get-caller-identity

# Set default region (recommended: us-west-2)
export AWS_DEFAULT_REGION=us-west-2
```

### Required Tools Installation

**macOS:**
```bash
# Install Homebrew if not installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required tools
brew install awscli git docker node jq
```

**Ubuntu/Debian:**
```bash
# Update package list
sudo apt update

# Install required tools
sudo apt install -y awscli git docker.io nodejs npm jq

# Add user to docker group
sudo usermod -aG docker $USER
```

**Windows (PowerShell):**
```powershell
# Install Chocolatey if not installed
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install required tools
choco install -y awscli git docker-desktop nodejs jq
```

## Getting Started

1. **Choose Your Starting Point**: 
   - Beginners: Start with Lab 1
   - Intermediate: Begin with Lab 2 or 4
   - Advanced: Jump to Lab 3, 5, or 6

2. **Prepare Your Environment**: 
   - Ensure all prerequisites are met
   - Configure AWS CLI with appropriate credentials
   - Verify tool installations

3. **Lab Progression**: 
   - Complete labs sequentially for comprehensive learning
   - Each lab builds on concepts from previous labs
   - Review lab objectives before starting

4. **Resource Management**: 
   - Always run cleanup commands after each lab
   - Monitor AWS costs using the billing dashboard
   - Use consistent naming conventions across labs

## Best Practices for Lab Completion

### Planning and Preparation
- Read through entire lab before starting
- Understand the objectives and expected outcomes
- Ensure you have sufficient time to complete the lab
- Have documentation and AWS console ready

### During Lab Execution
- Follow instructions step by step
- Verify each step before proceeding
- Take screenshots of key configurations
- Document any issues or observations
- Use descriptive names for resources

### Validation and Testing
- Complete all validation steps
- Test builds thoroughly before moving on
- Review logs and metrics
- Understand what each configuration achieves

### Cleanup and Review
- Always execute cleanup procedures
- Verify all resources have been removed
- Review what you learned
- Note any areas for further exploration

## Common Issues and Solutions

### Authentication Problems
- **Issue**: AWS CLI not configured or expired credentials
- **Solution**: Run `aws configure` or refresh credentials

### Permission Errors
- **Issue**: Insufficient IAM permissions
- **Solution**: Ensure required policies are attached to your user/role

### Build Failures
- **Issue**: Buildspec errors or missing dependencies
- **Solution**: Check CloudWatch logs, verify buildspec syntax

### Resource Limits
- **Issue**: AWS service limits exceeded
- **Solution**: Clean up unused resources, request limit increases

### Networking Issues
- **Issue**: VPC configuration or connectivity problems
- **Solution**: Verify security groups, subnets, and route tables

## Additional Resources

### AWS Documentation
- [AWS CodeBuild User Guide](https://docs.aws.amazon.com/codebuild/)
- [Buildspec File Reference](https://docs.aws.amazon.com/codebuild/latest/userguide/build-spec-ref.html)
- [CodeBuild Best Practices](https://docs.aws.amazon.com/codebuild/latest/userguide/best-practices.html)

### Useful Tools
- [AWS CodeBuild Local](https://github.com/aws/aws-codebuild-docker-images) - Test builds locally
- [CFN-Lint](https://github.com/aws-cloudformation/cfn-lint) - CloudFormation template validation
- [AWS CLI Documentation](https://docs.aws.amazon.com/cli/) - CLI reference

### Community Resources
- [AWS Samples - CodeBuild](https://github.com/aws-samples?q=codebuild)
- [AWS DevOps Blog](https://aws.amazon.com/blogs/devops/)
- [Stack Overflow - AWS CodeBuild](https://stackoverflow.com/questions/tagged/aws-codebuild)

## Support and Feedback

### Getting Help
- Review troubleshooting sections in each lab
- Check AWS documentation and community forums
- Use AWS Support if you have a support plan
- Consult with peers or mentors

### Providing Feedback
- Note any errors or unclear instructions
- Suggest improvements or additional scenarios
- Share your experience with the learning community

## Lab Completion Tracking

Use this checklist to track your progress:

- [ ] **Lab 1**: Basic CodeBuild Project Setup and Configuration
- [ ] **Lab 2**: Advanced Buildspec and Multi-Stage Builds
- [ ] **Lab 3**: Custom Build Environments and Container Builds
- [ ] **Lab 4**: Build Optimization with Caching and Parallel Execution
- [ ] **Lab 5**: Secure Builds with VPC and Secrets Management
- [ ] **Lab 6**: CodeBuild Integration with CI/CD Pipeline

## Next Steps After Lab Completion

1. **Practice Variations**: Try different application types and build scenarios
2. **Explore Advanced Features**: Investigate CodeBuild features not covered in labs
3. **Integration Projects**: Build real-world projects using CodeBuild
4. **Certification Preparation**: Use lab knowledge for AWS certification exams
5. **Team Implementation**: Apply learnings to your organization's CI/CD processes

---

**Remember**: The goal of these labs is to provide hands-on experience with real-world CodeBuild scenarios. Take time to understand each concept rather than rushing through the steps. The knowledge gained here will be invaluable for implementing CodeBuild in production environments.