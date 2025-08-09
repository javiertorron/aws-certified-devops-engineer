# Compliance Frameworks - Detailed Content

## Introduction

Compliance frameworks provide structured approaches to meeting regulatory requirements, industry standards, and organizational policies. In AWS DevOps environments, implementing compliance frameworks requires automation, continuous monitoring, and integration with development and deployment processes. This comprehensive guide covers the implementation of major compliance frameworks using AWS services and DevOps practices.

## 1. Understanding Compliance Frameworks

### 1.1 Compliance Framework Components

#### Control Objectives
Control objectives define what needs to be achieved to maintain compliance:
- **Preventive Controls:** Prevent non-compliant actions before they occur
- **Detective Controls:** Identify non-compliant conditions after they occur
- **Corrective Controls:** Remediate non-compliant conditions when detected

#### Control Implementation
Controls can be implemented at different layers:
- **Administrative Controls:** Policies, procedures, training
- **Technical Controls:** Automated systems, encryption, access controls
- **Physical Controls:** Physical security measures

#### Evidence and Documentation
Compliance requires documented evidence of control effectiveness:
- **Control Testing:** Regular validation of control operation
- **Evidence Collection:** Automated gathering of compliance artifacts
- **Audit Support:** Documentation and reports for external audits

### 1.2 AWS Shared Responsibility Model in Compliance

AWS provides compliance infrastructure, but customers are responsible for:
- **Configuration:** Properly configuring AWS services for compliance
- **Data Protection:** Encrypting and protecting customer data
- **Access Management:** Controlling access to resources and data
- **Monitoring:** Continuously monitoring compliance status
- **Documentation:** Maintaining evidence and audit trails

## 2. Major Compliance Frameworks

### 2.1 SOC 2 Type II Compliance

SOC 2 Type II evaluates the design and operational effectiveness of controls over a period of time.

#### Trust Service Criteria

**Security (Common Criteria)**
```yaml
# Example Config rule for security logging
AWSConfigRule:
  Type: AWS::Config::ConfigRule
  Properties:
    ConfigRuleName: cloudtrail-enabled
    Description: Ensures CloudTrail is enabled for logging
    Source:
      Owner: AWS
      SourceIdentifier: CLOUD_TRAIL_ENABLED
    Scope:
      ComplianceResourceTypes:
        - AWS::CloudTrail::Trail
```

**Availability**
- Multi-AZ deployments for high availability
- Disaster recovery procedures
- Backup and restore capabilities
- Performance monitoring and alerting

**Processing Integrity**
- Data validation controls
- Error handling and logging
- Change management procedures
- System monitoring and alerting

**Confidentiality**
- Data encryption in transit and at rest
- Access controls and authentication
- Data classification and handling
- Secure development practices

**Privacy (when applicable)**
- Data collection and use policies
- Consent management
- Data retention and disposal
- Privacy impact assessments

#### SOC 2 Implementation Example

