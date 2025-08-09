# Security Policies - Practice Questions

## Multiple Choice Questions

### Question 1
A DevOps team needs to implement a security policy that prevents IAM users from creating new IAM policies but allows them to attach existing managed policies to roles. Which approach should they use?

A) Create a service control policy (SCP) that denies `iam:CreatePolicy` actions
B) Implement permissions boundaries that exclude policy creation permissions
C) Use IAM conditions to restrict policy creation based on user attributes
D) Configure AWS Config rules to detect unauthorized policy creation

**Answer: B**
**Explanation:** Permissions boundaries define the maximum permissions an entity can have. By creating a permissions boundary that excludes policy creation permissions and attaching it to users or roles, you ensure they cannot create new policies while still allowing them to work within the defined boundary.

### Question 2
Your organization requires that all S3 buckets must use KMS encryption with customer-managed keys. Which combination of controls would enforce this requirement most effectively?

A) S3 default encryption and IAM policies
B) Bucket policies with encryption conditions and AWS Config rules
C) Service control policies and CloudTrail monitoring
D) Lambda functions triggered by S3 events

**Answer: B**
**Explanation:** Bucket policies with encryption conditions can deny uploads without proper KMS encryption, while AWS Config rules can continuously monitor compliance and detect any buckets that don't meet the encryption requirements.

### Question 3
A company wants to implement automated remediation when AWS Config detects non-compliant resources. What is the most efficient approach?

A) Use AWS Config remediation configurations with AWS Systems Manager documents
B) Create CloudWatch alarms based on Config compliance events
C) Implement Lambda functions triggered by Config rules
D) Use EventBridge rules to trigger Step Functions workflows

**Answer: A**
**Explanation:** AWS Config remediation configurations with Systems Manager documents provide native, built-in remediation capabilities that can automatically fix non-compliant resources without custom code.

### Question 4
Which IAM policy condition would restrict API calls to only occur during business hours (9 AM to 5 PM UTC)?

A) `"DateGreaterThan": {"aws:CurrentTime": "09:00:00Z"}`
B) `"DateBetween": {"aws:CurrentTime": ["09:00:00Z", "17:00:00Z"]}`
C) `"StringEquals": {"aws:RequestTime": "09:00-17:00"}`
D) `"IpAddress": {"aws:SourceIp": "business-hours"}`

**Answer: B**
**Explanation:** The DateBetween condition key with aws:CurrentTime allows you to specify a time range. However, note that this would be a daily recurring window, not a one-time date range.

### Question 5
A DevOps engineer needs to ensure that EC2 instances can only be launched in specific subnets. Which approach provides the most granular control?

A) Use VPC endpoints to restrict instance placement
B) Implement IAM conditions based on subnet IDs in the EC2 launch policy
C) Configure security groups to allow traffic only from specific subnets
D) Use AWS Config rules to detect instances in unauthorized subnets

**Answer: B**
**Explanation:** IAM conditions can restrict the RunInstances action based on the subnet ID, preventing instances from being launched in unauthorized subnets at the API level.

### Question 6
Your organization requires MFA for all administrative actions. Which IAM condition enforces this requirement?

A) `"Bool": {"aws:SecureTransport": "true"}`
B) `"Bool": {"aws:MultiFactorAuthPresent": "true"}`
C) `"StringEquals": {"aws:PrincipalType": "AssumedRole"}`
D) `"NumericGreaterThan": {"aws:MultiFactorAuthAge": "3600"}`

**Answer: B**
**Explanation:** The aws:MultiFactorAuthPresent condition key is true when MFA was used to authenticate the request, making it perfect for enforcing MFA requirements.

### Question 7
A company wants to prevent data exfiltration by blocking large downloads from S3 buckets. Which policy condition would be most effective?