```python
# Lambda function for SOC 2 evidence collection
import boto3
import json
from datetime import datetime, timedelta

def lambda_handler(event, context):
    """
    Automated SOC 2 evidence collection function
    Collects security, availability, and integrity evidence
    """
    
    evidence_collector = SOC2EvidenceCollector()
    
    # Collect security evidence
    security_evidence = evidence_collector.collect_security_evidence()
    
    # Collect availability evidence  
    availability_evidence = evidence_collector.collect_availability_evidence()
    
    # Collect processing integrity evidence
    integrity_evidence = evidence_collector.collect_integrity_evidence()
    
    # Generate compliance report
    compliance_report = {
        'timestamp': datetime.utcnow().isoformat(),
        'framework': 'SOC2_TYPE_II',
        'evidence': {
            'security': security_evidence,
            'availability': availability_evidence,
            'processing_integrity': integrity_evidence
        }
    }
    
    # Store evidence in S3
    s3_client = boto3.client('s3')
    s3_client.put_object(
        Bucket='compliance-evidence-bucket',
        Key=f'soc2-evidence/{datetime.utcnow().strftime("%Y/%m/%d")}/evidence.json',
        Body=json.dumps(compliance_report),
        ServerSideEncryption='aws:kms'
    )
    
    return compliance_report

class SOC2EvidenceCollector:
    def __init__(self):
        self.config_client = boto3.client('config')
        self.cloudwatch_client = boto3.client('cloudwatch')
        self.cloudtrail_client = boto3.client('cloudtrail')
    
    def collect_security_evidence(self):
        """Collect evidence for SOC 2 Security criteria"""
        evidence = {}
        
        # Check encryption compliance
        evidence['encryption_compliance'] = self._check_encryption_compliance()
        
        # Check access control compliance
        evidence['access_control_compliance'] = self._check_access_controls()
        
        # Check logging compliance
        evidence['logging_compliance'] = self._check_logging_compliance()
        
        return evidence
    
    def collect_availability_evidence(self):
        """Collect evidence for SOC 2 Availability criteria"""
        evidence = {}
        
        # Check multi-AZ deployments
        evidence['multi_az_compliance'] = self._check_multi_az_deployments()
        
        # Check backup compliance
        evidence['backup_compliance'] = self._check_backup_compliance()
        
        # Check monitoring compliance
        evidence['monitoring_compliance'] = self._check_monitoring_setup()
        
        return evidence
    
    def collect_integrity_evidence(self):
        """Collect evidence for SOC 2 Processing Integrity criteria"""
        evidence = {}
        
        # Check data validation controls
        evidence['data_validation'] = self._check_data_validation_controls()
        
        # Check error handling
        evidence['error_handling'] = self._check_error_handling()
        
        # Check change management
        evidence['change_management'] = self._check_change_management()
        
        return evidence
    
    def _check_encryption_compliance(self):
        """Check if resources are properly encrypted"""
        try:
            # Check S3 bucket encryption
            response = self.config_client.get_compliance_details_by_config_rule(
                ConfigRuleName='s3-bucket-server-side-encryption-enabled'
            )
            
            compliant_resources = [
                result for result in response['EvaluationResults']
                if result['ComplianceType'] == 'COMPLIANT'
            ]
            
            return {
                'status': 'COMPLIANT' if len(compliant_resources) > 0 else 'NON_COMPLIANT',
                'compliant_resources': len(compliant_resources),
                'total_resources': len(response['EvaluationResults'])
            }
        except Exception as e:
            return {'status': 'ERROR', 'error': str(e)}
    
    def _check_access_controls(self):
        """Check access control implementations"""
        # Implementation for checking IAM policies, MFA, etc.
        pass
    
    def _check_logging_compliance(self):
        """Check logging and monitoring compliance"""
        # Implementation for checking CloudTrail, VPC Flow Logs, etc.
        pass
```

### 2.2 PCI DSS Compliance

Payment Card Industry Data Security Standard (PCI DSS) applies to organizations that handle credit card data.

#### PCI DSS Requirements Mapping

**Requirement 1: Install and maintain a firewall configuration**
```yaml
# Security Group for PCI compliance
PCICompliantSecurityGroup:
  Type: AWS::EC2::SecurityGroup
  Properties:
    GroupDescription: PCI DSS compliant security group
    VpcId: !Ref VPC
    SecurityGroupIngress:
      # Allow HTTPS only
      - IpProtocol: tcp
        FromPort: 443
        ToPort: 443
        CidrIp: 10.0.0.0/8
        Description: HTTPS from internal network only
    SecurityGroupEgress:
      # Restrict outbound traffic
      - IpProtocol: tcp
        FromPort: 443
        ToPort: 443
        CidrIp: 0.0.0.0/0
        Description: HTTPS outbound only
    Tags:
      - Key: Compliance
        Value: PCI-DSS
      - Key: DataClassification
        Value: CardholderData
```

**Requirement 2: Do not use vendor-supplied defaults**
```python
# Config rule to check for default passwords/configurations
def evaluate_compliance(configuration_item):
    """
    Evaluate if resource uses default configurations
    """
    resource_type = configuration_item['resourceType']
    
    if resource_type == 'AWS::RDS::DBInstance':
        # Check if RDS instance uses default port
        if configuration_item['configuration'].get('dbPort') in [3306, 5432, 1433]:
            return 'NON_COMPLIANT'
    
    elif resource_type == 'AWS::ElastiCache::CacheCluster':
        # Check if ElastiCache uses default port
        if configuration_item['configuration'].get('port') in [6379, 11211]:
            return 'NON_COMPLIANT'
    
    return 'COMPLIANT'
```

**Requirement 3: Protect stored cardholder data**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "RequireEncryptionForCardholderData",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::cardholder-data-bucket/*",
      "Condition": {
        "StringNotEquals": {
          "s3:x-amz-server-side-encryption": "aws:kms"
        }
      }
    },
    {
      "Sid": "RequireSpecificKMSKeyForCardholderData",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::cardholder-data-bucket/*",
      "Condition": {
        "StringNotEquals": {
          "s3:x-amz-server-side-encryption-aws-kms-key-id": "arn:aws:kms:region:account:key/pci-compliant-key-id"
        }
      }
    }
  ]
}
```

### 2.3 HIPAA Compliance

Health Insurance Portability and Accountability Act (HIPAA) requires protection of health information.

#### HIPAA Safeguards Implementation

**Administrative Safeguards**
```yaml
# IAM policy for HIPAA administrative safeguards
HIPAAAdministrativePolicy:
  Type: AWS::IAM::Policy
  Properties:
    PolicyName: HIPAA-Administrative-Safeguards
    PolicyDocument:
      Version: '2012-10-17'
      Statement:
        # Unique user identification
        - Effect: Deny
          Action: '*'
          Resource: '*'
          Condition:
            Bool:
              aws:MultiFactorAuthPresent: 'false'
        
        # Emergency access procedure
        - Effect: Allow
          Action:
            - sts:AssumeRole
          Resource: 'arn:aws:iam::*:role/HIPAA-Emergency-Access-Role'
          Condition:
            StringEquals:
              sts:ExternalId: '${aws:RequestTag/EmergencyAccess}'
        
        # Automatic logoff
        - Effect: Deny
          Action: '*'
          Resource: '*'
          Condition:
            NumericGreaterThan:
              aws:TokenIssueTime: '28800'  # 8 hours
```

**Physical Safeguards**
```python
# Automated compliance check for physical safeguards
def check_physical_safeguards():
    """
    Check physical safeguards compliance for HIPAA
    """
    ec2_client = boto3.client('ec2')
    
    # Check if instances are in compliant AZs (dedicated tenancy)
    instances = ec2_client.describe_instances(
        Filters=[
            {'Name': 'tag:DataClassification', 'Values': ['PHI']},
            {'Name': 'instance-state-name', 'Values': ['running']}
        ]
    )
    
    non_compliant_instances = []
    
    for reservation in instances['Reservations']:
        for instance in reservation['Instances']:
            if instance.get('Tenancy') != 'dedicated':
                non_compliant_instances.append(instance['InstanceId'])
    
    return {
        'compliant': len(non_compliant_instances) == 0,
        'non_compliant_instances': non_compliant_instances,
        'recommendation': 'Move PHI processing instances to dedicated tenancy'
    }
```

**Technical Safeguards**
```yaml
# Technical safeguards for HIPAA compliance
HIPAATechnicalSafeguards:
  Type: AWS::CloudFormation::Stack
  Properties:
    TemplateURL: hipaa-technical-safeguards.yaml
    Parameters:
      # Access control
      RequireMFA: true
      MaxSessionDuration: 28800  # 8 hours
      
      # Audit controls
      EnableCloudTrail: true
      EnableVPCFlowLogs: true
      LogRetentionDays: 2555  # 7 years
      
      # Integrity controls
      EnableS3Versioning: true
      EnableBackups: true
      
      # Person or entity authentication
      RequireSSO: true
      
      # Transmission security
      RequireHTTPS: true
      RequireVPNAccess: true
```

### 2.4 GDPR Compliance

General Data Protection Regulation (GDPR) governs data protection and privacy in the EU.

#### GDPR Principles Implementation

**Data Minimization**
```python
# Data minimization compliance check
def check_data_minimization(event, context):
    """
    Check if data collection follows minimization principles
    """
    s3_client = boto3.client('s3')
    
    # Check S3 objects for PII data patterns
    response = s3_client.list_objects_v2(
        Bucket='user-data-bucket'
    )
    
    findings = []
    for obj in response.get('Contents', []):
        # Get object metadata
        metadata = s3_client.head_object(
            Bucket='user-data-bucket',
            Key=obj['Key']
        )
        
        # Check if object contains unnecessary PII
        if not metadata.get('Metadata', {}).get('data-minimization-review'):
            findings.append({
                'object': obj['Key'],
                'issue': 'Data minimization review required',
                'recommendation': 'Review and tag with data-minimization-review metadata'
            })
    
    return findings
```

**Right to be Forgotten**
```python
# Automated data deletion for GDPR right to be forgotten
def process_deletion_request(event, context):
    """
    Process GDPR data deletion requests
    """
    user_id = event['user_id']
    
    # Delete from S3
    s3_client = boto3.client('s3')
    s3_objects = s3_client.list_objects_v2(
        Bucket='user-data-bucket',
        Prefix=f'user-{user_id}/'
    )
    
    for obj in s3_objects.get('Contents', []):
        s3_client.delete_object(
            Bucket='user-data-bucket',
            Key=obj['Key']
        )
    
    # Delete from DynamoDB
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('user-profiles')
    table.delete_item(Key={'user_id': user_id})
    
    # Create audit log
    audit_log = {
        'timestamp': datetime.utcnow().isoformat(),
        'action': 'data_deletion',
        'user_id': user_id,
        'status': 'completed',
        'legal_basis': 'GDPR Article 17 - Right to erasure'
    }
    
    # Store audit log
    cloudwatch_logs = boto3.client('logs')
    cloudwatch_logs.put_log_events(
        logGroupName='/aws/lambda/gdpr-compliance',
        logStreamName=f'deletion-{datetime.utcnow().strftime("%Y-%m-%d")}',
        logEvents=[{
            'timestamp': int(datetime.utcnow().timestamp() * 1000),
            'message': json.dumps(audit_log)
        }]
    )
    
    return audit_log
```

## 3. AWS Compliance Services

### 3.1 AWS Config for Compliance

AWS Config provides configuration compliance monitoring and automated remediation.

#### Config Rules for Compliance
```yaml
# Config rules for common compliance requirements
ComplianceConfigRules:
  - ConfigRuleName: encrypted-volumes
    Description: EBS volumes must be encrypted
    Source:
      Owner: AWS
      SourceIdentifier: ENCRYPTED_VOLUMES
    Remediation:
      ConfigRuleName: encrypted-volumes
      ResourceType: AWS::EC2::Volume
      TargetType: SSM_DOCUMENT
      TargetId: AWSConfigRemediation-EncryptUnencryptedEBSVolumes
  
  - ConfigRuleName: s3-bucket-ssl-requests-only
    Description: S3 buckets must enforce SSL requests
    Source:
      Owner: AWS
      SourceIdentifier: S3_BUCKET_SSL_REQUESTS_ONLY
    Remediation:
      ConfigRuleName: s3-bucket-ssl-requests-only
      ResourceType: AWS::S3::Bucket
      TargetType: SSM_DOCUMENT
      TargetId: AWSConfigRemediation-RemoveS3BucketPolicy
```

### 3.2 AWS Security Hub Compliance Standards

Security Hub provides pre-built compliance standards and custom frameworks.

#### Enabling Compliance Standards
```python
# Enable multiple compliance standards in Security Hub
def enable_compliance_standards():
    """
    Enable AWS Security Hub compliance standards
    """
    securityhub_client = boto3.client('securityhub')
    
    standards_to_enable = [
        'arn:aws:securityhub:::ruleset/finding-format/aws-foundational-security-standard/v/1.0.0',
        'arn:aws:securityhub:region::standard/pci-dss/v/3.2.1',
        'arn:aws:securityhub:region::standard/aws-foundational-security-standard/v/1.0.0',
        'arn:aws:securityhub:region::standard/cis-aws-foundations-benchmark/v/1.2.0'
    ]
    
    for standard_arn in standards_to_enable:
        try:
            securityhub_client.batch_enable_standards(
                StandardsSubscriptionRequests=[{
                    'StandardsArn': standard_arn
                }]
            )
            print(f"Enabled standard: {standard_arn}")
        except Exception as e:
            print(f"Failed to enable {standard_arn}: {str(e)}")
```

### 3.3 AWS Audit Manager

Audit Manager automates evidence collection for compliance audits.

#### Creating Custom Compliance Framework
```python
# Create custom compliance framework in Audit Manager
def create_custom_framework():
    """
    Create a custom compliance framework in AWS Audit Manager
    """
    audit_manager_client = boto3.client('auditmanager')
    
    custom_framework = {
        'name': 'Custom-SOC2-Framework',
        'description': 'Custom SOC 2 Type II framework for our organization',
        'controlSets': [
            {
                'name': 'Security Controls',
                'controls': [
                    {
                        'name': 'Access Control',
                        'description': 'Logical access controls are implemented',
                        'testingInformation': 'Validate IAM policies and MFA implementation',
                        'actionPlanTitle': 'Access Control Remediation',
                        'actionPlanInstructions': 'Review and update access controls'
                    },
                    {
                        'name': 'Encryption',
                        'description': 'Data is encrypted in transit and at rest',
                        'testingInformation': 'Validate encryption implementation across all services',
                        'actionPlanTitle': 'Encryption Remediation',
                        'actionPlanInstructions': 'Implement encryption where missing'
                    }
                ]
            }
        ]
    }
    
    response = audit_manager_client.create_assessment_framework(
        name=custom_framework['name'],
        description=custom_framework['description'],
        controlSets=custom_framework['controlSets']
    )
    
    return response
```

## 4. Compliance Automation Patterns

### 4.1 Compliance as Code

Implement compliance requirements using Infrastructure as Code patterns.

#### Compliance Policy Templates
```yaml
# CloudFormation template with compliance constraints
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Compliance-enforced infrastructure template'

Parameters:
  ComplianceFramework:
    Type: String
    AllowedValues: [SOC2, PCI-DSS, HIPAA, GDPR]
    Default: SOC2
  
  DataClassification:
    Type: String
    AllowedValues: [Public, Internal, Confidential, Restricted]
    Default: Internal

Conditions:
  RequireEncryption: !Or
    - !Equals [!Ref ComplianceFramework, PCI-DSS]
    - !Equals [!Ref ComplianceFramework, HIPAA]
    - !Equals [!Ref DataClassification, Restricted]
  
  RequireDedicatedTenancy: !Equals [!Ref ComplianceFramework, HIPAA]

Resources:
  # S3 bucket with compliance-based configuration
  ComplianceBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub '${AWS::StackName}-compliance-bucket'
      BucketEncryption:
        ServerSideEncryptionConfiguration:
          - ServerSideEncryptionByDefault:
              SSEAlgorithm: !If [RequireEncryption, aws:kms, AES256]
              KMSMasterKeyID: !If [RequireEncryption, !Ref ComplianceKMSKey, !Ref 'AWS::NoValue']
            BucketKeyEnabled: !If [RequireEncryption, true, false]
      
      VersioningConfiguration:
        Status: !If [RequireEncryption, Enabled, Suspended]
      
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        BlockPublicPolicy: true
        IgnorePublicAcls: true
        RestrictPublicBuckets: true
      
      LoggingConfiguration:
        DestinationBucketName: !Ref AccessLogsBucket
        LogFilePrefix: access-logs/
      
      Tags:
        - Key: Compliance
          Value: !Ref ComplianceFramework
        - Key: DataClassification
          Value: !Ref DataClassification

  # KMS key for encryption
  ComplianceKMSKey:
    Type: AWS::KMS::Key
    Condition: RequireEncryption
    Properties:
      Description: !Sub 'KMS key for ${ComplianceFramework} compliance'
      KeyPolicy:
        Statement:
          - Sid: Enable IAM User Permissions
            Effect: Allow
            Principal:
              AWS: !Sub 'arn:aws:iam::${AWS::AccountId}:root'
            Action: 'kms:*'
            Resource: '*'
          - Sid: Allow CloudTrail Encryption
            Effect: Allow
            Principal:
              Service: cloudtrail.amazonaws.com
            Action:
              - kms:GenerateDataKey
              - kms:DescribeKey
            Resource: '*'
      Tags:
        - Key: Compliance
          Value: !Ref ComplianceFramework
```

### 4.2 Continuous Compliance Monitoring

Implement continuous compliance monitoring using event-driven architectures.

```python
# Continuous compliance monitoring system
import boto3
import json
from datetime import datetime

class ComplianceMonitor:
    def __init__(self):
        self.config_client = boto3.client('config')
        self.sns_client = boto3.client('sns')
        self.s3_client = boto3.client('s3')
        
    def lambda_handler(self, event, context):
        """
        Main handler for compliance monitoring events
        """
        
        # Parse the incoming event
        event_source = event.get('source')
        detail_type = event.get('detail-type')
        
        if event_source == 'aws.config':
            return self.handle_config_event(event)
        elif event_source == 'aws.securityhub':
            return self.handle_security_hub_event(event)
        elif event_source == 'aws.s3':
            return self.handle_s3_event(event)
        
        return {'statusCode': 200, 'message': 'Event processed'}
    
    def handle_config_event(self, event):
        """
        Handle AWS Config compliance change events
        """
        detail = event['detail']
        
        if detail.get('newEvaluationResult', {}).get('complianceType') == 'NON_COMPLIANT':
            compliance_violation = {
                'timestamp': datetime.utcnow().isoformat(),
                'source': 'AWS Config',
                'rule_name': detail.get('configRuleName'),
                'resource_type': detail.get('resourceType'),
                'resource_id': detail.get('resourceId'),
                'compliance_type': detail['newEvaluationResult']['complianceType'],
                'annotation': detail['newEvaluationResult'].get('annotation', '')
            }
            
            # Send notification
            self.send_compliance_notification(compliance_violation)
            
            # Store violation for reporting
            self.store_compliance_violation(compliance_violation)
            
            # Attempt automated remediation
            self.attempt_remediation(compliance_violation)
        
        return {'statusCode': 200}
    
    def handle_security_hub_event(self, event):
        """
        Handle Security Hub finding events
        """
        detail = event['detail']
        findings = detail.get('findings', [])
        
        for finding in findings:
            if finding.get('Compliance', {}).get('Status') == 'FAILED':
                compliance_violation = {
                    'timestamp': datetime.utcnow().isoformat(),
                    'source': 'AWS Security Hub',
                    'finding_id': finding.get('Id'),
                    'title': finding.get('Title'),
                    'severity': finding.get('Severity', {}).get('Label'),
                    'resource_id': finding.get('Resources', [{}])[0].get('Id', ''),
                    'compliance_status': finding.get('Compliance', {}).get('Status')
                }
                
                self.send_compliance_notification(compliance_violation)
                self.store_compliance_violation(compliance_violation)
        
        return {'statusCode': 200}
    
    def send_compliance_notification(self, violation):
        """
        Send compliance violation notification
        """
        message = f"""
        Compliance Violation Detected
        
        Timestamp: {violation['timestamp']}
        Source: {violation['source']}
        Resource: {violation.get('resource_id', 'Unknown')}
        Issue: {violation.get('title', violation.get('rule_name', 'Compliance violation'))}
        Severity: {violation.get('severity', 'Unknown')}
        
        Please investigate and remediate immediately.
        """
        
        self.sns_client.publish(
            TopicArn='arn:aws:sns:region:account:compliance-violations',
            Message=message,
            Subject=f"Compliance Violation - {violation.get('source', 'Unknown')}"
        )
    
    def store_compliance_violation(self, violation):
        """
        Store compliance violation for reporting and trending
        """
        key = f"compliance-violations/{datetime.utcnow().strftime('%Y/%m/%d')}/{violation.get('resource_id', 'unknown')}-{int(datetime.utcnow().timestamp())}.json"
        
        self.s3_client.put_object(
            Bucket='compliance-reporting-bucket',
            Key=key,
            Body=json.dumps(violation),
            ServerSideEncryption='aws:kms'
        )
    
    def attempt_remediation(self, violation):
        """
        Attempt automated remediation based on violation type
        """
        rule_name = violation.get('rule_name', '')
        resource_id = violation.get('resource_id', '')
        
        remediation_actions = {
            'encrypted-volumes': self.remediate_unencrypted_volume,
            's3-bucket-public-read-prohibited': self.remediate_public_s3_bucket,
            'root-access-key-check': self.remediate_root_access_keys
        }
        
        if rule_name in remediation_actions:
            try:
                remediation_actions[rule_name](resource_id)
                self.sns_client.publish(
                    TopicArn='arn:aws:sns:region:account:compliance-violations',
                    Message=f"Automated remediation attempted for {rule_name} on {resource_id}",
                    Subject="Automated Compliance Remediation"
                )
            except Exception as e:
                print(f"Remediation failed for {rule_name}: {str(e)}")
    
    def remediate_unencrypted_volume(self, volume_id):
        """
        Remediate unencrypted EBS volume
        """
        # Note: EBS volumes cannot be encrypted in-place
        # This would typically involve creating an encrypted snapshot
        # and notifying administrators
        pass
    
    def remediate_public_s3_bucket(self, bucket_name):
        """
        Remediate public S3 bucket by applying public access block
        """
        self.s3_client.put_public_access_block(
            Bucket=bucket_name,
            PublicAccessBlockConfiguration={
                'BlockPublicAcls': True,
                'IgnorePublicAcls': True,
                'BlockPublicPolicy': True,
                'RestrictPublicBuckets': True
            }
        )
```

### 4.3 Evidence Collection Automation

Automate the collection of compliance evidence for audit purposes.

```python
# Automated evidence collection system
class ComplianceEvidenceCollector:
    def __init__(self):
        self.s3_client = boto3.client('s3')
        self.config_client = boto3.client('config')
        self.cloudtrail_client = boto3.client('cloudtrail')
        self.iam_client = boto3.client('iam')
    
    def collect_quarterly_evidence(self, compliance_framework, quarter, year):
        """
        Collect quarterly compliance evidence
        """
        evidence_package = {
            'framework': compliance_framework,
            'period': f'Q{quarter}-{year}',
            'collection_date': datetime.utcnow().isoformat(),
            'evidence': {}
        }
        
        if compliance_framework == 'SOC2':
            evidence_package['evidence'] = self.collect_soc2_evidence(quarter, year)
        elif compliance_framework == 'PCI-DSS':
            evidence_package['evidence'] = self.collect_pci_evidence(quarter, year)
        elif compliance_framework == 'HIPAA':
            evidence_package['evidence'] = self.collect_hipaa_evidence(quarter, year)
        
        # Store evidence package
        evidence_key = f"compliance-evidence/{compliance_framework}/Q{quarter}-{year}/evidence-package.json"
        
        self.s3_client.put_object(
            Bucket='compliance-evidence-archive',
            Key=evidence_key,
            Body=json.dumps(evidence_package, indent=2),
            ServerSideEncryption='aws:kms',
            Metadata={
                'framework': compliance_framework,
                'period': f'Q{quarter}-{year}',
                'retention': '7-years'
            }
        )
        
        return evidence_package
    
    def collect_soc2_evidence(self, quarter, year):
        """
        Collect SOC 2 specific evidence
        """
        start_date = datetime(year, (quarter-1)*3+1, 1)
        end_date = datetime(year, quarter*3+1, 1) - timedelta(days=1)
        
        evidence = {
            'security_controls': self.collect_security_evidence(start_date, end_date),
            'availability_controls': self.collect_availability_evidence(start_date, end_date),
            'integrity_controls': self.collect_integrity_evidence(start_date, end_date),
            'confidentiality_controls': self.collect_confidentiality_evidence(start_date, end_date)
        }
        
        return evidence
    
    def collect_security_evidence(self, start_date, end_date):
        """
        Collect security-related evidence
        """
        evidence = {}
        
        # Collect access control evidence
        evidence['access_controls'] = {
            'iam_policies': self.get_iam_policy_snapshots(),
            'mfa_usage': self.get_mfa_usage_statistics(start_date, end_date),
            'failed_logins': self.get_failed_login_attempts(start_date, end_date)
        }
        
        # Collect encryption evidence
        evidence['encryption'] = {
            'encrypted_resources': self.get_encrypted_resources(),
            'kms_key_usage': self.get_kms_usage_statistics(start_date, end_date)
        }
        
        # Collect monitoring evidence
        evidence['monitoring'] = {
            'cloudtrail_status': self.get_cloudtrail_status(),
            'security_alerts': self.get_security_alerts(start_date, end_date)
        }
        
        return evidence
```

## 5. CI/CD Integration for Compliance

### 5.1 Compliance Gates in Pipelines

Implement compliance validation as part of deployment pipelines.

```yaml
# CodePipeline with compliance gates
version: 0.2
phases:
  pre_build:
    commands:
      - echo "Installing compliance validation tools..."
      - pip install checkov cfn-guard
      - apt-get update && apt-get install -y jq
  
  build:
    commands:
      - echo "Running compliance validation..."
      
      # CloudFormation Guard validation
      - cfn-guard validate --rules compliance-rules/ --data templates/ --output-format json > cfn-guard-results.json
      
      # Checkov security and compliance scanning
      - checkov -f templates/ --framework cloudformation --output json --output-file checkov-results.json
      
      # Custom compliance validation
      - python compliance-validator.py --framework SOC2 --templates templates/
      
      # Check results and fail build if non-compliant
      - python check-compliance-results.py

  post_build:
    commands:
      - echo "Build completed on `date`"
      - |
        if [ $CODEBUILD_BUILD_SUCCEEDING -eq 0 ]; then
          echo "Compliance validation failed. Build stopped."
          exit 1
        fi

artifacts:
  files:
    - templates/*
    - cfn-guard-results.json
    - checkov-results.json
    - compliance-report.json
```

### 5.2 Compliance Validation Scripts

```python
# Custom compliance validation for CI/CD pipelines
import json
import sys
import argparse
from pathlib import Path

class ComplianceValidator:
    def __init__(self, framework):
        self.framework = framework
        self.validation_rules = self.load_validation_rules()
        
    def load_validation_rules(self):
        """Load validation rules for the specified framework"""
        rules_file = f"compliance-rules/{self.framework.lower()}-rules.json"
        
        with open(rules_file, 'r') as f:
            return json.load(f)
    
    def validate_template(self, template_path):
        """Validate a CloudFormation template against compliance rules"""
        with open(template_path, 'r') as f:
            template = json.load(f) if template_path.suffix == '.json' else yaml.safe_load(f)
        
        violations = []
        
        for rule in self.validation_rules['rules']:
            violation = self.check_rule(template, rule)
            if violation:
                violations.append({
                    'rule': rule['name'],
                    'severity': rule['severity'],
                    'message': violation,
                    'template': str(template_path)
                })
        
        return violations
    
    def check_rule(self, template, rule):
        """Check a specific compliance rule against the template"""
        rule_type = rule['type']
        
        if rule_type == 'encryption_required':
            return self.check_encryption_rule(template, rule)
        elif rule_type == 'tagging_required':
            return self.check_tagging_rule(template, rule)
        elif rule_type == 'access_control':
            return self.check_access_control_rule(template, rule)
        
        return None
    
    def check_encryption_rule(self, template, rule):
        """Check encryption compliance rules"""
        resources = template.get('Resources', {})
        
        for resource_name, resource in resources.items():
            resource_type = resource.get('Type', '')
            
            if resource_type in rule['applicable_resources']:
                if not self.has_encryption_enabled(resource, resource_type):
                    return f"Resource {resource_name} of type {resource_type} does not have encryption enabled"
        
        return None
    
    def has_encryption_enabled(self, resource, resource_type):
        """Check if a resource has encryption enabled"""
        properties = resource.get('Properties', {})
        
        encryption_checks = {
            'AWS::S3::Bucket': lambda p: self.check_s3_encryption(p),
            'AWS::RDS::DBInstance': lambda p: p.get('StorageEncrypted', False),
            'AWS::EC2::Volume': lambda p: p.get('Encrypted', False),
            'AWS::EBS::Volume': lambda p: p.get('Encrypted', False)
        }
        
        check_function = encryption_checks.get(resource_type)
        return check_function(properties) if check_function else True
    
    def check_s3_encryption(self, properties):
        """Check S3 bucket encryption configuration"""
        bucket_encryption = properties.get('BucketEncryption', {})
        sse_config = bucket_encryption.get('ServerSideEncryptionConfiguration', [])
        
        if not sse_config:
            return False
        
        for rule in sse_config:
            default_encryption = rule.get('ServerSideEncryptionByDefault', {})
            if default_encryption.get('SSEAlgorithm') in ['AES256', 'aws:kms']:
                return True
        
        return False

def main():
    parser = argparse.ArgumentParser(description='Validate CloudFormation templates for compliance')
    parser.add_argument('--framework', required=True, help='Compliance framework (SOC2, PCI-DSS, HIPAA)')
    parser.add_argument('--templates', required=True, help='Path to templates directory')
    parser.add_argument('--output', default='compliance-report.json', help='Output file for results')
    
    args = parser.parse_args()
    
    validator = ComplianceValidator(args.framework)
    templates_path = Path(args.templates)
    
    all_violations = []
    
    # Validate all templates
    for template_file in templates_path.glob('*.yaml'):
        violations = validator.validate_template(template_file)
        all_violations.extend(violations)
    
    for template_file in templates_path.glob('*.json'):
        violations = validator.validate_template(template_file)
        all_violations.extend(violations)
    
    # Generate report
    report = {
        'framework': args.framework,
        'validation_timestamp': datetime.utcnow().isoformat(),
        'total_violations': len(all_violations),
        'critical_violations': len([v for v in all_violations if v['severity'] == 'CRITICAL']),
        'violations': all_violations
    }
    
    # Save report
    with open(args.output, 'w') as f:
        json.dump(report, f, indent=2)
    
    # Exit with error code if critical violations found
    critical_violations = [v for v in all_violations if v['severity'] == 'CRITICAL']
    if critical_violations:
        print(f"COMPLIANCE VALIDATION FAILED: {len(critical_violations)} critical violations found")
        sys.exit(1)
    else:
        print(f"COMPLIANCE VALIDATION PASSED: {len(all_violations)} non-critical violations found")
        sys.exit(0)

if __name__ == '__main__':
    main()
```

## 6. Compliance Reporting and Dashboards

### 6.1 Automated Compliance Reporting

```python
# Automated compliance reporting system
class ComplianceReporter:
    def __init__(self):
        self.s3_client = boto3.client('s3')
        self.quicksight_client = boto3.client('quicksight')
        
    def generate_monthly_report(self, framework, year, month):
        """Generate monthly compliance report"""
        
        # Collect compliance data
        compliance_data = self.collect_compliance_data(framework, year, month)
        
        # Generate executive summary
        executive_summary = self.generate_executive_summary(compliance_data)
        
        # Generate detailed findings
        detailed_findings = self.generate_detailed_findings(compliance_data)
        
        # Generate remediation recommendations
        recommendations = self.generate_recommendations(compliance_data)
        
        # Create comprehensive report
        report = {
            'framework': framework,
            'reporting_period': f"{year}-{month:02d}",
            'generated_date': datetime.utcnow().isoformat(),
            'executive_summary': executive_summary,
            'detailed_findings': detailed_findings,
            'recommendations': recommendations,
            'raw_data': compliance_data
        }
        
        # Store report
        report_key = f"compliance-reports/{framework}/{year}/{month:02d}/monthly-report.json"
        
        self.s3_client.put_object(
            Bucket='compliance-reports-bucket',
            Key=report_key,
            Body=json.dumps(report, indent=2),
            ServerSideEncryption='aws:kms'
        )
        
        return report
```

This comprehensive content covers the major aspects of compliance frameworks in AWS DevOps environments, providing practical implementation guidance and real-world examples for maintaining compliance while enabling automation and continuous delivery.