A) `"NumericLessThan": {"s3:max-keys": "100"}`
B) `"StringNotEquals": {"s3:x-amz-content-sha256": "UNSIGNED-PAYLOAD"}`
C) `"Bool": {"aws:ViaAWSService": "true"}`
D) `"IpAddress": {"aws:SourceIp": "internal-network-range"}`

**Answer: D**
**Explanation:** While not a perfect solution for preventing large downloads specifically, restricting S3 access to internal IP ranges helps prevent external data exfiltration. For more granular control, you might need additional conditions or AWS WAF.

### Question 8
Which GuardDuty finding type would indicate potential cryptocurrency mining activity?

A) TrojanFindingType
B) CryptoCurrencyFindingType
C) BackdoorFindingType
D) ReconnaissanceFindingType

**Answer: B**
**Explanation:** GuardDuty has specific finding types for cryptocurrency-related activities, including CryptoCurrency findings that detect mining activities and communication with known mining pools.

### Question 9
A security policy requires that all AWS API calls be logged and the logs be immutable. Which combination of services provides this capability?

A) CloudTrail with S3 bucket versioning and MFA delete
B) CloudWatch Logs with log retention policies
C) AWS Config with configuration snapshots
D) VPC Flow Logs with CloudWatch integration

**Answer: A**
**Explanation:** CloudTrail logs all API calls, and when stored in S3 with versioning enabled and MFA delete protection, the logs become effectively immutable.

### Question 10
An organization needs to ensure that sensitive data in S3 buckets is automatically classified and protected. Which AWS service combination would be most appropriate?

A) AWS Macie with AWS KMS and S3 bucket policies
B) Amazon Inspector with AWS Config rules
C) AWS GuardDuty with AWS Security Hub
D) AWS CloudHSM with AWS Certificate Manager

**Answer: A**
**Explanation:** AWS Macie can automatically discover, classify, and protect sensitive data in S3. Combined with KMS for encryption and bucket policies for access control, this provides comprehensive data protection.

## Scenario-Based Questions

### Scenario 1: Cross-Account Security
Your company has multiple AWS accounts for different environments (dev, staging, prod). The security team needs to implement centralized security monitoring and enforce consistent security policies across all accounts.

**Question 11:** Which approach would provide centralized security monitoring across multiple AWS accounts?

A) Deploy identical GuardDuty detectors in each account with manual correlation
B) Use AWS Organizations with a master Security Hub account and member accounts
C) Implement cross-account CloudTrail with a central logging account
D) Create identical AWS Config configurations in each account

**Answer: B**
**Explanation:** AWS Organizations with Security Hub allows for centralized security finding aggregation across multiple accounts, providing a single pane of glass for security monitoring.

**Question 12:** How would you enforce a policy that prevents the creation of public S3 buckets across all accounts in the organization?

A) Create identical bucket policies in each account
B) Use AWS Organizations Service Control Policies (SCPs)
C) Deploy Lambda functions in each account to monitor S3 creation
D) Configure AWS Config rules in each account with remediation

**Answer: B**
**Explanation:** Service Control Policies (SCPs) in AWS Organizations can prevent specific actions across all member accounts, including the creation of public S3 buckets.

### Scenario 2: Compliance Automation
A financial services company needs to ensure continuous compliance with SOC 2 Type II requirements, including automated detection and remediation of non-compliant resources.

**Question 13:** Which AWS Config rule would help detect unencrypted EBS volumes?

A) `ebs-snapshot-public-restorable-check`
B) `encrypted-volumes`
C) `ec2-security-group-attached-to-eni`
D) `ebs-optimized-instance`

**Answer: B**
**Explanation:** The `encrypted-volumes` Config rule specifically checks whether EBS volumes are encrypted, which is essential for compliance with data protection requirements.

**Question 14:** For automated remediation of non-compliant resources, which approach provides the most comprehensive solution?

A) AWS Config remediation configurations with Systems Manager
B) CloudWatch Events with Lambda functions
C) AWS Security Hub with custom integrations
D) Manual remediation based on Config rule violations

**Answer: A**
**Explanation:** AWS Config remediation configurations with Systems Manager provide native, automated remediation capabilities that can be configured directly within Config rules.

### Scenario 3: Zero Trust Architecture
A company is implementing a zero trust security model and needs to ensure that all access is authenticated, authorized, and encrypted.

**Question 15:** Which combination of IAM policy conditions would implement a zero trust principle for API access?

A) Require MFA and limit access to specific IP ranges
B) Allow access only from specific VPCs and require encryption in transit
C) Require MFA, verify source IP, check time of access, and ensure secure transport
D) Allow access only with temporary credentials from specific roles

**Answer: C**
**Explanation:** Zero trust requires verification of every access attempt. Combining MFA, source IP verification, time-based access controls, and secure transport creates multiple layers of verification.

## Advanced Technical Questions

### Question 16
You need to create an IAM policy that allows developers to manage EC2 instances but only if the instances are tagged with their team name. Which policy structure accomplishes this?

A)
```json
{
  "Effect": "Allow",
  "Action": "ec2:*",
  "Resource": "*",
  "Condition": {
    "StringEquals": {
      "aws:RequestedRegion": "us-east-1"
    }
  }
}
```

B)
```json
{
  "Effect": "Allow",
  "Action": "ec2:*",
  "Resource": "*",
  "Condition": {
    "StringEquals": {
      "ec2:ResourceTag/Team": "${aws:username}"
    }
  }
}
```

C)
```json
{
  "Effect": "Allow",
  "Action": "ec2:*",
  "Resource": "arn:aws:ec2:*:*:instance/*",
  "Condition": {
    "StringEquals": {
      "aws:PrincipalTag/Team": "${ec2:ResourceTag/Team}"
    }
  }
}
```

D)
```json
{
  "Effect": "Allow",
  "Action": "ec2:*",
  "Resource": "*",
  "Condition": {
    "ForAllValues:StringEquals": {
      "ec2:ResourceTag/Team": "development"
    }
  }
}
```

**Answer: C**
**Explanation:** Option C uses attribute-based access control (ABAC) to match the principal's team tag with the resource's team tag, allowing developers to manage only instances tagged with their team name.

### Question 17
A Lambda function needs to access S3 buckets, but only those that belong to the same project. The function should not be able to access buckets from other projects. Which policy provides the most secure approach?

A) Grant full S3 access and rely on bucket policies for restrictions
B) Use resource-based policies with wildcards for project-specific bucket names
C) Implement resource-based policies that match project tags between the Lambda function and S3 buckets
D) Create separate IAM roles for each project with hardcoded bucket ARNs

**Answer: C**
**Explanation:** Using resource-based policies that match tags between the Lambda function and S3 buckets provides dynamic, scalable access control without hardcoding specific resources.

### Question 18
Your organization requires that all CloudFormation stacks include mandatory tags for cost allocation and compliance. Which approach enforces this requirement most effectively?

A) Use CloudFormation Guard rules in the CI/CD pipeline
B) Implement Config rules to detect stacks without required tags
C) Use Service Control Policies to deny stack creation without tags
D) Create custom CloudFormation resource types with tag validation

**Answer: A**
**Explanation:** CloudFormation Guard can validate templates before deployment, preventing non-compliant stacks from being created in the first place, which is more effective than detecting violations after deployment.

## Practical Implementation Questions

### Question 19
You need to implement a security policy that automatically quarantines EC2 instances when GuardDuty detects suspicious activity. Describe the architecture and components needed.

**Expected Answer Components:**
- EventBridge rule to capture GuardDuty findings
- Lambda function for automated response
- Security group for quarantine (no inbound/outbound rules)
- SNS topic for notifications
- IAM roles with necessary permissions
- CloudWatch Logs for audit trail

### Question 20
Design a comprehensive S3 bucket security policy that meets the following requirements:
- Deny all unencrypted uploads
- Require MFA for object deletion
- Allow access only from specific VPC endpoints
- Log all access attempts

**Expected Answer Components:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyUnencryptedUploads",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::bucket-name/*",
      "Condition": {
        "StringNotEquals": {
          "s3:x-amz-server-side-encryption": "aws:kms"
        }
      }
    },
    {
      "Sid": "RequireMFAForDelete",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:DeleteObject",
      "Resource": "arn:aws:s3:::bucket-name/*",
      "Condition": {
        "BoolIfExists": {
          "aws:MultiFactorAuthPresent": "false"
        }
      }
    },
    {
      "Sid": "AllowOnlyVPCEndpointAccess",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::bucket-name",
        "arn:aws:s3:::bucket-name/*"
      ],
      "Condition": {
        "StringNotEquals": {
          "aws:SourceVpce": "vpce-12345678"
        }
      }
    }
  ]
}
```

## Performance and Optimization Questions

### Question 21
A large organization with thousands of resources is experiencing performance issues with AWS Config evaluations. Which optimization strategies would you recommend?

A) Increase the Config evaluation frequency to reduce backlog
B) Use Config aggregators to centralize evaluations
C) Filter Config rules to monitor only critical resources
D) Implement custom Lambda-based rules for faster evaluation

**Answer: C**
**Explanation:** Filtering Config rules to monitor only critical resources reduces the evaluation load and improves performance. Organizations should prioritize compliance checks based on risk assessment.

### Question 22
Your Security Hub is receiving thousands of findings per day, making it difficult to identify critical issues. How would you optimize the Security Hub configuration?

A) Disable low-severity findings and focus on high/critical severity only
B) Create custom insights to filter findings by resource type and severity
C) Use automated remediation for low-risk findings
D) All of the above

**Answer: D**
**Explanation:** A combination of filtering low-severity findings, creating custom insights for better organization, and implementing automated remediation for routine issues provides comprehensive optimization.

## Troubleshooting Questions

### Question 23
A Config rule is showing "NOT_APPLICABLE" for all resources instead of "COMPLIANT" or "NON_COMPLIANT". What could be the cause?

A) Insufficient permissions for the Config service role
B) The rule's resource scope doesn't match any existing resources
C) The Config recorder is not running
D) The rule evaluation logic has an error

**Answer: B**
**Explanation:** "NOT_APPLICABLE" typically means the rule's scope (resource types, tags, etc.) doesn't match any existing resources in the account.

### Question 24
Users are reporting that they can't access S3 buckets even though they have the necessary IAM permissions. The bucket has a restrictive bucket policy. How would you troubleshoot this?

**Expected Troubleshooting Steps:**
1. Check IAM policy simulator for the user's effective permissions
2. Review bucket policy for deny statements that might override IAM permissions
3. Verify if the user's source IP is allowed in the bucket policy
4. Check if MFA is required but not being used
5. Review CloudTrail logs for API call failures and error codes
6. Test with a simpler bucket policy to isolate the issue

## Answer Key Summary

1. B - Permissions boundaries
2. B - Bucket policies with conditions + Config rules
3. A - Config remediation with SSM
4. B - DateBetween condition
5. B - IAM conditions on subnet IDs
6. B - MultiFactorAuthPresent condition
7. D - IP address restrictions
8. B - CryptoCurrencyFindingType
9. A - CloudTrail + S3 versioning + MFA delete
10. A - Macie + KMS + bucket policies
11. B - Organizations with Security Hub
12. B - Service Control Policies
13. B - encrypted-volumes rule
14. A - Config remediation with SSM
15. C - Comprehensive zero trust conditions
16. C - ABAC with matching tags
17. C - Tag-based resource matching
18. A - CloudFormation Guard validation
19. Architecture question - see expected components
20. Policy design question - see expected policy
21. C - Filter rules to critical resources
22. D - All optimization strategies
23. B - Rule scope mismatch
24. Troubleshooting question - see expected steps